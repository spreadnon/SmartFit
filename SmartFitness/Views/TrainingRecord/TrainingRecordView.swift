import SwiftUI

struct TrainingRecordView: View {
    @EnvironmentObject var appData: AppData
    @State private var selectedDate = Date()
    
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
    }
    
    @ViewBuilder
    private var headerSection: some View {
        HStack(alignment: .bottom) {
            Text("HISTORY")
                .font(StitchTypography.headlineLarge)
                .italic()
                .foregroundColor(StitchTheme.primaryContainer)
//            
//            Text("& RECORDS")
//                .font(StitchTypography.headline)
//                .italic()
//                .foregroundColor(StitchTheme.onSurfaceVariant)
            
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
                            
                            // Indicator DOT
                            if let rec = record {
                                Circle()
                                    .fill(rec.isCompleted ? (isSelected ? StitchTheme.background : StitchTheme.primaryContainer) : StitchTheme.secondary)
                                    .frame(width: 4, height: 4)
                            } else {
                                Circle()
                                    .fill(Color.clear)
                                    .frame(width: 4, height: 4)
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
        
        VStack(alignment: .leading, spacing: 16) {
            Text(isToday ? "TODAY SUMMARY" : "DAILY SUMMARY")
                .font(StitchTypography.label)
                .tracking(2.0)
                .foregroundColor(StitchTheme.onSurfaceVariant)
                .padding(.horizontal, 24)
            
            VStack(alignment: .leading, spacing: 12) {
                if let record = record {
                    // Pre-recorded focus area is already localized or should be
                    summaryRows(exercises: record.exercises, source: record.focusArea, duration: record.duration)
                } else if isToday {
                    // 如果是今天且没有记录，才显示活跃计划
                    if let manualPlan = appData.manualPlan, let exercises = manualPlan.days.first?.exercises {
                        summaryRows(exercises: exercises, source: NSLocalizedString("MANUAL PLAN", comment: ""))
                    } else if let plan = appData.aiSmartPlan, let exercises = plan.days.first?.exercises {
                        summaryRows(exercises: exercises, source: NSLocalizedString("AI SMART PLAN", comment: ""), extra: plan.trainingSplit)
                    } else {
                        noDataText("NO ACTIVE TRAINING PLAN")
                    }
                } else {
                    noDataText("NO RECORD FOR THIS DAY")
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(StitchTheme.surfaceContainerLow)
            .cornerRadius(12)
            .padding(.horizontal, 24)
        }
    }
    
    @ViewBuilder
    private func summaryRows(exercises: [Exercise], source: String, extra: String? = nil, duration: TimeInterval? = nil) -> some View {
        SummaryRow(title: "EXERCISE PLAN", value: "\(exercises.count) EXERCISES")
        SummaryRow(title: "PLAN SOURCE", value: source)
        if let extra = extra {
            SummaryRow(title: "FOCUS AREA", value: extra)
        }
        
        let totalWeight = exercises.reduce(0.0) { $0 + $1.totalVolume }
        let totalSets = exercises.reduce(0) { $0 + $1.exerciseSets.count }
        
        SummaryRow(title: "TOTAL VOLUME", value: String(format: "%.1f KG", totalWeight))
        SummaryRow(title: "TOTAL SETS", value: String(format: NSLocalizedString(" %lld SETS", comment: ""), totalSets))
        
        let allMuscles = Array(Set(exercises.flatMap { $0.localizedMuscleNames })).joined(separator: ", ")
        if !allMuscles.isEmpty {
            SummaryRow(title: "TRAINED MUSCLES", value: allMuscles)
        }
        
        if let duration = duration, duration > 0 {
            SummaryRow(title: "ACTUAL DURATION", value: formatDuration(duration))
        } else {
            SummaryRow(title: "ESTIMATED TIME", value: "45 MIN")
        }
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
    
    @ViewBuilder
    private func noDataText(_ text: String) -> some View {
        Text(text)
            .font(StitchTypography.body)
            .foregroundColor(StitchTheme.outline)
            .italic()
    }
}

struct SummaryRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(StitchTypography.labelSmall)
                .foregroundColor(StitchTheme.onSurfaceVariant)
            Spacer()
            Text(value)
                .font(StitchTypography.label)
                .foregroundColor(StitchTheme.primaryContainer)
        }
    }
}

#Preview {
    TrainingRecordView()
}
