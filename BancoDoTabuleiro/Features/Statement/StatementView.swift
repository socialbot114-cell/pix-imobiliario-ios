import SwiftUI

struct StatementView: View {
    @EnvironmentObject private var store: GameStore
    @State private var selectedTransaction: GameTransaction?

    var body: some View {
        ZStack {
            Palette.canvas.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Extrato da partida")
                            .font(.system(.largeTitle, design: .serif, weight: .bold))
                            .foregroundStyle(Palette.ink)
                        Text(store.game?.name ?? "Histórico de movimentações")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Palette.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if let game = store.game, !game.transactions.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(game.transactions) { transaction in
                                Button { selectedTransaction = transaction } label: {
                                    TransactionRow(transaction: transaction, perspectivePlayerID: game.currentPlayer?.id)
                                }
                                    .buttonStyle(.plain)
                                    .accessibilityHint("Abrir comprovante da movimentação")
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                            }
                        }
                        .background(Palette.card, in: RoundedRectangle(cornerRadius: 22))
                    } else {
                        EmptySection(title: "Ainda sem movimentações", detail: "Transferências, cobranças e compras aparecerão aqui com data, valor e motivo.")
                    }

                    Text("As movimentações concluídas são mantidas para preservar o histórico da partida.")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(Palette.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 10)
                }
                .padding(18)
            }
        }
        .navigationTitle("Extrato")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedTransaction) { transaction in
            NavigationStack { TransactionReceiptView(transaction: transaction) }
                .presentationDetents([.large])
        }
    }
}

private struct TransactionReceiptView: View {
    @Environment(\.dismiss) private var dismiss
    let transaction: GameTransaction

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Label("Movimentação registrada", systemImage: "checkmark.circle.fill")
                    .font(.title2.bold()).foregroundStyle(Palette.forest)
                Text(MoneyFormat.string(transaction.amountMinor))
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(Palette.ink)
                PremiumCard {
                    VStack(spacing: 16) {
                        LabeledContent("Origem", value: transaction.fromName)
                        LabeledContent("Destino", value: transaction.toName)
                        LabeledContent("Motivo", value: transaction.description)
                        LabeledContent("Referência local", value: "MOV-\(transaction.id)")
                        LabeledContent("Data e hora", value: timestamp)
                    }
                }
                Text("Este comprovante mostra a movimentação original salva no extrato. Saldos atuais podem ter mudado após outras operações.")
                    .font(.subheadline).foregroundStyle(Palette.muted)
                Text("M$ é moeda fictícia. Nenhum pagamento real foi enviado.")
                    .font(.caption).foregroundStyle(Palette.muted)
            }
            .padding(20)
        }
        .background(Palette.canvas.ignoresSafeArea())
        .navigationTitle("Comprovante")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Fechar") { dismiss() }
            }
        }
    }

    private var timestamp: String {
        guard let date = ISO8601DateFormatter().date(from: transaction.createdAt) else { return transaction.createdAt }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
