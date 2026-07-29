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

