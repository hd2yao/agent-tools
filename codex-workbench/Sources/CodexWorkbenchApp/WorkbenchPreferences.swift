import ServiceManagement
import SwiftUI

enum WorkbenchPreferences {
    static let showWhenCodexLaunchesKey = "showWhenCodexLaunches"

    static var shouldShowWhenCodexLaunches: Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: showWhenCodexLaunchesKey) != nil else { return true }
        return defaults.bool(forKey: showWhenCodexLaunchesKey)
    }
}

struct WorkbenchSettingsView: View {
    @AppStorage(WorkbenchPreferences.showWhenCodexLaunchesKey)
    private var showWhenCodexLaunches = true

    @State private var startAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginItemError: String?

    var body: some View {
        Form {
            Section("启动关联") {
                Toggle("打开 Codex 时显示工具台", isOn: $showWhenCodexLaunches)
                Toggle("登录 Mac 时启动工具台", isOn: startAtLoginBinding)
                if let loginItemError {
                    Text(loginItemError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("说明") {
                Text("登录启动让菜单栏入口始终可用；Codex 启动关联只负责显示工具台，不会改变账号或任务。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 480, height: 250)
    }

    private var startAtLoginBinding: Binding<Bool> {
        Binding(
            get: { startAtLogin },
            set: { newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                    startAtLogin = newValue
                    loginItemError = nil
                } catch {
                    startAtLogin = SMAppService.mainApp.status == .enabled
                    loginItemError = "无法更新登录启动设置：\(error.localizedDescription)"
                }
            }
        )
    }
}
