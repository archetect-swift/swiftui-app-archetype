local context = Context.new()
local author  = require("author")
local license = require("license")
local scm     = require("scm")
local gitignore     = require("gitignore")
local editor_config = require("editor-config")

-- ── Prompts ─────────────────────────────────────────────────────────────
context:prompt_text("Project Name:", "project_name", {
    cases = Cases.programming(),
    help = "The project's canonical name.",
})

author.prompt(context)
license.prompt(context)
scm.prompt(context)

local repo_name = context:get("project-name")
context:set("repo_name", repo_name)
gitignore.prompt(context)
editor_config.prompt(context)

-- ── Render ──────────────────────────────────────────────────────────────
directory.render("contents", context)

-- ── Finalize ────────────────────────────────────────────────────────────
license.finalize(context, { destination = repo_name })
gitignore.finalize(context, { destination = repo_name })
editor_config.finalize(context, { destination = repo_name })
scm.finalize(context)
