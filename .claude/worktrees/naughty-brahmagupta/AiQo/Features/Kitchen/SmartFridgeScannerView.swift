import AVFoundation
import os
import SwiftData
import SwiftUI
import UIKit

struct SmartFridgeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.layoutDirection) private var layoutDirection
    @EnvironmentObject private var kitchenStore: KitchenPersistenceStore

    @StateObject private var viewModel = SmartFridgeCameraViewModel()
    @State private var persistedResultID: UUID?
    @State private var scanLineTravel: CGFloat = -140

    private let neonBlue = Color(red: 0.34, green: 0.84, blue: 1.00)
    private let platinum = Color(red: 0.92, green: 0.95, blue: 1.00)

    var body: some View {
        ZStack {
            cameraOrFallback
            scannerOverlay
            topBar
            bottomControls
        }
        .background(Color.black.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden(false)
        .onAppear {
            startScanner()
        }
        .onDisappear {
            viewModel.stopSession()
        }
        .onChange(of: viewModel.latestResultID) { _, newValue in
            guard let newValue, persistedResultID != newValue else { return }
            persistDetectedItems(viewModel.analyzedItems)
            persistedResultID = newValue
        }
    }

    @ViewBuilder
    private var cameraOrFallback: some View {
        switch viewModel.permissionState {
        case .denied, .unavailable, .failed:
            SmartFridgePermissionFallbackView(
                titleKey: titleKeyForPermissionState,
                messageKey: messageKeyForPermissionState,
                onOpenSettings: openSettings,
                onDismiss: { dismiss() }
            )
        default:
            ZStack {
                SmartFridgeCameraPreviewRepresentable(session: viewModel.captureSession)
                    .ignoresSafeArea()

                if let capturedImage = viewModel.capturedImage {
                    Image(uiImage: capturedImage)
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
            }
        }
    }

    private var scannerOverlay: some View {
        ZStack {
            Color.black.opacity(viewModel.scanPhase == .previewing ? 0.18 : 0.42)
                .ignoresSafeArea()

            if viewModel.permissionState == .granted || viewModel.permissionState == .requesting || viewModel.permissionState == .idle {
                GeometryReader { geometry in
                    let frameWidth = min(geometry.size.width - 56, 320)
                    let frameHeight = frameWidth * 1.18

                    ZStack {
                        scannerFrame(width: frameWidth, height: frameHeight)
                        if viewModel.scanPhase == .previewing {
                            scanningLine(width: frameWidth - 18)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .allowsHitTesting(false)
            }

            if viewModel.scanPhase == .processing {
                SmartFridgeProcessingOverlay(
                    processingTextKey: viewModel.processingTextKey,
                    neonBlue: neonBlue,
                    platinum: platinum
                )
            }

            if viewModel.scanPhase == .completed, let capturedImage = viewModel.capturedImage {
                SmartFridgeResultsOverlay(
                    image: capturedImage,
                    items: viewModel.analyzedItems,
                    onDone: { dismiss() },
                    onScanAgain: {
                        persistedResultID = nil
                        viewModel.resetScanner()
                    }
                )
            }

            if viewModel.scanPhase == .error {
                SmartFridgeErrorOverlay(
                    messageKey: viewModel.errorTextKey ?? "kitchen.scanner.processing.failed",
                    onRetry: {
                        persistedResultID = nil
                        viewModel.resetScanner()
                    }
                )
            }
        }
    }

    private var topBar: some View {
        VStack {
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: layoutDirection == .rightToLeft ? "chevron.right" : "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(platinum)
                        .frame(width: 46, height: 46)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(platinum.opacity(0.18), lineWidth: 1))
                }
                .frame(minWidth: 44, minHeight: 44)

                Spacer()

                VStack(spacing: 4) {
                    Text("kitchen.scanner.title".localized)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(platinum)
                    Text("kitchen.scanner.subtitle".localized)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(platinum.opacity(0.74))
                }

                Spacer()

                Circle()
                    .fill(neonBlue.opacity(0.18))
                    .frame(width: 46, height: 46)
                    .overlay(
                        Image(systemName: "sparkles")
                            .foregroundStyle(neonBlue)
                    )
                    .overlay(Circle().stroke(neonBlue.opacity(0.35), lineWidth: 1))
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            Spacer()
        }
        .ignoresSafeArea(edges: .top)
    }

    @ViewBuilder
    private var bottomControls: some View {
        VStack {
            Spacer()

            if viewModel.permissionState == .granted || viewModel.permissionState == .requesting || viewModel.permissionState == .idle {
                if viewModel.scanPhase == .previewing || viewModel.scanPhase == .capturing {
                    HStack {
                        Spacer()

                        VStack(spacing: 14) {
                            Text("kitchen.scanner.hint".localized)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(platinum.opacity(0.72))

                            Button {
                                viewModel.captureAndAnalyze()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [neonBlue, platinum],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 82, height: 82)
                                        .shadow(color: neonBlue.opacity(0.45), radius: 16, x: 0, y: 0)

                                    Circle()
                                        .stroke(Color.black.opacity(0.35), lineWidth: 2)
                                        .frame(width: 66, height: 66)

                                    Text("kitchen.scanner.capture".localized)
                                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                                        .foregroundStyle(.black)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .frame(minWidth: 88, minHeight: 88)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 30, style: .continuous)
                                    .stroke(platinum.opacity(0.14), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 18)
                    .padding(.bottom, 22)
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func scannerFrame(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(platinum.opacity(0.18), lineWidth: 1)
                .frame(width: width, height: height)
                .background(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(Color.black.opacity(0.06))
                )

            SmartFridgeViewfinderCorners(color: neonBlue)
                .frame(width: width, height: height)

            VStack {
                Text("kitchen.scanner.viewfinder".localized)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(platinum)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 18)
                Spacer()
            }
            .frame(width: width, height: height)
        }
    }

    private func scanningLine(width: CGFloat) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.clear, neonBlue.opacity(0.95), Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: width, height: 3)
            .shadow(color: neonBlue.opacity(0.8), radius: 10, x: 0, y: 0)
            .offset(y: scanLineTravel)
            .onAppear {
                scanLineTravel = -140
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    scanLineTravel = 140
                }
            }
    }

    private var titleKeyForPermissionState: String {
        switch viewModel.permissionState {
        case .unavailable:
            return "kitchen.scanner.permission.unavailable.title"
        default:
            return "kitchen.scanner.permission.denied.title"
        }
    }

    private var messageKeyForPermissionState: String {
        switch viewModel.permissionState {
        case .unavailable:
            return "kitchen.scanner.permission.unavailable.message"
        default:
            return "kitchen.scanner.permission.denied.message"
        }
    }

    private func startScanner() {
        persistedResultID = nil
        viewModel.startSession()
    }

    private func persistDetectedItems(_ items: [FridgeItem]) {
        guard !items.isEmpty else { return }

        kitchenStore.addFridgeItems(items)

        let stamp = Date()
        for item in items {
            modelContext.insert(SmartFridgeScannedItemRecord(item: item, capturedAt: stamp))
        }

        do {
            try modelContext.save()
        } catch {
            os_log(.fault, "Failed to save scanned fridge items: %{public}@", String(describing: error))
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private struct SmartFridgePermissionFallbackView: View {
    let titleKey: String
    let messageKey: String
    let onOpenSettings: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.07, green: 0.10, blue: 0.16)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 92, height: 92)
                    .overlay(
                        Image(systemName: "camera.aperture")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(Color(red: 0.34, green: 0.84, blue: 1.00))
                    )

                Text(titleKey.localized)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(messageKey.localized)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.74))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                VStack(spacing: 12) {
                    Button(action: onOpenSettings) {
                        Text("kitchen.scanner.permission.settings".localized)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color(red: 0.34, green: 0.84, blue: 1.00), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .frame(minWidth: 44, minHeight: 44)

                    Button(action: onDismiss) {
                        Text("kitchen.scanner.permission.close".localized)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }
                .padding(.top, 4)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .padding(24)
        }
    }
}

private struct SmartFridgeProcessingOverlay: View {
    let processingTextKey: String
    let neonBlue: Color
    let platinum: Color

    @State private var pulse = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(neonBlue.opacity(0.24), lineWidth: 18)
                    .frame(width: 116, height: 116)
                    .scaleEffect(pulse ? 1.06 : 0.94)

                Circle()
                    .trim(from: 0.12, to: 0.82)
                    .stroke(
                        LinearGradient(colors: [neonBlue, platinum], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 92, height: 92)
                    .rotationEffect(.degrees(pulse ? 360 : 0))

                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(platinum)
            }

            Text("kitchen.scanner.processing.title".localized)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(platinum)

            Text(processingTextKey.localized)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(platinum.opacity(0.72))
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black.opacity(0.62))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(platinum.opacity(0.12), lineWidth: 1)
                )
        )
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                pulse.toggle()
            }
        }
    }
}

private struct SmartFridgeResultsOverlay: View {
    let image: UIImage
    let items: [FridgeItem]
    let onDone: () -> Void
    let onScanAgain: () -> Void

    var body: some View {
        VStack {
            Spacer(minLength: 80)

            VStack(spacing: 16) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text("kitchen.scanner.results.title".localized)
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                    Text("kitchen.scanner.results.subtitle".localized)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 10) {
                    ForEach(items) { item in
                        HStack(alignment: .top, spacing: 12) {
                            Circle()
                                .fill(Color.kitchenMint.opacity(0.8))
                                .frame(width: 42, height: 42)
                                .overlay(
                                    Image(systemName: "shippingbox.fill")
                                        .foregroundStyle(.black)
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                Text(quantityText(for: item))
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                                if let alchemyNote = item.localizedAlchemyNote {
                                    Text(alchemyNote)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Color(red: 0.19, green: 0.49, blue: 0.90))
                                }
                            }

                            Spacer()
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                }

                HStack(spacing: 12) {
                    Button(action: onScanAgain) {
                        Text("kitchen.scanner.results.scanAgain".localized)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .frame(minWidth: 44, minHeight: 44)

                    Button(action: onDone) {
                        Text("kitchen.scanner.results.done".localized)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Color.kitchenMint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }
            }
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func quantityText(for item: FridgeItem) -> String {
        let value: String
        if item.quantity.rounded() == item.quantity {
            value = "\(Int(item.quantity))"
        } else {
            value = String(format: "%.1f", item.quantity)
        }

        if let unit = item.unit, !unit.isEmpty {
            return "\(value) \(unit)"
        }

        return value
    }
}

private struct SmartFridgeErrorOverlay: View {
    let messageKey: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Color.orange)

            Text("kitchen.scanner.error.title".localized)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            Text(messageKey.localized)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.74))
                .multilineTextAlignment(.center)

            Button(action: onRetry) {
                Text("kitchen.scanner.error.retry".localized)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Color.kitchenMint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .frame(minWidth: 44, minHeight: 44)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .padding(24)
    }
}

private struct SmartFridgeViewfinderCorners: View {
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let cornerLength = min(size.width, size.height) * 0.14
            let lineWidth: CGFloat = 4

            ZStack {
                corner(top: true, leading: true, length: cornerLength, lineWidth: lineWidth)
                    .position(x: cornerLength / 2 + 16, y: cornerLength / 2 + 16)
                corner(top: true, leading: false, length: cornerLength, lineWidth: lineWidth)
                    .position(x: size.width - cornerLength / 2 - 16, y: cornerLength / 2 + 16)
                corner(top: false, leading: true, length: cornerLength, lineWidth: lineWidth)
                    .position(x: cornerLength / 2 + 16, y: size.height - cornerLength / 2 - 16)
                corner(top: false, leading: false, length: cornerLength, lineWidth: lineWidth)
                    .position(x: size.width - cornerLength / 2 - 16, y: size.height - cornerLength / 2 - 16)
            }
        }
    }

    private func corner(top: Bool, leading: Bool, length: CGFloat, lineWidth: CGFloat) -> some View {
        Path { path in
            let horizontalStart = CGPoint(x: leading ? 0 : length, y: top ? 0 : length)
            let horizontalEnd = CGPoint(x: leading ? length : 0, y: top ? 0 : length)
            let verticalStart = CGPoint(x: leading ? 0 : length, y: top ? 0 : length)
            let verticalEnd = CGPoint(x: leading ? 0 : length, y: top ? length : 0)

            path.move(to: horizontalStart)
            path.addLine(to: horizontalEnd)
            path.move(to: verticalStart)
            path.addLine(to: verticalEnd)
        }
        .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        .frame(width: length, height: length)
        .shadow(color: color.opacity(0.7), radius: 8, x: 0, y: 0)
    }
}
