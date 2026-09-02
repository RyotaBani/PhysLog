import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var proStore = ProStore.shared

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .environment(proStore)
        .task { await proStore.load() }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("ホーム", systemImage: "house.fill") }

            RecordView()
                .tabItem { Label("記録", systemImage: "square.and.pencil") }

            GraphView()
                .tabItem { Label("グラフ", systemImage: "chart.line.uptrend.xyaxis") }

            TrainingMenuView()
                .tabItem { Label("メニュー", systemImage: "list.bullet.clipboard.fill") }

            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape.fill") }
        }
        .tint(Color.physlogPrimary)
    }
}

#Preview("メイン") {
    MainTabView()
        .modelContainer(PreviewData.container)
        .environment(ProStore.shared)
}

#Preview("オンボーディング") {
    OnboardingView()
}
