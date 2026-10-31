import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const model = vm.createContext({});
vm.runInContext(fs.readFileSync(process.argv[2], 'utf8'), model);
const window = (address, rank, workspace, extra = {}) => ({
    address, focusHistoryID: rank, workspace, mapped: true, hidden: false,
    title: address, class: 'kitty', ...extra,
});
const clients = [
    window('0xa', 2, {id: 1, name: '1'}),
    window('0xb', 0, {id: 2, name: '2'}),
    window('0xc', 1, {address: 'special:magic', type: 'special', name: 'special:magic'}),
    window('0xd', 3, {address: 'chat', type: 'normal', name: 'chat'}),
    window('0xe', -1, {}),
    window('0xf', 4, {}, {mapped: false}),
    window('0x10', 5, {}, {hidden: true}),
    window('invalid', 6, {}),
];
const history = JSON.parse(JSON.stringify(model.snapshot(clients)));
assert.deepEqual(history.map(w => w.address), ['0xb', '0xc', '0xa', '0xd']);
assert.equal(history[1].workspace, 'special:magic');
assert.equal(history[3].workspace, 'chat');
assert.equal(clients[0].address, '0xa', 'sorting must not mutate compositor data');
assert.equal(model.advance(0, 1, history.length), 1, 'first Alt-Tab selects previous window');
assert.equal(model.advance(0, -1, history.length), 3, 'reverse wraps');
assert.equal(model.advance(3, 2, history.length), 1, 'queued taps wrap');
assert.equal(model.advance(0, 1, 1), 0);
assert.equal(model.advance(0, 1, 0), -1);
assert.equal(model.snapshot(null).length, 0);
console.log('Window history: MRU order, special/named workspaces, filtering and cycling passed');
