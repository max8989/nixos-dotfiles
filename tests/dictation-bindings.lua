local bindings = {}
package.preload.shell_commands = function()
    return {
        dictationStart = "start",
        dictationStop = "stop",
        dictationToggle = "toggle",
    }
end
hl = {
    dsp = { exec_cmd = function(command) return command end },
    bind = function(key, command, flags)
        table.insert(bindings, { key = key, command = command, flags = flags })
    end,
}
dofile(arg[1])

local function dispatch(keycode, keysym, released, modifiers)
    local commands = {}
    for _, binding in ipairs(bindings) do
        local key = binding.key:match("([^ ]+)$")
        local keyMatches = key == "code:" .. keycode or key == keysym
        local mods = binding.key:match("^(.-) %+ [^ ]+$") or ""
        if keyMatches and (binding.flags.ignore_mods or mods == modifiers)
            and (binding.flags.release == true) == released then
            table.insert(commands, binding.command)
        end
    end
    return table.concat(commands, ",")
end

-- Actual evdev mapping of Kanata's Linux KEY_F13, in both configured layouts.
-- A keysym-only F13 binding silently fails this recording cycle.
assert(dispatch(191, "XF86Tools", false, "") == "start")
assert(dispatch(191, "XF86Tools", true, "") == "stop")
-- Releasing modifiers before V must still stop the recording.
assert(dispatch(191, "XF86Tools", false, "SUPER") == "start")
assert(dispatch(191, "XF86Tools", true, "") == "stop")
assert(dispatch(75, "F9", false, "") == "start")
assert(dispatch(75, "F9", true, "") == "stop")
-- Right Alt's modifier mask changes on release; AltGr remains available.
assert(dispatch(108, "Alt_R", false, "ALT") == "start")
assert(dispatch(108, "Alt_R", true, "") == "stop")
assert(dispatch(108, "ISO_Level3_Shift", false, "") == "")
assert(dispatch(53, "X", false, "SUPER + CTRL") == "toggle")
assert(dispatch(53, "X", true, "SUPER + CTRL") == "")
for _, binding in ipairs(bindings) do
    assert(not binding.flags.repeating, "Holding a key must not restart recording")
    assert(not binding.flags.locked, "Dictation must not start at the lock screen")
end
print("Dictation handles Kanata's evdev key, modifier release, and Omarchy shortcuts")
