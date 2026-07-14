import Foundation

var runner = TestRunner()
runAppContractsTests(&runner)
runLedgerRepositoryTests(&runner)
runActivityFilterTests(&runner)

if runner.failures.isEmpty {
    print("PASS: CodexWorkbenchCoreTests")
} else {
    for failure in runner.failures {
        fputs("FAIL: \(failure)\n", stderr)
    }
    exit(1)
}
