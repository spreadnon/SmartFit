import SwiftUI

struct TrainingRecordView: View {
    @State private var selectedDate = Date()
    
    // Mock records
    let records: [TrainingRecord] = [
        TrainingRecord(date: Date(), focusArea: "腿部", isCompleted: true),
        TrainingRecord(date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, focusArea: "胸部", isCompleted: true),
        TrainingRecord(date: Calendar.current.date(byAdding: .day, value: -3, to: Date())!, focusArea: "背部", isCompleted: false)
    ]
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                HStack {
                    Text("训练记录")
                        .font(Theme.Typography.title1)
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Calendar UI
                VStack(spacing: 16) {
                    HStack {
                        Text(selectedDate.formatted(.dateTime.year().month()))
                            .font(Theme.Typography.title2)
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                        HStack(spacing: 20) {
                            Button(action: {}) { Image(systemName: "chevron.left") }
                            Button(action: {}) { Image(systemName: "chevron.right") }
                        }
                        .foregroundColor(Theme.textPrimary)
                    }
                    .padding(.horizontal, 8)
                    
                    let days = ["一", "二", "三", "四", "五", "六", "日"]
                    HStack {
                        ForEach(days, id: \.self) { day in
                            Text(day)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.textSecondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    
                    let columns = Array(repeating: GridItem(.flexible()), count: 7)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(1...31, id: \.self) { day in
                            VStack(spacing: 4) {
                                Text("\(day)")
                                    .font(Theme.Typography.body)
                                    .foregroundColor(day == 19 ? Theme.primary : Theme.textPrimary)
                                    .fontWeight(day == 19 ? .bold : .regular)
                                
                                // Indicator for training
                                if let record = records.first(where: { Calendar.current.component(.day, from: $0.date) == day }) {
                                    Circle()
                                        .fill(record.isCompleted ? Theme.primary : Theme.secondary)
                                        .frame(width: 4, height: 4)
                                    Text(record.focusArea)
                                        .font(.system(size: 8))
                                        .foregroundColor(Theme.textSecondary)
                                } else {
                                    Spacer().frame(height: 14)
                                }
                            }
                            .frame(height: 40)
                            .background(day == 19 ? Theme.primary.opacity(0.1) : Color.clear)
                            .cornerRadius(4)
                        }
                    }
                }
                .padding(16)
                .background(Theme.surface)
                .cornerRadius(12)
                .padding(.horizontal, 20)
                
                // Details for selected day
                VStack(alignment: .leading, spacing: 16) {
                    Text("当日详情")
                        .font(Theme.Typography.title2)
                        .foregroundColor(Theme.textPrimary)
                    
                    if let record = records.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("今日已完成：\(record.focusArea)训练")
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.textPrimary)
                                Text("共 5 个动作，用时 45 分钟")
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Theme.primary)
                                .font(.title2)
                        }
                        .padding(16)
                        .background(Theme.surface)
                        .cornerRadius(8)
                    } else {
                        VStack(spacing: 12) {
                            Text("今天还没有训练哦")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.textSecondary)
                            
                            Button(action: {}) {
                                Text("查看未完成计划")
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Theme.primary, lineWidth: 1)
                                    )
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
    }
}

#Preview {
    TrainingRecordView()
}
