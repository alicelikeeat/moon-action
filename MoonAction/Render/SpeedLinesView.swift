import UIKit

/// Manga speed lines around the screen edge, flashed during forward dashes.
@MainActor
final class SpeedLinesView: UIView {
    private let lines = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        lines.fillColor = UIColor(white: 1, alpha: 0.5).cgColor
        lines.opacity = 0
        layer.addSublayer(lines)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        lines.frame = bounds
        lines.path = makePath(in: bounds)
    }

    private func makePath(in r: CGRect) -> CGPath {
        let path = UIBezierPath()
        let c = CGPoint(x: r.midX, y: r.midY * 0.9)
        let outer = hypot(r.width, r.height) * 0.6
        var rng = SystemRandomNumberGenerator()
        for i in 0..<56 {
            let a = CGFloat(i) / 56 * 2 * .pi + CGFloat.random(in: -0.03...0.03, using: &rng)
            // Lines start well outside the center so the fighters stay clear.
            let inner = outer * CGFloat.random(in: 0.52...0.72, using: &rng)
            let w = CGFloat.random(in: 0.004...0.012, using: &rng)
            let p0 = CGPoint(x: c.x + cos(a) * inner, y: c.y + sin(a) * inner)
            let p1 = CGPoint(x: c.x + cos(a - w) * outer, y: c.y + sin(a - w) * outer)
            let p2 = CGPoint(x: c.x + cos(a + w) * outer, y: c.y + sin(a + w) * outer)
            path.move(to: p0)
            path.addLine(to: p1)
            path.addLine(to: p2)
            path.close()
        }
        return path.cgPath
    }

    func flash(_ duration: Double) {
        lines.path = makePath(in: bounds)
        let a = CAKeyframeAnimation(keyPath: "opacity")
        a.values = [0, 1, 1, 0]
        a.keyTimes = [0, 0.15, 0.6, 1]
        a.duration = max(0.2, duration)
        lines.removeAllAnimations()
        lines.add(a, forKey: "flash")
    }
}
