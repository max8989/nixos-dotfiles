# Update commands for a desktop host. The homeserver updates flake.lock every
# night, builds this host against it and pushes the result to Attic
# (hosts/homeserver/prebuild-desktop.nix), committing the lock only if the
# build succeeded.
#
#   nixos-update  pull the builder's last good lock, switch; heavy packages download
#   bump-latest   fresh `nix flake update` right now; anything new compiles here
#   nixos-switch  switch to whatever is checked out; cache if it has it
{
  config,
  osConfig,
  pkgs,
  ...
}:
let
  repo = "${config.home.homeDirectory}/repos/nixos-dotfiles";
  flake = "${repo}#${osConfig.networking.hostName}";
  # nom shows a live tree of builds and downloads. pipefail keeps
  # nixos-rebuild's exit code instead of nom's. `sudo -v` first: nom redraws
  # over the password prompt and hides it.
  rebuild =
    action:
    "sudo -v && (set -o pipefail; sudo nixos-rebuild ${action} --flake ${flake} --log-format internal-json -v |& nom --json)";
  aliases = {
    nixos-switch = rebuild "switch";
    nixos-update = "git -C ${repo} pull --rebase --autostash && ${rebuild "switch"}";
    bump-latest = "nix flake update --flake ${repo} && ${rebuild "switch"}";
  };
in
{
  home.packages = [ pkgs.nix-output-monitor ];
  programs.zsh.shellAliases = aliases;
  programs.bash.shellAliases = aliases;
}
