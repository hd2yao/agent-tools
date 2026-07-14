import CodexWorkbenchCore
import SwiftUI

@main
struct CodexWorkbenchApp: App {
    @StateObject private var model = WorkbenchAppModel()

    var body: some Scene {
        Window("Codex 工具台", id: "main") {
            WorkbenchShell(model: model)
                .frame(
                    minWidth: WorkbenchLayout.minimumWidth,
                    minHeight: WorkbenchLayout.minimumHeight
                )
                .task { model.bootstrap() }
        }
        .defaultSize(width: WorkbenchLayout.defaultWidth, height: WorkbenchLayout.defaultHeight)
        .windowResizability(.contentMinSize)

        MenuBarExtra {
            MenuBarView(model: model)
        } label: {
            Label("Codex 工具台", systemImage: "square.grid.2x2")
        }
        .menuBarExtraStyle(.window)

        Settings {
            WorkbenchSettingsView()
        }
    }
}
