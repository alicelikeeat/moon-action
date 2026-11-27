import UIKit
import SceneKit

/// One app screen: a SceneKit scene (3D art) + a native Liquid Glass UIKit overlay.
@MainActor
class Screen {
    weak var host: GameViewController?
    let ui = PassthroughView()
    var scene: SCNScene = SCNScene()
    var pointOfView: SCNNode?

    var safe: UILayoutGuide { ui.safeAreaLayoutGuide }

    /// Build 3D content (set `scene`/`pointOfView`) and UI. Called once before presentation.
    func build() {}
    func update(dt: Double) {}
    func didAppear() {}
    func willDisappear() {}

    // Arena touches (touches that are not on a UI control)
    func touchesBegan(_ touches: Set<UITouch>, in view: UIView) {}
    func touchesMoved(_ touches: Set<UITouch>, in view: UIView) {}
    func touchesEnded(_ touches: Set<UITouch>, in view: UIView) {}

    func go(_ next: Screen) { host?.show(next) }

    // MARK: Helpers

    @discardableResult
    func presentModal(width: CGFloat, build: (UIStackView) -> Void) -> UIView {
        let dim = UIView()
        dim.backgroundColor = UIColor(white: 0, alpha: 0.45)
        dim.translatesAutoresizingMaskIntoConstraints = false
        ui.addSubview(dim)
        NSLayoutConstraint.activate([
            dim.leadingAnchor.constraint(equalTo: ui.leadingAnchor),
            dim.trailingAnchor.constraint(equalTo: ui.trailingAnchor),
            dim.topAnchor.constraint(equalTo: ui.topAnchor),
            dim.bottomAnchor.constraint(equalTo: ui.bottomAnchor),
        ])
        let card = Glass.panel(radius: 30)
        dim.addSubview(card)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: dim.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: dim.centerYAnchor),
            card.widthAnchor.constraint(equalToConstant: width),
            card.widthAnchor.constraint(lessThanOrEqualTo: dim.widthAnchor, constant: -32),
            stack.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -22),
            stack.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 22),
            stack.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -22),
        ])
        build(stack)
        dim.alpha = 0
        card.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            dim.alpha = 1
            card.transform = .identity
        }
        return dim
    }

    func dismissModal(_ v: UIView?) {
        guard let v else { return }
        UIView.animate(withDuration: 0.2, animations: { v.alpha = 0 }, completion: { _ in v.removeFromSuperview() })
    }

    func chip(symbol: String, text: String, tint: UIColor) -> (UIView, UILabel) {
        let panel = Glass.panel(radius: 18)
        let icon = UIImageView(image: UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)))
        icon.tintColor = tint
        let label = Glass.label(text, size: 14, weight: .semibold, align: .left, mono: true)
        let row = UIStackView(arrangedSubviews: [icon, label])
        row.spacing = 7
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView.addSubview(row)
        NSLayoutConstraint.activate([
            panel.heightAnchor.constraint(equalToConstant: 36),
            row.leadingAnchor.constraint(equalTo: panel.contentView.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: panel.contentView.trailingAnchor, constant: -14),
            row.centerYAnchor.constraint(equalTo: panel.contentView.centerYAnchor),
        ])
        return (panel, label)
    }

    func pin(_ v: UIView, edges to: UIView, inset: CGFloat = 0) {
        NSLayoutConstraint.activate([
            v.leadingAnchor.constraint(equalTo: to.leadingAnchor, constant: inset),
            v.trailingAnchor.constraint(equalTo: to.trailingAnchor, constant: -inset),
            v.topAnchor.constraint(equalTo: to.topAnchor, constant: inset),
            v.bottomAnchor.constraint(equalTo: to.bottomAnchor, constant: -inset),
        ])
    }

    /// Simple glass header with title + subtitle.
    func header(_ title: String, _ subtitle: String?, tint: UIColor? = nil) -> UIView {
        let panel = Glass.panel(radius: 22, tint: tint)
        let t = Glass.label(title, size: 17, weight: .semibold)
        var views: [UIView] = [t]
        if let subtitle {
            views.append(Glass.label(subtitle, size: 11, weight: .medium, color: Theme.text2))
        }
        let st = UIStackView(arrangedSubviews: views)
        st.axis = .vertical
        st.spacing = 2
        st.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView.addSubview(st)
        NSLayoutConstraint.activate([
            st.leadingAnchor.constraint(equalTo: panel.contentView.leadingAnchor, constant: 22),
            st.trailingAnchor.constraint(equalTo: panel.contentView.trailingAnchor, constant: -22),
            st.topAnchor.constraint(equalTo: panel.contentView.topAnchor, constant: 8),
            st.bottomAnchor.constraint(equalTo: panel.contentView.bottomAnchor, constant: -9),
        ])
        return panel
    }
}

/// Transparent layer between the 3D view and the glass UI that receives arena gestures.
final class TouchLayer: UIView {
    weak var host: GameViewController?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { host?.current?.touchesBegan(touches, in: self) }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { host?.current?.touchesMoved(touches, in: self) }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { host?.current?.touchesEnded(touches, in: self) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { host?.current?.touchesEnded(touches, in: self) }
}
