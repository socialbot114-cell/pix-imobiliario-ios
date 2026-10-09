import Foundation

struct GamePlayer: Identifiable, Equatable {
    let id: Int64
    let name: String
    let colorHex: String
    let token: String
    let boardPosition: Int
    let balanceMinor: Int64
}

struct GameProperty: Identifiable, Equatable {
    let id: Int64
    let name: String
    let purchasePriceMinor: Int64
    let rentMinor: Int64
    let ownerPlayerID: Int64?
    let ownerName: String?

    var isAvailable: Bool { ownerPlayerID == nil }
}

struct GameTransaction: Identifiable, Equatable {
    let id: Int64
    let kind: String
    let amountMinor: Int64
    let fromPlayerID: Int64?
    let fromName: String
    let toPlayerID: Int64?
    let toName: String
    let description: String
    let createdAt: String
}

struct PaymentRequest: Identifiable, Equatable {
    let id: Int64
    let payerPlayerID: Int64
    let payerName: String
    let creatorName: String
    let amountMinor: Int64
    let description: String
    let status: String
}

private struct PlayerValuation {
    let seat: Int
    let player: GamePlayer
    let propertyValueMinor: Int64
    let propertyCount: Int
    let netWorthMinor: Int64
}

struct GameSnapshot: Equatable {
    let id: Int64
    let name: String
    let inviteCode: String
    let status: String
    let activePlayerID: Int64?
    let players: [GamePlayer]
    let properties: [GameProperty]
    let transactions: [GameTransaction]
    let pendingRequests: [PaymentRequest]

    var currentPlayer: GamePlayer? {
        players.first(where: { $0.id == activePlayerID }) ?? players.first
    }

    var standings: [PlayerStanding] {
        var valuations: [PlayerValuation] = []
        for (seat, player) in players.enumerated() {
            let ownedProperties = properties.filter { $0.ownerPlayerID == player.id }
            let propertyValueMinor = ownedProperties.reduce(Int64(0)) { total, property in
                total + property.purchasePriceMinor
            }
            let valuation = PlayerValuation(
                seat: seat,
                player: player,
                propertyValueMinor: propertyValueMinor,
                propertyCount: ownedProperties.count,
                netWorthMinor: player.balanceMinor + propertyValueMinor
            )
            valuations.append(valuation)
        }

        valuations.sort { lhs, rhs in
            if lhs.netWorthMinor != rhs.netWorthMinor {
                return lhs.netWorthMinor > rhs.netWorthMinor
            }
            return lhs.seat < rhs.seat
        }

        var result: [PlayerStanding] = []
        var previousNetWorthMinor: Int64?
        var currentRank = 0
        for (index, valuation) in valuations.enumerated() {
            if previousNetWorthMinor != valuation.netWorthMinor {
                currentRank = index + 1
            }
            previousNetWorthMinor = valuation.netWorthMinor
            let standing = PlayerStanding(
                player: valuation.player,
                cashBalanceMinor: valuation.player.balanceMinor,
                propertyValueMinor: valuation.propertyValueMinor,
                propertyCount: valuation.propertyCount,
                netWorthMinor: valuation.netWorthMinor,
                rank: currentRank
            )
            result.append(standing)
        }
        return result
    }
}

struct PlayerStanding: Identifiable, Equatable {
    let player: GamePlayer
    let cashBalanceMinor: Int64
    let propertyValueMinor: Int64
    let propertyCount: Int
    let netWorthMinor: Int64
    let rank: Int

    var id: Int64 { player.id }
}

struct NewPlayer {
    let name: String
    let colorHex: String
    let token: String
}

enum BankMovementKind: String, CaseIterable, Identifiable, Hashable {
    case receive = "bank_credit"
    case pay = "bank_debit"

    var id: String { rawValue }
    var label: String { self == .receive ? "Receber do banco" : "Pagar ao banco" }
}

enum GameStoreError: LocalizedError, Equatable {
    case invalidGameName
    case invalidPlayerCount
    case invalidPlayerName
    case invalidAmount
    case samePlayer
    case insufficientFunds
    case propertyUnavailable
    case propertyNotOwned
    case requestUnavailable
    case noActiveGame
    case database(String)

    var errorDescription: String? {
        switch self {
        case .invalidGameName: return "Informe um nome para a partida."
        case .invalidPlayerCount: return "A partida precisa ter de 2 a 6 jogadores."
        case .invalidPlayerName: return "Todos os jogadores precisam de um apelido."
        case .invalidAmount: return "Informe um valor maior que zero."
        case .samePlayer: return "Escolha duas pessoas diferentes para a transferência."
        case .insufficientFunds: return "Saldo insuficiente para concluir esta operação."
        case .propertyUnavailable: return "Este imóvel não está mais disponível."
        case .propertyNotOwned: return "O imóvel não tem um proprietário válido para receber aluguel."
        case .requestUnavailable: return "Esta cobrança já foi paga ou não está disponível."
        case .noActiveGame: return "Crie uma partida antes de registrar operações."
        case .database(let message): return message
        }
    }
}

enum MoneyFormat {
    static func string(_ minor: Int64) -> String {
        let value = Double(minor) / 100
        return "M$ " + value.formatted(.number.locale(Locale(identifier: "pt_BR")).precision(.fractionLength(2)))
    }

    static func minorUnits(from text: String) -> Int64? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")), value > 0 else { return nil }
        var cents = value * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &cents, 0, .plain)
        return NSDecimalNumber(decimal: rounded).int64Value
    }
}
