import UIKit
import HealthKit

// MARK: - Inline expand/collapse
extension HomeViewController {

    func toggleInlineDetail(for kind: MetricKind, originalView: MetricView) {
        if expandedKind == kind {
            collapseExpandedCard()
            return
        }
        if expandedKind != nil {
            collapseExpandedCard()
        }

        guard let (row, col) = kindToIndexPath[kind],
              row < rowStacks.count else { return }

        let rowStack = rowStacks[row]
        let tint = (originalView.backgroundColor ?? UIColor.secondarySystemBackground)

        let detail = MetricDetailCardView(kind: kind, tint: tint)
        detail.translatesAutoresizingMaskIntoConstraints = false

        if let s = currentSummaryCache {
            detail.setHeaderValue(formattedHeader(for: kind, from: s))
        }

        detail.onClose = { [weak self] in
            self?.collapseExpandedCard()
        }

        detail.onScopeChange = { [weak self, weak detail] scope in
            guard let self, let detail else { return }
            self.loadSeries(for: kind, scope: scope) { values, totalText in
                detail.setHeaderValue(totalText)
                detail.setSeries(values)
            }
        }

        rowStack.insertArrangedSubview(detail, at: col)
        rowStack.removeArrangedSubview(originalView)
        originalView.removeFromSuperview()

        detail.heightAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true
        expandedKind = kind

        loadSeries(for: kind, scope: .day) { [weak detail] values, totalText in
            detail?.setHeaderValue(totalText)
            detail?.setSeries(values)
        }
    }

    func collapseExpandedCard() {
        guard let kind = expandedKind,
              let (row, col) = kindToIndexPath[kind],
              row < rowStacks.count else {
            expandedKind = nil
            return
        }

        let rowStack = rowStacks[row]
        guard rowStack.arrangedSubviews.indices.contains(col) else {
            expandedKind = nil
            return
        }

        let currentView = rowStack.arrangedSubviews[col]
        let tint = currentView.backgroundColor ?? UIColor.secondarySystemBackground

        let v = MetricView(kind: kind, tint: tint)
        v.onTap = { [weak self, weak v] in
            guard let self, let v else { return }
            self.toggleInlineDetail(for: v.kind, originalView: v)
        }

        if let s = currentSummaryCache {
            applySummary(s)
        }

        rowStack.insertArrangedSubview(v, at: col)
        rowStack.removeArrangedSubview(currentView)
        currentView.removeFromSuperview()

        if let idx = metrics.firstIndex(where: { $0.kind == kind }) {
            metrics[idx] = v
        }

        expandedKind = nil
    }
}
