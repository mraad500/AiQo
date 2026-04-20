import SwiftUI
import PhotosUI
import UIKit

struct LearningProofSubmissionView: View {
    let quest: QuestDefinition
    let option: LearningCourseOption
    let onVerified: () -> Void

    @ObservedObject var proofStore: LearningProofStore

    @Environment(\.dismiss) private var dismiss

    @State private var selectedItem: PhotosPickerItem?
    @State private var certificateImage: UIImage?
    @State private var certificateURLText: String = ""
    @State private var isSubmitting = false
    @State private var submissionError: String?
    @State private var localStatus: LearningProofVerificationStatus = .notSubmitted
    @State private var rejectionReason: String?
    @State private var captainMessage: String?
    @State private var showConsentSheet: Bool = false
    @State private var urlBadge: CourseURLValidator.Badge = .empty
    @State private var urlDebounceTask: Task<Void, Never>?
    @State private var lastTechReason: String?

    private var isArabicOption: Bool { option.language == .arabic }
    private var optionLayoutDirection: LayoutDirection {
        isArabicOption ? .rightToLeft : .leftToRight
    }
    private var appLayoutDirection: LayoutDirection {
        AppSettingsStore.shared.appLanguage == .arabic ? .rightToLeft : .leftToRight
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: appLayoutDirection == .rightToLeft ? .trailing : .leading, spacing: 18) {
                    headerBlock
                    statusBadge
                    certificatePickerBlock
                    certificateLinkBlock

                    if let submissionError {
                        Text(submissionError)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(appLayoutDirection == .rightToLeft ? .trailing : .leading)
                    }

                    if let rejectionReason, localStatus == .rejected {
                        Text(rejectionReason)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(hex: "B24545"))
                            .multilineTextAlignment(appLayoutDirection == .rightToLeft ? .trailing : .leading)
                    }

                    if lastTechReason == "rate_limit", localStatus == .rejected {
                        contactSupportButton
                    }

                    submitButton
                }
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            .background(Color(uiColor: .systemGroupedBackground).opacity(0.35))
            .navigationTitle(questLocalizedText("gym.quest.learning.proof.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(questLocalizedText("gym.quest.cancel")) {
                        dismiss()
                    }
                }
            }
            .environment(\.layoutDirection, appLayoutDirection)
        }
        .onAppear(perform: hydrateFromStore)
        .onChange(of: selectedItem) { _, newValue in
            loadPickedImage(newValue)
        }
        .sheet(isPresented: $showConsentSheet) {
            OnDeviceVerificationConsentSheet(onAccept: {
                // Re-enter submission now that the user has granted consent.
                if let image = certificateImage {
                    performSubmit(image: image)
                }
            })
        }
    }

    // MARK: - Sections

    private var headerBlock: some View {
        // The option's title is rendered in its own native layout direction so an
        // Arabic course title in an English app still reads correctly (and vice versa).
        VStack(alignment: isArabicOption ? .trailing : .leading, spacing: 6) {
            Text(questLocalizedText("gym.quest.learning.proof.forCourse"))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(hex: "666666"))
                .frame(maxWidth: .infinity, alignment: appLayoutDirection == .rightToLeft ? .trailing : .leading)

            Text(option.title)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(hex: "1A1A1A"))
                .frame(maxWidth: .infinity, alignment: isArabicOption ? .trailing : .leading)
                .environment(\.layoutDirection, optionLayoutDirection)

            Text(questLocalizedText(option.providerDisplayKey))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(hex: "666666"))
                .frame(maxWidth: .infinity, alignment: isArabicOption ? .trailing : .leading)
                .environment(\.layoutDirection, optionLayoutDirection)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var statusBadge: some View {
        HStack {
            Text(statusLabel)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(statusBadgeTint)
                )
                .foregroundStyle(statusBadgeForeground)
            Spacer()
        }
    }

    @ViewBuilder
    private var certificatePickerBlock: some View {
        VStack(alignment: appLayoutDirection == .rightToLeft ? .trailing : .leading, spacing: 10) {
            Text(questLocalizedText("gym.quest.learning.proof.certificateHeader"))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "1A1A1A"))

            PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                HStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 16, weight: .bold))
                    Text(
                        certificateImage == nil
                            ? questLocalizedText("gym.quest.learning.proof.uploadImage")
                            : questLocalizedText("gym.quest.learning.proof.replaceImage")
                    )
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .foregroundStyle(Color(hex: "1A1A1A"))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(hex: "EBCF97").opacity(0.85))
                )
            }
            .disabled(isSubmitting)

            if let certificateImage {
                Image(uiImage: certificateImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.4), lineWidth: 0.6)
                    )
            }
        }
    }

    @ViewBuilder
    private var certificateLinkBlock: some View {
        VStack(alignment: appLayoutDirection == .rightToLeft ? .trailing : .leading, spacing: 8) {
            Text(questLocalizedText("learningSpark.proof.url.label.optional"))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "1A1A1A"))

            TextField(
                questLocalizedText("learningSpark.proof.url.placeholder.optional"),
                text: $certificateURLText
            )
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .multilineTextAlignment(appLayoutDirection == .rightToLeft ? .trailing : .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(hex: "F5F5F5"))
            )
            .disabled(isSubmitting)
            .onChange(of: certificateURLText) { _, newValue in
                debounceURLClassification(newValue)
            }

            urlBadgeView
        }
    }

    @ViewBuilder
    private var urlBadgeView: some View {
        switch urlBadge {
        case .empty:
            EmptyView()
        case .trusted:
            urlBadgeLabel(symbol: "checkmark.seal.fill",
                          tint: Color(hex: "B7E5D2"),
                          text: questLocalizedText("gym.quest.learning.url.trusted"))
        case .untrusted:
            urlBadgeLabel(symbol: "exclamationmark.triangle.fill",
                          tint: Color(hex: "FDE2A7"),
                          text: questLocalizedText("gym.quest.learning.url.untrusted"))
        case .invalid:
            urlBadgeLabel(symbol: "xmark.octagon.fill",
                          tint: Color(hex: "F7C7C7"),
                          text: questLocalizedText("gym.quest.learning.url.invalid"))
        }
    }

    @ViewBuilder
    private func urlBadgeLabel(symbol: String, tint: Color, text: String) -> some View {
        HStack(spacing: 6) {
            if appLayoutDirection == .rightToLeft { Spacer() }
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
            if appLayoutDirection == .leftToRight { Spacer() }
        }
        .foregroundStyle(Color(hex: "1A1A1A"))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(tint))
    }

    private func debounceURLClassification(_ raw: String) {
        urlDebounceTask?.cancel()
        urlDebounceTask = Task { @MainActor in
            // 300ms debounce — live validation without thrashing on every keystroke.
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            urlBadge = CourseURLValidator.classify(raw)
        }
    }

    /// Shown only when the verifier rejected because the per-hour rate limit was hit.
    /// Pre-fills a mailto so the user can reach support with a consistent subject line.
    @ViewBuilder
    private var contactSupportButton: some View {
        Button(action: openSupportMail) {
            HStack(spacing: 6) {
                if appLayoutDirection == .rightToLeft { Spacer() }
                Image(systemName: "envelope.fill")
                    .font(.system(size: 13, weight: .bold))
                Text(questLocalizedText("gym.quest.learning.rateLimit.contact"))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                if appLayoutDirection == .leftToRight { Spacer() }
            }
            .foregroundStyle(Color(hex: "1A1A1A").opacity(0.78))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(hex: "1A1A1A").opacity(0.14), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }

    private func openSupportMail() {
        let subject = "مشكلة في تحقق شرارة التعلم"
        let encoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        guard let url = URL(string: "mailto:support@aiqo.app?subject=\(encoded)") else { return }
        UIApplication.shared.open(url)
    }

    @ViewBuilder
    private var submitButton: some View {
        Button(action: submit) {
            HStack(spacing: 8) {
                if isSubmitting {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Color(hex: "1A1A1A"))
                }
                Text(submitButtonTitle)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "1A1A1A"))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(canSubmit ? Color(hex: "B7E5D2") : Color(hex: "E0E0E0"))
            )
        }
        .disabled(!canSubmit || isSubmitting)
    }

    // MARK: - Actions

    private func hydrateFromStore() {
        let record = proofStore.record(for: quest.id)
        // Only hydrate fields belonging to the currently selected option; if the stored
        // proof was for a different option, ignore the old inputs.
        guard record.selectedCourseOptionId == option.id else {
            localStatus = .notSubmitted
            rejectionReason = nil
            certificateURLText = ""
            certificateImage = nil
            return
        }
        localStatus = record.lastResult.status
        rejectionReason = record.lastResult.rejectionReason
        certificateURLText = record.certificateURL ?? ""
        if let image = proofStore.loadCertificateImage(record.certificateImageRelativePath) {
            certificateImage = image
        }
    }

    private func loadPickedImage(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        self.certificateImage = image
                        self.submissionError = nil
                    }
                }
            } catch {
                await MainActor.run {
                    submissionError = questLocalizedText("gym.quest.learning.proof.errorImageLoad")
                }
            }
        }
    }

    private func submit() {
        guard canSubmit, let image = certificateImage else { return }

        // Show the lightweight consent sheet on the first attempt per install. The
        // sheet's onAccept callback re-enters `performSubmit(_:)`.
        guard OnDeviceVerificationConsent.hasConsented else {
            showConsentSheet = true
            return
        }

        performSubmit(image: image)
    }

    private func performSubmit(image: UIImage) {
        let trimmedURL = certificateURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        let persistedURL: String?

        if trimmedURL.isEmpty {
            // URL omitted — that's allowed. Image is the only verification input.
            persistedURL = nil
        } else {
            // User typed something → enforce the same strict validation as before so
            // garbage text doesn't silently get persisted.
            guard let url = URL(string: trimmedURL), url.scheme != nil, url.host != nil else {
                submissionError = questLocalizedText("gym.quest.learning.proof.errorInvalidURL")
                return
            }
            guard option.isURLFromAllowedDomain(url) else {
                submissionError = String(
                    format: questLocalizedText("gym.quest.learning.proof.errorDomain"),
                    questLocalizedText(option.providerDisplayKey)
                )
                return
            }
            persistedURL = trimmedURL
        }

        submissionError = nil
        rejectionReason = nil
        isSubmitting = true
        localStatus = .pending

        let relativePath = proofStore.saveCertificateImage(image, for: quest.id)
        proofStore.markSubmission(
            questId: quest.id,
            certificateImageRelativePath: relativePath,
            certificateURL: persistedURL
        )

        let userFirstName = Self.firstName(from: resolvedUserDisplayName())
        let course = option.course

        Task {
            let verdict = await CertificateVerifier.shared.verify(
                image: image,
                course: course,
                userFirstName: userFirstName,
                questId: quest.id
            )
            await MainActor.run {
                applyVerifierResult(verdict)
            }
        }
    }

    /// Maps the on-device `CertificateVerifier.Result` into the persisted proof record
    /// and the local view state. Nothing here touches the network.
    private func applyVerifierResult(_ verdict: CertificateVerifier.Result) {
        switch verdict {
        case let .verified(confidence, message):
            let result = LearningProofVerificationResult(
                status: .verified,
                confidence: confidence,
                extractedName: nil,
                extractedCourseTitle: option.title,
                extractedProvider: option.canonicalProviderName,
                extractedCertificateURL: certificateURLText,
                rejectionReason: nil,
                notes: message
            )
            proofStore.applyVerificationResult(questId: quest.id, result: result)
            localStatus = .verified
            rejectionReason = nil
            captainMessage = message
            lastTechReason = nil
            isSubmitting = false
            onVerified()
            dismiss()

        case let .needsReview(reason, message):
            let result = LearningProofVerificationResult(
                status: .needsReview,
                confidence: nil,
                extractedName: nil,
                extractedCourseTitle: nil,
                extractedProvider: nil,
                extractedCertificateURL: certificateURLText,
                rejectionReason: reason,
                notes: message
            )
            proofStore.applyVerificationResult(questId: quest.id, result: result)
            localStatus = .needsReview
            rejectionReason = message  // user-visible warm copy
            captainMessage = message
            lastTechReason = reason
            isSubmitting = false

        case let .rejected(reason, message):
            let result = LearningProofVerificationResult(
                status: .rejected,
                confidence: nil,
                extractedName: nil,
                extractedCourseTitle: nil,
                extractedProvider: nil,
                extractedCertificateURL: certificateURLText,
                rejectionReason: reason,
                notes: message
            )
            proofStore.applyVerificationResult(questId: quest.id, result: result)
            localStatus = .rejected
            rejectionReason = message
            lastTechReason = reason
            captainMessage = message
            isSubmitting = false
        }
    }

    private static func firstName(from full: String?) -> String {
        guard let full = full?.trimmingCharacters(in: .whitespacesAndNewlines),
              !full.isEmpty else { return "" }
        return full.split(separator: " ").first.map(String.init) ?? full
    }

    // MARK: - Derived state

    private var canSubmit: Bool {
        // URL is optional. Image is the only gating input — it's what the on-device
        // verifier actually needs. Empty URL is valid; `performSubmit` persists nil.
        certificateImage != nil && localStatus != .verified
    }

    private var submitButtonTitle: String {
        switch localStatus {
        case .pending:
            return isSubmitting
                ? questLocalizedText("gym.quest.learning.proof.submitting")
                : questLocalizedText("gym.quest.learning.proof.submitForVerification")
        case .rejected, .needsReview:
            return questLocalizedText("gym.quest.learning.proof.retryVerification")
        case .verified:
            return questLocalizedText("gym.quest.learning.proof.verified")
        case .notSubmitted:
            return questLocalizedText("gym.quest.learning.proof.submitForVerification")
        }
    }

    private var statusLabel: String {
        switch localStatus {
        case .notSubmitted:
            return questLocalizedText("gym.quest.learning.status.notSubmitted")
        case .pending:
            return questLocalizedText("gym.quest.learning.status.pending")
        case .verified:
            return questLocalizedText("gym.quest.learning.status.verified")
        case .rejected:
            return questLocalizedText("gym.quest.learning.status.rejected")
        case .needsReview:
            return questLocalizedText("gym.quest.learning.status.needsReview")
        }
    }

    private var statusBadgeTint: Color {
        switch localStatus {
        case .notSubmitted:
            return Color(hex: "F5F5F5")
        case .pending:
            return Color(hex: "FDE2A7").opacity(0.9)
        case .verified:
            return Color(hex: "B7E5D2")
        case .rejected:
            return Color(hex: "F7C7C7")
        case .needsReview:
            return Color(hex: "F6C77A").opacity(0.9) // orange tint
        }
    }

    private var statusBadgeForeground: Color {
        Color(hex: "1A1A1A")
    }

    private func resolvedUserDisplayName() -> String? {
        let profile = UserProfileStore.shared.current
        let name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name }
        if let username = profile.username?.trimmingCharacters(in: .whitespacesAndNewlines), !username.isEmpty {
            return username
        }
        return nil
    }
}
