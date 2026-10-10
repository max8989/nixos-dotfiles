-- Selection controls must disappear only after the last monitor's layer closes.
local callbacks, handles = {}, {}
local unbound = 0
package.preload.shell_commands = function() return { captureRegion = "capture-region" } end
hl = {
    layer_rule = function() end,
    on = function(event, callback) callbacks[event] = callback end,
    dsp = { exec_cmd = function(command) return command end },
    unbind = function() error("Must not unbind the user's shortcuts by key") end,
    bind = function(key, command)
        local handle = { key = key, command = command, active = true }
        function handle:unbind()
            assert(self.active, "A temporary binding was removed twice")
            self.active = false
            unbound = unbound + 1
        end
        table.insert(handles, handle)
        return handle
    end,
}
dofile(arg[1])
callbacks["layer.opened"]({ namespace = "unrelated" })
assert(#handles == 0)
callbacks["layer.opened"]({ namespace = "selection" })
assert(#handles == 8)
callbacks["layer.opened"]({ namespace = "selection" })
assert(#handles == 8)
callbacks["layer.closed"]({ namespace = "unrelated" })
callbacks["layer.closed"]({ namespace = "selection" })
assert(unbound == 0)
callbacks["layer.closed"]({ namespace = "selection" })
assert(unbound == 8)
callbacks["layer.closed"]({ namespace = "selection" })
assert(unbound == 8)
callbacks["layer.opened"]({ namespace = "selection" })
assert(#handles == 16)
callbacks["layer.closed"]({ namespace = "selection" })
assert(unbound == 16)
print("Multi-monitor capture bindings preserve unrelated shortcuts and clean up")
