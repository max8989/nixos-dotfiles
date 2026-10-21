-- Omarchy's compositor controls, plus Caps+V from Kanata's navigation layer.
local shell = require("shell_commands")

hl.bind("SUPER + CTRL + X", hl.dsp.exec_cmd(shell.dictationToggle), {
    description = "toggle dictation",
})

for _, binding in ipairs({
    -- Linux KEY_F13 (183) becomes XKB keycode 191. The default evdev keymap
    -- calls it XF86Tools, so binding the F13 keysym never sees Kanata's event.
    { key = "code:191", label = "Caps+V", ignore_mods = true },
    { key = "F9", label = "F9" },
    -- Right Alt changes its modifier mask between press and release. Match
    -- either mask, as Omarchy does; AltGr retains its separate keysym.
    { key = "ALT + Alt_R", label = "Right Alt", ignore_mods = true },
}) do
    hl.bind(binding.key, hl.dsp.exec_cmd(shell.dictationStart), {
        description = "start dictation (hold " .. binding.label .. ")",
        ignore_mods = binding.ignore_mods,
    })
    hl.bind(binding.key, hl.dsp.exec_cmd(shell.dictationStop), {
        description = "stop dictation and type transcription",
        release = true,
        ignore_mods = binding.ignore_mods,
    })
end
