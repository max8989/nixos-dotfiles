{ pkgs, inputs, ... }:
let
  tomlFormat = pkgs.formats.toml { };

  # Upstream flake package (see the superfile input in flake.nix — nixpkgs is
  # stuck on 1.3.3, whose image preview blocks the UI) plus a local clipboard
  # patch: upstream `y` fills only superfile's internal clipboard and `Y`
  # copies the path as plain text. The patch makes `y` also write the path(s)
  # to the system clipboard, and turns `Y` into "copy the actual file" — a
  # file:// URI pushed as text/uri-list via wl-copy — so the hovered file
  # pastes as a real file into browsers and GUI apps. Details and regeneration
  # notes in the patch header.
  superfile =
    (inputs.superfile.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [ ./files/superfile-system-clipboard.patch ];
    }));

  # Fire-and-forget Dolphin launcher for superfile's `e` key.
  #
  # superfile runs the editor through tea.ExecProcess, which hands the terminal
  # to the child and blocks until it exits. Calling `dolphin` directly means
  # superfile sits suspended behind a live Dolphin window while Qt's portal and
  # pipewire warnings scribble over the released terminal.
  #
  # `setsid -f` forks Dolphin into its own session and returns immediately, so
  # superfile resumes at once; the redirect (inherited by the forked child)
  # keeps Qt's chatter off the TUI. Errors go to /dev/null with it — run
  # `dolphin --select <path>` by hand if it ever misbehaves.
  dolphinReveal = pkgs.writeShellScript "dolphin-reveal" ''
    exec ${pkgs.util-linux}/bin/setsid -f \
      ${pkgs.kdePackages.dolphin}/bin/dolphin --select "$@" >/dev/null 2>&1
  '';
in
{
  # superfile (SUPER+E; the `superfile` binary, not `spf`) has no Home Manager
  # module, so its two TOML files are generated from attribute sets here — the
  # repo's two-tier rule: structured config stays native Nix, not a blob in
  # home/files/.
  #
  # Safe to symlink read-only from the store: superfile only writes these when
  # the path does not exist or when run with --fix-config-file/--fix-hotkeys
  # (LoadTomlFile in src/pkg/utils/file_utils.go — with ignore_missing_fields
  # set and no fix flag it returns before ever writing). Only the individual
  # files are managed — superfile populates the rest of ~/.config/superfile
  # itself (the theme/ directory), so the directory as a whole must stay
  # writable.

  # The patched upstream package from the let block above; the flake names the
  # binary `superfile`, matching the SUPER+E bind.
  home.packages = [ superfile ];

  xdg.configFile."superfile/config.toml".source = tomlFormat.generate "superfile-config.toml" {
    theme = "arctic";

    # `e` (open_file_with_editor) appends the hovered file's path; `E`
    # (open_current_directory_with_editor) appends the panel's directory.
    # Both are split on whitespace, so extra flags can be included here.
    # `e` reveals the hovered file in Dolphin, highlighted in its containing
    # folder. These two are the only hooks superfile ever shells out to
    # (the sole exec.Command call sites in handle_file_operations.go), and only
    # this one is handed a file path — so highlighting the file necessarily
    # costs `e` its old nvim binding, which moved to `E` below.
    #
    # Goes through the dolphin-reveal wrapper above rather than calling
    # `dolphin --select` directly, so superfile is not left suspended behind
    # the Dolphin window with Qt's warnings printed over its UI.
    editor = "${dolphinReveal}";
    dir_editor = "dolphin";

    auto_check_update = true;
    cd_on_quit = false;

    default_open_file_preview = true;
    # 1.6.0 renders previews asynchronously as downscaled thumbnails
    # (src/pkg/file_preview/thumbnail_generator.go) and draws them with the
    # kitty graphics protocol when TERM says kitty, ANSI half-blocks
    # elsewhere — the full-res synchronous decode that froze navigation on
    # 1.3.3 (yorukot/superfile#899) is gone.
    show_image_preview = true;
    show_panel_footer_info = true;

    default_directory = "~/Downloads";
    file_size_use_si = false;
    show_select_icons = true;
    # 0 = a full page, as before 1.6.0
    page_scroll_size = 0;
    # 0: Name, 1: Size, 2: Date Modified, 3: Type, 4: Natural
    default_sort_type = 2;
    # Counter-intuitively false, and only because we sort by date: upstream's
    # unreversed date comparator is `ModTime().After(...)`, i.e. it already
    # sorts newest-first, unlike every other sort kind whose base comparator is
    # `<` (ascending). `reversed` XORs that result
    # (getOrderingFunc, src/internal/ui/filepanel/sort.go), so true would give
    # oldest-first here. false = most recently modified at the top; flip it at
    # runtime with `R` (toggle_reverse_sort). Revisit if default_sort_type ever
    # changes away from 2.
    sort_order_reversed = false;
    case_sensitive_sort = false;

    shell_close_on_success = false;
    debug = false;
    # Must stay true: the store symlink is read-only, so if a future
    # superfile adds config fields it cannot rewrite the file, and
    # `superfile --fix-config-file` would fail. This suppresses the
    # missing-field warning on every launch; add the new fields here
    # instead.
    ignore_missing_fields = true;

    # --- style ---
    # "" = builtin chroma highlighting, "bat" = use bat
    code_previewer = "";
    nerdfont = true;
    transparent_background = false;
    # 0 = same width as the file panel
    file_preview_width = 0;
    enable_file_preview_border = false;
    sidebar_width = 20;
    sidebar_sections = [
      "home"
      "pinned"
      "disks"
    ];
    # extra file-panel columns (0 = just the name) and the name column's share
    file_panel_extra_columns = 0;
    file_panel_name_percent = 50;

    # Each border string must be exactly one character wide.
    border_top = "─";
    border_bottom = "─";
    border_left = "│";
    border_right = "│";
    border_top_left = "╭";
    border_top_right = "╮";
    border_bottom_left = "╰";
    border_bottom_right = "╯";
    border_middle_left = "├";
    border_middle_right = "┤";

    # --- plugins (need external dependencies) ---
    # metadata needs exiftool on PATH before it can be enabled.
    metadata = false;
    enable_md5_checksum = false;
    zoxide_support = true;
  };

  # Tuned to match ~/.config/nvim — vim motions plus nvim-tree conventions.
  # Each action takes two bindings; use "" for an unused second slot.
  xdg.configFile."superfile/hotkeys.toml".source = tomlFormat.generate "superfile-hotkeys.toml" {
    # --- global (cannot conflict with other hotkeys) ---
    confirm = [
      "enter"
      "right"
      "l"
    ];
    quit = [
      "q"
      "esc"
    ];
    # quit and cd the parent shell into the current directory (needs the
    # shell-side spf wrapper; harmless without it since cd_on_quit = false)
    cd_quit = [
      "Q"
      ""
    ];

    # movement: j/k as in nvim, ctrl+u / ctrl+d half-page as in vim
    list_up = [
      "up"
      "k"
    ];
    list_down = [
      "down"
      "j"
    ];
    page_up = [
      "ctrl+u"
      "pgup"
    ];
    page_down = [
      "ctrl+d"
      "pgdown"
    ];

    # panel control: H/L cycle panels, mirroring the <S-h>/<S-l> buffer
    # cycling in personal.lua
    create_new_file_panel = [
      "n"
      ""
    ];
    close_file_panel = [
      "w"
      "ctrl+w"
    ];
    next_file_panel = [
      "L"
      "tab"
    ];
    split_file_panel = [
      "N"
      ""
    ];
    previous_file_panel = [
      "H"
      "shift+left"
    ];
    toggle_file_preview_panel = [
      "f"
      ""
    ];
    open_sort_options_menu = [
      "o"
      ""
    ];
    toggle_reverse_sort = [
      "R"
      ""
    ];

    # change focus
    focus_on_process_bar = [
      "ctrl+p"
      ""
    ];
    focus_on_sidebar = [
      "s"
      ""
    ];
    focus_on_metadata = [
      "m"
      ""
    ];

    # create / rename (nvim-tree: a = add, r = rename)
    file_panel_item_create = [
      "a"
      "ctrl+n"
    ];
    file_panel_item_rename = [
      "r"
      "ctrl+r"
    ];

    # file operations (vim yank / cut / put / delete)
    # y also writes the path(s) to the system clipboard (local patch — see
    # files/superfile-system-clipboard.patch)
    copy_items = [
      "y"
      "ctrl+c"
    ];
    cut_items = [
      "x"
      "ctrl+x"
    ];
    paste_items = [
      "p"
      "ctrl+v"
    ];
    delete_items = [
      "D"
      "delete"
    ];
    # upstream default is D, which collides with delete_items above (delete =
    # trash here, as in nvim-tree); X mirrors x-the-cut but destructive
    permanently_delete_items = [
      "X"
      ""
    ];

    # compress and extract
    extract_file = [
      "ctrl+e"
      ""
    ];
    compress_file = [
      "ctrl+a"
      ""
    ];

    # editor
    open_file_with_editor = [
      "e"
      ""
    ];
    open_current_directory_with_editor = [
      "E"
      ""
    ];

    # other
    # zoxide jump prompt (zoxide_support = true above)
    open_zoxide = [
      "z"
      ""
    ];
    pinned_directory = [
      "P"
      ""
    ];
    toggle_dot_file = [
      "."
      ""
    ];
    change_panel_mode = [
      "v"
      ""
    ];
    open_help_menu = [
      "?"
      ""
    ];
    open_command_line = [
      ":"
      ""
    ];
    open_spf_prompt = [
      ">"
      ""
    ];
    # patched (files/superfile-system-clipboard.patch): copies the hovered
    # file itself as text/uri-list via wl-copy — paste it as a real file into
    # a browser or GUI app. The plain-text path now comes with y instead.
    copy_path = [
      "Y"
      ""
    ];
    copy_present_working_directory = [
      "c"
      ""
    ];
    toggle_footer = [
      "F"
      ""
    ];

    # --- typing mode (may conflict with all hotkeys) ---
    confirm_typing = [
      "enter"
      ""
    ];
    cancel_typing = [
      "esc"
      "ctrl+c"
    ];

    # --- normal mode (must not conflict with global hotkeys) ---
    parent_directory = [
      "h"
      "left"
      "backspace"
    ];
    search_bar = [
      "/"
      ""
    ];

    # --- select mode (must not conflict with global hotkeys) ---
    file_panel_select_mode_items_select_down = [
      "J"
      "shift+down"
    ];
    file_panel_select_mode_items_select_up = [
      "K"
      "shift+up"
    ];
    file_panel_select_all_items = [
      "A"
      ""
    ];
  };
}
