import assert from "node:assert/strict";
import fs from "node:fs";
import vm from "node:vm";
const context = vm.createContext({});
vm.runInContext(fs.readFileSync(process.argv[2], "utf8").replace(/^\.pragma library\s*/, ""), context);
const plain = value => JSON.parse(JSON.stringify(value));
assert.deepEqual(plain(context.todos("- [ ] one\n* [ ] [[a|Two]]\n- [x] done\n- [ ]   \n  - [ ] [[note]]\ntext")), ["one","Two","note"]);
const before = context.cpuSample("cpu 10 0 20 70 0 0 0 0 50 0\ncpu0 1 2 3");
const after = context.cpuSample("cpu 20 0 30 150 0 0 0 0 50 0");
assert.ok(Math.abs(context.cpuUsage(before,after)-20)<0.0001);
assert.equal(context.cpuUsage(after,before),0);
assert.equal(context.memory("MemTotal: 1000 kB\nMemAvailable: 600 kB\nMemFree: 200 kB").percent,40);
assert.equal(context.memory("").percent,0);
assert.equal(context.batteryBand(9,true,true),"critical");
assert.equal(context.batteryBand(20,true,true),"low");
assert.equal(context.batteryBand(21,true,true),"normal");
assert.equal(context.batteryBand(10,false,true),"charging");
assert.equal(context.batteryBand(100,false,true),"full");
assert.equal(context.batteryBand(0,true,false),"absent");
assert.equal(context.restoreState({temperature:9000,nightlight:"true",folder:8}).temperature,6000);
assert.equal(context.restoreState({nightlight:"true"}).nightlight,false);
assert.equal(context.restoreState({folder:8}).folder,"");
assert.equal(context.restoreState(null).folder,"");
assert.equal(context.restoreState([]).nightlight,false);
assert.equal(context.restoreState("broken").temperature,4000);
assert.deepEqual(plain(context.parseJson("broken",{})),{});
assert.equal(context.search([{title:"中文 test",subtitle:"note"}],"中文 note").length,1);
assert.deepEqual(plain(context.clipboardEntries("17\t  keep spaces  \n16\t[[ binary data 4 KiB png 20x20 ]]\ninvalid\nX\tbad key\n15\t中文\twith tab\n")), [
    {id:"17", title:"  keep spaces  ", image:false},
    {id:"16", title:"[[ binary data 4 KiB png 20x20 ]]", image:true},
    {id:"15", title:"中文\twith tab", image:false},
]);
assert.deepEqual(plain(context.clipboardEntries("")), []);
const network=context.networkSample("wlan0: 100 0 0 0 0 0 0 0 200 0 0 0\nlo: 999 0 0 0 0 0 0 0 999");
assert.deepEqual(plain(network),{wlan0:{rx:100,tx:200}});
assert.equal(context.networkRate(network,{wlan0:{rx:300,tx:400}},2),"↓ 100 B/s  ↑ 100 B/s");
console.log("Quickshell parsing, state recovery, metrics and search assertions passed");

let alert=context.batteryAlert({},"low");
assert.equal(alert.alert,"low");
assert.equal(context.batteryAlert(alert.state,"low").alert,"");
alert=context.batteryAlert(alert.state,"critical");
assert.equal(alert.alert,"critical");
assert.equal(context.batteryAlert(alert.state,"low").alert,"");
alert=context.batteryAlert(alert.state,"charging");
assert.equal(context.batteryAlert(alert.state,"critical").alert,"critical");
console.log("Battery threshold hysteresis and charging reset passed");
