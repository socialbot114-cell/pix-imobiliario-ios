import SwiftUI

struct GameHistoryView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss

    private var orderedGames: [GameSnapshot] {
        store.savedGames.sorted { lhs, rhs in
            let lhsIsActive = lhs.status == "active"
            let rhsIsActive = rhs.status == "active"
            if lhsIsActive != rhsIsActive { return lhsIsActive }
            return lhs.id > rhs.id
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Suas partidas")
                        .font(.system(.title2, design: .serif, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Text("Partidas locais neste iPhone")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Palette.muted)
                }

                if store.savedGames.isEmpty {
                    EmptySection(title: "Ainda sem partidas", detail: "Quando você criar uma mesa, ela aparecerá aqui para retomar depois.")
                } else {
                    ForEach(orderedGames, id: \.id) { game in
                        gameCard(game)
                    }
                }
            }
            .padding(14)
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
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(game.name)
                        .font(.system(.headline, design: .serif, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(game.status == "active" ? "Em andamento" : "Encerrada")
                        .font(.system(.caption2, design: .rounded, weight: .black))
                        .tracking(0.35)
                        .foregroundStyle(game.status == "active" ? Palette.success : Palette.muted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background((game.status == "active" ? Palette.success : Palette.muted).opacity(0.12), in: Capsule())
                }
                Spacer(minLength: 4)
                if game.id == store.game?.id {
                    Label("Aberta agora", systemImage: "checkmark.circle.fill")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(Palette.forest)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Palette.forest.opacity(0.08), in: Capsule())
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
                VStack(spacing: 8) {
                    detailRow("Conta ativa", value: current.name)
                    detailRow("Saldo", value: MoneyFormat.string(current.balanceMinor), emphasized: true)
                }
                .padding(10)
                .background(Palette.canvas.opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else if let leader = game.standings.first {
                VStack(alignment: .leading, spacing: 6) {
                    Text("MAIOR PATRIMÔNIO")
                        .font(.system(.caption2, design: .rounded, weight: .black))
                        .tracking(0.65)
                        .foregroundStyle(Palette.muted)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(leader.player.name)
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                        Spacer(minLength: 4)
                        Text(MoneyFormat.string(leader.netWorthMinor))
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(Palette.forest)
                            .multilineTextAlignment(.trailing)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.canvas.opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                        .frame(maxWidth: .infinity, minHeight: 38)
                }
                .accessibilityIdentifier("share-game-\(game.id)")
            }
        }
        .padding(14)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 21, style: .continuous).stroke(Palette.line, lineWidth: 1))
    }

    private func detailRow(_ title: String, value: String, emphasized: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(Palette.muted)
            Spacer(minLength: 6)
            Text(value)
                .font(.system(emphasized ? .subheadline : .callout, design: .rounded, weight: emphasized ? .bold : .semibold))
                .foregroundStyle(Palette.forest)
                .multilineTextAlignment(.trailing)
        }
    }

    private func lastActivity(for game: GameSnapshot) -> String {
        guard let timestamp = game.transactions.first?.createdAt,
              let date = ISO8601DateFormatter().date(from: timestamp) else {
            return "Ainda sem movimentações"
        }
        let time = date.formatted(date: .omitted, time: .shortened)
        if Calendar.current.isDateInToday(date) {
            return "Última atividade · Hoje, \(time)"
        }
        if Calendar.current.isDateInYesterday(date) {
            return "Última atividade · Ontem, \(time)"
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
