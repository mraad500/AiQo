import UIKit

final class AboutAiQoViewController: UIViewController {
    
    private let textView = UITextView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "About AiQo"
        view.backgroundColor = .systemBackground
        
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.alwaysBounceVertical = true
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 24, left: 20, bottom: 24, right: 20)
        
        textView.text = """
AiQo is your AI-powered body & mind coach.

- Tracks your movement, sleep, and daily activity.
- Helps you drink enough water and move more.
- Gives you smart daily advice through Captain Hamoudi.
- Cares about both your physical and mental wellbeing.

نسخة AUE الأولى مخصصة للعرض الأكاديمي وتطوير الفكرة إلى منتج عالمي إن شاء الله.
"""
        textView.font = .systemFont(ofSize: 16)
        
        view.addSubview(textView)
        
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}
