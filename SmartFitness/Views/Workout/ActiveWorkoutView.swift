import SwiftUI

enum ActiveWorkoutSource {
    case ai
    case manual
}

enum WorkoutSyncStatus {
    case notSaved
    case localSaved
    case syncing
    case synced
    case failed

    var title: String {
        switch self {
        case .notSaved: return "未生成训练记录"
        case .localSaved: return "本地已保存"
        case .syncing: return "云端同步中"
        case .synced: return "云端已同步"
        case .failed: return "云端同步失败"
        }
    }

    var systemImage: String {
        switch self {
        case .notSaved: return "minus.circle"
        case .localSaved: return "checkmark.circle"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .synced: return "checkmark.icloud"
        case .failed: return "exclamationmark.icloud"
        }
    }
}

struct WorkoutSummary {
    let duration: TimeInterval
    let focusArea: String
    let exercises: [Exercise]

    var completedSets: Int {
        exercises.flatMap { $0.exerciseSets }.filter { $0.isCompleted }.count
    }

    var totalSets: Int {
        exercises.flatMap { $0.exerciseSets }.count
    }

    var completedExercises: Int {
        exercises.filter { $0.isCompleted }.count
    }

    var totalVolume: Double {
        exercises.reduce(0) { $0 + $1.totalVolume }
    }
}

struct ActiveWorkoutView: View {
    @EnvironmentObject var appData: AppData
    @Environment(\.dismiss) private var dismiss

    let source: ActiveWorkoutSource
    let dayIndex: Int

    @State private var currentExerciseIndex = 0
    @State private var startTime = Date()
    @State private var sessionDuration: TimeInterval = 0
    @State private var isResting = false
    @State private var restRemaining = 0
    @State private var showingEndConfirmation = false
    @State private var showingExitConfirmation = false
    @State private var showingWorkoutComplete = false
    @State private var showingRestComplete = false
    @State private var showingExerciseCompletePrompt = false
    @State private var exercisePendingDeletion: Exercise?
    @State private var completedSummary: WorkoutSummary?
    @State private var syncStatus: WorkoutSyncStatus = .notSaved
    @State private var pendingSyncRecord: TrainingRecord?
    @State private var hasInteracted = false
    @State private var originalPlan: TrainingPlan?
    @State private var weightInputSetIndex: Int?
    @State private var weightInputText = ""
    @State private var showingWeightInput = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var activePlan: TrainingPlan? {
        source == .manual ? appData.manualPlan : appData.aiSmartPlan
    }

    private var resolvedDayIndex: Int {
        guard let plan = activePlan, !plan.days.isEmpty else { return 0 }
        return min(dayIndex, plan.days.count - 1)
    }

    private var currentDay: TrainingDay? {
        guard let plan = activePlan, !plan.days.isEmpty else { return nil }
        return plan.days[resolvedDayIndex]
    }

    private var exercises: [Exercise] {
        currentDay?.exercises ?? []
    }

    private var currentExercise: Exercise? {
        guard exercises.indices.contains(currentExerciseIndex) else { return nil }
        return exercises[currentExerciseIndex]
    }

    private var completedSets: Int {
        exercises.flatMap { $0.exerciseSets }.filter { $0.isCompleted }.count
    }

    private var totalSets: Int {
        exercises.flatMap { $0.exerciseSets }.count
    }

    var body: some View {
        ZStack(alignment: .top) {
            StitchTheme.background.ignoresSafeArea()

            if let completedSummary {
                WorkoutSummaryView(
                    summary: completedSummary,
                    syncStatus: syncStatus,
                    onRetrySync: retrySync,
                    onViewHistory: {
                        appData.selectedTab = 3
                        dismiss()
                    }
                ) {
                    dismiss()
                }
            } else {
                VStack(spacing: 0) {
                    headerBar

                    if let exercise = currentExercise {
                        stickyStatusPanel

                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 20) {
                                currentExerciseSection(exercise)
                                    .gesture(
                                        DragGesture(minimumDistance: 40)
                                            .onEnded { value in
                                                handleExerciseSwipe(value.translation.width)
                                            }
                                    )
                                setEditorSection(exercise)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 120)
                        }

                        bottomControls
                    } else {
                        emptyWorkoutState
                    }
                }

                restOverlayPanel
                exerciseCompleteOverlay
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .preferredColorScheme(.dark)
        .onDisappear {
            setTabBarHidden(false)
        }
        .onAppear {
            setTabBarHidden(true)
            startTime = Date()
            if originalPlan == nil {
                originalPlan = activePlan
            }
            setInitialExerciseIndex()
        }
        .onReceive(timer) { _ in
            sessionDuration = Date().timeIntervalSince(startTime)
            tickRestTimer()
        }
        .alert("退出训练？", isPresented: $showingExitConfirmation) {
            Button("继续训练", role: .cancel) {}
            Button("放弃改动", role: .destructive) {
                discardWorkoutChanges()
            }
            Button("保存并退出") {
                finishWorkout()
            }
        } message: {
            Text("你已经修改了本次训练。可以保存为训练记录，或放弃本次改动。")
        }
        .alert("结束训练？", isPresented: $showingEndConfirmation) {
            Button("继续训练", role: .cancel) {}
            Button("保存并结束", role: .destructive) {
                finishWorkout()
            }
        } message: {
            Text("已完成 \(completedSets)/\(totalSets) 组，训练时长 \(formatDuration(sessionDuration))。")
        }
        .alert("训练完成", isPresented: $showingWorkoutComplete) {
            Button("查看一下", role: .cancel) {}
            Button("保存并结束") {
                finishWorkout()
            }
        } message: {
            Text("所有动作都已完成。训练时长 \(formatDuration(sessionDuration))，共完成 \(completedSets) 组。")
        }
        .alert("删除当前动作？", isPresented: deleteConfirmationBinding) {
            Button("取消", role: .cancel) {
                exercisePendingDeletion = nil
            }
            Button("删除", role: .destructive) {
                if let exercise = exercisePendingDeletion {
                    removeCurrentExercise(exercise)
                }
                exercisePendingDeletion = nil
            }
        } message: {
            Text("这会从今日训练中移除当前动作。")
        }
        .alert("输入重量 (kg)", isPresented: $showingWeightInput) {
            TextField("例如 42.5", text: $weightInputText)
                .keyboardType(.decimalPad)
            Button("取消", role: .cancel) {
                weightInputSetIndex = nil
                weightInputText = ""
            }
            Button("确定") {
                applyManualWeightInput()
            }
        } message: {
            Text("直接输入本次组使用的重量。")
        }
    }

    private var headerBar: some View {
        HStack {
            Button {
                requestDismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(StitchTheme.primaryContainer)
                    .frame(width: 36, height: 36)
                    .background(StitchTheme.surfaceContainerHigh)
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("ACTIVE WORKOUT")
                    .font(StitchTypography.labelSmall)
                    .foregroundColor(StitchTheme.onSurfaceVariant)
                    .tracking(2)
                Text(formatDuration(sessionDuration))
                    .font(StitchTypography.headline)
                    .foregroundColor(StitchTheme.primaryContainer)
                    .monospacedDigit()
            }

            Spacer()

            Button {
                showingEndConfirmation = true
            } label: {
                Text("结束")
                    .font(StitchTypography.label)
                    .foregroundColor(StitchTheme.primaryContainer)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(StitchTheme.primaryContainer.opacity(0.12))
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .background(StitchTheme.background.opacity(0.96))
    }

    private var restCompleteBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
            Text("休息结束，继续下一组")
                .font(StitchTypography.label)
            Spacer()
        }
        .foregroundColor(StitchTheme.onPrimaryFixed)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(StitchTheme.primaryContainer)
    }

    private var stickyStatusPanel: some View {
        VStack(spacing: 0) {
            progressSection
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(
            StitchTheme.background.opacity(0.98)
                .shadow(color: Color.black.opacity(0.25), radius: 14, y: 8)
        )
    }

    @ViewBuilder
    private var restOverlayPanel: some View {
        VStack(spacing: 10) {
            if showingRestComplete {
                restCompleteBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if isResting {
                restBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 132)
        .allowsHitTesting(isResting || showingRestComplete)
    }

    @ViewBuilder
    private var exerciseCompleteOverlay: some View {
        if showingExerciseCompletePrompt {
            VStack {
                Spacer()

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(StitchTheme.primaryContainer)
                        Text("当前动作已完成")
                            .font(StitchTypography.label)
                            .foregroundColor(StitchTheme.onSurface)
                        Spacer()
                    }

                    Button {
                        showingExerciseCompletePrompt = false
                        moveToNextIncompleteExercise()
                    } label: {
                        Text("进入下一个动作")
                            .font(StitchTypography.label)
                            .foregroundColor(StitchTheme.onPrimaryFixed)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(StitchTheme.primaryContainer)
                            .cornerRadius(10)
                    }
                }
                .padding(16)
                .background(StitchTheme.surfaceContainer)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.35), radius: 20, y: 8)
                .padding(.horizontal, 20)
                .padding(.bottom, 92)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("动作 \(min(currentExerciseIndex + 1, max(exercises.count, 1)))/\(exercises.count)")
                    .font(StitchTypography.labelSmall)
                    .foregroundColor(StitchTheme.onSurfaceVariant)
                Spacer()
                Text("\(completedSets)/\(totalSets) 组")
                    .font(StitchTypography.labelSmall)
                    .foregroundColor(StitchTheme.primaryContainer)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(StitchTheme.surfaceContainerHighest)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(StitchTheme.primaryContainer)
                        .frame(width: geo.size.width * progressRatio)
                }
            }
            .frame(height: 8)
        }
    }

    @ViewBuilder
    private var restBanner: some View {
        if isResting {
            HStack(spacing: 14) {
                Image(systemName: "timer")
                    .foregroundColor(StitchTheme.onPrimaryFixed)

                VStack(alignment: .leading, spacing: 2) {
                    Text("REST")
                        .font(StitchTypography.labelSmall)
                        .foregroundColor(StitchTheme.onPrimaryFixed.opacity(0.75))
                    Text(formatRest(restRemaining))
                        .font(StitchTypography.dataMedium)
                        .foregroundColor(StitchTheme.onPrimaryFixed)
                        .monospacedDigit()
                }

                Spacer()

                Button("跳过") {
                    isResting = false
                    restRemaining = 0
                }
                .font(StitchTypography.labelSmall)
                .foregroundColor(StitchTheme.onPrimaryFixed)
            }
            .padding(16)
            .background(StitchTheme.primaryContainer)
            .cornerRadius(14)
        }
    }

    private func currentExerciseSection(_ exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let image = exercise.images.first {
                ExerciseImageView(imagePath: image)
                    .id("\(exercise.id)-\(image)")
                    .frame(height: 190)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .cornerRadius(14)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(exercise.exerciseName.uppercased())
                    .font(StitchTypography.headlineLarge)
                    .italic()
                    .foregroundColor(StitchTheme.primaryContainer)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                Text(exercise.localizedMuscleNames.isEmpty ? exercise.focusArea : exercise.localizedMuscleNames.joined(separator: " / "))
                    .font(StitchTypography.label)
                    .foregroundColor(StitchTheme.onSurfaceVariant)
                    .tracking(1.5)

                HStack(spacing: 6) {
                    Image(systemName: "arrow.left.and.right")
                    Text("左右滑动切换动作")
                }
                .font(StitchTypography.labelSmall)
                .foregroundColor(StitchTheme.onSurfaceVariant.opacity(0.65))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func setEditorSection(_ exercise: Exercise) -> some View {
        VStack(spacing: 12) {
            let nextSetIndex = exercise.exerciseSets.firstIndex(where: { !$0.isCompleted })
            ForEach(Array(exercise.exerciseSets.enumerated()), id: \.element.id) { index, set in
                setRow(
                    set: set,
                    index: index,
                    restTime: exercise.restTime,
                    isNextSet: nextSetIndex == index
                )
            }

            HStack(spacing: 12) {
                Button(action: addSet) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text("加一组")
                            .font(StitchTypography.label)
                    }
                    .foregroundColor(StitchTheme.primaryContainer)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(StitchTheme.surfaceContainerHigh)
                    .cornerRadius(10)
                }

                if exercise.exerciseSets.count > 1 {
                    Button(action: removeLastSet) {
                        Image(systemName: "minus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(StitchTheme.secondary)
                            .frame(width: 48)
                            .padding(.vertical, 12)
                            .background(StitchTheme.surfaceContainerHighest)
                            .cornerRadius(10)
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(StitchTheme.surfaceContainer)
        .cornerRadius(16)
    }

    private func setRow(set: ExerciseSet, index: Int, restTime: Int, isNextSet: Bool) -> some View {
        HStack(spacing: 12) {
            Button {
                toggleSetCompletion(at: index, restTime: restTime)
            } label: {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(set.isCompleted ? StitchTheme.primaryContainer : StitchTheme.onSurfaceVariant)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("SET \(index + 1)")
                    .font(StitchTypography.labelSmall)
                    .foregroundColor(isNextSet ? StitchTheme.primaryContainer : StitchTheme.onSurfaceVariant)

                HStack(spacing: 12) {
                    valueStepper(
                        value: formatWeight(set.weight),
                        isDisabled: set.isCompleted,
                        minus: { adjustWeight(at: index, by: -2.5) },
                        plus: { adjustWeight(at: index, by: 2.5) },
                        onValueTap: { beginWeightInput(at: index, currentWeight: set.weight) }
                    )

                    valueStepper(
                        value: "\(set.reps)次",
                        isDisabled: set.isCompleted,
                        minus: { adjustReps(at: index, by: -1) },
                        plus: { adjustReps(at: index, by: 1) }
                    )
                }
            }

            Spacer()
        }
        .padding(12)
        .background(setRowBackground(isCompleted: set.isCompleted, isNextSet: isNextSet))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isNextSet ? StitchTheme.primaryContainer.opacity(0.75) : Color.clear, lineWidth: 1.5)
        )
        .cornerRadius(12)
    }

    private func valueStepper(
        value: String,
        isDisabled: Bool = false,
        minus: @escaping () -> Void,
        plus: @escaping () -> Void,
        onValueTap: (() -> Void)? = nil
    ) -> some View {
        HStack(spacing: 8) {
            Button(action: minus) {
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .bold))
            }
            .disabled(isDisabled)

            if let onValueTap {
                Button(action: onValueTap) {
                    Text(value)
                        .font(StitchTypography.label)
                        .foregroundColor(StitchTheme.onSurface)
                        .monospacedDigit()
                        .frame(minWidth: 52)
                        .underline(color: StitchTheme.primaryContainer.opacity(0.45))
                }
                .disabled(isDisabled)
            } else {
                Text(value)
                    .font(StitchTypography.label)
                    .foregroundColor(StitchTheme.onSurface)
                    .monospacedDigit()
                    .frame(minWidth: 52)
            }

            Button(action: plus) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
            }
            .disabled(isDisabled)
        }
        .foregroundColor(StitchTheme.primaryContainer)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(StitchTheme.surfaceContainerHigh)
        .cornerRadius(8)
        .opacity(isDisabled ? 0.55 : 1)
    }

    private func setRowBackground(isCompleted: Bool, isNextSet: Bool) -> Color {
        if isCompleted {
            return StitchTheme.primaryContainer.opacity(0.08)
        }
        if isNextSet {
            return StitchTheme.primaryContainer.opacity(0.12)
        }
        return StitchTheme.surfaceContainerLow
    }

    private var bottomControls: some View {
        HStack(spacing: 12) {
            workoutControlButton(
                title: "上一个",
                systemImage: "chevron.left",
                isPrimary: false,
                isDisabled: currentExerciseIndex == 0
            ) {
                moveExercise(by: -1)
            }

            workoutControlButton(
                title: "删除",
                systemImage: "trash",
                isPrimary: false,
                isDisabled: currentExercise?.isCompleted ?? true
            ) {
                if let exercise = currentExercise {
                    exercisePendingDeletion = exercise
                }
            }

            workoutControlButton(
                title: "替换",
                systemImage: "arrow.triangle.2.circlepath",
                isPrimary: false,
                isDisabled: false
            ) {
                if let exercise = currentExercise {
                    appData.replacementTargetId = exercise.id
                    appData.selectedTab = 2
                }
            }

            workoutControlButton(
                title: shouldShowFinishControl ? "结束训练" : "下一个",
                systemImage: shouldShowFinishControl ? "checkmark.circle.fill" : "chevron.right",
                isPrimary: true,
                isDisabled: false
            ) {
                if shouldShowFinishControl {
                    showingEndConfirmation = true
                } else {
                    moveExercise(by: 1)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            StitchTheme.background.opacity(0.98)
                .shadow(color: Color.black.opacity(0.35), radius: 18, y: -8)
        )
    }

    private func workoutControlButton(
        title: String,
        systemImage: String,
        isPrimary: Bool,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: isPrimary ? 18 : 15, weight: .bold))
                Text(title)
                    .font(isPrimary ? StitchTypography.label : StitchTypography.labelSmall)
            }
            .foregroundColor(isPrimary ? StitchTheme.onPrimaryFixed : StitchTheme.primaryContainer)
            .frame(maxWidth: .infinity)
            .padding(.vertical, isPrimary ? 14 : 12)
            .background(isPrimary ? StitchTheme.primaryContainer : StitchTheme.surfaceContainerHigh)
            .cornerRadius(14)
            .opacity(isDisabled ? 0.35 : 1)
        }
        .disabled(isDisabled)
    }

    private var emptyWorkoutState: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 48))
                .foregroundColor(StitchTheme.onSurfaceVariant.opacity(0.4))
            Text("NO EXERCISES")
                .font(StitchTypography.dataMedium)
                .foregroundColor(StitchTheme.onSurface)
            Button("去动作库添加") {
                appData.libraryInsertionTarget = LibraryInsertionTarget(planType: source == .manual ? .manual : .ai, dayIndex: resolvedDayIndex)
                appData.selectedTab = 2
            }
            .font(StitchTypography.label)
            .foregroundColor(StitchTheme.primaryContainer)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var progressRatio: CGFloat {
        guard totalSets > 0 else { return 0 }
        return CGFloat(completedSets) / CGFloat(totalSets)
    }

    private var isWorkoutComplete: Bool {
        totalSets > 0 && completedSets == totalSets
    }

    private var shouldShowFinishControl: Bool {
        currentExerciseIndex >= exercises.count - 1 || isWorkoutComplete
    }

    private func assignPlan(_ plan: TrainingPlan) {
        if source == .manual {
            appData.manualPlan = plan
        } else {
            appData.aiSmartPlan = plan
        }
    }

    private func updateCurrentSet(at setIndex: Int, _ update: (inout ExerciseSet) -> Void) {
        guard var plan = activePlan,
              plan.days.indices.contains(resolvedDayIndex),
              plan.days[resolvedDayIndex].exercises.indices.contains(currentExerciseIndex),
              plan.days[resolvedDayIndex].exercises[currentExerciseIndex].exerciseSets.indices.contains(setIndex) else {
            return
        }

        update(&plan.days[resolvedDayIndex].exercises[currentExerciseIndex].exerciseSets[setIndex])
        hasInteracted = true
        assignPlan(plan)
    }

    private func updateCurrentExerciseSets(_ update: (inout [ExerciseSet]) -> Void) {
        guard var plan = activePlan,
              plan.days.indices.contains(resolvedDayIndex),
              plan.days[resolvedDayIndex].exercises.indices.contains(currentExerciseIndex) else {
            return
        }

        update(&plan.days[resolvedDayIndex].exercises[currentExerciseIndex].exerciseSets)
        hasInteracted = true
        assignPlan(plan)
    }

    private func toggleSetCompletion(at setIndex: Int, restTime: Int) {
        var completedNow = false
        var currentExerciseCompletedNow = false
        updateCurrentSet(at: setIndex) { set in
            set.isCompleted.toggle()
            completedNow = set.isCompleted
        }
        currentExerciseCompletedNow = currentExercise?.isCompleted ?? false

        if completedNow {
            if isWorkoutComplete {
                isResting = false
                restRemaining = 0
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                showingWorkoutComplete = true
            } else if currentExerciseCompletedNow {
                isResting = false
                restRemaining = 0
                showExerciseCompletePrompt()
            } else {
                startRestTimer(seconds: restTime)
            }
        }
    }

    private func adjustWeight(at setIndex: Int, by amount: Double) {
        updateCurrentSet(at: setIndex) { set in
            set.weight = max(0, set.weight + amount)
        }
    }

    private func adjustReps(at setIndex: Int, by amount: Int) {
        updateCurrentExerciseSets { sets in
            guard sets.indices.contains(setIndex) else { return }
            let newReps = max(1, sets[setIndex].reps + amount)

            // Keep unfinished sets on the same habitual rep target.
            for index in sets.indices where !sets[index].isCompleted {
                if index == setIndex || index > setIndex {
                    sets[index].reps = newReps
                }
            }
        }
    }

    private func addSet() {
        updateCurrentExerciseSets { sets in
            let template = sets.last ?? ExerciseSet(weight: 10, reps: 10)
            sets.append(ExerciseSet(weight: template.weight, reps: template.reps))
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func removeLastSet() {
        updateCurrentExerciseSets { sets in
            guard sets.count > 1 else { return }
            sets.removeLast()
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func beginWeightInput(at setIndex: Int, currentWeight: Double) {
        weightInputSetIndex = setIndex
        weightInputText = formatWeightValue(currentWeight)
        showingWeightInput = true
    }

    private func applyManualWeightInput() {
        defer {
            weightInputSetIndex = nil
            weightInputText = ""
        }

        guard let setIndex = weightInputSetIndex else { return }

        let normalized = weightInputText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let weight = Double(normalized), weight >= 0 else { return }

        updateCurrentSet(at: setIndex) { set in
            set.weight = weight
        }
    }

    private func formatWeight(_ weight: Double) -> String {
        "\(formatWeightValue(weight))kg"
    }

    private func formatWeightValue(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(weight))"
        }
        return String(format: "%g", weight)
    }

    private func startRestTimer(seconds: Int) {
        guard seconds > 0 else { return }
        restRemaining = seconds
        isResting = true
    }

    private func tickRestTimer() {
        guard isResting else { return }
        if restRemaining > 0 {
            restRemaining -= 1
        }
        if restRemaining <= 0 {
            isResting = false
            restRemaining = 0
            showRestCompletePrompt()
        }
    }

    private func showRestCompletePrompt() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            showingRestComplete = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.2)) {
                showingRestComplete = false
            }
        }
    }

    private func showExerciseCompletePrompt() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            showingExerciseCompletePrompt = true
        }
    }

    private func moveExercise(by offset: Int) {
        let nextIndex = currentExerciseIndex + offset
        guard exercises.indices.contains(nextIndex) else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            currentExerciseIndex = nextIndex
            isResting = false
            restRemaining = 0
            showingExerciseCompletePrompt = false
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func moveToNextIncompleteExercise() {
        guard !exercises.isEmpty else { return }
        if let nextIndex = exercises.indices.first(where: { $0 > currentExerciseIndex && !exercises[$0].isCompleted }) {
            moveExercise(to: nextIndex)
        } else if let firstIncompleteIndex = exercises.firstIndex(where: { !$0.isCompleted }) {
            moveExercise(to: firstIncompleteIndex)
        }
    }

    private func moveExercise(to index: Int) {
        guard exercises.indices.contains(index) else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            currentExerciseIndex = index
            isResting = false
            restRemaining = 0
            showingExerciseCompletePrompt = false
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func removeCurrentExercise(_ exercise: Exercise) {
        appData.removeExerciseFromToday(exerciseId: exercise.id)
        let nextCount = max(exercises.count - 1, 0)
        currentExerciseIndex = min(currentExerciseIndex, max(nextCount - 1, 0))
        isResting = false
        restRemaining = 0
        hasInteracted = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func handleExerciseSwipe(_ horizontalTranslation: CGFloat) {
        if horizontalTranslation < -60 {
            moveExercise(by: 1)
        } else if horizontalTranslation > 60 {
            moveExercise(by: -1)
        }
    }

    private func clampCurrentExerciseIndex() {
        guard !exercises.isEmpty else {
            currentExerciseIndex = 0
            return
        }
        currentExerciseIndex = min(currentExerciseIndex, exercises.count - 1)
    }

    private func setInitialExerciseIndex() {
        guard !exercises.isEmpty else {
            currentExerciseIndex = 0
            return
        }

        if let firstIncompleteIndex = exercises.firstIndex(where: { !$0.isCompleted }) {
            currentExerciseIndex = firstIncompleteIndex
        } else {
            currentExerciseIndex = exercises.count - 1
        }
    }

    private func requestDismiss() {
        if completedSummary != nil {
            dismiss()
            return
        }

        if hasInteracted {
            showingExitConfirmation = true
        } else {
            dismiss()
        }
    }

    private func finishWorkout() {
        guard let plan = activePlan,
              plan.days.indices.contains(resolvedDayIndex) else {
            dismiss()
            return
        }

        let day = plan.days[resolvedDayIndex]
        let focusArea = workoutFocusArea(for: day, in: plan)
        if hasInteracted {
            appData.saveSessionRecord(
                exercises: day.exercises,
                focusArea: focusArea,
                duration: sessionDuration
            )
            syncStatus = .syncing

            let record = TrainingRecord(
                date: Date(),
                focusArea: focusArea,
                exercises: day.exercises,
                duration: sessionDuration,
                isCompleted: day.exercises.allSatisfy { $0.isCompleted }
            )
            pendingSyncRecord = record

            syncTrainingRecord(record)
        } else {
            syncStatus = .notSaved
        }

        completedSummary = WorkoutSummary(
            duration: sessionDuration,
            focusArea: focusArea,
            exercises: day.exercises
        )
    }

    private func workoutFocusArea(for day: TrainingDay, in plan: TrainingPlan) -> String {
        if let focus = day.focus, !focus.isEmpty {
            return focus
        }

        let muscles = day.exercises
            .flatMap { $0.localizedMuscleNames.isEmpty ? $0.primaryMuscles : $0.localizedMuscleNames }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let uniqueMuscles = Array(NSOrderedSet(array: muscles)) as? [String] ?? []
        if !uniqueMuscles.isEmpty {
            return uniqueMuscles.prefix(2).joined(separator: " / ")
        }

        return source == .manual ? "CUSTOM" : plan.trainingSplit
    }

    private func discardWorkoutChanges() {
        if let originalPlan {
            assignPlan(originalPlan)
        }
        dismiss()
    }

    private func retrySync() {
        guard let pendingSyncRecord else { return }
        syncTrainingRecord(pendingSyncRecord)
    }

    private func syncTrainingRecord(_ record: TrainingRecord) {
        syncStatus = .syncing
        NetworkManager.shared.saveTraining(record: record, token: appData.currentUser?.token) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    syncStatus = .synced
                case .failure(let error):
                    syncStatus = .failed
                    print("❌ 训练记录同步失败: \(error.localizedDescription)")
                }
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func formatRest(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { exercisePendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    exercisePendingDeletion = nil
                }
            }
        )
    }

    private func setTabBarHidden(_ hidden: Bool) {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(StitchTheme.background)

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().isTranslucent = false
        UITabBar.appearance().isHidden = hidden
    }
}

struct WorkoutSummaryView: View {
    let summary: WorkoutSummary
    let syncStatus: WorkoutSyncStatus
    let onRetrySync: () -> Void
    let onViewHistory: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    syncStatusView
                    statsGrid
                    exerciseList
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .padding(.bottom, 120)
            }

            VStack(spacing: 12) {
                Button(action: onViewHistory) {
                    Text("查看历史记录")
                        .font(StitchTypography.label)
                        .foregroundColor(StitchTheme.onPrimaryFixed)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(StitchTheme.primaryContainer)
                        .cornerRadius(14)
                }

                Button(action: onDone) {
                    Text("完成")
                        .font(StitchTypography.labelSmall)
                        .foregroundColor(StitchTheme.primaryContainer)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(StitchTheme.primaryContainer.opacity(0.1))
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(StitchTheme.background.opacity(0.98))
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WORKOUT COMPLETE")
                .font(StitchTypography.label)
                .foregroundColor(StitchTheme.onSurfaceVariant)
                .tracking(3)

            Text("训练总结")
                .font(StitchTypography.headlineLarge)
                .italic()
                .foregroundColor(StitchTheme.primaryContainer)

            Text(summary.focusArea)
                .font(StitchTypography.labelSmall)
                .foregroundColor(StitchTheme.onSurfaceVariant)
        }
    }

    private var statsGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                summaryStat(title: "时长", value: formatDuration(summary.duration))
                summaryStat(title: "完成组", value: "\(summary.completedSets)/\(summary.totalSets)")
            }

            HStack(spacing: 12) {
                summaryStat(title: "完成动作", value: "\(summary.completedExercises)/\(summary.exercises.count)")
                summaryStat(title: "总训练量", value: "\(Int(summary.totalVolume))kg")
            }
        }
    }

    private var syncStatusView: some View {
        HStack(spacing: 12) {
            Image(systemName: syncStatus.systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(StitchTheme.primaryContainer)

            VStack(alignment: .leading, spacing: 4) {
                Text("SAVE STATUS")
                    .font(StitchTypography.labelSmall)
                    .foregroundColor(StitchTheme.onSurfaceVariant)
                    .tracking(2)
                Text(syncStatus.title)
                    .font(StitchTypography.label)
                    .foregroundColor(StitchTheme.onSurface)
            }

            Spacer()

            if syncStatus == .failed {
                Button("重试") {
                    onRetrySync()
                }
                .font(StitchTypography.labelSmall)
                .foregroundColor(StitchTheme.onPrimaryFixed)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(StitchTheme.primaryContainer)
                .cornerRadius(8)
            }
        }
        .padding(16)
        .background(StitchTheme.surfaceContainer)
        .cornerRadius(14)
    }

    private var exerciseList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EXERCISES")
                .font(StitchTypography.label)
                .foregroundColor(StitchTheme.onSurfaceVariant)
                .tracking(2)

            ForEach(summary.exercises) { exercise in
                HStack(spacing: 12) {
                    Image(systemName: exercise.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(exercise.isCompleted ? StitchTheme.primaryContainer : StitchTheme.onSurfaceVariant)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.exerciseName)
                            .font(StitchTypography.bodyBold)
                            .foregroundColor(StitchTheme.onSurface)
                            .lineLimit(1)

                        Text("\(exercise.exerciseSets.filter { $0.isCompleted }.count)/\(exercise.exerciseSets.count) 组 · \(Int(exercise.totalVolume))kg")
                            .font(StitchTypography.labelSmall)
                            .foregroundColor(StitchTheme.onSurfaceVariant)
                    }

                    Spacer()
                }
                .padding(12)
                .background(StitchTheme.surfaceContainerLow)
                .cornerRadius(12)
            }
        }
    }

    private func summaryStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(StitchTypography.labelSmall)
                .foregroundColor(StitchTheme.onSurfaceVariant)
            Text(value)
                .font(StitchTypography.dataMedium)
                .foregroundColor(StitchTheme.onSurface)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(StitchTheme.surfaceContainer)
        .cornerRadius(14)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
