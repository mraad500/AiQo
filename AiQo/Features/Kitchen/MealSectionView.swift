import UIKit
import SwiftUI

final class MealSectionView: UIStackView {
    
    let titleKey: String
    let type: MealType
    
    private let titleLabel = UILabel()
    private let emptyLabel = UILabel()
    private var cardContainer = UIView()
    private var hostingController: UIHostingController<RecipeCardView>?
    
    var onMealTapped: ((Meal) -> Void)?
    
    init(titleKey: String, type: MealType) {
        self.titleKey = titleKey
        self.type = type
        super.init(frame: .zero)
        setup()
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        axis = .vertical
        spacing = 12
        
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.text = titleKey.localized
        
        emptyLabel.font = .systemFont(ofSize: 14)
        emptyLabel.textColor = .gray
        emptyLabel.text = "screen.kitchen.noMeals".localized
        emptyLabel.textAlignment = .right
        
        cardContainer.translatesAutoresizingMaskIntoConstraints = false
        cardContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 80).isActive = true
        
        addArrangedSubview(titleLabel)
        addArrangedSubview(cardContainer)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(cardTapped))
        cardContainer.addGestureRecognizer(tap)
        cardContainer.isUserInteractionEnabled = true
    }
    
    func updateMeal(_ meal: Meal?) {
        hostingController?.view.removeFromSuperview()
        hostingController?.removeFromParent()
        hostingController = nil
        
        if let meal {
            // Embed SwiftUI RecipeCardView
            let hosting = UIHostingController(rootView: RecipeCardView(meal: meal))
            hosting.view.translatesAutoresizingMaskIntoConstraints = false
            hosting.view.backgroundColor = .clear
            
            cardContainer.addSubview(hosting.view)
            NSLayoutConstraint.activate([
                hosting.view.topAnchor.constraint(equalTo: cardContainer.topAnchor),
                hosting.view.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor),
                hosting.view.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor),
                hosting.view.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor)
            ])
            hostingController = hosting
            emptyLabel.removeFromSuperview()
        } else {
            // no meal
            cardContainer.subviews.forEach { $0.removeFromSuperview() }
            cardContainer.addSubview(emptyLabel)
            emptyLabel.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                emptyLabel.topAnchor.constraint(equalTo: cardContainer.topAnchor),
                emptyLabel.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor),
                emptyLabel.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor),
                emptyLabel.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor)
            ])
        }
    }
    
    @objc private func cardTapped() {
        guard let meal = (hostingController?.rootView.meal) else { return }
        onMealTapped?(meal)
    }
}
