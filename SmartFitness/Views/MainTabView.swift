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
                Label("训练计划", systemImage: "figure.strengthtraining.traditional")
            }
            .tag(0)
            
            NavigationView {
                ExerciseLibraryView()//TodayTrainingView()
            }
            .tabItem {
                Label("今日训练", systemImage: "plus.circle")
            }
            .tag(1)
            
            TrainingRecordView()
                .tabItem {
                    Label("训练记录", systemImage: "calendar")
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
            Theme.background.ignoresSafeArea()
            
            if appData.manualPlan.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 60))
                        .foregroundColor(Theme.textSecondary)
                    Text("今日还没有添加训练计划哦")
                        .font(Theme.Typography.title2)
                        .foregroundColor(Theme.textSecondary)
                    Text("请到「训练计划」页面添加今日内容")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.textSecondary)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("🔥 今日训练挑战")
                            .font(Theme.Typography.title1)
                            .foregroundColor(Theme.textPrimary)
                            .padding(.top, 16)
                        
                        ForEach($appData.manualPlan) { $exercise in
                            ExerciseCard(exercise: $exercise)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .navigationTitle("今日训练")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MeView: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            Text("我的 (开发中)")
                .foregroundColor(Theme.textPrimary)
        }
    }
}

#Preview {
    MainTabView()
}
