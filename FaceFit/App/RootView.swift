import SwiftUI

enum AppTab: Hashable {
    case today, exercises, analyze, progress, you
}

struct RootView: View {
    @AppStorage(SettingsKey.hasOnboarded) private var hasOnboarded = false
    @State private var tab: AppTab = .today

    var body: some View {
        TabView(selection: $tab) {
            TodayView(selectedTab: $tab)
                .tabItem { Label("Today", systemImage: "sun.max") }
                .tag(AppTab.today)
            ExerciseListView()
                .tabItem { Label("Exercises", systemImage: "face.smiling") }
                .tag(AppTab.exercises)
            AnalyzeView()
                .tabItem { Label("Analyze", systemImage: "faceid") }
                .tag(AppTab.analyze)
            TrendsView()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(AppTab.progress)
            ProfileView()
                .tabItem { Label("You", systemImage: "person") }
                .tag(AppTab.you)
        }
        .fullScreenCover(isPresented: Binding(get: { !hasOnboarded }, set: { hasOnboarded = !$0 })) {
            OnboardingView { hasOnboarded = true }
        }
    }
}
