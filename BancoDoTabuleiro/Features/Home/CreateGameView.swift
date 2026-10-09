import SwiftUI

private enum GameSetupStep: Equatable {
    case game
    case players
}

private struct PlayerDraft: Identifiable {
    let id: UUID
    var name: String
    var colorHex: String
    var token: String

    init(id: UUID = UUID(), name: String, colorHex: String, token: String) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.token = token
    }
}

private struct PlayerColorChoice: Identifiable {
    let name: String
    let hex: String
    var id: String { hex }
}

private struct PlayerTokenChoice: Identifiable {
    let id: String
    let name: String
    let symbol: String
}

struct CreateGameView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: UUID?
    @State private var step: GameSetupStep
    @State private var gameName = "Noite de Jogo"
    @State private var startingBalance = "2.450"
    @State private var players: [PlayerDraft]
    @State private var isCreating = false

    fileprivate static let tokenChoices = [
        PlayerTokenChoice(id: "peao", name: "Peão", symbol: "pawn.fill"),
        PlayerTokenChoice(id: "casa", name: "Casa", symbol: "house.fill"),
        PlayerTokenChoice(id: "torre", name: "Torre", symbol: "building.2.fill"),
        PlayerTokenChoice(id: "estrela", name: "Estrela", symbol: "star.fill"),
        PlayerTokenChoice(id: "carro", name: "Carro", symbol: "car.fill"),
        PlayerTokenChoice(id: "coroa", name: "Coroa", symbol: "crown.fill")
    ]

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let isPlayerSetupCapture = arguments.contains("-capture-player-setup")
        let isVisualReview = arguments.contains("-visual-review-data")
        let names = isVisualReview ? ["Ana", "Bruno", "Carla"] : ["", ""]
        _step = State(initialValue: isPlayerSetupCapture ? .players : .game)
        _players = State(initialValue: names.enumerated().map { index, name in
            PlayerDraft(
                name: name,
                colorHex: Palette.playerColors[index % Palette.playerColors.count],
                token: Self.tokenChoices[index % Self.tokenChoices.count].id
            )
        })
    }

    var body: some View {
        VStack(spacing: 0) {
            progressHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if step == .game {
                        gameDetailsStep
                    } else {
                        playersStep
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)

            stepActions
        }
        .background(Palette.canvas.ignoresSafeArea())
        .navigationTitle("Nova partida")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
                    .foregroundStyle(Palette.forest)
            }
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("NOVA PARTIDA")
                    .font(.system(.caption, design: .rounded, weight: .black))
                    .tracking(1.2)
                    .foregroundStyle(Palette.forest)
                Spacer()
                Text(step == .game ? "1 DE 2" : "2 DE 2")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(Palette.muted)
            }
            HStack(spacing: 7) {
                Capsule().fill(Palette.forest).frame(height: 5)
                Capsule().fill(step == .players ? Palette.forest : Palette.line).frame(height: 5)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("game-setup-progress")
    }

    private var gameDetailsStep: some View {
        VStack(alignment: .leading, spacing: 19) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Prepare a mesa")
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Text("Defina os detalhes básicos. Você poderá ajustar os jogadores antes de começar.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PremiumCard {
                VStack(alignment: .leading, spacing: 17) {
                    setupFieldTitle("Nome da partida", subtitle: "Um nome fácil de reconhecer no histórico.")
                    TextField("Ex.: Noite de Jogo", text: $gameName)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.next)
                        .accessibilityLabel("Nome da partida")
                        .accessibilityIdentifier("game-name-field")

                    Rectangle().fill(Palette.line).frame(height: 1)

                    setupFieldTitle("Saldo inicial", subtitle: "Cada jogador começa com este valor fictício.")
                    HStack(spacing: 10) {
                        Text("M$")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(Palette.forest)
                        TextField("2.450", text: $startingBalance)
                            .keyboardType(.decimalPad)
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .accessibilityLabel("Saldo inicial por pessoa")
                            .accessibilityIdentifier("starting-balance-field")
                        Spacer(minLength: 0)
                        Text("por pessoa")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundStyle(Palette.muted)
                    }
                }
                .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 11) {
                Label("Funciona offline e os dados ficam neste iPhone.", systemImage: "iphone")
                Label("M$ é fictício; nenhum dinheiro real é movimentado.", systemImage: "lock.shield")
            }
            .font(.system(.subheadline, design: .rounded, weight: .medium))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 4)

            if let setupMessage {
                validationMessage(setupMessage)
            }
        }
    }

    private var playersStep: some View {
        VStack(alignment: .leading, spacing: 17) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Quem vai jogar?")
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Text("Adicione de 2 a 6 pessoas. A primeira da lista começa a partida.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Label("Jogadores", systemImage: "person.2.fill")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text("\(players.count) de 6")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(Palette.forest)
                    .accessibilityIdentifier("player-count")
            }

            ForEach($players) { playerBinding in
                let playerID = playerBinding.wrappedValue.id
                let index = players.firstIndex(where: { $0.id == playerID }) ?? 0
                PlayerSetupCard(
                    player: playerBinding,
                    number: index + 1,
                    canRemove: players.count > 2,
                    focus: $focusedField,
                    onRemove: { removePlayer(id: playerID) }
                )
            }

            if players.count < 6 {
                Button(action: addPlayer) {
                    Label("Adicionar jogador", systemImage: "plus.circle.fill")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(Palette.forest)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Palette.card, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.line, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
                }
                .accessibilityIdentifier("add-player-button")
            }

            if let playerMessage {
                validationMessage(playerMessage)
            }

            PremiumCard(padding: 15) {
                HStack(spacing: 12) {
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Palette.gold)
                        .frame(width: 42, height: 42)
                        .background(Palette.gold.opacity(0.14), in: RoundedRectangle(cornerRadius: 13))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Distribuição inicial")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(Palette.ink)
                        Text("\(MoneyFormat.string(startingBalanceMinor)) para cada pessoa · registrado no extrato")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Text("Todos jogam no mesmo iPhone. O código da partida não conecta outros aparelhos.")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    private var stepActions: some View {
        VStack(spacing: 9) {
            if step == .players {
                Button("Voltar à partida") {
                    focusedField = nil
                    withAnimation(.easeInOut(duration: 0.2)) { step = .game }
                }
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Palette.forest)
                .accessibilityIdentifier("back-to-game-details")
            }

            Button {
                if step == .game {
                    advanceToPlayers()
                } else {
                    createGame()
                }
            } label: {
                HStack(spacing: 9) {
                    Text(step == .game ? "Continuar" : "Criar partida")
                    Image(systemName: step == .game ? "arrow.right" : "sparkles")
                }
            }
            .buttonStyle(PrimaryActionStyle())
            .disabled(isCreating || (step == .game ? !canContinue : !canCreate))
            .accessibilityIdentifier(step == .game ? "continue-to-players" : "confirm-create-game")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(Palette.canvas.shadow(color: Palette.ink.opacity(0.08), radius: 12, x: 0, y: -5))
    }

    private var canContinue: Bool {
        !gameName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && startingBalanceMinor > 0
    }

    private var canCreate: Bool {
        canContinue && playerMessage == nil && (2...6).contains(players.count)
    }

    private var startingBalanceMinor: Int64 {
        MoneyFormat.minorUnits(from: startingBalance) ?? 0
    }

    private var setupMessage: String? {
        if gameName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Informe um nome para a partida."
        }
        if startingBalanceMinor <= 0 {
            return "Informe um saldo inicial maior que zero."
        }
        return nil
    }

    private var playerMessage: String? {
        let names = players.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
        if names.contains(where: { $0.isEmpty }) {
            return "Dê um nome a cada jogador para continuar."
        }
        let normalizedNames = names.map {
            $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        }
        if Set(normalizedNames).count != normalizedNames.count {
            return "Cada pessoa precisa ter um nome diferente."
        }
        return nil
    }

    @ViewBuilder
    private func setupFieldTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(Palette.ink)
            Text(subtitle)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Palette.muted)
        }
    }

    private func validationMessage(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.system(.caption, design: .rounded, weight: .semibold))
            .foregroundStyle(Palette.burgundy)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("setup-validation-message")
    }

    private func advanceToPlayers() {
        guard canContinue else { return }
        focusedField = nil
        withAnimation(.easeInOut(duration: 0.2)) { step = .players }
    }

    private func addPlayer() {
        guard players.count < 6 else { return }
        let index = players.count
        players.append(PlayerDraft(
            name: "",
            colorHex: Palette.playerColors[index % Palette.playerColors.count],
            token: Self.tokenChoices[index % Self.tokenChoices.count].id
        ))
    }

    private func removePlayer(id: UUID) {
        guard players.count > 2 else { return }
        players.removeAll { $0.id == id }
    }

    private func createGame() {
        guard canCreate else { return }
        let newPlayers = players.map { player in
            NewPlayer(
                name: player.name.trimmingCharacters(in: .whitespacesAndNewlines),
                colorHex: player.colorHex,
                token: player.token
            )
        }
        isCreating = true
        store.clearError()
        store.createGame(
            name: gameName.trimmingCharacters(in: .whitespacesAndNewlines),
            startingBalanceMinor: startingBalanceMinor,
            players: newPlayers
        )
        isCreating = false
        if store.game != nil && store.errorMessage == nil { dismiss() }
    }
}

private struct PlayerSetupCard: View {
    @Binding var player: PlayerDraft
    let number: Int
    let canRemove: Bool
    let focus: FocusState<UUID?>.Binding
    let onRemove: () -> Void

    private let colors = [
        PlayerColorChoice(name: "Verde", hex: "#13845B"),
        PlayerColorChoice(name: "Coral", hex: "#D9483B"),
        PlayerColorChoice(name: "Azul", hex: "#536FD8"),
        PlayerColorChoice(name: "Roxo", hex: "#9253C7"),
        PlayerColorChoice(name: "Âmbar", hex: "#E39224"),
        PlayerColorChoice(name: "Turquesa", hex: "#1689A6")
    ]

    private var selectedToken: PlayerTokenChoice {
        CreateGameView.tokenChoices.first(where: { $0.id == player.token }) ?? CreateGameView.tokenChoices[0]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 11) {
                ZStack {
                    Circle().fill(Color(hexString: player.colorHex))
                    Image(systemName: selectedToken.symbol)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("JOGADOR \(number)")
                        .font(.system(.caption2, design: .rounded, weight: .black))
                        .tracking(0.9)
                        .foregroundStyle(Palette.muted)
                    TextField("Nome do jogador \(number)", text: $player.name)
                        .textContentType(.nickname)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused(focus, equals: player.id)
                        .accessibilityIdentifier("player-name-\(number)")
                }

                if canRemove {
                    Button(role: .destructive, action: onRemove) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 21))
                            .foregroundStyle(Palette.burgundy)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Remover jogador \(number)")
                    .accessibilityIdentifier("remove-player-\(number)")
                }
            }

            Rectangle().fill(Palette.line).frame(height: 1)

            HStack(alignment: .center, spacing: 5) {
                Text("COR")
                    .font(.system(.caption2, design: .rounded, weight: .black))
                    .tracking(0.7)
                    .foregroundStyle(Palette.muted)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 3) {
                        ForEach(colors) { choice in
                            let index = colors.firstIndex(where: { $0.id == choice.id }) ?? 0
                            Button {
                                player.colorHex = choice.hex
                            } label: {
                                Circle()
                                    .fill(Color(hexString: choice.hex))
                                    .frame(width: 23, height: 23)
                                    .overlay {
                                        if player.colorHex == choice.hex {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 10, weight: .black))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .frame(width: 40, height: 44)
                                    .background(player.colorHex == choice.hex ? Palette.line.opacity(0.7) : .clear, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Cor \(choice.name) para jogador \(number)")
                            .accessibilityIdentifier("player-color-\(number)-\(index + 1)")
                            .accessibilityAddTraits(player.colorHex == choice.hex ? .isSelected : [])
                        }
                    }
                }
            }

            Menu {
                ForEach(CreateGameView.tokenChoices) { choice in
                    Button {
                        player.token = choice.id
                    } label: {
                        Label(choice.name, systemImage: choice.symbol)
                    }
                }
            } label: {
                Label("Peça: \(selectedToken.name)", systemImage: selectedToken.symbol)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(Palette.forest)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 42)
                    .background(Palette.canvas, in: RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityLabel("Peça do jogador \(number): \(selectedToken.name)")
            .accessibilityIdentifier("player-token-\(number)")
        }
        .padding(14)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Palette.line, lineWidth: 1))
    }
}
