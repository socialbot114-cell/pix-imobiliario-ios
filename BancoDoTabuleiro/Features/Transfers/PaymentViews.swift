import SwiftUI

struct TransferView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var fromPlayerID: Int64 = 0
    @State private var toPlayerID: Int64 = 0
    @State private var amount = ProcessInfo.processInfo.arguments.contains("-screenshot-mode") ? "150" : ""
    @State private var description = ProcessInfo.processInfo.arguments.contains("-screenshot-mode") ? "Aluguel da Rua Verde" : ""

    private var players: [GamePlayer] { store.game?.players ?? [] }

    var body: some View {
        Form {
            Section {
                playerPicker(title: "Quem paga", selection: $fromPlayerID)
                playerPicker(title: "Quem recebe", selection: $toPlayerID)
            } header: {
                Text("Entre jogadores")
            }

            Section {
                HStack {
                    Text("M$").fontWeight(.bold).foregroundStyle(Palette.forest)
                    TextField("0,00", text: $amount)
                        .keyboardType(.decimalPad)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .accessibilityIdentifier("transfer-amount-field")
                }
                TextField("Ex.: Aluguel, empréstimo...", text: $description)
                    .accessibilityIdentifier("transfer-description-field")
            } header: {
                Text("Valor e descrição")
            }

            Section {
                Label("Revise o valor antes de confirmar. A transferência atualiza os dois saldos em conjunto.", systemImage: "lock.fill")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Palette.muted)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.canvas)
        .navigationTitle("PIX Imobiliário")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() }.foregroundStyle(Palette.forest) }
            ToolbarItem(placement: .confirmationAction) {
                Button("Confirmar") { confirmTransfer() }
                    .fontWeight(.bold)
                    .foregroundStyle(Palette.forest)
                    .accessibilityIdentifier("confirm-transfer-button")
            }
        }
        .onAppear { setDefaultPlayers() }
    }

    @ViewBuilder
    private func playerPicker(title: String, selection: Binding<Int64>) -> some View {
        Picker(title, selection: selection) {
            ForEach(players) { player in
                Text(player.name).tag(player.id)
            }
        }
        .pickerStyle(.menu)
    }

    private func setDefaultPlayers() {
        guard players.count > 1 else { return }
        let activeIndex = players.firstIndex(where: { $0.id == store.game?.activePlayerID }) ?? 0
        if fromPlayerID == 0 { fromPlayerID = players[activeIndex].id }
        if toPlayerID == 0 { toPlayerID = players[(activeIndex + 1) % players.count].id }
    }

    private func confirmTransfer() {
        guard let amountMinor = MoneyFormat.minorUnits(from: amount) else {
            store.errorMessage = GameStoreError.invalidAmount.localizedDescription
            return
        }
        store.clearError()
        store.transfer(from: fromPlayerID, to: toPlayerID, amount: amountMinor, description: description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "PIX Imobiliário" : description)
        if store.errorMessage == nil { dismiss() }
    }
}

struct ChargeView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var creatorID: Int64 = 0
    @State private var payerID: Int64 = 0
    @State private var amount = ""
    @State private var description = "Aluguel"

    private var players: [GamePlayer] { store.game?.players ?? [] }

    var body: some View {
        Form {
            Section("Cobrança") {
                Picker("Quem cobra", selection: $creatorID) {
                    ForEach(players) { Text($0.name).tag($0.id) }
                }
                Picker("Quem paga", selection: $payerID) {
                    ForEach(players) { Text($0.name).tag($0.id) }
                }
                HStack {
                    Text("M$").fontWeight(.bold).foregroundStyle(Palette.forest)
                    TextField("Valor", text: $amount).keyboardType(.decimalPad)
                        .accessibilityIdentifier("charge-amount-field")
                }
                TextField("Motivo (ex.: Rua do Ipê)", text: $description)
            }
            Section {
                Label("A cobrança fica pendente. O saldo só muda quando o pagador confirmar o pagamento.", systemImage: "clock.badge.checkmark")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Palette.muted)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.canvas)
        .navigationTitle("Nova cobrança")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() }.foregroundStyle(Palette.forest) }
            ToolbarItem(placement: .confirmationAction) {
                Button("Criar") { createCharge() }.fontWeight(.bold).foregroundStyle(Palette.forest)
                    .accessibilityIdentifier("create-charge-button")
            }
        }
        .onAppear { setDefaultPlayers() }
    }

    private func setDefaultPlayers() {
        guard players.count > 1 else { return }
        let activeIndex = players.firstIndex(where: { $0.id == store.game?.activePlayerID }) ?? 0
        if creatorID == 0 { creatorID = players[activeIndex].id }
        if payerID == 0 { payerID = players[(activeIndex + 1) % players.count].id }
    }

    private func createCharge() {
        guard let amountMinor = MoneyFormat.minorUnits(from: amount) else {
            store.errorMessage = GameStoreError.invalidAmount.localizedDescription
            return
        }
        store.clearError()
        store.createCharge(creator: creatorID, payer: payerID, amount: amountMinor, description: description)
        if store.errorMessage == nil { dismiss() }
    }
}

struct BankOperationView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var kind: BankMovementKind = .receive
    @State private var amount = ""
    @State private var description = ""

    var body: some View {
        Form {
            Section("Operação da partida") {
                Picker("Movimentação", selection: $kind) {
                    ForEach(BankMovementKind.allCases) { movement in
                        Text(movement.label).tag(movement)
                    }
                }
                HStack {
                    Text("M$").fontWeight(.bold).foregroundStyle(Palette.forest)
                    TextField("Valor", text: $amount)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("bank-operation-amount")
                }
                TextField("Motivo (ex.: passou pela casa inicial)", text: $description)
                    .accessibilityIdentifier("bank-operation-description")
            }
            Section {
                Label(kind == .receive ? "O banco creditará a conta do jogador ativo." : "O banco cobrará a conta do jogador ativo; saldo insuficiente será recusado.", systemImage: "building.columns.fill")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Palette.muted)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.canvas)
        .navigationTitle("Movimentação do banco")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() }.foregroundStyle(Palette.forest) }
            ToolbarItem(placement: .confirmationAction) {
                Button("Confirmar") { confirm() }
                    .fontWeight(.bold)
                    .foregroundStyle(Palette.forest)
                    .accessibilityIdentifier("confirm-bank-operation")
            }
        }
    }

    private func confirm() {
        guard let amountMinor = MoneyFormat.minorUnits(from: amount) else {
            store.errorMessage = GameStoreError.invalidAmount.localizedDescription
            return
        }
        let reason = description.trimmingCharacters(in: .whitespacesAndNewlines)
        store.clearError()
        store.bankMovement(
            amount: amountMinor,
            kind: kind,
            description: reason.isEmpty ? kind.label : reason
        )
        if store.errorMessage == nil { dismiss() }
    }
}
