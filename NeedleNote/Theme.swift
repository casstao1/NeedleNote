import SwiftUI

// MARK: - Theme

struct KnitTheme {
    static let rose = Color(red: 0.718, green: 0.416, blue: 0.416)        // #B76A6A
    static let roseLight = Color(red: 0.937, green: 0.878, blue: 0.878)   // #EFE0E0
    static let roseMid = Color(red: 0.859, green: 0.745, blue: 0.745)     // #DBBEBD
    static let cream = Color(red: 0.980, green: 0.969, blue: 0.957)       // #FAF7F4
    static let warmWhite = Color(red: 0.996, green: 0.992, blue: 0.984)   // #FEFDFA
    static let taupe = Color(red: 0.553, green: 0.494, blue: 0.463)       // #8D7E76
    static let brown = Color(red: 0.302, green: 0.220, blue: 0.196)       // #4D3832
    static let sage = Color(red: 0.608, green: 0.694, blue: 0.620)        // #9BB19E
    static let charcoal = Color(red: 0.18, green: 0.16, blue: 0.14)

    static let cardShadow = Color.black.opacity(0.06)
    static let divider = Color(red: 0.91, green: 0.88, blue: 0.86)
}

// MARK: - View Modifiers

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(KnitTheme.warmWhite)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: KnitTheme.cardShadow, radius: 8, x: 0, y: 2)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(KnitTheme.rose.opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(KnitTheme.rose)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(KnitTheme.roseLight.opacity(configuration.isPressed ? 0.6 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardStyle()) }
}

enum KnitHaptics {
    private static let counterGenerator = UIImpactFeedbackGenerator(style: .light)

    static func prepareCounterTap() {
        counterGenerator.prepare()
    }

    static func counterTap() {
        counterGenerator.impactOccurred()
        counterGenerator.prepare()
    }
}

// MARK: - Counter Button

struct CounterButton: View {
    let systemName: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(KnitTheme.brown)
                .frame(width: 44, height: 44)
                .background(KnitTheme.roseLight)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: KnitProject.ProjectStatus
    
    var body: some View {
        Text(status.rawValue)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
    
    var color: Color {
        switch status {
        case .notStarted: return KnitTheme.taupe
        case .inProgress: return KnitTheme.rose
        case .completed: return KnitTheme.sage
        }
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(KnitTheme.taupe)
            .kerning(1.2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Formatted Date

extension Date {
    var relativeString: String {
        let cal = Calendar.current
        if cal.isDateInToday(self) { return "Today" }
        if cal.isDateInYesterday(self) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: self)
    }
}
