"""Record real H.264/AAC on a private headless display and virtual audio sink.

Only Hyprland's monitor/selector boundary and desktop notifications are replaced.
The production controller, wf-recorder, codec/filter and audio capture run live.
"""
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile
import time

script, output = map(lambda value: Path(value).resolve(), sys.argv[1:])
output.mkdir(parents=True)
runtime_directory = tempfile.TemporaryDirectory(prefix="recording-", dir="/tmp")
runtime = Path(runtime_directory.name)
tools = output / "bin"
tools.mkdir()
for name, body in {
    "hyprctl": 'printf \'[{"name":"HEADLESS-1","focused":true}]\\n\'\n',
    "nixos-capture-region": "printf '20,30 301x201\\n'\n",
    "notify-send": "exit 0\n",
    "nixos-screen-record-notify": 'test -s "$1"\n',
}.items():
    executable = tools / name
    executable.write_text("#!" + shutil.which("bash") + "\n" + body)
    executable.chmod(0o700)
env = dict(os.environ, PATH=str(tools) + ":" + os.environ["PATH"],
           XDG_RUNTIME_DIR=str(runtime), HOME=str(output / "home"),
           XDG_CONFIG_HOME=str(output / "config"), XDG_STATE_HOME=str(output / "state"),
           NIXOS_SCREENRECORD_DIR=str(output / "videos with spaces"),
           WLR_BACKENDS="headless", WLR_RENDERER="pixman", WLR_LIBINPUT_NO_DEVICES="1",
           PULSE_SERVER="unix:" + str(runtime / "pulse.socket"))
for name in ("WAYLAND_DISPLAY", "DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE", "SWAYSOCK",
             "DBUS_SESSION_BUS_ADDRESS", "DBUS_SYSTEM_BUS_ADDRESS"):
    env.pop(name, None)
processes = []
report = []


def run(args):
    return subprocess.run(args, env=env, capture_output=True, check=True, timeout=15)


def wait(predicate):
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        if predicate(): return
        time.sleep(0.05)
    raise AssertionError("Timed out waiting for isolated recording")


def start(args, name):
    log = (output / (name + ".log")).open("wb")
    process = subprocess.Popen(args, env=env, stdout=log, stderr=subprocess.STDOUT)
    processes.append(process)
    return process


try:
    bus_config = output / "session.conf"
    bus_config.write_text(f'''<busconfig><type>session</type><listen>unix:path={runtime}/bus</listen>
      <auth>EXTERNAL</auth><policy context="default">
        <allow send_destination="*" eavesdrop="true"/>
        <allow eavesdrop="true"/><allow own="*"/>
      </policy></busconfig>''')
    start(["dbus-daemon", "--config-file", str(bus_config), "--nofork"], "bus")
    wait(lambda: (runtime / "bus").is_socket())
    env["DBUS_SESSION_BUS_ADDRESS"] = "unix:path=" + str(runtime / "bus")
    env["DBUS_SYSTEM_BUS_ADDRESS"] = env["DBUS_SESSION_BUS_ADDRESS"]
    compositor_config = output / "sway.conf"
    compositor_config.write_text("output HEADLESS-1 resolution 800x600\noutput HEADLESS-1 bg #20283a solid_color\nseat seat0 fallback true\n")
    start(["sway", "--config", str(compositor_config)], "compositor")
    wait(lambda: any(path.is_socket() for path in runtime.glob("wayland-*")))
    env["WAYLAND_DISPLAY"] = next(path.name for path in runtime.glob("wayland-*") if path.is_socket())
    env["SWAYSOCK"] = str(next(runtime.glob("sway-ipc.*.sock")))
    pulse_config = output / "pulse.conf"
    pulse_config.write_text(f"load-module module-native-protocol-unix socket={runtime}/pulse.socket auth-anonymous=1\n"
                            "load-module module-null-sink sink_name=recording_qa\n"
                            "set-default-sink recording_qa\nset-default-source recording_qa.monitor\n")
    start(["pulseaudio", "-n", "--file=" + str(pulse_config), "--daemonize=no", "--exit-idle-time=-1"], "audio")
    wait(lambda: (runtime / "pulse.socket").exists())
    run(["pactl", "info"])
    # A local generated tone makes an accidentally silent/wrong source fail.
    audio_log = (output / "tone.log").open("wb")
    tone = subprocess.Popen(["ffmpeg", "-v", "error", "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=48000",
                             "-f", "s16le", "-"], env=env, stdout=subprocess.PIPE, stderr=audio_log)
    processes.append(tone)
    playback = subprocess.Popen(["pacat", "--playback", "--device=recording_qa", "--rate=48000", "--channels=1", "--format=s16le"],
                                env=env, stdin=tone.stdout, stdout=audio_log, stderr=audio_log)
    tone.stdout.close()
    processes.append(playback)
    for mode, audio in [("fullscreen", "none"), ("region", "desktop"), ("windows", "microphone")]:
        controller = start(["bash", str(script), mode, audio], mode)
        wait(lambda: json.loads(run(["bash", str(script), "--status"]).stdout).get("phase") == "recording")
        time.sleep(0.8)
        run(["swaymsg", "output", "HEADLESS-1", "bg", "#406080", "solid_color"])
        time.sleep(0.8)
        run(["bash", str(script), "--stop"])
        assert controller.wait(timeout=10) == 0, (output / (mode + ".log")).read_text()
        video = Path((output / (mode + ".log")).read_text().strip())
        streams = json.loads(run(["ffprobe", "-v", "error", "-show_streams", "-of", "json", str(video)]).stdout)["streams"]
        visual = next(stream for stream in streams if stream["codec_type"] == "video")
        assert visual["codec_name"] == "h264", visual
        expected = (800, 600) if mode == "fullscreen" else (300, 200)
        assert (visual["width"], visual["height"]) == expected, visual
        assert float(visual["duration"]) >= 1 and int(visual["nb_frames"]) >= 2, visual
        audible = [stream for stream in streams if stream["codec_type"] == "audio"]
        assert bool(audible) == (audio != "none"), streams
        if audible:
            assert audible[0]["codec_name"] == "aac", audible
            pcm = run(["ffmpeg", "-v", "error", "-i", str(video), "-vn", "-f", "s16le", "-"]).stdout
            assert max(abs(value[0]) for value in struct.iter_unpack("<h", pcm)) > 100, "Recording audio is silent"
        shutil.copy(video, output / f"{mode}-{audio}.mp4")
        report.append({"mode": mode, "audio": audio, "dimensions": expected, "bytes": video.stat().st_size})
        run(["swaymsg", "output", "HEADLESS-1", "bg", "#20283a", "solid_color"])
    (output / "result.json").write_text(json.dumps(report, indent=2))
    print("Live H.264/AAC recording, odd-sized regions, desktop/microphone audio and finalization passed")
except Exception:
    for log in [*output.glob("*.log"), *runtime.glob("nixos-screen-record-*/recorder.log")]:
        print(log.name + ":\n" + "\n".join(log.read_text(errors="replace").splitlines()[-20:]), flush=True)
    raise
finally:
    for process in reversed(processes):
        if process.poll() is None:
            process.terminate()
            try: process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
    runtime_directory.cleanup()
