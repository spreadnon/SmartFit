import SwiftUI

// 真正的今日训练视图
struct TodayTrainingView: View {
    @EnvironmentObject var appData: AppData
    @State private var showingClearConfirmation = false
    @State private var exercisePendingDeletion: Exercise?
    @State private var selectedDayIndex: Int?

    private var activePlan: TrainingPlan? {
        appData.aiSmartPlan ?? appData.manualPlanForToday ?? appData.manualWeeklyPlan
    }

    private var todayDayIndex: Int {
        guard let plan = activePlan else { return 0 }
        if isManualSession(plan) { return 0 }
        let currentWeekday = Calendar.current.component(.weekday, from: Date())
        if let index = plan.days.firstIndex(where: { $0.weekday == currentWeekday }) {
            return index
        }
        return plan.days.firstIndex(where: { $0.kind == .training && !$0.isCompleted }) ?? 0
    }

    var body: some View {
        ZStack {
            StitchTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection

                    if let plan = activePlan, let day = selectedDay(for: plan) {
                        let dayIndex = displayedDayIndex(for: plan)

                        if !isManualSession(plan) {
                            weeklyScheduleSection(plan: plan, selectedDayIndex: dayIndex)
                            missedTrainingBanner(for: plan)
                        }

                        VStack(alignment: .leading, spacing: 24) {
                            todayPlanCard(plan: plan, day: day, dayIndex: dayIndex)
                            exercisePreviewList(day: day, dayIndex: dayIndex, isManualSession: isManualSession(plan))
                        }
                        .gesture(
                            DragGesture(minimumDistance: 40)
                                .onEnded { value in
                                    handleDaySwipe(value.translation.width, in: plan)
                                }
                        )
                    } else {
                        emptyState
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .padding(.bottom, 48)
            }
        }
        .navigationBarHidden(true)
        .toolbar(.visible, for: .tabBar)
        .preferredColorScheme(.dark)
        .onAppear {
            syncSelectedDayWithActivePlan()
        }
        .onChange(of: activePlan?.id) { _ in
            syncSelectedDayWithActivePlan()
        }
        .alert("清空当前训练日？", isPresented: $showingClearConfirmation) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                clearSelectedTrainingDay()
            }
        } message: {
            Text("这会移除当前选中训练日里的动作。")
        }
        .alert("删除动作？", isPresented: deleteConfirmationBinding) {
            Button("取消", role: .cancel) {
                exercisePendingDeletion = nil
            }
            Button("删除", role: .destructive) {
                if let exercise = exercisePendingDeletion {
                    appData.removeExerciseFromToday(exerciseId: exercise.id)
                }
                exercisePendingDeletion = nil
            }
        } message: {
            Text("这会从今日训练中移除该动作。")
        }
    }

    private func weeklyScheduleSection(plan: TrainingPlan, selectedDayIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("WEEK PLAN")
                        .font(StitchTypography.label)
                        .foregroundColor(StitchTheme.onSurfaceVariant)
                        .tracking(3)

                    Text("训练日 / 恢复日安排")
                        .font(StitchTypography.labelSmall)
                        .foregroundColor(StitchTheme.onSurfaceVariant)
                }

                Spacer()

                Text(weeklyProgressText(for: plan))
                    .font(StitchTypography.labelSmall)
                    .foregroundColor(StitchTheme.primaryContainer)
            }

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(0..<max(7, plan.days.count), id: \.self) { index in
                            weekScheduleItem(plan: plan, index: index, selectedDayIndex: selectedDayIndex)
                                .id(weekScheduleItemId(for: index))
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.horizontal, -24)
                .onAppear {
                    scrollWeekPlan(to: selectedDayIndex, proxy: proxy, animated: false)
                }
                .onChange(of: self.selectedDayIndex) { index in
                    guard let index else { return }
                    scrollWeekPlan(to: index, proxy: proxy, animated: true)
                }
            }
        }
    }

    @ViewBuilder
    private func weekScheduleItem(plan: TrainingPlan, index: Int, selectedDayIndex: Int) -> some View {
        let date = scheduleDate(for: index, day: plan.days.indices.contains(index) ? plan.days[index] : nil, in: plan)
        let isToday = Calendar.current.isDate(date, inSameDayAs: Date())

        if index < plan.days.count {
            let day = plan.days[index]
            let isSelected = index == selectedDayIndex
            let progress = progressInfo(for: day)
            let isCompleted = progress.total > 0 && progress.completed == progress.total

            Button {
                selectDay(index, in: plan)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text(weekdayText(for: date, day: day))
                        if isToday {
                            Circle()
                                .fill(isSelected ? StitchTheme.onPrimaryFixed : StitchTheme.primaryContainer)
                                .frame(width: 5, height: 5)
                        }
                    }
                    .font(StitchTypography.labelSmall)
                    .foregroundColor(isSelected ? StitchTheme.onPrimaryFixed.opacity(0.8) : StitchTheme.onSurfaceVariant)

                    Text(dayDisplayTitle(for: day))
                        .font(StitchTypography.label)
                        .foregroundColor(isSelected ? StitchTheme.onPrimaryFixed : StitchTheme.primaryContainer)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(isCompleted ? "已完成" : focusTitle(for: day))
                        .font(StitchTypography.labelSmall)
                        .foregroundColor(isSelected ? StitchTheme.onPrimaryFixed.opacity(0.85) : StitchTheme.onSurfaceVariant)
                        .lineLimit(1)
                }
                .frame(width: 104, alignment: .leading)
                .padding(12)
                .background(isSelected ? StitchTheme.primaryContainer : StitchTheme.surfaceContainerLow)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isToday && !isSelected ? StitchTheme.primaryContainer.opacity(0.5) : Color.clear, lineWidth: 1)
                )
                .cornerRadius(14)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(weekdayText(for: date, day: nil))
                    .font(StitchTypography.labelSmall)
                    .foregroundColor(StitchTheme.onSurfaceVariant)

                Text("恢复")
                    .font(StitchTypography.label)
                    .foregroundColor(StitchTheme.onSurfaceVariant)

                Text("休息 / 拉伸")
                    .font(StitchTypography.labelSmall)
                    .foregroundColor(StitchTheme.onSurfaceVariant.opacity(0.8))
                    .lineLimit(1)
            }
            .frame(width: 104, alignment: .leading)
            .padding(12)
            .background(StitchTheme.surfaceContainerLow.opacity(0.55))
            .cornerRadius(14)
        }
    }

    @ViewBuilder
    private func missedTrainingBanner(for plan: TrainingPlan) -> some View {
        let missedIndices = missedTrainingDayIndices(for: plan)

        if let firstMissedIndex = missedIndices.first {
            Button {
                selectDay(firstMissedIndex, in: plan)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 18, weight: .semibold))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("有 \(missedIndices.count) 个计划训练日未完成")
                            .font(StitchTypography.labelSmall)
                        Text("点击查看 \(dayDisplayTitle(for: plan.days[firstMissedIndex]))")
                            .font(StitchTypography.labelSmall)
                            .foregroundColor(StitchTheme.onSurfaceVariant)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(StitchTheme.primaryContainer)
                .padding(14)
                .background(StitchTheme.primaryContainer.opacity(0.1))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TODAY")
                .font(StitchTypography.label)
                .foregroundColor(StitchTheme.onSurfaceVariant)
                .tracking(4)

            Text("READY TO TRAIN")
                .font(StitchTypography.headlineLarge)
                .italic()
                .foregroundColor(StitchTheme.onSurface)

            Text(Date(), style: .date)
                .font(StitchTypography.labelSmall)
                .foregroundColor(StitchTheme.onSurfaceVariant)
        }
    }

    private func todayPlanCard(plan: TrainingPlan, day: TrainingDay, dayIndex: Int) -> some View {
        let progress = progressInfo(for: day)
        let percentage = progress.total == 0 ? 0 : Int((Double(progress.completed) / Double(progress.total)) * 100)
        let isCompleted = progress.total > 0 && progress.completed == progress.total

        return VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(isManualSession(plan) ? "CUSTOM SESSION" : "\(plan.trainingSplit.uppercased()) · \(dayDisplayTitle(for: day))")
                        .font(StitchTypography.labelSmall)
                        .foregroundColor(StitchTheme.onSurfaceVariant)
                        .tracking(2)

                    Text(focusTitle(for: day))
                        .font(StitchTypography.headline)
                        .foregroundColor(StitchTheme.primaryContainer)
                        .lineLimit(2)

                    if !isManualSession(plan) {
                        Text(scheduleDisplayText(for: dayIndex, in: plan))
                            .font(StitchTypography.labelSmall)
                            .foregroundColor(StitchTheme.onSurfaceVariant)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(percentage)%")
                        .font(StitchTypography.dataLarge)
                        .foregroundColor(StitchTheme.primaryContainer)
                    Text("\(progress.completed)/\(progress.total) 组")
                        .font(StitchTypography.labelSmall)
                        .foregroundColor(StitchTheme.onSurfaceVariant)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(StitchTheme.surfaceContainerHighest)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(StitchTheme.primaryContainer)
                        .frame(width: geo.size.width * CGFloat(percentage) / 100)
                }
            }
            .frame(height: 8)

            HStack(spacing: 12) {
                statBlock(title: "动作", value: "\(day.exercises.count)")
                statBlock(title: "总组数", value: "\(progress.total)")
                statBlock(title: "已完成", value: "\(progress.completed)")
            }

            if day.kind != .training {
                HStack(spacing: 12) {
                    Image(systemName: day.kind == .rest ? "moon.fill" : "figure.cooldown")

                    VStack(alignment: .leading, spacing: 3) {
                        Text(day.kind == .rest ? "今天安排为休息日" : "今天安排为恢复日")
                        if let nextTrainingText = nextTrainingText(after: dayIndex, in: plan) {
                            Text(nextTrainingText)
                                .font(StitchTypography.labelSmall)
                                .foregroundColor(StitchTheme.onSurfaceVariant)
                        }
                    }

                    Spacer()
                }
                .font(StitchTypography.label)
                .foregroundColor(StitchTheme.primaryContainer)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(StitchTheme.primaryContainer.opacity(0.1))
                .cornerRadius(12)
            } else if day.exercises.isEmpty {
                Button {
                    appData.libraryInsertionTarget = LibraryInsertionTarget(planType: planType(for: plan), dayIndex: dayIndex)
                    appData.selectedTab = 2
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("先添加动作")
                    }
                    .font(StitchTypography.label)
                    .foregroundColor(StitchTheme.onPrimaryFixed)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(StitchTheme.primaryContainer)
                    .cornerRadius(12)
                }
            } else if isCompleted {
                Button {
                    appData.selectedTab = 3
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("本日训练已完成，查看记录")
                    }
                    .font(StitchTypography.label)
                    .foregroundColor(StitchTheme.onPrimaryFixed)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(StitchTheme.primaryContainer)
                    .cornerRadius(12)
                }
            } else {
                NavigationLink {
                    ActiveWorkoutView(source: workoutSource(for: plan), dayIndex: dayIndex)
                } label: {
                    HStack {
                        Image(systemName: progress.completed > 0 ? "play.fill" : "bolt.fill")
                        Text(progress.completed > 0 ? "继续训练" : "开始训练")
                    }
                    .font(StitchTypography.label)
                    .foregroundColor(StitchTheme.onPrimaryFixed)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(StitchTheme.primaryContainer)
                    .cornerRadius(12)
                }
            }

            HStack(spacing: 12) {
                Button {
                    appData.libraryInsertionTarget = LibraryInsertionTarget(planType: planType(for: plan), dayIndex: dayIndex)
                    appData.selectedTab = 2
                } label: {
                    Text("添加动作")
                        .font(StitchTypography.labelSmall)
                        .foregroundColor(StitchTheme.primaryContainer)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(StitchTheme.primaryContainer.opacity(0.1))
                        .cornerRadius(10)
                }

                Button {
                    showingClearConfirmation = true
                } label: {
                    Text("清空当前日")
                        .font(StitchTypography.labelSmall)
                        .foregroundColor(StitchTheme.onSurfaceVariant)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(StitchTheme.surfaceContainerHigh)
                        .cornerRadius(10)
                }
            }
        }
        .padding(24)
        .background(StitchTheme.surfaceContainer)
        .cornerRadius(16)
    }

    private func statBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(StitchTypography.labelSmall)
                .foregroundColor(StitchTheme.onSurfaceVariant)
            Text(value)
                .font(StitchTypography.dataMedium)
                .foregroundColor(StitchTheme.onSurface)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(StitchTheme.surfaceContainerLow)
        .cornerRadius(10)
    }

    private func exercisePreviewList(day: TrainingDay, dayIndex: Int, isManualSession: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(isManualSession ? "TODAY'S EXERCISES" : "\(dayDisplayTitle(for: day)) EXERCISES")
                    .font(StitchTypography.label)
                    .foregroundColor(StitchTheme.onSurfaceVariant)
                    .tracking(2)

                Spacer()

                if !isManualSession {
                    Text("Day \(dayIndex + 1)")
                        .font(StitchTypography.labelSmall)
                        .foregroundColor(StitchTheme.primaryContainer)
                }
            }

            if day.exercises.isEmpty {
                Text(day.kind == .training ? "还没有添加动作，点上方“添加动作”开始配置。" : "这一天不安排正式训练。")
                    .font(StitchTypography.body)
                    .foregroundColor(StitchTheme.onSurfaceVariant)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ForEach(day.exercises) { exercise in
                    HStack(spacing: 12) {
                        Image(systemName: exercise.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(exercise.isCompleted ? StitchTheme.primaryContainer : StitchTheme.onSurfaceVariant)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.exerciseName)
                                .font(StitchTypography.bodyBold)
                                .foregroundColor(StitchTheme.onSurface)
                                .lineLimit(1)

                            Text("\(exercise.exerciseSets.filter { $0.isCompleted }.count)/\(exercise.exerciseSets.count) 组 · \(exercise.equipment)")
                                .font(StitchTypography.labelSmall)
                                .foregroundColor(StitchTheme.onSurfaceVariant)
                        }

                        Spacer()

                        if !exercise.isCompleted {
                            Button {
                                exercisePendingDeletion = exercise
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(StitchTheme.onSurfaceVariant)
                                    .padding(8)
                                    .background(StitchTheme.surfaceContainerHigh)
                                    .clipShape(Circle())
                            }
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(StitchTheme.surfaceContainerLow)
        .cornerRadius(16)
    }

    private var emptyState: some View {
        VStack(spacing: 22) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 56))
                .foregroundColor(StitchTheme.onSurfaceVariant.opacity(0.4))

            VStack(spacing: 8) {
                Text("NO TRAINING TODAY")
                    .font(StitchTypography.dataMedium)
                    .foregroundColor(StitchTheme.onSurface)
                Text("Generate a plan or build a custom session from the library.")
                    .font(StitchTypography.body)
                    .foregroundColor(StitchTheme.onSurfaceVariant)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button {
                    appData.selectedTab = 0
                } label: {
                    Text("AI 计划")
                        .font(StitchTypography.label)
                        .foregroundColor(StitchTheme.onPrimaryFixed)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(StitchTheme.primaryContainer)
                        .cornerRadius(10)
                }

                Button {
                    appData.selectedTab = 2
                } label: {
                    Text("手动添加")
                        .font(StitchTypography.label)
                        .foregroundColor(StitchTheme.primaryContainer)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(StitchTheme.primaryContainer.opacity(0.1))
                        .cornerRadius(10)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(StitchTheme.surfaceContainerLow)
        .cornerRadius(16)
    }

    private func isManualSession(_ plan: TrainingPlan) -> Bool {
        plan.trainingSplit == "MANUAL" || plan.trainingSplit == "自选训练"
    }

    private func displayedDayIndex(for plan: TrainingPlan) -> Int {
        guard !plan.days.isEmpty else { return 0 }
        if isManualSession(plan) { return 0 }
        if let selectedDayIndex, plan.days.indices.contains(selectedDayIndex) {
            return selectedDayIndex
        }
        return min(todayDayIndex, plan.days.count - 1)
    }

    private func selectedDay(for plan: TrainingPlan) -> TrainingDay? {
        guard !plan.days.isEmpty else { return nil }
        return plan.days[displayedDayIndex(for: plan)]
    }

    private func syncSelectedDayWithActivePlan() {
        guard let plan = activePlan, !plan.days.isEmpty, !isManualSession(plan) else {
            selectedDayIndex = nil
            return
        }

        if let selectedDayIndex, plan.days.indices.contains(selectedDayIndex) {
            return
        }

        selectedDayIndex = min(todayDayIndex, plan.days.count - 1)
    }

    private func selectDay(_ index: Int, in plan: TrainingPlan) {
        guard !isManualSession(plan), plan.days.indices.contains(index) else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            selectedDayIndex = index
        }
    }

    private func handleDaySwipe(_ horizontalTranslation: CGFloat, in plan: TrainingPlan) {
        guard !isManualSession(plan), plan.days.count > 1, abs(horizontalTranslation) > 60 else { return }

        let currentIndex = displayedDayIndex(for: plan)
        let nextIndex = horizontalTranslation < 0 ? min(currentIndex + 1, plan.days.count - 1) : max(currentIndex - 1, 0)
        guard nextIndex != currentIndex else { return }
        selectDay(nextIndex, in: plan)
    }

    private func clearSelectedTrainingDay() {
        guard let plan = activePlan else { return }

        if isManualSession(plan) {
            appData.clearTodayTraining()
            return
        }

        switch planType(for: plan) {
        case .ai:
            guard var aiPlan = appData.aiSmartPlan, aiPlan.days.indices.contains(displayedDayIndex(for: aiPlan)) else { return }
            aiPlan.days[displayedDayIndex(for: aiPlan)].exercises.removeAll()
            appData.aiSmartPlan = aiPlan
        case .manual:
            guard var manualPlan = appData.manualPlan, manualPlan.days.indices.contains(displayedDayIndex(for: manualPlan)) else { return }
            manualPlan.days[displayedDayIndex(for: manualPlan)].exercises.removeAll()
            appData.manualPlan = manualPlan
        }
    }

    private func workoutSource(for plan: TrainingPlan) -> ActiveWorkoutSource {
        planType(for: plan) == .manual ? .manual : .ai
    }

    private func planType(for plan: TrainingPlan) -> TrainingPlanType {
        appData.manualPlan?.id == plan.id ? .manual : .ai
    }

    private func scheduleDate(for index: Int, day: TrainingDay?, in plan: TrainingPlan) -> Date {
        if let weekday = day?.weekday {
            return dateInCurrentWeek(for: weekday)
        }
        return Calendar.current.date(byAdding: .day, value: index, to: plan.createdAt) ?? plan.createdAt
    }

    private func weekdayText(for date: Date, day: TrainingDay?) -> String {
        let weekday = day?.weekday ?? Calendar.current.component(.weekday, from: date)
        let names = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        return names[max(0, min(weekday - 1, names.count - 1))]
    }

    private func scheduleDisplayText(for index: Int, in plan: TrainingPlan) -> String {
        let dayModel = plan.days.indices.contains(index) ? plan.days[index] : nil
        let date = scheduleDate(for: index, day: dayModel, in: plan)
        let month = Calendar.current.component(.month, from: date)
        let day = Calendar.current.component(.day, from: date)
        return "\(weekdayText(for: date, day: dayModel)) · \(month)月\(day)日"
    }

    private func dateInCurrentWeek(for weekday: Int) -> Date {
        let calendar = Calendar.current
        let today = Date()
        let currentWeekday = calendar.component(.weekday, from: today)
        let delta = weekday - currentWeekday
        return calendar.date(byAdding: .day, value: delta, to: today) ?? today
    }

    private func weeklyProgressText(for plan: TrainingPlan) -> String {
        let trainingDays = plan.days.filter { $0.kind == .training }
        let completedDays = trainingDays.filter { $0.isCompleted }.count
        return "\(completedDays)/\(trainingDays.count) 训练日"
    }

    private func missedTrainingDayIndices(for plan: TrainingPlan) -> [Int] {
        plan.days.indices.filter { index in
            let day = plan.days[index]
            guard day.kind == .training,
                  !day.isCompleted,
                  let weekday = day.weekday else {
                return false
            }

            return dateInCurrentWeek(for: weekday) < Calendar.current.startOfDay(for: Date())
        }
    }

    private func weekScheduleItemId(for index: Int) -> String {
        "week-schedule-day-\(index)"
    }

    private func scrollWeekPlan(to index: Int, proxy: ScrollViewProxy, animated: Bool) {
        let action = {
            proxy.scrollTo(weekScheduleItemId(for: index), anchor: .center)
        }

        if animated {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                action()
            }
        } else {
            DispatchQueue.main.async {
                action()
            }
        }
    }

    private func nextTrainingText(after dayIndex: Int, in plan: TrainingPlan) -> String? {
        guard plan.days.count > 1 else { return nil }

        for offset in 1..<plan.days.count {
            let index = (dayIndex + offset) % plan.days.count
            let day = plan.days[index]
            guard day.kind == .training else { continue }

            let weekday: String
            if let dayWeekday = day.weekday {
                weekday = weekdayText(for: dateInCurrentWeek(for: dayWeekday), day: day)
            } else {
                weekday = "训练日"
            }

            return "下一次训练：\(weekday) · \(dayDisplayTitle(for: day))"
        }

        return nil
    }

    private func dayDisplayTitle(for day: TrainingDay) -> String {
        switch day.kind {
        case .training:
            return day.focus ?? day.label
        case .recovery:
            return "恢复"
        case .rest:
            return "休息"
        }
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

    private func progressInfo(for day: TrainingDay) -> (completed: Int, total: Int) {
        let sets = day.exercises.flatMap { $0.exerciseSets }
        return (sets.filter { $0.isCompleted }.count, sets.count)
    }

    private func focusTitle(for day: TrainingDay) -> String {
        if day.kind == .rest {
            return "休息日"
        }
        if day.kind == .recovery {
            return "主动恢复 / 拉伸"
        }

        let muscles = day.exercises
            .flatMap { $0.localizedMuscleNames.isEmpty ? $0.primaryMuscles : $0.localizedMuscleNames }
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let uniqueMuscles = Array(NSOrderedSet(array: muscles)) as? [String] ?? []
        if !uniqueMuscles.isEmpty {
            return uniqueMuscles.prefix(2).joined(separator: " / ")
        }
        return day.focus ?? day.label.components(separatedBy: "·").last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? NSLocalizedString("全身训练", comment: "")
    }
}
