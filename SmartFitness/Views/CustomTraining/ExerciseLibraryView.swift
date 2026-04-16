import SwiftUI

struct ExerciseLibraryView: View {
    @EnvironmentObject var appData: AppData
    @StateObject private var store = ExerciseLibraryStore.shared
    @State private var searchText = ""
    @State private var selectedCategory = "ALL"
    @State private var selectedExercises: [LibraryExercise] = []
    @State private var sidebarLastFocusedKey: String?
    @State private var isSidebarDragging = false
    @FocusState private var isSearchFocused: Bool
    
    let categories = ["ALL", "CHEST", "BACK", "SHOULDERS", "LEGS", "ARMS", "ABDOMINALS", "GLUTES", "GYM", "HOME", "OUTDOOR"]
    private let muscleGroupOrder = ["CHEST", "BACK", "SHOULDERS", "LEGS", "ARMS", "ABDOMINALS", "GLUTES", "STRETCHING", "GYM", "HOME", "OUTDOOR", "OTHER"]
    private let muscleGroupTitles: [String: String] = [
        "ALL": "全部",
        "CHEST": "胸",
        "BACK": "背",
        "SHOULDERS": "肩",
        "LEGS": "腿",
        "ARMS": "手臂",
        "ABDOMINALS": "腹部",
        "GLUTES": "臀部",
        "STRETCHING": "放松拉伸",
        "GYM": "健身房",
        "HOME": "居家",
        "OUTDOOR": "户外",
        "OTHER": "其他"
    ]
    //健身房 居家 户外
    var filteredExercises: [LibraryExercise] {
        store.exercises.filter { exercise in
            let matchesSearch = matchesSearchText(exercise)
                               
            let matchesCategory = matchesSelectedCategory(for: exercise)
            return matchesSearch && matchesCategory
        }
    }
    
    private func matchesSelectedCategory(for exercise: LibraryExercise) -> Bool {
        if selectedCategory == "ALL" { return true }
        if ["GYM", "HOME", "OUTDOOR"].contains(selectedCategory) {
            return environmentKey(for: exercise) == selectedCategory
        }
        return muscleGroupKey(for: exercise) == selectedCategory
    }

    private func matchesSearchText(_ exercise: LibraryExercise) -> Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }

        // Split by any whitespace to support multi-keyword search.
        let keywords = trimmed
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        let searchTargets = [
            exercise.name,
            exercise.nameCN,
            exercise.equipment ?? ""
        ] + exercise.localizedMuscleNames

        // A keyword matches if it can be found in raw text OR whitespace-normalized text.
        // This allows matching names containing spaces even when users type with/without spaces.
        return keywords.allSatisfy { keyword in
            let normalizedKeyword = normalizedText(keyword)
            return searchTargets.contains { target in
                target.localizedCaseInsensitiveContains(keyword) ||
                normalizedText(target).contains(normalizedKeyword)
            }
        }
    }

    private func normalizedText(_ text: String) -> String {
        text
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
    }
    
    private var groupedExercises: [String: [LibraryExercise]] {
        Dictionary(grouping: filteredExercises) { exercise in
            muscleGroupKey(for: exercise)
        }
    }
    
    private var sortedGroupKeys: [String] {
        muscleGroupOrder.filter { key in
            !(groupedExercises[key] ?? []).isEmpty
        }
    }
    
    private func muscleGroupKey(for exercise: LibraryExercise) -> String {
        let allMuscles = (exercise.primaryMuscles + exercise.localizedMuscleNames).map { $0.uppercased() }
        if allMuscles.contains(where: { $0.contains("CHEST") || $0.contains("胸") }) { return "CHEST" }
        if allMuscles.contains(where: { $0.contains("BACK") || $0.contains("背") }) { return "BACK" }
        if allMuscles.contains(where: { $0.contains("SHOULDER") || $0.contains("肩") }) { return "SHOULDERS" }
        if allMuscles.contains(where: { $0.contains("LEG") || $0.contains("QUAD") || $0.contains("HAMSTRING") || $0.contains("CALF") || $0.contains("腿") }) { return "LEGS" }
        if allMuscles.contains(where: { $0.contains("ARM") || $0.contains("BICEP") || $0.contains("TRICEP") || $0.contains("手臂") }) { return "ARMS" }
        if allMuscles.contains(where: { $0.contains("AB") || $0.contains("CORE") || $0.contains("腹") }) { return "ABDOMINALS" }
        if allMuscles.contains(where: { $0.contains("GLUTE") || $0.contains("臀") || $0.contains("HIP") }) { return "GLUTES" }
        if allMuscles.contains(where: { $0.contains("STRETCH") || $0.contains("MOBILITY") || $0.contains("WARMUP") || $0.contains("COOLDOWN") || $0.contains("拉伸") || $0.contains("放松") }) { return "STRETCHING" }
        return "OTHER"
    }
    
    private func environmentKey(for exercise: LibraryExercise) -> String {
        let equipment = (exercise.equipment ?? "").uppercased()
        let category = exercise.category.uppercased()
        let name = exercise.name.uppercased()
        
        if equipment.contains("BARBELL") || equipment.contains("CABLE") || equipment.contains("MACHINE") ||
            equipment.contains("SMITH") || equipment.contains("DUMBBELL") || equipment.contains("KETTLEBELL") {
            return "GYM"
        }
        if equipment.contains("BODY ONLY") || equipment.contains("BODYWEIGHT") || equipment.contains("NONE") ||
            category.contains("STRETCHING") || category.contains("PLYOMETRICS") {
            return "HOME"
        }
        if category.contains("CARDIO") || name.contains("RUN") || name.contains("SPRINT") || name.contains("JOG") {
            return "OUTDOOR"
        }
        return "GYM"
    }
    
    var body: some View {
        ZStack {
            StitchTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerSection
                    .padding(.bottom, 8)
                
                // Content
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 24) {
                            searchSection
                            categoryChipsSection(proxy: proxy)
                            exerciseGridSection(proxy: proxy)
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 120) // Extra padding for the floating button
                    }
                    .scrollDismissesKeyboard(.immediately)
                    .overlay(indexSidebar(proxy: proxy), alignment: .trailing)
                }
            }
            
            // Floating Confirm Button
            if !selectedExercises.isEmpty {
                confirmButtonSection
            }
            
            if store.isLoading {
                ProgressView()
                    .tint(StitchTheme.primaryContainer)
                    .scaleEffect(1.5)
            }
        }
        .navigationBarHidden(true)
        .preferredColorScheme(.dark)
    }
    
    @ViewBuilder
    private var headerSection: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(appData.replacementTargetId != nil ? NSLocalizedString("REPLACEMENT MODE", comment: "") : NSLocalizedString("LIBRARY", comment: ""))
                    .font(StitchTypography.headlineLarge)
                    .italic()
                    .foregroundColor(StitchTheme.primaryContainer)
            }
            Spacer()
            
            if !selectedExercises.isEmpty {
                HStack(spacing: 10) {
                    Text("\(NSLocalizedString("SELECTED: ", comment: ""))\(selectedExercises.count)")
                        .font(StitchTypography.label)
                        .foregroundColor(StitchTheme.primaryContainer)
                    
                    Button("取消全选") {
                        selectedExercises = []
                    }
                    .font(StitchTypography.labelSmall)
                    .foregroundColor(StitchTheme.onPrimaryFixed)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(StitchTheme.primaryContainer.opacity(0.9))
                    .cornerRadius(6)
                }
                .padding(.bottom, 8)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .overlay(
            LinearGradient(
                colors: [StitchTheme.primaryContainer, StitchTheme.primaryContainer.opacity(0.1), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 2)
            .padding(.horizontal, 24)
            .offset(y: 8),
            alignment: .bottom
        )
    }
    
    @ViewBuilder
    private var searchSection: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(StitchTheme.onSurfaceVariant)
            TextField(NSLocalizedString("SEARCH EXERCISES...", comment: ""), text: $searchText)
                .font(StitchTypography.label)
                .tracking(1.0)
                .foregroundColor(StitchTheme.onSurface)
                .submitLabel(.search)
                .focused($isSearchFocused)
        }
        .padding(16)
        .background(StitchTheme.surfaceContainerLow)
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            isSearchFocused = true
        }
        .padding(.horizontal, 24)
    }
    
    @ViewBuilder
    private func categoryChipsSection(proxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedCategory = category
                        }
                        if category != "ALL" {
                            DispatchQueue.main.async {
                                scrollToSection(category, proxy: proxy)
                            }
                        }
                    } label: {
                        Text(muscleGroupTitles[category] ?? category)
                            .font(StitchTypography.label)
                            .tracking(1.5)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(selectedCategory == category ? StitchTheme.primaryContainer : StitchTheme.surfaceContainerHigh)
                            .foregroundColor(selectedCategory == category ? StitchTheme.onPrimaryFixed : StitchTheme.onSurfaceVariant)
                            .cornerRadius(4)
                            .shadow(color: selectedCategory == category ? StitchTheme.primaryContainer.opacity(0.2) : .clear, radius: 10)
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }
    
    @ViewBuilder
    private func exerciseGridSection(proxy: ScrollViewProxy) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ]
        
        if filteredExercises.isEmpty {
            VStack(spacing: 20) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 60))
                    .foregroundColor(StitchTheme.surfaceContainerHighest)
                Text("NO EXERCISES FOUND")
                    .font(StitchTypography.label)
                    .foregroundColor(StitchTheme.onSurfaceVariant)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
        } else {
            VStack(alignment: .leading, spacing: 32) {
                ForEach(sortedGroupKeys, id: \.self) { key in
                    VStack(alignment: .leading, spacing: 16) {
                        Text(muscleGroupTitles[key] ?? key)
                            .font(StitchTypography.dataMedium)
                            .italic()
                            .foregroundColor(StitchTheme.onSurfaceVariant.opacity(0.5))
                            .padding(.horizontal, 24)
                        
                        Color.clear
                            .frame(height: 0)
                            .id(sectionId(for: key))
                        
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(groupedExercises[key] ?? []) { exercise in
                                let isSelected = selectedExercises.contains(where: { $0.id == exercise.id })
                                LibraryExerciseCard(exercise: exercise, isSelected: isSelected) {
                                    toggleSelection(exercise)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
            .animation(nil, value: selectedExercises.map(\.id))
        }
    }
    
    @ViewBuilder
    private func indexSidebar(proxy: ScrollViewProxy) -> some View {
        if !sortedGroupKeys.isEmpty && filteredExercises.count > 10 {
            VStack(spacing: 0) {
                Spacer()
                GeometryReader { geometry in
                    VStack(spacing: 2) {
                        ForEach(sortedGroupKeys, id: \.self) { key in
                            Button {
                                scrollToSidebarKey(key, proxy: proxy)
                            } label: {
                                Text(muscleGroupTitles[key] ?? key)
                                    .font(StitchTypography.labelSmall)
                                    .foregroundColor(StitchTheme.primaryContainer)
                                    .frame(width: 24, height: 20)
                                    .contentShape(Rectangle())
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isSidebarDragging = true
                                scrollToSidebarKey(at: value.location.y, in: geometry.size.height, proxy: proxy)
                            }
                            .onEnded { _ in
                                isSidebarDragging = false
                                sidebarLastFocusedKey = nil
                            }
                    )
                }
                .padding(.vertical, 12)
                .frame(width: 32)
                .background(
                    Capsule()
                        .fill(StitchTheme.surfaceContainerLow.opacity(0.6))
                        .overlay(
                            Capsule()
                                .stroke(StitchTheme.primaryContainer.opacity(0.1), lineWidth: 1)
                        )
                )
                .padding(.trailing, 8)
                Spacer()
            }
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }

    private func scrollToSidebarKey(_ key: String, proxy: ScrollViewProxy) {
        if isSidebarDragging {
            proxy.scrollTo(sectionId(for: key), anchor: .top)
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                proxy.scrollTo(sectionId(for: key), anchor: .top)
            }
        }
        if sidebarLastFocusedKey != key {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            sidebarLastFocusedKey = key
        }
    }

    private func scrollToSidebarKey(at yPosition: CGFloat, in totalHeight: CGFloat, proxy: ScrollViewProxy) {
        guard !sortedGroupKeys.isEmpty, totalHeight > 0 else { return }
        let clampedY = min(max(yPosition, 0), totalHeight - 1)
        let ratio = clampedY / totalHeight
        let index = min(Int(ratio * CGFloat(sortedGroupKeys.count)), sortedGroupKeys.count - 1)
        let key = sortedGroupKeys[index]
        if sidebarLastFocusedKey != key {
            proxy.scrollTo(sectionId(for: key), anchor: .top)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            sidebarLastFocusedKey = key
        }
    }
    
    private func sectionId(for key: String) -> String {
        "muscle-section-\(key)"
    }
    
    private func scrollToSection(_ key: String, proxy: ScrollViewProxy) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            proxy.scrollTo(sectionId(for: key), anchor: .top)
        }
    }
    
    @ViewBuilder
    private var confirmButtonSection: some View {
        VStack {
            Spacer()
            Button(action: {
                if let targetId = appData.replacementTargetId, let newEx = selectedExercises.first {
                    // Replacement Mode
                    appData.replaceExercise(targetId: targetId, with: newEx)
                    appData.replacementTargetId = nil
                } else {
                    // Normal Selection Mode
                    let exercises = appData.convertLibraryExercises(selectedExercises)
                    appData.addToToday(exercises: exercises)
                }
                
                withAnimation {
                    appData.selectedTab = 0
                }
                // Clear selection for next time
                selectedExercises = []
            }) {
                HStack(spacing: 12) {
                    if appData.replacementTargetId != nil {
                        Text("CONFIRM REPLACEMENT")
                    } else {
                        Text(LocalizedStringKey("CONFIRM SELECTION (\(selectedExercises.count))"))
                    }
                    Image(systemName: "checkmark.circle.fill")
                }
                .foregroundColor(StitchTheme.onPrimaryFixed)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
                .background(StitchTheme.primaryContainer)
                .cornerRadius(12)
                .shadow(color: StitchTheme.primaryContainer.opacity(0.4), radius: 20, y: 10)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    private func toggleSelection(_ exercise: LibraryExercise) {
        if let index = selectedExercises.firstIndex(where: { $0.id == exercise.id }) {
            selectedExercises.remove(at: index)
        } else {
            selectedExercises.append(exercise)
        }
    }
}

struct LibraryExerciseCard: View {
    let exercise: LibraryExercise
    var isSelected: Bool
    var onTap: () -> Void
    
    @State private var isHovered = false
    
    private let equipmentTranslation: [String: String] = [
        "body only": "仅自重",
        "machine": "器械",
        "cable": "绳索",
        "dumbbell": "哑铃",
        "barbell": "杠铃",
        "kettlebell": "壶铃",
        "medicine ball": "药球",
        "exercise ball": "健身球",
        "resistance band": "弹力带",
        "foam roll": "泡沫轴",
        "e-z curl bar": "曲杆",
        "bench": "哑铃凳",
        "smith machine": "史密斯机",
        "kettlebells": "壶铃",
        "other": "其他",
        "bands":"弹力绳"
    ]
    
    private var equipmentDisplayText: String {
        let rawValue = exercise.equipment?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? "body only"
        let key = rawValue.lowercased()
        return equipmentTranslation[key] ?? rawValue
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Image Placeholder/Loader
            ZStack {
                if let thumb = exercise.thumbnailPath {
                    ExerciseImageView(imagePath: thumb)
                        .grayscale((isHovered || isSelected) ? 0 : 1.0)
                        .scaleEffect((isHovered || isSelected) ? 1.05 : 1.0)
                } else {
                    Rectangle()
                        .fill(StitchTheme.surfaceContainerHighest)
                        .overlay(
                            Image(systemName: "figure.strengthtraining.traditional")
                                .foregroundColor(StitchTheme.onSurfaceVariant.opacity(0.3))
                        )
                }
                
                if isSelected {
                    Color.black.opacity(0.3)
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(StitchTheme.primaryContainer)
                        .font(.title)
                }
            }
            .frame(height: 120)
            .clipped()
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.muscleLabel)
                    .font(StitchTypography.labelSmall)
                    .tracking(2.0)
                    .foregroundColor(isSelected ? StitchTheme.primaryContainer : StitchTheme.secondary)
                
                Text(exercise.displayName.uppercased())
                    .font(StitchTypography.bodyBold)
                    .italic()
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .foregroundColor(StitchTheme.onSurface)
                
                HStack(spacing: 4) {
                    Image(systemName: "fitness.center")
                        .font(.system(size: 10))
                        .foregroundColor(StitchTheme.onSurfaceVariant)
                    Text(equipmentDisplayText)
                        .font(StitchTypography.labelSmall)
                        .foregroundColor(StitchTheme.onSurfaceVariant)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
        }
        .background(isSelected ? StitchTheme.surfaceContainerHigh : StitchTheme.surfaceContainerLow)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? StitchTheme.primaryContainer : Color.clear, lineWidth: 2)
        )
        .overlay(
            Rectangle()
                .fill(StitchTheme.primaryContainer)
                .frame(width: 4)
                .padding(.vertical, 8)
                .opacity(isHovered ? 1 : 0),
            alignment: .leading
        )
        .onTapGesture {
            onTap()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
}

// ExerciseImageView has been moved to Common/ExerciseImageView.swift for shared use.

// Ensure pre-existing Theme/Typography are accessible OR copy them here
// Since I already matched types in previous tasks, I'll assume consistency or re-define locally if necessary.
// To be safe, I'll copy the StitchTheme and StitchTypography here since they were defined locally in the other views.

#Preview {
    NavigationView {
        ExerciseLibraryView()
    }
}
