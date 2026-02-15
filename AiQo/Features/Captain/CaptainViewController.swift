import SwiftUI

final class CaptainViewController: UIHostingController<CaptainScreen> {
    init() {
        super.init(rootView: CaptainScreen())
    }

    @MainActor @preconcurrency required dynamic init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: CaptainScreen())
    }
}
