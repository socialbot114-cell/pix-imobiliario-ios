import SwiftUI

struct CreateGameView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var gameName = "Noite de Jogo"
    @State private var startingBalance = "2.450"
    @State private var playerNames = ["Ana", "Bruno"]
    @State private var isCreating = false

    var body: some View {
        Form {
            Section {
                TextField("Ex.: Noite de Jogo", text: $gameName)
                    .accessibilityIdentifier("game-name-field")
                HStack {
                    Text("M$")
                        .foregroundStyle(Palette.forest)
                        .fontWeight(.bold)
                    TextField("Saldo inicial", text: $startingBalance)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("starting-balance-field")
                }
            } header: {
                Text("A partida")
            } footer: {
                Text("O saldo é fictício e pode ser configurado para as regras do seu grupo.")
            }

            Section {
                ForEach(playerNames.indices, id: \.self) { index in
                    HStack(spacing: 11) {
                        Circle()
                            .fill(Color(hexString: Palette.playerColors[index % Palette.playerColors.count]))
                            .frame(width: 28, height: 28)
                            .overlay(Image(systemName: index == 0 ? "pawn.fill" : "house.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(.white))
                        TextField("Apelido do jogador", text: $playerNames[index])
                            .accessibilityIdentifier("player-name-\(index)")
                        if playerNames.count > 2 {
                            Button(role: .destructive) { playerNames.remove(at: index) } label: {
                                Image(systemName: "minus.circle.fill").foregroundStyle(Palette.burgundy)
                            }
                            .accessibilityLabel("Remover jogador \(index + 1)")
                        }
                    }
                }
                if playerNames.count < 6 {
                    Button {
                        playerNames.append("Jogador \(playerNames.count + 1)")
                    } label: {
                        Label("Adicionar jogador", systemImage: "plus.circle.fill")
                            .foregroundStyle(Palette.forest)
                    }
                }
            } header: {
                Text("Jogadores · \(playerNames.count) de 6")
            } footer: {
                Text("Todos jogam no mesmo iPhone. O código local identifica a partida, mas não conecta outros aparelhos.")
            }

            Section {
                HStack {
                    Image(systemName: "building.columns.fill").foregroundStyle(Palette.gold)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Banco do Tabuleiro")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(Palette.ink)
                        Text("Distribuição inicial registrada no extrato")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(Palette.muted)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.canvas)
        .navigationTitle("Nova partida")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
                    .foregroundStyle(Palette.forest)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Criar") { createGame() }
                    .fontWeight(.bold)
                    .foregroundStyle(Palette.forest)
                    .disabled(isCreating || playerNames.count < 2)
                    .accessibilityIdentifier("confirm-create-game")
            }
        }
    }

    private func createGame() {
        guard let amount = MoneyFormat.minorUnits(from: startingBalance) else {
            store.errorMessage = GameStoreError.invalidAmount.localizedDescription
            return
        }
        isCreating = true
        let players = playerNames.enumerated().map { index, name in
            NewPlayer(name: name, colorHex: Palette.playerColors[index % Palette.playerColors.count], token: ["peao", "casa", "torre", "estrela", "carro", "coroa"][index])
        }
        store.createGame(name: gameName, startingBalanceMinor: amount, players: players)
        isCreating = false
        if store.game != nil && store.errorMessage == nil { dismiss() }
    }
}
