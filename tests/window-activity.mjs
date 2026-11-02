import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const model = vm.createContext({});
vm.runInContext(fs.readFileSync(process.argv[2], 'utf8'), model);
const window = (address, app, workspace, rank = 0, extra = {}) => ({
    address, class: app, initialClass: app, appId: app,
    workspace: {name: workspace}, focusHistoryID: rank,
    mapped: true, hidden: false, urgent: false, fullscreen: false, ...extra,
});
const state = (workspace, clients, entries = []) =>
    JSON.parse(JSON.stringify(model.workspaceState(workspace, clients, entries)));
const freeze = value => {
    if (value && typeof value === 'object') {
        Object.values(value).forEach(freeze);
        Object.freeze(value);
    }
    return value;
};

// A notification targets the most recently focused matching live app window.
const discordOld = window('0xa', 'discord', '2', 4);
const discordRecent = window('0xb', 'discord', 'chat', 1);
const discordUnknown = window('0xc', 'discord', '1', -1);
const discordUnmapped = window('0xd', 'discord', '2', 0, {mapped: false});
const discordHidden = window('0xe', 'discord', 'special:magic', 2, {hidden: true});
const clients = freeze([
    discordOld, discordRecent, discordUnknown, discordUnmapped, discordHidden,
    window('0xf', 'kitty', '1', 0),
]);
const discord = freeze({app: 'Discord', desktopEntry: 'discord.desktop', unread: true});
assert.equal(model.notificationTarget(discord, clients), discordRecent,
    'use app focus history, excluding unmapped clients and unknown focus ranks');
assert.equal(model.notificationTarget({...discord, windowAddress: '0xa'}, clients), discordOld,
    'a still-live cached target wins over the most recent app window');
assert.equal(model.notificationTarget({...discord, windowAddress: '0xdead'}, clients), discordRecent,
    'a closed cached target falls back to the most recent live app window');
assert.equal(model.notificationTarget({...discord, windowAddress: '0xd'}, clients), discordRecent,
    'an unmapped cached target is no longer a live target');
assert.equal(model.notificationTarget(discord, [discordHidden]), discordHidden,
    'scratchpad and other hidden app windows remain accessible');
assert.equal(model.notificationTarget(discord, [discordUnmapped]), null);
assert.equal(model.notificationTarget(null, clients), null);
assert.equal(model.notificationTarget({}, clients), null);
assert.equal(model.notificationTarget(discord, []), null);
assert.equal(model.notificationTarget(discord, null), null);

// Match stable app identities, including desktop suffixes and reverse-domain IDs.
assert.equal(model.notificationTarget({desktopEntry: 'DISCORD.DESKTOP'}, clients), discordRecent);
assert.equal(model.notificationTarget({desktopEntry: 'com.discordapp.Discord.desktop'}, clients),
    discordRecent, 'the final segment of a reverse-domain desktop ID identifies the app');
assert.equal(model.notificationTarget({appName: 'Discord'}, clients), discordRecent,
    'notification app names are a fallback when desktop entries are absent');
assert.equal(model.notificationTarget({app: 'Discord', desktopEntry: 'missing-app'}, clients),
    discordRecent, 'app-name fallback also works when a desktop entry has no live match');
const initialClass = window('0x10', 'renamed-window', '2', 0,
    {initialClass: 'discord', appId: ''});
assert.equal(model.notificationTarget(discord, [initialClass]), initialClass);
const appId = window('0x11', 'unrelated-class', '2', 0,
    {initialClass: '', appId: 'Com.TickTick.TickTick'});
assert.equal(model.notificationTarget({desktopEntry: 'com.ticktick.ticktick.desktop'}, [appId]), appId);
assert.equal(model.notificationTarget({app: 'TickTick'}, [appId]), appId);
const titleOnly = window('0x12', 'kitty', '2', 0, {title: 'Discord'});
const partialClass = window('0x13', 'discord-canary', '2');
assert.equal(model.notificationTarget(discord, [titleOnly, partialClass]), null,
    'window titles and arbitrary class substrings must not redirect to unrelated windows');
assert.equal(model.notificationTarget({app: 'zen'}, [window('0x14', 'zenity', '2')]), null);
assert.deepEqual(clients.map(client => client.address), ['0xa', '0xb', '0xc', '0xd', '0xe', '0xf'],
    'matching must not reorder compositor data');

// Workspace attention follows unread notifications and native urgency.
const workspaceClients = freeze([
    window('0x20', 'discord', '2', 0),
    window('0x21', 'kitty', '2', 1, {fullscreen: true}),
    window('0x22', 'kitty', '2', 2, {mapped: false, urgent: true, fullscreen: true}),
    window('0x23', 'ticktick', 'special:magic', 3, {hidden: true}),
    window('0x24', 'kitty', 'chat', 4, {urgent: true}),
]);
const unread = freeze([{
    app: 'Discord', windowAddress: '0x20', unread: true, notification: {},
}]);
assert.deepEqual(state('2', workspaceClients, unread), {count: 2, urgent: true, fullscreen: true});
assert.deepEqual(state('2', workspaceClients, [{...unread[0], unread: false}]),
    {count: 2, urgent: false, fullscreen: true}, 'reading clears notification attention');
assert.deepEqual(state('2', workspaceClients, [{...unread[0], notification: null}]),
    {count: 2, urgent: true, fullscreen: true}, 'expired popups remain unread until visited');
assert.deepEqual(state('chat', workspaceClients), {count: 1, urgent: true, fullscreen: false},
    'native urgency works without a notification');
assert.deepEqual(state('special:magic', workspaceClients, [{app: 'TickTick', unread: true}]),
    {count: 1, urgent: true, fullscreen: false}, 'named scratchpads retain hidden window attention');
assert.deepEqual(state('1', workspaceClients, unread), {count: 0, urgent: false, fullscreen: false});
assert.deepEqual(state('2', null, null), {count: 0, urgent: false, fullscreen: false});
assert.deepEqual(state('2', [workspaceClients[2]], unread),
    {count: 0, urgent: false, fullscreen: false}, 'unmapped clients contribute no workspace state');

// Never leave notification attention behind after the target moves or closes.
const movedClients = freeze(workspaceClients.map(client => client.address === '0x20'
    ? {...client, workspace: {name: 'work'}} : client));
assert.deepEqual(state('2', movedClients, unread), {count: 1, urgent: false, fullscreen: true});
assert.deepEqual(state('work', movedClients, unread), {count: 1, urgent: true, fullscreen: false});
const closedClients = freeze(workspaceClients.filter(client => client.address !== '0x20'));
assert.deepEqual(state('2', closedClients, unread), {count: 1, urgent: false, fullscreen: true});
const replacedClients = freeze([...closedClients, window('0x25', 'discord', 'replacement', 0)]);
assert.deepEqual(state('2', replacedClients, unread), {count: 1, urgent: false, fullscreen: true});
assert.deepEqual(state('replacement', replacedClients, unread),
    {count: 1, urgent: true, fullscreen: false});

// Window borders use the same unread/native attention and clear on focus.
const attentionTag = 'quickshell-notification';
const changes = (clients, entries = [], active = '') =>
    JSON.parse(JSON.stringify(model.attentionChanges(clients, entries, active)));
assert.deepEqual(changes(workspaceClients, unread, '0x21'), [
    {address: '0x20', attention: true}, {address: '0x24', attention: true},
]);
assert.deepEqual(changes(workspaceClients, [...unread, ...unread], '0x20'),
    [{address: '0x24', attention: true}], 'the active sender never receives an attention border');
const taggedClients = freeze(workspaceClients.map(client => client.address === '0x20'
    ? {...client, tags: ['personal-tag', attentionTag]} : client));
assert.deepEqual(changes(taggedClients, unread), [{address: '0x24', attention: true}],
    'an existing attention border does not need another compositor update');
assert.deepEqual(changes(taggedClients, [{...unread[0], notification: null}]),
    [{address: '0x24', attention: true}], 'popup expiry keeps the border');
assert.deepEqual(changes(taggedClients, unread, '0x20'), [
    {address: '0x20', attention: false}, {address: '0x24', attention: true},
], 'focus removes the border even before the notification is marked read');
assert.deepEqual(changes(taggedClients, [{...unread[0], unread: false}]), [
    {address: '0x20', attention: false}, {address: '0x24', attention: true},
], 'reading removes notification borders and preserves other urgent windows');
assert.deepEqual(changes(taggedClients, [], '0x24'), [{address: '0x20', attention: false}],
    'clearing history or restarting the shell removes stale attention tags');
assert.deepEqual(changes(movedClients, unread), changes(workspaceClients, unread),
    'moving a window keeps its border and moves the workspace marker');
assert.deepEqual(changes(closedClients, unread), [{address: '0x24', attention: true}],
    'closed and unmapped windows never receive tag commands');
assert.deepEqual(changes(workspaceClients, [{app: 'TickTick', unread: true}], '0x24'),
    [{address: '0x23', attention: true}], 'hidden scratchpad senders get attention borders');
assert.deepEqual(changes(null, null), []);
assert.deepEqual(taggedClients[0].tags, ['personal-tag', attentionTag],
    'attention reconciliation must not change unrelated window tags');

// Notification-body clicks must never run an arbitrary first action.
const deleteAction = freeze({identifier: 'delete', text: 'Delete'});
const defaultAction = freeze({identifier: 'default', text: 'Open'});
const actions = freeze([deleteAction, defaultAction]);
assert.equal(model.defaultAction(actions), defaultAction);
assert.equal(model.defaultAction([deleteAction]), null,
    'a non-default action may be destructive and must not run from a body click');
assert.equal(model.defaultAction([]), null);
assert.equal(model.defaultAction(null), null);

console.log('Window activity: app targets, unread/native attention, moved/hidden/fullscreen windows and safe default actions passed');
