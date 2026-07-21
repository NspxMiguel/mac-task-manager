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
                    Text(tr(en: "Shortcut to open/close", pt: "Atalho para abrir/fechar"))
                    Spacer()
                    Button {
                        isRecording = true
                    } label: {
                        Text(isRecording ? tr(en: "Press a key…", pt: "Pressione uma tecla…") : settings.hotKeyCombo.displayString)
                            .frame(minWidth: 90)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .contentShape(Rectangle())
                            .background(RoundedRectangle(cornerRadius: 6).fill(isRecording ? Color.accentColor.opacity(0.2) : Theme.controlBackground))
                    }
                    .buttonStyle(.plain)
                    .background(
                        ShortcutRecorderView(combo: $settings.hotKeyCombo, isRecording: $isRecording)
                            .frame(width: 0, height: 0)
                    )

                    Button(tr(en: "Default", pt: "Padrão")) {
                        settings.resetToDefault()
                    }
                    .contentShape(Rectangle())
                }
                Text(tr(
                    en: "Default: ⌘⇧⎋ (Cmd + Shift + Esc). Click the shortcut and press the new combination.",
                    pt: "Padrão: ⌘⇧⎋ (Cmd + Shift + Esc). Clique no atalho e pressione a nova combinação desejada."
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text(tr(en: "Global shortcut", pt: "Atalho global"))
            }

            Section {
                Toggle(tr(en: "Open automatically at login", pt: "Abrir automaticamente ao fazer login"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        toggleLaunchAtLogin(newValue)
                    }
            } header: {
                Text(tr(en: "Startup", pt: "Inicialização"))
            }

            Section {
                Toggle(tr(en: "Show icon in Dock", pt: "Mostrar ícone no Dock"), isOn: $settings.showInDock)
                Text(tr(
                    en: "When off, the app stays available only in the menu bar and via the global shortcut.",
                    pt: "Quando desativado, o app fica disponível apenas na barra de menu e pelo atalho global."
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text(tr(en: "Dock", pt: "Dock"))
            }

            Section {
                Picker(tr(en: "Language", pt: "Idioma"), selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text(tr(en: "Language", pt: "Idioma"))
            }

            Section {
                Picker(tr(en: "Appearance", pt: "Aparência"), selection: $settings.themeMode) {
                    ForEach(ThemeMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                Text(tr(
                    en: "\"System\" follows your Mac's Light/Dark setting automatically.",
                    pt: "\"Sistema\" acompanha automaticamente o modo claro/escuro do seu Mac."
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text(tr(en: "Appearance", pt: "Aparência"))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.contentBackground)
        .padding(20)
        .frame(maxWidth: 480, alignment: .leading)
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
