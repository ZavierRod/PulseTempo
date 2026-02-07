//
//  MainTabView.swift
//  inSync
//
//  Created by Zavier Rodrigues on 2/7/26.
//

import SwiftUI

/// Main tab-based navigation after onboarding
/// Provides bottom tab bar with Home, Playlists, Past Workouts, and Settings
struct MainTabView: View {
    
    @State private var selectedTab: Tab = .home
    @StateObject private var homeViewModel = HomeViewModel()
    
    enum Tab: String {
        case home, playlists, history, settings
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(viewModel: homeViewModel)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(Tab.home)
            
            PlaylistSelectionView { tracks in
                print("✅ Selected \(tracks.count) tracks from playlists")
                homeViewModel.refreshPlaylists()
            }
            .tabItem {
                Image(systemName: "music.note.list")
                Text("Playlists")
            }
            .tag(Tab.playlists)
            
            RunHistoryView(viewModel: homeViewModel)
                .tabItem {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("History")
                }
                .tag(Tab.history)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
                .tag(Tab.settings)
        }
        .tint(.red)
        .onAppear {
            // Style the tab bar for dark theme
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithOpaqueBackground()
            tabBarAppearance.backgroundColor = UIColor.black.withAlphaComponent(0.9)
            
            // Unselected items
            tabBarAppearance.stackedLayoutAppearance.normal.iconColor = UIColor.gray
            tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.gray]
            
            // Selected items
            tabBarAppearance.stackedLayoutAppearance.selected.iconColor = UIColor.systemRed
            tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.systemRed]
            
            UITabBar.appearance().standardAppearance = tabBarAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
    }
}

#if DEBUG
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
#endif
