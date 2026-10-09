import SwiftUI
import SceneKit
import UIKit

struct BoardView: View {
    @EnvironmentObject private var store: GameStore
    @State private var rollToken = 0
    @State private var lastRoll = 0
    @State private var selectedPlayer = 0

    var body: some View {
        ZStack {
            Palette.canvas.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Sua jogada")
                            .font(.system(.largeTitle, design: .serif, weight: .bold))
                            .foregroundStyle(Palette.ink)
                        Text("Companion visual para a mesa física")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Palette.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if let game = store.game {
                        Picker("Jogador", selection: $selectedPlayer) {
                            ForEach(game.players.indices, id: \.self) { index in
                                Text(game.players[index].name).tag(index)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("board-player-picker")

                        BoardSceneView(moveToken: rollToken, playerIndex: selectedPlayer, spacesToMove: lastRoll)
                            .frame(height: 340)
                            .clipShape(RoundedRectangle(cornerRadius: 26))
                            .overlay(RoundedRectangle(cornerRadius: 26).stroke(Palette.gold.opacity(0.75), lineWidth: 1))
                            .shadow(color: Palette.ink.opacity(0.13), radius: 18, x: 0, y: 9)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Tabuleiro tridimensional com peças originais")

                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 17).fill(Palette.forest).frame(width: 60, height: 60)
                                Image(systemName: "die.face.\(lastRoll == 0 ? 5 : ((lastRoll - 1) % 6) + 1).fill")
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundStyle(Palette.goldLight)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(lastRoll == 0 ? "A próxima jogada começa aqui" : "\(game.players[min(selectedPlayer, game.players.count - 1)].name) avançou \(lastRoll) casas")
                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                    .foregroundStyle(Palette.ink)
                                Text("O resultado é apenas visual: continuem usando o tabuleiro físico.")
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundStyle(Palette.muted)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(15)
                        .background(Palette.card, in: RoundedRectangle(cornerRadius: 20))

                        Button(action: rollDice) {
                            Label(lastRoll == 0 ? "Lançar dados" : "Lançar novamente", systemImage: "die.face.5.fill")
                        }
                        .buttonStyle(PrimaryActionStyle())
                        .accessibilityIdentifier("roll-board-dice")

                        Label("A posição é uma anotação visual local e não altera saldos, aluguéis ou regras.", systemImage: "info.circle")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(Palette.muted)
                            .multilineTextAlignment(.center)
                    } else {
                        EmptySection(title: "Tabuleiro", detail: "Crie uma partida para ver o tabuleiro e as peças.")
                    }
                }
                .padding(18)
            }
        }
        .navigationTitle("Tabuleiro")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let activeID = store.game?.activePlayerID,
               let index = store.game?.players.firstIndex(where: { $0.id == activeID }) {
                selectedPlayer = index
            }
        }
        .onChange(of: selectedPlayer) { _, newIndex in
            guard let players = store.game?.players, players.indices.contains(newIndex) else { return }
            store.selectActivePlayer(players[newIndex])
        }
    }

    private func rollDice() {
        var generator = SystemRandomNumberGenerator()
        lastRoll = Int.random(in: 1...6, using: &generator) + Int.random(in: 1...6, using: &generator)
        rollToken += 1
    }
}

private struct BoardSceneView: UIViewRepresentable {
    let moveToken: Int
    let playerIndex: Int
    let spacesToMove: Int

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = UIColor(red: 0.035, green: 0.18, blue: 0.13, alpha: 1)
        view.scene = Coordinator.makeScene()
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = true
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.isPlaying = true
        context.coordinator.view = view
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.view = view
        context.coordinator.moveIfNeeded(token: moveToken, playerIndex: playerIndex, steps: spacesToMove)
    }

    final class Coordinator {
        weak var view: SCNView?
        private var lastMoveToken = 0
        private var positions = Array(repeating: 0, count: 6)

        func moveIfNeeded(token: Int, playerIndex: Int, steps: Int) {
            guard token != lastMoveToken, token > 0, let scene = view?.scene else { return }
            lastMoveToken = token
            let index = min(max(playerIndex, 0), positions.count - 1)
            positions[index] = (positions[index] + steps) % 20
            let nodeName = "Token_\(index + 1)"
            guard let node = scene.rootNode.childNode(withName: nodeName, recursively: true) else { return }
            let point = Self.spacePosition(positions[index])
            let move = SCNAction.move(to: SCNVector3(point.x, 0.24, point.y), duration: 0.82)
            move.timingMode = .easeInEaseOut
            let turn = SCNAction.rotateBy(x: .pi * 2, y: .pi * 2, z: .pi * 2, duration: 0.82)
            node.removeAllActions()
            node.runAction(.group([move, turn]))
        }

        static func makeScene() -> SCNScene {
            let scene = (try? loadBlenderScene()) ?? makeProceduralScene()
            scene.background.contents = UIColor(red: 0.035, green: 0.18, blue: 0.13, alpha: 1)
            if scene.rootNode.childNode(withName: "BoardCamera", recursively: true) == nil {
                let camera = SCNCamera()
                camera.fieldOfView = 37
                let cameraNode = SCNNode()
                cameraNode.name = "BoardCamera"
                cameraNode.camera = camera
                cameraNode.position = SCNVector3(0, 5.6, 6.8)
                cameraNode.look(at: SCNVector3(0, 0, 0))
                scene.rootNode.addChildNode(cameraNode)
            }
            addLighting(to: scene)
            return scene
        }

        private static func loadBlenderScene() throws -> SCNScene {
            guard let url = Bundle.main.url(forResource: "BoardScene", withExtension: "usdz", subdirectory: "Art.scnassets") else {
                throw GameStoreError.database("Blender USDZ indisponível; usando tabuleiro procedural.")
            }
            let imported = try SCNScene(url: url, options: [.convertToYUp: true])
            let scene = SCNScene()
            for child in imported.rootNode.childNodes { scene.rootNode.addChildNode(child.clone()) }
            return scene
        }

        private static func makeProceduralScene() -> SCNScene {
            let scene = SCNScene()
            scene.rootNode.addChildNode(makeBox(name: "Table", size: SCNVector3(4.45, 0.18, 4.45), color: UIColor(red: 0.79, green: 0.68, blue: 0.47, alpha: 1), position: SCNVector3(0, -0.10, 0), radius: 0.08))
            scene.rootNode.addChildNode(makeBox(name: "Felt", size: SCNVector3(3.63, 0.05, 3.63), color: UIColor(red: 0.73, green: 0.82, blue: 0.66, alpha: 1), position: SCNVector3(0, 0.02, 0), radius: 0.025))

            for index in 0..<20 {
                let point = spacePosition(index)
                let colors: [UIColor] = [
                    UIColor(red: 0.88, green: 0.73, blue: 0.39, alpha: 1),
                    UIColor(red: 0.91, green: 0.87, blue: 0.73, alpha: 1),
                    UIColor(red: 0.78, green: 0.48, blue: 0.38, alpha: 1),
                    UIColor(red: 0.71, green: 0.79, blue: 0.65, alpha: 1)
                ]
                let tile = makeBox(name: String(format: "Space_%02d", index), size: SCNVector3(0.62, 0.08, 0.62), color: colors[index % colors.count], position: SCNVector3(point.x, 0.10, point.y), radius: 0.035)
                scene.rootNode.addChildNode(tile)
            }

            scene.rootNode.addChildNode(makeBox(name: "TownHall", size: SCNVector3(0.54, 0.62, 0.48), color: UIColor(red: 0.91, green: 0.82, blue: 0.63, alpha: 1), position: SCNVector3(0, 0.37, 0), radius: 0.045))
            let roof = SCNPyramid(width: 0.64, height: 0.30, length: 0.57)
            roof.materials = [material(UIColor(red: 0.55, green: 0.25, blue: 0.16, alpha: 1))]
            let roofNode = SCNNode(geometry: roof)
            roofNode.name = "TownHallRoof"
            roofNode.position = SCNVector3(0, 0.83, 0)
            scene.rootNode.addChildNode(roofNode)

            let colors: [UIColor] = [
                UIColor(red: 0.78, green: 0.10, blue: 0.12, alpha: 1),
                UIColor(red: 0.06, green: 0.43, blue: 0.27, alpha: 1),
                UIColor(red: 0.10, green: 0.30, blue: 0.68, alpha: 1),
                UIColor(red: 0.55, green: 0.21, blue: 0.68, alpha: 1),
                UIColor(red: 0.88, green: 0.48, blue: 0.09, alpha: 1),
                UIColor(red: 0.04, green: 0.48, blue: 0.57, alpha: 1)
            ]
            for index in 0..<6 {
                let token = makeToken(name: "Token_\(index + 1)", color: colors[index])
                let point = spacePosition(index * 2)
                token.position = SCNVector3(point.x, 0.24, point.y)
                scene.rootNode.addChildNode(token)
            }

            for index in 0..<2 {
                let die = SCNBox(width: 0.33, height: 0.33, length: 0.33, chamferRadius: 0.055)
                die.materials = [material(UIColor(red: 0.96, green: 0.92, blue: 0.80, alpha: 1))]
                let dieNode = SCNNode(geometry: die)
                dieNode.name = "Die_\(index + 1)"
                dieNode.position = SCNVector3(Float(index) * 0.42 - 0.21, 0.30, 0.0)
                scene.rootNode.addChildNode(dieNode)
            }
            return scene
        }

        private static func makeToken(name: String, color: UIColor) -> SCNNode {
            let root = SCNNode()
            root.name = name
            let base = SCNCylinder(radius: 0.14, height: 0.09)
            base.materials = [material(color)]
            let baseNode = SCNNode(geometry: base)
            baseNode.position.y = 0.05
            root.addChildNode(baseNode)
            let body = SCNCone(topRadius: 0.025, bottomRadius: 0.12, height: 0.31)
            body.materials = [material(color)]
            let bodyNode = SCNNode(geometry: body)
            bodyNode.position.y = 0.23
            root.addChildNode(bodyNode)
            let head = SCNSphere(radius: 0.065)
            head.materials = [material(color)]
            let headNode = SCNNode(geometry: head)
            headNode.position.y = 0.43
            root.addChildNode(headNode)
            return root
        }

        private static func makeBox(name: String, size: SCNVector3, color: UIColor, position: SCNVector3, radius: CGFloat) -> SCNNode {
            let box = SCNBox(width: CGFloat(size.x), height: CGFloat(size.y), length: CGFloat(size.z), chamferRadius: radius)
            box.materials = [material(color)]
            let node = SCNNode(geometry: box)
            node.name = name
            node.position = position
            return node
        }

        private static func material(_ color: UIColor) -> SCNMaterial {
            let material = SCNMaterial()
            material.diffuse.contents = color
            material.metalness.contents = 0.02
            material.roughness.contents = 0.36
            material.lightingModel = .physicallyBased
            return material
        }

        private static func addLighting(to scene: SCNScene) {
            guard scene.rootNode.childNode(withName: "BoardKeyLight", recursively: true) == nil else { return }
            let ambient = SCNLight()
            ambient.type = .ambient
            ambient.intensity = 520
            ambient.color = UIColor(white: 0.8, alpha: 1)
            let ambientNode = SCNNode()
            ambientNode.name = "BoardAmbientLight"
            ambientNode.light = ambient
            scene.rootNode.addChildNode(ambientNode)

            let key = SCNLight()
            key.type = .omni
            key.intensity = 950
            key.color = UIColor(red: 1, green: 0.84, blue: 0.58, alpha: 1)
            key.castsShadow = true
            let keyNode = SCNNode()
            keyNode.name = "BoardKeyLight"
            keyNode.light = key
            keyNode.position = SCNVector3(-3, 6, 4)
            scene.rootNode.addChildNode(keyNode)
        }

        private static func spacePosition(_ index: Int) -> (x: Float, y: Float) {
            let side = index / 5
            let offset = Float(index % 5) * 0.82 - 1.64
            switch side {
            case 0: return (offset, -1.64)
            case 1: return (1.64, offset)
            case 2: return (-offset, 1.64)
            default: return (-1.64, -offset)
            }
        }
    }
}
