import SwiftUI

enum Palette {
    static let forest = Color(hex: 0x073D2F)
    static let forestLight = Color(hex: 0x0D5B43)
    static let ink = Color(hex: 0x18332D)
    static let canvas = Color(hex: 0xF4EEDC)
    static let card = Color(hex: 0xFFFCF3)
    static let gold = Color(hex: 0xD7AE58)
    static let goldLight = Color(hex: 0xF0D58F)
    static let burgundy = Color(hex: 0x873C48)
    static let muted = Color(hex: 0x718079)
    static let line = Color(hex: 0xE5DDC7)
    static let success = Color(hex: 0x18764D)
    static let danger = Color(hex: 0xB83E38)
    static let playerColors: [String] = ["#13845B", "#D9483B", "#536FD8", "#9253C7", "#E39224", "#1689A6"]
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    init(hexString: String) {
        let cleaned = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt32(cleaned, radix: 16) ?? 0x13845B
        self.init(hex: value)
    }
}

struct PremiumCard<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Palette.line.opacity(0.8), lineWidth: 1))
            .shadow(color: Palette.ink.opacity(0.07), radius: 18, x: 0, y: 9)
    }
}

struct PrimaryActionStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .bold))
            .foregroundStyle(Palette.card)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(LinearGradient(colors: [Palette.forestLight, Palette.forest], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(Palette.gold.opacity(0.45), lineWidth: 1))
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.98 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

struct SectionTitle: View {
    let title: String
    var action: String? = nil
    var actionHandler: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(.title3, design: .serif, weight: .bold))
                .foregroundStyle(Palette.ink)
            Spacer()
            if let action {
                Button(action, action: { actionHandler?() })
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(Palette.forestLight)
            }
        }
    }
}
