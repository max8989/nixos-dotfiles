# ThinkPad X1 Carbon 7th Gen.
#
# All host-agnostic system config lives in ../common.nix. This file only wires
# in the shared module + this machine's generated hardware configuration, plus
# any genuinely 7th-Gen-specific overrides (none currently).
{ ... }:
{
  imports = [
    ../common.nix
    ./hardware-configuration.nix
  ];
}
