{ lib, pkgs, ... }:
let
  voxtypePackage = pkgs.voxtype-vulkan;
  # nixpkgs ships the OSD launcher and audio bridge, but not its QML assets.
  # Use the matching upstream source already pinned by the Voxtype package.
  voxtypeQuickshell = pkgs.runCommand "voxtype-quickshell-${voxtypePackage.version}" { } ''
    mkdir "$out"
    cp -r ${voxtypePackage.src}/quickshell/. "$out/"
    cp ${voxtypePackage.src}/LICENSE "$out/LICENSE"
  '';

  # Omarchy's local Voxtype backend, with a multilingual model instead of
  # base.en. Fetch at build time so the daemon works offline from first use.
  whisperModel = pkgs.fetchurl {
    name = "ggml-base.bin";
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-base.bin";
    hash = "sha256-YO1bw90U7qhWST0zQ0m0BXgt3K8AKNS130CINF+6Lv4=";
  };
in
{
  home.packages = [ pkgs.wtype ];

  services.voxtype = {
    enable = true;
    package = voxtypePackage;

    # Inherit WAYLAND_DISPLAY from the graphical session rather than pinning
    # a socket name. The HM module only adds these tools for a fixed display.
    environment = {
      VOXTYPE_OSD_QML_PATH = "${voxtypeQuickshell}";
      PATH = lib.makeBinPath [
        voxtypePackage
        pkgs.quickshell
        pkgs.coreutils
        pkgs.which
        pkgs.wtype
        pkgs.wl-clipboard
        pkgs.playerctl
        pkgs.libnotify
      ];
    };

    settings = {
      state_file = "auto";
      hotkey.enabled = false;
      # Omarchy's waveform HUD: real microphone levels while recording,
      # processing feedback during transcription, hidden again when idle.
      osd = {
        enabled = true;
        frontend = "quickshell";
      };
      audio = {
        device = "default";
        sample_rate = 16000;
        max_duration_secs = 60;
        pause_media = true;
      };
      whisper = {
        model = "${whisperModel}";
        # Constrain detection to the languages used for dictation.
        language = [
          "fr"
          "en"
        ];
        initial_prompt = "Dictée en français canadien (Québec) et en anglais. Québec, Montréal, courriel.";
        translate = false;
      };
      output = {
        mode = "type";
        fallback_to_clipboard = true;
        type_delay_ms = 1;
        notification = {
          on_recording_start = false;
          on_recording_stop = false;
          on_transcription = false;
        };
      };
    };
  };
}
