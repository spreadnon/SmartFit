import SwiftUI

struct ExerciseLibraryView: View {
    @EnvironmentObject var appData: AppData
    @StateObject private var store = ExerciseLibraryStore.shared
    @State private var searchText = ""
    @State private var selectedCategory = "ALL"
    @State private var selectedExercises: [LibraryExercise] = []
    
    let categories = ["ALL", "CHEST", "BACK", "LEGS", "SHOULDERS", "ARMS", "ABDOMINALS"]
    
    var filteredExercises: [LibraryExercise] {
        store.exercises.filter { exercise in
            let matchesSearch = searchText.isEmpty || 
                               exercise.name.localizedCaseInsensitiveContains(searchText) || 
                               exercise.nameCN.localizedCaseInsensitiveContains(searchText) ||
                               exercise.localizedMuscleNames.contains { $0.localizedCaseInsensitiveContains(searchText) }
                               
            let matchesCategory = selectedCategory == "ALL" || 
                                 exercise.primaryMuscles.contains { $0.localizedCaseInsensitiveContains(selectedCategory) } ||
                                 exercise.localizedMuscleNames.contains { $0.localizedCaseInsensitiveContains(selectedCategory) }
            return matchesSearch && matchesCategory
        }
    }
    
    private var groupedExercises: [String: [LibraryExercise]] {
        Dictionary(grouping: filteredExercises) { exercise in
            String(exercise.name.prefix(1)).uppercased()
        }
    }
    
    private var sortedInitialKeys: [String] {
        groupedExercises.keys.sorted()
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
                            categoryChipsSection
                            exerciseGridSection(proxy: proxy)
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 120) // Extra padding for the floating button
                    }
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
                Text("\(NSLocalizedString("SELECTED: ", comment: ""))\(selectedExercises.count)")
                    .font(StitchTypography.label)
                    .foregroundColor(StitchTheme.primaryContainer)
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
        }
        .padding(16)
        .background(StitchTheme.surfaceContainerLow)
        .cornerRadius(8)
        .padding(.horizontal, 24)
    }
    
    @ViewBuilder
    private var categoryChipsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedCategory = category
                        }
                    } label: {
                        Text(LocalizedStringKey(category))
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
                ForEach(sortedInitialKeys, id: \.self) { key in
                    VStack(alignment: .leading, spacing: 16) {
                        Text(key)
                            .font(StitchTypography.dataMedium)
                            .italic()
                            .foregroundColor(StitchTheme.onSurfaceVariant.opacity(0.5))
                            .padding(.horizontal, 24)
                            .id(key) // For ScrollViewReader
                        
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(groupedExercises[key] ?? []) { exercise in
                                let isSelected = selectedExercises.contains(where: { $0.id == exercise.id })
                                LibraryExerciseCard(exercise: exercise, isSelected: isSelected) {
                                    toggleSelection(exercise)
                                }
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: filteredExercises.count)
        }
    }
    
    @ViewBuilder
    private func indexSidebar(proxy: ScrollViewProxy) -> some View {
        if !sortedInitialKeys.isEmpty && filteredExercises.count > 10 {
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 2) {
                    ForEach(sortedInitialKeys, id: \.self) { key in
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                proxy.scrollTo(key, anchor: .top)
                            }
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        } label: {
                            Text(key)
                                .font(StitchTypography.labelSmall)
                                .foregroundColor(StitchTheme.primaryContainer)
                                .frame(width: 24, height: 20)
                                .contentShape(Rectangle())
                        }
                    }
                }
                .padding(.vertical, 12)
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
                    Text(LocalizedStringKey(exercise.equipment?.uppercased() ?? "BODY ONLY"))
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
