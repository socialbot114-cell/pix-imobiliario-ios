import SwiftUI

private struct TransferReceiptDetails {
    let fromName: String
    let toName: String
    let amountMinor: Int64
    let description: String
    let reference: String
    let timestamp: String
    let fromBalanceMinor: Int64
    let toBalanceMinor: Int64
}

struct TransferView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var fromPlayerID: Int64 = 0
    @State private var toPlayerID: Int64 = 0
    @State private var amount = ProcessInfo.processInfo.arguments.contains("-screenshot-mode") ? "150" : ""
    @State private var description = ProcessInfo.processInfo.arguments.contains("-screenshot-mode") ? "Aluguel da Rua Verde" : ""
    @State private var isProcessing = ProcessInfo.processInfo.arguments.contains("-capture-transfer-processing")
    @State private var receipt: TransferReceiptDetails?
    @State private var isReviewing = false
    @State private var validationError: String?

    private var players: [GamePlayer] { store.game?.players ?? [] }

    var body: some View {
        Group {
            if let receipt {
                receiptView(receipt)
            } else if isReviewing {
                reviewView
            } else {
                transferForm
            }
        }
        .background(Palette.canvas)
        .navigationTitle(receipt == nil ? "PIX Imobiliário" : "Comprovante")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if receipt == nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Palette.forest)
                        .disabled(isProcessing)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        if isReviewing { confirmTransfer() } else { reviewTransfer() }
                    } label: {
                        if isProcessing {
                            ProgressView().tint(Palette.forest)
                        } else {
                            Text(isReviewing ? "Confirmar" : "Revisar")
                        }
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(Palette.forest)
                    .disabled(isProcessing)
                    .accessibilityIdentifier("confirm-transfer-button")
                }
            } else {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fechar") { dismiss() }
                        .foregroundStyle(Palette.forest)
                }
            }
        }
        .overlay {
            if isProcessing && receipt == nil {
                ZStack {
                    Color.black.opacity(0.28).ignoresSafeArea()
                    VStack(spacing: 13) {
                        ProgressView().tint(Palette.forest).scaleEffect(1.2)
                        Text("Processando PIX local…")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(Palette.ink)
                        Text("Salvando a transferência no extrato desta partida.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Palette.muted)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                    .frame(maxWidth: 300)
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("transfer-processing-state")
                }
                .transition(.opacity)
            }
        }
        .interactiveDismissDisabled(isProcessing)
        .onAppear {
            setDefaultPlayers()
            if ProcessInfo.processInfo.arguments.contains("-capture-transfer-receipt") {
                confirmTransfer()
            }
        }
    }

    private var transferForm: some View {
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
            if let validationError {
                Section {
                    Text(validationError)
                        .foregroundStyle(Palette.danger)
                        .accessibilityIdentifier("transfer-validation-error")
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var reviewView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Revise seu PIX")
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Text(MoneyFormat.string(MoneyFormat.minorUnits(from: amount) ?? 0))
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(Palette.forest)
                PremiumCard {
                    VStack(spacing: 14) {
                        reviewParticipant(id: fromPlayerID, role: "Pagador")
                        reviewParticipant(id: toPlayerID, role: "Recebedor")
                        LabeledContent("Quem paga", value: players.first { $0.id == fromPlayerID }?.name ?? "—")
                        LabeledContent("Quem recebe", value: players.first { $0.id == toPlayerID }?.name ?? "—")
                        LabeledContent("Motivo", value: description.isEmpty ? "PIX Imobiliário" : description)
                        Divider()
                        LabeledContent("Saldo atual", value: MoneyFormat.string(players.first { $0.id == fromPlayerID }?.balanceMinor ?? 0))
                        LabeledContent("Saldo após o PIX", value: MoneyFormat.string((players.first { $0.id == fromPlayerID }?.balanceMinor ?? 0) - (MoneyFormat.minorUnits(from: amount) ?? 0)))
                    }
                }
                if let validationError {
                    Text(validationError).foregroundStyle(Palette.danger)
                        .accessibilityIdentifier("transfer-validation-error")
                }
                Button("Editar transferência") { isReviewing = false }
                    .foregroundStyle(Palette.forest)
                    .accessibilityIdentifier("edit-transfer")
                Text("Moeda fictícia. A operação será registrada somente nesta partida.")
                    .font(.caption).foregroundStyle(Palette.muted)
            }
            .padding(20)
        }
    }

    private func reviewTransfer() {
        guard validateTransfer() else { return }
        isReviewing = true
    }

    private func reviewParticipant(id: Int64, role: String) -> some View {
        let player = players.first { $0.id == id }
        return HStack(spacing: 12) {
            Image(systemName: "person.fill")
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color(hexString: player?.colorHex ?? "#13845B"), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(role).font(.caption).foregroundStyle(Palette.muted)
                Text(player?.name ?? "—").font(.headline).foregroundStyle(Palette.ink)
            }
            Spacer()
        }
    }

    private func validateTransfer() -> Bool {
        validationError = nil
        guard let value = MoneyFormat.minorUnits(from: amount) else {
            validationError = GameStoreError.invalidAmount.localizedDescription
            return false
        }
        guard fromPlayerID != toPlayerID else {
            validationError = GameStoreError.samePlayer.localizedDescription
            return false
        }
        guard let payer = players.first(where: { $0.id == fromPlayerID }), payer.balanceMinor >= value else {
            validationError = GameStoreError.insufficientFunds.localizedDescription
            return false
        }
        return true
    }

    private func receiptView(_ receipt: TransferReceiptDetails) -> some View {
        ScrollView {
            VStack(spacing: 17) {
                ZStack {
                    Circle().fill(Palette.success.opacity(0.12)).frame(width: 78, height: 78)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 46, weight: .medium))
                        .foregroundStyle(Palette.success)
                }
                .padding(.top, 14)

                VStack(spacing: 5) {
                    Text("Transferência concluída")
                        .font(.system(.title2, design: .serif, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .accessibilityIdentifier("transfer-receipt-title")
                    Text(MoneyFormat.string(receipt.amountMinor))
                        .font(.system(.largeTitle, design: .rounded, weight: .black))
                        .foregroundStyle(Palette.forest)
                        .accessibilityIdentifier("transfer-receipt-amount")
                }

                PremiumCard(padding: 17) {
                    VStack(spacing: 13) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("PAGADOR").font(.system(.caption2, design: .rounded, weight: .black)).foregroundStyle(Palette.muted)
                                Text(receipt.fromName).font(.system(.headline, design: .rounded, weight: .bold)).foregroundStyle(Palette.ink)
                            }
                            Spacer()
                            Image(systemName: "arrow.right").foregroundStyle(Palette.gold)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("RECEBEDOR").font(.system(.caption2, design: .rounded, weight: .black)).foregroundStyle(Palette.muted)
                                Text(receipt.toName).font(.system(.headline, design: .rounded, weight: .bold)).foregroundStyle(Palette.ink)
                            }
                        }

                        Rectangle().fill(Palette.line).frame(height: 1)

                        LabeledContent("Motivo", value: receipt.description)
                        LabeledContent("Referência local", value: receipt.reference)
                        LabeledContent("Data e hora", value: receipt.timestamp)
                    }
                }

                HStack(spacing: 12) {
                    balanceResult(name: receipt.fromName, amount: receipt.fromBalanceMinor, icon: "arrow.up.right")
                    balanceResult(name: receipt.toName, amount: receipt.toBalanceMinor, icon: "arrow.down.left")
                }

                Label("Registrado somente no extrato desta partida neste iPhone. Nenhum PIX oficial foi enviado.", systemImage: "iphone")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("transfer-receipt-local-state")

                Button("Voltar ao painel") { dismiss() }
                    .buttonStyle(PrimaryActionStyle())
                    .accessibilityIdentifier("transfer-receipt-close")
            }
            .padding(20)
        }
        .background(Palette.canvas.ignoresSafeArea())
    }

    private func balanceResult(name: String, amount: Int64, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(name, systemImage: icon)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(Palette.muted)
                .lineLimit(1)
            Text(MoneyFormat.string(amount))
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 16))
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
        guard !isProcessing, receipt == nil else { return }
        guard validateTransfer() else { return }
        guard let amountMinor = MoneyFormat.minorUnits(from: amount) else {
            store.errorMessage = GameStoreError.invalidAmount.localizedDescription
            return
        }
        guard let game = store.game,
              let payer = game.players.first(where: { $0.id == fromPlayerID }),
              let receiver = game.players.first(where: { $0.id == toPlayerID }) else {
            store.errorMessage = GameStoreError.noActiveGame.localizedDescription
            return
        }
        let memo = description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "PIX Imobiliário" : description.trimmingCharacters(in: .whitespacesAndNewlines)
        let existingTransactionIDs = Set(game.transactions.map(\.id))
        store.clearError()
        isProcessing = true
        Task { @MainActor in
            await Task.yield()
            store.transfer(from: fromPlayerID, to: toPlayerID, amount: amountMinor, description: memo)
            guard store.errorMessage == nil,
                  let updatedGame = store.game,
                  let updatedPayer = updatedGame.players.first(where: { $0.id == fromPlayerID }),
                  let updatedReceiver = updatedGame.players.first(where: { $0.id == toPlayerID }) else {
                isProcessing = false
                return
            }
            let transaction = updatedGame.transactions.first {
                !existingTransactionIDs.contains($0.id)
                    && $0.kind == "transfer"
                    && $0.fromPlayerID == fromPlayerID
                    && $0.toPlayerID == toPlayerID
                    && $0.amountMinor == amountMinor
            }
            let transactionDate = transaction.flatMap { ISO8601DateFormatter().date(from: $0.createdAt) } ?? Date.now
            receipt = TransferReceiptDetails(
                fromName: updatedPayer.name,
                toName: updatedReceiver.name,
                amountMinor: amountMinor,
                description: memo,
                reference: transaction.map { "PIX-\($0.id)" } ?? "PIX local",
                timestamp: transactionDate.formatted(date: .abbreviated, time: .shortened),
                fromBalanceMinor: updatedPayer.balanceMinor,
                toBalanceMinor: updatedReceiver.balanceMinor
            )
            isProcessing = false
        }
    }
}

struct ChargeView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var creatorID: Int64 = 0
    @State private var payerID: Int64 = 0
    @State private var amount = ProcessInfo.processInfo.arguments.contains("-screenshot-mode") ? "350" : ""
    @State private var description = ProcessInfo.processInfo.arguments.contains("-screenshot-mode") ? "Aluguel da Rua Verde" : "Aluguel"

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
    @State private var amount = ProcessInfo.processInfo.arguments.contains("-screenshot-mode") ? "200" : ""
    @State private var description = ProcessInfo.processInfo.arguments.contains("-screenshot-mode") ? "Renda pela casa inicial" : ""

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
