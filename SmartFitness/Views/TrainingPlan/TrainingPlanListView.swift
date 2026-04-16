import SwiftUI

struct TrainingPlanListView: View {
    @EnvironmentObject var appData: AppData
    @State private var showingGeneratePlan = false
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
                        
                        if let plan = appData.aiSmartPlan ?? appData.manualPlan {
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
                                appData.selectedTab = 1
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
            .sheet(isPresented: $showingGeneratePlan){
                GeneratePlanView()
//                FoodCalorieView()
//                LocalLLMView()
//                MultiImageScheduleView()
//                DrinkOCRView()
//                llmBitnetView()
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
        let isManual = plan.trainingSplit == "自选训练" || plan.trainingSplit == "MANUAL"
        let nextDayIndex = plan.days.firstIndex(where: { !$0.isCompleted }) ?? 0
        let planTitle = plan.trainingSplit
        
        let progress: CGFloat
        let progressDetail: String
        
        if isManual, let firstDay = plan.days.first {
            let allSets = firstDay.exercises.flatMap { $0.exerciseSets }
            let completedCount = allSets.filter { $0.isCompleted }.count
            let totalCount = max(allSets.count, 1)
            progress = CGFloat(completedCount) / CGFloat(totalCount)
            progressDetail = "\(completedCount)/\(allSets.count) 组"
        } else {
            let completedCount = plan.days.filter { $0.isCompleted }.count
            let totalCount = max(plan.days.count, 1)
            progress = CGFloat(completedCount) / CGFloat(totalCount)
            progressDetail = "\(completedCount)/\(plan.days.count) 天"
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
                NavigationLink(destination: TrainingPlanDetailView(plan: plan, selectedDayIndex: nextDayIndex)) {
                    Image(systemName: "play.fill")
                        .font(.title2)
                        .foregroundColor(StitchTheme.onPrimaryFixed)
                        .padding(16)
                        .background(StitchTheme.primaryContainer)
                        .clipShape(Circle())
                }
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
            
            VStack(spacing: 10) {
                ForEach(Array(plan.days.enumerated()), id: \.offset) { index, day in
                    let focusTitle = currentDayFocusTitle(for: day)
                    NavigationLink(destination: TrainingPlanDetailView(plan: plan, selectedDayIndex: index)) {
                        HStack(spacing: 10) {
                            Text(day.label)
                                .font(StitchTypography.label)
                                .foregroundColor(day.isCompleted ? StitchTheme.onSurfaceVariant : StitchTheme.primaryContainer)
                                .strikethrough(day.isCompleted, color: StitchTheme.onSurfaceVariant)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(width: 72, alignment: .leading)
                            
                            Text(focusTitle)
                                .font(StitchTypography.label)
                                .foregroundColor(day.isCompleted ? StitchTheme.onSurfaceVariant : StitchTheme.onSurface)
                                .strikethrough(day.isCompleted, color: StitchTheme.onSurfaceVariant)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text("\(day.exercises.count) 项")
                                .font(StitchTypography.labelSmall)
                                .foregroundColor(StitchTheme.onSurfaceVariant)
                            
                            Image(systemName: day.isCompleted ? "checkmark.circle.fill" : "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(day.isCompleted ? StitchTheme.primaryContainer : StitchTheme.onSurfaceVariant)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(StitchTheme.surfaceContainerLow)
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(24)
        .background(StitchTheme.surfaceContainer)
        .cornerRadius(12)
    }
    
    private func currentDayFocusTitle(for day: TrainingDay) -> String {
        let muscles = day.exercises
            .flatMap { $0.localizedMuscleNames.isEmpty ? $0.primaryMuscles : $0.localizedMuscleNames }
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        let uniqueMuscles = Array(NSOrderedSet(array: muscles)) as? [String] ?? []
        if !uniqueMuscles.isEmpty {
            return uniqueMuscles.prefix(2).joined(separator: " / ")
        }
        return NSLocalizedString("全身", comment: "")
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
