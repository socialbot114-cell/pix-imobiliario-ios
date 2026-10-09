import XCTest
@testable import BancoDoTabuleiro

final class SQLiteGameRepositoryTests: XCTestCase {
    private var databaseURL: URL!
    private var repository: SQLiteGameRepository!
    private var game: GameSnapshot!

    override func setUpWithError() throws {
        databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("BancoDoTabuleiroTests-\(UUID().uuidString).sqlite")
        repository = try SQLiteGameRepository(databaseURL: databaseURL)
        game = try repository.createGame(
            name: "Teste local",
            startingBalanceMinor: 1_000_00,
            players: [
                NewPlayer(name: "Ana", colorHex: "#13845B", token: "peao"),
                NewPlayer(name: "Bia", colorHex: "#D9483B", token: "casa")
            ]
        )
    }

    override func tearDownWithError() throws {
        repository = nil
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(atPath: databaseURL.path + suffix)
        }
    }

    func testStartingBalanceAndLedgerAreCreatedTogether() throws {
        XCTAssertEqual(game.players.map(\.balanceMinor), [1_000_00, 1_000_00])
        XCTAssertEqual(game.transactions.count, 2)
        XCTAssertTrue(game.transactions.allSatisfy { $0.kind == "initial" && $0.amountMinor == 1_000_00 })
        for transaction in game.transactions {
            XCTAssertEqual(try repository.transactionEntriesBalance(transactionID: transaction.id), 0)
        }
    }

    func testTransferUpdatesBothPlayersAndSameIdempotencyKeyDoesNotDuplicate() throws {
        let payer = try XCTUnwrap(game.players.first)
        let receiver = try XCTUnwrap(game.players.last)
        let first = try repository.transfer(
            gameID: game.id,
            fromPlayerID: payer.id,
            toPlayerID: receiver.id,
            amountMinor: 25_00,
            description: "PIX de teste",
            idempotencyKey: "test-transfer-once"
        )
        let retry = try repository.transfer(
            gameID: game.id,
            fromPlayerID: payer.id,
            toPlayerID: receiver.id,
            amountMinor: 25_00,
            description: "PIX de teste",
            idempotencyKey: "test-transfer-once"
        )
        let result = try repository.snapshot(gameID: game.id)

        XCTAssertEqual(first, retry)
        XCTAssertEqual(try repository.transactionEntriesBalance(transactionID: first), 0)
        XCTAssertEqual(result.players.map(\.balanceMinor), [975_00, 1_025_00])
        XCTAssertEqual(result.transactions.filter { $0.kind == "transfer" }.count, 1)
    }

    func testInsufficientFundsDoesNotCreateTransactionOrChangeBalance() throws {
        let payer = try XCTUnwrap(game.players.first)
        let receiver = try XCTUnwrap(game.players.last)

        XCTAssertThrowsError(try repository.transfer(
            gameID: game.id,
            fromPlayerID: payer.id,
            toPlayerID: receiver.id,
            amountMinor: 1_000_01,
            description: "Valor acima do saldo",
            idempotencyKey: "insufficient-funds"
        )) { error in
            XCTAssertEqual(error as? GameStoreError, .insufficientFunds)
        }

        let result = try repository.snapshot(gameID: game.id)
        XCTAssertEqual(result.players.map(\.balanceMinor), [1_000_00, 1_000_00])
        XCTAssertEqual(result.transactions.filter { $0.kind == "initial" }.count, 2)
    }

    func testPropertyPurchaseIsAtomicAndRentUsesPropertyOwner() throws {
        let buyer = try XCTUnwrap(game.players[0])
        let payer = try XCTUnwrap(game.players[1])
        let property = try XCTUnwrap(game.properties.first)

        let firstPurchase = try repository.buyProperty(gameID: game.id, playerID: buyer.id, propertyID: property.id, idempotencyKey: "buy-ipê")
        let retriedPurchase = try repository.buyProperty(gameID: game.id, playerID: buyer.id, propertyID: property.id, idempotencyKey: "buy-ipê")
        let afterPurchase = try repository.snapshot(gameID: game.id)
        let purchased = try XCTUnwrap(afterPurchase.properties.first(where: { $0.id == property.id }))
        XCTAssertEqual(firstPurchase, retriedPurchase)
        XCTAssertEqual(purchased.ownerPlayerID, buyer.id)
        XCTAssertEqual(afterPurchase.players.first?.balanceMinor, 780_00)

        let rent = try repository.payRent(gameID: game.id, payerPlayerID: payer.id, propertyID: property.id, idempotencyKey: "rent-ipê")
        let repeatedRent = try repository.payRent(gameID: game.id, payerPlayerID: payer.id, propertyID: property.id, idempotencyKey: "rent-ipê")
        let afterRent = try repository.snapshot(gameID: game.id)
        XCTAssertEqual(rent, repeatedRent)
        XCTAssertEqual(afterRent.players.first?.balanceMinor, 1_000_00 + property.rentMinor - property.purchasePriceMinor)
        XCTAssertEqual(afterRent.players.last?.balanceMinor, 1_000_00 - property.rentMinor)
        XCTAssertTrue(afterRent.transactions.contains(where: { $0.kind == "rent" && $0.description.contains(property.name) }))
    }

    func testChargeChangesBalanceOnlyWhenPaidAndCannotBePaidTwice() throws {
        let creator = try XCTUnwrap(game.players[0])
        let payer = try XCTUnwrap(game.players[1])
        let request = try repository.createPaymentRequest(
            gameID: game.id,
            creatorPlayerID: creator.id,
            payerPlayerID: payer.id,
            amountMinor: 20_00,
            description: "Aluguel"
        )
        XCTAssertEqual(try repository.snapshot(gameID: game.id).players.map(\.balanceMinor), [1_000_00, 1_000_00])

        let firstPayment = try repository.payRequest(gameID: game.id, requestID: request)
        let retryPayment = try repository.payRequest(gameID: game.id, requestID: request)
        let result = try repository.snapshot(gameID: game.id)

        XCTAssertEqual(firstPayment, retryPayment)
        XCTAssertEqual(result.players.map(\.balanceMinor), [1_020_00, 980_00])
        XCTAssertEqual(result.transactions.filter { $0.kind == "charge" }.count, 1)
        XCTAssertTrue(result.pendingRequests.isEmpty)
    }

    func testMoneyFormattingUsesVirtualCurrencyAndMinorUnits() {
        XCTAssertEqual(MoneyFormat.minorUnits(from: "1.234,50"), 123_450)
        XCTAssertEqual(MoneyFormat.minorUnits(from: "0"), nil)
        XCTAssertTrue(MoneyFormat.string(12_345).contains("123,45"))
        XCTAssertTrue(MoneyFormat.string(12_345).hasPrefix("M$"))
    }

    func testFinishedGameRejectsNewFinancialOperations() throws {
        let payer = try XCTUnwrap(game.players.first)
        let receiver = try XCTUnwrap(game.players.last)
        try repository.closeGame(gameID: game.id)

        XCTAssertThrowsError(try repository.transfer(
            gameID: game.id,
            fromPlayerID: payer.id,
            toPlayerID: receiver.id,
            amountMinor: 10_00,
            description: "Após encerramento",
            idempotencyKey: "after-finish-transfer"
        )) { error in
            XCTAssertEqual(error as? GameStoreError, .noActiveGame)
        }
        XCTAssertThrowsError(try repository.createPaymentRequest(
            gameID: game.id,
            creatorPlayerID: payer.id,
            payerPlayerID: receiver.id,
            amountMinor: 10_00,
            description: "Após encerramento"
        )) { error in
            XCTAssertEqual(error as? GameStoreError, .noActiveGame)
        }

        let result = try repository.snapshot(gameID: game.id)
        XCTAssertEqual(result.players.map(\.balanceMinor), [1_000_00, 1_000_00])
        XCTAssertEqual(result.transactions.filter { $0.kind == "initial" }.count, 2)
    }

    func testActivePlayerChoicePersistsAcrossRepositoryReopen() throws {
        let selected = try XCTUnwrap(game.players.last)
        try repository.selectActivePlayer(gameID: game.id, playerID: selected.id)

        let reopened = try SQLiteGameRepository(databaseURL: databaseURL)
        let restored = try XCTUnwrap(reopened.latestGame())
        XCTAssertEqual(restored.activePlayerID, selected.id)
        XCTAssertEqual(restored.currentPlayer?.name, selected.name)
    }

    func testBankCreditsAndDebitsUseTheSameBalancedLedger() throws {
        let player = try XCTUnwrap(game.currentPlayer)
        let credit = try repository.bankMovement(
            gameID: game.id,
            playerID: player.id,
            amountMinor: 50_00,
            kind: .receive,
            description: "Passou pela casa inicial",
            idempotencyKey: "start-bonus"
        )
        let repeatedCredit = try repository.bankMovement(
            gameID: game.id,
            playerID: player.id,
            amountMinor: 50_00,
            kind: .receive,
            description: "Passou pela casa inicial",
            idempotencyKey: "start-bonus"
        )
        XCTAssertEqual(credit, repeatedCredit)
        XCTAssertEqual(try repository.transactionEntriesBalance(transactionID: credit), 0)
        XCTAssertEqual(try repository.snapshot(gameID: game.id).currentPlayer?.balanceMinor, 1_050_00)

        let debit = try repository.bankMovement(
            gameID: game.id,
            playerID: player.id,
            amountMinor: 25_00,
            kind: .pay,
            description: "Taxa da partida",
            idempotencyKey: "game-fee"
        )
        XCTAssertEqual(try repository.transactionEntriesBalance(transactionID: debit), 0)
        XCTAssertEqual(try repository.snapshot(gameID: game.id).currentPlayer?.balanceMinor, 1_025_00)

        XCTAssertThrowsError(try repository.bankMovement(
            gameID: game.id,
            playerID: player.id,
            amountMinor: 2_000_00,
            kind: .pay,
            description: "Taxa acima do saldo",
            idempotencyKey: "too-large-fee"
        )) { error in
            XCTAssertEqual(error as? GameStoreError, .insufficientFunds)
        }
    }

    func testBoardPositionAdvancesWrapsAndPersists() throws {
        let player = try XCTUnwrap(game.players.first)
        XCTAssertEqual(player.boardPosition, 0)
        XCTAssertEqual(try repository.advanceBoardPosition(gameID: game.id, playerID: player.id, spaces: 12), 12)
        XCTAssertEqual(try repository.advanceBoardPosition(gameID: game.id, playerID: player.id, spaces: 10), 2)

        let reopened = try SQLiteGameRepository(databaseURL: databaseURL)
        let restored = try XCTUnwrap(reopened.latestGame())
        XCTAssertEqual(restored.players.first?.boardPosition, 2)
    }
}
