import SwiftUI

struct TrainingPlanDetailView: View {
    @EnvironmentObject var appData: AppData
    let plan: TrainingPlan
    let selectedDayIndex: Int
    
    @State private var selectedExercise: Exercise? = nil
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        summarySection
                        exerciseListSection
                    }
                }
            }
        }
        .navigationTitle("训练内容")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedExercise) { exercise in
            ExerciseDetailSheet(exercise: exercise)
        }
    }
    
    @ViewBuilder
    private var summarySection: some View {
        let currentDay = plan.days[selectedDayIndex]
        VStack(spacing: 8) {
            Text("训练日 \(currentDay.label)")
                .font(Theme.Typography.title1)
                .foregroundColor(Theme.textPrimary)
            
            Text(plan.trainingSplit)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Theme.primary.opacity(0.1))
                .cornerRadius(4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }
    
    @ViewBuilder
    private var exerciseListSection: some View {
        VStack(spacing: 12) {
            // Find the plan to get a binding for modifications
            if plan.id == appData.currentPlan?.id, let planBinding = Binding($appData.currentPlan) {
                ForEach(planBinding.days[selectedDayIndex].exercises) { $exercise in
                    ExerciseCard(exercise: $exercise)
                        .onTapGesture {
                            selectedExercise = exercise
                        }
                }
            } else {
                // Fallback for preview or if plan is not in the main data source
                Text("Could not find this plan in the app's data. Edits will not be saved.")
                    .font(.caption)
                    .foregroundColor(.red)
                ForEach(plan.days[selectedDayIndex].exercises) { exercise in
                    let exerciseBinding = Binding.constant(exercise)
                    ExerciseCard(exercise: exerciseBinding)
                        .onTapGesture {
                            selectedExercise = exercise
                        }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
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
            Text("第 \(index + 1) 组")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.textSecondary)
                .frame(width: 50, alignment: .leading)
            
            // Weight Button
            Button(action: onWeightTapped) {
                Text(String(format: "%.1f", exerciseSet.weight))
                    .font(Theme.Typography.body.bold())
                    .foregroundColor(Theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Theme.background)
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            }
            
            // Reps Button
            Button(action: onRepsTapped) {
                Text("\(exerciseSet.reps)")
                    .font(Theme.Typography.body.bold())
                    .foregroundColor(Theme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Theme.background)
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            }
            
            Spacer()
            
            // Completion Toggle
            Button(action: onCompleteTapped) {
                Image(systemName: exerciseSet.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(exerciseSet.isCompleted ? Theme.primary : Theme.textSecondary)
            }
        }
    }
}

// MARK: - Exercise Card View
struct ExerciseCard: View {
    @Binding var exercise: Exercise
    @State private var isCollapsed: Bool = false
    @State private var activeSheet: ActiveSheet?
    
    // Rest Timer
    @State private var timer: Timer?
    @State private var timeRemaining: Int = 60
    @State private var isTimerRunning: Bool = false
    
    // Weight/Reps options
    private let weightOptions = Array(stride(from: 0.0, to: 300.0, by: 0.5))
    private let repsOptions = Array(1...30)
    
    enum ActiveSheet: Identifiable {
        case weight(index: Int)
        case reps(index: Int)
        
        var id: Int {
            switch self {
            case .weight(let index):
                return 1000 + index
            case .reps(let index):
                return 2000 + index
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection
            
            if isCollapsed {
                summarySection
            } else {
                editorSection
            }
        }
        .padding()
        .background(Theme.background)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .onChange(of: exercise.exerciseSets) { _ in
            checkAndCollapse()
        }
        .sheet(item: $activeSheet) { sheet in
            PickerSheetView(sheet: sheet, exercise: $exercise)
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        HStack {
            Text(exercise.exerciseName)
                .font(Theme.Typography.h3)
                .foregroundColor(Theme.textPrimary)
            
            Spacer()
            
            Text(exercise.equipment)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.background)
                .cornerRadius(8)
        }
    }
    
    @ViewBuilder
    private var editorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            setsListHeader
            setsListSection
            actionButtonsSection
            if isTimerRunning {
                timerView
            }
        }
    }
    
    @ViewBuilder
    private var setsListHeader: some View {
        HStack {
            Text("组数")
                .font(Theme.Typography.label)
                .foregroundColor(Theme.textSecondary)
                .frame(width: 50, alignment: .leading)
            
            Text("重量 (kg)")
                .font(Theme.Typography.label)
                .foregroundColor(Theme.textSecondary)
                .frame(maxWidth: .infinity)
            
            Text("次数")
                .font(Theme.Typography.label)
                .foregroundColor(Theme.textSecondary)
                .frame(maxWidth: .infinity)
            
            Spacer().frame(width: 40)
        }
        .padding(.horizontal, 8)
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
                        withAnimation {
                            exercise.exerciseSets[index].isCompleted.toggle()
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
    private var actionButtonsSection: some View {
        HStack {
            Button(action: addSet) {
                Label("添加一组", systemImage: "plus.circle")
            }
            .buttonStyle(SecondaryButtonStyle())
            
            Spacer()
            
            Button(action: removeSet) {
                Label("删除一组", systemImage: "minus.circle")
            }
            .buttonStyle(SecondaryButtonStyle(isDestructive: true))
            .disabled(exercise.exerciseSets.count <= 1)
        }
    }
    
    @ViewBuilder
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("锻炼完成！")
                .font(Theme.Typography.h3)
                .foregroundColor(Theme.primary)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("总组数")
                        .font(Theme.Typography.label)
                        .foregroundColor(Theme.textSecondary)
                    Text("\(exercise.exerciseSets.count)")
                        .font(Theme.Typography.body.bold())
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("总容量 (kg)")
                        .font(Theme.Typography.label)
                        .foregroundColor(Theme.textSecondary)
                    Text(String(format: "%.1f", exercise.totalVolume))
                        .font(Theme.Typography.body.bold())
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("平均次数")
                        .font(Theme.Typography.label)
                        .foregroundColor(Theme.textSecondary)
                    Text(String(format: "%.1f", exercise.averageReps))
                        .font(Theme.Typography.body.bold())
                }
            }
            .padding(.top, 8)
        }
    }
    
    @ViewBuilder
    private var timerView: some View {
        HStack {
            Image(systemName: "timer")
                .font(.title2)
                .foregroundColor(Theme.primary)
            
            Text(String(format: "%02d:%02d", timeRemaining / 60, timeRemaining % 60))
                .font(Theme.Typography.h3.monospacedDigit())
                .foregroundColor(Theme.textPrimary)
            
            Spacer()
            
            Button(action: {
                timer?.invalidate()
                isTimerRunning = false
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding()
        .background(Theme.background)
        .cornerRadius(12)
        .transition(.scale.animation(.spring()))
    }
    
    // MARK: - Functions
    private func checkAndCollapse() {
        let allCompleted = exercise.exerciseSets.allSatisfy { $0.isCompleted }
        if allCompleted {
            withAnimation {
                isCollapsed = true
                timer?.invalidate()
                isTimerRunning = false
            }
        }
    }
    
    private func addSet() {
        let lastSet = exercise.exerciseSets.last ?? ExerciseSet(weight: 10.0, reps: 10)
        exercise.exerciseSets.append(ExerciseSet(weight: lastSet.weight, reps: lastSet.reps))
    }
    
    private func removeSet() {
        if exercise.exerciseSets.count > 1 {
            _ = exercise.exerciseSets.popLast()
        }
    }
    
    private func startRestTimer() {
        timeRemaining = 60
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

// MARK: - Picker Sheet View (Router)
struct PickerSheetView: View {
    let sheet: ExerciseCard.ActiveSheet
    @Binding var exercise: Exercise
    
    private var weightOptions: [Double] { Array(stride(from: 0.0, to: 300.0, by: 0.5)) }
    private var repsOptions: [Int] { Array(1...30) }
    
    var body: some View {
        switch sheet {
        case .weight(let index):
            ValuePickerSheet(
                title: "选择重量 (kg)",
                selection: $exercise.exerciseSets[index].weight,
                options: weightOptions,
                format: "%.1f"
            )
        case .reps(let index):
            ValuePickerSheet(
                title: "选择次数",
                selection: Binding(
                    get: { Double(exercise.exerciseSets[index].reps) },
                    set: { exercise.exerciseSets[index].reps = Int($0) }
                ),
                options: repsOptions.map { Double($0) },
                format: "%.0f"
            )
        }
    }
}

// MARK: - Value Picker Sheet
struct ValuePickerSheet<T: Hashable>: View {
    let title: String
    @Binding var selection: T
    let options: [T]
    let format: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            Text(title)
                .font(Theme.Typography.h3)
                .padding()
            
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(String(format: format, option as! CVarArg))
                }
            }
            .pickerStyle(WheelPickerStyle())
            .labelsHidden()
            
            Button("完成") {
                dismiss()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Theme.primary)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding()
        }
        .presentationDetents([.height(300)])
    }
}


struct ExerciseCompletionSummary: View {
    let exercise: Exercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("训练完成")
                .font(Theme.Typography.title2)
                .foregroundColor(Theme.primary)
            
            HStack(spacing: 16) {
                SummaryItem(title: "总时长", value: "5:32") // Placeholder
                SummaryItem(title: "总重量", value: String(format: "%.1f kg", exercise.totalVolume))
                SummaryItem(title: "卡路里", value: "85 kcal") // Placeholder
            }
            
            Text("完成于 \(Date().formatted(.dateTime.hour().minute()))")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.vertical, 8)
    }
}

struct SummaryItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.textSecondary)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.textPrimary)
        }
    }
}

struct WeightPickerSheet: View {
    @Binding var weight: Double
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("选择重量 (kg)")
                .font(Theme.Typography.title2)
                .padding(.top, 20)
            
            Picker("重量", selection: $weight) {
                ForEach(Array(stride(from: 0.0, through: 200.0, by: 2.5)), id: \.self) { w in
                    Text(String(format: "%.1f kg", w)).tag(w)
                }
            }
            .pickerStyle(.wheel)
            
            Button("确定") {
                dismiss()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Theme.primary)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .presentationDetents([.height(350)])
        .preferredColorScheme(.dark)
    }
}

struct RepsPickerSheet: View {
    @Binding var reps: Int
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("选择次数")
                .font(Theme.Typography.title2)
                .padding(.top, 20)
            
            Picker("次数", selection: $reps) {
                ForEach(1...50, id: \.self) { r in
                    Text("\(r) 次").tag(r)
                }
            }
            .pickerStyle(.wheel)
            
            Button("确定") {
                dismiss()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Theme.primary)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .presentationDetents([.height(350)])
        .preferredColorScheme(.dark)
    }
}

struct RestTimerPopup: View {
    let timeRemaining: Int
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            
            VStack(spacing: 16) {
                Text("休息时间")
                    .font(Theme.Typography.title2)
                
                Text("\(timeRemaining)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.primary)
                
                Text("秒")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.textSecondary)
                
                Button("跳过") {
                    onDismiss()
                }
                .font(Theme.Typography.body)
                .foregroundColor(Theme.textSecondary)
            }
            .padding(32)
            .background(Theme.surface)
            .cornerRadius(20)
            .shadow(radius: 10)
        }
    }
}

struct InfoTag: View {
    let label: String
    var body: some View {
        Text(label)
            .font(Theme.Typography.caption)
            .foregroundColor(Theme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.background.opacity(0.5))
            .cornerRadius(4)
    }
}

struct ExerciseDetailSheet: View {
    let exercise: Exercise
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Spacer()
                        Capsule()
                            .fill(Color.gray)
                            .frame(width: 40, height: 4)
                        Spacer()
                    }
                    .padding(.top, 12)
                    
                    Text(exercise.exerciseName)
                        .font(Theme.Typography.title1)
                        .foregroundColor(Theme.textPrimary)
                    
                    // Mock Image View
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<2) { _ in
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Theme.surface)
                                    .frame(width: 300, height: 200)
                                    .overlay(
                                        Image(systemName: "figure.strengthtraining.traditional")
                                            .resizable()
                                            .scaledToFit()
                                            .padding(40)
                                            .foregroundColor(Theme.primary.opacity(0.5))
                                    )
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("发力部位")
                            .font(Theme.Typography.title2)
                            .foregroundColor(Theme.textPrimary)
                        Text(exercise.focusArea.isEmpty ? "全身" : exercise.focusArea)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.textSecondary)
                        
                        Text("注意事项")
                            .font(Theme.Typography.title2)
                            .foregroundColor(Theme.textPrimary)
                        Text(exercise.instructions.isEmpty ? "保持核心收紧，动作平稳。" : exercise.instructions)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.textSecondary)
                            .lineSpacing(1.5)
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

#Preview {
    NavigationView {
        TrainingPlanDetailView(plan: TrainingPlan(
            trainingSplit: "每周 3 练 (A/B/C 循环)",
            instructions: "新手入门计划",
            days: [
                TrainingDay(label: "A", exercises: [
                    Exercise(
                        order: 1,
                        exerciseName: "深蹲",
                        sets: 3,
                        reps: "10-12",
                        equipment: "杠铃",
                        difficulty: "中等",
                        instructions: "下蹲时保持背部挺直，核心收紧，膝盖不要超过脚尖。",
                        focusArea: "腿部"
                    )
                ])
            ]
        ), selectedDayIndex: 0)
        .environmentObject(AppData())
    }
}
