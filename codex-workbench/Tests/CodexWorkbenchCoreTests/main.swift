import Foundation
import CodexWorkbenchCore

if CommandLine.arguments.contains("--live-dry-run") {
    let snapshot = LocalEvidenceReader().read()
    let events = EvidenceReconciler().events(from: snapshot)
    let categoryCounts = Dictionary(grouping: events, by: \.category)
        .mapValues(\.count)
        .map { "\($0.key.rawValue)=\($0.value)" }
        .sorted()
        .joined(separator: ",")
    print(
        "LIVE_DRY_RUN cards=\(snapshot.contextCards.count) resets=\(snapshot.automaticResets.count) "
            + "lifecycle=\(snapshot.lifecycleRecords.count) events=\(events.count) categories=\(categoryCounts) "
            + "warnings=\(snapshot.warnings.count)"
    )
}

var runner = TestRunner()
runAppContractsTests(&runner)
runLedgerRepositoryTests(&runner)
runActivityFilterTests(&runner)
runEvidenceReconcilerTests(&runner)
runQuotaObservationTests(&runner)
runCodexMetadataCatalogTests(&runner)
runWorkflowEvidenceTests(&runner)
runObservationStateTests(&runner)
runAppServerNotificationTests(&runner)
runAccountGatewayTests(&runner)
runCodexIntegrationTests(&runner)

if runner.failures.isEmpty {
    print("PASS: CodexWorkbenchCoreTests")
} else {
    for failure in runner.failures {
        fputs("FAIL: \(failure)\n", stderr)
    }
    exit(1)
}
