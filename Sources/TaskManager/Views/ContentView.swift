import SwiftUI

enum SidebarSection: CaseIterable, Identifiable, Hashable {
    case processes
    case performance
    case settings

    var id: Self { self }

    var icon: String {
        switch self {
        case .processes: return "list.bullet.rectangle"
        case .performance: return "waveform.path.ecg"
        case .settings: return "gearshape"
        }
    }

    var label: String {
        switch self {
        case .processes: return tr(en: "Processes", pt: "Processos")
        case .performance: return tr(en: "Performance", pt: "Desempenho")
        case .settings: return tr(en: "Settings", pt: "Ajustes")
        }
    }
}

struct ContentView: View {
    @ObservedObject private var settings = SettingsStore.shared
    @State private var selection: SidebarSection = .processes

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Divider().overlay(Theme.separator)

            Group {
                switch selection {
                case .processes: ProcessListView()
                case .performance: PerformanceView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.contentBackground)
        }
        .frame(minWidth: 680, idealWidth: 780, minHeight: 480, idealHeight: 580)
    }

    private var sidebar: some View {
        VStack(spacing: 4) {
            Spacer().frame(height: 16)

            ForEach(SidebarSection.allCases) { section in
                sidebarButton(section)
            }

            Spacer()
        }
        .frame(width: 64)
        .background(Theme.sidebarBackground)
    }

    private func sidebarButton(_ section: SidebarSection) -> some View {
        let isSelected = selection == section
        return Button {
            selection = section
        } label: {
            VStack(spacing: 4) {
                Image(systemName: section.icon)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                Text(section.label)
                    .font(.system(size: 9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? .white : .secondary)
            .frame(width: 52, height: 48)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Theme.accent.opacity(0.85) : .clear)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
    }
}
