import SwiftUI



struct TrainingPlanDetailView: View {
    @EnvironmentObject var appData: AppData
    let plan: TrainingPlan
    @State private var selectedDayIndex: Int
    @State private var activePlanType: Int // 0: AI, 1: MANUAL
    
    @State private var selectedExercise: Exercise? = nil
    @State private var hasInteracted = false
    
    // Timer properties
    @State private var startTime = Date()
    @State private var sessionDuration: TimeInterval = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    init(plan: TrainingPlan, selectedDayIndex: Int) {
        self.plan = plan
        self._selectedDayIndex = State(initialValue: selectedDayIndex)
        self._activePlanType = State(initialValue: plan.trainingSplit == "MANUAL" ? 1 : 0)
    }
    
    init(exercises: [Exercise]) {
        self.plan = TrainingPlan(
            trainingSplit: "MANUAL",
            instructions: NSLocalizedString("CUSTOM SESSION", comment: ""),
            days: [TrainingDay(label: NSLocalizedString("TODAY", comment: ""), exercises: exercises)]
        )
        self._selectedDayIndex = State(initialValue: 0)
        self._activePlanType = State(initialValue: 1)
    }
    
    var body: some View {
        let aiSmartPlan = appData.aiSmartPlan
        
        ZStack {
            StitchTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        summarySection
                        exerciseListSection
                    }
                }
            }
        }
        .navigationTitle(activePlanType == 0 ? (appData.aiSmartPlan?.trainingSplit ?? plan.trainingSplit) : NSLocalizedString("MANUAL SESSION", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                    Text(formatDuration(sessionDuration))
                        .monospacedDigit()
                }
                .font(StitchTypography.label)
                .foregroundColor(StitchTheme.primaryContainer)
            }
        }
        .onReceive(timer) { _ in
            if !isDayCompleted(index: selectedDayIndex) {
                sessionDuration = Date().timeIntervalSince(startTime)
            }
        }
        .onAppear {
            startTime = Date()
        }
        .onDisappear {
            saveSession()
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(StitchTheme.background.opacity(0.8), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(item: $selectedExercise) { exercise in
            ExerciseDetailSheet(exercise: exercise)
        }
        .preferredColorScheme(.dark)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func saveSession() {
        let exercises: [Exercise]
        let focusArea: String
        
        if activePlanType == 0 {
            let dayIndex = min(selectedDayIndex, (appData.aiSmartPlan ?? plan).days.count - 1)
            exercises = (appData.aiSmartPlan ?? plan).days[dayIndex].exercises
            focusArea = (appData.aiSmartPlan ?? plan).trainingSplit
        } else {
            exercises = appData.manualPlan?.days.first?.exercises ?? []
            focusArea = "CUSTOM"
        }
        
        if !exercises.isEmpty {
            guard hasInteracted else {
                print("ℹ️ No interaction with completion detected, skipping session save.")
                return
            }
            
            // 1. 本地保存
            appData.saveSessionRecord(exercises: exercises, focusArea: focusArea, duration: sessionDuration)
            
            // 2. 远程保存到 MySQL
            let record = TrainingRecord(
                date: Date(),
                focusArea: focusArea,
                exercises: exercises,
                duration: sessionDuration,
                isCompleted: exercises.allSatisfy { $0.isCompleted }
            )
            
            NetworkManager.shared.saveTraining(record: record, token: appData.currentUser?.token) { result in
                switch result {
                case .success:
                    print("✅ 训练记录已同步至 MySQL")
                case .failure(let error):
                    print("❌ 训练记录同步失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @ViewBuilder
    private var summarySection: some View {
        VStack(spacing: 24) {
            if activePlanType == 0 {
                VStack(spacing: 12) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<plan.days.count, id: \.self) { index in
                                let completed = isDayCompleted(index: index)
                                Button(action: {
                                    withAnimation(.spring()) {
                                        selectedDayIndex = index
                                    }
                                }) {
                                    Text(plan.days[index].label)
                                        .font(StitchTypography.label)
                                        .tracking(1.5)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 10)
                                        .background(selectedDayIndex == index ? StitchTheme.primaryContainer : StitchTheme.surfaceContainerHigh)
                                        .foregroundColor(selectedDayIndex == index ? StitchTheme.onPrimaryFixed : (completed ? StitchTheme.primaryContainer : StitchTheme.onSurfaceVariant))
                                        .cornerRadius(4)
                                        .shadow(color: selectedDayIndex == index ? StitchTheme.primaryContainer.opacity(0.2) : .clear, radius: 10)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            } else {
                // Manual Mode Header
                VStack(spacing: 8) {
                    Text("MANUAL SESSION")
                        .font(StitchTypography.headline)
                        .italic()
                        .foregroundColor(StitchTheme.secondary)
                    
                    Text("CUSTOM EXERCISE LOADOUT")
                        .font(StitchTypography.labelSmall)
                        .tracking(2)
                        .foregroundColor(StitchTheme.onSurfaceVariant)
                }
            }
        }
        .padding(.top, 24)
        .padding(.bottom, activePlanType == 0 ? 4 : 0)
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    @ViewBuilder
    private var exerciseListSection: some View {
        VStack(spacing: 32) {
            if activePlanType == 0 {
                // 1. AI Plan Binding
                let planBinding = Binding(
                    get: { appData.aiSmartPlan ?? plan },
                    set: { appData.aiSmartPlan = $0 }
                )
                
                let dayIndex = min(selectedDayIndex, planBinding.days.count - 1)
                if dayIndex >= 0 {
                    let isLocked = isDayCompleted(index: dayIndex)
                    ForEach(planBinding.days[dayIndex].exercises.indices, id: \.self) { idx in
                        ExerciseCard(exercise: planBinding.days[dayIndex].exercises[idx], isLocked: isLocked, onInteraction: { hasInteracted = true })
                            .id("ai-day-\(dayIndex)-exercise-\(planBinding.days[dayIndex].exercises[idx].id)")
                    }
                } else {
                    Color.clear.frame(height: 1)
                }
            } else {
                // 2. Manual Exercises Binding
                if let manualPlan = appData.manualPlan, !manualPlan.days.isEmpty {
                    let planBinding = Binding(
                        get: { appData.manualPlan ?? manualPlan },
                        set: { appData.manualPlan = $0 }
                    )
                    let exercises = planBinding.days[0].exercises
                    ForEach(exercises.indices, id: \.self) { idx in
                        ExerciseCard(exercise: planBinding.days[0].exercises[idx], onInteraction: { hasInteracted = true })
                    }
                } else {
                    emptyManualState
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 64)
    }

    @ViewBuilder
    private var emptyManualState: some View {
        VStack(spacing: 16) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(StitchTheme.onSurfaceVariant.opacity(0.3))
            
            Text("NO EXERCISES SELECTED")
                .font(StitchTypography.label)
                .foregroundColor(StitchTheme.onSurfaceVariant)
            
            Button {
                withAnimation {
                    appData.selectedTab = 1
                }
            } label: {
                Text("GO TO LIBRARY")
                    .font(StitchTypography.labelSmall)
                    .foregroundColor(StitchTheme.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(StitchTheme.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(StitchTheme.surfaceContainerLow)
        .cornerRadius(12)
    }
    
    // MARK: - Helper Functions
    private func isDayCompleted(index: Int) -> Bool {
        if activePlanType == 1 {
            // Manual Mode
            return appData.manualPlan?.days.first?.isCompleted ?? false
        }
        
        let activePlan = appData.aiSmartPlan ?? plan
        guard index < activePlan.days.count else { return false }
        return activePlan.days[index].isCompleted
    }
}

// MARK: - Exercise Card View
struct ExerciseCard: View {
    @Binding var exercise: Exercise
    var isEditable: Bool = true
    var isLocked: Bool = false
    var onInteraction: (() -> Void)? = nil
    @State private var isCollapsed: Bool = false
    @State private var activeSheet: ActiveSheet?
    
    // Environment object for navigation
    @EnvironmentObject var appData: AppData
    
    // Rest Timer
    @State private var timer: Timer?
    @State private var timeRemaining: Int = 90
    @State private var isTimerRunning: Bool = false
    
    enum ActiveSheet: Identifiable {
        case weight(index: Int)
        case reps(index: Int)
        case restTime
        
        var id: Int {
            switch self {
            case .weight(let index): return 1000 + index
            case .reps(let index): return 2000 + index
            case .restTime: return 3000
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let thumb = exercise.images.first {
                ExerciseImageView(imagePath: thumb)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .cornerRadius(12)
                    .padding(.bottom, 24)
            }
            headerSection
            statsSection
            
            if isCollapsed {
                summarySection
            } else {
                editorSection
            }
        }
        .padding(.vertical, 24)
        .onChange(of: exercise.exerciseSets) { _ in
            checkAndCollapse()
        }
        .sheet(item: $activeSheet) { sheet in
            PickerSheetView(sheet: sheet, exercise: $exercise)
        }
        .onAppear {
            if isLocked {
                isCollapsed = true
            }
            if !isTimerRunning {
                timeRemaining = exercise.restTime
            }
        }
        .onChange(of: exercise.restTime) { newValue in
            if !isTimerRunning {
                timeRemaining = newValue
            }
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom) {
                Text(exercise.exerciseName.uppercased())
                    .font(StitchTypography.headlineLarge)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .italic()
                    .foregroundColor(StitchTheme.primaryContainer)
                Spacer()
                HStack(spacing: 12) {
                    if isEditable && !isLocked {
                        Button {
                            appData.replacementTargetId = exercise.id
                            withAnimation {
                                appData.selectedTab = 1
                            }
                        } label: {
                            Text("替换")
                                .font(StitchTypography.labelSmall)
                                .foregroundColor(StitchTheme.primaryContainer)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(StitchTheme.primaryContainer.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(!exercise.localizedMuscleNames.isEmpty ? exercise.localizedMuscleNames.joined(separator: " / ") : (exercise.focusArea.isEmpty ? "" : exercise.focusArea))
                        .font(StitchTypography.label)
                        .foregroundColor(StitchTheme.onSurfaceVariant)
                        .tracking(2.0)
                }
            }
            .padding(.bottom, 4)
            
            // Divider Line
            LinearGradient(
                colors: [StitchTheme.primaryContainer, StitchTheme.primaryContainer.opacity(0.1), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 2)
        }
        .padding(.bottom, 24)
    }
    
    @ViewBuilder
    private var statsSection: some View {
        HStack(spacing: 12) {
            // Rest Timer Stats
            VStack(alignment: .leading, spacing: 8) {
                Text("休息时间")
                    .font(StitchTypography.label)
                    .tracking(2.0)
                    .foregroundColor(StitchTheme.onSurfaceVariant)
                
                Button {
                    activeSheet = .restTime
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%02d:%02d", timeRemaining / 60, timeRemaining % 60))
                            .font(StitchTypography.dataLarge)
                            .foregroundColor(isTimerRunning ? StitchTheme.tertiary : StitchTheme.onSurfaceVariant)
                        Text("SEC")
                            .font(StitchTypography.label)
                            .foregroundColor(StitchTheme.onSurfaceVariant)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(StitchTheme.surfaceContainer)
            .cornerRadius(8)
            .overlay(
                Rectangle()
                    .fill(StitchTheme.tertiary)
                    .frame(width: 4)
                    .padding(.vertical, 0),
                alignment: .leading
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Total Volume Stats
            VStack(alignment: .leading, spacing: 8) {
                Text("总重量")
                    .font(StitchTypography.label)
                    .tracking(2.0)
                    .foregroundColor(StitchTheme.onSurfaceVariant)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.0f", exercise.totalVolume))
                        .font(StitchTypography.dataLarge)
                        .foregroundColor(StitchTheme.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("KG")
                        .font(StitchTypography.label)
                        .foregroundColor(StitchTheme.onSurfaceVariant)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(StitchTheme.surfaceContainer)
            .cornerRadius(8)
            .overlay(
                Rectangle()
                    .fill(StitchTheme.secondary)
                    .frame(width: 4)
                    .padding(.vertical, 0),
                alignment: .leading
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.bottom, 24)
    }
    
    @ViewBuilder
    private var editorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            setsListHeader
            setsListSection
            if !isLocked {
                HStack(spacing: 16) {
                    addSetButton
                    if exercise.exerciseSets.count > 1 {
                        removeSetButton
                    }
                }
                .padding(.top, 16)
            }
        }
    }
    
    @ViewBuilder
    private var setsListHeader: some View {
        HStack {
            Text("组")
                .font(StitchTypography.label)
                .tracking(2.0)
                .foregroundColor(StitchTheme.onSurfaceVariant)
                .frame(width: 40, alignment: .leading)
            
            Text("KG")
                .font(StitchTypography.label)
                .tracking(2.0)
                .foregroundColor(StitchTheme.onSurfaceVariant)
                .frame(maxWidth: .infinity)
            
            Text("次")
                .font(StitchTypography.label)
                .tracking(2.0)
                .foregroundColor(StitchTheme.onSurfaceVariant)
                .frame(maxWidth: .infinity)
            
            Text("完成")
                .font(StitchTypography.label)
                .tracking(2.0)
                .foregroundColor(StitchTheme.onSurfaceVariant)
                .frame(width: 50, alignment: .center)
        }
        .padding(.horizontal, 12)
    }
    
    @ViewBuilder
    private var setsListSection: some View {
        VStack(spacing: 12) {
            ForEach($exercise.exerciseSets.indices, id: \.self) { index in
                SetRowView(
                    index: index,
                    exerciseSet: $exercise.exerciseSets[index],
                    onWeightTapped: { activeSheet = .weight(index: index) },
                    onRepsTapped: { activeSheet = .reps(index: index) },
                    onCompleteTapped: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            exercise.exerciseSets[index].isCompleted.toggle()
                            onInteraction?()
                            if exercise.exerciseSets[index].isCompleted {
                                startRestTimer()
                            }
                        }
                    }
                )
            }
        }
    }
    
    @ViewBuilder
    private var addSetButton: some View {
        Button(action: addSet) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.body.weight(.bold))
                    .foregroundColor(StitchTheme.primaryContainer)
                Text("加组数")
                    .font(StitchTypography.label)
                    .tracking(2.0)
                    .foregroundColor(StitchTheme.onSurface)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(StitchTheme.surfaceContainerHigh)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(StitchTheme.outlineVariant.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    @ViewBuilder
    private var removeSetButton: some View {
        Button(action: removeSet) {
            Image(systemName: "minus")
                .font(.body.weight(.bold))
                .foregroundColor(StitchTheme.secondary)
                .frame(width: 50)
                .padding(.vertical, 16)
                .background(StitchTheme.surfaceContainerLowest)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(StitchTheme.outlineVariant.opacity(0.3), lineWidth: 1)
                )
        }
    }
    
    @ViewBuilder
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("动作结束总结")
                .font(StitchTypography.dataMedium)
                .italic()
                .foregroundColor(StitchTheme.primaryContainer)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("组数")
                        .font(StitchTypography.label)
                        .tracking(2.0)
                        .foregroundColor(StitchTheme.onSurfaceVariant)
                    Text("\(exercise.exerciseSets.count)")
                        .font(StitchTypography.dataMedium)
                        .foregroundColor(StitchTheme.onSurface)
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("重量")
                        .font(StitchTypography.label)
                        .tracking(2.0)
                        .foregroundColor(StitchTheme.onSurfaceVariant)
                    Text(String(format: "%.1f", exercise.totalVolume))
                        .font(StitchTypography.dataMedium)
                        .foregroundColor(StitchTheme.onSurface)
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("次数/组")
                        .font(StitchTypography.label)
                        .tracking(2.0)
                        .foregroundColor(StitchTheme.onSurfaceVariant)
                    Text(String(format: "%.1f", exercise.averageReps))
                        .font(StitchTypography.dataMedium)
                        .foregroundColor(StitchTheme.onSurface)
                }
            }
            .padding(20)
            .background(StitchTheme.surfaceContainerLow)
            .cornerRadius(8)
            
            Button {
                withAnimation { isCollapsed = false }
            } label: {
                Text("编辑")
                    .font(StitchTypography.label)
                    .tracking(2.0)
                    .foregroundColor(StitchTheme.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(StitchTheme.outline.opacity(0.4), lineWidth: 1)
                    )
            }
        }
        .padding(.top, 16)
    }
    
    // MARK: - Functions
    private func checkAndCollapse() {
        let allCompleted = !exercise.exerciseSets.isEmpty && exercise.exerciseSets.allSatisfy { $0.isCompleted }
        if allCompleted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring()) {
                    isCollapsed = true
                    timer?.invalidate()
                    isTimerRunning = false
                }
            }
        }
    }
    
    private func addSet() {
        let lastSet = exercise.exerciseSets.last ?? ExerciseSet(weight: 10.0, reps: 10)
        withAnimation(.easeInOut) {
            exercise.exerciseSets.append(ExerciseSet(weight: lastSet.weight, reps: lastSet.reps))
        }
    }
    
    private func removeSet() {
        if exercise.exerciseSets.count > 1 {
            withAnimation(.easeInOut) {
                _ = exercise.exerciseSets.popLast()
            }
        }
    }
    
    private func startRestTimer() {
        timeRemaining = exercise.restTime
        isTimerRunning = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                timer?.invalidate()
                isTimerRunning = false
            }
        }
    }
}

// MARK: - Set Row View
struct SetRowView: View {
    let index: Int
    @Binding var exerciseSet: ExerciseSet
    
    let onWeightTapped: () -> Void
    let onRepsTapped: () -> Void
    let onCompleteTapped: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Identifier
            Text("\(index + 1)")
                .font(StitchTypography.dataMedium)
                .italic()
                .foregroundColor(exerciseSet.isCompleted ? StitchTheme.onSurfaceVariant : StitchTheme.primaryContainer)
                .frame(width: 40, alignment: .leading)
            
            // Weight Button
            Button(action: onWeightTapped) {
                Text(String(format: "%.1f", exerciseSet.weight))
                    .font(StitchTypography.dataMedium)
                    .foregroundColor(exerciseSet.isCompleted ? StitchTheme.onSurfaceVariant : StitchTheme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(StitchTheme.surfaceContainerLowest)
                    .cornerRadius(6)
            }
            .disabled(exerciseSet.isCompleted)
            
            // Reps Button
            Button(action: onRepsTapped) {
                Text("\(exerciseSet.reps)")
                    .font(StitchTypography.dataMedium)
                    .foregroundColor(exerciseSet.isCompleted ? StitchTheme.onSurfaceVariant : StitchTheme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(StitchTheme.surfaceContainerLowest)
                    .cornerRadius(6)
            }
            .disabled(exerciseSet.isCompleted)
            
            // Completion Toggle
            Button(action: onCompleteTapped) {
                ZStack {
                    if exerciseSet.isCompleted {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(StitchTheme.primaryContainer)
                            .frame(width: 32, height: 32)
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(StitchTheme.onPrimaryFixed)
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(StitchTheme.outline.opacity(0.4), lineWidth: 2)
                            .frame(width: 32, height: 32)
                    }
                }
                .frame(width: 50, alignment: .center)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(exerciseSet.isCompleted ? StitchTheme.surfaceBright.opacity(0.6) : StitchTheme.surfaceContainerHigh)
        .cornerRadius(8)
        .overlay(
            Rectangle()
                .fill(StitchTheme.primaryContainer)
                .frame(width: 4)
                .padding(.vertical, 0)
                .opacity(exerciseSet.isCompleted ? 1 : (index == 0 ? 1 : 0)), // Mock active state for visual
            alignment: .leading
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Picker Sheet View
struct PickerSheetView: View {
    let sheet: ExerciseCard.ActiveSheet
    @Binding var exercise: Exercise
    
    private var weightOptions: [Double] { Array(stride(from: 0.0, to: 300.0, by: 0.5)) }
    private var repsOptions: [Int] { Array(1...50) }
    
    var body: some View {
        switch sheet {
        case .weight(let index):
            ValuePickerSheet(
                title: "WEIGHT (KG)",
                selection: $exercise.exerciseSets[index].weight,
                options: weightOptions,
                format: "%.1f"
            )
        case .reps(let index):
            ValuePickerSheet(
                title: "REPS",
                selection: Binding(
                    get: { Double(exercise.exerciseSets[index].reps) },
                    set: { exercise.exerciseSets[index].reps = Int($0) }
                ),
                options: repsOptions.map { Double($0) },
                format: "%.0f"
            )
        case .restTime:
            ValuePickerSheet(
                title: "REST TIME (SEC)",
                selection: Binding(
                    get: { Double(exercise.restTime) },
                    set: { exercise.restTime = Int($0) }
                ),
                options: Array(stride(from: 30.0, to: 301.0, by: 5.0)),
                format: "%.0f"
            )
        }
    }
}

struct ValuePickerSheet<T: Hashable>: View {
    let title: String
    @Binding var selection: T
    let options: [T]
    let format: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(StitchTypography.dataMedium)
                .foregroundColor(StitchTheme.primaryContainer)
                .padding(.top, 24)
                .padding(.bottom, 16)
            
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(String(format: format, option as! CVarArg))
                        .foregroundColor(StitchTheme.onSurface)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            
            Button { dismiss() } label: {
                Text("DONE")
                    .font(StitchTypography.label)
                    .tracking(2.0)
                    .foregroundColor(StitchTheme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(StitchTheme.primaryContainer)
                    .cornerRadius(8)
            }
            .padding(24)
        }
        .background(StitchTheme.background.ignoresSafeArea())
        .presentationDetents([.height(350)])
    }
}

struct ExerciseDetailSheet: View {
    let exercise: Exercise
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            StitchTheme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Spacer()
                        Capsule()
                            .fill(StitchTheme.outlineVariant)
                            .frame(width: 40, height: 4)
                        Spacer()
                    }
                    .padding(.top, 12)
                    
                    Text(exercise.exerciseName.uppercased())
                        .font(StitchTypography.headlineLarge)
                        .italic()
                        .foregroundColor(StitchTheme.primaryContainer)
                    
                    Text("TECHNIQUE")
                        .font(StitchTypography.label)
                        .tracking(2.0)
                        .foregroundColor(StitchTheme.onSurfaceVariant)
                    Text(exercise.instructions.isEmpty ? "MAINTAIN CORE TENSION." : exercise.instructions.uppercased())
                        .font(StitchTypography.bodyBold)
                        .foregroundColor(StitchTheme.onSurface)
                        .lineSpacing(4)
                }
                .padding(24)
            }
        }
    }
}

#Preview {
    NavigationView {
        TrainingPlanDetailView(plan: TrainingPlan(
            trainingSplit: "3 DAYS (A/B/C)",
            instructions: "Hypertrophy focus today. Drive through the movement.",
            days: [
                TrainingDay(label: "A", exercises: [
                    Exercise(
                        order: 1,
                        exerciseName: "BENCH PRESS",
                        sets: 3,
                        reps: "8-10",
                        equipment: "BARBELL",
                        difficulty: "HARD",
                        instructions: "Keep shoulders retracted. Pause at bottom.",
                        focusArea: "CHEST / TRICEPS"
                    )
                ])
            ]
        ), selectedDayIndex: 0)
        .environmentObject(AppData())
    }
}
