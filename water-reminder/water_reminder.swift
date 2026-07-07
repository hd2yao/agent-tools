#!/usr/bin/env swift

import AppKit
import Foundation

struct ReminderSettings {
    var intervalMinutes: Double = 15
    var entrySeconds: Double = 4
    var exitSeconds: Double = 1.5
    var message: String = "太辛苦了！快去喝水！"
    var confirmText: String = "知道了"
    var autoConfirmSeconds: Double?
    var once = false
    var dryRun = false
    var startNow = false
    var help = false

    var intervalSeconds: TimeInterval {
        max(1, intervalMinutes * 60)
    }

    static func parse(_ arguments: [String]) throws -> ReminderSettings {
        var settings = ReminderSettings()
        var index = 0

        func nextValue(for option: String) throws -> String {
            let valueIndex = index + 1
            guard valueIndex < arguments.count else {
                throw CLIError.missingValue(option)
            }
            index = valueIndex
            return arguments[valueIndex]
        }

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--help", "-h":
                settings.help = true
            case "--dry-run":
                settings.dryRun = true
            case "--once":
                settings.once = true
            case "--start-now":
                settings.startNow = true
            case "--interval":
                let value = try nextValue(for: argument)
                guard let minutes = Double(value), minutes > 0 else {
                    throw CLIError.invalidNumber(argument, value)
                }
                settings.intervalMinutes = minutes
            case "--display-seconds", "--entry-seconds":
                let value = try nextValue(for: argument)
                guard let seconds = Double(value), seconds > 0 else {
                    throw CLIError.invalidNumber(argument, value)
                }
                settings.entrySeconds = seconds
            case "--exit-seconds":
                let value = try nextValue(for: argument)
                guard let seconds = Double(value), seconds > 0 else {
                    throw CLIError.invalidNumber(argument, value)
                }
                settings.exitSeconds = seconds
            case "--message":
                settings.message = try nextValue(for: argument)
            case "--confirm-text":
                settings.confirmText = try nextValue(for: argument)
            case "--auto-confirm-seconds":
                let value = try nextValue(for: argument)
                guard let seconds = Double(value), seconds > 0 else {
                    throw CLIError.invalidNumber(argument, value)
                }
                settings.autoConfirmSeconds = seconds
            default:
                throw CLIError.unknownOption(argument)
            }
            index += 1
        }

        return settings
    }
}

enum CLIError: Error, CustomStringConvertible {
    case invalidNumber(String, String)
    case missingValue(String)
    case unknownOption(String)

    var description: String {
        switch self {
        case let .invalidNumber(option, value):
            return "\(option) needs a positive number, got '\(value)'."
        case let .missingValue(option):
            return "\(option) needs a value."
        case let .unknownOption(option):
            return "Unknown option: \(option)"
        }
    }
}

func formatNumber(_ value: Double) -> String {
    if value.rounded() == value {
        return String(Int(value))
    }
    return String(value)
}

func easeInOutCubic(_ value: CGFloat) -> CGFloat {
    if value < 0.5 {
        return 4 * value * value * value
    }
    return 1 - pow(-2 * value + 2, 3) / 2
}

func printHelp() {
    print("""
    water_reminder.swift

    Usage:
      swift water_reminder.swift [options]

    Options:
      --interval <minutes>         Reminder interval. Default: 15
      --message <text>             Reminder text. Default: 太辛苦了！快去喝水！
      --display-seconds <seconds>  Flight-in duration before confirmation. Default: 4
      --entry-seconds <seconds>    Same as --display-seconds
      --exit-seconds <seconds>     Flight-out duration after confirmation. Default: 1.5
      --confirm-text <text>        Confirmation button text. Default: 知道了
      --auto-confirm-seconds <n>   Auto-click after waiting n seconds, mainly for preview/testing
      --once                       Show one reminder now and exit
      --start-now                  Show immediately, then continue on the interval
      --dry-run                    Print parsed settings without opening UI
      --help                       Show this help
    """)
}

func printDryRun(_ settings: ReminderSettings) {
    print("message=\(settings.message)")
    print("interval_minutes=\(formatNumber(settings.intervalMinutes))")
    print("entry_seconds=\(formatNumber(settings.entrySeconds))")
    print("exit_seconds=\(formatNumber(settings.exitSeconds))")
    print("mode=\(settings.once ? "once" : "repeat")")
    print("start_now=\(settings.startNow ? "true" : "false")")
    print("confirmation=click")
    print("confirm_text=\(settings.confirmText)")
    if let autoConfirmSeconds = settings.autoConfirmSeconds {
        print("auto_confirm_seconds=\(formatNumber(autoConfirmSeconds))")
    } else {
        print("auto_confirm_seconds=none")
    }
    print("window_scope=compact")
    print("click_blocking=confirm_button")
    print("confirm_control=nsbutton")
    print("accepts_first_mouse=true")
    print("visual_style=macos_compact_toast")
    print("motion=slow_enter_wait_confirm_exit")
    print("icon_semantics=airplane_leads_banner_trails")
    print("decorations=minimal")
    print("ui=appkit_compact_reminder")
}

func executableURLForChildProcess() -> URL {
    let executablePath = CommandLine.arguments[0]
    if executablePath.hasPrefix("/") {
        return URL(fileURLWithPath: executablePath)
    }

    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(executablePath)
}

func runReminderChild(settings: ReminderSettings) {
    let process = Process()
    process.executableURL = executableURLForChildProcess()
    process.arguments = [
        "--once",
        "--display-seconds",
        formatNumber(settings.entrySeconds),
        "--exit-seconds",
        formatNumber(settings.exitSeconds),
        "--message",
        settings.message,
        "--confirm-text",
        settings.confirmText,
    ]
    if let autoConfirmSeconds = settings.autoConfirmSeconds {
        process.arguments?.append(contentsOf: ["--auto-confirm-seconds", formatNumber(autoConfirmSeconds)])
    }
    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        fputs("water-reminder: failed to launch reminder child: \(error)\n", stderr)
    }
}

func runRepeatingService(settings: ReminderSettings) -> Never {
    if settings.startNow {
        runReminderChild(settings: settings)
    }

    while true {
        Thread.sleep(forTimeInterval: settings.intervalSeconds)
        runReminderChild(settings: settings)
    }
}

func runOverlayApp(settings: ReminderSettings) {
    let app = NSApplication.shared
    let delegate = ReminderAppDelegate(settings: settings)
    app.delegate = delegate
    app.run()
}

final class ReminderAppDelegate: NSObject, NSApplicationDelegate {
    private let settings: ReminderSettings
    private var reminderTimer: Timer?
    private var overlay: ReminderOverlay?

    init(settings: ReminderSettings) {
        self.settings = settings
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        if settings.once || settings.startNow {
            showReminder()
        }

        guard !settings.once else {
            return
        }

        reminderTimer = Timer.scheduledTimer(
            withTimeInterval: settings.intervalSeconds,
            repeats: true
        ) { [weak self] _ in
            self?.showReminder()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func showReminder() {
        overlay?.close()
        let nextOverlay = ReminderOverlay(settings: settings) { [weak self] in
            guard let self else {
                return
            }
            self.overlay = nil
            if self.settings.once {
                exit(0)
            }
        }
        overlay = nextOverlay
        nextOverlay.show()
    }
}

final class ReminderOverlay {
    private enum AnimationPhase {
        case entering
        case waiting
        case exiting
    }

    private let window: NSWindow
    private let reminderView: PlaneReminderView
    private let screenFrame: NSRect
    private let windowSize: NSSize
    private let entryDuration: TimeInterval
    private let exitDuration: TimeInterval
    private let autoConfirmSeconds: TimeInterval?
    private let onComplete: () -> Void
    private var animationTimer: Timer?
    private var autoConfirmTimer: Timer?
    private var mouseCaptureTimer: Timer?
    private var phase: AnimationPhase = .entering
    private var phaseStartedAt = Date()
    private var animationStartedAt = Date()
    private var didComplete = false

    init(settings: ReminderSettings, onComplete: @escaping () -> Void) {
        self.entryDuration = settings.entrySeconds
        self.exitDuration = settings.exitSeconds
        self.autoConfirmSeconds = settings.autoConfirmSeconds
        self.onComplete = onComplete

        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        self.screenFrame = screenFrame
        self.windowSize = NSSize(width: min(760, max(520, screenFrame.width - 48)), height: 164)

        let initialFrame = Self.windowFrame(
            screenFrame: screenFrame,
            windowSize: windowSize,
            phase: .entering,
            progress: 0
        )
        reminderView = PlaneReminderView(frame: NSRect(origin: .zero, size: windowSize))
        reminderView.message = settings.message
        reminderView.confirmText = settings.confirmText

        window = NSWindow(
            contentRect: initialFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.backgroundColor = .clear
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isOpaque = false
        window.level = .floating
        window.contentView = reminderView

        reminderView.onConfirm = { [weak self] in
            self?.confirmAndExit()
        }
    }

    func show() {
        phase = .entering
        phaseStartedAt = Date()
        animationStartedAt = phaseStartedAt
        reminderView.phase = .entering
        reminderView.phaseProgress = 0
        reminderView.isWaitingForConfirmation = false
        window.ignoresMouseEvents = true
        stopMouseCaptureTimer()
        updateWindowFrame(progress: 0)
        window.orderFrontRegardless()
        animationTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0 / 60.0,
            repeats: true
        ) { [weak self] _ in
            self?.tick()
        }
    }

    func close() {
        complete()
    }

    private func tick() {
        let now = Date()
        let phaseElapsed = now.timeIntervalSince(phaseStartedAt)
        reminderView.animationClock = CGFloat(now.timeIntervalSince(animationStartedAt))

        switch phase {
        case .entering:
            let progress = min(1, phaseElapsed / entryDuration)
            reminderView.phase = .entering
            reminderView.phaseProgress = CGFloat(progress)
            updateWindowFrame(progress: CGFloat(progress))

            if progress >= 1 {
                beginWaiting()
            }
        case .waiting:
            reminderView.phase = .waiting
            reminderView.phaseProgress = 1
            updateWindowFrame(progress: 1)
        case .exiting:
            let progress = min(1, phaseElapsed / exitDuration)
            reminderView.phase = .exiting
            reminderView.phaseProgress = CGFloat(progress)
            updateWindowFrame(progress: CGFloat(progress))

            if progress >= 1 {
                complete()
            }
        }
    }

    private func beginWaiting() {
        guard phase == .entering else {
            return
        }

        phase = .waiting
        phaseStartedAt = Date()
        reminderView.phase = .waiting
        reminderView.phaseProgress = 1
        reminderView.isWaitingForConfirmation = true
        updateWindowFrame(progress: 1)
        startMouseCaptureTimer()

        if let autoConfirmSeconds {
            autoConfirmTimer?.invalidate()
            autoConfirmTimer = Timer.scheduledTimer(withTimeInterval: autoConfirmSeconds, repeats: false) { [weak self] _ in
                self?.confirmAndExit()
            }
        }
    }

    private func confirmAndExit() {
        guard phase == .waiting else {
            return
        }

        autoConfirmTimer?.invalidate()
        autoConfirmTimer = nil
        phase = .exiting
        phaseStartedAt = Date()
        reminderView.phase = .exiting
        reminderView.phaseProgress = 0
        reminderView.isWaitingForConfirmation = false
        window.ignoresMouseEvents = true
        stopMouseCaptureTimer()
        updateWindowFrame(progress: 0)
    }

    private func startMouseCaptureTimer() {
        mouseCaptureTimer?.invalidate()
        updateMouseCapture()
        mouseCaptureTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.updateMouseCapture()
        }
    }

    private func stopMouseCaptureTimer() {
        mouseCaptureTimer?.invalidate()
        mouseCaptureTimer = nil
        window.ignoresMouseEvents = true
    }

    private func updateMouseCapture() {
        guard phase == .waiting, let buttonRect = reminderView.confirmButtonScreenRect() else {
            window.ignoresMouseEvents = true
            return
        }

        window.ignoresMouseEvents = !buttonRect.insetBy(dx: -12, dy: -12).contains(NSEvent.mouseLocation)
    }

    private func updateWindowFrame(progress: CGFloat) {
        let frame = Self.windowFrame(
            screenFrame: screenFrame,
            windowSize: windowSize,
            phase: phase,
            progress: progress
        )
        window.setFrame(frame, display: true)
    }

    private static func windowFrame(
        screenFrame: NSRect,
        windowSize: NSSize,
        phase: AnimationPhase,
        progress: CGFloat
    ) -> NSRect {
        let eased = easeInOutCubic(progress)
        let centerX = screenFrame.midX - windowSize.width / 2
        let startX = screenFrame.minX - windowSize.width - 24
        let endX = screenFrame.maxX + 24
        let topOffset = min(max(screenFrame.height * 0.22, 110), 230)
        let y = screenFrame.maxY - topOffset - windowSize.height
        let x: CGFloat

        switch phase {
        case .entering:
            x = startX + (centerX - startX) * eased
        case .waiting:
            x = centerX
        case .exiting:
            x = centerX + (endX - centerX) * eased
        }

        return NSRect(x: x, y: y, width: windowSize.width, height: windowSize.height)
    }

    private func complete() {
        guard !didComplete else {
            return
        }
        didComplete = true
        autoConfirmTimer?.invalidate()
        autoConfirmTimer = nil
        stopMouseCaptureTimer()
        animationTimer?.invalidate()
        animationTimer = nil
        window.orderOut(nil)
        onComplete()
    }
}

enum PlaneReminderPhase {
    case entering
    case waiting
    case exiting
}

final class FirstMouseButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

final class PlaneReminderView: NSView {
    var phase: PlaneReminderPhase = .entering {
        didSet {
            needsDisplay = true
        }
    }

    var phaseProgress: CGFloat = 0 {
        didSet {
            needsDisplay = true
        }
    }

    var animationClock: CGFloat = 0 {
        didSet {
            needsDisplay = true
        }
    }

    var isWaitingForConfirmation = false {
        didSet {
            confirmButton.isHidden = !isWaitingForConfirmation
            needsLayout = true
            needsDisplay = true
        }
    }

    var message = "太辛苦了！快去喝水！"
    var confirmText = "知道了" {
        didSet {
            updateConfirmButtonTitle()
            needsLayout = true
        }
    }
    var onConfirm: (() -> Void)?
    private let confirmButton = FirstMouseButton(frame: .zero)

    override var isFlipped: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureConfirmButton()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureConfirmButton()
    }

    override func layout() {
        super.layout()
        confirmButton.frame = confirmButtonFrame()
    }

    func confirmButtonScreenRect() -> NSRect? {
        guard isWaitingForConfirmation, let window else {
            return nil
        }

        return window.convertToScreen(confirmButton.convert(confirmButton.bounds, to: nil))
    }

    private func configureConfirmButton() {
        confirmButton.isHidden = true
        confirmButton.isBordered = false
        confirmButton.wantsLayer = true
        confirmButton.layer?.backgroundColor = NSColor(calibratedRed: 0.12, green: 0.45, blue: 0.82, alpha: 0.96).cgColor
        confirmButton.layer?.cornerRadius = 18
        confirmButton.target = self
        confirmButton.action = #selector(confirmButtonPressed)
        updateConfirmButtonTitle()
        addSubview(confirmButton)
    }

    private func updateConfirmButtonTitle() {
        confirmButton.attributedTitle = NSAttributedString(
            string: confirmText,
            attributes: [
                .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
                .foregroundColor: NSColor.white,
            ]
        )
    }

    @objc private func confirmButtonPressed(_ sender: NSButton) {
        onConfirm?()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard bounds.width > 0, bounds.height > 0 else {
            return
        }

        confirmButton.isHidden = !isWaitingForConfirmation
        let layout = drawingLayout()

        drawTowLine(from: layout.towStart, to: layout.towEnd)
        drawBanner(origin: layout.bannerOrigin, width: layout.bannerWidth)
        drawAirplane(origin: layout.planeOrigin)
    }

    private func drawingLayout() -> (
        bannerOrigin: CGPoint,
        bannerWidth: CGFloat,
        planeOrigin: CGPoint,
        towStart: CGPoint,
        towEnd: CGPoint
    ) {
        let planeWidth: CGFloat = 152
        let towGap: CGFloat = 34
        let horizontalInset: CGFloat = 30
        let maxBannerWidth = max(320, bounds.width - planeWidth - towGap - horizontalInset * 2)
        let bannerWidth = currentBannerWidth(maxWidth: maxBannerWidth)
        let groupWidth = bannerWidth + towGap + planeWidth
        let groupX = max(horizontalInset, (bounds.width - groupWidth) / 2)
        let bob = phase == .waiting ? 0 : sin(animationClock * 1.8) * 2.5
        let baseY = 24 + bob
        let bannerOrigin = CGPoint(x: groupX, y: baseY + 18)
        let planeOrigin = CGPoint(x: groupX + bannerWidth + towGap, y: baseY)
        let towStart = CGPoint(x: bannerOrigin.x + bannerWidth + 10, y: bannerOrigin.y + 30)
        let towEnd = CGPoint(x: planeOrigin.x + 8, y: planeOrigin.y + 50)

        return (bannerOrigin, bannerWidth, planeOrigin, towStart, towEnd)
    }

    private func currentBannerWidth(maxWidth: CGFloat) -> CGFloat {
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 22, weight: .semibold),
        ]
        let textSize = message.size(withAttributes: textAttributes)
        return min(maxWidth, max(340, textSize.width + 72))
    }

    private func confirmButtonFrame() -> NSRect {
        let layout = drawingLayout()
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
        ]
        let textSize = confirmText.size(withAttributes: textAttributes)
        let width = max(96, textSize.width + 38)

        return NSRect(
            x: layout.bannerOrigin.x + layout.bannerWidth / 2 - width / 2,
            y: layout.bannerOrigin.y + 72,
            width: width,
            height: 36
        )
    }

    private func drawAirplane(origin: CGPoint) {
        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        context.saveGState()
        context.translateBy(x: origin.x + 76, y: origin.y + 48)
        context.rotate(by: sin(animationClock * 1.8) * 0.035)
        context.translateBy(x: -76, y: -48)

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.12)
        shadow.shadowBlurRadius = 10
        shadow.shadowOffset = CGSize(width: 0, height: 3)
        shadow.set()

        NSColor(calibratedRed: 0.90, green: 0.97, blue: 1.0, alpha: 1).setFill()
        let body = NSBezierPath()
        body.move(to: CGPoint(x: 24, y: 47))
        body.curve(
            to: CGPoint(x: 122, y: 30),
            controlPoint1: CGPoint(x: 50, y: 28),
            controlPoint2: CGPoint(x: 96, y: 28)
        )
        body.curve(
            to: CGPoint(x: 146, y: 48),
            controlPoint1: CGPoint(x: 136, y: 30),
            controlPoint2: CGPoint(x: 146, y: 38)
        )
        body.curve(
            to: CGPoint(x: 122, y: 66),
            controlPoint1: CGPoint(x: 146, y: 58),
            controlPoint2: CGPoint(x: 136, y: 66)
        )
        body.curve(
            to: CGPoint(x: 24, y: 56),
            controlPoint1: CGPoint(x: 92, y: 66),
            controlPoint2: CGPoint(x: 50, y: 61)
        )
        body.curve(
            to: CGPoint(x: 24, y: 47),
            controlPoint1: CGPoint(x: 17, y: 55),
            controlPoint2: CGPoint(x: 17, y: 49)
        )
        body.close()
        body.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSColor(calibratedRed: 0.19, green: 0.52, blue: 0.89, alpha: 1).setStroke()
        body.lineWidth = 2
        body.stroke()

        NSColor(calibratedRed: 0.12, green: 0.52, blue: 0.88, alpha: 1).setFill()
        let belly = NSBezierPath()
        belly.move(to: CGPoint(x: 39, y: 50))
        belly.curve(
            to: CGPoint(x: 122, y: 53),
            controlPoint1: CGPoint(x: 62, y: 56),
            controlPoint2: CGPoint(x: 94, y: 57)
        )
        belly.curve(
            to: CGPoint(x: 122, y: 63),
            controlPoint1: CGPoint(x: 127, y: 56),
            controlPoint2: CGPoint(x: 127, y: 60)
        )
        belly.curve(
            to: CGPoint(x: 43, y: 58),
            controlPoint1: CGPoint(x: 98, y: 67),
            controlPoint2: CGPoint(x: 63, y: 64)
        )
        belly.curve(
            to: CGPoint(x: 39, y: 50),
            controlPoint1: CGPoint(x: 37, y: 56),
            controlPoint2: CGPoint(x: 36, y: 52)
        )
        belly.close()
        belly.fill()

        drawTail()
        drawWing()
        drawCockpit()
        drawPropeller(center: CGPoint(x: 146, y: 48))

        context.restoreGState()
    }

    private func drawPropeller(center: CGPoint) {
        NSColor(calibratedWhite: 1, alpha: 0.72).setFill()
        for index in 0..<4 {
            let angle = animationClock * .pi * 10 + CGFloat(index) * .pi / 2
            let transform = NSAffineTransform()
            transform.translateX(by: center.x, yBy: center.y)
            transform.rotate(byRadians: angle)
            transform.translateX(by: -center.x, yBy: -center.y)

            let blade = NSBezierPath(ovalIn: NSRect(x: center.x - 4, y: center.y - 24, width: 8, height: 22))
            blade.transform(using: transform as AffineTransform)
            blade.fill()
        }

        NSColor(calibratedRed: 0.20, green: 0.48, blue: 0.80, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10)).fill()
    }

    private func drawCockpit() {
        NSColor(calibratedRed: 1, green: 0.88, blue: 0.38, alpha: 1).setFill()
        let cockpit = NSBezierPath(roundedRect: NSRect(x: 88, y: 31, width: 28, height: 15), xRadius: 8, yRadius: 8)
        cockpit.fill()
    }

    private func drawTail() {
        NSColor(calibratedRed: 0.45, green: 0.80, blue: 0.62, alpha: 1).setFill()
        let topTail = NSBezierPath()
        topTail.move(to: CGPoint(x: 30, y: 40))
        topTail.line(to: CGPoint(x: 8, y: 18))
        topTail.curve(to: CGPoint(x: 44, y: 41), controlPoint1: CGPoint(x: 26, y: 19), controlPoint2: CGPoint(x: 39, y: 29))
        topTail.close()
        topTail.fill()

        NSColor(calibratedRed: 0.24, green: 0.61, blue: 0.92, alpha: 1).setFill()
        let tail = NSBezierPath()
        tail.move(to: CGPoint(x: 31, y: 56))
        tail.line(to: CGPoint(x: 9, y: 75))
        tail.curve(to: CGPoint(x: 46, y: 59), controlPoint1: CGPoint(x: 27, y: 75), controlPoint2: CGPoint(x: 40, y: 67))
        tail.close()
        tail.fill()
    }

    private func drawWing() {
        NSColor(calibratedRed: 0.46, green: 0.82, blue: 0.68, alpha: 1).setFill()
        let upperWing = NSBezierPath()
        upperWing.move(to: CGPoint(x: 67, y: 42))
        upperWing.line(to: CGPoint(x: 94, y: 9))
        upperWing.curve(to: CGPoint(x: 115, y: 22), controlPoint1: CGPoint(x: 106, y: 9), controlPoint2: CGPoint(x: 116, y: 15))
        upperWing.line(to: CGPoint(x: 84, y: 51))
        upperWing.close()
        upperWing.fill()

        NSColor(calibratedRed: 0.30, green: 0.66, blue: 0.95, alpha: 1).setFill()
        let lowerWing = NSBezierPath()
        lowerWing.move(to: CGPoint(x: 66, y: 53))
        lowerWing.line(to: CGPoint(x: 100, y: 76))
        lowerWing.curve(to: CGPoint(x: 117, y: 63), controlPoint1: CGPoint(x: 112, y: 75), controlPoint2: CGPoint(x: 119, y: 69))
        lowerWing.line(to: CGPoint(x: 83, y: 47))
        lowerWing.close()
        lowerWing.fill()
    }

    private func drawTowLine(from start: CGPoint, to end: CGPoint) {
        NSColor(calibratedRed: 0.65, green: 0.72, blue: 0.77, alpha: 0.8).setStroke()
        let line = NSBezierPath()
        line.move(to: start)
        line.curve(
            to: end,
            controlPoint1: CGPoint(x: start.x + 16, y: start.y - 5),
            controlPoint2: CGPoint(x: end.x - 18, y: end.y + 5)
        )
        line.lineWidth = 1.6
        line.setLineDash([6, 5], count: 2, phase: 0)
        line.stroke()
    }

    private func drawBanner(origin: CGPoint, width: CGFloat) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byTruncatingTail

        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 22, weight: .semibold),
            .foregroundColor: NSColor(calibratedRed: 0.09, green: 0.24, blue: 0.45, alpha: 1),
            .paragraphStyle: paragraphStyle,
        ]
        let rect = NSRect(x: origin.x, y: origin.y, width: width, height: 58)

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.12)
        shadow.shadowBlurRadius = 10
        shadow.shadowOffset = CGSize(width: 0, height: 3)
        shadow.set()

        NSColor(calibratedWhite: 1, alpha: 0.97).setFill()
        let banner = NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12)
        banner.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSColor(calibratedRed: 0.86, green: 0.91, blue: 0.94, alpha: 1).setStroke()
        banner.lineWidth = 1.2
        banner.stroke()

        drawBannerPin(at: CGPoint(x: rect.minX + 18, y: rect.midY))
        drawBannerPin(at: CGPoint(x: rect.maxX - 18, y: rect.midY))

        let textRect = rect.insetBy(dx: 36, dy: 15)
        message.draw(in: textRect, withAttributes: textAttributes)
    }

    private func drawBannerPin(at point: CGPoint) {
        NSColor(calibratedRed: 0.82, green: 0.87, blue: 0.9, alpha: 1).setStroke()
        NSBezierPath(ovalIn: NSRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)).stroke()
    }

}

do {
    let settings = try ReminderSettings.parse(Array(CommandLine.arguments.dropFirst()))

    if settings.help {
        printHelp()
        exit(0)
    }

    if settings.dryRun {
        printDryRun(settings)
        exit(0)
    }

    if settings.once {
        runOverlayApp(settings: settings)
    } else {
        runRepeatingService(settings: settings)
    }
} catch {
    fputs("water-reminder: \(error)\n", stderr)
    fputs("Run with --help for usage.\n", stderr)
    exit(2)
}
