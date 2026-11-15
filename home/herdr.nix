{ ... }:
{
  # Herdr Desktop's native key map; keep the TUI's prefix-based config separate.
  # https://github.com/herdrdev/herdr-app/blob/master/defaults/AGENTS.md#keys-keysjson
  xdg.configFile."herdr-app/keys.json".text = builtins.toJSON {
    global = {
      # Hyprland owns Alt+1..4 (screenshots) and Super+digits (workspaces).
      # Ctrl selects tabs; adding Shift selects spaces.
      "ctrl-shift-1" = "space.select:1";
      "ctrl-shift-2" = "space.select:2";
      "ctrl-shift-3" = "space.select:3";
      "ctrl-shift-4" = "space.select:4";
      "ctrl-shift-5" = "space.select:5";
      "ctrl-shift-6" = "space.select:6";
      "ctrl-shift-7" = "space.select:7";
      "ctrl-shift-8" = "space.select:8";
      "ctrl-shift-9" = "space.select:9";
      # GPUI on Linux can report Shift+digits as their symbols, without Shift.
      # Keep aliases for the same physical chords on the US layout.
      "ctrl-!" = "space.select:1";
      "ctrl-@" = "space.select:2";
      "ctrl-#" = "space.select:3";
      "ctrl-$" = "space.select:4";
      "ctrl-%" = "space.select:5";
      "ctrl-^" = "space.select:6";
      "ctrl-&" = "space.select:7";
      "ctrl-*" = "space.select:8";
      "ctrl-(" = "space.select:9";
      "alt-h" = "pane.go:left";
      "alt-j" = "pane.go:down";
      "alt-k" = "pane.go:up";
      "alt-l" = "pane.go:right";
      "alt-left" = "pane.go:left";
      "alt-right" = "pane.go:right";
      "alt-shift-h" = "pane.swap:left";
      "alt-shift-j" = "pane.swap:down";
      "alt-shift-k" = "pane.swap:up";
      "alt-shift-l" = "pane.swap:right";
      "ctrl-+" = "app.zoom_in";
      "ctrl--" = "app.zoom_out";
      "ctrl-0" = "app.zoom_reset";
      "ctrl-=" = "app.zoom_in";
      "ctrl-1" = "tab.select:1";
      "ctrl-2" = "tab.select:2";
      "ctrl-3" = "tab.select:3";
      "ctrl-4" = "tab.select:4";
      "ctrl-5" = "tab.select:5";
      "ctrl-6" = "tab.select:6";
      "ctrl-7" = "tab.select:7";
      "ctrl-8" = "tab.select:8";
      "ctrl-9" = "tab.select:9";
      "ctrl-pagedown" = "tab.next";
      "ctrl-pageup" = "tab.prev";
      "ctrl-tab" = "tab.next";
      "ctrl-shift-tab" = "tab.prev";
      "alt-]" = "tab.next";
      "alt-[" = "tab.prev";
      "ctrl-shift-pagedown" = "space.next";
      "ctrl-shift-pageup" = "space.prev";
      "alt-down" = "agent.next";
      "alt-up" = "agent.prev";
      "ctrl-shift-/" = "app.help";
      "ctrl-shift-?" = "app.help";
      "ctrl-shift-b" = "layout.toggle:sidebar";
      "ctrl-shift-n" = "space.new";
      "ctrl-shift-t" = "tab.new";
      "ctrl-shift-k" = "mod.open:picker";
      "ctrl-shift-p" = "app.palette";
      "ctrl-," = "app.settings";
      "ctrl-shift-enter" = "pane.split:right";
      "ctrl-shift-o" = "pane.split:right";
      "ctrl-shift-e" = "pane.split:down";
      "ctrl-shift-w" = "tab.close";
      "ctrl-shift-x" = "pane.close";
      "ctrl-shift-z" = "pane.zoom";
      "ctrl-shift-l" = "layout.switch";
      "ctrl-shift-r" = "tab.rename";
      "f2" = "tab.rename";
      "shift-f2" = "space.rename";
    };
    terminal = {
      "ctrl-backspace" = builtins.fromJSON ''"send:\u0017"'';
      "ctrl-left" = builtins.fromJSON ''"send:\u001bb"'';
      "ctrl-right" = builtins.fromJSON ''"send:\u001bf"'';
      "ctrl-shift-c" = "terminal.copy";
      "ctrl-shift-v" = "terminal.paste";
      "ctrl-v" = "terminal.paste_image";
      # Specific terminal bindings override global ones, preserving LSP rename.
      "f2" = "terminal";
    };
  };
}
