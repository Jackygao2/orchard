import XCTest
import AppKit

/// Smoke suite: launches the app against the in-memory stub backend (via the
/// `--uitest-mock-backend` launch argument) and drives a few flows a user would meet.
/// Deliberately capped at a handful of high-signal flows — this is a smoke harness, not a
/// per-feature UI-test suite. Seeded identifiers come from `UITestSeed` in the app target.
final class OrchardUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchedApp(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["--uitest-mock-backend"] + extraArguments
        app.launchEnvironment["ORCHARD_UITEST_MOCK_BACKEND"] = "1"
        app.launch()
        app.activate()
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 15),
            "App should reach the foreground under the mock backend"
        )
        return app
    }

    /// The app now opens on the Dashboard; the container list lives under the Containers tab.
    /// Every flow below starts here so it doesn't depend on the launch default.
    ///
    /// Retry until the seeded row renders: selection can race a cold launch, and re-selecting
    /// the Containers tab is idempotent.
    private func openContainersTab(_ app: XCUIApplication) {
        let tab = app.buttons["sidebar-containers"]
        XCTAssertTrue(tab.waitForExistence(timeout: 20), "Containers sidebar tab should exist")
        for _ in 0..<5 {
            tab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
            if app.staticTexts["uitest-web"].waitForExistence(timeout: 5) { return }
        }
        XCTFail("Containers list did not render after selecting the Containers tab")
    }

    @MainActor
    func testGroupedResourceNavigation() throws {
        let app = launchedApp()
        for (tab, choice, search) in [
            ("images", "Builds", "search-builds"),
            ("volumes", "Mounts", "search-mounts"),
            ("networks", "DNS", "search-dns")
        ] {
            let button = app.buttons["sidebar-\(tab)"]
            XCTAssertTrue(button.waitForExistence(timeout: 20))
            button.click()
            let option = app.radioButtons[choice]
            XCTAssertTrue(option.waitForExistence(timeout: 10), "Missing \(choice)")
            option.click()
            XCTAssertTrue(app.descendants(matching: .any)[search].waitForExistence(timeout: 10), "Missing \(search)")
        }
    }

    @MainActor
    func testToolbarShowsRuntimeAndRunAction() throws {
        let app = launchedApp()
        XCTAssertTrue(app.descendants(matching: .any)["toolbar-runtime-status"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["toolbar-refresh"].exists)
        let run = app.buttons["toolbar-run-container"]
        XCTAssertTrue(run.exists)
        run.click()
        XCTAssertTrue(app.descendants(matching: .any)["run-container-image"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testPrimaryNavigationShortcuts() throws {
        let app = launchedApp()
        for (key, identifier) in [
            ("1", "overview-content"), ("2", "search-containers"),
            ("3", "search-compose"), ("4", "search-images"),
            ("5", "search-volumes"), ("6", "search-networks")
        ] {
            app.typeKey(key, modifierFlags: .command)
            XCTAssertTrue(app.descendants(matching: .any)[identifier].waitForExistence(timeout: 10),
                          "Command-\(key) did not open \(identifier)")
        }
    }

    @MainActor
    func testPrimarySidebarHasAccessibilityActions() throws {
        let app = launchedApp()
        app.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(app.descendants(matching: .any)["overview-content"].waitForExistence(timeout: 10))
        var sidebarIssues: [String] = []
        try app.performAccessibilityAudit(for: .action) { issue in
            let identifier = issue.element?.identifier ?? ""
            if identifier.hasPrefix("sidebar-") || identifier.isEmpty {
                sidebarIssues.append("\(identifier): \(issue.compactDescription)")
            }
            // Other controls are covered by the wider audit, not this focused regression.
            return true
        }
        XCTAssertTrue(sidebarIssues.isEmpty, sidebarIssues.joined(separator: ", "))
    }

    @MainActor
    func testPrimarySearchFieldsHaveAccessibleNames() throws {
        let app = launchedApp()
        for (key, identifier, name) in [
            ("2", "search-containers", "Search containers"),
            ("3", "search-compose", "Search compose projects"),
            ("4", "search-images", "Search images"),
            ("5", "search-volumes", "Search volumes"),
            ("6", "search-networks", "Search networks")
        ] {
            app.typeKey(key, modifierFlags: .command)
            let field = app.textFields[identifier]
            XCTAssertTrue(field.waitForExistence(timeout: 10), identifier)
            XCTAssertEqual(field.label, name)
        }
    }

    @MainActor
    func testSearchShortcutFocusesToolbar() throws {
        let app = launchedApp()
        openContainersTab(app)
        app.typeKey("f", modifierFlags: .command)
        app.typeText("uitest")
        let search = app.descendants(matching: .any)["toolbar-search"]
        XCTAssertEqual(search.value as? String, "uitest")
    }

    @MainActor
    func testSelectedContainerShortcuts() throws {
        let app = launchedApp()
        openContainersTab(app)
        app.typeKey("t", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["UI test: terminal requested for uitest-web"].waitForExistence(timeout: 10))
        app.buttons["OK"].click()
        app.typeKey("l", modifierFlags: .command)
        XCTAssertTrue(app.windows.element(boundBy: 1).waitForExistence(timeout: 10))
    }

    @MainActor
    func testDeleteShortcutAsksBeforeRemovingStoppedContainer() throws {
        let app = launchedApp()
        openContainersTab(app)
        app.staticTexts["uitest-db"].click()
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 10), "Stopped container's Delete action should be visible")
        app.typeKey(XCUIKeyboardKey.delete, modifierFlags: .command)
        let confirmation = app.sheets.firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 10))
        XCTAssertTrue(confirmation.staticTexts.containing(NSPredicate(format: "value CONTAINS 'uitest-db'")).firstMatch.exists)
        confirmation.buttons["Cancel"].click()
        XCTAssertTrue(app.staticTexts["uitest-db"].exists)
    }

    @MainActor
    func testDeleteConfirmationDismissesWithEscape() throws {
        let app = launchedApp()
        openContainersTab(app)
        app.staticTexts["uitest-db"].click()
        app.typeKey(XCUIKeyboardKey.delete, modifierFlags: .command)
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 10))
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        XCTAssertFalse(app.sheets.firstMatch.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["uitest-db"].exists)
    }

    @MainActor
    func testContainerRowsExposeStatusAndSelectAllShortcut() throws {
        let app = launchedApp()
        openContainersTab(app)
        let running = app.descendants(matching: .outlineRow)
            .containing(.staticText, identifier: "uitest-web").firstMatch
        XCTAssertTrue(running.waitForExistence(timeout: 10))
        XCTAssertTrue(running.images["Container status: running"].exists)
        XCTAssertFalse(running.images["Depth Effect"].exists)
        app.typeKey("a", modifierFlags: .command)
        XCTAssertTrue(running.isSelected)
        let stopped = app.descendants(matching: .outlineRow)
            .containing(.staticText, identifier: "uitest-db").firstMatch
        XCTAssertTrue(stopped.isSelected)
    }

    @MainActor
    func testResourceSelectAllShortcutsRemainAvailable() throws {
        let app = launchedApp()
        for (key, identifier, rowName) in [
            ("4", "search-images", "uitest-nginx"),
            ("6", "search-networks", "uitest-net")
        ] {
            app.typeKey(key, modifierFlags: .command)
            XCTAssertTrue(app.descendants(matching: .any)[identifier].waitForExistence(timeout: 10))
            let row = app.descendants(matching: .outlineRow)
                .containing(.staticText, identifier: rowName).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 10), rowName)
            app.typeKey("a", modifierFlags: .command)
            XCTAssertTrue(row.isSelected, rowName)
        }
    }

    @MainActor
    func testImageDetailsRemainReadableInNarrowWindow() throws {
        let app = launchedApp()
        app.typeKey("4", modifierFlags: .command)
        XCTAssertTrue(app.descendants(matching: .any)["search-images"].waitForExistence(timeout: 10))
        let window = app.windows.firstMatch
        let corner = window.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1))
        let narrower = window.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 1))
        corner.press(forDuration: 0.2, thenDragTo: narrower)
        let reference = app.staticTexts.matching(NSPredicate(format: "value CONTAINS %@", "docker.io/library/uitest-nginx")).firstMatch
        XCTAssertTrue(reference.waitForExistence(timeout: 10))
        XCTAssertGreaterThan(reference.frame.width, 20, "Image reference should not collapse to a one-point column")
        let hostname = app.staticTexts["Hostname"].firstMatch
        XCTAssertTrue(hostname.waitForExistence(timeout: 10))
        XCTAssertGreaterThan(hostname.frame.width, 20, "The container table should retain readable columns")
    }

    @MainActor
    func testToolbarRefreshAndCommandPalette() throws {
        let app = launchedApp()
        let status = app.descendants(matching: .any)["toolbar-runtime-status"]
        XCTAssertTrue(status.waitForExistence(timeout: 20))
        status.click()
        XCTAssertTrue(app.menuItems["Stop"].waitForExistence(timeout: 5))
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        let refresh = app.buttons["toolbar-refresh"]
        XCTAssertTrue(refresh.waitForExistence(timeout: 20))
        refresh.click()
        app.typeKey("k", modifierFlags: .command)
        XCTAssertTrue(app.textFields["command-palette"].waitForExistence(timeout: 10))
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        XCTAssertTrue(refresh.exists)
    }

    @MainActor
    func testQuickActionOpensNetworkCreation() throws {
        let app = launchedApp()
        let actions = app.descendants(matching: .any)["toolbar-quick-actions"]
        XCTAssertTrue(actions.waitForExistence(timeout: 20))
        actions.click()
        app.menuItems["New Network"].click()
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 10))
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
    }

    @MainActor
    func testComposeOpenShortcutPresentsFileChooser() throws {
        let app = launchedApp()
        app.typeKey("o", modifierFlags: [.command, .shift])
        let panel = app.dialogs["open-panel"]
        XCTAssertTrue(panel.waitForExistence(timeout: 10))
        panel.buttons["Cancel"].click()
    }

    @MainActor
    func testAdvancedVisibilitySetting() throws {
        let app = launchedApp()
        let settings = app.buttons["sidebar-settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 20))
        settings.click()
        let general = app.buttons["General"]
        XCTAssertTrue(general.waitForExistence(timeout: 10))
        general.click()
        let toggle = app.descendants(matching: .any)["settings-show-advanced"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        guard let original = toggle.value as? Int else { return XCTFail("Advanced preference has no checkbox value") }
        if original != 1 { toggle.click() }
        defer { if (toggle.value as? Int) != original { toggle.click() } }
        toggle.click()
        XCTAssertFalse(app.buttons["sidebar-advanced"].exists)
        toggle.click()
        XCTAssertTrue(app.buttons["sidebar-advanced"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testAdvancedDestinationsAreReachable() throws {
        let app = launchedApp()
        let disclosure = app.buttons["sidebar-advanced"]
        XCTAssertTrue(disclosure.waitForExistence(timeout: 20))
        disclosure.click()
        for (tab, content) in [
            ("machines", "search-machines"), ("clusters", "search-clusters"),
            ("models", "advanced-models-content"), ("sandboxes", "advanced-sandboxes-content")
        ] {
            let row = app.buttons["sidebar-\(tab)"]
            XCTAssertTrue(row.waitForExistence(timeout: 10))
            row.click()
            XCTAssertTrue(app.descendants(matching: .any)[content].waitForExistence(timeout: 10),
                          "Advanced destination \(tab) did not render")
        }
    }

    @MainActor
    func testAdvancedListsHaveAccessibleNames() throws {
        let app = launchedApp()
        let disclosure = app.buttons["sidebar-advanced"]
        XCTAssertTrue(disclosure.waitForExistence(timeout: 20))
        disclosure.click()
        for (tab, listName) in [("machines", "Machines"), ("models", "Models")] {
            let row = app.buttons["sidebar-\(tab)"]
            XCTAssertTrue(row.waitForExistence(timeout: 10))
            row.click()
            XCTAssertTrue(app.outlines[listName].waitForExistence(timeout: 10), listName)
        }
    }

    @MainActor
    func testRegistryAndSystemLogSettings() throws {
        let app = launchedApp()
        let settings = app.buttons["sidebar-settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 20))
        settings.click()
        let registries = app.buttons["Registries"]
        XCTAssertTrue(registries.waitForExistence(timeout: 10))
        registries.click()
        XCTAssertTrue(app.windows["Registries"].waitForExistence(timeout: 10))
        app.buttons["System Logs"].click()
        XCTAssertTrue(app.windows["System Logs"].waitForExistence(timeout: 10))
    }

    /// The "#54 class" of bug: the app is up but everything is broken/empty — invisible to
    /// service unit tests. If the seeded container renders in the Containers list, launch +
    /// system-status + container list + the per-service environment injection all worked.
    @MainActor
    func testLaunchesAndRendersSeededContainers() throws {
        let app = launchedApp()
        openContainersTab(app)
        XCTAssertTrue(
            app.staticTexts["uitest-web"].waitForExistence(timeout: 20),
            "Seeded container should render in the Containers list"
        )
    }

    /// The auto-selected container's detail pane renders alongside the list — exercising
    /// ContainerDetail and its sub-services (stats/image sections, header actions). The detail
    /// header's Logs button is a stable element unique to the detail pane.
    @MainActor
    func testContainerDetailRenders() throws {
        let app = launchedApp()
        openContainersTab(app)
        XCTAssertTrue(app.staticTexts["uitest-web"].waitForExistence(timeout: 20))
        XCTAssertTrue(
            app.buttons["Logs"].waitForExistence(timeout: 10),
            "The selected container's detail pane (with its header actions) should render"
        )
    }

    @MainActor
    func testPublishedPortsAndUptimeAreVisible() throws {
        let app = launchedApp()
        openContainersTab(app)
        XCTAssertTrue(app.descendants(matching: .any)["container-uptime-uitest-web"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["open-port-127.0.0.1|8080|80|tcp"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["open-port-::1|9090|90|tcp"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["open-port-127.0.0.1|5353|53|udp"].exists)
        app.descendants(matching: .any)["container-uptime-uitest-web"].rightClick()
        XCTAssertTrue(app.descendants(matching: .any)["Open Port"].waitForExistence(timeout: 10))
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
    }

    @MainActor
    func testUptimeSortIsAvailable() throws {
        let app = launchedApp()
        openContainersTab(app)
        app.menuButtons["Sort"].click()
        let uptime = app.menuItems["Uptime"]
        XCTAssertTrue(uptime.waitForExistence(timeout: 10))
        uptime.click()
    }

    /// A long environment key must not push its own row's controls out of the pane: the key
    /// column is capped, so the key wraps and Show/Copy stay reachable. The seeded container
    /// carries `ORCHARD_UI_TEST_LONG_ENVIRONMENT_VARIABLE_KEY` for exactly this.
    @MainActor
    func testLongEnvironmentKeyKeepsItsRowControlsReachable() throws {
        let app = launchedApp()
        openContainersTab(app)
        XCTAssertTrue(app.staticTexts["uitest-web"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["Logs"].waitForExistence(timeout: 10))

        // Scroll from a point inside the detail pane rather than querying the SwiftUI
        // ScrollView: resolving that element asks XCTest to snapshot the whole detail
        // hierarchy, which is slow enough to time out. Wheel deltas also avoid the inertia
        // a synthetic swipe adds, and the normalised anchor holds at any window size.
        let detailPane = app.windows.firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.6))
        let toggle = app.buttons["environment-value-toggle-ORCHARD_UI_TEST_LONG_ENVIRONMENT_VARIABLE_KEY"]

        for _ in 0..<8 where !(toggle.exists && toggle.isHittable) {
            detailPane.scroll(byDeltaX: 0, deltaY: -150)
        }
        XCTAssertTrue(
            toggle.waitForExistence(timeout: 10),
            "The long environment key's value control should render after scrolling"
        )
        XCTAssertTrue(
            toggle.isHittable,
            "The value control beside a long environment key should remain onscreen and clickable"
        )

        // The label flips only once SwiftUI has re-rendered the row, so wait for it.
        toggle.click()
        let revealed = expectation(for: NSPredicate(format: "label == %@", "Hide"), evaluatedWith: toggle)
        wait(for: [revealed], timeout: 10)
    }

    @MainActor
    func testSecretValuesAreMaskedAndRevealResets() throws {
        let app = launchedApp()
        openContainersTab(app)
        let detail = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.6))
        let toggle = app.buttons["environment-value-toggle-MIXED_secret"]
        for _ in 0..<8 where !(toggle.exists && toggle.isHittable) {
            detail.scroll(byDeltaX: 0, deltaY: -150)
        }
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["fixture-private-value"].exists)
        XCTAssertTrue(app.staticTexts["fixture-visible-value"].exists)
        XCTAssertFalse(app.staticTexts["PASSWORDfixture-malformed-private"].exists)
        toggle.click()
        XCTAssertTrue(app.staticTexts["fixture-private-value"].waitForExistence(timeout: 5))
        app.staticTexts["uitest-db"].firstMatch.click()
        app.staticTexts["uitest-web"].firstMatch.click()
        XCTAssertFalse(app.staticTexts["fixture-private-value"].exists)
    }

    @MainActor
    func testRunFormDisclosesHostMountGuidance() throws {
        let app = launchedApp()
        let run = app.buttons["toolbar-run-container"]
        XCTAssertTrue(run.waitForExistence(timeout: 20))
        run.click()
        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 10))
        XCTAssertTrue(sheet.descendants(matching: .any)["run-container-image"].exists)
        XCTAssertTrue(sheet.descendants(matching: .any)["container-name"].exists)
        XCTAssertTrue(sheet.buttons["container-add-port"].exists)
        let scroll = sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.65))
        let more = sheet.descendants(matching: .any)["container-more-options"]
        for _ in 0..<8 where !(more.exists && more.isHittable) {
            scroll.scroll(byDeltaX: 0, deltaY: -180)
        }
        XCTAssertTrue(sheet.buttons["container-add-environment"].exists)
        XCTAssertTrue(more.waitForExistence(timeout: 10))
        XCTAssertFalse(sheet.buttons["container-add-mount"].exists)
        more.click()
        let addMount = sheet.buttons["container-add-mount"]
        for _ in 0..<8 where !(addMount.exists && addMount.isHittable) {
            scroll.scroll(byDeltaX: 0, deltaY: -180)
        }
        XCTAssertTrue(addMount.waitForExistence(timeout: 10))
        addMount.click()
        let note = sheet.descendants(matching: .any)["host-mount-security-note"]
        for _ in 0..<5 where !(note.exists && note.isHittable) {
            scroll.scroll(byDeltaX: 0, deltaY: -120)
        }
        XCTAssertTrue(note.waitForExistence(timeout: 10))
        XCTAssertTrue(sheet.descendants(matching: .any)["mount-read-only"].exists)
    }

    @MainActor
    func testOverviewCountsAndRunAction() throws {
        let app = launchedApp()
        let overview = app.buttons["sidebar-dashboard"]
        XCTAssertTrue(overview.waitForExistence(timeout: 20))
        let running = app.descendants(matching: .any)["overview-running"]
        for _ in 0..<5 where !running.exists {
            overview.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
            if running.waitForExistence(timeout: 3) { break }
        }
        XCTAssertTrue(running.waitForExistence(timeout: 10))
        XCTAssertTrue(running.label.contains("1"))
        XCTAssertTrue(app.descendants(matching: .any)["overview-stopped"].label.contains("1"))
        XCTAssertTrue(app.descendants(matching: .any)["overview-images"].label.contains("1"))
        XCTAssertTrue(app.descendants(matching: .any)["overview-projects"].label.contains("0"))
        XCTAssertTrue(app.descendants(matching: .any)["overview-volumes"].label.contains("0"))
        app.buttons["overview-run"].click()
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 10))
        app.sheets.firstMatch.buttons["Cancel"].click()
        for _ in 0..<5 where !running.exists {
            overview.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
            if running.waitForExistence(timeout: 3) { break }
        }
        XCTAssertTrue(running.waitForExistence(timeout: 10))
        running.click()
        XCTAssertTrue(app.staticTexts["uitest-web"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testOverviewComposeAndPullActions() throws {
        let app = launchedApp()
        app.buttons["sidebar-dashboard"].click()
        let compose = app.buttons["overview-compose"]
        XCTAssertTrue(compose.waitForExistence(timeout: 10))
        compose.click()
        let panel = app.dialogs["open-panel"]
        XCTAssertTrue(panel.waitForExistence(timeout: 10))
        panel.buttons["Cancel"].click()
        app.buttons["overview-pull"].click()
        XCTAssertTrue(app.sheets.firstMatch.waitForExistence(timeout: 10))
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
    }

    @MainActor
    func testEditUsesTheSameBasicFirstForm() throws {
        let app = launchedApp()
        openContainersTab(app)
        app.staticTexts["uitest-db"].firstMatch.click()
        let edit = app.buttons["Edit Configuration"]
        XCTAssertTrue(edit.waitForExistence(timeout: 10))
        edit.click()
        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 10))
        XCTAssertTrue(sheet.descendants(matching: .any)["container-name"].exists)
        XCTAssertTrue(sheet.buttons["container-add-port"].exists)
        XCTAssertFalse(sheet.buttons["container-add-mount"].exists)
        sheet.buttons["Cancel"].click()
    }

    /// The #54 class: a failed user action must be visible. With the stub set to fail
    /// `stopContainer`, stopping the running container should surface the error alert.
    @MainActor
    func testFailedActionPresentsErrorAlert() throws {
        let app = launchedApp(extraArguments: ["--uitest-fail-stop"])
        openContainersTab(app)
        XCTAssertTrue(app.staticTexts["uitest-web"].waitForExistence(timeout: 20))

        let stop = app.buttons["Stop"]
        XCTAssertTrue(stop.waitForExistence(timeout: 10), "The running container's Stop button should render")
        stop.click()

        XCTAssertTrue(
            app.staticTexts["Something Went Wrong"].waitForExistence(timeout: 10),
            "A failed action should present the error alert"
        )
    }
    @MainActor
    func testComposeImportReviewRequiresAcknowledgement() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try """
        services:
          web:
            image: nginx
            restart: always
            user: "1000"
        """.write(to: directory.appendingPathComponent("compose.yaml"), atomically: true, encoding: .utf8)
        let app = launchedApp(extraArguments: ["--uitest-compose-review", directory.path, "--uitest-no-compose-plugin"])
        app.typeKey("3", modifierFlags: .command)
        let acknowledge = app.checkBoxes["compose-acknowledge"]
        XCTAssertTrue(acknowledge.waitForExistence(timeout: 20))
        let confirm = app.buttons["compose-confirm-import"]
        XCTAssertTrue(confirm.exists)
        XCTAssertFalse(confirm.isEnabled)
        XCTAssertTrue(app.descendants(matching: .any)["compose-finding-restart"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["compose-suggestion-user"].exists)
        acknowledge.click()
        XCTAssertTrue(confirm.isEnabled)
        app.buttons["Cancel"].click()
        XCTAssertTrue(app.buttons["Install"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testComposeDryRunShowsPlan() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try """
        name: uitest-plan
        services:
          web:
            image: nginx
        """.write(to: directory.appendingPathComponent("compose.yaml"), atomically: true, encoding: .utf8)
        let app = launchedApp(extraArguments: ["--uitest-compose-review", directory.path])
        app.typeKey("3", modifierFlags: .command)
        let add = app.buttons["compose-confirm-import"]
        XCTAssertTrue(add.waitForExistence(timeout: 20))
        add.click()
        let dryRun = app.buttons["compose-dry-run"]
        XCTAssertTrue(dryRun.waitForExistence(timeout: 20))
        dryRun.click()
        XCTAssertTrue(app.descendants(matching: .any)["compose-plan-operation-0"].waitForExistence(timeout: 20))
        app.buttons["Done"].click()
    }

    @MainActor
    func testComposeVolumeRemovalCancellation() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try "name: uitest-plan\nservices:\n  web:\n    image: nginx\n".write(to: directory.appendingPathComponent("compose.yaml"), atomically: true, encoding: .utf8)
        let app = launchedApp(extraArguments: ["--uitest-compose-review", directory.path, "--uitest-compose-volume"])
        app.typeKey("3", modifierFlags: .command)
        let add = app.buttons["compose-confirm-import"]
        XCTAssertTrue(add.waitForExistence(timeout: 20))
        add.click()
        let remove = app.buttons["Remove Volumes…"]
        XCTAssertTrue(remove.waitForExistence(timeout: 20))
        for _ in 0..<20 where !remove.isEnabled { sleep(1) }
        XCTAssertTrue(remove.isEnabled)
        remove.click()
        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 20))
        cancel.click()
        XCTAssertTrue(remove.waitForExistence(timeout: 10))
        remove.click()
        XCTAssertTrue(cancel.waitForExistence(timeout: 20))
        cancel.click()
    }

    @MainActor
    func testComposeVolumeDeleteCancellation() throws {
        let app = launchedApp(extraArguments: ["--uitest-compose-volume"])
        app.typeKey("5", modifierFlags: .command)
        let volume = app.staticTexts.matching(identifier: "uitest-plan_data").firstMatch
        XCTAssertTrue(volume.waitForExistence(timeout: 20))
        volume.click()
        let delete = app.buttons["Delete..."]
        XCTAssertTrue(delete.waitForExistence(timeout: 10))
        delete.click()
        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 10))
        cancel.click()
        XCTAssertTrue(volume.exists)
    }

    @MainActor
    func testImageRetryAndUnusedCleanup() throws {
        let app = launchedApp(extraArguments: ["--uitest-fail-pull"])
        app.buttons["sidebar-dashboard"].click()
        let pull = app.buttons["overview-pull"]
        XCTAssertTrue(pull.waitForExistence(timeout: 10))
        pull.click()
        let field = app.textFields["image-pull-reference"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.click()
        field.typeText("nginx:latest")
        app.buttons["Pull"].click()
        let retry = app.sheets.firstMatch.buttons["image-pull-retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 10))
        retry.click()
        XCTAssertTrue(retry.waitForExistence(timeout: 10))
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
        let cleanup = app.buttons["images-delete-unused"]
        XCTAssertTrue(cleanup.waitForExistence(timeout: 10))
        cleanup.click()
        XCTAssertTrue(app.staticTexts["Free Up Space"].waitForExistence(timeout: 10))
        app.buttons["Cancel"].click()
    }

    @MainActor
    func testCopyFilteredLogs() throws {
        let pasteboard = NSPasteboard.general
        let saved = (pasteboard.pasteboardItems ?? []).map { item -> NSPasteboardItem in
            let copy = NSPasteboardItem()
            for type in item.types { if let data = item.data(forType: type) { copy.setData(data, forType: type) } }
            return copy
        }
        defer { pasteboard.clearContents(); if !saved.isEmpty { pasteboard.writeObjects(saved) } }
        let app = launchedApp(extraArguments: ["--uitest-logs"])
        openContainersTab(app)
        app.staticTexts["uitest-web"].firstMatch.click()
        app.typeKey("l", modifierFlags: .command)
        let filter = app.textFields["logs-filter"].firstMatch
        XCTAssertTrue(filter.waitForExistence(timeout: 20))
        app.typeKey("f", modifierFlags: .command)
        app.typeText("second")
        XCTAssertEqual(filter.value as? String, "second")
        let copy = app.buttons["logs-copy"].firstMatch
        XCTAssertTrue(copy.waitForExistence(timeout: 20))
        for _ in 0..<10 where !copy.isEnabled { sleep(1) }
        XCTAssertTrue(copy.isEnabled)
        copy.click()
        XCTAssertEqual(pasteboard.string(forType: .string), "fixture second line")
    }

    @MainActor
    func testRunCommandInRunningContainer() throws {
        let app = launchedApp(extraArguments: ["--uitest-run-command"])
        openContainersTab(app)
        app.staticTexts["uitest-web"].firstMatch.click()
        let open = app.buttons["open-run-command"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        open.click()
        let input = app.textFields["run-command-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.click()
        input.typeText("echo 'hello world'")
        app.buttons["run-command-submit"].click()
        XCTAssertTrue(app.staticTexts["Exited with status 3."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["run-command-output"].waitForExistence(timeout: 10))
        app.buttons["Close"].click()
    }

    @MainActor
    func testOnboardingMissingRuntimeAndSkipPlugin() throws {
        let app = launchedApp(extraArguments: ["--uitest-onboarding", "missing"])
        app.buttons["onboarding-begin"].click()
        let install = app.buttons["onboarding-install"]
        XCTAssertTrue(install.waitForExistence(timeout: 10))
        install.click()
        let start = app.buttons["onboarding-start"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.click()
        let skip = app.buttons["onboarding-skip-plugin"]
        XCTAssertTrue(skip.waitForExistence(timeout: 10))
        skip.click()
        app.buttons["onboarding-finish"].click()
        XCTAssertTrue(app.descendants(matching: .any)["overview-content"].waitForExistence(timeout: 20))
    }

    @MainActor
    func testOnboardingBlocksDifferentMajor() throws {
        let app = launchedApp(extraArguments: ["--uitest-onboarding", "incompatible"])
        app.buttons["onboarding-begin"].click()
        XCTAssertTrue(app.staticTexts["Runtime version not supported"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["onboarding-start"].exists)
    }

    @MainActor
    func testOnboardingVersionWarningsAndStoppedRuntime() throws {
        for (seed, expected) in [("stopped", "onboarding-start"), ("older", "onboarding-continue-version"), ("newer", "onboarding-continue-version")] {
            let app = launchedApp(extraArguments: ["--uitest-onboarding", seed])
            let begin = app.buttons["onboarding-begin"]
            XCTAssertTrue(begin.waitForExistence(timeout: 10))
            begin.click()
            XCTAssertTrue(app.buttons[expected].waitForExistence(timeout: 10), "Missing state for \(seed)")
            app.terminate()
        }
    }

    @MainActor
    func testSettingsTabsAndSetupReentry() throws {
        let app = launchedApp()
        let settings = app.buttons["sidebar-settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 20))
        settings.click()
        for tab in ["General", "System", "Registries", "Acknowledgements", "Runtime"] {
            let button = app.buttons[tab]
            XCTAssertTrue(button.waitForExistence(timeout: 10), "Missing Settings tab \(tab)")
            button.click()
        }
        let rerun = app.buttons["settings-rerun-setup"]
        XCTAssertTrue(rerun.waitForExistence(timeout: 10))
        rerun.click()
        XCTAssertTrue(app.buttons["onboarding-begin"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testNoInAppUpdateMenu() throws {
        let app = launchedApp()
        let menu = app.menuBars.menuBarItems["ContainerDesk"]
        XCTAssertTrue(menu.waitForExistence(timeout: 15))
        menu.click()
        XCTAssertFalse(app.menuItems["Check for Updates…"].exists)
        app.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])
    }

    @MainActor
    func testAcknowledgementsAreReadable() throws {
        let app = launchedApp()
        let settings = app.buttons["sidebar-settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 20))
        settings.click()
        let tab = app.buttons["Acknowledgements"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.click()
        let notices = app.textViews["acknowledgements-notices"]
        XCTAssertTrue(notices.waitForExistence(timeout: 20))
        XCTAssertTrue((notices.value as? String ?? "").contains("Andrew Waters"))
    }

}
