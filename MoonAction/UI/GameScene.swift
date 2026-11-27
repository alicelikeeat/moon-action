import SpriteKit
import UIKit

/// Base scene: SpriteKit renders the world/art, while a native UIKit overlay
/// (`ui`) hosts all Liquid Glass controls.
class GameScene: SKScene {
    let ui = PassthroughView()
    private var uiBuilt = false

    var safe: UILayoutGuide { ui.safeAreaLayoutGuide }

    /// Subclasses build their UIKit controls here (called once, after the overlay is on screen).
    func buildUI() {}

    func installUI(in view: SKView) {
        ui.frame = view.bounds
        ui.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(ui)
        if !uiBuilt {
            uiBuilt = true
            buildUI()
        }
        ui.alpha = 0
        UIView.animate(withDuration: 0.35, delay: 0.1, options: [.curveEaseOut]) { self.ui.alpha = 1 }
    }

    override func willMove(from view: SKView) {
        super.willMove(from: view)
        ui.removeFromSuperview()
    }

    /// Full-screen dimmed modal with a glass card in the middle.
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
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: dim.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: dim.centerYAnchor),
            card.widthAnchor.constraint(equalToConstant: width),
            card.heightAnchor.constraint(lessThanOrEqualTo: dim.safeAreaLayoutGuide.heightAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -22),
            stack.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -20),
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

    /// A glass capsule holding an SF Symbol + text (coins, records…).
    func chip(symbol: String, text: String, tint: UIColor) -> (UIView, UILabel) {
        let panel = Glass.panel(radius: 20)
        let icon = UIImageView(image: UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)))
        icon.tintColor = tint
        let label = Glass.label(text, size: 17, weight: .heavy, color: .white, align: .left)
        let row = UIStackView(arrangedSubviews: [icon, label])
        row.spacing = 7
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView.addSubview(row)
        NSLayoutConstraint.activate([
            panel.heightAnchor.constraint(equalToConstant: 40),
            row.leadingAnchor.constraint(equalTo: panel.contentView.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: panel.contentView.trailingAnchor, constant: -16),
            row.centerYAnchor.constraint(equalTo: panel.contentView.centerYAnchor),
        ])
        return (panel, label)
    }
}

extension UIColor {
    static let maRed = UIColor(hex: 0xE5483A)
    static let maPurple = UIColor(hex: 0x8D5CF6)
    static let maGold = UIColor(hex: 0xF5B83D)
    static let maBlue = UIColor(hex: 0x3B8BF6)
    static let maTeal = UIColor(hex: 0x23A3B8)
    static let maCoin = UIColor(hex: 0xFFD45A)
}
