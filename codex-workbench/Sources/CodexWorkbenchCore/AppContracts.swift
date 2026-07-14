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

public enum WorkbenchLayout {
    public static let minimumWidth = 900.0
    public static let minimumHeight = 640.0
    public static let defaultWidth = 1_160.0
    public static let defaultHeight = 780.0
    public static let sidebarMinimum = 188.0
    public static let sidebarIdeal = 216.0
    public static let sidebarMaximum = 248.0
    public static let spacingUnit = 8.0
}
