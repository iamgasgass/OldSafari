import SwiftUI
import UIKit

// MARK: - Colors

extension Color {
    /// 8-bit sRGB convenience initialiser, matching the `Color(red: n/255, ...)`
    /// style used throughout the original OldOS sources.
    static func oldOS(_ r: Double, _ g: Double, _ b: Double, _ opacity: Double = 1) -> Color {
        Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: opacity)
    }
}

// MARK: - Gradients

/// A single gradient stop expressed the same way OldOS expresses it.
struct OldOSStop {
    let color: Color
    let location: Double

    init(_ color: Color, _ location: Double) {
        self.color = color
        self.location = location
    }
}

extension LinearGradient {
    /// Replaces PureSwiftUI's `LinearGradient([(color:location:)], from:to:)`
    /// convenience initialiser without pulling in the dependency.
    init(oldOS stops: [OldOSStop], from: UnitPoint = .top, to: UnitPoint = .bottom) {
        self.init(
            gradient: Gradient(stops: stops.map {
                Gradient.Stop(color: $0.color, location: CGFloat($0.location))
            }),
            startPoint: from,
            endPoint: to
        )
    }

    init(oldOS colors: [Color], from: UnitPoint = .top, to: UnitPoint = .bottom) {
        self.init(gradient: Gradient(colors: colors), startPoint: from, endPoint: to)
    }
}

// MARK: - Fonts

/// OldOS renders every label with Helvetica Neue at a fixed size.  The font is
/// resolved through UIFont first so the app degrades to the system face instead
/// of silently falling back to a wrong metric when the family is unavailable.
enum OldOSFont {
    static func bold(_ size: CGFloat) -> Font {
        resolve(["Helvetica Neue Bold", "HelveticaNeue-Bold"], size: size, weight: .bold)
    }

    static func regular(_ size: CGFloat) -> Font {
        resolve(["Helvetica Neue Regular", "HelveticaNeue", "Helvetica Neue"], size: size, weight: .regular)
    }

    static func medium(_ size: CGFloat) -> Font {
        resolve(["HelveticaNeue-Medium", "Helvetica Neue Medium"], size: size, weight: .medium)
    }

    static func uiBold(_ size: CGFloat) -> UIFont {
        for name in ["Helvetica Neue Bold", "HelveticaNeue-Bold"] {
            if let font = UIFont(name: name, size: size) { return font }
        }
        return UIFont.systemFont(ofSize: size, weight: .bold)
    }

    static func uiRegular(_ size: CGFloat) -> UIFont {
        for name in ["Helvetica Neue Regular", "HelveticaNeue", "Helvetica Neue"] {
            if let font = UIFont(name: name, size: size) { return font }
        }
        return UIFont.systemFont(ofSize: size)
    }

    private static var cache: [String: Font] = [:]

    private static func resolve(_ names: [String], size: CGFloat, weight: Font.Weight) -> Font {
        let key = "\(names.first ?? "system")-\(size)"
        if let cached = cache[key] { return cached }

        var resolved = Font.system(size: size, weight: weight)
        for name in names where UIFont(name: name, size: size) != nil {
            resolved = Font.custom(name, fixedSize: size)
            break
        }
        cache[key] = resolved
        return resolved
    }
}

// MARK: - Edge borders

/// Verbatim port of OldOS' `EdgeBorder` shape, used by `border_top` /
/// `border_bottom` to draw the 1pt hairlines above and below the chrome.
struct OldOSEdgeBorder: Shape {
    var width: CGFloat
    var edges: [Edge]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for edge in edges {
            let x: CGFloat
            let y: CGFloat
            let w: CGFloat
            let h: CGFloat

            switch edge {
            case .top:
                x = rect.minX; y = rect.minY; w = rect.width; h = width
            case .bottom:
                x = rect.minX; y = rect.maxY - width; w = rect.width; h = width
            case .leading:
                x = rect.minX; y = rect.minY; w = width; h = rect.height
            case .trailing:
                x = rect.maxX - width; y = rect.minY; w = width; h = rect.height
            }

            path.addRect(CGRect(x: x, y: y, width: w, height: h))
        }
        return path
    }
}

extension View {
    func oldOSBorder(width: CGFloat = 1, edges: [Edge], color: Color) -> some View {
        overlay(OldOSEdgeBorder(width: width, edges: edges).fill(color))
    }

    /// OldOS `innerShadowBottom`: a soft highlight bleeding down from the top
    /// edge of the bar.  `radius` is a fraction of the shortest side.
    func oldOSInnerShadowBottom(color: Color, radius: CGFloat = 0.1) -> some View {
        modifier(OldOSInnerShadowBottom(color: color, radius: min(max(0, radius), 1)))
    }

    /// Verbatim port of OldOS' `addBorder`.
    func oldOSAddBorder<S: ShapeStyle>(_ content: S, width: CGFloat = 1, cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        return clipShape(shape).overlay(shape.strokeBorder(content, lineWidth: width))
    }

    func oldOSStrokeRoundedRectangle(_ radius: CGFloat, _ color: Color, lineWidth: CGFloat) -> some View {
        overlay(RoundedRectangle(cornerRadius: radius).stroke(color, lineWidth: lineWidth))
    }

    func oldOSStrokeCapsule(_ color: Color, lineWidth: CGFloat) -> some View {
        overlay(Capsule().stroke(color, lineWidth: lineWidth))
    }
}

private struct OldOSInnerShadowBottom: ViewModifier {
    var color: Color
    var radius: CGFloat

    private var colors: [Color] {
        [color.opacity(0.75), color.opacity(0.0), .clear]
    }

    func body(content: Content) -> some View {
        GeometryReader { geo in
            content.overlay(
                LinearGradient(gradient: Gradient(colors: colors), startPoint: .top, endPoint: .bottom)
                    .frame(height: radius * min(geo.size.width, geo.size.height) * 1.5),
                alignment: .top
            )
        }
    }
}

// MARK: - Inner shadow

/// Native replacement for PureSwiftUI's
/// `ps_innerShadow(.roundedRectangle(radius, fill), radius:offset:intensity:)`.
/// The shape is filled, then the same shape is stroked with a blurred dark
/// stroke clipped back into the shape, which produces the recessed bevel that
/// every iOS 6 control relies on.
struct OldOSInnerShadow<S: Shape, F: ShapeStyle>: View {
    var shape: S
    var fill: F
    var radius: CGFloat = 1.8
    var offset: CGPoint = CGPoint(x: 0, y: 1)
    var intensity: Double = 0.5
    var shadowColor: Color = .black

    var body: some View {
        shape
            .fill(fill)
            .overlay(
                shape
                    .stroke(shadowColor.opacity(intensity), lineWidth: max(radius, 0.4) * 2)
                    .blur(radius: radius)
                    .offset(x: offset.x, y: offset.y)
                    .clipShape(shape)
            )
    }
}

extension View {
    /// Applies an OldOS inner shadow *behind* the receiver, mirroring the way
    /// `ps_innerShadow` is used as a background treatment in OldOS.
    func oldOSInnerShadowBackground<S: Shape, F: ShapeStyle>(
        _ shape: S,
        _ fill: F,
        radius: CGFloat = 1.8,
        offset: CGPoint = CGPoint(x: 0, y: 1),
        intensity: Double = 0.5
    ) -> some View {
        background(
            OldOSInnerShadow(shape: shape, fill: fill, radius: radius, offset: offset, intensity: intensity)
        )
    }
}

// MARK: - Lists

/// OldOS `NoSepratorList`: a plain scrolling stack, because iOS 6 tables draw
/// their own hairlines instead of relying on `List` chrome.
struct OldOSPlainList<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) { content }
        }
        .scrollIndicators(.hidden)
    }
}

/// OldOS `vertical_bar_background`: the fine pinstripe used behind grouped
/// tables (Settings, Add Bookmark).
struct OldOSPinstripeBackground: View {
    var horizontalSpacing: CGFloat = 12
    var line: Color

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let count = max(Int(geometry.size.width / horizontalSpacing), 1)
                for index in 0...count {
                    let offset = CGFloat(index) * horizontalSpacing
                    path.move(to: CGPoint(x: offset, y: 0))
                    path.addLine(to: CGPoint(x: offset, y: geometry.size.height))
                }
            }
            .stroke(line, lineWidth: 3)
        }
    }
}

// MARK: - Keyboard

extension View {
    func oldOSHideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}

func oldOSHideKeyboard() {
    UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil, from: nil, for: nil
    )
}

// MARK: - Safe area

/// Reading the safe area from a `GeometryReader` that has already been told to
/// ignore it returns zero, which pushed the chrome under the Dynamic Island.
/// The window is the only reliable source, so it is queried directly and
/// refreshed when the interface geometry changes.
enum OldOSScreen {
    static var safeArea: EdgeInsets {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }

        guard let window = windows.first(where: { $0.isKeyWindow }) ?? windows.first else {
            return EdgeInsets(top: 20, leading: 0, bottom: 0, trailing: 0)
        }

        let insets = window.safeAreaInsets
        return EdgeInsets(
            top: insets.top,
            leading: insets.left,
            bottom: insets.bottom,
            trailing: insets.right
        )
    }
}

/// Keeps a live copy of the window safe area for views that draw edge to edge.
final class OldOSSafeArea: ObservableObject {
    @Published private(set) var insets: EdgeInsets = OldOSScreen.safeArea

    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            UIDevice.orientationDidChangeNotification,
            UIApplication.didBecomeActiveNotification
        ]

        observers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.refresh()
            }
        }
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    func refresh() {
        let latest = OldOSScreen.safeArea
        if latest != insets { insets = latest }
    }
}
