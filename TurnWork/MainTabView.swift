import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ContentView()
                .tabItem {
                    Label("首页", systemImage: "calendar")
                }
                .tag(0)
            
            StatisticsTabView()
                .tabItem {
                    Label("统计", systemImage: "chart.bar")
                }
                .tag(1)
            
            AlarmView()
                .tabItem {
                    Label("闹钟", systemImage: "alarm.fill")
                }
                .tag(2)
            
            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.circle")
                }
                .tag(3)
        }
    }
} 