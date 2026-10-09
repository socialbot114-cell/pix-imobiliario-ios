import SwiftUI

struct StatementView: View {
    @EnvironmentObject private var store: GameStore

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
                                TransactionRow(transaction: transaction, perspectivePlayerID: game.currentPlayer?.id)
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
    }
}
