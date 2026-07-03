import SwiftUI

struct ManualWeeklyPlanBuilderView: View {
    @EnvironmentObject var appData: AppData
    @Environment(\.dismiss) private var dismiss

    @State private var days: [ManualWeeklyDayDraft] = ManualWeeklyDayDraft.defaultWeek

    private let focusOptions = ["胸", "背", "腿", "肩", "手臂", "腹部", "全身"]

    var body: some View {
        NavigationView {
            ZStack {
                StitchTheme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection
                        weeklySummarySection
                        weekEditor
                        createButton
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(StitchTheme.onSurfaceVariant)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(StitchTheme.background.opacity(0.8), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            loadExistingManualWeeklyPlan()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MANUAL WEEK")
                .font(StitchTypography.label)
                .tracking(4)
                .foregroundColor(StitchTheme.onSurfaceVariant)

            Text("手动安排一周训练")
                .font(StitchTypography.headlineLarge)
                .italic()
                .foregroundColor(StitchTheme.onSurface)

            Text("先把每一天设为训练、休息或恢复。创建后可以从 Today 页选中某一天，再添加具体动作。")
                .font(StitchTypography.body)
                .foregroundColor(StitchTheme.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var weeklySummarySection: some View {
        let trainingCount = days.filter { $0.kind == .training }.count
        let recoveryCount = days.filter { $0.kind == .recovery }.count
        let restCount = days.filter { $0.kind == .rest }.count
        let exerciseCount = appData.manualWeeklyPlan?.days.reduce(0) { $0 + $1.exercises.count } ?? 0

        return HStack(spacing: 10) {
            summaryPill(title: "训练", value: "\(trainingCount) 天")
            summaryPill(title: "恢复", value: "\(recoveryCount) 天")
            summaryPill(title: "休息", value: "\(restCount) 天")
            summaryPill(title: "动作", value: "\(exerciseCount)")
        }
    }

    private func summaryPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(StitchTypography.labelSmall)
                .foregroundColor(StitchTheme.onSurfaceVariant)
            Text(value)
                .font(StitchTypography.label)
                .foregroundColor(StitchTheme.primaryContainer)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(StitchTheme.surfaceContainerLow)
        .cornerRadius(12)
    }

    private var weekEditor: some View {
        VStack(spacing: 14) {
            ForEach(days.indices, id: \.self) { index in
                dayEditor(day: $days[index], index: index)
            }
        }
    }

    private func dayEditor(day: Binding<ManualWeeklyDayDraft>, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(day.wrappedValue.weekday)
                        .font(StitchTypography.label)
                        .foregroundColor(StitchTheme.primaryContainer)
                        .tracking(2)

                    Text(daySubtitle(for: day.wrappedValue))
                        .font(StitchTypography.labelSmall)
                        .foregroundColor(StitchTheme.onSurfaceVariant)
                }

                Spacer()

                Picker("", selection: day.kind) {
                    Text("训练").tag(TrainingDayKind.training)
                    Text("恢复").tag(TrainingDayKind.recovery)
                    Text("休息").tag(TrainingDayKind.rest)
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
            }

            if day.wrappedValue.kind == .training {
                existingExercisePreview(for: index)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(focusOptions, id: \.self) { focus in
                            Button {
                                day.wrappedValue.focus = focus
                            } label: {
                                Text(focus)
                                    .font(StitchTypography.labelSmall)
                                    .foregroundColor(day.wrappedValue.focus == focus ? StitchTheme.onPrimaryFixed : StitchTheme.primaryContainer)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(day.wrappedValue.focus == focus ? StitchTheme.primaryContainer : StitchTheme.primaryContainer.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }

                Button {
                    saveManualWeeklyPlan()
                    appData.libraryInsertionTarget = LibraryInsertionTarget(planType: .manual, dayIndex: index)
                    appData.selectedTab = 2
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(exerciseActionTitle(for: index))
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(StitchTypography.labelSmall)
                    .foregroundColor(StitchTheme.primaryContainer)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(StitchTheme.primaryContainer.opacity(0.1))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)

                if !(appData.manualWeeklyPlan?.days[safe: index]?.exercises.isEmpty ?? true) {
                    Button {
                        clearExercises(fromDayAt: index)
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("清空这一天动作")
                            Spacer()
                        }
                        .font(StitchTypography.labelSmall)
                        .foregroundColor(StitchTheme.onSurfaceVariant)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(StitchTheme.surfaceContainerHigh.opacity(0.55))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(StitchTheme.surfaceContainerLow)
        .cornerRadius(14)
    }

    @ViewBuilder
    private func existingExercisePreview(for index: Int) -> some View {
        let exercises = appData.manualWeeklyPlan?.days[safe: index]?.exercises ?? []

        if exercises.isEmpty {
            Text("还没有添加动作")
                .font(StitchTypography.labelSmall)
                .foregroundColor(StitchTheme.onSurfaceVariant)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(StitchTheme.surfaceContainerHigh.opacity(0.45))
                .cornerRadius(10)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(exercises.prefix(3)) { exercise in
                    HStack(spacing: 8) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 5))
                            .foregroundColor(StitchTheme.primaryContainer)

                        Text(exercise.exerciseName)
                            .font(StitchTypography.labelSmall)
                            .foregroundColor(StitchTheme.onSurface)
                            .lineLimit(1)

                        Spacer()

                        Text("\(exercise.exerciseSets.count) 组")
                            .font(StitchTypography.labelSmall)
                            .foregroundColor(StitchTheme.onSurfaceVariant)

                        Button {
                            removeExercise(exercise, fromDayAt: index)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(StitchTheme.onSurfaceVariant)
                                .padding(6)
                                .background(StitchTheme.surfaceContainerLow)
                                .clipShape(Circle())
                        }
                    }
                    .buttonStyle(.plain)
                }

                if exercises.count > 3 {
                    Text("+\(exercises.count - 3) 个动作")
                        .font(StitchTypography.labelSmall)
                        .foregroundColor(StitchTheme.onSurfaceVariant)
                }
            }
            .padding(12)
            .background(StitchTheme.surfaceContainerHigh.opacity(0.45))
            .cornerRadius(10)
        }
    }

    private func removeExercise(_ exercise: Exercise, fromDayAt index: Int) {
        guard var plan = appData.manualWeeklyPlan,
              plan.days.indices.contains(index) else {
            return
        }

        plan.days[index].exercises.removeAll { $0.id == exercise.id }
        appData.manualPlan = plan
    }

    private func clearExercises(fromDayAt index: Int) {
        guard var plan = appData.manualWeeklyPlan,
              plan.days.indices.contains(index) else {
            return
        }

        plan.days[index].exercises.removeAll()
        appData.manualPlan = plan
    }

    private var createButton: some View {
        Button {
            saveManualWeeklyPlan()
            appData.selectedTab = 1
            dismiss()
        } label: {
            HStack {
                Image(systemName: "calendar.badge.plus")
                Text(appData.manualWeeklyPlan == nil ? "创建手动周计划" : "保存周计划")
            }
            .font(StitchTypography.label)
            .foregroundColor(StitchTheme.onPrimaryFixed)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(StitchTheme.primaryContainer)
            .cornerRadius(12)
        }
    }

    private func daySubtitle(for day: ManualWeeklyDayDraft) -> String {
        switch day.kind {
        case .training:
            return "\(day.focus)训练"
        case .recovery:
            return "主动恢复 / 拉伸"
        case .rest:
            return "完全休息"
        }
    }

    private func exerciseActionTitle(for index: Int) -> String {
        let count = appData.manualWeeklyPlan?.days[safe: index]?.exercises.count ?? 0
        return count == 0 ? "添加动作" : "管理动作（\(count)）"
    }

    private func saveManualWeeklyPlan() {
        let existingDays = appData.manualWeeklyPlan?.days ?? []

        let trainingDays = days.enumerated().map { index, draft in
            let existingExercises = existingDays.indices.contains(index) ? existingDays[index].exercises : []
            return TrainingDay(
                label: draft.displayLabel,
                exercises: draft.kind == .training ? existingExercises : [],
                kind: draft.kind,
                weekday: draft.weekdayIndex,
                focus: draft.kind == .training ? draft.focus : nil
            )
        }

        appData.manualPlan = TrainingPlan(
            trainingSplit: "手动周计划",
            instructions: "手动创建的一周训练安排",
            days: trainingDays
        )
    }

    private func loadExistingManualWeeklyPlan() {
        guard let plan = appData.manualWeeklyPlan, plan.days.count >= 7 else { return }

        days = plan.days.prefix(7).enumerated().map { index, day in
            ManualWeeklyDayDraft(
                weekdayIndex: day.weekday ?? index + 2,
                weekday: ManualWeeklyDayDraft.weekdayName(for: day.weekday ?? index + 2),
                kind: day.kind,
                focus: day.focus ?? inferredFocus(from: day)
            )
        }
    }

    private func inferredFocus(from day: TrainingDay) -> String {
        if let focus = day.label.components(separatedBy: "·").last?.trimmingCharacters(in: .whitespacesAndNewlines),
           !focus.isEmpty,
           focus != "休息",
           focus != "恢复" {
            return focus
        }
        return "全身"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private struct ManualWeeklyDayDraft: Identifiable {
    let id = UUID()
    let weekdayIndex: Int
    let weekday: String
    var kind: TrainingDayKind
    var focus: String

    var displayLabel: String {
        switch kind {
        case .training:
            return "\(weekday) · \(focus)"
        case .recovery:
            return "\(weekday) · 恢复"
        case .rest:
            return "\(weekday) · 休息"
        }
    }

    static let defaultWeek: [ManualWeeklyDayDraft] = [
        ManualWeeklyDayDraft(weekdayIndex: 2, weekday: "周一", kind: .training, focus: "胸"),
        ManualWeeklyDayDraft(weekdayIndex: 3, weekday: "周二", kind: .training, focus: "背"),
        ManualWeeklyDayDraft(weekdayIndex: 4, weekday: "周三", kind: .training, focus: "腿"),
        ManualWeeklyDayDraft(weekdayIndex: 5, weekday: "周四", kind: .rest, focus: "全身"),
        ManualWeeklyDayDraft(weekdayIndex: 6, weekday: "周五", kind: .training, focus: "肩"),
        ManualWeeklyDayDraft(weekdayIndex: 7, weekday: "周六", kind: .training, focus: "手臂"),
        ManualWeeklyDayDraft(weekdayIndex: 1, weekday: "周日", kind: .rest, focus: "全身"),
    ]

    static func weekdayName(for weekdayIndex: Int) -> String {
        let names = [1: "周日", 2: "周一", 3: "周二", 4: "周三", 5: "周四", 6: "周五", 7: "周六"]
        return names[weekdayIndex] ?? "周一"
    }
}
