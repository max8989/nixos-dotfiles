# ThinkPad X1 Carbon 7th Gen.
#
# All host-agnostic system config lives in ../common.nix. This file wires in the
# shared module + this machine's generated hardware configuration, plus any
# genuinely 7th-Gen-specific overrides.
{ ... }:
{
  imports = [
    ../common.nix
    ./hardware-configuration.nix
  ];

  ##########################################################################
  ## Graphics — 8th-gen Intel iGPU (UHD 620).
  ##
  ## hardware.graphics.enable is set HERE (rather than in the generated
  ## hardware-configuration.nix) so it survives a `nixos-generate-config`
  ## regen. If it lived in the generated file, regenerating would wipe it and
  ## Hyprland would come up with no GL/DRI. (The Gen 12 does the same for its
  ## Meteor Lake video stack.)
  ##########################################################################
  hardware.graphics.enable = true;
}
