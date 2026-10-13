# OpenCode web UI, published as opencode.maximegagne.ca through Nginx Proxy
# Manager, which terminates TLS. The agent runs shell commands as the user, so
# the service refuses to start without a password. Create it on the box:
#   sudo install -Dm600 /dev/null /var/lib/opencode/env
#   echo 'OPENCODE_SERVER_PASSWORD=<long random string>' | sudo tee /var/lib/opencode/env
{
  config,
  pkgs,
  username,
  ...
}:
{
  systemd.services.opencode-web = {
    description = "OpenCode web UI";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    # Give the agent the same tools as an interactive shell.
    path = [ config.system.path ];
    script = ''
      if [ -z "''${OPENCODE_SERVER_PASSWORD:-}" ]; then
        echo "OPENCODE_SERVER_PASSWORD is unset; refusing to expose OpenCode" >&2
        exit 1
      fi
      exec ${pkgs.opencode}/bin/opencode web --hostname 0.0.0.0 --port 4096
    '';
    serviceConfig = {
      User = username;
      WorkingDirectory = "/home/${username}";
      EnvironmentFile = "/var/lib/opencode/env";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  networking.firewall.allowedTCPPorts = [ 4096 ];
}
