import SwiftUI

struct GameHistoryView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Suas partidas")
                        .font(.system(.largeTitle, design: .serif, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Text("Partidas locais neste iPhone")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Palette.muted)
                }

                if store.savedGames.isEmpty {
                    EmptySection(title: "Ainda sem partidas", detail: "Quando você criar uma mesa, ela aparecerá aqui para retomar depois.")
                } else {
                    ForEach(store.savedGames) { game in
                        gameCard(game)
                    }
                }
            }
            .padding(18)
        }
        .background(Palette.canvas.ignoresSafeArea())
        .navigationTitle("Partidas")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Fechar") { dismiss() }
                    .foregroundStyle(Palette.forest)
            }
        }
    }

    private func gameCard(_ game: GameSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(game.name)
                        .font(.system(.title3, design: .serif, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Text(game.status == "active" ? "EM ANDAMENTO" : "ENCERRADA")
                        .font(.system(.caption2, design: .rounded, weight: .black))
                        .tracking(0.8)
                        .foregroundStyle(game.status == "active" ? Palette.success : Palette.muted)
                }
                Spacer(minLength: 4)
                if game.id == store.game?.id {
                    Label("Aberta agora", systemImage: "checkmark.circle.fill")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(Palette.forest)
                }
            }

            Rectangle().fill(Palette.line).frame(height: 1)

            HStack(spacing: 12) {
                Label("\(game.players.count) jogadores", systemImage: "person.2.fill")
                Spacer(minLength: 4)
                Text("\(game.transactions.count) movimentações")
            }
            .font(.system(.caption, design: .rounded, weight: .medium))
            .foregroundStyle(Palette.muted)

            if game.status == "active", let current = game.currentPlayer {
                LabeledContent("Conta ativa", value: current.name)
                LabeledContent("Saldo", value: MoneyFormat.string(current.balanceMinor))
            } else if let leader = game.standings.first {
                LabeledContent("Maior patrimônio", value: "\(leader.player.name) · \(MoneyFormat.string(leader.netWorthMinor))")
            }

            Text(lastActivity(for: game))
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Palette.muted)

            Button {
                store.selectGame(id: game.id)
                dismiss()
            } label: {
                Label(game.status == "active" ? "Abrir partida" : "Ver resultado", systemImage: game.status == "active" ? "arrow.uturn.backward" : "chart.bar.fill")
            }
            .buttonStyle(PrimaryActionStyle())
            .accessibilityIdentifier("saved-game-\(game.id)")

            if game.status != "active" {
                ShareLink(item: shareSummary(for: game)) {
                    Label("Compartilhar resultado", systemImage: "square.and.arrow.up")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Palette.forest)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .accessibilityIdentifier("share-game-\(game.id)")
            }
        }
        .padding(16)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 21, style: .continuous).stroke(Palette.line, lineWidth: 1))
    }

    private func lastActivity(for game: GameSnapshot) -> String {
        guard let timestamp = game.transactions.first?.createdAt,
              let date = ISO8601DateFormatter().date(from: timestamp) else {
            return "Ainda sem movimentações"
        }
        return "Última atividade · \(date.formatted(date: .abbreviated, time: .shortened))"
    }

    private func shareSummary(for game: GameSnapshot) -> String {
        let entries = game.standings.map { standing in
            "\(standing.rank)º · \(standing.player.name) · saldo \(MoneyFormat.string(standing.cashBalanceMinor)) · imóveis \(MoneyFormat.string(standing.propertyValueMinor)) · patrimônio \(MoneyFormat.string(standing.netWorthMinor))"
        }
        return "\(game.name) — resultado final\n\n\(entries.joined(separator: "\n"))\n\nPatrimônio = saldo disponível + preço de compra cadastrado dos imóveis. M$ é moeda fictícia; nenhum pagamento real foi realizado."
    }
}
