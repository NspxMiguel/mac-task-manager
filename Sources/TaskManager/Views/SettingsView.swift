import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var settings = SettingsStore.shared
    @State private var isRecording = false
    @State private var launchAtLogin = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Atalho para abrir/fechar")
                    Spacer()
                    Button {
                        isRecording = true
                    } label: {
                        Text(isRecording ? "Pressione uma tecla…" : settings.hotKeyCombo.displayString)
                            .frame(minWidth: 90)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(RoundedRectangle(cornerRadius: 6).fill(isRecording ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                    .background(
                        ShortcutRecorderView(combo: $settings.hotKeyCombo, isRecording: $isRecording)
                            .frame(width: 0, height: 0)
                    )

                    Button("Padrão") {
                        settings.resetToDefault()
                    }
                }
                Text("Padrão: ⌘⎋ (Cmd + Esc). Clique no atalho e pressione a nova combinação desejada.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Atalho global")
            }

            Section {
                Toggle("Abrir automaticamente ao fazer login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        toggleLaunchAtLogin(newValue)
                    }
            } header: {
                Text("Inicialização")
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear {
            if #available(macOS 13.0, *) {
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }

    private func toggleLaunchAtLogin(_ enabled: Bool) {
        guard #available(macOS 13.0, *) else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Falha ao configurar login automático: \(error)")
        }
    }
}
