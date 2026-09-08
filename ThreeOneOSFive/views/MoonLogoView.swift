import SwiftUI

/// Logo visual usado en Moon Place: círculo con texto lunar.
struct MoonLogoView: View {
    let size: CGFloat
    let pulse: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    AngularGradient(
                        gradient: .init(colors: [MoonPlaceTheme.accent, MoonPlaceTheme.accentBlue, MoonPlaceTheme.danger, MoonPlaceTheme.accent]),
                        center: .center
                    )
                )
                .frame(width: size, height: size)
                .blur(radius: pulse ? 1.5 : 0)
                .scaleEffect(pulse ? 1.04 : 1.0)
                .animation(
                    pulse
                        ? Animation.slowEaseInOut.repeatForever(autoreverses: true)
                        : .default,
                    value: pulse
                )

            Image(systemName: "crescent.moon.fill")
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.42, height: size * 0.42)
                .foregroundStyle(Color.white)
                .symbolEffect(.pulse, isActive: pulse)
        }
        .moonGlow(pulse ? .infinity : .zero, radius: pulse ? 18 : 0)
    }
}

// swift-format-ignore
private extension Animation {
    static var slowEaseInOut: Animation {
        Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)
    }
}
