import SwiftUI

struct TrainingRecordView: View {
    @EnvironmentObject var appData: AppData
    @State private var selectedDate = Date()
    @State private var isFetchingRemote = false
    
    // Helper to get month name
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale.current
        return formatter.string(from: selectedDate).uppercased()
    }
    
    var body: some View {
        ZStack {
            StitchTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerSection
                    .padding(.bottom, 24)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        calendarSection
                        
                        VStack(spacing: 24) {
//                            detailsSection
                            
                            // Summary for selected date
                            todaySummarySection
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: selectedDate) { newDate in
            fetchRemoteRecordIfNeeded(for: newDate)
        }
        .onAppear {
            fetchRemoteRecordIfNeeded(for: selectedDate)
        }
    }
    
    private func fetchRemoteRecordIfNeeded(for date: Date) {
        // Only fetch if local record is missing
//        let localRecord = appData.records.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) })
//        print(localRecord)
//        if localRecord == nil {
            isFetchingRemote = true
            NetworkManager.shared.getTraining(date: date, token: appData.currentUser?.token) { result in
                isFetchingRemote = false
                switch result {
                case .success(let record):
                    if let record = record {
                        appData.updateRecord(record)
                    }
                case .failure(let error):
                    print("❌ 远程记录获取失败: \(error.localizedDescription)")
                    //在这里处理默认状态，停止loading并显示没有数据
                }
            }
//        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        HStack(alignment: .bottom) {
            Text("HISTORY")
                .font(StitchTypography.headlineLarge)
                .italic()
                .foregroundColor(StitchTheme.primaryContainer)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
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
    private var calendarSection: some View {
        VStack(spacing: 16) {
            // Month Header
            HStack {
                Text(monthYearString)
                    .font(StitchTypography.dataMedium)
                    .foregroundColor(StitchTheme.onSurface)
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button(action: {
                        selectedDate = Calendar.current.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(StitchTheme.primaryContainer)
                            .padding(8)
                            .background(StitchTheme.surfaceContainerHigh)
                            .clipShape(Circle())
                    }
                    
                    Button(action: {
                        selectedDate = Calendar.current.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(StitchTheme.primaryContainer)
                            .padding(8)
                            .background(StitchTheme.surfaceContainerHigh)
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            
            // Days of Week Header
            let days = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
            HStack {
                ForEach(days, id: \.self) { day in
                    Text(day)
                        .font(StitchTypography.label)
                        .tracking(2.0)
                        .foregroundColor(StitchTheme.onSurfaceVariant)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 8)
            
            // Calendar Grid
            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
            let daysInMonth = getDaysInMonth(for: selectedDate)
            
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(daysInMonth, id: \.self) { date in
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                    let isToday = Calendar.current.isDateInToday(date)
                    let dayNum = Calendar.current.component(.day, from: date)
                    
                    let record = appData.records.first(where: { rec in
                        Calendar.current.isDate(rec.date, inSameDayAs: date)
                    })
                    
                    Button(action: {
                        withAnimation(.easeInOut) {
                            selectedDate = date
                        }
                    }) {
                        VStack(spacing: 6) {
                            Text("\(dayNum)")
                                .font(StitchTypography.bodyBold)
                                .foregroundColor(isSelected ? StitchTheme.background : (isToday ? StitchTheme.primaryContainer : StitchTheme.onSurface))
                            
                            // Focus indicator text
                            if let rec = record {
                                Text(calendarFocusTag(for: rec))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(isSelected ? StitchTheme.background.opacity(0.9) : StitchTheme.primaryContainer)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Color.clear
                                    .frame(height: 10)
                            }
                        }
                        .frame(height: 50)
                        .frame(maxWidth: .infinity)
                        .background(isSelected ? StitchTheme.primaryContainer : StitchTheme.surfaceContainerLow)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isToday && !isSelected ? StitchTheme.primaryContainer : Color.clear, lineWidth: 1)
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(StitchTheme.surfaceContainer)
        .cornerRadius(12)
        .padding(.horizontal, 24)
    }
    
    private func getDaysInMonth(for date: Date) -> [Date] {
        guard let range = Calendar.current.range(of: .day, in: .month, for: date),
              let startOfMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date))
        else { return [] }
        
        return range.compactMap { day in
            Calendar.current.date(byAdding: .day, value: day - 1, to: startOfMonth)
        }
    }
    
    private func calendarFocusTag(for record: TrainingRecord) -> String {
        let muscles = Array(Set(record.exercises.flatMap { $0.localizedMuscleNames }))
        let area = record.focusArea.lowercased()
        
        // 优先检查肌肉名称
        if let first = muscles.first?.lowercased(), !first.isEmpty {
            if first.contains("胸") || first.contains("chest") { return "胸" }
            if first.contains("背") || first.contains("back") || first.contains("lats") { return "背" }
            if first.contains("肩") || first.contains("shoulder") { return "肩" }
            if first.contains("腿") || first.contains("leg") || first.contains("quad") || first.contains("ham") || first.contains("calf") { return "腿" }
            if first.contains("臂") || first.contains("arm") || first.contains("bicep") || first.contains("tricep") { return "臂" }
            if first.contains("腹") || first.contains("core") || first.contains("ab") { return "腹" }
            if first.contains("臀") || first.contains("glute") { return "臀" }
            return String(first.prefix(1)).uppercased()
        }
        
        // 备选检查总体部位
        if !area.isEmpty {
            if area.contains("胸") || area.contains("chest") { return "胸" }
            if area.contains("背") || area.contains("back") || area.contains("lats") { return "背" }
            if area.contains("肩") || area.contains("shoulder") { return "肩" }
            if area.contains("腿") || area.contains("leg") { return "腿" }
            if area.contains("臂") || area.contains("arm") { return "臂" }
            if area.contains("腹") || area.contains("core") || area.contains("ab") { return "腹" }
            if area.contains("臀") || area.contains("glute") { return "臀" }
            return String(area.prefix(1)).uppercased()
        }
        return "练"
    }
    
    @ViewBuilder
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SESSION LOG")
                .font(StitchTypography.label)
                .tracking(2.0)
                .foregroundColor(StitchTheme.onSurfaceVariant)
                .padding(.horizontal, 24)
            
            if let record = appData.records.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }) {
                // Completed session card
                HStack(spacing: 16) {
                    Rectangle()
                        .fill(record.isCompleted ? StitchTheme.primaryContainer : StitchTheme.secondary)
                        .frame(width: 4)
                        .cornerRadius(2)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(record.isCompleted ? "\(NSLocalizedString("COMPLETED: ", comment: ""))\(record.focusArea)" : "\(NSLocalizedString("INCOMPLETE: ", comment: ""))\(record.focusArea)")
                            .font(StitchTypography.dataMedium)
                            .italic()
                            .foregroundColor(StitchTheme.onSurface)
                        
                        Text("RECORDED SESSION")
                            .font(StitchTypography.label)
                            .tracking(1.5)
                            .foregroundColor(StitchTheme.onSurfaceVariant)
                    }
                    
                    Spacer()
                }
                .padding(20)
                .background(StitchTheme.surfaceContainerHigh)
                .cornerRadius(12)
                .padding(.horizontal, 24)
            } else {
                Text("NO RECORD FOR THIS DAY")
                    .font(StitchTypography.label)
                    .foregroundColor(StitchTheme.outline)
                    .padding(.horizontal, 32)
            }
        }
    }
    
    @ViewBuilder
    private var todaySummarySection: some View {
        summaryContentForDate(selectedDate)
    }
    
    @ViewBuilder
    private func summaryContentForDate(_ date: Date) -> some View {
        let isToday = Calendar.current.isDateInToday(date)
        let record = appData.records.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) })
        
        VStack(alignment: .leading, spacing: 20) {
            Text(isToday ? "TODAY OVERVIEW" : "SESSION OVERVIEW")
                .font(StitchTypography.label)
                .tracking(2.0)
                .foregroundColor(StitchTheme.onSurfaceVariant)
                .padding(.horizontal, 24)
            
            if isFetchingRemote {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(StitchTheme.primaryContainer)
                    Text("FETCHING RECORDS...")
                        .font(StitchTypography.labelSmall)
                        .foregroundColor(StitchTheme.onSurfaceVariant)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if let record = record {
                // Tier 1: Summary Card
                WorkoutSummaryCard(record: record)
                    .padding(.horizontal, 24)
                
                // Tier 2: Exercise List
                VStack(spacing: 16) {
                    Text("EXERCISES (\(record.exercises.count))")
                        .font(StitchTypography.labelSmall)
                        .tracking(1.5)
                        .foregroundColor(StitchTheme.onSurfaceVariant)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                    
                    ForEach(record.exercises) { exercise in
                        ExerciseRecordCard(exercise: exercise)
                    }
                }
                .padding(.top, 8)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 40))
                        .foregroundColor(StitchTheme.outline.opacity(0.3))
                    
                    Text("NO RECORD FOUND")
                        .font(StitchTypography.label)
                        .foregroundColor(StitchTheme.outline)
                    
                    if isToday {
                        Text("Active plans will appear here once started.")
                            .font(.system(size: 12))
                            .foregroundColor(StitchTheme.onSurfaceVariant)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
                .background(StitchTheme.surfaceContainerLow)
                .cornerRadius(12)
                .padding(.horizontal, 24)
            }
        }
    }
}

// MARK: - Workout Summary Card
struct WorkoutSummaryCard: View {
    let record: TrainingRecord
    
    var totalVolume: Double {
        record.exercises.reduce(0) { $0 + $1.totalVolume }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Main Stats
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOTAL VOLUME")
                        .font(StitchTypography.labelSmall)
                        .foregroundColor(StitchTheme.onPrimaryFixed.opacity(0.7))
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", totalVolume / 1000.0))
                            .font(StitchTypography.headlineLarge)
                            .italic()
                        Text("TONS")
                            .font(StitchTypography.label)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("DURATION")
                        .font(StitchTypography.labelSmall)
                        .foregroundColor(StitchTheme.onPrimaryFixed.opacity(0.7))
                    Text(formatDuration(record.duration))
                        .font(StitchTypography.headline)
                        .italic()
                }
            }
            
            Divider()
                .background(StitchTheme.onPrimaryFixed.opacity(0.2))
            
            // Focus Area
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOP FOCUS")
                        .font(StitchTypography.labelSmall)
                        .foregroundColor(StitchTheme.onPrimaryFixed.opacity(0.7))
                    Text(record.focusArea.uppercased())
                        .font(StitchTypography.dataMedium)
                        .italic()
                }
                Spacer()
                Image(systemName: "flame.fill")
                    .foregroundColor(StitchTheme.secondary)
                    .font(.title2)
            }
        }
        .padding(24)
        .background(
            ZStack {
                StitchTheme.primaryContainer
                LinearGradient(
                    colors: [Color.black.opacity(0.2), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .foregroundColor(StitchTheme.onPrimaryFixed)
        .cornerRadius(16)
        .shadow(color: StitchTheme.primaryContainer.opacity(0.3), radius: 15, x: 0, y: 8)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct ExerciseRecordCard: View {
    let exercise: Exercise
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.spring()) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 16) {
                    // Muscle Group Indicator
                    ZStack {
                        Circle()
                            .fill(StitchTheme.surfaceContainerHigh)
                            .frame(width: 44, height: 44)
                        Image(systemName: muscleIcon(for: exercise.focusArea))
                            .foregroundColor(StitchTheme.primaryContainer)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.exerciseName.uppercased())
                            .font(StitchTypography.bodyBold)
                            .italic()
                            .foregroundColor(StitchTheme.onSurface)
                        Text(exercise.focusArea.uppercased())
                            .font(StitchTypography.labelSmall)
                            .tracking(1.0)
                            .foregroundColor(StitchTheme.onSurfaceVariant)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Text("\(exercise.sets)")
                                .font(StitchTypography.bodyBold)
                            Text("SETS")
                                .font(StitchTypography.labelSmall)
                        }
                        .foregroundColor(StitchTheme.onSurface)
                        
                        if exercise.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 14))
                        }
                    }
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(StitchTheme.outline)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(20)
                .background(StitchTheme.surfaceContainerLow)
            }
            
            if isExpanded {
                VStack(spacing: 12) {
                    // Set Breakdown Header
                    HStack {
                        Text("SET")
                        Spacer()
                        Text("LOAD")
                        Spacer()
                        Text("REPS")
                        Spacer()
                        Text("STATUS")
                    }
                    .font(StitchTypography.labelSmall)
                    .foregroundColor(StitchTheme.onSurfaceVariant.opacity(0.6))
                    .padding(.horizontal, 24)
                    
                    Divider()
                        .padding(.horizontal, 20)
                    
                    // Simple Trend Chart
                    WeightTrendChart(sets: exercise.exerciseSets)
                        .frame(height: 40)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                    
                    ForEach(Array(exercise.exerciseSets.enumerated()), id: \.offset) { index, set in
                        HStack {
                            Text("\(index + 1)")
                                .font(StitchTypography.dataMedium)
                                .frame(width: 30, alignment: .leading)
                            Spacer()
                            Text("\(Int(set.weight))kg")
                                .font(StitchTypography.dataMedium)
                                .foregroundColor(StitchTheme.primaryContainer)
                            Spacer()
                            Text("\(set.reps)")
                                .font(StitchTypography.dataMedium)
                            Spacer()
                            Image(systemName: set.isCompleted ? "checkmark" : "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(set.isCompleted ? .green : .red)
                                .frame(width: 40, alignment: .trailing)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 4)
                    }
                    
                    // Mini Metric
                    HStack {
                        HStack(spacing: 4) {
                            Text("MAX")
                                .font(StitchTypography.labelSmall)
                                .foregroundColor(StitchTheme.onSurfaceVariant)
                            Text("\(Int(exercise.exerciseSets.map { $0.weight }.max() ?? 0))kg")
                                .font(StitchTypography.bodyBold)
                                .foregroundColor(StitchTheme.secondary)
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            Text("VOL")
                                .font(StitchTypography.labelSmall)
                                .foregroundColor(StitchTheme.onSurfaceVariant)
                            Text("\(Int(exercise.totalVolume))kg")
                                .font(StitchTypography.bodyBold)
                                .foregroundColor(StitchTheme.secondary)
                        }
                    }
                    .padding(16)
                    .background(StitchTheme.surfaceContainer)
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .background(StitchTheme.surfaceContainerLow)
            }
        }
        .cornerRadius(12)
        .padding(.horizontal, 24)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(StitchTheme.outlineVariant.opacity(0.2), lineWidth: 1)
                .padding(.horizontal, 24)
        )
    }
    
    private func muscleIcon(for area: String) -> String {
        let area = area.lowercased()
        if area.contains("chest") || area.contains("胸") { return "figure.strengthtraining.traditional" }
        if area.contains("back") || area.contains("背") { return "figure.handball" }
        if area.contains("leg") || area.contains("腿") { return "figure.run" }
        if area.contains("shoulder") || area.contains("肩") { return "figure.arms.open" }
        if area.contains("arm") || area.contains("臂") { return "figure.strengthtraining.functional" }
        return "figure.walk"
    }
}

struct WeightTrendChart: View {
    let sets: [ExerciseSet]
    
    var body: some View {
        GeometryReader { geometry in
            if sets.count > 1 {
                let weights = sets.map { $0.weight }
                let maxWeight = weights.max() ?? 1
                let minWeight = weights.min() ?? 0
                let diff = maxWeight - minWeight
                let range = max(diff, 10.0) // At least 10kg range for visual scale
                
                Path { path in
                    for (index, set) in sets.enumerated() {
                        let x = CGFloat(index) / CGFloat(sets.count - 1) * geometry.size.width
                        let y = geometry.size.height - (CGFloat(set.weight - minWeight) / CGFloat(range) * geometry.size.height)
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [StitchTheme.primaryContainer, StitchTheme.secondary],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
            } else {
                HStack {
                    Spacer()
                    Text("NO TREND DATA")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(StitchTheme.outline.opacity(0.5))
                    Spacer()
                }
            }
        }
    }
}

#Preview {
    TrainingRecordView()
}
