import CodexWorkbenchCore
import SwiftUI

@main
struct CodexWorkbenchApp: App {
    @StateObject private var model = WorkbenchAppModel()

    var body: some Scene {
        WindowGroup("Codex 工具台") {
            WorkbenchShell(model: model)
                .frame(
                    minWidth: WorkbenchLayout.minimumWidth,
                    minHeight: WorkbenchLayout.minimumHeight
                )
                .task { model.bootstrap() }
        }
        .defaultSize(width: WorkbenchLayout.defaultWidth, height: WorkbenchLayout.defaultHeight)
        .windowResizability(.contentMinSize)
    }
}
