import SwiftUI

struct PropertyView: View {
    @EnvironmentObject private var store: GameStore
    @State private var showingAddProperty = false
    @State private var propertyForRent: GameProperty?

    var body: some View {
        ZStack {
            Palette.canvas.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    if let game = store.game {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Carteira de imóveis")
                                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                                    .foregroundStyle(Palette.ink)
                                Text("Propriedades desta partida")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(Palette.muted)
                            }
                            Spacer()
                            if game.status == "active" {
                                Button { showingAddProperty = true } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 42, height: 42)
                                        .background(Palette.forest, in: Circle())
                                }
                                .accessibilityLabel("Cadastrar imóvel")
                            }
                        }

                        summary(game)
                        ForEach(game.properties) { property in
                            propertyCard(property, game: game)
                        }
                        Text("Nomes e valores são configurados pelo grupo. O app não inclui catálogos oficiais de jogos comerciais.")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(Palette.muted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)
                    } else {
                        EmptySection(title: "Imóveis", detail: "Crie uma partida para cadastrar e comprar propriedades.")
                    }
                }
                .padding(18)
            }
        }
        .navigationTitle("Imóveis")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddProperty) {
            NavigationStack { AddPropertyView() }
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $propertyForRent) { property in
            NavigationStack { RentPaymentView(property: property) }
                .presentationDetents([.medium])
        }
    }

    private func summary(_ game: GameSnapshot) -> some View {
        let owned = game.properties.filter { !$0.isAvailable }.count
        return HStack(spacing: 0) {
            summaryValue("\(game.properties.count)", label: "PROPRIEDADES")
            Rectangle().fill(Palette.line).frame(width: 1, height: 35)
            summaryValue("\(owned)", label: "ADQUIRIDOS")
            Rectangle().fill(Palette.line).frame(width: 1, height: 35)
            summaryValue("\(game.properties.count - owned)", label: "DISPONÍVEIS")
        }
        .padding(.vertical, 15)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 20))
    }

    private func summaryValue(_ value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(.title3, design: .rounded, weight: .bold)).foregroundStyle(Palette.forest)
            Text(label).font(.system(size: 8, weight: .heavy, design: .rounded)).tracking(0.8).foregroundStyle(Palette.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private func propertyCard(_ property: GameProperty, game: GameSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: property.isAvailable ? "house.fill" : "house.lodge.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Palette.forest)
                    .frame(width: 46, height: 46)
                    .background(Palette.forest.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 3) {
                    Text(property.name).font(.system(.headline, design: .rounded, weight: .bold)).foregroundStyle(Palette.ink)
                    Text(property.isAvailable ? "Disponível para compra" : "Proprietário: \(property.ownerName ?? "Jogador")")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(property.isAvailable ? Palette.success : Palette.muted)
                }
                Spacer()
                Circle().fill(property.isAvailable ? Palette.success.opacity(0.12) : Palette.gold.opacity(0.2))
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(property.isAvailable ? Palette.success : Palette.gold, lineWidth: 1.5))
            }

            HStack(spacing: 0) {
                priceColumn("PREÇO", value: property.purchasePriceMinor)
                Spacer()
                priceColumn("ALUGUEL", value: property.rentMinor)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .background(Palette.canvas, in: RoundedRectangle(cornerRadius: 14))

            if property.isAvailable && game.status == "active" {
                Button {
                    guard let buyerID = game.currentPlayer?.id else { return }
                    store.clearError()
                    store.buy(property: property, playerID: buyerID)
                } label: {
                    Label("Comprar com \(game.currentPlayer?.name ?? "jogador ativo")", systemImage: "cart.fill")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Palette.forest, in: RoundedRectangle(cornerRadius: 13))
                }
                .accessibilityIdentifier("buy-property-\(property.id)")
            } else if game.status == "active", property.ownerPlayerID != game.currentPlayer?.id {
                Button { propertyForRent = property } label: {
                    Label("Cobrar aluguel", systemImage: "key.fill")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(Palette.forest)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Palette.forest.opacity(0.09), in: RoundedRectangle(cornerRadius: 13))
                }
            }
        }
        .padding(16)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Palette.line.opacity(0.8), lineWidth: 1))
    }

    private func priceColumn(_ title: String, value: Int64) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 8, weight: .heavy, design: .rounded)).tracking(0.8).foregroundStyle(Palette.muted)
            Text(MoneyFormat.string(value)).font(.system(.subheadline, design: .rounded, weight: .bold)).foregroundStyle(Palette.ink)
        }
    }
}

private struct AddPropertyView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var price = ""
    @State private var rent = ""

    var body: some View {
        Form {
            Section("Dados do imóvel") {
                TextField("Nome", text: $name)
                HStack { Text("M$").foregroundStyle(Palette.forest).fontWeight(.bold); TextField("Preço", text: $price).keyboardType(.decimalPad) }
                HStack { Text("M$").foregroundStyle(Palette.forest).fontWeight(.bold); TextField("Aluguel", text: $rent).keyboardType(.decimalPad) }
            }
            Section {
                Text("Cadastre apenas nomes e valores definidos pelo grupo para esta partida.")
                    .font(.system(.caption, design: .rounded)).foregroundStyle(Palette.muted)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.canvas)
        .navigationTitle("Novo imóvel")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() }.foregroundStyle(Palette.forest) }
            ToolbarItem(placement: .confirmationAction) { Button("Salvar") { save() }.fontWeight(.bold).foregroundStyle(Palette.forest) }
        }
    }

    private func save() {
        guard let priceMinor = MoneyFormat.minorUnits(from: price) else {
            store.errorMessage = GameStoreError.invalidAmount.localizedDescription
            return
        }
        let rentMinor = MoneyFormat.minorUnits(from: rent) ?? 0
        store.clearError()
        store.addProperty(name: name, price: priceMinor, rent: rentMinor)
        if store.errorMessage == nil { dismiss() }
    }
}

private struct RentPaymentView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss
    let property: GameProperty
    @State private var payerID: Int64 = 0

    private var players: [GamePlayer] { store.game?.players ?? [] }

    var body: some View {
        Form {
            Section("Aluguel de \(property.name)") {
                Picker("Quem paga", selection: $payerID) {
                    ForEach(players.filter { $0.id != property.ownerPlayerID }) { Text($0.name).tag($0.id) }
                }
                LabeledContent("Proprietário", value: property.ownerName ?? "—")
                LabeledContent("Valor", value: MoneyFormat.string(property.rentMinor))
            }
            Section {
                Text("O pagamento será registrado no extrato junto com o imóvel.")
                    .font(.system(.caption, design: .rounded)).foregroundStyle(Palette.muted)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.canvas)
        .navigationTitle("Registrar aluguel")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() }.foregroundStyle(Palette.forest) }
            ToolbarItem(placement: .confirmationAction) { Button("Pagar") { pay() }.fontWeight(.bold).foregroundStyle(Palette.forest) }
        }
        .onAppear { payerID = players.first(where: { $0.id != property.ownerPlayerID })?.id ?? 0 }
    }

    private func pay() {
        store.clearError()
        store.payRent(property: property, payerID: payerID)
        if store.errorMessage == nil { dismiss() }
    }
}

struct EmptySection: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "building.2.crop.circle.fill")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Palette.gold)
            Text(title).font(.system(.title2, design: .serif, weight: .bold)).foregroundStyle(Palette.ink)
            Text(detail).font(.system(.subheadline, design: .rounded)).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .padding(20)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 24))
    }
}
