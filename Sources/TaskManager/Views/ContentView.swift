import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            ProcessListView()
                .tabItem { Label("Processos", systemImage: "list.bullet.rectangle") }

            PerformanceView()
                .tabItem { Label("Desempenho", systemImage: "waveform.path.ecg") }

            SettingsView()
                .tabItem { Label("Ajustes", systemImage: "gearshape") }
        }
        .frame(minWidth: 640, idealWidth: 760, minHeight: 460, idealHeight: 560)
    }
}
