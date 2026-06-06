# ThinkPad X1 Carbon Gen 12 (machine type 21KC) — Intel Core Ultra 5 125U
# (Meteor Lake) with the integrated Intel Graphics (Xe / Arc) iGPU.
#
# All host-agnostic system config lives in ../common.nix. This file wires in the
# shared module + this machine's generated hardware configuration, plus the
# Meteor-Lake-specific GPU video stack.
{ pkgs, ... }:
{
  imports = [
    ../common.nix
    ./hardware-configuration.nix
  ];

  ##########################################################################
  ## Graphics — Meteor Lake iGPU.
  ##
  ## hardware.graphics.enable is set here (rather than in the generated
  ## hardware-configuration.nix) so it survives a `nixos-generate-config`
  ## regen. extraPackages adds hardware-accelerated video decode/encode:
  ##   - intel-media-driver: the iHD VAAPI driver (Gen8+ / Xe / Arc).
  ##   - vpl-gpu-rt: oneVPL GPU runtime, the modern successor to Media SDK
  ##     used by Meteor Lake's media engine.
  ##########################################################################
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vpl-gpu-rt
    ];
  };
  # Force the iHD driver for VAAPI consumers (mpv, ffmpeg, browsers).
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";
}
