import SwiftUI

struct scheduleHistoryView: View {
    @ObservedObject var manager = ScheduleHistoryManager.shared
    @Environment(\.dismiss) var dismiss
    
    var onReEdit: ((ScheduleHistoryRecord) -> Void)?
    
    var groupedRecords: [String: [ScheduleHistoryRecord]] {
        Dictionary(grouping: manager.records) { $0.dateString }
    }
    
    var sortedDates: [String] {
        groupedRecords.keys.sorted(by: >)
    }
    
    @State private var showSuccessAlert = false
    @State private var showReEditConfirm = false
    @State private var selectedRecordForReEdit: ScheduleHistoryRecord?
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                    }
                    
                    Spacer()
                    
                    Text("历史记录")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    // Invisible placeholder for alignment
                    Image(systemName: "chevron.left")
                        .opacity(0)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                if manager.records.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.3))
                        Text("暂无行程记录")
                            .foregroundColor(.gray)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(sortedDates, id: \.self) { date in
                            Section(header: Text(date)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.gray)
                                .padding(.vertical, 8)
                            ) {
                                ForEach(groupedRecords[date] ?? []) { record in
                                    ScheduleHistoryCell(record: record)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedRecordForReEdit = record
                                            showReEditConfirm = true
                                        }
                                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                withAnimation {
                                                    manager.deleteRecord(record)
                                                }
                                            } label: {
                                                Label("删除", systemImage: "trash")
                                            }
                                            
                                            Button {
                                                addToCalendarMulti(record.schedule, isReminderEnabled: true, reminderOffset: 15)
                                                showSuccessAlert = true
                                            } label: {
                                                Label("日历", systemImage: "calendar.badge.plus")
                                            }
                                            .tint(.blue)
                                        }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .background(Color.white)
                }
            }
            .navigationBarHidden(true)
        }
        .alert("重新编辑", isPresented: $showReEditConfirm) {
            Button("取消", role: .cancel) {}
            Button("确定") {
                if let record = selectedRecordForReEdit {
                    onReEdit?(record)
                    dismiss()
                }
            }
        } message: {
            Text("确定要重新编辑这条记录吗？这会覆盖当前正在处理的内容。")
        }
        .alert("保存成功", isPresented: $showSuccessAlert) {
            Button("好的") {}
        } message: {
            Text("行程已添加到您的日历中。")
        }
    }
    
    struct ScheduleHistoryCell: View {
        let record: ScheduleHistoryRecord
        @ObservedObject var manager = ScheduleHistoryManager.shared
        
        var body: some View {
            HStack(alignment: .top, spacing: 16) {
                // Image
                if let imageName = record.imageName, let uiImage = manager.loadImage(named: imageName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .cornerRadius(12)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 80, height: 80)
                        .cornerRadius(12)
                        .overlay(
                            Image(systemName: "calendar")
                                .foregroundColor(.gray.opacity(0.3))
                        )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(record.schedule.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                        .lineLimit(1)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text("\(record.schedule.start_time) - \(record.schedule.end_time)")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.gray)
                        
                        if !record.schedule.location.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.system(size: 10))
                                Text(record.schedule.location)
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(.gray)
                        }
                    }
                    
                    if !record.schedule.remark.isEmpty {
                        Text(record.schedule.remark)
                            .font(.system(size: 12))
                            .foregroundColor(.gray.opacity(0.8))
                            .padding(.top, 4)
                    }
                }
                
                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(white: 0.99))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )
        }
    }
}


#Preview {
    scheduleHistoryView()
}
