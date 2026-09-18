import SwiftUI
import UIKit

struct ContentView: View {
    @State private var showSettings = false
    @State private var showLogs = false
    
    var body: some View {
        // SOLO PATCHES - TU SICA PECHO
        PatchProjectsView(
            onOpenSettings: { showSettings = true },
            onOpenLogs: { showLogs = true }
        )
        .tint(AppTheme.accent)
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showLogs) { LogView() }
    }
}