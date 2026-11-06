{ pkgs, inputs }:
# Share the configured package with the wallpaper chooser. Keep the clipboard
# behavior identical whether superfile is opened from Super+E or the gallery.
inputs.superfile.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [ ./files/superfile-system-clipboard.patch ];
})
