import SwiftUI

// MARK: - Moon Place Theme
/// Central design system for the Moon Place interface.
/// Palette: black base with purple / blue / red accents (matches the app logo).
enum MoonPlaceTheme {
    // MARK: Core palette
    static let background = Color(red: 0.03, green: 0.03, blue: 0.06)
    static let surface = Color(red: 0.09, green: 0.08, blue: 0.15)
    static let surfaceHighlight = Color.white.opacity(0.07)
    static let border = Color(red: 0.45, green: 0.36, blue: 0.85).opacity(0.45)

    static let accent = Color(red: 0.58, green: 0.40, blue: 1.00)     // purple
    static let accentBlue = Color(red: 0.22, green: 0.55, blue: 1.00) // blue
    static let danger = Color(red: 1.00, green: 0.22, blue: 0.36)     // red
    static let success = Color(red: 0.30, green: 0.95, blue: 0.62)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.60)

    // MARK: Gradients
    static let heroGradient = LinearGradient(
        colors: [accent, accentBlue, danger],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let buttonGradient = LinearGradient(
        colors: [accent, accentBlue],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let backgroundGradient = LinearGradient(
        colors: [Color(red: 0.05, green: 0.03, blue: 0.11), background],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: Metrics
    static let cornerRadius: CGFloat = 18
}

// MARK: - Glow
private struct MoonPlaceGlowModifier: ViewModifier {
    var color: Color
    var radius: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.55), radius: radius)
            .shadow(color: color.opacity(0.25), radius: radius * 2)
    }
}

extension View {
    /// Soft neon glow used across the Moon Place interface.
    func moonGlow(_ color: Color = MoonPlaceTheme.accent, radius: CGFloat = 10) -> some View {
        modifier(MoonPlaceGlowModifier(color: color, radius: radius))
    }
}

// MARK: - Card container
private struct MoonPlaceCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: MoonPlaceTheme.cornerRadius, style: .continuous)
                    .fill(MoonPlaceTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: MoonPlaceTheme.cornerRadius, style: .continuous)
                            .strokeBorder(MoonPlaceTheme.border, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.45), radius: 14, y: 6)
            )
    }
}

extension View {
    /// Premium dark card look for panels and rows.
    func moonCard() -> some View {
        modifier(MoonPlaceCardModifier())
    }
}

// MARK: - Particle field
private struct MoonPlaceParticle: Identifiable {
    let id = UUID()
    let x: Double          // 0...1 relative width
    let yOffset: Double    // extra travel above the top edge
    let radius: Double
    let speed: Double
    let phase: Double
    let colorIndex: Int
}

/// Lightweight animated particle field (~22 Canvas particles, 30 fps cap, GPU friendly).
struct MoonPlaceParticleField: View {
    @State private var particles: [MoonPlaceParticle] = []

    private static let palette: [Color] = [
        MoonPlaceTheme.accent,
        MoonPlaceTheme.accentBlue,
        MoonPlaceTheme.danger
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                for particle in particles {
                    let drift = now * particle.speed + particle.phase
                    let fraction = drift.truncatingRemainder(dividingBy: 1.0)
                    let y = size.height - fraction * (size.height + particle.yOffset)
                    let wobble = sin(now * 1.4 + particle.phase) * 8
                    let x = particle.x * size.width + wobble
                    let rect = CGRect(
                        x: x,
                        y: y,
                        width: particle.radius * 2,
                        height: particle.radius * 2
                    )
                    let color = Self.palette[particle.colorIndex % Self.palette.count]
                    context.opacity = 0.10 + 0.18 * fraction
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear(perform: seed)
    }

    private func seed() {
        guard particles.isEmpty else { return }
        var generator = SystemRandomNumberGenerator()
        particles = (0..<22).map { _ in
            MoonPlaceParticle(
                x: Double.random(in: 0...1, using: &generator),
                yOffset: Double.random(in: 40...140, using: &generator),
                radius: Double.random(in: 1.2...2.8, using: &generator),
                speed: Double.random(in: 0.04...0.12, using: &generator),
                phase: Double.random(in: 0...(2 * .pi), using: &generator),
                colorIndex: Int.random(in: 0..<3, using: &generator)
            )
        }
    }
}
