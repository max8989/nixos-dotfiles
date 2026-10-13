# OpenCode web UI, published as opencode.maximegagne.ca through Nginx Proxy
# Manager, which terminates TLS and requires the login. OpenCode itself has no
# password, so anything that reaches port 4096 directly gets a shell as the user.
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
    script = "exec ${pkgs.opencode}/bin/opencode web --hostname 0.0.0.0 --port 4096";
    serviceConfig = {
      User = username;
      WorkingDirectory = "/home/${username}";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  networking.firewall.allowedTCPPorts = [ 4096 ];
}
