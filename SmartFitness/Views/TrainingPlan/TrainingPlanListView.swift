import SwiftUI

struct TrainingPlanListView: View {
    @EnvironmentObject var appData: AppData
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            if let plan = appData.currentPlan {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Summary
                        VStack(alignment: .leading, spacing: 12) {
                            Text(plan.trainingSplit)
                                .font(Theme.Typography.title1)
                                .foregroundColor(Theme.textPrimary)
                            Text(plan.instructions)
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.textSecondary)
                                .lineSpacing(1.5)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Days List
                        VStack(spacing: 16) {
                            ForEach(plan.days) { day in
                                NavigationLink(destination: TrainingPlanDetailView(plan: plan, selectedDayIndex: plan.days.firstIndex(where: { $0.id == day.id }) ?? 0)) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("训练日 \(day.label)")
                                                .font(Theme.Typography.title2)
                                                .foregroundColor(Theme.textPrimary)
                                            Text("\(day.exercises.count) 个动作")
                                                .font(Theme.Typography.caption)
                                                .foregroundColor(Theme.textSecondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                    .padding(20)
                                    .background(Theme.surface)
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("我的计划")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    withAnimation {
                        appData.resetPlan()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(Theme.primary)
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        TrainingPlanListView()
            .environmentObject(AppData())
    }
}
