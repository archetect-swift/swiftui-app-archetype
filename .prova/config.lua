-- Runtime companion to prova.toml — where capabilities are registered.

-- AX-driven UI proofs need a real macOS login session with a display, Minion granted
-- Accessibility, and a built .app bundle. None of that exists in CI or a headless run,
-- so `requires = {"macos-ui"}` skips those proofs GRACEFULLY rather than failing them.
--
-- A capability, not a tag: skipping-where-unavailable is exactly what capabilities
-- mean. The predicate PROBES the driver rather than reading an opt-in variable, so a
-- machine that can run these does so without being told.
--
-- Returns a boolean, never a string — prova reads a returned string as a VERSION
-- ("2.4.0"), not as a reason, so a helpful message here becomes a hard config error.
runtime.capability("macos-ui", function()
	if os.getenv("NO_UI_TESTS") then
		return false
	end
	local minion = os.getenv("MINION_BIN") or "minion"
	local ok, r = pcall(shell.run, { minion, "eval", "return #minion.screen.windows()" })
	-- A window COUNT is the signal: Minion answers even when ungranted, but cannot
	-- enumerate windows without the Accessibility grant.
	return ok and r.code == 0 and tonumber((r.stdout:gsub("%s+$", ""))) ~= nil
end)
