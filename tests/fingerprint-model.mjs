import assert from "node:assert/strict";
import fs from "node:fs";
import vm from "node:vm";

const model = vm.createContext({});
vm.runInContext(fs.readFileSync(process.argv[2], "utf8"), model);

assert.equal(model.enrollment("found 1 devices\n - #0: right-index-finger\n"), "enrolled");
assert.equal(model.enrollment("User alice has no fingers enrolled for Synaptics Sensors."), "empty");
assert.equal(model.enrollment("No devices available"), "empty");
assert.equal(model.enrollment("found 0 devices"), "empty");
for (const message of ["", "D-Bus error: service unavailable", "ListEnrolledFingers failed", "found 1 devices"])
    assert.equal(model.enrollment(message), "unknown", message);

assert.equal(model.retryDelay(0), 250);
assert.equal(model.retryDelay(1), 1000);
assert.equal(model.retryDelay(2), 2000);
assert.equal(model.retryDelay(3), 4000);
assert.equal(model.retryDelay(6), 32000);
assert.equal(model.retryDelay(7), 40000);
assert.equal(model.retryDelay(10000), 40000);
console.log("Fingerprint enrollment states and bounded retry pacing passed");
