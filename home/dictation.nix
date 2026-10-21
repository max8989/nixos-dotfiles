{ lib, pkgs, ... }:
let
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
    package = pkgs.voxtype-vulkan;

    # Inherit WAYLAND_DISPLAY from the graphical session rather than pinning
    # a socket name. The HM module only adds these tools for a fixed display.
    environment.PATH = lib.makeBinPath [
      pkgs.coreutils
      pkgs.which
      pkgs.wtype
      pkgs.wl-clipboard
      pkgs.playerctl
      pkgs.libnotify
    ];

    settings = {
      state_file = "auto";
      hotkey.enabled = false;
      # Recording feedback uses the desktop's existing notification service.
      osd.enabled = false;
      audio = {
        device = "default";
        sample_rate = 16000;
        max_duration_secs = 60;
        pause_media = true;
      };
      whisper = {
        model = "${whisperModel}";
        language = "auto";
        translate = false;
      };
      output = {
        mode = "type";
        fallback_to_clipboard = true;
        type_delay_ms = 1;
        notification = {
          on_recording_start = true;
          on_recording_stop = true;
          on_transcription = false;
        };
      };
    };
  };
}
