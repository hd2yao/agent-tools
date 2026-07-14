import CodexWorkbenchCore
import SwiftUI

@main
struct CodexWorkbenchApp: App {
    var body: some Scene {
        WindowGroup("Codex 工具台") {
            NavigationSplitView {
                List(AppModule.allCases, id: \.self) { module in
                    Label(module.title, systemImage: module.systemImage)
                }
                .navigationTitle("Codex 工具台")
                .navigationSplitViewColumnWidth(min: 188, ideal: 216, max: 248)
            } detail: {
                VStack(spacing: 12) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Codex 工具台")
                        .font(.title2.weight(.semibold))
                    Text("正在建立运行概览与操作日志。")
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
            .frame(minWidth: 900, minHeight: 640)
        }
        .defaultSize(width: 1160, height: 780)
        .windowResizability(.contentMinSize)
    }
}
