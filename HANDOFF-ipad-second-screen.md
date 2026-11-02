# Handoff: iPad as a second screen on NixOS

Prepared 2026-11-01 (America/Toronto).

## Goal and current status

Use the user's **2018 iPad Pro, Wi-Fi only**, as an extended display for the
ThinkPad. The user previously used a Wi-Fi application and wanted a cable option.
The conversation has focused on **Orion plus an HDMI capture card**.

**The setup is not working yet.** The user is comparing capture cards; no purchase
or successful connection with a confirmed capture card has been reported. No
NixOS configuration, runtime display settings, or installed applications were
changed during this investigation. This handoff is the only file added for it.

Read `~/.claude/CLAUDE.md` and the repository's `CLAUDE.md` before continuing.

## Verified configuration and observations

- Laptop: the repository's ThinkPad X1 Carbon Gen 12 host, with Intel Meteor Lake
  graphics and the `i915` driver.
- The running compositor was **Hyprland 0.56.0**, commit
  `fb6e5380228b2908ed9b74867a32b26f623a0cec`.
- `hosts/thinkpad-x1-carbon-g12/configuration.nix` already configures Intel video
  acceleration through `intel-media-driver`, `vpl-gpu-rt`, and the iHD driver.
- `hosts/desktop.nix` already enables PipeWire and the Hyprland screen-sharing
  portal. Those components matter for streaming alternatives; Orion receives
  HDMI video through the iPad's USB connection.
- `home/files/hypr/hyprland.lua` has a general monitor rule:

  ```lua
  hl.monitor({ output = "", mode = "highres", position = "auto", scale = 1 })
  ```

  A correctly detected HDMI capture card should therefore get an extended
  desktop without an initial configuration change.
- During repeated connection checks, only `eDP-1`, **1920x1200 at approximately
  60 Hz, scale 1**, was active. The kernel reported
  `card1-HDMI-A-1/status = disconnected`, no EDID bytes, and no available modes.
  These are observations from troubleshooting, not a guarantee of current state.
- The user reported Orion showing **"No signal"** and a cable icon. The icon was
  not sufficient to establish that a working HDMI capture device was attached.
- The user said they used two dongles and supplied a photo. It appeared to show
  a standard USB-C multiport hub with HDMI output. Its exact model was not
  identified. A hub with HDMI output cannot receive the laptop's HDMI signal.
- The agent shell did not inherit the desktop environment variables, but
  `hyprctl instances -j` found the session; supplying its instance explicitly
  allowed monitor queries. An unset `HYPRLAND_INSTANCE_SIGNATURE` in this shell
  does not mean Hyprland is stopped.

## Orion connection and hardware requirement

Required direction:

**Laptop HDMI output → ordinary HDMI cable → capture card HDMI input → capture
card USB-C connection → iPad running Orion.**

The iPad-side device must be an **HDMI-to-USB video capture card**, not a normal
USB-C-to-HDMI display adapter or hub. The capture card's USB connection belongs
on the iPad, so it need not appear in the laptop's USB device list. Linux is
the HDMI source; the iPad is the USB capture host.

Orion requires a USB-C iPad running **iPadOS 17 or later**. The user's installed
iPadOS version was not explicitly confirmed. Cellular service and Personal
Hotspot are unnecessary for this HDMI capture arrangement.

No Linux capture application, Sunshine server, or Apple USB service is needed
for this route. The existing ordinary HDMI cable can be reused; Amazon's
suggested micro-HDMI cable is unnecessary for the laptop's full-size HDMI port.

## Capture cards discussed

Specifications and prices below are seller claims and session snapshots, not
measurements or current offers. Neither card was tested on this laptop/iPad.

| Product | Listed capture capability | Assessment given to the user |
| --- | --- | --- |
| Guermok, silver, Amazon ASIN `B08Z3XDYQ7` | USB 3.0; 1080p at 60 fps or advertised 2K at 30 fps; up to 4K at 30 Hz input | Recommended budget option. Orion's own recommended capture-card link resolved to this exact listing during research. The basic version has no charging passthrough. |
| UGREEN CM489 / model 40189, Amazon.ca ASIN `B0BGMYPBF4` | USB 2.0; up to 1080p at 30 fps capture; MJPEG; advertised UVC 1.0 | Should work with Orion, but the 30 fps limit makes it less attractive for desktop scrolling and pointer movement. |

The original Guermok Amazon.com offer was CAD 26.52 plus CAD 11.90 shipping
(CAD 38.42 before tax). The later Amazon.ca page showed the UGREEN at CAD 22.99
and a Guermok gray variant advertised at 1080p/60 fps for CAD 26.99 under
"Customers also bought". The latest advice was to prefer the 60 fps Guermok for
the CAD 4 difference **if shipping costs are similar**. The gray variant's exact
ASIN was not provided or independently identified.

Important limits to preserve:

- "4K input" does not mean 4K capture. Start with a mode the chosen card actually
  supports, typically 1080p/60 fps for the Guermok or 1080p/30 fps for this UGREEN.
- 1080p video will not reproduce the iPad panel's native text sharpness. Capture
  can also add latency; "ultra low latency" was not independently verified.
- The basic cards do not provide a dedicated charging input. Plan for battery
  use unless a separately verified powered USB arrangement is used.
- The UGREEN listing's warning about not extending displays refers to direct
  display-adapter use. With Orion, the iPad displays captured HDMI video while
  Hyprland extends the desktop onto its HDMI output.
- A review claiming 1080p/60 fps for the UGREEN conflicts with the seller's
  explicit 1080p/30 fps specification. Use the stated capture specification.

## Next steps

1. Confirm which actual **capture card** the user obtained. Do not assume the
   photographed hub or the two original dongles provide video capture.
2. Connect it in the direction above, open Orion, and grant any camera/audio
   permissions requested by the app. Recheck laptop HDMI detection.
3. Use read-only diagnostics before changing settings:

   ```sh
   cat /sys/class/drm/card*-HDMI-A-*/status
   hyprctl instances -j
   hyprctl -i 'INSTANCE_FROM_PREVIOUS_COMMAND' monitors -j
   ```

   Replace the quoted placeholder with the returned instance. DRM card numbers
   can change; do not depend on `card1`. If the connection uses a laptop USB-C
   video adapter instead of its HDMI port, inspect the DP connectors too.
4. If HDMI remains disconnected with a confirmed capture card, check card power,
   HDMI cable seating, and input/output direction. Isolate the HDMI cable or
   laptop port with a known working display if available. No software fix has
   been established for the original disconnected state.
5. Once detected, verify the card's advertised modes, start with a supported
   capture resolution/frame rate, and confirm an image in Orion. Keep the
   built-in display enabled.
6. Confirm that windows can move onto the iPad as an extended desktop. Then
   choose placement and scaling with the user. The iPad's size (11-inch versus
   12.9-inch) has not been established.
7. If persistent settings are needed, use `home/files/hypr/hyprland.lua` and
   follow this repository's Lua configuration conventions. Prefer a rule specific
   to the detected capture device, preserving existing external-monitor rules.
   Follow the repository's validation requirements after configuration edits.

## Alternatives researched, not implemented

- A `SUNSHINE` headless monitor rule already exists in `hyprland.lua`, set to
  1280x720 at 30 Hz. It is for streaming and is unnecessary for Orion's physical
  HDMI connection. Sunshine was disabled in the evaluated configuration.
- Sunshine/Moonlight over Wi-Fi remains an alternative. It has not been set up
  or tested in this session.
- OpenDisplay's **community Linux fork** documents Hyprland and direct USB
  transport through `usbmuxd`; it would require custom Nix packaging. The
  official Linux sender's documentation, when checked, explicitly excluded USB
  transport. Do not confuse the upstream sender with the community fork.
- The user confirmed a Wi-Fi-only iPad, so ordinary cellular Personal Hotspot
  tethering is unavailable. This does not rule out application-specific USB
  transport such as the OpenDisplay community approach.

## Validation when creating this handoff

- The handoff's required sections, formatting whitespace, and final newline
  were checked. The working tree was clean before creation; afterward, this
  Markdown document was the only untracked or modified file.
- The repository-required `nix flake check` was run and exited with code 1 in
  `checks.x86_64-linux.quickshell`. Reported QML lint issues included missing
  `values` members in `services/Media.qml` and `services/Network.qml`, missing
  popup-anchor properties/methods in `widgets/HoverTip.qml`, and a shadowed
  `slider` identifier in `widgets/SettingsSlider.qml`.
- Evaluation also emitted a homeserver disko diagnostic about the read-only
  `disko.devices.disk.disk1.content.partitions...content._config` option being
  set multiple times. The terminating failure was the Quickshell check above.
- These diagnostics concern existing tracked configuration; no tracked code or
  configuration was changed by this handoff task. They were left for a separate
  task. Do not report the full flake check as passing.
- No successful Orion capture or end-to-end extended-display test has occurred.

## Sources

- [Orion requirements and recommended accessories](https://orion.tube/)
- [Orion App Store requirements](https://apps.apple.com/us/app/hdmi-monitor-orion/id6459355072)
- [Guermok model recommended by Orion](https://www.amazon.com/dp/B08Z3XDYQ7)
- [UGREEN CM489 / 40189 listing](https://www.amazon.ca/dp/B0BGMYPBF4)
- [OpenDisplay community sender comparison](https://opendisplay.app/docs/third-party/linux/)
- [OpenDisplay community Linux guide, linux-port branch](https://github.com/tixwho/opendisplay-linux/blob/linux-port/Linux/README.md)
- [Official OpenDisplay Linux sender limitations](https://opendisplay.app/docs/linux/)

Recheck product variants, prices, and software support before relying on them
in a later session.
