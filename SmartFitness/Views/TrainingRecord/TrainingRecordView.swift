import SwiftUI

struct TrainingRecordView: View {
    @EnvironmentObject var appData: AppData
    @State private var selectedDate = Date()
    
    // Helper to get month name
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "en_US")
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
                            detailsSection
                            
                            // Today's specific summary if selected date is today
                            if Calendar.current.isDateInToday(selectedDate) {
                                todaySummarySection
                            }
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
            LazyVGrid(columns: columns, spacing: 12) {
                // Mock generating days for the current view month
                // For simplicity in UI implementation, we'll keep the 31 iteration but use real date logic for dots
                ForEach(1...31, id: \.self) { day in
                    let isToday = day == Calendar.current.component(.day, from: Date()) && Calendar.current.isDate(selectedDate, equalTo: Date(), toGranularity: .month)
                    let isSelected = day == Calendar.current.component(.day, from: selectedDate)
                    let record = appData.records.first(where: { Calendar.current.component(.day, from: $0.date) == day })
                    
                    Button(action: {
                        if let newDate = Calendar.current.date(bySetting: .day, value: day, of: selectedDate) {
                            withAnimation(.easeInOut) {
                                selectedDate = newDate
                            }
                        }
                    }) {
                        VStack(spacing: 6) {
                            Text("\(day)")
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
                        Text(record.isCompleted ? "COMPLETED: \(record.focusArea)" : "INCOMPLETE: \(record.focusArea)")
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
        VStack(alignment: .leading, spacing: 16) {
            Text("TODAY'S SUMMARY")
                .font(StitchTypography.label)
                .tracking(2.0)
                .foregroundColor(StitchTheme.onSurfaceVariant)
                .padding(.horizontal, 24)
            
            VStack(alignment: .leading, spacing: 12) {
                if !appData.manualPlan.isEmpty {
                    SummaryRow(title: "CURRENT ARRANGEMENT", value: "\(appData.manualPlan.count) EXERCISES")
                    SummaryRow(title: "SOURCE", value: "MANUAL SELECTION")
                } else if let plan = appData.aiSmartPlan {
                    SummaryRow(title: "CURRENT ARRANGEMENT", value: "AI SMART PLAN")
                    SummaryRow(title: "SPLIT", value: plan.trainingSplit)
                } else {
                    Text("NO ACTIVE TRAINING PLAN FOR TODAY")
                        .font(StitchTypography.body)
                        .foregroundColor(StitchTheme.outline)
                        .italic()
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(StitchTheme.surfaceContainerLow)
            .cornerRadius(12)
            .padding(.horizontal, 24)
        }
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
