// Enrollment probing and retry pacing follow Omarchy's FingerprintModel:
// https://github.com/omacom/omarchy/blob/quattro/shell/plugins/lock/FingerprintModel.js
// A transport error is unknown, not proof that enrollment was removed.
function enrollment(text) {
    var output = String(text || "").trim();
    if (/^[ \t]*-[ \t]*#[0-9]+:/m.test(output))
        return "enrolled";
    if (/has no fingers enrolled|no devices available|found 0 devices/i.test(output))
        return "empty";
    return "unknown";
}

function retryDelay(errors) {
    if (errors <= 0)
        return 250;
    // The upper bound leaves fprintd its 30-second idle-exit window when a
    // device is wedged, instead of continuously reclaiming the reader.
    return 1000 * Math.min(40, Math.pow(2, Math.min(errors - 1, 6)));
}
