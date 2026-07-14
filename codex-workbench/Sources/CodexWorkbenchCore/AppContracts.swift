public enum AppModule: String, CaseIterable, Hashable, Sendable {
    case overview
    case activity
    case accounts

    public var title: String {
        switch self {
        case .overview: "概览"
        case .activity: "操作日志"
        case .accounts: "账号管理"
        }
    }

    public var systemImage: String {
        switch self {
        case .overview: "rectangle.grid.2x2"
        case .activity: "clock.arrow.trianglehead.counterclockwise.rotate.90"
        case .accounts: "person.2"
        }
    }
}
