local context = Context.new()
local author  = require("author")
local license = require("license")
local scm     = require("scm")
local gitignore     = require("gitignore")
local editor_config = require("editor-config")

-- ── Prompts ─────────────────────────────────────────────────────────────
context:prompt_text("Project Name:", "project_name", {
	cases = Cases.programming(),
	help = "The project's canonical name. Drives the repo directory (kebab) and the "
		.. "Swift module names (Pascal).",
})

context:prompt_text("Display Name:", "app_display_name", {
	default = Case.Title:apply(context:get("project_name")),
	help = "What the user sees: the menu bar title and Finder name.",
})

context:prompt_text("Organization Identifier:", "organization_identifier", {
	default = "com.example",
	help = "Reverse-DNS prefix. The bundle identifier becomes <organization>.<project-name>.",
})

context:prompt_select("Minimum macOS:", "minimum_macos", { "14", "15", "26" }, {
	default = "14",
	help = "14 (Sonoma) is the floor for the Observation framework, and keeps roughly "
		.. "three years of back-support. Raise it only when you need newer API.",
})

author.prompt(context)
license.prompt(context)
scm.prompt(context)

local repo_name = context:get("project-name")
context:set("repo_name", repo_name)
-- Swift covers SwiftPM and Xcode user state; XcodeGen is separate because
-- ignoring *.xcodeproj is only correct for projects that generate it — which
-- this one does.
gitignore.prompt(context, {
	default = { "Claude", "IDEA", "VSCode", "Vim", "macOS", "Swift", "XcodeGen" },
})
editor_config.prompt(context)

-- ── Derived ─────────────────────────────────────────────────────────────
-- SwiftPM wants the enum form (`.v14`); Xcode wants the version string
-- ("14.0"). Compute both here so neither template has to do arithmetic.
local macos = context:get("minimum_macos")
context:set("macos_platform", ".v" .. macos)
context:set("macos_deployment_target", macos .. ".0")
context:set("bundle_identifier", context:get("organization_identifier") .. "." .. repo_name)

-- ── Render ──────────────────────────────────────────────────────────────
directory.render("contents", context)

-- ── Finalize ────────────────────────────────────────────────────────────
license.finalize(context, { destination = repo_name })
gitignore.finalize(context, { destination = repo_name })
editor_config.finalize(context, { destination = repo_name })
scm.finalize(context)
