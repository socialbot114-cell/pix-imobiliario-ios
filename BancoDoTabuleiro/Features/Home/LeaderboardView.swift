import SwiftUI

struct LeaderboardView: View {
    @Environment(\.dismiss) private var dismiss
    let game: GameSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(game.status == "active" ? "Ranking da partida" : "Resultado final")
                        .font(.system(.largeTitle, design: .serif, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .accessibilityIdentifier("leaderboard-title")
                    Text(game.name)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Palette.muted)
                }

                PremiumCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Como o ranking é calculado", systemImage: "chart.bar.xaxis")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(Palette.forest)
                        Text("Patrimônio = saldo disponível + preço de compra dos imóveis. O aluguel futuro não entra nesta conta.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(spacing: 11) {
                    ForEach(game.standings) { standing in
                        PlayerStandingRow(standing: standing)
                    }
                }
            }
            .padding(18)
        }
        .background(Palette.canvas.ignoresSafeArea())
        .navigationTitle("Ranking")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Fechar") { dismiss() }
                    .foregroundStyle(Palette.forest)
            }
        }
    }
}

struct PlayerStandingRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let standing: PlayerStanding
    var identifierPrefix = "leaderboard-row"
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            if compact {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 11) {
                            rankBadge
                            playerIdentity
                        }
                        wealthSummary
                    }
                } else {
                    HStack(spacing: 11) {
                        rankBadge
                        playerIdentity
                        Spacer(minLength: 4)
                        wealthSummary
                    }
                }
            } else {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 11) {
                            rankBadge
                            playerIdentity
                        }
                        wealthSummary
                    }
                } else {
                    HStack(spacing: 11) {
                        rankBadge
                        playerIdentity
                        Spacer(minLength: 4)
                        wealthSummary
                    }
                }

                Rectangle().fill(Palette.line).frame(height: 1)

                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 9) {
                        metric(label: "Saldo disponível", value: standing.cashBalanceMinor, icon: "banknote.fill")
                        metric(label: "Valor dos imóveis", value: standing.propertyValueMinor, icon: "house.fill")
                    }
                } else {
                    HStack(alignment: .top, spacing: 14) {
                        metric(label: "Saldo", value: standing.cashBalanceMinor, icon: "banknote.fill")
                        Spacer(minLength: 4)
                        metric(label: "Imóveis · \(standing.propertyCount)", value: standing.propertyValueMinor, icon: "house.fill")
                    }
                }
            }
        }
        .padding(15)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 19, style: .continuous).stroke(Palette.line, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("\(identifierPrefix)-\(standing.id)")
    }

    private var rankBadge: some View {
        Text("\(standing.rank)º")
            .font(.system(.subheadline, design: .rounded, weight: .black))
            .foregroundStyle(standing.rank == 1 ? Palette.forest : Palette.muted)
            .frame(minWidth: 42, minHeight: 42)
            .background(standing.rank == 1 ? Palette.gold.opacity(0.22) : Palette.canvas, in: RoundedRectangle(cornerRadius: 14))
    }

    private var playerIdentity: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(Color(hexString: standing.player.colorHex))
                .frame(width: 14, height: 14)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(standing.player.name)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Text("\(standing.propertyCount) \(standing.propertyCount == 1 ? "imóvel" : "imóveis")")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Palette.muted)
            }
        }
    }

    private var wealthSummary: some View {
        VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 3) {
            Text("PATRIMÔNIO")
                .font(.system(.caption2, design: .rounded, weight: .black))
                .tracking(0.6)
                .foregroundStyle(Palette.muted)
            Text(MoneyFormat.string(standing.netWorthMinor))
                .font(.system(.subheadline, design: .rounded, weight: .black))
                .foregroundStyle(Palette.forest)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func metric(label: String, value: Int64, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(label, systemImage: icon)
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundStyle(Palette.muted)
            Text(MoneyFormat.string(value))
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
