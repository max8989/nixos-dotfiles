# Push every new store path to the homeserver's Attic cache (`main`), so
# nothing is compiled twice across hosts. Downloads are configured system-wide
# in hosts/attic-client.nix.
#
# The push token is never in the Nix store: log in once per machine with
#   attic login homeserver http://192.168.2.43:8085 <token>
# which writes ~/.config/attic/config.toml. Until then the service stays
# inactive (ConditionPathExists). Mint a token on the server with
#   sudo atticd-atticadm make-token --sub <host> --validity 10y --pull main --push main
{ pkgs, ... }:
{
  home.packages = [ pkgs.attic-client ];

  systemd.user.services.attic-watch-store = {
    Unit = {
      Description = "Attic watch-store (auto-push to main)";
      ConditionPathExists = "%h/.config/attic/config.toml";
    };
    Service = {
      ExecStart = "${pkgs.attic-client}/bin/attic watch-store homeserver:main";
      # Retries when the server is unreachable (off the LAN, server down).
      Restart = "on-failure";
      RestartSec = "30s";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
