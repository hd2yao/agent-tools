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
            Label("Codex 观测站", systemImage: "scope")
        }
        .menuBarExtraStyle(.window)

        Settings {
            WorkbenchSettingsView()
        }
    }
}
