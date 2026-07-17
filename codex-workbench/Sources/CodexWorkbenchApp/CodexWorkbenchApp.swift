import CodexWorkbenchCore
import SwiftUI

@main
struct CodexWorkbenchApp: App {
    @NSApplicationDelegateAdaptor(WorkbenchAppDelegate.self) private var appDelegate
    @StateObject private var model = WorkbenchAppModel()

    init() {
        WorkbenchLoginItemManager.migrateLegacyRegistrationIfNeeded()
    }

    var body: some Scene {
        mainWindow

        MenuBarExtra {
            MenuBarView(model: model)
        } label: {
            MenuBarStatusLabel(model: model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            WorkbenchSettingsView()
        }
    }

    private var mainWindow: some Scene {
        Window("Codex 观测站", id: "main") {
            WorkbenchShell(model: model)
                .frame(
                    minWidth: WorkbenchLayout.minimumWidth,
                    minHeight: WorkbenchLayout.minimumContentHeight
                )
                .task { model.bootstrap() }
        }
        .defaultSize(width: WorkbenchLayout.defaultWidth, height: WorkbenchLayout.defaultHeight)
        .windowResizability(.contentMinSize)
    }
}

private struct MenuBarStatusLabel: View {
    @ObservedObject var model: WorkbenchAppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let presentation = AccountPresentationBuilder.menu(payload: model.accountPayload)
        HStack(spacing: 4) {
            Image(systemName: presentation.runtimeSymbol)
            Text(presentation.quotaText)
                .monospacedDigit()
        }
        .accessibilityLabel(presentation.accessibilityLabel)
        .onReceive(NotificationCenter.default.publisher(for: .workbenchReopenRequested)) { _ in
            NSApp.setActivationPolicy(.regular)
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
