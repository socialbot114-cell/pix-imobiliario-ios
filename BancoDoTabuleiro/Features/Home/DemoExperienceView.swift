import SwiftUI

private struct DemoStanding: Identifiable {
    let rank: Int
    let name: String
    let colorHex: String
    let cashMinor: Int64
    let propertyCount: Int
    let propertyValueMinor: Int64

    var id: String { name }
    var totalMinor: Int64 { cashMinor + propertyValueMinor }
}

struct DemoExperienceView: View {
    @Environment(\.dismiss) private var dismiss
    let onCreateGame: () -> Void

    private let standings = [
        DemoStanding(rank: 1, name: "Bruno", colorHex: "#D9483B", cashMinor: 255_300, propertyCount: 0, propertyValueMinor: 0),
        DemoStanding(rank: 2, name: "Ana", colorHex: "#13845B", cashMinor: 232_700, propertyCount: 1, propertyValueMinor: 22_000),
        DemoStanding(rank: 3, name: "Carla", colorHex: "#536FD8", cashMinor: 245_000, propertyCount: 0, propertyValueMinor: 0),
        DemoStanding(rank: 3, name: "Diego", colorHex: "#9253C7", cashMinor: 245_000, propertyCount: 0, propertyValueMinor: 0)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("DEMONSTRAÇÃO · SOMENTE LEITURA", systemImage: "sparkles")
                        .font(.system(.caption, design: .rounded, weight: .black))
                        .tracking(0.7)
                        .foregroundStyle(Palette.forest)
                        .accessibilityIdentifier("demo-mode-banner")
                    Text("Conheça sua mesa")
                        .font(.system(.title, design: .serif, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Text("Veja saldos, jogadores e movimentações de uma partida.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                demoBalanceCard
                demoPlayersCard
                demoRankingCard
                demoActivityCard

                Label("Esta demonstração usa dados de exemplo e não altera partidas salvas.", systemImage: "lock.shield")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 18)
        }
        .background(Palette.canvas.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button(action: onCreateGame) {
                Label("Criar minha partida", systemImage: "sparkles")
            }
            .buttonStyle(PrimaryActionStyle())
            .accessibilityIdentifier("create-game-from-demo")
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(Palette.canvas)
        }
        .navigationTitle("Demonstração")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Fechar") { dismiss() }
                    .foregroundStyle(Palette.forest)
            }
        }
    }

    private var demoBalanceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("SALDO DO JOGADOR ATIVO", systemImage: "sparkle")
                .font(.system(.caption2, design: .rounded, weight: .black))
                .foregroundStyle(Palette.goldLight)
            Text("M$ 2.327,00")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            Text("Ana · 4 jogadores · valores fictícios")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(Palette.card.opacity(0.82))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(LinearGradient(colors: [Palette.forest, Palette.ink], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Palette.gold.opacity(0.6), lineWidth: 1))
    }

    private var demoPlayersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Jogadores")
            HStack(spacing: 9) {
                ForEach(standings) { standing in
                    VStack(spacing: 5) {
                        Circle().fill(Color(hexString: standing.colorHex)).frame(width: 38, height: 38)
                            .overlay(Image(systemName: demoToken(for: standing.name)).accessibilityHidden(true).foregroundStyle(.white))
                        Text(standing.name)
                            .font(.system(.caption2, design: .rounded, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 21))
    }

    private var demoRankingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Ranking de exemplo")
            ForEach(standings) { standing in
                HStack(spacing: 9) {
                    Text("\(standing.rank)º")
                        .font(.system(.caption, design: .rounded, weight: .black))
                        .foregroundStyle(Palette.forest)
                        .frame(width: 34, height: 34)
                        .background(Palette.gold.opacity(0.16), in: RoundedRectangle(cornerRadius: 11))
                    Text(standing.name)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                    Spacer()
                    Text(MoneyFormat.string(standing.totalMinor))
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(Palette.forest)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("demo-ranking-\(standing.name.lowercased())")
            }
            Text("Patrimônio = saldo + preço cadastrado dos imóveis.")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Palette.muted)
        }
        .padding(16)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 21))
    }

    private var demoActivityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Atividade recente")
            Label("Renda pela casa inicial · +M$ 200,00", systemImage: "arrow.down.left.circle.fill")
            Label("Aluguel: Rua do Ipê · +M$ 22,00", systemImage: "key.fill")
            Label("PIX · acordo de mesa · −M$ 125,00", systemImage: "arrow.left.arrow.right")
        }
        .font(.system(.caption, design: .rounded, weight: .medium))
        .foregroundStyle(Palette.ink)
        .padding(16)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 21))
    }

    private func demoToken(for name: String) -> String {
        switch name {
        case "Bruno": return "building.2.fill"
        case "Carla": return "star.fill"
        case "Diego": return "house.fill"
        default: return "figure.stand"
        }
    }
}
