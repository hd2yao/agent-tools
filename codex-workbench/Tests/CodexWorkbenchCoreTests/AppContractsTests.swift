import CodexWorkbenchCore

func runAppContractsTests(_ runner: inout TestRunner) {
    runner.expect(
        AppModule.allCases == [.overview, .activity, .accounts],
        "Primary modules should keep overview/activity/accounts order"
    )
    runner.expect(AppModule.overview.title == "概览", "Overview title should be localized")
    runner.expect(AppModule.activity.title == "操作日志", "Activity title should be localized")
    runner.expect(AppModule.accounts.title == "账号管理", "Accounts title should be localized")
    runner.expect(
        AppModule.allCases.allSatisfy { !$0.systemImage.isEmpty },
        "Every module should have an SF Symbol"
    )
}
