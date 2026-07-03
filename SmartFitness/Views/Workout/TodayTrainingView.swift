import SwiftUI

// 真正的今日训练视图
struct TodayTrainingView: View {
    @EnvironmentObject var appData: AppData
    @State private var showingClearConfirmation = false
    @State private var exercisePendingDeletion: Exercise?

    private var activePlan: TrainingPlan? {
        appData.aiSmartPlan ?? appData.manualPlanForToday
    }

    private var todayDayIndex: Int {
        guard let plan = activePlan else { return 0 }
        if isManualPlan(plan) { return 0 }
        return plan.days.firstIndex(where: { !$0.isCompleted }) ?? 0
    }

    private var todayDay: TrainingDay? {
        guard let plan = activePlan, !plan.days.isEmpty else { return nil }
        return plan.days[min(todayDayIndex, plan.days.count - 1)]
    }

    var body: some View {
        ZStack {
            StitchTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection

                    if let plan = activePlan, let day = todayDay {
                        todayPlanCard(plan: plan, day: day, dayIndex: todayDayIndex)
                        exercisePreviewList(day: day)
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
        .alert("清空今日训练？", isPresented: $showingClearConfirmation) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                appData.clearTodayTraining()
            }
        } message: {
            Text("这会移除当前今日训练列表里的动作。")
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

        return VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(isManualPlan(plan) ? "CUSTOM SESSION" : plan.trainingSplit.uppercased())
                        .font(StitchTypography.labelSmall)
                        .foregroundColor(StitchTheme.onSurfaceVariant)
                        .tracking(2)

                    Text(focusTitle(for: day))
                        .font(StitchTypography.headline)
                        .foregroundColor(StitchTheme.primaryContainer)
                        .lineLimit(2)
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

            NavigationLink {
                ActiveWorkoutView(source: isManualPlan(plan) ? .manual : .ai, dayIndex: dayIndex)
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

            HStack(spacing: 12) {
                Button {
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
                    Text("清空今日")
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

    private func exercisePreviewList(day: TrainingDay) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TODAY'S EXERCISES")
                .font(StitchTypography.label)
                .foregroundColor(StitchTheme.onSurfaceVariant)
                .tracking(2)

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

    private func isManualPlan(_ plan: TrainingPlan) -> Bool {
        plan.trainingSplit == "MANUAL" || plan.trainingSplit == "自选训练"
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
        let muscles = day.exercises
            .flatMap { $0.localizedMuscleNames.isEmpty ? $0.primaryMuscles : $0.localizedMuscleNames }
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let uniqueMuscles = Array(NSOrderedSet(array: muscles)) as? [String] ?? []
        if !uniqueMuscles.isEmpty {
            return uniqueMuscles.prefix(2).joined(separator: " / ")
        }
        return NSLocalizedString("全身训练", comment: "")
    }
}
