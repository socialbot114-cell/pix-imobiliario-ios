import Foundation
import SQLite3
import Combine

/// Local authority for a hot-seat game. All money changes run inside one SQLite transaction.
final class SQLiteGameRepository {
    private var connection: OpaquePointer?
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(databaseURL: URL? = nil) throws {
        let url = databaseURL ?? Self.defaultDatabaseURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard sqlite3_open_v2(url.path, &connection, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            throw makeError("Não foi possível abrir o banco local.")
        }
        sqlite3_busy_timeout(connection, 5_000)
        try execute("PRAGMA foreign_keys = ON")
        try execute("PRAGMA journal_mode = WAL")
        try migrate()
    }

    deinit {
        if let connection { sqlite3_close(connection) }
    }

    static func defaultDatabaseURL() -> URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return root.appendingPathComponent("BancoDoTabuleiro/game.sqlite", isDirectory: false)
    }

    func latestGame() throws -> GameSnapshot? {
        guard let id = try queryInt("SELECT id FROM games ORDER BY id DESC LIMIT 1") else { return nil }
        return try snapshot(gameID: id)
    }

    @discardableResult
    func createGame(name: String, startingBalanceMinor: Int64, players: [NewPlayer]) throws -> GameSnapshot {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { throw GameStoreError.invalidGameName }
        guard (2...6).contains(players.count) else { throw GameStoreError.invalidPlayerCount }
        guard startingBalanceMinor >= 0 else { throw GameStoreError.invalidAmount }
        guard players.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw GameStoreError.invalidPlayerName
        }

        return try transaction {
            try execute("INSERT INTO games(name, invite_code, status, starting_balance_minor, created_at) VALUES(?, ?, 'active', ?, ?)", [
                .text(cleanName), .text(Self.localCode()), .integer(startingBalanceMinor), .text(Self.now())
            ])
            let gameID = sqlite3_last_insert_rowid(connection)
            try execute("INSERT INTO accounts(game_id, player_id, account_type, balance_minor) VALUES(?, NULL, 'bank', 0)", [.integer(gameID)])
            var createdPlayerIDs: [Int64] = []
            for (index, player) in players.enumerated() {
                let name = player.name.trimmingCharacters(in: .whitespacesAndNewlines)
                try execute("INSERT INTO players(game_id, name, color_hex, token, seat_order, board_position) VALUES(?, ?, ?, ?, ?, ?)", [
                    .integer(gameID), .text(name), .text(player.colorHex), .text(player.token), .integer(Int64(index)), .integer(Int64(index * 2))
                ])
                let playerID = sqlite3_last_insert_rowid(connection)
                createdPlayerIDs.append(playerID)
                try execute("INSERT INTO accounts(game_id, player_id, account_type, balance_minor) VALUES(?, ?, 'player', 0)", [
                    .integer(gameID), .integer(playerID)
                ])
            }
            try execute("UPDATE games SET active_player_id = ? WHERE id = ?", [.integer(createdPlayerIDs[0]), .integer(gameID)])

            if startingBalanceMinor > 0 {
                let bankID = try accountID(gameID: gameID, playerID: nil)
                for (index, playerID) in createdPlayerIDs.enumerated() {
                    let account = try accountID(gameID: gameID, playerID: playerID)
                    let txID = try insertTransaction(
                        gameID: gameID,
                        kind: "initial",
                        amount: startingBalanceMinor,
                        description: "Saldo inicial · \(players[index].name)",
                        idempotencyKey: "initial-\(gameID)-\(playerID)"
                    )
                    try recordPair(txID: txID, debitAccount: bankID, creditAccount: account, amount: startingBalanceMinor)
                }
            }

            let samples: [(String, Int64, Int64)] = [
                ("Rua do Ipê", 220_00, 22_00),
                ("Praça das Oliveiras", 360_00, 36_00),
                ("Estação Aurora", 500_00, 50_00)
            ]
            for property in samples {
                try execute("INSERT INTO properties(game_id, name, purchase_price_minor, rent_minor) VALUES(?, ?, ?, ?)", [
                    .integer(gameID), .text(property.0), .integer(property.1), .integer(property.2)
                ])
            }
            return try snapshot(gameID: gameID)
        }
    }

    func addProperty(gameID: Int64, name: String, priceMinor: Int64, rentMinor: Int64) throws {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw GameStoreError.invalidGameName }
        guard priceMinor > 0, rentMinor >= 0 else { throw GameStoreError.invalidAmount }
        try transaction {
            guard try queryInt("SELECT id FROM games WHERE id = ? AND status = 'active'", [.integer(gameID)]) != nil else { throw GameStoreError.noActiveGame }
            try execute("INSERT INTO properties(game_id, name, purchase_price_minor, rent_minor) VALUES(?, ?, ?, ?)", [
                .integer(gameID), .text(clean), .integer(priceMinor), .integer(rentMinor)
            ])
        }
    }

    func selectActivePlayer(gameID: Int64, playerID: Int64) throws {
        try transaction {
            guard try queryInt("SELECT id FROM games WHERE id = ? AND status = 'active'", [.integer(gameID)]) != nil,
                  try queryInt("SELECT id FROM players WHERE id = ? AND game_id = ?", [.integer(playerID), .integer(gameID)]) != nil else {
                throw GameStoreError.noActiveGame
            }
            try execute("UPDATE games SET active_player_id = ? WHERE id = ?", [.integer(playerID), .integer(gameID)])
        }
    }

    @discardableResult
    func advanceBoardPosition(gameID: Int64, playerID: Int64, spaces: Int) throws -> Int {
        guard spaces > 0 else { throw GameStoreError.invalidAmount }
        return try transaction {
            guard try queryInt("SELECT id FROM games WHERE id = ? AND status = 'active'", [.integer(gameID)]) != nil,
                  let current = try queryInt("SELECT board_position FROM players WHERE id = ? AND game_id = ?", [.integer(playerID), .integer(gameID)]) else {
                throw GameStoreError.noActiveGame
            }
            let next = Int((current + Int64(spaces)) % 20)
            try execute("UPDATE players SET board_position = ? WHERE id = ? AND game_id = ?", [.integer(Int64(next)), .integer(playerID), .integer(gameID)])
            return next
        }
    }

    @discardableResult
    func transfer(gameID: Int64, fromPlayerID: Int64, toPlayerID: Int64, amountMinor: Int64, description: String, idempotencyKey: String = UUID().uuidString) throws -> Int64 {
        try performTransfer(gameID: gameID, fromPlayerID: fromPlayerID, toPlayerID: toPlayerID, amountMinor: amountMinor, kind: "transfer", description: description, propertyID: nil, idempotencyKey: idempotencyKey)
    }

    @discardableResult
    func bankMovement(gameID: Int64, playerID: Int64, amountMinor: Int64, kind: BankMovementKind, description: String, idempotencyKey: String = UUID().uuidString) throws -> Int64 {
        guard amountMinor > 0 else { throw GameStoreError.invalidAmount }
        return try transaction {
            guard try queryInt("SELECT id FROM games WHERE id = ? AND status = 'active'", [.integer(gameID)]) != nil else { throw GameStoreError.noActiveGame }
            if let existing = try transactionID(idempotencyKey: idempotencyKey) { return existing }
            let bank = try accountID(gameID: gameID, playerID: nil)
            let player = try accountID(gameID: gameID, playerID: playerID)
            if kind == .receive {
                let txID = try insertTransaction(gameID: gameID, kind: kind.rawValue, amount: amountMinor, description: description, idempotencyKey: idempotencyKey)
                try recordPair(txID: txID, debitAccount: bank, creditAccount: player, amount: amountMinor)
                return txID
            }
            try requireFunds(accountID: player, amount: amountMinor)
            let txID = try insertTransaction(gameID: gameID, kind: kind.rawValue, amount: amountMinor, description: description, idempotencyKey: idempotencyKey)
            try recordPair(txID: txID, debitAccount: player, creditAccount: bank, amount: amountMinor)
            return txID
        }
    }

    @discardableResult
    func buyProperty(gameID: Int64, playerID: Int64, propertyID: Int64, idempotencyKey: String = UUID().uuidString) throws -> Int64 {
        try transaction {
            guard try queryInt("SELECT id FROM games WHERE id = ? AND status = 'active'", [.integer(gameID)]) != nil else { throw GameStoreError.noActiveGame }
            if let existing = try transactionID(idempotencyKey: idempotencyKey) { return existing }
            guard let property = try queryOne("SELECT purchase_price_minor, name, owner_player_id FROM properties WHERE id = ? AND game_id = ?", [.integer(propertyID), .integer(gameID)], map: { row in
                (sqlite3_column_int64(row, 0), text(row, 1), sqlite3_column_type(row, 2) == SQLITE_NULL ? nil : sqlite3_column_int64(row, 2))
            }) else { throw GameStoreError.propertyUnavailable }
            guard property.2 == nil else { throw GameStoreError.propertyUnavailable }
            let bankAccount = try accountID(gameID: gameID, playerID: nil)
            let playerAccount = try accountID(gameID: gameID, playerID: playerID)
            try requireFunds(accountID: playerAccount, amount: property.0)
            let txID = try insertTransaction(gameID: gameID, kind: "purchase", amount: property.0, description: "Compra: \(property.1)", idempotencyKey: idempotencyKey, propertyID: propertyID)
            try recordPair(txID: txID, debitAccount: playerAccount, creditAccount: bankAccount, amount: property.0)
            try execute("UPDATE properties SET owner_player_id = ? WHERE id = ? AND owner_player_id IS NULL", [.integer(playerID), .integer(propertyID)])
            guard sqlite3_changes(connection) == 1 else { throw GameStoreError.propertyUnavailable }
            try execute("INSERT INTO property_ownership(property_id, player_id, acquired_at, transaction_id) VALUES(?, ?, ?, ?)", [
                .integer(propertyID), .integer(playerID), .text(Self.now()), .integer(txID)
            ])
            return txID
        }
    }

    @discardableResult
    func payRent(gameID: Int64, payerPlayerID: Int64, propertyID: Int64, idempotencyKey: String = UUID().uuidString) throws -> Int64 {
        try transaction {
            guard let details = try queryOne("SELECT p.owner_player_id, p.rent_minor, p.name FROM properties p WHERE p.id = ? AND p.game_id = ?", [.integer(propertyID), .integer(gameID)], map: { row in
                (sqlite3_column_type(row, 0) == SQLITE_NULL ? nil : sqlite3_column_int64(row, 0), sqlite3_column_int64(row, 1), text(row, 2))
            }), let ownerID = details.0 else { throw GameStoreError.propertyNotOwned }
            guard details.1 > 0 else { throw GameStoreError.invalidAmount }
            return try transferInsideTransaction(
                gameID: gameID,
                fromPlayerID: payerPlayerID,
                toPlayerID: ownerID,
                amountMinor: details.1,
                kind: "rent",
                description: "Aluguel: \(details.2)",
                propertyID: propertyID,
                idempotencyKey: idempotencyKey
            )
        }
    }

    @discardableResult
    func createPaymentRequest(gameID: Int64, creatorPlayerID: Int64, payerPlayerID: Int64, amountMinor: Int64, description: String) throws -> Int64 {
        guard amountMinor > 0 else { throw GameStoreError.invalidAmount }
        guard creatorPlayerID != payerPlayerID else { throw GameStoreError.samePlayer }
        return try transaction {
            guard try queryInt("SELECT id FROM games WHERE id = ? AND status = 'active'", [.integer(gameID)]) != nil else { throw GameStoreError.noActiveGame }
            _ = try accountID(gameID: gameID, playerID: creatorPlayerID)
            _ = try accountID(gameID: gameID, playerID: payerPlayerID)
            try execute("INSERT INTO payment_requests(game_id, creator_player_id, payer_player_id, amount_minor, description, status, created_at) VALUES(?, ?, ?, ?, ?, 'pending', ?)", [
                .integer(gameID), .integer(creatorPlayerID), .integer(payerPlayerID), .integer(amountMinor), .text(description), .text(Self.now())
            ])
            return sqlite3_last_insert_rowid(connection)
        }
    }

    @discardableResult
    func payRequest(gameID: Int64, requestID: Int64) throws -> Int64 {
        try transaction {
            guard let request = try queryOne("SELECT creator_player_id, payer_player_id, amount_minor, description, status, transaction_id FROM payment_requests WHERE id = ? AND game_id = ?", [.integer(requestID), .integer(gameID)], map: { row in
                (
                    sqlite3_column_int64(row, 0),
                    sqlite3_column_int64(row, 1),
                    sqlite3_column_int64(row, 2),
                    text(row, 3),
                    text(row, 4),
                    sqlite3_column_type(row, 5) == SQLITE_NULL ? nil : sqlite3_column_int64(row, 5)
                )
            }) else { throw GameStoreError.requestUnavailable }
            if request.4 == "paid", let transactionID = request.5 { return transactionID }
            guard request.4 == "pending" else { throw GameStoreError.requestUnavailable }
            let idempotencyKey = "payment-request-\(requestID)"
            if let existing = try transactionID(idempotencyKey: idempotencyKey) { return existing }
            let txID = try transferInsideTransaction(gameID: gameID, fromPlayerID: request.1, toPlayerID: request.0, amountMinor: request.2, kind: "charge", description: request.3, propertyID: nil, idempotencyKey: idempotencyKey)
            try execute("UPDATE payment_requests SET status = 'paid', transaction_id = ? WHERE id = ? AND status = 'pending'", [.integer(txID), .integer(requestID)])
            guard sqlite3_changes(connection) == 1 else { throw GameStoreError.requestUnavailable }
            return txID
        }
    }

    func snapshot(gameID: Int64) throws -> GameSnapshot {
        guard let game = try queryOne("SELECT name, invite_code, status, active_player_id FROM games WHERE id = ?", [.integer(gameID)], map: { row in
            (text(row, 0), text(row, 1), text(row, 2), sqlite3_column_type(row, 3) == SQLITE_NULL ? nil : sqlite3_column_int64(row, 3))
        }) else {
            throw GameStoreError.noActiveGame
        }
        let players = try query("SELECT id, name, color_hex, token, board_position, (SELECT balance_minor FROM accounts WHERE accounts.player_id = players.id) FROM players WHERE game_id = ? ORDER BY seat_order", [.integer(gameID)]) { row in
            GamePlayer(id: sqlite3_column_int64(row, 0), name: text(row, 1), colorHex: text(row, 2), token: text(row, 3), boardPosition: Int(sqlite3_column_int64(row, 4)), balanceMinor: sqlite3_column_int64(row, 5))
        }
        let properties = try query("SELECT p.id, p.name, p.purchase_price_minor, p.rent_minor, p.owner_player_id, owner.name FROM properties p LEFT JOIN players owner ON owner.id = p.owner_player_id WHERE p.game_id = ? ORDER BY p.id", [.integer(gameID)]) { row in
            GameProperty(id: sqlite3_column_int64(row, 0), name: text(row, 1), purchasePriceMinor: sqlite3_column_int64(row, 2), rentMinor: sqlite3_column_int64(row, 3), ownerPlayerID: sqlite3_column_type(row, 4) == SQLITE_NULL ? nil : sqlite3_column_int64(row, 4), ownerName: sqlite3_column_type(row, 5) == SQLITE_NULL ? nil : text(row, 5))
        }
        let transactions = try query("SELECT t.id, t.kind, t.amount_minor, src.id, COALESCE(src.name, 'Banco'), dst.id, COALESCE(dst.name, 'Banco'), t.description, t.created_at FROM transactions t LEFT JOIN accounts srca ON srca.id = (SELECT account_id FROM transaction_entries WHERE transaction_id = t.id AND amount_minor < 0 ORDER BY id LIMIT 1) LEFT JOIN players src ON src.id = srca.player_id LEFT JOIN accounts dsta ON dsta.id = (SELECT account_id FROM transaction_entries WHERE transaction_id = t.id AND amount_minor > 0 ORDER BY id LIMIT 1) LEFT JOIN players dst ON dst.id = dsta.player_id WHERE t.game_id = ? ORDER BY t.id DESC LIMIT 50", [.integer(gameID)]) { row in
            GameTransaction(
                id: sqlite3_column_int64(row, 0),
                kind: text(row, 1),
                amountMinor: sqlite3_column_int64(row, 2),
                fromPlayerID: sqlite3_column_type(row, 3) == SQLITE_NULL ? nil : sqlite3_column_int64(row, 3),
                fromName: text(row, 4),
                toPlayerID: sqlite3_column_type(row, 5) == SQLITE_NULL ? nil : sqlite3_column_int64(row, 5),
                toName: text(row, 6),
                description: text(row, 7),
                createdAt: text(row, 8)
            )
        }
        let requests = try query("SELECT r.id, r.payer_player_id, payer.name, creator.name, r.amount_minor, r.description, r.status FROM payment_requests r JOIN players payer ON payer.id = r.payer_player_id JOIN players creator ON creator.id = r.creator_player_id WHERE r.game_id = ? AND r.status = 'pending' ORDER BY r.id DESC", [.integer(gameID)]) { row in
            PaymentRequest(id: sqlite3_column_int64(row, 0), payerPlayerID: sqlite3_column_int64(row, 1), payerName: text(row, 2), creatorName: text(row, 3), amountMinor: sqlite3_column_int64(row, 4), description: text(row, 5), status: text(row, 6))
        }
        return GameSnapshot(id: gameID, name: game.0, inviteCode: game.1, status: game.2, activePlayerID: game.3, players: players, properties: properties, transactions: transactions, pendingRequests: requests)
    }

    func transactionEntriesBalance(transactionID: Int64) throws -> Int64 {
        try queryInt("SELECT COALESCE(SUM(amount_minor), 0) FROM transaction_entries WHERE transaction_id = ?", [.integer(transactionID)]) ?? 0
    }

    func closeGame(gameID: Int64) throws {
        try execute("UPDATE games SET status = 'finished', finished_at = ? WHERE id = ? AND status = 'active'", [.text(Self.now()), .integer(gameID)])
    }

    func deleteAllGames() throws {
        try transaction {
            try execute("DELETE FROM games")
        }
    }

    private func performTransfer(gameID: Int64, fromPlayerID: Int64, toPlayerID: Int64, amountMinor: Int64, kind: String, description: String, propertyID: Int64?, idempotencyKey: String) throws -> Int64 {
        guard amountMinor > 0 else { throw GameStoreError.invalidAmount }
        guard fromPlayerID != toPlayerID else { throw GameStoreError.samePlayer }
        return try transaction {
            try transferInsideTransaction(gameID: gameID, fromPlayerID: fromPlayerID, toPlayerID: toPlayerID, amountMinor: amountMinor, kind: kind, description: description, propertyID: propertyID, idempotencyKey: idempotencyKey)
        }
    }

    private func transferInsideTransaction(gameID: Int64, fromPlayerID: Int64, toPlayerID: Int64, amountMinor: Int64, kind: String, description: String, propertyID: Int64?, idempotencyKey: String) throws -> Int64 {
        guard amountMinor > 0 else { throw GameStoreError.invalidAmount }
        guard fromPlayerID != toPlayerID else { throw GameStoreError.samePlayer }
        guard try queryInt("SELECT id FROM games WHERE id = ? AND status = 'active'", [.integer(gameID)]) != nil else { throw GameStoreError.noActiveGame }
        if let existing = try transactionID(idempotencyKey: idempotencyKey) { return existing }
        let debit = try accountID(gameID: gameID, playerID: fromPlayerID)
        let credit = try accountID(gameID: gameID, playerID: toPlayerID)
        try requireFunds(accountID: debit, amount: amountMinor)
        let txID = try insertTransaction(gameID: gameID, kind: kind, amount: amountMinor, description: description, idempotencyKey: idempotencyKey, propertyID: propertyID)
        try recordPair(txID: txID, debitAccount: debit, creditAccount: credit, amount: amountMinor)
        return txID
    }

    private func recordPair(txID: Int64, debitAccount: Int64, creditAccount: Int64, amount: Int64) throws {
        try addEntry(transactionID: txID, accountID: debitAccount, amount: -amount)
        try addEntry(transactionID: txID, accountID: creditAccount, amount: amount)
        try changeBalance(accountID: debitAccount, amount: -amount)
        try changeBalance(accountID: creditAccount, amount: amount)
    }

    private func insertTransaction(gameID: Int64, kind: String, amount: Int64, description: String, idempotencyKey: String, propertyID: Int64? = nil) throws -> Int64 {
        try execute("INSERT INTO transactions(game_id, kind, amount_minor, description, idempotency_key, property_id, created_at) VALUES(?, ?, ?, ?, ?, ?, ?)", [
            .integer(gameID), .text(kind), .integer(amount), .text(description), .text(idempotencyKey), propertyID.map(SQLiteValue.integer) ?? .null, .text(Self.now())
        ])
        return sqlite3_last_insert_rowid(connection)
    }

    private func transactionID(idempotencyKey: String) throws -> Int64? {
        try queryInt("SELECT id FROM transactions WHERE idempotency_key = ?", [.text(idempotencyKey)])
    }

    private func accountID(gameID: Int64, playerID: Int64?) throws -> Int64 {
        guard let id = try queryInt("SELECT id FROM accounts WHERE game_id = ? AND player_id IS ?", [.integer(gameID), playerID.map(SQLiteValue.integer) ?? .null]) else {
            throw GameStoreError.noActiveGame
        }
        return id
    }

    private func requireFunds(accountID: Int64, amount: Int64) throws {
        guard let balance = try queryInt("SELECT balance_minor FROM accounts WHERE id = ?", [.integer(accountID)]), balance >= amount else {
            throw GameStoreError.insufficientFunds
        }
    }

    private func changeBalance(accountID: Int64, amount: Int64) throws {
        try execute("UPDATE accounts SET balance_minor = balance_minor + ? WHERE id = ?", [.integer(amount), .integer(accountID)])
        guard sqlite3_changes(connection) == 1 else { throw GameStoreError.noActiveGame }
    }

    private func addEntry(transactionID: Int64, accountID: Int64, amount: Int64) throws {
        try execute("INSERT INTO transaction_entries(transaction_id, account_id, amount_minor) VALUES(?, ?, ?)", [.integer(transactionID), .integer(accountID), .integer(amount)])
    }

    private func migrate() throws {
        try executeScript("""
        CREATE TABLE IF NOT EXISTS schema_migrations(version INTEGER PRIMARY KEY, applied_at TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS games(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            invite_code TEXT NOT NULL UNIQUE,
            status TEXT NOT NULL CHECK(status IN ('active','finished')),
            starting_balance_minor INTEGER NOT NULL CHECK(starting_balance_minor >= 0),
            created_at TEXT NOT NULL,
            finished_at TEXT
        );
        CREATE TABLE IF NOT EXISTS players(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            game_id INTEGER NOT NULL REFERENCES games(id) ON DELETE CASCADE,
            name TEXT NOT NULL,
            color_hex TEXT NOT NULL,
            token TEXT NOT NULL,
            seat_order INTEGER NOT NULL,
            UNIQUE(game_id, seat_order)
        );
        CREATE TABLE IF NOT EXISTS accounts(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            game_id INTEGER NOT NULL REFERENCES games(id) ON DELETE CASCADE,
            player_id INTEGER REFERENCES players(id) ON DELETE CASCADE,
            account_type TEXT NOT NULL CHECK(account_type IN ('bank','player')),
            balance_minor INTEGER NOT NULL DEFAULT 0,
            CHECK((account_type = 'bank' AND player_id IS NULL) OR (account_type = 'player' AND player_id IS NOT NULL)),
            UNIQUE(game_id, player_id)
        );
        CREATE TABLE IF NOT EXISTS properties(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            game_id INTEGER NOT NULL REFERENCES games(id) ON DELETE CASCADE,
            name TEXT NOT NULL,
            purchase_price_minor INTEGER NOT NULL CHECK(purchase_price_minor > 0),
            rent_minor INTEGER NOT NULL CHECK(rent_minor >= 0),
            owner_player_id INTEGER REFERENCES players(id),
            UNIQUE(game_id, name)
        );
        CREATE TABLE IF NOT EXISTS transactions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            game_id INTEGER NOT NULL REFERENCES games(id) ON DELETE CASCADE,
            kind TEXT NOT NULL,
            amount_minor INTEGER NOT NULL CHECK(amount_minor >= 0),
            description TEXT NOT NULL,
            idempotency_key TEXT NOT NULL UNIQUE,
            property_id INTEGER REFERENCES properties(id),
            created_at TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS transaction_entries(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            transaction_id INTEGER NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
            account_id INTEGER NOT NULL REFERENCES accounts(id),
            amount_minor INTEGER NOT NULL CHECK(amount_minor != 0)
        );
        CREATE TABLE IF NOT EXISTS property_ownership(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            property_id INTEGER NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
            player_id INTEGER NOT NULL REFERENCES players(id),
            acquired_at TEXT NOT NULL,
            released_at TEXT,
            transaction_id INTEGER NOT NULL REFERENCES transactions(id)
        );
        CREATE UNIQUE INDEX IF NOT EXISTS one_active_owner_per_property ON property_ownership(property_id) WHERE released_at IS NULL;
        CREATE TABLE IF NOT EXISTS payment_requests(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            game_id INTEGER NOT NULL REFERENCES games(id) ON DELETE CASCADE,
            creator_player_id INTEGER NOT NULL REFERENCES players(id),
            payer_player_id INTEGER NOT NULL REFERENCES players(id),
            amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
            description TEXT NOT NULL,
            status TEXT NOT NULL CHECK(status IN ('pending','paid','cancelled')),
            transaction_id INTEGER REFERENCES transactions(id),
            created_at TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS transactions_by_game ON transactions(game_id, id DESC);
        CREATE INDEX IF NOT EXISTS properties_by_game ON properties(game_id, id);
        INSERT OR IGNORE INTO schema_migrations(version, applied_at) VALUES(1, '2026-10-09T00:00:00Z');
        """)
        if (try queryInt("SELECT MAX(version) FROM schema_migrations") ?? 0) < 2 {
            try transaction {
                try execute("ALTER TABLE games ADD COLUMN active_player_id INTEGER")
                try execute("UPDATE games SET active_player_id = (SELECT id FROM players WHERE players.game_id = games.id ORDER BY seat_order LIMIT 1)")
                try execute("INSERT INTO schema_migrations(version, applied_at) VALUES(2, ?)", [.text(Self.now())])
            }
        }
        if (try queryInt("SELECT MAX(version) FROM schema_migrations") ?? 0) < 3 {
            try transaction {
                try execute("ALTER TABLE players ADD COLUMN board_position INTEGER NOT NULL DEFAULT 0")
                try execute("UPDATE players SET board_position = seat_order * 2")
                try execute("INSERT INTO schema_migrations(version, applied_at) VALUES(3, ?)", [.text(Self.now())])
            }
        }
    }

    private enum SQLiteValue {
        case integer(Int64)
        case text(String)
        case null
    }

    private func transaction<T>(_ body: () throws -> T) throws -> T {
        try execute("BEGIN IMMEDIATE")
        do {
            let value = try body()
            try execute("COMMIT")
            return value
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    private func execute(_ sql: String, _ values: [SQLiteValue] = []) throws {
        try withStatement(sql, values) { statement in
            let result = sqlite3_step(statement)
            guard result == SQLITE_DONE || result == SQLITE_ROW else { throw makeError(String(cString: sqlite3_errmsg(connection))) }
        }
    }

    private func executeScript(_ sql: String) throws {
        guard let connection else { throw GameStoreError.database("Banco local indisponível.") }
        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(connection, sql, nil, nil, &errorMessage)
        guard result == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? String(cString: sqlite3_errmsg(connection))
            if let errorMessage { sqlite3_free(errorMessage) }
            throw GameStoreError.database(message)
        }
    }

    private func queryInt(_ sql: String, _ values: [SQLiteValue] = []) throws -> Int64? {
        try queryOne(sql, values, map: { sqlite3_column_int64($0, 0) })
    }

    private func query<T>(_ sql: String, _ values: [SQLiteValue] = [], map: (OpaquePointer) -> T) throws -> [T] {
        try withStatement(sql, values) { statement in
            var rows: [T] = []
            while true {
                let result = sqlite3_step(statement)
                if result == SQLITE_DONE { break }
                guard result == SQLITE_ROW else { throw makeError(String(cString: sqlite3_errmsg(connection))) }
                rows.append(map(statement))
            }
            return rows
        }
    }

    private func queryOne<T>(_ sql: String, _ values: [SQLiteValue] = [], map: (OpaquePointer) -> T) throws -> T? {
        try query(sql, values, map: map).first
    }

    private func withStatement<T>(_ sql: String, _ values: [SQLiteValue], body: (OpaquePointer) throws -> T) throws -> T {
        guard let connection else { throw GameStoreError.database("Banco local indisponível.") }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw makeError(String(cString: sqlite3_errmsg(connection)))
        }
        defer { sqlite3_finalize(statement) }
        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1)
            let result: Int32
            switch value {
            case .integer(let number): result = sqlite3_bind_int64(statement, index, number)
            case .text(let string): result = string.withCString { sqlite3_bind_text(statement, index, $0, -1, transient) }
            case .null: result = sqlite3_bind_null(statement, index)
            }
            guard result == SQLITE_OK else { throw makeError(String(cString: sqlite3_errmsg(connection))) }
        }
        return try body(statement)
    }

    private func text(_ row: OpaquePointer, _ column: Int32) -> String {
        guard let value = sqlite3_column_text(row, column) else { return "" }
        return String(cString: value)
    }

    private func makeError(_ message: String) -> GameStoreError {
        .database(message)
    }

    private static func now() -> String { ISO8601DateFormatter().string(from: Date()) }
    private static func localCode() -> String { String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6)).uppercased() }
}

@MainActor
final class GameStore: ObservableObject {
    @Published private(set) var game: GameSnapshot?
    @Published var errorMessage: String?
    private var repository: SQLiteGameRepository?

    init(repository: SQLiteGameRepository? = nil) {
        let arguments = ProcessInfo.processInfo.arguments
        let isUITesting = arguments.contains("-ui-testing")
        let testURL = FileManager.default.temporaryDirectory.appendingPathComponent("banco-do-tabuleiro-ui-test.sqlite")
        if isUITesting {
            for url in [testURL, URL(fileURLWithPath: testURL.path + "-wal"), URL(fileURLWithPath: testURL.path + "-shm")] {
                try? FileManager.default.removeItem(at: url)
            }
        }
        do {
            let localRepository: SQLiteGameRepository
            if let repository {
                localRepository = repository
            } else {
                localRepository = try SQLiteGameRepository(databaseURL: isUITesting ? testURL : nil)
            }
            self.repository = localRepository
            game = try localRepository.latestGame()
            if isUITesting, game == nil, arguments.contains("-screenshot-mode") {
                game = try localRepository.createGame(
                    name: "Noite de Jogo",
                    startingBalanceMinor: 245_000,
                    players: [
                        NewPlayer(name: "Ana", colorHex: "#13845B", token: "peao"),
                        NewPlayer(name: "Bruno", colorHex: "#D9483B", token: "torre"),
                        NewPlayer(name: "Carla", colorHex: "#536FD8", token: "estrela"),
                        NewPlayer(name: "Diego", colorHex: "#9253C7", token: "casa")
                    ]
                )
            }
            if isUITesting, arguments.contains("-visual-review-data"), let game {
                self.game = try Self.seedVisualReviewData(repository: localRepository, game: game)
            }
        } catch {
            self.repository = nil
            errorMessage = error.localizedDescription
        }
    }

    func createGame(name: String, startingBalanceMinor: Int64, players: [NewPlayer]) {
        guard let repository else { errorMessage = "O banco local não está disponível."; return }
        do { game = try repository.createGame(name: name, startingBalanceMinor: startingBalanceMinor, players: players); errorMessage = nil }
        catch { errorMessage = error.localizedDescription }
    }

    func transfer(from: Int64, to: Int64, amount: Int64, description: String) {
        guard let game, let repository else { errorMessage = GameStoreError.noActiveGame.localizedDescription; return }
        do { try repository.transfer(gameID: game.id, fromPlayerID: from, toPlayerID: to, amountMinor: amount, description: description); refresh() }
        catch { errorMessage = error.localizedDescription }
    }

    func bankMovement(amount: Int64, kind: BankMovementKind, description: String) {
        guard let game, let playerID = game.currentPlayer?.id, let repository else {
            errorMessage = GameStoreError.noActiveGame.localizedDescription
            return
        }
        do { try repository.bankMovement(gameID: game.id, playerID: playerID, amountMinor: amount, kind: kind, description: description); refresh() }
        catch { errorMessage = error.localizedDescription }
    }

    func buy(property: GameProperty, playerID: Int64) {
        guard let game, let repository else { errorMessage = GameStoreError.noActiveGame.localizedDescription; return }
        do { try repository.buyProperty(gameID: game.id, playerID: playerID, propertyID: property.id); refresh() }
        catch { errorMessage = error.localizedDescription }
    }

    func addProperty(name: String, price: Int64, rent: Int64) {
        guard let game, let repository else { errorMessage = GameStoreError.noActiveGame.localizedDescription; return }
        do { try repository.addProperty(gameID: game.id, name: name, priceMinor: price, rentMinor: rent); refresh() }
        catch { errorMessage = error.localizedDescription }
    }

    func selectActivePlayer(_ player: GamePlayer) {
        guard let game, let repository else { errorMessage = GameStoreError.noActiveGame.localizedDescription; return }
        do { try repository.selectActivePlayer(gameID: game.id, playerID: player.id); refresh() }
        catch { errorMessage = error.localizedDescription }
    }

    func advanceBoardPosition(playerID: Int64, spaces: Int) {
        guard let game, let repository else { errorMessage = GameStoreError.noActiveGame.localizedDescription; return }
        do { try repository.advanceBoardPosition(gameID: game.id, playerID: playerID, spaces: spaces); refresh() }
        catch { errorMessage = error.localizedDescription }
    }

    func createCharge(creator: Int64, payer: Int64, amount: Int64, description: String) {
        guard let game, let repository else { errorMessage = GameStoreError.noActiveGame.localizedDescription; return }
        do { try repository.createPaymentRequest(gameID: game.id, creatorPlayerID: creator, payerPlayerID: payer, amountMinor: amount, description: description); refresh() }
        catch { errorMessage = error.localizedDescription }
    }

    func payCharge(_ request: PaymentRequest) {
        guard let game, let repository else { errorMessage = GameStoreError.noActiveGame.localizedDescription; return }
        do { try repository.payRequest(gameID: game.id, requestID: request.id); refresh() }
        catch { errorMessage = error.localizedDescription }
    }

    func payRent(property: GameProperty, payerID: Int64) {
        guard let game, let repository else { errorMessage = GameStoreError.noActiveGame.localizedDescription; return }
        do { try repository.payRent(gameID: game.id, payerPlayerID: payerID, propertyID: property.id); refresh() }
        catch { errorMessage = error.localizedDescription }
    }

    func finishGame() {
        guard let game, let repository else { return }
        do { try repository.closeGame(gameID: game.id); refresh() }
        catch { errorMessage = error.localizedDescription }
    }

    func deleteAllGames() {
        guard let repository else { errorMessage = "O banco local não está disponível."; return }
        do { try repository.deleteAllGames(); game = nil; errorMessage = nil }
        catch { errorMessage = error.localizedDescription }
    }

    func refresh() {
        do { if let game, let repository { self.game = try repository.snapshot(gameID: game.id) } }
        catch { errorMessage = error.localizedDescription }
    }

    func clearError() { errorMessage = nil }

    private static func seedVisualReviewData(repository: SQLiteGameRepository, game: GameSnapshot) throws -> GameSnapshot {
        guard game.players.count > 1,
              let ana = game.players.first,
              let bruno = game.players.dropFirst().first,
              let firstProperty = game.properties.first else { return game }

        _ = try repository.buyProperty(
            gameID: game.id,
            playerID: ana.id,
            propertyID: firstProperty.id,
            idempotencyKey: "visual-purchase-\(game.id)"
        )
        _ = try repository.transfer(
            gameID: game.id,
            fromPlayerID: ana.id,
            toPlayerID: bruno.id,
            amountMinor: 12_500,
            description: "PIX · acordo de mesa",
            idempotencyKey: "visual-transfer-\(game.id)"
        )
        _ = try repository.payRent(
            gameID: game.id,
            payerPlayerID: bruno.id,
            propertyID: firstProperty.id,
            idempotencyKey: "visual-rent-\(game.id)"
        )
        _ = try repository.bankMovement(
            gameID: game.id,
            playerID: ana.id,
            amountMinor: 20_000,
            kind: .receive,
            description: "Renda pela casa inicial",
            idempotencyKey: "visual-bank-credit-\(game.id)"
        )
        return try repository.snapshot(gameID: game.id)
    }
}
