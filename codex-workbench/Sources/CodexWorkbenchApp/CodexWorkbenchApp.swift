import CodexWorkbenchCore
import SwiftUI

@main
struct CodexWorkbenchApp: App {
    @StateObject private var model = WorkbenchAppModel()

    var body: some Scene {
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

        MenuBarExtra {
            MenuBarView(model: model)
        } label: {
            let presentation = AccountPresentationBuilder.menu(payload: model.accountPayload)
            HStack(spacing: 4) {
                Image(systemName: presentation.runtimeSymbol)
                Text(presentation.quotaText)
                    .monospacedDigit()
            }
            .accessibilityLabel(presentation.accessibilityLabel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            WorkbenchSettingsView()
        }
    }
}
