# Portainer CE manages the server's existing Docker daemon.
# Keep application data in a named volume across rebuilds and container stops.
{ ... }:
{
  virtualisation.oci-containers = {
    backend = "docker";
    containers.portainer = {
      # Portainer CE 2.45.2 LTS, verified against the official image on
      # 2026-10-11. Update the version and digest together.
      image = "docker.io/portainer/portainer-ce:2.45.2@sha256:03f94a406496dc84d37b552795fc424ccad8d0d7200353b6a82915f6e8f73ab0";
      autoStart = true;
      ports = [ "9443:9443" ];
      volumes = [
        "/var/run/docker.sock:/var/run/docker.sock"
        "portainer_data:/data"
      ];
    };
  };

  networking.firewall.allowedTCPPorts = [ 9443 ];
}
