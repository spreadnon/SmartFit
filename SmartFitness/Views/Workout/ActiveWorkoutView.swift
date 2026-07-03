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
    @State private var exercisePendingDeletion: Exercise?
    @State private var completedSummary: WorkoutSummary?
    @State private var syncStatus: WorkoutSyncStatus = .notSaved
    @State private var hasInteracted = false
    @State private var originalPlan: TrainingPlan?

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
        ZStack {
            StitchTheme.background.ignoresSafeArea()

            if let completedSummary {
                WorkoutSummaryView(summary: completedSummary, syncStatus: syncStatus) {
                    dismiss()
                }
            } else {
                VStack(spacing: 0) {
                if showingRestComplete {
                    restCompleteBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

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
            clampCurrentExerciseIndex()
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
        VStack(spacing: 12) {
            progressSection
            restBanner
        }
        .padding(.horizontal, 20)
        .padding(.bottom, isResting ? 14 : 12)
        .background(
            StitchTheme.background.opacity(0.98)
                .shadow(color: Color.black.opacity(0.25), radius: 14, y: 8)
        )
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
            ForEach(Array(exercise.exerciseSets.enumerated()), id: \.element.id) { index, set in
                setRow(set: set, index: index, restTime: exercise.restTime)
            }
        }
        .padding(16)
        .background(StitchTheme.surfaceContainer)
        .cornerRadius(16)
    }

    private func setRow(set: ExerciseSet, index: Int, restTime: Int) -> some View {
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
                    .foregroundColor(StitchTheme.onSurfaceVariant)

                HStack(spacing: 12) {
                    valueStepper(
                        value: "\(Int(set.weight))kg",
                        minus: { adjustWeight(at: index, by: -2.5) },
                        plus: { adjustWeight(at: index, by: 2.5) }
                    )

                    valueStepper(
                        value: "\(set.reps)次",
                        minus: { adjustReps(at: index, by: -1) },
                        plus: { adjustReps(at: index, by: 1) }
                    )
                }
            }

            Spacer()
        }
        .padding(12)
        .background(set.isCompleted ? StitchTheme.primaryContainer.opacity(0.08) : StitchTheme.surfaceContainerLow)
        .cornerRadius(12)
    }

    private func valueStepper(value: String, minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Button(action: minus) {
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .bold))
            }

            Text(value)
                .font(StitchTypography.label)
                .foregroundColor(StitchTheme.onSurface)
                .monospacedDigit()
                .frame(minWidth: 52)

            Button(action: plus) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
            }
        }
        .foregroundColor(StitchTheme.primaryContainer)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(StitchTheme.surfaceContainerHigh)
        .cornerRadius(8)
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

    private func toggleSetCompletion(at setIndex: Int, restTime: Int) {
        var completedNow = false
        updateCurrentSet(at: setIndex) { set in
            set.isCompleted.toggle()
            completedNow = set.isCompleted
        }

        if completedNow {
            if isWorkoutComplete {
                isResting = false
                restRemaining = 0
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                showingWorkoutComplete = true
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
        updateCurrentSet(at: setIndex) { set in
            set.reps = max(1, set.reps + amount)
        }
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

    private func moveExercise(by offset: Int) {
        let nextIndex = currentExerciseIndex + offset
        guard exercises.indices.contains(nextIndex) else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            currentExerciseIndex = nextIndex
            isResting = false
            restRemaining = 0
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
        let focusArea = source == .manual ? "CUSTOM" : plan.trainingSplit
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
        } else {
            syncStatus = .notSaved
        }

        completedSummary = WorkoutSummary(
            duration: sessionDuration,
            focusArea: focusArea,
            exercises: day.exercises
        )
    }

    private func discardWorkoutChanges() {
        if let originalPlan {
            assignPlan(originalPlan)
        }
        dismiss()
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
        UITabBar.appearance().isHidden = hidden
    }
}

struct WorkoutSummaryView: View {
    let summary: WorkoutSummary
    let syncStatus: WorkoutSyncStatus
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

            Button(action: onDone) {
                Text("完成")
                    .font(StitchTypography.label)
                    .foregroundColor(StitchTheme.onPrimaryFixed)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(StitchTheme.primaryContainer)
                    .cornerRadius(14)
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
