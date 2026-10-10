import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: GameStore
    @State private var selectedTab: Int

    init() {
        let args = ProcessInfo.processInfo.arguments
        let tab = args.contains("-capture-tab-board") ? 1
            : args.contains("-capture-tab-properties") ? 2
            : args.contains("-capture-tab-statement") ? 3
            : 0
        _selectedTab = State(initialValue: tab)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { HomeView(selectedTab: $selectedTab) }
                .tabItem { Label("Início", systemImage: "house.fill") }
                .tag(0)
            NavigationStack { BoardView() }
                .tabItem { Label("Tabuleiro", systemImage: "square.grid.3x3.fill") }
                .tag(1)
            NavigationStack { PropertyView() }
                .tabItem { Label("Imóveis", systemImage: "building.2.fill") }
                .tag(2)
            NavigationStack { StatementView() }
                .tabItem { Label("Extrato", systemImage: "list.bullet.rectangle") }
                .tag(3)
        }
        .tint(Palette.forest)
        .background(Palette.canvas.ignoresSafeArea())
        .alert("Banco do Tabuleiro", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.clearError() } }
        )) {
            Button("Entendi", role: .cancel) { store.clearError() }
        } message: {
            Text(store.errorMessage ?? "Ocorreu um erro inesperado.")
        }
    }
}

private enum HomeSheet: String, Identifiable {
    case createGame, transfer, bank, charge, privacy, leaderboard, demoAccess
    var id: String { rawValue }
}

struct HomeView: View {
    @EnvironmentObject private var store: GameStore
    @Binding var selectedTab: Int
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var balanceFontSize: CGFloat = 34
    @State private var sheet: HomeSheet?
    @State private var showFinishConfirmation = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        ZStack {
            Palette.canvas.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    topBar
                    if let game = store.game {
                        gameDashboard(game)
                    } else {
                        welcomeCard
                    }
                    footer
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $sheet) { selected in
            NavigationStack {
                switch selected {
                case .createGame: CreateGameView()
                case .transfer: TransferView()
                case .bank: BankOperationView()
                case .charge: ChargeView()
                case .privacy: PrivacyAndDataView()
                case .leaderboard:
                    if let game = store.game {
                        LeaderboardView(game: game)
                    } else {
                        EmptySection(title: "Ranking", detail: "Crie uma partida para ver a classificação.")
                    }
                case .demoAccess:
                    DemoAccessView { sheet = .createGame }
                }
            }
            .presentationDetents(selected == .createGame || selected == .transfer || selected == .privacy || selected == .leaderboard || selected == .demoAccess ? [.large] : [.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog("Encerrar esta partida?", isPresented: $showFinishConfirmation, titleVisibility: .visible) {
            Button("Encerrar partida", role: .destructive) { store.finishGame() }
            Button("Continuar jogando", role: .cancel) { }
        } message: {
            Text("O histórico e o resumo continuarão salvos neste iPhone.")
        }
        .confirmationDialog("Apagar todas as partidas salvas?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Apagar dados locais", role: .destructive) { store.deleteAllGames() }
                .accessibilityIdentifier("confirm-delete-local-data")
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Esta ação remove partidas, saldos, imóveis e extratos deste iPhone. Ela não pode ser desfeita.")
        }
        .onAppear {
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-capture-transfer")
                || arguments.contains("-capture-transfer-review")
                || arguments.contains("-capture-transfer-processing")
                || arguments.contains("-capture-transfer-receipt") {
                sheet = .transfer
            } else if arguments.contains("-capture-bank") {
                sheet = .bank
            } else if arguments.contains("-capture-charge") {
                sheet = .charge
            } else if arguments.contains("-capture-privacy") {
                sheet = .privacy
            } else if arguments.contains("-capture-create-game") {
                sheet = .createGame
            } else if arguments.contains("-capture-ranking") {
                sheet = .leaderboard
            } else if arguments.contains("-capture-demo-access") {
                sheet = .demoAccess
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 15).fill(Palette.forest).frame(width: 48, height: 48)
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(Palette.goldLight)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("BANCO DO TABULEIRO")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(Palette.forest)
                Text("Seu jogo, bem organizado")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .minimumScaleFactor(0.75)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if store.game != nil {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.muted)
                    .accessibilityLabel("Partida local, sem conexão necessária")
            }
        }
        .padding(.bottom, 2)
    }

    private var welcomeCard: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 28).fill(LinearGradient(colors: [Palette.forest, Color(hex: 0x0B6045)], startPoint: .topLeading, endPoint: .bottomTrailing))
                VStack(spacing: 16) {
                    BoardIllustration()
                        .frame(height: 190)
                        .padding(.horizontal, 4)
                    VStack(spacing: 7) {
                        Text("A mesa está pronta.")
                            .font(.system(size: 27, weight: .bold, design: .serif))
                            .foregroundStyle(Palette.card)
                            .multilineTextAlignment(.center)
                        Text("Controle saldos, imóveis e pagamentos da partida em um só lugar.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Palette.card.opacity(0.83))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(20)
            }
            .frame(minHeight: 350)
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(Palette.gold.opacity(0.55), lineWidth: 1))

            VStack(alignment: .leading, spacing: 15) {
                Label("Tudo fica salvo neste iPhone", systemImage: "iphone")
                Label("Sem cadastro e sem dinheiro real", systemImage: "lock.shield")
                Label("Cada operação entra no extrato", systemImage: "checkmark.seal")
            }
            .font(.system(.subheadline, design: .rounded, weight: .medium))
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 21))

            Button { sheet = .createGame } label: {
                Label("Criar partida", systemImage: "sparkles")
            }
            .buttonStyle(PrimaryActionStyle())
            .accessibilityIdentifier("create-game-button")

            Button { sheet = .demoAccess } label: {
                Label("Prévia de acesso fintech", systemImage: "person.crop.circle.badge.checkmark")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Palette.forest)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .accessibilityIdentifier("demo-access-preview")

            Button { sheet = .privacy } label: {
                Label("Privacidade e dados", systemImage: "lock.shield")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Palette.forest)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .accessibilityIdentifier("privacy-info-button")

            Text("M$ é uma moeda fictícia da partida. Nenhum pagamento real é realizado.")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
        }
    }

    private func gameDashboard(_ game: GameSnapshot) -> some View {
        VStack(spacing: 17) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(game.name)
                        .font(.system(.title2, design: .serif, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    Text(game.status == "active" ? "PARTIDA EM ANDAMENTO" : "PARTIDA ENCERRADA")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .tracking(1.3)
                        .foregroundStyle(game.status == "active" ? Palette.success : Palette.muted)
                }
                Spacer()
                Menu {
                    Button("Nova partida", systemImage: "plus") { sheet = .createGame }
                    Button("Privacidade e dados", systemImage: "lock.shield") { sheet = .privacy }
                    Button("Apagar dados locais", systemImage: "trash", role: .destructive) { showDeleteConfirmation = true }
                    if game.status == "active" {
                        Button("Encerrar partida", systemImage: "flag.checkered", role: .destructive) { showFinishConfirmation = true }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Palette.forest)
                        .frame(width: 42, height: 42)
                        .background(Palette.card, in: Circle())
                }
                .accessibilityLabel("Opções da partida")
            }

            balanceCard(game)
            playerCard(game)

            if game.status == "active" {
                if dynamicTypeSize.isAccessibilitySize {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 11) {
                        actionButton("PIX", icon: "arrow.left.arrow.right", color: Palette.forest) { sheet = .transfer }
                        actionButton("Banco", icon: "building.columns.fill", color: Palette.ink) { sheet = .bank }
                        actionButton("Cobrar", icon: "qrcode", color: Palette.burgundy) { sheet = .charge }
                        actionButton("Tabuleiro", icon: "square.grid.3x3", color: Palette.forestLight) { selectedTab = 1 }
                    }
                } else {
                    HStack(spacing: 11) {
                        actionButton("PIX", icon: "arrow.left.arrow.right", color: Palette.forest) { sheet = .transfer }
                        actionButton("Banco", icon: "building.columns.fill", color: Palette.ink) { sheet = .bank }
                        actionButton("Cobrar", icon: "qrcode", color: Palette.burgundy) { sheet = .charge }
                        actionButton("Tabuleiro", icon: "square.grid.3x3", color: Palette.forestLight) { selectedTab = 1 }
                    }
                }

                if !game.pendingRequests.isEmpty {
                    pendingPayments(game.pendingRequests)
                }
            }

            rankingCard(game)

            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "Últimas movimentações", action: "Ver extrato", actionHandler: { selectedTab = 3 })
                if game.transactions.isEmpty {
                    Text("As movimentações desta partida aparecerão aqui.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Palette.muted)
                } else {
                    ForEach(game.transactions.prefix(3)) { transaction in
                        TransactionRow(transaction: transaction, perspectivePlayerID: game.currentPlayer?.id, compact: true)
                    }
                }
            }
            .padding(18)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 23))

            Text("Código local  ·  \(game.inviteCode)  ·  Funciona apenas neste iPhone")
                .font(.system(.caption2, design: .monospaced, weight: .medium))
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
        }
    }

    private func balanceCard(_ game: GameSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("SALDO DO JOGADOR ATIVO", systemImage: "sparkle")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(Palette.goldLight)
                Spacer()
                Text("MOEDA DO JOGO")
                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(Palette.card.opacity(0.68))
            }
            Text(MoneyFormat.string(game.currentPlayer?.balanceMinor ?? 0))
                .font(.system(size: balanceFontSize, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .foregroundStyle(.white)
                .accessibilityIdentifier("balance-value")
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 7) {
                    Label(game.currentPlayer?.name ?? "Jogador", systemImage: "person.crop.circle.fill")
                        .foregroundStyle(Palette.card.opacity(0.82))
                    Text("\(game.players.count) jogadores")
                        .foregroundStyle(Palette.card.opacity(0.82))
                }
                .font(.system(.caption, design: .rounded, weight: .semibold))
            } else {
                HStack(spacing: 7) {
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundStyle(Palette.goldLight)
                    Text(game.currentPlayer?.name ?? "Jogador")
                        .foregroundStyle(Palette.card.opacity(0.82))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer(minLength: 4)
                    Text("\(game.players.count) jogadores")
                        .foregroundStyle(Palette.card.opacity(0.82))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .font(.system(.caption, design: .rounded, weight: .semibold))
            }
        }
        .padding(21)
        .background(LinearGradient(colors: [Palette.forest, Color(hex: 0x0A4938), Palette.ink], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 25))
        .overlay(RoundedRectangle(cornerRadius: 25).stroke(Palette.gold.opacity(0.65), lineWidth: 1))
        .shadow(color: Palette.forest.opacity(0.18), radius: 16, x: 0, y: 9)
    }

    private func playerCard(_ game: GameSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Jogadores na partida")
            if dynamicTypeSize.isAccessibilitySize {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(game.players) { player in
                        playerButton(player, game: game, accessibilitySize: true)
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 17) {
                        ForEach(game.players) { player in
                            playerButton(player, game: game, accessibilitySize: false)
                        }
                    }
                }
            }
        }
        .padding(17)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 23))
    }

    private func playerButton(_ player: GamePlayer, game: GameSnapshot, accessibilitySize: Bool) -> some View {
        Button {
            store.selectActivePlayer(player)
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Circle().fill(Color(hexString: player.colorHex)).frame(width: 48, height: 48)
                        .overlay(Image(systemName: tokenSymbol(player.token)).font(.system(size: 20, weight: .bold)).foregroundStyle(.white))
                        .overlay(Circle().stroke(player.id == game.currentPlayer?.id ? Palette.gold : .clear, lineWidth: 3))
                    if player.id == game.currentPlayer?.id {
                        Image(systemName: "crown.fill").font(.system(size: 12)).foregroundStyle(Palette.gold).offset(x: 5, y: -4)
                    }
                }
                Text(player.name)
                    .font(.system(accessibilitySize ? .body : .caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(accessibilitySize ? 2 : 1)
                    .minimumScaleFactor(accessibilitySize ? 0.85 : 0.65)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: accessibilitySize ? .infinity : 58)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(player.name), \(player.id == game.currentPlayer?.id ? "jogador ativo" : "selecionar como jogador ativo")")
        .accessibilityIdentifier("select-player-\(player.id)")
        .disabled(game.status != "active")
    }

    private func pendingPayments(_ requests: [PaymentRequest]) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            SectionTitle(title: "Cobranças aguardando")
            ForEach(requests) { request in
                HStack(spacing: 12) {
                    Image(systemName: "bell.badge.fill").foregroundStyle(Palette.burgundy)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(request.payerName) deve pagar a \(request.creatorName)")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                        Text(request.description)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(Palette.muted)
                    }
                    Spacer(minLength: 4)
                    Button("Pagar") { store.payCharge(request) }
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(Palette.forest)
                }
                .padding(13)
                .background(Palette.canvas, in: RoundedRectangle(cornerRadius: 15))
            }
        }
        .padding(17)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 23))
    }

    private func rankingCard(_ game: GameSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(game.status == "active" ? "Ranking ao vivo" : "Resultado final")
                        .font(.system(.title3, design: .serif, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Text(game.status == "active" ? "A classificação acompanha a partida." : "Classificação da partida encerrada.")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 8)
                Button("Ver classificação") { sheet = .leaderboard }
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(Palette.forest)
                    .accessibilityIdentifier("show-leaderboard")
            }

            ForEach(game.standings.prefix(3)) { standing in
                PlayerStandingRow(standing: standing, identifierPrefix: "leaderboard-preview-row", compact: true)
            }

            if game.standings.count > 3 {
                Text("+ \(game.standings.count - 3) jogadores na classificação")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(Palette.muted)
            }

            Text("Patrimônio = saldo disponível + preço de compra dos imóveis.")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 23))
    }

    private func actionButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 9) {
                Image(systemName: icon).font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Palette.goldLight)
                    .frame(width: 48, height: 48)
                    .background(color, in: Circle())
                Text(title)
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 19))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home-action-\(title)")
    }

    private var footer: some View {
        Text("M$ é dinheiro fictício. PIX Imobiliário funciona somente dentro da partida.")
            .font(.system(.caption2, design: .rounded))
            .foregroundStyle(Palette.muted)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
    }

    private func tokenSymbol(_ token: String) -> String {
        switch token {
        case "torre": return "building.2.fill"
        case "estrela": return "star.fill"
        case "casa": return "house.fill"
        case "carro": return "car.fill"
        default: return "pawn.fill"
        }
    }
}

private struct PrivacyAndDataView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(Palette.forest.opacity(0.08)).frame(width: 92, height: 92)
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 39, weight: .medium))
                        .foregroundStyle(Palette.forest)
                }
                .padding(.top, 16)

                Text("Privacidade e dados")
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .foregroundStyle(Palette.ink)

                PremiumCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Seus dados ficam neste iPhone")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(Palette.forest)
                        privacyRow("iphone", identifier: "privacy-local-storage", "Partidas, saldos e extratos são armazenados localmente em SQLite.")
                        privacyRow("wifi.slash", identifier: "privacy-no-network", "Esta versão não usa login, sincronização em nuvem, analytics ou rede para movimentar valores.")
                        privacyRow("banknote", identifier: "privacy-virtual-currency", "M$ é uma moeda fictícia; nenhum dinheiro real nem PIX oficial é movimentado.")
                        privacyRow("trash", identifier: "privacy-delete-data", "Use o menu da partida para apagar todas as partidas e dados locais.")
                    }
                }

                Text("Ao compartilhar este iPhone durante uma partida, os participantes podem ver as informações locais exibidas no app.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(20)
        }
        .background(Palette.canvas.ignoresSafeArea())
        .navigationTitle("Privacidade")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Fechar") { dismiss() }
                    .foregroundStyle(Palette.forest)
            }
        }
    }

    private func privacyRow(_ icon: String, identifier: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.gold)
                .frame(width: 24)
            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}

private struct DemoAccessView: View {
    @Environment(\.dismiss) private var dismiss
    let onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ZStack {
                    Circle().fill(Palette.forest.opacity(0.08)).frame(width: 88, height: 88)
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 37, weight: .medium))
                        .foregroundStyle(Palette.forest)
                }
                .padding(.top, 18)

                VStack(spacing: 6) {
                    Text("Acesso demonstrativo")
                        .font(.system(.largeTitle, design: .serif, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("demo-access-title")
                    Text("Uma prévia visual de acesso fintech para sua mesa local.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Palette.muted)
                        .multilineTextAlignment(.center)
                }

                PremiumCard {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(Palette.forest).frame(width: 50, height: 50)
                                Image(systemName: "person.fill")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(Palette.goldLight)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("PERFIL DE DEMONSTRAÇÃO")
                                    .font(.system(.caption2, design: .rounded, weight: .black))
                                    .tracking(0.7)
                                    .foregroundStyle(Palette.muted)
                                Text("Anfitrião local")
                                    .font(.system(.headline, design: .rounded, weight: .bold))
                                    .foregroundStyle(Palette.ink)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 23))
                                .foregroundStyle(Palette.success)
                        }

                        Rectangle().fill(Palette.line).frame(height: 1)

                        LabeledContent("Acesso", value: "Neste iPhone")
                        LabeledContent("Conexão", value: "Offline")
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("Mock visual: não solicita e-mail nem senha.", systemImage: "lock.shield")
                    Label("Nenhuma credencial é enviada ou armazenada.", systemImage: "wifi.slash")
                        .accessibilityIdentifier("demo-no-credentials")
                    Label("M$ é fictício e só existe nesta partida.", systemImage: "banknote")
                }
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(17)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 20))

                Button(action: onContinue) {
                    Label("Acessar demonstração", systemImage: "arrow.right")
                }
                .buttonStyle(PrimaryActionStyle())
                .accessibilityIdentifier("demo-access-continue")
            }
            .padding(20)
        }
        .background(Palette.canvas.ignoresSafeArea())
        .navigationTitle("Acesso")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Fechar") { dismiss() }
                    .foregroundStyle(Palette.forest)
            }
        }
    }
}

struct TransactionRow: View {
    let transaction: GameTransaction
    var perspectivePlayerID: Int64? = nil
    var compact = false

    private var amountLabel: String {
        let amount = MoneyFormat.string(transaction.amountMinor)
        if let perspectivePlayerID, transaction.fromPlayerID == perspectivePlayerID { return "−\(amount)" }
        if let perspectivePlayerID, transaction.toPlayerID == perspectivePlayerID { return "+\(amount)" }
        return amount
    }

    private var amountColor: Color {
        if let perspectivePlayerID, transaction.fromPlayerID == perspectivePlayerID { return Palette.danger }
        if let perspectivePlayerID, transaction.toPlayerID == perspectivePlayerID { return Palette.success }
        return Palette.ink
    }

    private var timestamp: String {
        guard let date = ISO8601DateFormatter().date(from: transaction.createdAt) else { return transaction.createdAt }
        return date.formatted(date: .numeric, time: .shortened)
    }

    private var symbol: String {
        switch transaction.kind {
        case "initial": return "banknote.fill"
        case "purchase": return "house.fill"
        case "rent": return "key.fill"
        case "charge": return "qrcode"
        case "bank_credit": return "arrow.down.left.circle.fill"
        case "bank_debit": return "arrow.up.right.circle.fill"
        default: return "arrow.left.arrow.right"
        }
    }

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Palette.forest)
                .frame(width: compact ? 34 : 38, height: compact ? 34 : 38)
                .background(Palette.forest.opacity(0.09), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.description)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(compact ? 1 : 2)
                Text(compact ? "\(transaction.fromName)  →  \(transaction.toName)" : "\(transaction.fromName)  →  \(transaction.toName)  ·  \(timestamp)")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 2)
            Text(amountLabel)
                .font(.system(compact ? .caption2 : .caption, design: .rounded, weight: .bold))
                .foregroundStyle(amountColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("transaction-row-\(transaction.id)")
    }
}

private struct BoardIllustration: View {
    private let squares: [(String, Color)] = [
        ("house.fill", Color(hex: 0xE6C16C)), ("building.2.fill", Color(hex: 0xE7E2D4)),
        ("train.side.front.car", Color(hex: 0xD08471)), ("leaf.fill", Color(hex: 0xC8D7B8)),
        ("house.fill", Color(hex: 0xE6C16C)), ("bolt.fill", Color(hex: 0xE7E2D4)),
        ("building.2.fill", Color(hex: 0xC8D7B8)), ("star.fill", Color(hex: 0xD08471)),
        ("house.fill", Color(hex: 0xE6C16C)), ("leaf.fill", Color(hex: 0xE7E2D4)),
        ("building.2.fill", Color(hex: 0xC8D7B8)), ("train.side.front.car", Color(hex: 0xD08471))
    ]

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                RoundedRectangle(cornerRadius: 24).fill(Color(hex: 0xEADBB4)).frame(width: side * 0.96, height: side * 0.88).rotationEffect(.degrees(-4))
                RoundedRectangle(cornerRadius: 22).fill(Color(hex: 0xF6F0DF)).frame(width: side * 0.93, height: side * 0.86).overlay {
                    ZStack {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
                            ForEach(squares.indices, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(squares[index].1)
                                    .overlay(Image(systemName: squares[index].0).font(.system(size: 10, weight: .bold)).foregroundStyle(Palette.ink.opacity(0.75)))
                                    .frame(height: side * 0.12)
                            }
                        }
                        RoundedRectangle(cornerRadius: 13).fill(LinearGradient(colors: [Color(hex: 0xE0E9D6), Color(hex: 0xC8D9BC)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: side * 0.48, height: side * 0.45)
                            .overlay {
                                VStack(spacing: 5) {
                                    Image(systemName: "building.columns.fill").font(.system(size: 29, weight: .medium)).foregroundStyle(Palette.forest)
                                    Text("CIDADE\nDO JOGO").font(.system(size: 8, weight: .black, design: .rounded)).tracking(1).multilineTextAlignment(.center).foregroundStyle(Palette.forest)
                                }
                            }
                        HStack(spacing: 20) {
                            token("pawn.fill", color: Color(hex: 0xD9483B), angle: -12)
                            token("house.fill", color: Color(hex: 0xE2B642), angle: 8)
                            token("building.2.fill", color: Color(hex: 0x4B78D5), angle: -5)
                        }
                        .offset(y: side * 0.31)
                    }
                    .padding(side * 0.035)
                }
                .shadow(color: .black.opacity(0.23), radius: 12, x: 0, y: 8)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityLabel("Ilustração original de um tabuleiro imobiliário e peças de jogo")
    }

    private func token(_ icon: String, color: Color, angle: Double) -> some View {
        Image(systemName: icon)
            .font(.system(size: 19, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.7), lineWidth: 1))
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 4)
            .rotationEffect(.degrees(angle))
    }
}
