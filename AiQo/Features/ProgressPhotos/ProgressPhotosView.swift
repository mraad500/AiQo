import SwiftUI
import PhotosUI

// MARK: - Palette

private enum ProgressPalette {
    static let backgroundTop = Color(red: 0.996, green: 0.988, blue: 0.973)    // #FEFCF8
    static let backgroundBottom = Color(red: 0.953, green: 0.925, blue: 0.882)  // #F3ECE1
    static let mint = Color(red: 0.718, green: 0.890, blue: 0.792)              // #B7E3CA
    static let sand = Color(red: 0.922, green: 0.780, blue: 0.576)              // #EBC793
    static let pearl = Color(red: 1.0, green: 0.973, blue: 0.937)              // #FFF8EF
    static let textPrimary = Color.black.opacity(0.84)
    static let textSecondary = Color.black.opacity(0.58)
    static let glassCard = Color.white.opacity(0.72)
    static let glassBorder = Color.white.opacity(0.66)
}

// MARK: - Main View

/// شاشة صور التقدم — تتبع التحول الجسدي مع مقارنة Before/After
struct ProgressPhotosView: View {
    @StateObject private var store = ProgressPhotoStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showAddSheet = false
    @State private var showCompare = false

    @State private var capturedImage: UIImage?
    @State private var inputWeight: String = ""
    @State private var inputNote: String = ""
    @State private var loadedImages: [String: UIImage] = [:]

    var body: some View {
        NavigationStack {
            ZStack {
                // الخلفية
                LinearGradient(
                    colors: [ProgressPalette.backgroundTop, ProgressPalette.backgroundBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                if store.entries.isEmpty {
                    emptyState
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 20) {
                            // ملخص التقدم
                            progressSummaryCard

                            // المقارنة السريعة
                            if store.entries.count >= 2 {
                                quickCompareCard
                            }

                            // شبكة الصور
                            photoGridSection
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle("صور التقدم")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(ProgressPalette.textSecondary)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(ProgressPalette.mint)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                addPhotoSheet
            }
            .sheet(isPresented: $showCompare) {
                if let first = store.firstEntry, let latest = store.latestEntry {
                    ComparePhotosSheet(
                        firstEntry: first,
                        latestEntry: latest,
                        store: store
                    )
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                ProgressCameraView { image in
                    capturedImage = image
                    showCamera = false
                }
            }
            .task(id: store.entries.count) {
                await preloadImages()
            }
        }
    }

    private func preloadImages() async {
        let entries = store.entries
        var result: [String: UIImage] = [:]
        for entry in entries {
            if let img = await store.loadImageAsync(for: entry) {
                result[entry.id] = img
            }
        }
        loadedImages = result
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "camera.viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(ProgressPalette.mint)

            VStack(spacing: 8) {
                Text("ابدأ رحلة التحول")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(ProgressPalette.textPrimary)

                Text("صوّر جسمك كل أسبوع وشوف الفرق بعينك.\nالصور تنحفظ على جهازك فقط.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ProgressPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Button {
                showAddSheet = true
            } label: {
                Label("أضف أول صورة", systemImage: "camera.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [ProgressPalette.mint, ProgressPalette.mint.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
            }

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Progress Summary Card

    private var progressSummaryCard: some View {
        HStack(spacing: 0) {
            summaryItem(
                value: "\(store.totalPhotos)",
                label: "صورة",
                icon: "photo.stack.fill",
                tint: ProgressPalette.mint
            )

            if let firstEntry = store.firstEntry {
                Divider()
                    .frame(height: 36)
                    .padding(.horizontal, 4)

                summaryItem(
                    value: "\(firstEntry.daysSinceCapture)",
                    label: "يوم",
                    icon: "calendar",
                    tint: ProgressPalette.sand
                )
            }

            if let weightChange = store.weightChange {
                Divider()
                    .frame(height: 36)
                    .padding(.horizontal, 4)

                summaryItem(
                    value: String(format: "%+.1f", weightChange),
                    label: "كغم",
                    icon: "scalemass.fill",
                    tint: weightChange <= 0 ? .green : .orange
                )
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(glassCard)
    }

    private func summaryItem(value: String, label: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(tint)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(ProgressPalette.textPrimary)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ProgressPalette.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Quick Compare Card

    private var quickCompareCard: some View {
        Button {
            showCompare = true
        } label: {
            HStack(spacing: 16) {
                // أول صورة (مصغّرة)
                if let first = store.firstEntry, let img = loadedImages[first.id] {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("قارن التقدم")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(ProgressPalette.textPrimary)

                    Text("شوف الفرق بين أول صورة وآخر صورة")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ProgressPalette.textSecondary)
                }

                Spacer()

                // آخر صورة (مصغّرة)
                if let latest = store.latestEntry, let img = loadedImages[latest.id] {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ProgressPalette.textSecondary)
            }
            .padding(16)
            .background(
                glassCard
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Photo Grid

    private var photoGridSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("الألبوم")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(ProgressPalette.textPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ], spacing: 10) {
                ForEach(store.entries) { entry in
                    PhotoGridCell(entry: entry, store: store)
                }
            }
        }
    }

    // MARK: - Add Photo Sheet

    private var addPhotoSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // صورة ملتقطة أو مختارة
                if let image = capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(ProgressPalette.glassBorder, lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                } else {
                    // أزرار اختيار الصورة
                    VStack(spacing: 14) {
                        sourceButton(
                            title: "التقط صورة",
                            subtitle: "استخدم الكاميرا",
                            icon: "camera.fill",
                            tint: ProgressPalette.mint
                        ) {
                            showCamera = true
                            showAddSheet = false
                        }

                        PhotosPicker(
                            selection: $selectedPhoto,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            sourceButtonLabel(
                                title: "اختر من المعرض",
                                subtitle: "من ألبوم الصور",
                                icon: "photo.on.rectangle",
                                tint: ProgressPalette.sand
                            )
                        }
                        .onChange(of: selectedPhoto) { _, newValue in
                            Task {
                                if let data = try? await newValue?.loadTransferable(type: Data.self),
                                   let image = UIImage(data: data) {
                                    capturedImage = image
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }

                // إدخال الوزن
                if capturedImage != nil {
                    VStack(spacing: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: "scalemass.fill")
                                .foregroundStyle(ProgressPalette.sand)
                                .frame(width: 24)

                            TextField("الوزن (اختياري)", text: $inputWeight)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.plain)

                            Text("كغم")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(ProgressPalette.textSecondary)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(ProgressPalette.pearl)
                        )

                        HStack(spacing: 12) {
                            Image(systemName: "note.text")
                                .foregroundStyle(ProgressPalette.mint)
                                .frame(width: 24)

                            TextField("ملاحظة (اختياري)", text: $inputNote)
                                .textFieldStyle(.plain)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(ProgressPalette.pearl)
                        )
                    }
                    .padding(.horizontal, 20)
                }

                Spacer()

                // زر الحفظ
                if capturedImage != nil {
                    Button {
                        savePhoto()
                    } label: {
                        Text("حفظ الصورة ✨")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [ProgressPalette.mint, Color(red: 0.55, green: 0.82, blue: 0.68)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .background(
                LinearGradient(
                    colors: [ProgressPalette.backgroundTop, ProgressPalette.backgroundBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("صورة جديدة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("إلغاء") {
                        resetInputs()
                        showAddSheet = false
                    }
                    .foregroundStyle(ProgressPalette.textSecondary)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Source Button

    private func sourceButton(title: String, subtitle: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            sourceButtonLabel(title: title, subtitle: subtitle, icon: icon, tint: tint)
        }
        .buttonStyle(.plain)
    }

    private func sourceButtonLabel(title: String, subtitle: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(tint)
                .frame(width: 48, height: 48)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(ProgressPalette.textPrimary)

                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ProgressPalette.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.left")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ProgressPalette.textSecondary)
        }
        .padding(16)
        .background(glassCard)
    }

    // MARK: - Helpers

    private var glassCard: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(ProgressPalette.glassCard)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(ProgressPalette.glassBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }

    private func savePhoto() {
        guard let image = capturedImage else { return }
        let weight = Double(inputWeight)
        let note = inputNote.isEmpty ? nil : inputNote
        store.addEntry(image: image, weight: weight, note: note)
        resetInputs()
        showAddSheet = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func resetInputs() {
        capturedImage = nil
        inputWeight = ""
        inputNote = ""
        selectedPhoto = nil
    }
}

// MARK: - Photo Grid Cell

private struct PhotoGridCell: View {
    let entry: ProgressPhotoEntry
    let store: ProgressPhotoStore

    @State private var showDetail = false
    @State private var loadedImage: UIImage?

    var body: some View {
        Button {
            showDetail = true
        } label: {
            ZStack(alignment: .bottomLeading) {
                if let image = loadedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 140)
                        .overlay(ProgressView())
                }

                // التاريخ
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.shortDate)
                        .font(.system(size: 10, weight: .bold, design: .rounded))

                    if let w = entry.weightKg {
                        Text(String(format: "%.1f كغم", w))
                            .font(.system(size: 9, weight: .medium))
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .padding(6)
            }
        }
        .buttonStyle(.plain)
        .task {
            loadedImage = await store.loadImageAsync(for: entry)
        }
        .sheet(isPresented: $showDetail) {
            PhotoDetailSheet(entry: entry, store: store)
        }
    }
}

// MARK: - Photo Detail Sheet

private struct PhotoDetailSheet: View {
    let entry: ProgressPhotoEntry
    let store: ProgressPhotoStore
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @State private var loadedImage: UIImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let image = loadedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .padding(.horizontal, 16)
                    } else {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 300)
                            .overlay(ProgressView())
                            .padding(.horizontal, 16)
                    }

                    // التفاصيل
                    VStack(spacing: 14) {
                        detailRow(icon: "calendar", label: "التاريخ", value: entry.formattedDate)

                        if let weight = entry.weightKg {
                            detailRow(icon: "scalemass.fill", label: "الوزن", value: String(format: "%.1f كغم", weight))
                        }

                        if let note = entry.note, !note.isEmpty {
                            detailRow(icon: "note.text", label: "ملاحظة", value: note)
                        }

                        detailRow(icon: "clock", label: "من", value: "\(entry.daysSinceCapture) يوم")
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(ProgressPalette.glassCard)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(ProgressPalette.glassBorder, lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 16)

                    // زر الحذف
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("حذف الصورة", systemImage: "trash")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .padding(.top, 8)
                }
                .padding(.bottom, 40)
            }
            .background(
                LinearGradient(
                    colors: [ProgressPalette.backgroundTop, ProgressPalette.backgroundBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle(entry.shortDate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .alert("حذف الصورة؟", isPresented: $showDeleteConfirm) {
                Button("حذف", role: .destructive) {
                    store.deleteEntry(entry)
                    dismiss()
                }
                Button("إلغاء", role: .cancel) {}
            } message: {
                Text("هالصورة بتنحذف نهائياً من الجهاز.")
            }
            .task {
                loadedImage = await store.loadImageAsync(for: entry)
            }
        }
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(ProgressPalette.mint)
                .frame(width: 24)

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ProgressPalette.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(ProgressPalette.textPrimary)
        }
    }
}

// MARK: - Compare Photos Sheet

struct ComparePhotosSheet: View {
    let firstEntry: ProgressPhotoEntry
    let latestEntry: ProgressPhotoEntry
    let store: ProgressPhotoStore
    @Environment(\.dismiss) private var dismiss

    @State private var sliderValue: CGFloat = 0.5
    @State private var firstImage: UIImage?
    @State private var latestImage: UIImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // العنوان
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("البداية")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(ProgressPalette.sand)
                        Text(firstEntry.shortDate)
                            .font(.system(size: 11))
                            .foregroundStyle(ProgressPalette.textSecondary)
                    }

                    Spacer()

                    if let w1 = firstEntry.weightKg, let w2 = latestEntry.weightKg {
                        let diff = w2 - w1
                        Text(String(format: "%+.1f كغم", diff))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(diff <= 0 ? .green : .orange)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill((diff <= 0 ? Color.green : Color.orange).opacity(0.1))
                            )
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("الحين")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(ProgressPalette.mint)
                        Text(latestEntry.shortDate)
                            .font(.system(size: 11))
                            .foregroundStyle(ProgressPalette.textSecondary)
                    }
                }
                .padding(.horizontal, 24)

                // المقارنة بالسلايدر
                GeometryReader { geo in
                    ZStack {
                        // الصورة الثانية (الأحدث) — كاملة بالخلف
                        if let latestImage {
                            Image(uiImage: latestImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        }

                        // الصورة الأولى (الأقدم) — مقطوعة بالسلايدر
                        if let firstImage {
                            Image(uiImage: firstImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                .mask(
                                    HStack(spacing: 0) {
                                        Rectangle()
                                            .frame(width: geo.size.width * sliderValue)
                                        Spacer(minLength: 0)
                                    }
                                )
                        }

                        // خط السلايدر
                        Rectangle()
                            .fill(.white)
                            .frame(width: 3)
                            .shadow(color: .black.opacity(0.3), radius: 4)
                            .position(x: geo.size.width * sliderValue, y: geo.size.height / 2)

                        // مقبض السلايدر
                        Circle()
                            .fill(.white)
                            .frame(width: 32, height: 32)
                            .shadow(color: .black.opacity(0.2), radius: 6)
                            .overlay(
                                Image(systemName: "arrow.left.and.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.gray)
                            )
                            .position(x: geo.size.width * sliderValue, y: geo.size.height / 2)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        sliderValue = min(max(value.location.x / geo.size.width, 0.05), 0.95)
                                    }
                            )

                        // Labels
                        HStack {
                            Text("قبل")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(ProgressPalette.sand.opacity(0.8)))
                                .padding(12)

                            Spacer()

                            Text("بعد")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(ProgressPalette.mint.opacity(0.8)))
                                .padding(12)
                        }
                        .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal, 18)

                Spacer(minLength: 0)
            }
            .padding(.top, 10)
            .background(
                LinearGradient(
                    colors: [ProgressPalette.backgroundTop, ProgressPalette.backgroundBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("المقارنة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .task {
                async let first = store.loadImageAsync(for: firstEntry)
                async let latest = store.loadImageAsync(for: latestEntry)
                firstImage = await first
                latestImage = await latest
            }
        }
    }
}

// MARK: - Camera View (UIKit Wrapper)

private struct ProgressCameraView: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraDevice = .front
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void

        init(onCapture: @escaping (UIImage) -> Void) {
            self.onCapture = onCapture
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Preview

#Preview {
    ProgressPhotosView()
}
