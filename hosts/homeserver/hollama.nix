# Hollama replaces OpenCode on the existing proxy's upstream port.
# The browser uses a same-origin Ollama proxy; port 11434 stays loopback-only.
{ pkgs, ... }:
{
  virtualisation.oci-containers = {
    backend = "docker";
    containers.hollama = {
      # Upstream 0.37.0. Keep the defaults script in sync when upgrading.
      image = "ghcr.io/fmaclen/hollama:0.37.0@sha256:247c2e5e2583c4a3d6b35bde8dc9be18e1fea038d2bf9a04ff1d9a6c08f8718d";
      autoStart = true;
      ports = [ "127.0.0.1:4173:4173" ];
      environment.HOST = "0.0.0.0";
    };
  };

  services.nginx = {
    enable = true;
    virtualHosts.hollama = {
      listen = [
        {
          addr = "0.0.0.0";
          port = 4096;
        }
      ];
      extraConfig = "client_max_body_size 64m;";
      locations = {
        "/" = {
          proxyPass = "http://127.0.0.1:4173";
          extraConfig = ''
            proxy_set_header Accept-Encoding "";
            sub_filter '</head>' '<script src="/hollama-defaults.js"></script></head>';
            sub_filter_once on;
          '';
        };
        "= /hollama-defaults.js" = {
          alias = pkgs.writeText "hollama-defaults.js" (builtins.readFile ./hollama-defaults.js);
          extraConfig = ''
            default_type application/javascript;
            add_header Cache-Control "no-store";
          '';
        };
        "/ollama/api/" = {
          proxyPass = "http://127.0.0.1:11434/api/";
          extraConfig = ''
            proxy_http_version 1.1;
            proxy_set_header Host localhost:11434;
            proxy_set_header Origin "";
            proxy_buffering off;
            proxy_read_timeout 600s;
          '';
        };
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 4096 ];
}
