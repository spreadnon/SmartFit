import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appData: AppData
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $appData.selectedTab) {
            NavigationView {
                TrainingPlanListView()
            }
            .tabItem {
                Label("TRAINING PLAN", systemImage: "figure.strengthtraining.traditional")
            }
            .tag(0)
            
            NavigationView {
                ExerciseLibraryView()//TodayTrainingView()
            }
            .tabItem {
                Label("TODAY TRAINING", systemImage: "plus.circle")
            }
            .tag(1)
            
            TrainingRecordView()
                .tabItem {
                    Label("HISTORY", systemImage: "calendar")
                }
                .tag(2)
            
//            MeView()
//                .tabItem {
//                    Label("我的", systemImage: "person.circle")
//                }
//                .tag(3)
        }
        .accentColor(StitchTheme.primary)
        .preferredColorScheme(.dark)
    }
}

// 真正的今日训练视图
struct TodayTrainingView: View {
    @EnvironmentObject var appData: AppData
    
    var body: some View {
        ZStack {
            StitchTheme.background.ignoresSafeArea()
            
            if appData.manualPlan == nil || (appData.manualPlan?.days.first?.exercises.isEmpty ?? true) {
                VStack(spacing: 20) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 60))
                        .foregroundColor(StitchTheme.onSurfaceVariant)
                    Text("NO TRAINING PLAN ADDED TODAY")
                        .font(StitchTypography.dataMedium)
                        .foregroundColor(StitchTheme.onSurfaceVariant)
                    Text("PLEASE ADD TASKS IN TRAINING PLAN")
                        .font(StitchTypography.body)
                        .foregroundColor(StitchTheme.onSurfaceVariant)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("🔥 TODAY'S CHALLENGE")
                            .font(StitchTypography.headline)
                            .foregroundColor(StitchTheme.onSurface)
                            .padding(.top, 16)
                        
                        if let manualPlan = appData.manualPlan {
                            let planBinding = Binding(
                                get: { appData.manualPlan ?? manualPlan },
                                set: { appData.manualPlan = $0 }
                            )
                            ForEach(planBinding.days[0].exercises.indices, id: \.self) { idx in
                                ExerciseCard(exercise: planBinding.days[0].exercises[idx])
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .navigationTitle("TODAY TRAINING")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MeView: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            Text("ME (COMING SOON)")
                .foregroundColor(StitchTheme.onSurface)
        }
    }
}

#Preview {
    MainTabView()
}
