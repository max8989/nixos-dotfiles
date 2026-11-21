# Download from the homeserver's Attic cache (hosts/homeserver/attic.nix)
# before building. Set system-wide so nix-daemon uses it for every user; a
# flake's nixConfig is ignored for users who aren't trusted-users.
#
# The cache is public on the LAN, so no netrc/pull token is needed. Uploads
# are done per user by home/attic.nix.
{
  nix.settings = {
    substituters = [ "http://192.168.2.43:8085/main" ];
    trusted-public-keys = [ "main:xbh+v793ohkOSHrCzEe8zrzE/WwoJOQU53gbuxOXTtk=" ];

    # Off the home network (or server down) give up quickly and fall back to
    # cache.nixos.org / local builds instead of hanging for minutes.
    connect-timeout = 5;
  };
}
