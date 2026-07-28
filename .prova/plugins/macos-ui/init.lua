-- macos-ui — drive a bundled macOS app through the Accessibility API.
--
-- Two Lua runtimes are involved and it pays to keep them straight: proofs run in
-- PROVA's Lua, AX calls run inside MINIOND's Lua. `ax()` bridges them by shelling
-- `minion eval` and decoding what comes back.
--
-- The wire between them is JSON in both directions (`minion.json` on the far side,
-- prova's `json` here). An earlier driver hand-rolled a TAB/NEWLINE record protocol
-- because "Minion has no json" — that stopped being true, and the encoding went with
-- it. Values are never concatenated into injected source; `lit()` quotes them.
--
-- What belongs here: anything true of ANY macOS app. What does not: your app's
-- vocabulary, its hermetic state, its fixtures. Compose those on top.

local ui = {}

local MINION = os.getenv("MINION_BIN") or "minion"

--- Quote a Lua string literal for injection. Never build source by concatenating a
--- value — a title containing a quote or newline would otherwise rewrite the snippet.
---@param s string
local function lit(s)
	return string.format("%q", tostring(s))
end

--- Run Lua inside the live Minion daemon and return the decoded result.
--- The snippet must end in `return minion.json.encode(<value>)`.
---@param src string
local function ax(src)
	local ok, r = pcall(shell.run, { MINION, "eval", src })
	if not ok then
		error(
			("macos-ui: could not run `%s` — UI proofs need Minion installed and granted "
				.. "Accessibility (System Settings → Privacy & Security → Accessibility). %s"):format(
				MINION,
				tostring(r):gsub("\nstack traceback.*", "")
			),
			2
		)
	end
	if r.code ~= 0 then
		error(("macos-ui: minion eval failed: %s"):format(r.stderr ~= "" and r.stderr or r.stdout), 2)
	end
	local text = (r.stdout:gsub("%s+$", ""))
	if text == "" then
		return nil
	end
	local ok_decode, decoded = pcall(json.decode, text)
	if not ok_decode then
		error(("macos-ui: minion returned undecodable output %q (%s)"):format(text, tostring(decoded)), 2)
	end
	return decoded
end

--- Whether the AX driver is present AND granted. Checked before launching anything:
--- an ungranted Minion otherwise surfaces as "the element never appeared" several
--- seconds into an assertion, which tells you nothing about what is actually wrong.
function ui.available()
	local ok, count = pcall(ax, "return minion.json.encode(#minion.screen.windows())")
	return ok and type(count) == "number"
end

-- ── Window ──────────────────────────────────────────────────────────────────────

local Window = {}
Window.__index = Window

--- Every element in the window, flattened. Each carries `identifier`, `role`,
--- `label`, `title`, `enabled` and `actions` — enough to assert on, and enough to
--- act on. Absent AX attributes arrive as MISSING KEYS, not empty strings: Lua drops
--- nil on the way into JSON. Callers must test presence, not emptiness.
---@param opts? { depth?: integer }
function Window:elements(opts)
	opts = opts or {}
	local depth = opts.depth or 8
	return ax(([[
		local out = {}
		for _, e in ipairs(minion.window.elements(%d, { depth = %d })) do
			out[#out+1] = {
				identifier = e.identifier, role = e.role, label = e.label,
				title = e.title, value = e.value, enabled = e.enabled,
				actions = e.actions or {},
			}
		end
		return minion.json.encode(out)
	]]):format(self.id, depth))
end

--- What an element reads as, wherever macOS put it. Static text carries its content
--- in AXValue; a button carries it in AXTitle; a labelled control in AXDescription.
--- Callers asserting "it says X" should not have to know which.
---@param element table
function ui.text_of(element)
	if not element then
		return ""
	end
	return element.value or element.label or element.title or ""
end

--- The first element with this accessibility identifier, or nil.
---@param identifier string
function Window:element(identifier)
	for _, element in ipairs(self:elements()) do
		if element.identifier == identifier then
			return element
		end
	end
	return nil
end

--- Press an element by identifier. Never by coordinates: a coordinate-driven proof
--- passes until someone moves a button, where an identifier-driven one fails at the
--- rename — which is the entire point.
---@param identifier string
function Window:click(identifier)
	return ax(([[
		minion.window.click(%d, { identifier = %s })
		return minion.json.encode(true)
	]]):format(self.id, lit(identifier)))
end

---@param identifier string
---@param text string
function Window:type(identifier, text)
	return ax(([[
		minion.window.type(%d, { identifier = %s }, %s)
		return minion.json.encode(true)
	]]):format(self.id, lit(identifier), lit(text)))
end

--- Poll until an identifier is present. Returns the element, or nil on timeout.
---@param identifier string
---@param timeout? string
function Window:wait_for(identifier, timeout)
	local deadline = tonumber((timeout or "5s"):match("^(%d+)")) or 5
	for _ = 1, deadline * 5 do
		local element = self:element(identifier)
		if element then
			return element
		end
		shell.run({ "sh", "-c", "sleep 0.2" })
	end
	return nil
end

--- Poll until an identifier is ABSENT (or assert it never appears). The negative a
--- non-AX harness cannot make: "the UI stayed silent" is only observable from here.
---@param identifier string
---@param timeout? string
function Window:wait_absent(identifier, timeout)
	local deadline = tonumber((timeout or "3s"):match("^(%d+)")) or 3
	for _ = 1, deadline * 5 do
		if not self:element(identifier) then
			return true
		end
		shell.run({ "sh", "-c", "sleep 0.2" })
	end
	return false
end

-- ── App ─────────────────────────────────────────────────────────────────────────

local App = {}
App.__index = App

--- Resolve one of the app's windows.
---
--- `normal` matters more than it looks: a MenuBarExtra popover and an open Picker
--- menu are BOTH windows of the same app and neither is `normal`, so matching
--- without it silently drives the wrong surface.
---@param match? { title?: string, normal?: boolean, timeout?: string }
function App:window(match)
	match = match or {}
	local want_normal = match.normal ~= false
	local deadline = tonumber((match.timeout or "10s"):match("^(%d+)")) or 10

	for _ = 1, deadline * 5 do
		local windows = ax(("return minion.json.encode(minion.screen.windows(%s))"):format(lit(self.name)))
		for _, w in ipairs(windows or {}) do
			local normal_ok = (not want_normal) or w.normal
			local title_ok = (not match.title) or (w.title and w.title:find(match.title, 1, true) ~= nil)
			if normal_ok and title_ok then
				return setmetatable({ id = w.id, title = w.title, app = w.app }, Window)
			end
		end
		shell.run({ "sh", "-c", "sleep 0.2" })
	end
	return nil
end

function App:quit()
	shell.run({ "osascript", "-e", ('quit app "%s"'):format(self.name) })
end

--- Launch a bundled app and wait until it is drivable.
---
--- Requires a real `.app`, not the bare SwiftPM executable: macOS does not treat a
--- loose Mach-O as a GUI application — launched directly it runs and shows nothing,
--- silently. Bundling is a build step, not packaging polish.
---
--- Launches through LaunchServices (`open`) rather than exec'ing the binary, so the
--- harness exercises the same path a user does: activation, Dock/Spaces behaviour,
--- one instance per `-n`.
---@param ctx prova.Context
---@param opts { bundle: string, env?: table<string,string>, timeout?: string }
function ui.launch(ctx, opts)
	opts = opts or {}
	local bundle = opts.bundle or error("macos-ui.launch: pass { bundle = '/path/to/App.app' }", 2)

	if not ui.available() then
		error(
			"macos-ui.launch: Minion is not answering AX queries — is it granted Accessibility "
				.. "(System Settings → Privacy & Security → Accessibility)?",
			2
		)
	end

	local name = bundle:match("([^/]+)%.app/?$") or error("macos-ui.launch: not a .app bundle: " .. bundle, 2)

	-- Three names, and they routinely differ. The BUNDLE is named after the Xcode
	-- target (SampleApp.app), the EXECUTABLE is declared in CFBundleExecutable, and
	-- the window server knows the app by CFBundleName ("Sample App"). Deriving any
	-- of them from the folder name works right up until a display name has a space.
	local function plist_key(key, fallback)
		local r = shell.run({ "defaults", "read", bundle .. "/Contents/Info", key }, { check = false })
		if r.code == 0 then
			local value = (r.stdout:gsub("%s+$", ""))
			if value ~= "" then
				return value
			end
		end
		return fallback
	end

	local executable = plist_key("CFBundleExecutable", name)
	local display = plist_key("CFBundleName", name)

	if not fs.exists(bundle .. "/Contents/MacOS/" .. executable) then
		error(
			("macos-ui.launch: no executable at %s/Contents/MacOS/%s — build the bundle first (`just app`)")
				:format(bundle, executable),
			2
		)
	end

	local argv = { "open", "-n", "-a", bundle }
	if opts.env then
		argv = { "open", "-n", "-a", bundle }
		for key, value in pairs(opts.env) do
			argv[#argv + 1] = "--env"
			argv[#argv + 1] = key .. "=" .. value
		end
	end
	shell.run(argv, { check = true })

	local app = setmetatable({ name = display, executable = executable, bundle = bundle }, App)
	ctx:defer(function()
		app:quit()
	end)
	return app
end

-- ── The invariant ───────────────────────────────────────────────────────────────

--- Accessibility-first, as an assertion: every INTERACTIVE element carries an
--- identity, a human label, and at least one action.
---
--- This is a tree walk, deliberately — asserting against a hard-coded list of
--- identifiers proves only that the listed controls exist, and says nothing about
--- the control someone added last week. Walking means a new control is proven or
--- reported, never silently unproven.
---
--- Static text and containers are exempt: they are not actionable and naming every
--- decorative group is noise, not accessibility.
---@param t prova.TestContext
---@param window table
---@param opts? { exempt?: string[] }
function ui.assert_no_anonymous_controls(t, window, opts)
	opts = opts or {}
	local exempt = {}
	for _, role in ipairs(opts.exempt or {}) do
		exempt[role] = true
	end

	local interactive = {
		AXButton = true, AXCheckBox = true, AXRadioButton = true, AXPopUpButton = true,
		AXTextField = true, AXTextArea = true, AXSlider = true, AXMenuButton = true,
		AXSearchField = true, AXComboBox = true, AXDisclosureTriangle = true, AXLink = true,
	}

	local anonymous = {}
	for _, element in ipairs(window:elements()) do
		if interactive[element.role] and not exempt[element.role] then
			-- Missing key, not empty string: Lua drops nil into JSON.
			local unidentified = element.identifier == nil or element.identifier == ""
			local unlabelled = (element.label == nil or element.label == "")
				and (element.title == nil or element.title == "")
			local inert = #(element.actions or {}) == 0
			if unidentified or unlabelled or inert then
				anonymous[#anonymous + 1] = ("%s(id=%s label=%s actions=%d)"):format(
					element.role,
					tostring(element.identifier),
					tostring(element.label or element.title),
					#(element.actions or {})
				)
			end
		end
	end

	t:expect(table.concat(anonymous, "; "), "every interactive control is identified, labelled and actionable")
		:equals("")
end

return ui
