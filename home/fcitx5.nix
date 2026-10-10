{ config, lib, pkgs, ... }:
##########################################################################
## fcitx5 user config: input methods, Traditional (Taiwan) output, and a
## Theme-aware palette for the Pinyin candidate popup.
##
## The addons themselves are installed system-wide (hosts/desktop.nix).
## Everything here lives in the user dirs because fcitx5 saves its own copy
## of these files and that copy shadows /etc/xdg. `force` lets Home Manager
## replace whatever fcitx5 saved on the next switch.
##########################################################################
let
  palette = import ./palette.nix;
  latte = config.localTheme.palettes.catppuccin-latte;
  toINI = lib.generators.toINI { };
  # fcitx5 keeps top-level options outside any [section].
  withGlobals =
    globalSection: sections:
    lib.generators.toINIWithGlobalSection { } { inherit globalSection sections; };
  margin = n: {
    Left = n;
    Right = n;
    Top = n;
    Bottom = n;
  };

  # Rounded panels. classicui 9-slices the image: the `Margin` sections below
  # keep the corners unscaled, so the margin must cover the corner radius.
  roundedRect =
    {
      fill,
      stroke ? "none",
      radius,
    }:
    ''
      <svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48">
        <rect x="0.5" y="0.5" width="47" height="47" rx="${toString radius}" fill="${fill}" stroke="${stroke}" stroke-width="1"/>
      </svg>
    '';
  defaultDark = "${pkgs.fcitx5}/share/fcitx5/themes/default-dark";

  themeFor = palette: {
    Metadata = {
      Name = palette.name;
      Version = 1;
      Author = "nixos-dotfiles";
      Description = "Desktop palette candidate popup";
      ScaleWithDPI = "True";
    };
    InputPanel = {
      NormalColor = palette.text;
      # Selected candidate: contrasting text on the accent.
      HighlightCandidateColor = palette.background;
      HighlightColor = palette.background;
      HighlightBackgroundColor = palette.accent;
      PageButtonAlignment = "Last Candidate";
      Spacing = 4;
    };
    "InputPanel/TextMargin" = {
      Left = 10;
      Right = 10;
      Top = 6;
      Bottom = 6;
    };
    "InputPanel/ContentMargin" = margin 8;
    "InputPanel/Background".Image = "panel.svg";
    "InputPanel/Background/Margin" = margin 14;
    "InputPanel/Highlight".Image = "highlight.svg";
    "InputPanel/Highlight/Margin" = margin 10;
    "InputPanel/PrevPage".Image = "prev.svg";
    "InputPanel/PrevPage/ClickMargin" = margin 5;
    "InputPanel/NextPage".Image = "next.svg";
    "InputPanel/NextPage/ClickMargin" = margin 5;
    Menu = {
      NormalColor = palette.text;
      HighlightCandidateColor = palette.background;
    };
    "Menu/Background".Image = "panel.svg";
    "Menu/Background/Margin" = margin 14;
    "Menu/ContentMargin" = margin 8;
    "Menu/Highlight".Image = "highlight.svg";
    "Menu/Highlight/Margin" = margin 10;
    "Menu/Separator".Color = palette.border;
    "Menu/TextMargin" = margin 6;
    "Menu/CheckBox".Image = "radio.svg";
    "Menu/SubMenu".Image = "arrow.svg";
  };
in
{
  xdg.configFile = {
    # keyboard-us, keyboard-ca, pinyin — the three steps of cycle-input
    # (home/hyprland.nix), which relies on these exact names.
    "fcitx5/profile" = {
      force = true;
      text = toINI {
        "Groups/0" = {
          Name = "Default";
          "Default Layout" = "us";
          DefaultIM = "keyboard-us";
        };
        "Groups/0/Items/0".Name = "keyboard-us";
        # French as an fcitx5 IM (not only a Hyprland layout) so switching to
        # it shows the same input-method popup as English and Pinyin.
        "Groups/0/Items/1".Name = "keyboard-ca";
        "Groups/0/Items/2".Name = "pinyin";
        GroupOrder."0" = "Default";
      };
    };

    # One input method for every window. fcitx5's default keeps a separate
    # state per window, which drifts from Hyprland's single global layout.
    "fcitx5/config" = {
      force = true;
      text = toINI {
        Behavior.ShareInputState = "All";
      };
    };

    # Enter picks the highlighted candidate instead of typing the raw
    # letters; Shift/Ctrl+Enter still commit the raw pinyin.
    "fcitx5/conf/pinyin.conf" = {
      force = true;
      text = withGlobals { FirstRun = "False"; } {
        CurrentCandidate = {
          "0" = "space";
          "1" = "KP_Space";
          "2" = "Return";
          "3" = "KP_Enter";
        };
        CommitRawInput = {
          "0" = "Shift+Return";
          "1" = "Shift+KP_Enter";
          "2" = "Control+Return";
          "3" = "Control+KP_Enter";
        };
      };
    };

    # Candidate popup: selected desktop theme, horizontal list, bigger CJK text. The TC
    # (Taiwan) cut of Noto Sans CJK draws Traditional glyph forms correctly.
    "fcitx5/conf/classicui.conf" = {
      force = true;
      source = config.lib.file.mkOutOfStoreSymlink "${config.localTheme.currentDir}/fcitx-classicui.conf";
    };

    # Pinyin types Simplified candidates; chttrans converts them with
    # OpenCC's s2twp (Taiwan characters + Taiwan phrasing). Listing pinyin
    # in EnabledIM turns the conversion on by default; Ctrl+Shift+F toggles.
    "fcitx5/conf/chttrans.conf" = {
      force = true;
      text =
        withGlobals
          {
            Engine = "OpenCC";
            OpenCCS2TProfile = "s2twp.json";
          }
          {
            EnabledIM."0" = "pinyin";
          };
    };
  };

  xdg.dataFile = {
    "fcitx5/themes/${palette.name}/theme.conf".text = toINI (themeFor palette);
    "fcitx5/themes/${palette.name}/panel.svg".text = roundedRect {
      fill = palette.base;
      stroke = palette.border;
      radius = 12;
    };
    "fcitx5/themes/${palette.name}/highlight.svg".text = roundedRect {
      fill = palette.accent;
      radius = 8;
    };
    "fcitx5/themes/${palette.name}/prev.svg".source = "${defaultDark}/prev.svg";
    "fcitx5/themes/${palette.name}/next.svg".source = "${defaultDark}/next.svg";
    "fcitx5/themes/${palette.name}/radio.svg".source = "${defaultDark}/radio.svg";
    "fcitx5/themes/${palette.name}/arrow.svg".source = "${defaultDark}/arrow.svg";
    "fcitx5/themes/${latte.name}/theme.conf".text = toINI (themeFor latte);
    "fcitx5/themes/${latte.name}/panel.svg".text = roundedRect {
      fill = latte.base;
      stroke = latte.border;
      radius = 12;
    };
    "fcitx5/themes/${latte.name}/highlight.svg".text = roundedRect {
      fill = latte.accent;
      radius = 8;
    };
    "fcitx5/themes/${latte.name}/prev.svg".source = "${defaultDark}/prev.svg";
    "fcitx5/themes/${latte.name}/next.svg".source = "${defaultDark}/next.svg";
    "fcitx5/themes/${latte.name}/radio.svg".source = "${defaultDark}/radio.svg";
    "fcitx5/themes/${latte.name}/arrow.svg".source = "${defaultDark}/arrow.svg";
  };
}
