import SwiftUI

// MARK: - Record Detail View (Full-screen push navigation)

struct RecordDetailView: View {
    let record: LegendaryRecord
    @ObservedObject var viewModel: LegendaryChallengesViewModel
    @State private var navigateToProject = false
    @State private var navigateToRecordProject = false
    @State private var showActiveProjectAlert = false
    @State private var isGeneratingPlan = false
    @State private var newRecordProject: RecordProject?
    // CHANGED: New state for fitness assessment navigation
    @State private var navigateToAssessment = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                heroSection
                infoCardsRow
                storySection
                requirementsSection
                ctaButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(Color.white.ignoresSafeArea())
        .navigationTitle(NSLocalizedString("recordDetail.title", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToProject) {
            if let project = viewModel.activeProject {
                ProjectView(viewModel: viewModel, project: project)
            }
        }
        .navigationDestination(isPresented: $navigateToRecordProject) {
            if let project = newRecordProject {
                RecordProjectView(project: project)
            }
        }
        // CHANGED: Navigation destination for HRR fitness assessment
        .navigationDestination(isPresented: $navigateToAssessment) {
            FitnessAssessmentView(record: record)
        }
        .alert(NSLocalizedString("recordDetail.activeProjectAlert", comment: ""), isPresented: $showActiveProjectAlert) {
            Button(NSLocalizedString("recordDetail.ok", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("recordDetail.activeProjectMessage", comment: ""))
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 12) {
            // DESIGN: SF Symbol icon in circle with mint background
            Image(systemName: record.iconName)
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.6))
                .frame(width: 80, height: 80)
                .background(
                    Circle()
                        .fill(GymTheme.mint.opacity(0.3))
                )

            // DESIGN: Large record number — mint color, centered
            Text(record.formattedTarget)
                .font(.system(size: 56, weight: .heavy, design: .rounded))
                .foregroundStyle(GymTheme.mint)

            Text(record.unit)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary.opacity(0.5))

            // Record title
            Text(record.titleAr)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary)

            // Record holder
            Text("\(record.recordHolderAr) \(record.country) • \(String(record.year))")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Info Cards Row (3 cards)

    private var infoCardsRow: some View {
        HStack(spacing: 10) {
            infoCard(title: NSLocalizedString("recordDetail.difficulty", comment: ""), value: record.difficulty.labelAr, color: GymTheme.beige)
            infoCard(title: NSLocalizedString("recordDetail.estimatedDuration", comment: ""), value: "\(record.estimatedWeeks) \(NSLocalizedString("recordDetail.weeks", comment: ""))", color: GymTheme.mint)
            infoCard(title: NSLocalizedString("recordDetail.category", comment: ""), value: record.category.rawValue, color: GymTheme.beige)
        }
    }

    private func infoCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.45))

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(color.opacity(0.2))
        )
    }

    // MARK: - Story Section

    private var storySection: some View {
        VStack(alignment: .trailing, spacing: 10) {
            Text(NSLocalizedString("recordDetail.story", comment: ""))
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.primary)

            Text(record.storyAr)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color.primary.opacity(0.7))
                .multilineTextAlignment(.trailing)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "F7F7F7"))
        )
    }

    // MARK: - Requirements Section

    private var requirementsSection: some View {
        VStack(alignment: .trailing, spacing: 10) {
            Text(NSLocalizedString("recordDetail.requirements", comment: ""))
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.primary)

            ForEach(record.requirementsAr, id: \.self) { req in
                HStack(spacing: 8) {
                    Text(req)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.65))

                    Circle()
                        .fill(GymTheme.mint)
                        .frame(width: 6, height: 6)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "F7F7F7"))
        )
    }

    // MARK: - CTA Button

    // DESIGN: Full-width rounded button, Mint background, bold black Arabic text
    private var ctaButton: some View {
        // CHANGED: CTA now navigates to FitnessAssessmentView instead of creating project directly
        Button {
            // التحقق: هل في مشروع نشط
            if !RecordProjectManager.shared.canStartNewProject() {
                showActiveProjectAlert = true
                return
            }

            // بدء المشروع القديم (UserDefaults) للتوافق
            viewModel.startProject(for: record)

            // CHANGED: Navigate to fitness assessment instead of creating project here
            navigateToAssessment = true
        } label: {
            HStack {
                Spacer()
                Text(NSLocalizedString("recordDetail.startProject", comment: ""))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                Spacer()
            }
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(GymTheme.mint.opacity(0.5))
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        RecordDetailView(
            record: LegendaryRecord.seedRecords[0],
            viewModel: LegendaryChallengesViewModel()
        )
    }
    .environment(\.layoutDirection, .rightToLeft)
}
