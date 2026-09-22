import SwiftUI
import AppKit

/// Yahya's pixel-art VR face, lit up by progress.
enum FaceState: Int, CaseIterable {
    case idle, half, goal, crazed

    var asset: String {
        switch self {
        case .idle: return "face-idle"
        case .half: return "face-half"
        case .goal: return "face-goal"
        case .crazed: return "face-crazed"
        }
    }

    var caption: String {
        switch self {
        case .idle: return "Visor's dark. Go play."
        case .half: return "Left lens lit — halfway to the goal"
        case .goal: return "Both lenses lit — goal reached"
        case .crazed: return "CRAZED — every game in the rotation, done"
        }
    }

    /// idle → half at ⌊goal/2⌋ games → goal when the day is complete → crazed when every
    /// enabled game is done.
    static func compute(_ s: DayStatus) -> FaceState {
        if s.eligibleCount > 0, s.done >= s.eligibleCount { return .crazed }
        if s.complete { return .goal }
        if s.goal > 0, s.done >= max(1, s.goal / 2) { return .half }
        return .idle
    }
}

/// Loose PNGs in the bundle's Resources (both the app and the widget extension carry a copy).
enum Art {
    nonisolated(unsafe) private static var cache: [String: NSImage] = [:]

    static func image(_ name: String) -> NSImage? {
        if let c = cache[name] { return c }
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let img = NSImage(contentsOf: url) else { return nil }
        cache[name] = img
        return img
    }
}

struct MascotView: View {
    let state: FaceState
    var size: CGFloat = 60
    /// App only: shake when crazed (widgets are static).
    var animated: Bool = false

    private var glow: Color {
        switch state {
        case .idle: return .clear
        case .half: return Color(hex: "#FF7A1A")
        case .goal: return Color(hex: "#FF5A36")
        case .crazed: return Color(hex: "#FF2D95")
        }
    }

    var body: some View {
        Group {
            if let img = Art.image(state.asset) {
                Image(nsImage: img).resizable().scaledToFit()
            } else {
                Image(systemName: "face.smiling").resizable().scaledToFit().foregroundStyle(.white.opacity(0.4))
            }
        }
        .frame(width: size, height: size)
        .shadow(color: glow.opacity(state == .idle ? 0 : 0.55), radius: size * 0.2)
        .modifier(CrazedShake(active: animated && state == .crazed))
        .accessibilityLabel(state.caption)
    }
}

/// Continuous jitter + pulse for the crazed state.
struct CrazedShake: ViewModifier {
    var active: Bool

    func body(content: Content) -> some View {
        if active {
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                content
                    .rotationEffect(.degrees(sin(t * 22) * 4))
                    .scaleEffect(1 + 0.05 * abs(sin(t * 6)))
                    .offset(x: sin(t * 31) * 1.5, y: cos(t * 27) * 1.5)
            }
        } else {
            content
        }
    }
}
