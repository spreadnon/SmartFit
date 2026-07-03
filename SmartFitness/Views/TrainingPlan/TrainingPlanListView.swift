import SwiftUI

struct TrainingPlanListView: View {
    @EnvironmentObject var appData: AppData
    @State private var showingGeneratePlan = false
    @State private var showingManualWeeklyPlanBuilder = false

    private var activeDisplayPlan: TrainingPlan? {
        appData.aiSmartPlan ?? appData.manualPlanForToday ?? appData.manualWeeklyPlan
    }

    var body: some View {
        ZStack(alignment: .top) {
            StitchTheme.background.ignoresSafeArea()
            
            // Fixed Top Bar (Glassmorphic)
            //            glassHeader
            //                .zIndex(10)
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 32) {
                    
                    // Welcome Header
                    welcomeSection
                        .padding(.top, 50) // Spacing for top bar
                        .padding(.horizontal, 20)
                    
                    // Today's Arrangement Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("THE PLAN")
                                    .font(StitchTypography.label)
                                    .foregroundColor(StitchTheme.onSurfaceVariant)
                                    .tracking(2)
                                
                                Text("TRAINING PLAN")
                                    .font(StitchTypography.headline)
                                    .foregroundColor(StitchTheme.onSurface)
                            }
                            Spacer()
                        }
                        
                        if let plan = activeDisplayPlan {
                            aiPlanArrangementCard(plan: plan)
                        } else {
                            // Empty State
                            emptyStateSection
                        }
                        
                        // Quick Entry Actions (Ignition Blocks)
                        HStack(spacing: 16) {
                            entryButton(
                                title: NSLocalizedString("AI GEN", comment: ""),
                                subtitle: NSLocalizedString("SMART GEN", comment: ""),
                                icon: "sparkles",
                                color: StitchTheme.primaryContainer,
                                textColor: StitchTheme.onPrimaryFixed
                            ) {
                                if appData.isLoggedIn {
                                    showingGeneratePlan = true
                                } else {
                                    AuthService.shared.startAppleLogin { result in
                                        switch result {
                                        case .success(let user):
                                            appData.currentUser = user
                                            showingGeneratePlan = true
                                        case .failure(let error):
                                            print("Login failed: \(error.localizedDescription)")
                                        }
                                    }
                                }
                            }
                            
                            entryButton(
                                title: NSLocalizedString("MANUAL", comment: ""),
                                subtitle: NSLocalizedString("MANUAL", comment: ""),
                                icon: "plus.circle",
                                color: StitchTheme.surfaceContainerHigh,
                                textColor: StitchTheme.primary
                            ) {
                                showingManualWeeklyPlanBuilder = true
                            }
                        }
                        
//                        HStack(spacing: 16) {
//                            entryButton(
//                                title: NSLocalizedString("食物热量", comment: ""),
//                                subtitle: NSLocalizedString("查看食物的热量", comment: ""),
//                                icon: "sparkles",
//                                color: StitchTheme.primaryContainer,
//                                textColor: StitchTheme.onPrimaryFixed
//                            ) {
//                                if appData.isLoggedIn {
//                                    showingGeneratePlan = true
//                                } else {
//                                    AuthService.shared.startAppleLogin { result in
//                                        switch result {
//                                        case .success(let user):
//                                            appData.currentUser = user
//                                            showingGeneratePlan = true
//                                        case .failure(let error):
//                                            print("Login failed: \(error.localizedDescription)")
//                                        }
//                                    }
//                                }
//                            }
//                            
//                        }
                        .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .navigationBarHidden(true)
            .toolbar(.visible, for: .tabBar)
            .sheet(isPresented: $showingGeneratePlan){
                GeneratePlanView()
//                FoodCalorieView()
//                LocalLLMView()
//                MultiImageScheduleView()
//                DrinkOCRView()
//                llmBitnetView()
            }
            .sheet(isPresented: $showingManualWeeklyPlanBuilder) {
                ManualWeeklyPlanBuilderView()
            }
        }
    }
    // MARK: - Components
    
    private var glassHeader: some View {
        HStack {
            HStack(spacing: 12) {
                Button(action: {
                    if appData.isLoggedIn {
                        appData.currentUser = nil
                    }
                }) {
                    Circle()
                        .fill(StitchTheme.surfaceContainerHigh)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: appData.isLoggedIn ? "person.badge.minus" : "person.fill")
                                .font(.system(size: 14))
                                .foregroundColor(StitchTheme.onSurfaceVariant)
                        )
                        .overlay(Circle().stroke(StitchTheme.outlineVariant.opacity(0.2), lineWidth: 1))
                }
            }
            
            Spacer()
            
            Text("KINETIC NOIR")
                .font(StitchTypography.headline)
                .italic()
                .tracking(4)
                .foregroundColor(StitchTheme.primaryContainer)
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(StitchTheme.primaryContainer)
            }
        }
        .padding(.horizontal, 24)
        .frame(height: 64)
        .background(
            StitchTheme.surfaceContainerLow.opacity(0.8)
                .background(.ultraThinMaterial)
        )
    }
    
    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("COMMAND CENTER")
                .font(StitchTypography.label)
                .foregroundColor(StitchTheme.onSurfaceVariant)
                .tracking(4)
            
            Group {
                Text("WELCOME BACK,\n\(appData.currentUser?.name ?? "TRAINER")")
                    .font(StitchTypography.headlineLarge)
                    .foregroundColor(StitchTheme.onSurface)
                    .italic()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        queryWeather()
                    }
            }
        }
    }

    private func queryWeather() {
//        // 查询天气（同步）
//        A2AClient.shared.sendRequest(action: "query_weather", payload: ["city": "北京"]) { res, err in
//            print("返回：", res ?? "无数据")
//            if let err {
//                print("错误：", err)
//            }
//        }
        
        
        // // 流式 AI 对话
        // var fullText = ""
        // A2ASSEClient.shared.sendStreamRequest(
        //     prompt: "你好，请介绍一下 A2A 协议"
        // ) { char in
        //     // 每收到一个字，拼接显示
        //     fullText += char
        //     print(fullText)
        //     // 你可以在这里更新 UILabel / UITextView
        //     if fullText.count > 5{
        //         A2ASSEClient.shared.stopCurrentStream()
        //     }
        // } onComplete: {
        //     print("✅ 流式输出完成")
        // }
    }
    
    private func aiPlanArrangementCard(plan: TrainingPlan) -> some View {
        let isManualSession = plan.trainingSplit == "自选训练" || plan.trainingSplit == "MANUAL"
        let featuredDayIndex = featuredDayIndex(for: plan)
        let planTitle = plan.trainingSplit
        
        let progress: CGFloat
        let progressDetail: String
        
        if isManualSession, let firstDay = plan.days.first {
            let allSets = firstDay.exercises.flatMap { $0.exerciseSets }
            let completedCount = allSets.filter { $0.isCompleted }.count
            let totalCount = max(allSets.count, 1)
            progress = CGFloat(completedCount) / CGFloat(totalCount)
            progressDetail = "\(completedCount)/\(allSets.count) 组"
        } else {
            let trainingDays = plan.days.filter { $0.kind == .training }
            let completedCount = trainingDays.filter { $0.isCompleted }.count
            let totalCount = max(trainingDays.count, 1)
            progress = CGFloat(completedCount) / CGFloat(totalCount)
            progressDetail = "\(completedCount)/\(trainingDays.count) 训练日"
        }
        
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("IN PROGRESS")
                        .font(StitchTypography.labelSmall)
                        .foregroundColor(StitchTheme.onSurfaceVariant)
                    Text(planTitle)
                        .font(StitchTypography.dataLarge)
                        .foregroundColor(StitchTheme.primaryContainer)
                }
                Spacer()
                if appData.manualWeeklyPlan?.id == plan.id {
                    Button {
                        showingManualWeeklyPlanBuilder = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title3)
                            .foregroundColor(StitchTheme.primaryContainer)
                            .padding(14)
                            .background(StitchTheme.primaryContainer.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                if plan.days.indices.contains(featuredDayIndex) {
                    let featuredDay = plan.days[featuredDayIndex]
                    if featuredDay.kind != .training {
                        Image(systemName: dayIcon(for: featuredDay))
                            .font(.title2)
                            .foregroundColor(StitchTheme.onSurfaceVariant)
                            .padding(16)
                            .background(StitchTheme.surfaceContainerHigh)
                            .clipShape(Circle())
                    } else if featuredDay.exercises.isEmpty, appData.manualWeeklyPlan?.id == plan.id {
                        Button {
                            appData.libraryInsertionTarget = LibraryInsertionTarget(planType: .manual, dayIndex: featuredDayIndex)
                            appData.selectedTab = 2
                        } label: {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(StitchTheme.onPrimaryFixed)
                                .padding(16)
                                .background(StitchTheme.primaryContainer)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    } else {
                        NavigationLink(destination: ActiveWorkoutView(source: workoutSource(for: plan), dayIndex: isManualSession ? 0 : featuredDayIndex)) {
                            Image(systemName: "play.fill")
                                .font(.title2)
                                .foregroundColor(StitchTheme.onPrimaryFixed)
                                .padding(16)
                                .background(StitchTheme.primaryContainer)
                                .clipShape(Circle())
                        }
                    }
                }
            }
            
            if !plan.days.isEmpty {
                todayExercisePreview(for: plan.days[min(featuredDayIndex, plan.days.count - 1)])
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("进度")
                        .font(StitchTypography.labelSmall)
                        .foregroundColor(StitchTheme.onSurfaceVariant)
                    Spacer()
                    Text("\(progressDetail) · \(Int(progress * 100))%")
                        .font(StitchTypography.labelSmall)
                        .foregroundColor(StitchTheme.primaryContainer)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(StitchTheme.surfaceContainerHighest)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(StitchTheme.primaryContainer)
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 8)
            }

            if !isManualSession {
                weeklyAdherenceSection(for: plan)
            }
            
            VStack(spacing: 10) {
                ForEach(Array(plan.days.enumerated()), id: \.offset) { index, day in
                    if day.kind == .training {
                        if day.exercises.isEmpty, appData.manualWeeklyPlan?.id == plan.id {
                            Button {
                                appData.libraryInsertionTarget = LibraryInsertionTarget(planType: .manual, dayIndex: index)
                                appData.selectedTab = 2
                            } label: {
                                planDayRow(day: day, index: index)
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink(destination: ActiveWorkoutView(source: workoutSource(for: plan), dayIndex: isManualSession ? 0 : index)) {
                                planDayRow(day: day, index: index)
                            }
                        }
                    } else {
                        planDayRow(day: day, index: index)
                    }
                }
            }
        }
        .padding(24)
        .background(StitchTheme.surfaceContainer)
        .cornerRadius(12)
    }

    private func weeklyAdherenceSection(for plan: TrainingPlan) -> some View {
        let plannedDates = plannedTrainingDatesThisWeek(for: plan)
        let completedCount = completedPlannedTrainingCount(plannedDates: plannedDates)
        let missedCount = missedPlannedTrainingCount(for: plan)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("本周达成")
                    .font(StitchTypography.labelSmall)
                    .foregroundColor(StitchTheme.onSurfaceVariant)
                Spacer()
                Text("\(completedCount)/\(plannedDates.count)")
                    .font(StitchTypography.labelSmall)
                    .foregroundColor(StitchTheme.primaryContainer)
            }

            HStack(spacing: 10) {
                planMetricPill(title: "计划", value: "\(plannedDates.count)")
                planMetricPill(title: "完成", value: "\(completedCount)")
                planMetricPill(title: "未练", value: "\(missedCount)")
            }
        }
        .padding(12)
        .background(StitchTheme.surfaceContainerLow)
        .cornerRadius(10)
    }

    private func planMetricPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(StitchTypography.labelSmall)
                .foregroundColor(StitchTheme.onSurfaceVariant)
            Text(value)
                .font(StitchTypography.label)
                .foregroundColor(StitchTheme.onSurface)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func planDayRow(day: TrainingDay, index: Int) -> some View {
        let isToday = isToday(day)
        let isMissed = isMissedPlannedTraining(day)

        return HStack(spacing: 10) {
            Text(weekdayTitle(for: day, fallbackIndex: index))
                .font(StitchTypography.label)
                .foregroundColor(isToday || isMissed ? StitchTheme.primaryContainer : (day.kind == .training ? (day.isCompleted ? StitchTheme.onSurfaceVariant : StitchTheme.primaryContainer) : StitchTheme.onSurfaceVariant))
                .strikethrough(day.isCompleted, color: StitchTheme.onSurfaceVariant)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 72, alignment: .leading)

            Text(currentDayFocusTitle(for: day))
                .font(StitchTypography.label)
                .foregroundColor(day.kind == .training ? (day.isCompleted ? StitchTheme.onSurfaceVariant : StitchTheme.onSurface) : StitchTheme.onSurfaceVariant)
                .strikethrough(day.isCompleted, color: StitchTheme.onSurfaceVariant)
                .lineLimit(1)

            Spacer()

            Text(planDayStatusText(for: day, isToday: isToday, isMissed: isMissed))
                .font(StitchTypography.labelSmall)
                .foregroundColor(isToday || isMissed ? StitchTheme.primaryContainer : StitchTheme.onSurfaceVariant)

            Image(systemName: dayIcon(for: day, isMissed: isMissed))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(day.isCompleted || isToday || isMissed ? StitchTheme.primaryContainer : StitchTheme.onSurfaceVariant)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(StitchTheme.surfaceContainerLow)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isToday || isMissed ? StitchTheme.primaryContainer.opacity(0.55) : Color.clear, lineWidth: 1)
        )
        .cornerRadius(8)
    }

    private func todayExercisePreview(for day: TrainingDay) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TODAY · \(weekdayTitle(for: day, fallbackIndex: 0))")
                .font(StitchTypography.labelSmall)
                .foregroundColor(StitchTheme.onSurfaceVariant)
                .tracking(2)

            if day.kind != .training {
                HStack(spacing: 8) {
                    Image(systemName: dayIcon(for: day))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(StitchTheme.onSurfaceVariant)
                    Text(currentDayFocusTitle(for: day))
                        .font(StitchTypography.labelSmall)
                        .foregroundColor(StitchTheme.onSurfaceVariant)
                    Spacer()
                }
            } else if day.exercises.isEmpty {
                Text("还没有添加动作")
                    .font(StitchTypography.labelSmall)
                    .foregroundColor(StitchTheme.onSurfaceVariant)
            } else {
                ForEach(day.exercises.prefix(4)) { exercise in
                    HStack(spacing: 8) {
                        Image(systemName: exercise.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(exercise.isCompleted ? StitchTheme.primaryContainer : StitchTheme.onSurfaceVariant)

                        Text(exercise.exerciseName)
                            .font(StitchTypography.labelSmall)
                            .foregroundColor(StitchTheme.onSurface)
                            .lineLimit(1)

                        Spacer()

                        Text("\(exercise.exerciseSets.filter { $0.isCompleted }.count)/\(exercise.exerciseSets.count)")
                            .font(StitchTypography.labelSmall)
                            .foregroundColor(StitchTheme.onSurfaceVariant)
                    }
                }

                if day.exercises.count > 4 {
                    Text("+\(day.exercises.count - 4) more")
                        .font(StitchTypography.labelSmall)
                        .foregroundColor(StitchTheme.onSurfaceVariant)
                }
            }
        }
        .padding(12)
        .background(StitchTheme.surfaceContainerLow)
        .cornerRadius(10)
    }
    
    private func currentDayFocusTitle(for day: TrainingDay) -> String {
        if day.kind == .rest {
            return "完全休息"
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
        return day.focus ?? day.label.components(separatedBy: "·").last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? NSLocalizedString("全身", comment: "")
    }

    private func featuredDayIndex(for plan: TrainingPlan) -> Int {
        guard !plan.days.isEmpty else { return 0 }

        let currentWeekday = Calendar.current.component(.weekday, from: Date())
        if let todayIndex = plan.days.firstIndex(where: { $0.weekday == currentWeekday }) {
            return todayIndex
        }

        return plan.days.firstIndex(where: { $0.kind == .training && !$0.isCompleted }) ?? 0
    }

    private func plannedTrainingDatesThisWeek(for plan: TrainingPlan) -> [Date] {
        plan.days.compactMap { day in
            guard day.kind == .training,
                  let weekday = day.weekday else {
                return nil
            }
            return dateInCurrentWeek(for: weekday)
        }
    }

    private func completedPlannedTrainingCount(plannedDates: [Date]) -> Int {
        plannedDates.filter { plannedDate in
            appData.records.contains { record in
                Calendar.current.isDate(record.date, inSameDayAs: plannedDate) && record.isCompleted
            }
        }.count
    }

    private func missedPlannedTrainingCount(for plan: TrainingPlan) -> Int {
        plannedTrainingDatesThisWeek(for: plan).filter { date in
            let hasRecord = appData.records.contains { Calendar.current.isDate($0.date, inSameDayAs: date) }
            return !hasRecord && Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date())
        }.count
    }

    private func isToday(_ day: TrainingDay) -> Bool {
        guard let weekday = day.weekday else { return false }
        return weekday == Calendar.current.component(.weekday, from: Date())
    }

    private func isMissedPlannedTraining(_ day: TrainingDay) -> Bool {
        guard day.kind == .training,
              let weekday = day.weekday else {
            return false
        }

        let date = dateInCurrentWeek(for: weekday)
        let hasRecord = appData.records.contains { Calendar.current.isDate($0.date, inSameDayAs: date) }
        return !hasRecord && Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date())
    }

    private func dateInCurrentWeek(for weekday: Int) -> Date {
        let calendar = Calendar.current
        let today = Date()
        let currentWeekday = calendar.component(.weekday, from: today)
        return calendar.date(byAdding: .day, value: weekday - currentWeekday, to: today) ?? today
    }

    private func weekdayTitle(for day: TrainingDay, fallbackIndex: Int) -> String {
        let weekday = day.weekday ?? fallbackWeekday(for: fallbackIndex)
        let names = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        return names[max(0, min(weekday - 1, names.count - 1))]
    }

    private func fallbackWeekday(for index: Int) -> Int {
        let mondayFirstWeek = [2, 3, 4, 5, 6, 7, 1]
        return mondayFirstWeek[index % mondayFirstWeek.count]
    }

    private func planDayStatusText(for day: TrainingDay, isToday: Bool, isMissed: Bool) -> String {
        if isMissed { return "未练" }
        if isToday { return "今日" }
        if day.kind != .training { return day.kind.localizedTitle }
        if day.exercises.isEmpty { return "配置" }
        return "\(day.exercises.count) 项"
    }

    private func dayIcon(for day: TrainingDay, isMissed: Bool = false) -> String {
        if day.isCompleted { return "checkmark.circle.fill" }
        if isMissed { return "exclamationmark.circle" }
        switch day.kind {
        case .training: return "chevron.right"
        case .recovery: return "figure.cooldown"
        case .rest: return "moon.fill"
        }
    }

    private func workoutSource(for plan: TrainingPlan) -> ActiveWorkoutSource {
        appData.manualPlan?.id == plan.id ? .manual : .ai
    }
    
    
    private var emptyStateSection: some View {
        VStack(spacing: 24) {
            Image(systemName: "bolt.slash.fill")
                .font(.system(size: 48))
                .foregroundColor(StitchTheme.onSurfaceVariant.opacity(0.3))
            
            VStack(spacing: 8) {
                Text("NO ACTIVE TRAINING PLAN")
                    .font(StitchTypography.dataMedium)
                    .foregroundColor(StitchTheme.onSurface)
                Text("GENERATE AI PLAN OR SELECT MANUALLY")
                    .font(StitchTypography.labelSmall)
                    .foregroundColor(StitchTheme.onSurfaceVariant)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(StitchTheme.surfaceContainerLow)
        .cornerRadius(12)
    }
    
    private func hudStat(label: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(StitchTypography.labelSmall)
                .foregroundColor(StitchTheme.onSurfaceVariant)
            Text(value)
                .font(StitchTypography.label)
                .foregroundColor(StitchTheme.onSurface)
                .tracking(1)
        }
    }
    
    private func entryButton(title: String, subtitle: String, icon: String, color: Color, textColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: icon)
                    .font(.title)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(subtitle)
                        .font(StitchTypography.labelSmall)
                        .opacity(0.8)
                    Text(title)
                        .font(StitchTypography.dataMedium)
                }
            }
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(color)
            .cornerRadius(12)
        }
    }
}
