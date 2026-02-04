// File: LegacyCalculationComponents.swift
import UIKit

struct PointsRow {
    let title: String
    let value: String
    let points: Int
    let symbol: String
}

// MARK: - ✅ Dark Elegant Card Base (بدون Blur) — Carbon Dark
final class BeigeGlassCardView: UIView {

    let contentView = UIView()

    private let backplate = UIView()
    private let beigeTint = UIView()
    private let mintTint = UIView()
    private let highlight = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        clipsToBounds = false

        layer.cornerRadius = 34
        layer.cornerCurve = .continuous

        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor

        layer.shadowColor = UIColor.black.withAlphaComponent(0.70).cgColor
        layer.shadowOpacity = 1
        layer.shadowRadius = 26
        layer.shadowOffset = CGSize(width: 0, height: 18)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.clipsToBounds = true
        contentView.layer.cornerRadius = 34
        contentView.layer.cornerCurve = .continuous
        addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        backplate.translatesAutoresizingMaskIntoConstraints = false
        backplate.isUserInteractionEnabled = false
        // ✅ Carbon dark (مو أسود فاحم)
        backplate.backgroundColor = UIColor(red: 0.11, green: 0.12, blue: 0.14, alpha: 0.88)

        beigeTint.translatesAutoresizingMaskIntoConstraints = false
        beigeTint.isUserInteractionEnabled = false

        mintTint.translatesAutoresizingMaskIntoConstraints = false
        mintTint.isUserInteractionEnabled = false

        highlight.translatesAutoresizingMaskIntoConstraints = false
        highlight.isUserInteractionEnabled = false
        highlight.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        highlight.layer.cornerRadius = 1
        highlight.layer.cornerCurve = .continuous

        contentView.addSubview(backplate)
        contentView.addSubview(beigeTint)
        contentView.addSubview(mintTint)
        contentView.addSubview(highlight)

        NSLayoutConstraint.activate([
            backplate.topAnchor.constraint(equalTo: contentView.topAnchor),
            backplate.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            backplate.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            backplate.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            beigeTint.topAnchor.constraint(equalTo: contentView.topAnchor),
            beigeTint.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            beigeTint.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            beigeTint.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            mintTint.topAnchor.constraint(equalTo: contentView.topAnchor),
            mintTint.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            mintTint.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            mintTint.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            highlight.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            highlight.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            highlight.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            highlight.heightAnchor.constraint(equalToConstant: 2)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func apply(beige: UIColor, mint: UIColor) {
        // ✅ تِنت أقوى شوي حتى يطلع راقي وواضح
        beigeTint.backgroundColor = beige.withAlphaComponent(0.28)
        mintTint.backgroundColor  = mint.withAlphaComponent(0.22)
    }
}

// MARK: - Plain Card (Reusable) — Carbon Dark
final class PlainCardView: UIView {
    let contentView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        layer.cornerRadius = 26
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor

        layer.shadowColor = UIColor.black.withAlphaComponent(0.60).cgColor
        layer.shadowOpacity = 1
        layer.shadowRadius = 20
        layer.shadowOffset = CGSize(width: 0, height: 14)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.clipsToBounds = true
        contentView.layer.cornerRadius = 26
        contentView.layer.cornerCurve = .continuous
        // ✅ Carbon dark elegant
        contentView.backgroundColor = UIColor(red: 0.10, green: 0.11, blue: 0.13, alpha: 0.86)
        addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Plain Pill (for progress) — Dark
final class PlainPillView: UIView {
    let contentView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear

        layer.cornerRadius = 14
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor

        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.clipsToBounds = true
        contentView.layer.cornerRadius = 14
        contentView.layer.cornerCurve = .continuous
        contentView.backgroundColor = UIColor.black.withAlphaComponent(0.38)
        addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Buttons (✅ بدون Blur) — Strong
enum GlassButtons {

    private static let bgTag = 987001

    static func stylePrimary(_ button: UIButton, title: String, systemImage: String, mint: UIColor, text: UIColor) {
        reset(button)

        button.setTitle(title, for: .normal)
        button.setImage(UIImage(systemName: systemImage), for: .normal)
        button.tintColor = text
        button.titleLabel?.font = roundedFont(size: 17, weight: .heavy)
        button.imageView?.preferredSymbolConfiguration = .init(pointSize: 16, weight: .bold)

        button.contentEdgeInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        button.layer.cornerRadius = 18
        button.layer.cornerCurve = .continuous
        button.clipsToBounds = true

        let bg = UIView()
        bg.tag = bgTag
        bg.translatesAutoresizingMaskIntoConstraints = false
        bg.isUserInteractionEnabled = false
        bg.backgroundColor = mint.withAlphaComponent(0.92)
        bg.layer.cornerRadius = 18
        bg.layer.cornerCurve = .continuous

        button.insertSubview(bg, at: 0)

        NSLayoutConstraint.activate([
            bg.topAnchor.constraint(equalTo: button.topAnchor),
            bg.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            bg.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            bg.trailingAnchor.constraint(equalTo: button.trailingAnchor)
        ])

        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.14).cgColor

        button.layer.shadowColor = UIColor.black.withAlphaComponent(0.55).cgColor
        button.layer.shadowOpacity = 1
        button.layer.shadowRadius = 16
        button.layer.shadowOffset = CGSize(width: 0, height: 12)
    }

    static func styleSecondary(_ button: UIButton, title: String, beige: UIColor, text: UIColor) {
        reset(button)

        button.setTitle(title, for: .normal)
        button.tintColor = text
        button.titleLabel?.font = roundedFont(size: 16, weight: .bold)

        button.contentEdgeInsets = UIEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        button.layer.cornerRadius = 18
        button.layer.cornerCurve = .continuous
        button.clipsToBounds = true

        let bg = UIView()
        bg.tag = bgTag
        bg.translatesAutoresizingMaskIntoConstraints = false
        bg.isUserInteractionEnabled = false
        bg.backgroundColor = beige.withAlphaComponent(0.78)
        bg.layer.cornerRadius = 18
        bg.layer.cornerCurve = .continuous

        button.insertSubview(bg, at: 0)

        NSLayoutConstraint.activate([
            bg.topAnchor.constraint(equalTo: button.topAnchor),
            bg.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            bg.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            bg.trailingAnchor.constraint(equalTo: button.trailingAnchor)
        ])

        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.14).cgColor
        button.layer.shadowOpacity = 0
    }

    private static func reset(_ button: UIButton) {
        button.subviews.filter { $0.tag == bgTag }.forEach { $0.removeFromSuperview() }
        button.layer.shadowOpacity = 0
        button.layer.borderWidth = 0
        button.backgroundColor = .clear
    }

    private static func roundedFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        if let rounded = base.fontDescriptor.withDesign(.rounded) {
            return UIFont(descriptor: rounded, size: size)
        }
        return base
    }
}

// MARK: - Points Cell (✅ بدون Blur) — Dark Elegant
final class PointsCell: UITableViewCell {
    static let reuseID = "PointsCell"

    private let card = UIView()
    private let icon = UIImageView()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let pointsPill = UIView()
    private let pointsLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        card.translatesAutoresizingMaskIntoConstraints = false
        card.clipsToBounds = true
        card.layer.cornerRadius = 18
        card.layer.cornerCurve = .continuous
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
        card.backgroundColor = UIColor(red: 0.09, green: 0.10, blue: 0.12, alpha: 0.86)
        contentView.addSubview(card)

        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.contentMode = .scaleAspectFit

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = roundedFont(size: 15, weight: .bold)

        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = roundedFont(size: 13, weight: .semibold)

        let textStack = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        pointsPill.translatesAutoresizingMaskIntoConstraints = false
        pointsPill.clipsToBounds = true
        pointsPill.layer.cornerRadius = 14
        pointsPill.layer.cornerCurve = .continuous
        pointsPill.layer.borderWidth = 1
        pointsPill.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
        pointsPill.backgroundColor = UIColor.black.withAlphaComponent(0.38)

        pointsLabel.translatesAutoresizingMaskIntoConstraints = false
        pointsLabel.font = roundedFont(size: 13, weight: .heavy)
        pointsPill.addSubview(pointsLabel)

        card.addSubview(icon)
        card.addSubview(textStack)
        card.addSubview(pointsPill)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),

            icon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            icon.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 22),
            icon.heightAnchor.constraint(equalToConstant: 22),

            textStack.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            textStack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: pointsPill.leadingAnchor, constant: -10),

            pointsPill.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            pointsPill.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            pointsPill.heightAnchor.constraint(equalToConstant: 30),

            pointsLabel.leadingAnchor.constraint(equalTo: pointsPill.leadingAnchor, constant: 10),
            pointsLabel.trailingAnchor.constraint(equalTo: pointsPill.trailingAnchor, constant: -10),
            pointsLabel.centerYAnchor.constraint(equalTo: pointsPill.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String, value: String, points: Int, symbol: String, isTotal: Bool, tint: UIColor, text: UIColor, sub: UIColor) {
        icon.image = UIImage(systemName: symbol)
        icon.tintColor = isTotal ? tint : text

        titleLabel.text = title
        titleLabel.textColor = text

        valueLabel.text = isTotal ? " " : value
        valueLabel.textColor = sub

        pointsLabel.text = isTotal ? "\(points) pts" : "+\(points)"
        pointsLabel.textColor = text

        card.layer.borderColor = UIColor.white.withAlphaComponent(isTotal ? 0.16 : 0.12).cgColor
    }

    private func roundedFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        if let rounded = base.fontDescriptor.withDesign(.rounded) {
            return UIFont(descriptor: rounded, size: size)
        }
        return base
    }
}

// MARK: - ✅ Premium Ripple Loader (أنيميشن عالمي)
final class PremiumRippleLoader: UIView {
    
    private let centerDot = UIView()
    private let ring1 = UIView()
    private let ring2 = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        
        setupViews()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupViews() {
        [ring1, ring2, centerDot].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.layer.cornerRadius = 0 // Will adjust in layout
            $0.isUserInteractionEnabled = false
            addSubview($0)
        }
        
        // Center Dot constraints
        NSLayoutConstraint.activate([
            centerDot.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerDot.centerYAnchor.constraint(equalTo: centerYAnchor),
            centerDot.widthAnchor.constraint(equalToConstant: 16),
            centerDot.heightAnchor.constraint(equalToConstant: 16),
            
            ring1.centerXAnchor.constraint(equalTo: centerXAnchor),
            ring1.centerYAnchor.constraint(equalTo: centerYAnchor),
            ring1.widthAnchor.constraint(equalToConstant: 16), // Starts same size
            ring1.heightAnchor.constraint(equalToConstant: 16),
            
            ring2.centerXAnchor.constraint(equalTo: centerXAnchor),
            ring2.centerYAnchor.constraint(equalTo: centerYAnchor),
            ring2.widthAnchor.constraint(equalToConstant: 16),
            ring2.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        centerDot.layer.cornerRadius = 8
        ring1.layer.cornerRadius = 8
        ring2.layer.cornerRadius = 8
    }
    
    func setup(tint: UIColor) {
        centerDot.backgroundColor = tint
        ring1.layer.borderColor = tint.cgColor
        ring1.layer.borderWidth = 2
        ring2.layer.borderColor = tint.cgColor
        ring2.layer.borderWidth = 1.5
    }
    
    func startAnimating() {
        // Dot Pulse
        let dotPulse = CABasicAnimation(keyPath: "transform.scale")
        dotPulse.fromValue = 1.0
        dotPulse.toValue = 1.25
        dotPulse.duration = 0.8
        dotPulse.autoreverses = true
        dotPulse.repeatCount = .infinity
        dotPulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        centerDot.layer.add(dotPulse, forKey: "dotPulse")
        
        // Ring 1 Ripple
        let scale1 = CABasicAnimation(keyPath: "transform.scale")
        scale1.fromValue = 1.0
        scale1.toValue = 4.5
        scale1.duration = 2.4
        scale1.repeatCount = .infinity
        scale1.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        let fade1 = CABasicAnimation(keyPath: "opacity")
        fade1.fromValue = 0.8
        fade1.toValue = 0.0
        fade1.duration = 2.4
        fade1.repeatCount = .infinity
        fade1.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        ring1.layer.add(scale1, forKey: "scale1")
        ring1.layer.add(fade1, forKey: "fade1")
        
        // Ring 2 Ripple (Delayed)
        let scale2 = CABasicAnimation(keyPath: "transform.scale")
        scale2.fromValue = 1.0
        scale2.toValue = 4.5
        scale2.duration = 2.4
        scale2.beginTime = CACurrentMediaTime() + 1.2 // Delay half cycle
        scale2.repeatCount = .infinity
        scale2.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        let fade2 = CABasicAnimation(keyPath: "opacity")
        fade2.fromValue = 0.6
        fade2.toValue = 0.0
        fade2.duration = 2.4
        fade2.beginTime = CACurrentMediaTime() + 1.2
        fade2.repeatCount = .infinity
        fade2.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        ring2.layer.add(scale2, forKey: "scale2")
        ring2.layer.add(fade2, forKey: "fade2")
    }
    
    func stopAnimating() {
        centerDot.layer.removeAllAnimations()
        ring1.layer.removeAllAnimations()
        ring2.layer.removeAllAnimations()
    }
}
