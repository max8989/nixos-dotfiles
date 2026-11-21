# Attic — self-hosted Nix binary cache for every host in this flake.
#
# atticd stores NAR chunks on the Corsair root disk (/var/lib/atticd), not on
# the nofail /mnt/data disk: an unmounted data disk would otherwise make atticd
# fill an empty directory on the root filesystem. Metadata lives in a local
# PostgreSQL. Do not switch to SQLite: a single connection serialises every
# chunk lookup, and there is no SQLite → PostgreSQL migration (a new cache
# would mean a new signing key on every client).
#
# The cache `main` is public on the LAN: anyone who can reach the port can
# download from it. Uploads need a token with --push. Clients are configured in
# ../attic-client.nix.
#
# Tokens are JWTs signed with an RSA key. There is no secrets manager in this
# repo, so atticd-keygen generates that key once on the box into a root-only
# file outside the Nix store. Back it up with /var/lib/atticd and the
# PostgreSQL database: losing it invalidates every issued token (the cache's
# signing key is in the database and survives).
{ lib, pkgs, ... }:
let
  port = 8085;
  tokenEnv = "/var/lib/atticd-secrets/token.env";
in
{
  # Static user so PostgreSQL peer authentication maps the OS user onto the
  # role. The module sets DynamicUser, which systemd ignores when a static
  # user of the same name exists.
  users.users.atticd = {
    isSystemUser = true;
    group = "atticd";
  };
  users.groups.atticd = { };

  services.postgresql = {
    enable = true;
    ensureDatabases = [ "atticd" ];
    ensureUsers = [
      {
        name = "atticd";
        ensureDBOwnership = true;
      }
    ];
  };

  systemd.services.atticd-keygen = {
    description = "Generate the Attic token-signing key once";
    wantedBy = [ "atticd.service" ];
    before = [ "atticd.service" ];
    path = [
      pkgs.coreutils
      pkgs.openssl
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      UMask = "0077";
    };
    script = ''
      set -eu
      [ -s ${tokenEnv} ] && exit 0
      mkdir -p "$(dirname ${tokenEnv})"
      key="$(openssl genrsa -traditional 4096 | base64 -w0)"
      printf 'ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64="%s"\n' "$key" > ${tokenEnv}.tmp
      mv ${tokenEnv}.tmp ${tokenEnv}
    '';
  };
  systemd.services.atticd = {
    requires = [ "atticd-keygen.service" ];
    after = [ "atticd-keygen.service" ];
  };

  services.atticd = {
    enable = true;
    environmentFile = tokenEnv;

    settings = {
      listen = "[::]:${toString port}";
      api-endpoint = "http://192.168.2.43:${toString port}/";

      # PostgreSQL over the local socket with peer authentication.
      database.url = "postgresql://atticd@localhost/atticd?host=/run/postgresql";

      storage = {
        type = "local";
        path = "/var/lib/atticd/storage";
      };

      # ~64 KiB chunks: identical chunks are stored once across builds.
      chunking = {
        nar-size-threshold = 65536;
        min-size = 16384;
        avg-size = 65536;
        max-size = 262144;
      };

      compression.type = "zstd";
      garbage-collection.interval = "12 hours";
    };
  };

  networking.firewall.allowedTCPPorts = [ port ];
}
