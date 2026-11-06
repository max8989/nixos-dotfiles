"""Run real OCR and QR decoders through the production capture script."""
import json
import os
from pathlib import Path
import subprocess
import sys

# The capture fixture consumes the script-directory argument and isolates the
# compositor, screenshots and clipboard from the developer's desktop.
import capture

font = sys.argv[1]
fixture = capture.CaptureTests()
fixture.setUp()
try:
    for decoder in ["tesseract", "zbarimg"]:
        (fixture.bin / decoder).unlink()
    languages = subprocess.run(["tesseract", "--list-langs"], check=True,
                               capture_output=True, text=True).stdout.splitlines()
    assert {"eng", "fra", "chi_tra"} <= set(languages), languages

    image = fixture.root / "text.png"
    subprocess.run(["magick", "-size", "800x120", "xc:white", "-font", font,
                    "-pointsize", "40", "-fill", "black", "-annotate", "+20+75",
                    "Bonjour Québec 2026", str(image)], check=True)
    (fixture.root / "image").write_bytes(image.read_bytes())
    result = fixture.run_capture("region", "ocr")
    assert result.stdout == "", result.stdout
    assert (fixture.root / "clipboard").read_text() == "Bonjour Québec 2026"
    fixture.assert_clean()

    # The payload is deliberately only a fixture; keep it out of stdout and
    # notifications, and verify that no URL is ever opened.
    payload = "otpauth://totp/Fixture?secret=EXAMPLE&issuer=Test"
    image = fixture.root / "qr.png"
    subprocess.run(["qrencode", "-o", str(image), payload], check=True)
    (fixture.root / "image").write_bytes(image.read_bytes())
    result = fixture.run_capture("region", "qr")
    assert result.stdout == "" and payload not in result.stderr
    assert (fixture.root / "clipboard").read_text() == payload
    assert payload not in json.dumps(fixture.calls("notify-send"))
    fixture.assert_clean()

    # No detection is a normal result and must leave the previous copy intact.
    image = fixture.root / "blank.png"
    subprocess.run(["magick", "-size", "400x100", "xc:white", str(image)], check=True)
    (fixture.root / "image").write_bytes(image.read_bytes())
    for processing in ["ocr", "qr"]:
        fixture.run_capture("region", processing)
        assert (fixture.root / "clipboard").read_text() == payload
        fixture.assert_clean()
    runtime = Path(fixture.env["XDG_RUNTIME_DIR"]) / f"nixos-capture-{os.getuid()}"
    assert not list(runtime.glob("extract.*"))
    assert not Path(fixture.env["NIXOS_SCREENSHOT_DIR"]).exists()
    print("Real multilingual OCR, sensitive QR decoding and empty-result handling passed")
finally:
    fixture.tearDown()
