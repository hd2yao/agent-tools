import unittest
from pathlib import Path


SWIFT_SOURCE = Path(__file__).resolve().parents[1] / "macos" / "CodexProfileMenuBar.swift"


class MenuBarUISourceTests(unittest.TestCase):
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

    def test_main_dashboard_glass_keeps_text_readable(self):
        source = SWIFT_SOURCE.read_text()
        root_start = source.index("final class MainDashboardRootView")
        root_end = source.index("enum DashboardText", root_start)
        root_source = source[root_start:root_end]
        self.assertIn("alpha: 0.97", root_source)
        self.assertIn("alpha: 0.94", root_source)

        glass_start = source.index("class GlassPanelView")
        glass_end = source.index("final class DashboardHeroGridView", glass_start)
        glass_source = source[glass_start:glass_end]
        self.assertIn("withAlphaComponent(0.68)", glass_source)

    def test_popover_actions_use_short_labels(self):
        source = SWIFT_SOURCE.read_text()
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

    def test_main_dashboard_hero_exposes_profile_switching(self):
        source = SWIFT_SOURCE.read_text()
        controller_start = source.index("final class MainDashboardViewController")
        build_start = source.index("    private func build()", controller_start)
        build_end = source.index("    private func selectedAnalyticsPanel", build_start)
        build_source = source[build_start:build_end]

        self.assertIn("DashboardHeroGridView(payload: payload, width: contentWidth, switchAction: switchAction)", build_source)
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

    def test_main_dashboard_uses_horizontal_glass_shell(self):
        source = SWIFT_SOURCE.read_text()
        self.assertIn("width: 1160, height: 720", source)
        self.assertIn("private let contentWidth: CGFloat = 1080", source)
        self.assertIn("DashboardHeroGridView(payload: payload, width: contentWidth, switchAction: switchAction)", source)
        self.assertIn("DashboardMetricGridView(payload: payload, width:", source)

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
