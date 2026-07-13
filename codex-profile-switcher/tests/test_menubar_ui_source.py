import unittest
from pathlib import Path


SWIFT_SOURCE = Path(__file__).resolve().parents[1] / "macos" / "CodexProfileMenuBar.swift"


class MenuBarUISourceTests(unittest.TestCase):
    def test_python_runtime_prefers_compatible_paths_before_inherited_gui_path(self):
        source = SWIFT_SOURCE.read_text()

        self.assertIn(
            'let defaultPath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"',
            source,
        )
        self.assertIn(
            'environment["PATH"] = [defaultPath, environment["PATH"]]',
            source,
        )
        self.assertNotIn(
            'environment["PATH"] = [environment["PATH"], defaultPath]',
            source,
        )

    def test_main_dashboard_uses_tabbed_analytics_layout(self):
        source = SWIFT_SOURCE.read_text()

        for symbol in [
            "DashboardSectionTab",
            "DashboardTabBarView",
            "DashboardAnalyticsPanelView",
            "QuotaOperationsPanelView",
            "UsageTrendAnalyticsPanelView",
        ]:
            self.assertIn(symbol, source)

    def test_popover_is_not_the_full_dashboard(self):
        source = SWIFT_SOURCE.read_text()
        controller_start = source.index("final class AccountManagerViewController")
        controller_end = source.index("\nfinal class AccountManagerView", controller_start + 1)
        controller_source = source[controller_start:controller_end]

        self.assertNotIn("AccountCardView(", controller_source)
        self.assertNotIn("ResetCreditsPanelView(", controller_source)
        self.assertNotIn("TokenDashboardView(", controller_source)

    def test_main_dashboard_surface_has_no_decorative_pattern(self):
        source = SWIFT_SOURCE.read_text()
        root_start = source.index("final class MainDashboardRootView")
        root_end = source.index("enum DashboardText", root_start)
        root_source = source[root_start:root_end]
        self.assertNotIn("drawPattern", root_source)
        self.assertNotIn("NSGradient", root_source)
        self.assertIn("NSVisualEffectView", root_source)

        popover_start = source.index("final class AccountManagerView")
        popover_end = source.index("final class ToolLogoView", popover_start)
        popover_source = source[popover_start:popover_end]
        self.assertNotIn("drawPattern", popover_source)
        self.assertNotIn("NSGradient", popover_source)

    def test_popover_actions_use_short_labels(self):
        source = SWIFT_SOURCE.read_text()
        self.assertIn("final class ActionRowView: NSButton", source)
        controller_start = source.index("final class AccountManagerViewController")
        controller_end = source.index("\nfinal class AccountManagerView", controller_start + 1)
        controller_source = source[controller_start:controller_end]
        self.assertIn('title: "面板"', controller_source)
        self.assertNotIn('title: "主面板"', controller_source)
        self.assertIn('return "重启"', controller_source)
        self.assertIn('return "接管"', controller_source)
        self.assertIn('return "打开"', controller_source)

    def test_dashboard_rankings_do_not_render_zero_index(self):
        source = SWIFT_SOURCE.read_text()
        self.assertNotIn("RankingRowView(index: 0", source)

    def test_popover_exposes_direct_profile_switching(self):
        source = SWIFT_SOURCE.read_text()
        controller_start = source.index("final class AccountManagerViewController")
        controller_end = source.index("\nfinal class AccountManagerView", controller_start + 1)
        controller_source = source[controller_start:controller_end]

        self.assertIn("PopoverProfileSwitcherView(", controller_source)
        self.assertIn("switchAction: switchAction", controller_source)
        self.assertIn("final class PopoverProfileSwitcherView", source)

    def test_main_dashboard_exposes_profile_switching(self):
        source = SWIFT_SOURCE.read_text()
        controller_start = source.index("final class MainDashboardViewController")
        build_start = source.index("    private func build()", controller_start)
        build_end = source.index("    private func selectedAnalyticsPanel", build_start)
        build_source = source[build_start:build_end]

        self.assertIn("AccountSwitcherStripView(", build_source)
        self.assertIn("AccountSwitcherStripView(", source)

    def test_popover_no_longer_has_secondary_pages(self):
        source = SWIFT_SOURCE.read_text()
        for legacy_symbol in [
            "enum ManagerPage",
            "currentPage",
            "setPageAction",
            "PageToggleView",
            "PageToggleButtonView",
        ]:
            self.assertNotIn(legacy_symbol, source)

    def test_main_dashboard_matches_codexu_window_size_contract(self):
        source = SWIFT_SOURCE.read_text()
        self.assertIn("width: 820, height: 720", source)
        self.assertIn("window.minSize = NSSize(width: 760, height: 620)", source)
        self.assertIn("window.maxSize = NSSize(width: 1180, height: 920)", source)

    def test_main_dashboard_document_tracks_clip_width_and_only_scrolls_vertically(self):
        source = SWIFT_SOURCE.read_text()
        controller_start = source.index("final class MainDashboardViewController")
        controller_end = source.index("final class MainDashboardRootView", controller_start)
        controller_source = source[controller_start:controller_end]

        self.assertIn("scrollView.hasHorizontalScroller = false", controller_source)
        self.assertIn("scrollView.horizontalScrollElasticity = .none", controller_source)
        self.assertIn(
            "document.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor)",
            controller_source,
        )
        self.assertNotIn(
            "document.widthAnchor.constraint(greaterThanOrEqualTo: scrollView.contentView.widthAnchor)",
            controller_source,
        )
        self.assertIn("DashboardFooterView(", controller_source)

    def test_main_dashboard_document_starts_at_visual_top(self):
        source = SWIFT_SOURCE.read_text()
        self.assertIn("final class FlippedDocumentView", source)
        self.assertIn("override var isFlipped: Bool { true }", source)
        controller_start = source.index("final class MainDashboardViewController")
        controller_end = source.index("final class MainDashboardRootView", controller_start)
        controller_source = source[controller_start:controller_end]
        self.assertIn("let document = FlippedDocumentView()", controller_source)

    def test_main_dashboard_uses_codexu_overview_order(self):
        source = SWIFT_SOURCE.read_text()
        controller_start = source.index("final class MainDashboardViewController")
        controller_end = source.index("final class MainDashboardRootView", controller_start)
        controller_source = source[controller_start:controller_end]

        overview_index = controller_source.index("CodexUOverviewSectionView(")
        switcher_index = controller_source.index("AccountSwitcherStripView(")
        tabs_index = controller_source.index("DashboardTabBarView(")
        self.assertLess(overview_index, switcher_index)
        self.assertLess(switcher_index, tabs_index)
        self.assertIn("CodexUResetCreditsProgressView", source)

    def test_swift_models_include_current_app_server_summary_fields(self):
        source = SWIFT_SOURCE.read_text()
        self.assertIn("let windowMinutes: Int?", source)
        self.assertIn("let longestRunningTurnSec: Int?", source)
        self.assertIn("let title: String?", source)
        self.assertIn("let description: String?", source)

    def test_popover_matches_codexu_width_and_avoids_text_icons(self):
        source = SWIFT_SOURCE.read_text()
        self.assertIn("static let popoverWidth: CGFloat = 380", source)
        self.assertNotIn('icon: "🚀"', source)

    def test_quota_dial_uses_codexu_blue_and_purple_roles(self):
        source = SWIFT_SOURCE.read_text()
        dial_start = source.index("final class QuotaDialView")
        dial_end = source.index("final class DailyUsageChartView", dial_start)
        dial_source = source[dial_start:dial_end]
        self.assertIn("QuotaWindowPresentation.windows", dial_source)
        self.assertIn("item.tint", dial_source)
        self.assertNotIn("AccountHealth(remaining:", dial_source)

    def test_tabs_use_neutral_codexu_selection_surface(self):
        source = SWIFT_SOURCE.read_text()
        button_start = source.index("final class DashboardTabButtonView")
        button_end = source.index("final class AccountSwitcherStripView", button_start)
        button_source = source[button_start:button_end]
        self.assertIn("DashboardSurface.selectedControlFill", button_source)
        self.assertNotIn("calibratedRed: 0.16", button_source)

    def test_account_switcher_uses_neutral_codexu_control_surfaces(self):
        source = SWIFT_SOURCE.read_text()
        strip_start = source.index("final class AccountSwitcherStripView")
        strip_end = source.index("final class UsageTrendAnalyticsPanelView", strip_start)
        strip_source = source[strip_start:strip_end]
        self.assertIn("DashboardSurface.controlFill", strip_source)
        self.assertIn("DashboardSurface.selectedControlFill", strip_source)
        self.assertNotIn("NSColor.systemGreen", strip_source)

    def test_account_switcher_preserves_short_profile_names_before_role_copy(self):
        source = SWIFT_SOURCE.read_text()
        pill_start = source.index("final class AccountSwitchPillView")
        pill_end = source.index("final class UsageTrendAnalyticsPanelView", pill_start)
        pill_source = source[pill_start:pill_end]
        self.assertIn(
            "name.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)",
            pill_source,
        )
        self.assertIn(
            "state.setContentCompressionResistancePriority(.required, for: .horizontal)",
            pill_source,
        )
        self.assertIn('isTaskProfile ? "最近"', pill_source)
        self.assertIn('isDesktopDefault ? "默认"', pill_source)

    def test_dashboard_text_and_quota_legends_use_semantic_label_colors(self):
        source = SWIFT_SOURCE.read_text()
        text_start = source.index("enum DashboardText")
        text_end = source.index("class GlassPanelView", text_start)
        text_source = source[text_start:text_end]
        self.assertIn("AppearanceTokens.label", text_source)
        self.assertIn("AppearanceTokens.label(alpha: alpha)", text_source)
        self.assertNotIn("label.alphaValue = alpha", text_source)
        self.assertNotIn("AppearanceTokens.label.withAlphaComponent(alpha)", text_source)
        self.assertNotIn("NSColor.black", text_source)

        dial_start = source.index("final class QuotaDialView")
        dial_end = source.index("final class DailyUsageChartView", dial_start)
        dial_source = source[dial_start:dial_end]
        self.assertIn("AppearanceTokens.label(alpha:", dial_source)
        self.assertNotIn("NSColor.black", dial_source)

    def test_popover_runtime_card_matches_codexu_three_column_summary(self):
        source = SWIFT_SOURCE.read_text()
        card_start = source.index("final class PopoverRuntimeSummaryView")
        card_end = source.index("final class PopoverProfileSwitcherView", card_start)
        card_source = source[card_start:card_end]
        self.assertIn("PopoverQuotaColumnView", card_source)
        self.assertIn("title: item.longLabel", card_source)
        self.assertIn('title: "今日 token"', card_source)
        self.assertNotIn("QuotaDialView", card_source)
        self.assertIn("QuotaWindowPresentation.windows", card_source)
        self.assertIn('title: "重置卡"', card_source)

    def test_quota_windows_are_labeled_from_window_minutes(self):
        source = SWIFT_SOURCE.read_text()
        start = source.index("struct QuotaWindowPresentation")
        end = source.index("enum DashboardSectionTab", start)
        presentation_source = source[start:end]
        self.assertIn("window.windowMinutes", presentation_source)
        self.assertIn("case 300:", presentation_source)
        self.assertIn('return "5h"', presentation_source)
        self.assertIn("case 10_080:", presentation_source)
        self.assertIn('return "7d"', presentation_source)
        self.assertIn("compactMap", presentation_source)
        self.assertIn("QuotaPalette.fiveHour", presentation_source)
        self.assertIn("QuotaPalette.sevenDay", presentation_source)

    def test_quota_dial_supports_a_single_weekly_ring(self):
        source = SWIFT_SOURCE.read_text()
        dial_start = source.index("final class QuotaDialView")
        dial_end = source.index("final class DailyUsageChartView", dial_start)
        dial_source = source[dial_start:dial_end]
        self.assertIn("QuotaWindowPresentation.windows", dial_source)
        self.assertIn("windows.count == 1", dial_source)
        self.assertNotIn("profile?.rateLimits.primary", dial_source)
        self.assertNotIn("profile?.rateLimits.secondary", dial_source)

    def test_account_sources_are_explicit_and_desktop_default_is_not_current_task(self):
        source = SWIFT_SOURCE.read_text()
        self.assertIn("struct ProfileRoles: Decodable", source)
        self.assertIn("let task: ProfileRole", source)
        self.assertIn("let desktop: ProfileRole", source)
        self.assertIn("let attribution: ProfileRole", source)
        self.assertIn('"最近活动任务（推断）"', source)
        self.assertIn('"桌面默认"', source)
        self.assertNotIn('"当前任务（推断）"', source)

        switcher_start = source.index("final class AccountSwitcherStripView")
        switcher_end = source.index("final class UsageTrendAnalyticsPanelView", switcher_start)
        switcher_source = source[switcher_start:switcher_end]
        self.assertNotIn('DashboardText.label("当前"', switcher_source)
        self.assertNotIn('isActive ? "当前"', switcher_source)

    def test_dynamic_appearance_tokens_refresh_layer_colors(self):
        source = SWIFT_SOURCE.read_text()
        self.assertNotIn("NSColor.labelColor.withAlphaComponent", source)
        self.assertIn("enum AppearanceTokens", source)
        self.assertIn("override func viewDidChangeEffectiveAppearance()", source)
        self.assertIn("AppearanceTokens.surface", source)
        self.assertIn("AppearanceTokens.control", source)
        self.assertIn("AppearanceTokens.label", source)
        self.assertIn("calibratedWhite: 0.98, alpha: 1.0", source)
        self.assertIn("calibratedWhite: 0.86, alpha: 1.0", source)

        root_start = source.index("final class MainDashboardRootView")
        root_end = source.index("enum DashboardText", root_start)
        root_source = source[root_start:root_end]
        self.assertNotIn("NSColor.windowBackgroundColor.withAlphaComponent", root_source)

        popover_start = source.index("final class AccountManagerView")
        popover_end = source.index("final class ToolLogoView", popover_start)
        popover_source = source[popover_start:popover_end]
        self.assertNotIn("NSColor.windowBackgroundColor.withAlphaComponent", popover_source)

    def test_global_theme_defaults_to_light_and_is_shared_by_window_and_popover(self):
        source = SWIFT_SOURCE.read_text()
        self.assertIn("final class ThemeController", source)
        self.assertIn('static let storageKey = "codexProfileSwitcher.theme"', source)
        self.assertIn('?? .light', source)
        self.assertIn("UserDefaults.standard.set", source)
        self.assertIn("NSApp.appearance =", source)
        self.assertIn("window.appearance = ThemeController.shared.appearance", source)
        self.assertIn("appearance = ThemeController.shared.appearance", source)
        self.assertIn("ThemeController.shared.apply()", source)

        main_header_start = source.index("    private func mainHeader(")
        main_header_end = source.index("    private func runtimeShortText()", main_header_start)
        self.assertIn("themeButton()", source[main_header_start:main_header_end])

        popover_header_start = source.index("    private func headerView()")
        popover_header_end = source.index("    private func trafficLights()", popover_header_start)
        self.assertIn("themeButton()", source[popover_header_start:popover_header_end])

    def test_popover_chrome_uses_semantic_dark_mode_colors(self):
        source = SWIFT_SOURCE.read_text()
        controller_start = source.index("final class AccountManagerViewController")
        header_start = source.index("    private func headerView()", controller_start)
        header_end = source.index("    private func trafficLights()", header_start)
        header_source = source[header_start:header_end]
        self.assertIn("NSColor.labelColor", header_source)
        self.assertIn("NSColor.secondaryLabelColor", header_source)
        self.assertNotIn("NSColor.black", header_source)
        self.assertNotIn("NSColor(calibratedRed:", header_source)

        pill_start = source.index("final class HeaderStatusPillView")
        pill_end = source.index("final class QuotaDialView", pill_start)
        pill_source = source[pill_start:pill_end]
        self.assertIn("NSColor.controlBackgroundColor", pill_source)
        self.assertIn("AppearanceTokens.label(alpha:", pill_source)
        self.assertNotIn("NSColor.black", pill_source)

        action_start = source.index("final class ActionRowView")
        action_source = source[action_start:]
        self.assertIn("NSColor.labelColor", action_source)
        self.assertIn("NSColor.tertiaryLabelColor", action_source)
        self.assertNotIn("NSColor.black", action_source)

    def test_profile_names_are_single_line_and_truncate_inside_fixed_layouts(self):
        source = SWIFT_SOURCE.read_text()
        boundaries = [
            ("final class DashboardQuotaFocusPanelView", "final class DashboardMetricGridView"),
            ("final class AccountMiniRowView", "final class ProjectRankingPanelView"),
            ("final class AccountQuotaRowView", "final class ResetCreditCompactStripView"),
            ("final class ResetCreditCompactStripView", "final class PopoverRuntimeSummaryView"),
        ]
        for start_symbol, end_symbol in boundaries:
            with self.subTest(component=start_symbol):
                start = source.index(start_symbol)
                end = source.index(end_symbol, start)
                component_source = source[start:end]
                self.assertIn(".byTruncatingMiddle", component_source)
                self.assertIn("maximumNumberOfLines = 1", component_source)

    def test_analytics_columns_derive_widths_from_the_current_panel(self):
        source = SWIFT_SOURCE.read_text()
        start = source.index("final class QuotaOperationsPanelView")
        end = source.index("class AnalyticsCardView", start)
        panel_source = source[start:end]
        self.assertIn("let availableWidth = width - 36 - 16", panel_source)
        self.assertIn("let leftWidth", panel_source)
        for fixed_width in ["width: 590", "width: 318", "width: 452", "width: 456"]:
            self.assertNotIn(fixed_width, panel_source)

    def test_account_quota_rows_size_names_and_bars_from_row_width(self):
        source = SWIFT_SOURCE.read_text()
        start = source.index("final class AccountQuotaRowView")
        end = source.index("final class ResetCreditCompactStripView", start)
        row_source = source[start:end]
        self.assertIn("let nameWidth", row_source)
        self.assertIn("let barWidth", row_source)
        self.assertNotIn("equalToConstant: 160", row_source)
        self.assertNotIn("width: 210", row_source)
        self.assertIn("QuotaWindowPresentation.windows", row_source)
        self.assertIn("item.tint", row_source)
        self.assertNotIn("AccountHealth(remaining:", row_source)

    def test_rankings_fit_six_rows_and_truncate_long_names(self):
        source = SWIFT_SOURCE.read_text()
        panel_start = source.index("final class DashboardAnalyticsPanelView")
        panel_end = source.index("class AnalyticsCardView", panel_start)
        panel_source = source[panel_start:panel_end]
        self.assertIn(".prefix(6)", panel_source)
        self.assertNotIn(".prefix(7)", panel_source)

        row_start = source.index("final class RankingRowView")
        row_end = source.index("final class DashboardTabBarView", row_start)
        row_source = source[row_start:row_end]
        self.assertIn(".byTruncatingMiddle", row_source)
        self.assertIn("maximumNumberOfLines = 1", row_source)

    def test_legacy_vertical_dashboard_components_are_removed(self):
        source = SWIFT_SOURCE.read_text()
        for legacy_class in [
            "final class OverviewDashboardView",
            "final class ResetCreditsPanelView",
            "final class AccountCardView",
            "final class TokenDashboardView",
            "final class AccountTokenCardView",
        ]:
            self.assertNotIn(legacy_class, source)


if __name__ == "__main__":
    unittest.main()
