import Foundation

struct GamePlayer: Identifiable, Equatable {
    let id: Int64
    let name: String
    let colorHex: String
    let token: String
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
    let fromName: String
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
}

struct NewPlayer {
    let name: String
    let colorHex: String
    let token: String
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
