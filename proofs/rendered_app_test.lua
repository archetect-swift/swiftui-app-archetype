-- The archetype's acceptance suite: render it, then drive the result the way
-- a developer would — through `just`. Asserting on the tree alone would let a
-- scaffold that does not compile pass, which is the failure mode that matters.

local workspace = require("prova.workspace")

local NAME = "Sample App"
local DIR = "sample-app"
local MODULE = "SampleApp"

-- One render, shared by every proof in this file. Rendering is the slow part;
-- the assertions are not.
local app = prova.fixture("rendered-app", Scope.File, function(ctx)
	local ws = workspace.create(ctx)
	shell.run({
		"archetect", "render", prova.root, ws.path,
		"-a", "project_name=" .. NAME,
		"-a", "organization_identifier=com.example",
		"-a", "minimum_macos=14",
		-- Answer these explicitly rather than letting the author library fall
		-- back to ~/.gitconfig. A proof that reads the developer's identity
		-- passes on a laptop and fails on a clean runner, which is exactly how
		-- this suite first went red in CI.
		"-a", "author_name=Proof Runner",
		"-a", "author_email=proofs@example.com",
		"-D",
	}, { timeout = "300s", check = true })
	return ws.path .. "/" .. DIR
end)

prova.test("renders the layered SwiftPM + Xcode layout", {
	proves = "the split is the point: Core has no SwiftUI so it stays testable headlessly, "
		.. "UI depends on Core and never the reverse, and the .app shell lives outside the "
		.. "package so `swift test` needs no Xcode.",
}, function(t)
	local root = t:use(app)

	for _, relative in ipairs({
		"Package.swift",
		"project.yml",
		"justfile",
		"README.md",
		"Sources/" .. MODULE .. "Core/AppInfo.swift",
		"Sources/" .. MODULE .. "Core/GreetingService.swift",
		"Sources/" .. MODULE .. "UI/AppModel.swift",
		"Sources/" .. MODULE .. "UI/RootView.swift",
		"Sources/" .. MODULE .. "UI/SettingsView.swift",
		"App/" .. MODULE .. "App.swift",
		"Tests/" .. MODULE .. "CoreTests/GreetingServiceTests.swift",
		"Tests/" .. MODULE .. "UITests/AppModelTests.swift",
	}) do
		t:expect(fs.exists(root .. "/" .. relative), relative):equals(true)
	end
end)

prova.test("names the repo in kebab and the modules in Pascal", {
	proves = "one prompt drives both conventions. Getting this wrong produces a package that "
		.. "compiles but whose module names read as an accident.",
}, function(t)
	local root = t:use(app)
	local manifest = fs.read(root .. "/Package.swift")

	t:expect(manifest, "package is named in Pascal"):contains('name: "' .. MODULE .. '"')
	t:expect(manifest, "Core product"):contains('"' .. MODULE .. 'Core"')
	t:expect(manifest, "swift 6 language mode"):contains("swiftLanguageModes: [.v6]")
	t:expect(manifest, "deployment target flows from the prompt"):contains(".macOS(.v14)")
end)

prova.test("ignores build output and the generated Xcode project", {
	proves = "without these the first commit of every generated repo carries .build/ and a "
		.. "checked-in .xcodeproj — the exact thing project.yml exists to avoid. Needs "
		.. "gitignore-library >= v1.2; a stale cached `v1` tag fails here, and `-U` fixes it.",
}, function(t)
	local ignored = fs.read(t:use(app) .. "/.gitignore")
	t:expect(ignored, "SwiftPM build output"):contains(".build/")
	t:expect(ignored, "the generated Xcode project"):contains("*.xcodeproj/")
end)

prova.test("the generated package builds", {
	proves = "a scaffold that does not compile is worse than no scaffold — it costs the "
		.. "developer the time to discover it. Driven through `just` so the justfile is "
		.. "proven at the same time.",
}, function(t)
	local root = t:use(app)
	shell.run({ "just", "build" }, { cwd = root, timeout = "600s", check = true })
end)

prova.test("the generated tests pass", {
	proves = "the scaffold ships green. A generated project whose tests fail on the first run "
		.. "teaches every developer who sees it that red is normal.",
}, function(t)
	local root = t:use(app)
	local result = shell.run({ "just", "test" }, { cwd = root, timeout = "600s", check = true })
	t:expect(result.stdout .. result.stderr, "Swift Testing ran"):contains("Test run with")
end)

prova.test("xcodegen produces a project from project.yml", {
	proves = "the .xcodeproj is generated, never committed. If project.yml drifts out of sync "
		.. "with the package layout, this is where it surfaces.",
}, function(t)
	local root = t:use(app)
	shell.run({ "just", "xcodeproj" }, { cwd = root, timeout = "300s", check = true })
	t:expect(fs.exists(root .. "/" .. MODULE .. ".xcodeproj"), "project generated"):equals(true)
end)

prova.test("the .app bundle builds and signs ad-hoc", {
	proves = "project.yml correctness is only observable here — a package that compiles can "
		.. "still fail to produce a bundle. Ad-hoc signing means this passes on a fresh clone "
		.. "with no Apple Developer account, which is what keeps it runnable in CI.",
}, function(t)
	local root = t:use(app)
	local result = shell.run({ "just", "app" }, { cwd = root, timeout = "900s", check = true })
	t:expect(result.stdout .. result.stderr, "xcodebuild succeeded"):contains("BUILD SUCCEEDED")
end)

-- ── AX-driven proofs ────────────────────────────────────────────────────────────
--
-- These drive the RUNNING app through the Accessibility API rather than reading the
-- source. Source-reading would prove the identifiers were typed; only AX proves they
-- reach the accessibility tree, which is what a screen reader — and any UI
-- automation — actually consumes.
--
-- `requires = {"macos-ui"}` skips them where the driver is unavailable (CI, headless),
-- so they cost nothing there and hold the line on a dev machine.

local ui = require("macos-ui")

--- The rendered app, built into a bundle and launched. Scope.File so one launch
--- serves every AX proof below.
local running = prova.fixture("running-app", Scope.File, function(ctx)
	local root = ctx:use(app)
	shell.run({ "just", "app" }, { cwd = root, timeout = "900s", check = true })

	local settings = shell.run({
		"xcodebuild", "-project", MODULE .. ".xcodeproj", "-scheme", MODULE,
		"-configuration", "Debug", "-showBuildSettings",
	}, { cwd = root, timeout = "300s", check = true })
	local products = settings.stdout:match("BUILT_PRODUCTS_DIR = ([^\n]+)")
	assert(products, "could not locate BUILT_PRODUCTS_DIR")

	-- The product is named after the Xcode TARGET, not the display name: a project
	-- whose display name has a space still builds `SampleApp.app`.
	local bundle = (products:gsub("%s+$", "")) .. "/" .. MODULE .. ".app"
	local handle = ui.launch(ctx, { bundle = bundle })
	local window = handle:window({ title = NAME, normal = true })
	assert(window, "the app launched but presented no normal window")
	return window
end)

prova.test("the app's greeting reaches the accessibility tree", {
	proves = "identifiers in source only prove someone typed them. Reading the value back "
		.. "through AX proves it reaches the tree a screen reader consumes — and that the "
		.. "async load actually resolved, which a static check cannot see.",
	requires = { "macos-ui" },
}, function(t)
	local window = t:use(running)

	local greeting = window:wait_for("root.greeting.text", "10s")
	t:expect(greeting, "the greeting appears once loading resolves"):never():equals(nil)
	t:expect(ui.text_of(greeting), "it greets by name"):contains(NAME)
end)

prova.test("no control in the app is anonymous", {
	spec = "blocked on minion: the invariant works and currently reports the window's three "
		.. "traffic lights (close/minimize/zoom at y=188 with the window top at y=180, one "
		.. "carrying AXZoomWindow). Those are AppKit-owned chrome an app cannot label, and the "
		.. "correct discriminator is AXSubrole — which minion.window.elements does not return, "
		.. "so chrome is indistinguishable from a genuinely unlabelled app button. Add `subrole` "
		.. "to minion_core::ElementInfo + element_info_table, then exempt the standard chrome "
		.. "subroles and graduate this.",
	requires = { "macos-ui" },
}, function(t)
	ui.assert_no_anonymous_controls(t, t:use(running))
end)

prova.test("pressing Reload re-resolves the greeting", {
	proves = "the scaffold is drivable end to end — an AX press reaches the button, the "
		.. "async reload runs, and the tree settles back to a loaded greeting. This is the "
		.. "shape every downstream UI proof will copy.",
	requires = { "macos-ui" },
}, function(t)
	local window = t:use(running)
	t:expect(window:wait_for("root.reload.button", "10s"), "the reload button is reachable"):never():equals(nil)

	window:click("root.reload.button")

	local greeting = window:wait_for("root.greeting.text", "10s")
	t:expect(greeting, "the greeting is back after reloading"):never():equals(nil)
end)
