import CodexWorkbenchCore
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

@MainActor
enum WorkbenchLoginItemManager {
    static var service: SMAppService {
        SMAppService.loginItem(identifier: WorkbenchBundleContract.loginHelperIdentifier)
    }

    static var isEnabled: Bool {
        service.status == .enabled || service.status == .requiresApproval
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            if service.status == .notRegistered {
                try service.register()
            }
            if service.status == .enabled, SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } else {
            if service.status != .notRegistered {
                try service.unregister()
            }
            if SMAppService.mainApp.status != .notRegistered {
                try SMAppService.mainApp.unregister()
            }
        }
    }

    static func migrateLegacyRegistrationIfNeeded() {
        guard SMAppService.mainApp.status == .enabled else { return }
        do {
            if service.status == .notRegistered {
                try service.register()
            }
            if service.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Keep the working legacy registration if the helper cannot be enabled.
        }
    }
}

struct WorkbenchSettingsView: View {
    @AppStorage(WorkbenchPreferences.showWhenCodexLaunchesKey)
    private var showWhenCodexLaunches = true

    @State private var startAtLogin = WorkbenchLoginItemManager.isEnabled
    @State private var loginItemError: String?

    var body: some View {
        Form {
            Section("启动关联") {
                Toggle("打开 Codex 时显示观测站", isOn: $showWhenCodexLaunches)
                Toggle("登录 Mac 时启动观测站", isOn: startAtLoginBinding)
                if let loginItemError {
                    Text(loginItemError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("说明") {
                Text("登录启动让菜单栏入口始终可用；Codex 启动关联只负责显示观测站，不会改变账号或任务。")
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
                        try WorkbenchLoginItemManager.setEnabled(true)
                    } else {
                        try WorkbenchLoginItemManager.setEnabled(false)
                    }
                    startAtLogin = WorkbenchLoginItemManager.isEnabled
                    loginItemError = nil
                } catch {
                    startAtLogin = WorkbenchLoginItemManager.isEnabled
                    loginItemError = "无法更新登录启动设置：\(error.localizedDescription)"
                }
            }
        )
    }
}
