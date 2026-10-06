{ lib, pkgs, ... }:
##########################################################################
## fcitx5 user config: input methods, Traditional (Taiwan) output, and a
## Jade-palette theme for the Pinyin candidate popup.
##
## The addons themselves are installed system-wide (hosts/desktop.nix).
## Everything here lives in the user dirs because fcitx5 saves its own copy
## of these files and that copy shadows /etc/xdg. `force` lets Home Manager
## replace whatever fcitx5 saved on the next switch.
##########################################################################
let
  palette = import ./palette.nix;
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

  theme = {
    Metadata = {
      Name = palette.name;
      Version = 1;
      Author = "nixos-dotfiles";
      Description = "Jade palette candidate popup";
      ScaleWithDPI = "True";
    };
    InputPanel = {
      NormalColor = palette.text;
      # Selected candidate: dark text on the mint accent.
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
    # keyboard-us + pinyin. cycle-input (home/hyprland.nix) relies on
    # "pinyin" being in this group.
    "fcitx5/profile" = {
      force = true;
      text = toINI {
        "Groups/0" = {
          Name = "Default";
          "Default Layout" = "us";
          DefaultIM = "keyboard-us";
        };
        "Groups/0/Items/0".Name = "keyboard-us";
        "Groups/0/Items/1".Name = "pinyin";
        GroupOrder."0" = "Default";
      };
    };

    # Candidate popup: Jade theme, horizontal list, bigger CJK text. The TC
    # (Taiwan) cut of Noto Sans CJK draws Traditional glyph forms correctly.
    "fcitx5/conf/classicui.conf" = {
      force = true;
      text = withGlobals {
        Theme = palette.name;
        DarkTheme = palette.name;
        UseDarkTheme = "False";
        # Otherwise the GNOME accent colour overrides the Jade highlight.
        UseAccentColor = "False";
        "Vertical Candidate List" = "False";
        Font = "Noto Sans CJK TC 15";
        MenuFont = "Figtree 12";
        TrayFont = "Figtree Medium 11";
        PerScreenDPI = "True";
        EnableFractionalScale = "True";
      } { };
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
    "fcitx5/themes/${palette.name}/theme.conf".text = toINI theme;
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
  };
}
