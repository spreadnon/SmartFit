import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appData: AppData

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
                TodayTrainingView()
            }
            .tabItem {
                Label("TODAY TRAINING", systemImage: "play.circle")
            }
            .tag(1)

            NavigationView {
                ExerciseLibraryView()
            }
            .tabItem {
                Label("LIBRARY", systemImage: "square.grid.2x2")
            }
            .tag(2)

            TrainingRecordView()
                .tabItem {
                    Label("HISTORY", systemImage: "calendar")
                }
                .tag(3)

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
