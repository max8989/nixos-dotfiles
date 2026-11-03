# A separate chat UI with Tavily search; Hollama keeps its existing address.
{ lib, pkgs, ... }:
{
  virtualisation.oci-containers = {
    backend = "docker";
    containers.open-webui = {
      # Official v0.13.0 release. Update the version and digest together.
      image = "ghcr.io/open-webui/open-webui:v0.13.0@sha256:2272b0fb7c8783a016bcc179abb467cfa34590c99c5e6560fe0e9155b4820a09";
      autoStart = true;
      volumes = [ "open-webui-data:/app/backend/data" ];
      # Ollama's published port stays on the host loopback interface.
      extraOptions = [ "--network=host" ];
      environmentFiles = [
        "/var/lib/open-webui/bootstrap.env"
        "/var/lib/open-webui/tavily.env"
      ];
      environment = {
        HOST = "127.0.0.1";
        PORT = "8081";
        WEBUI_URL = "https://ai.maximegagne.ca";
        CORS_ALLOW_ORIGIN = "https://ai.maximegagne.ca;http://192.168.2.43:4097";
        FORWARDED_ALLOW_IPS = "127.0.0.1";
        OLLAMA_BASE_URL = "http://127.0.0.1:11434";
        ENABLE_OPENAI_API = "False";
        # Match Hollama's no-thinking default, including search-query tasks.
        DEFAULT_MODEL_PARAMS = builtins.toJSON { think = false; };
        TASK_MODEL_PARAMS = builtins.toJSON { think = false; };
        WEBUI_AUTH = "True";
        ENABLE_SIGNUP = "False";
        WEBUI_SECRET_KEY_FILE = "/app/backend/data/.webui_secret_key";
        # Keep the Nix configuration and runtime secret authoritative.
        ENABLE_PERSISTENT_CONFIG = "False";
        ENABLE_WEB_SEARCH = "True";
        WEB_SEARCH_ENGINE = "tavily";
        WEB_SEARCH_RESULT_COUNT = "3";
        TAVILY_SEARCH_DEPTH = "basic";
      };
    };
  };

  systemd.services.docker-open-webui = {
    serviceConfig = {
      StateDirectory = "open-webui";
      StateDirectoryMode = "0700";
    };
    # Bootstrap a private administrator before accepting any connections.
    # Credentials are generated at runtime and never enter the Nix store.
    preStart = lib.mkBefore ''
      if [ ! -e /var/lib/open-webui/bootstrap.env ]; then
        umask 077
        printf 'WEBUI_ADMIN_EMAIL=admin@example.com\nWEBUI_ADMIN_PASSWORD=%s\n' \
          "$(${pkgs.openssl}/bin/openssl rand -hex 32)" \
          > /var/lib/open-webui/bootstrap.env
      fi
    '';
  };

  services.nginx = {
    enable = true;
    virtualHosts.open-webui = {
      listen = [
        {
          addr = "0.0.0.0";
          port = 4097;
        }
      ];
      extraConfig = "client_max_body_size 64m;";
      locations."/" = {
        proxyPass = "http://127.0.0.1:8081";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_buffering off;
          proxy_read_timeout 600s;
          proxy_send_timeout 600s;
        '';
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 4097 ];
}
