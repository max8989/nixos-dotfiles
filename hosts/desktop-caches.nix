# Upstream binary caches for Hyprland and nix-gaming. Shared by the desktop
# (hosts/desktop.nix) and the homeserver's nightly prebuild
# (hosts/homeserver/prebuild-desktop.nix), which must substitute from the same
# caches or it would compile Hyprland itself.
{
  substituters = [
    "https://hyprland.cachix.org"
    "https://nix-gaming.cachix.org"
  ];
  trusted-public-keys = [
    "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
  ];
}
