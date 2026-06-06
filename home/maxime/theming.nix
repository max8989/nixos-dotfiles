{ pkgs, ... }:
{
  # Cursor — the Hyprland exec-once sets `catppuccin-frappe-dark-cursors`.
  home.pointerCursor = {
    name = "catppuccin-frappe-dark-cursors";
    package = pkgs.catppuccin-cursors.frappeDark;
    size = 24;
    gtk.enable = true;
    hyprcursor.enable = true;
  };

  gtk = {
    enable = true;
    theme = {
      name = "catppuccin-mocha-blue-standard";
      package = pkgs.catppuccin-gtk.override {
        variant = "mocha";
        accents = [ "blue" ];
      };
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
  };

  # Make Qt apps follow the GTK look where possible.
  qt = {
    enable = true;
    platformTheme.name = "gtk";
  };
}
