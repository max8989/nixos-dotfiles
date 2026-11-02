function identities(value) {
    var name = String(value || "").trim().toLowerCase().replace(/\.desktop$/, "");
    return [name, name.split(".").pop()].map(function(part) {
        return part.replace(/[\s_-]/g, "");
    }).filter(function(part) { return part.length > 0; });
}

function liveClients(clients) {
    return (clients || []).filter(function(client) {
        return client && client.mapped !== false && /^0x[0-9a-f]+$/i.test(client.address);
    });
}

function notificationTarget(entry, clients) {
    if (!entry) return null;
    var live = liveClients(clients);
    var cached = live.find(function(client) { return client.address === entry.windowAddress; });
    if (entry.senderPid > 0) {
        var processWindows = live.filter(function(client) { return client.pid === entry.senderPid; });
        if (processWindows.length === 1) return processWindows[0];
    }
    if (cached) return cached;
    var sources = [entry.desktopEntry, entry.app || entry.appName];
    for (var i = 0; i < sources.length; i++) {
        var sender = identities(sources[i]);
        var matches = live.filter(function(client) {
            return [client.class, client.initialClass, client.appId].some(function(value) {
                return identities(value).some(function(identity) { return sender.indexOf(identity) >= 0; });
            });
        });
        matches.sort(function(a, b) {
            var first = a.focusHistoryID >= 0 ? a.focusHistoryID : Infinity;
            var second = b.focusHistoryID >= 0 ? b.focusHistoryID : Infinity;
            return first - second;
        });
        if (matches.length) return matches[0];
    }
    return null;
}

function bindNotificationSource(entry, pid, clients, activeAddress, locked) {
    var identified = Object.assign({}, entry, {senderPid: pid});
    var target = notificationTarget(identified, clients);
    if (!target || target.pid !== pid) return identified;
    return Object.assign(identified, {
        windowAddress: target.address,
        unread: !entry.explicitlyRead && (locked || target.address !== activeAddress)
    });
}

function workspaceState(name, clients, entries) {
    var live = liveClients(clients);
    var windows = live.filter(function(client) { return client.workspace?.name === name; });
    return {
        count: windows.length,
        urgent: windows.some(function(client) { return client.urgent; }) || (entries || []).some(function(entry) {
            var target = entry.unread ? notificationTarget(entry, live) : null;
            return target?.workspace?.name === name;
        }),
        fullscreen: windows.some(function(client) { return client.fullscreen; })
    };
}

function attentionChanges(clients, entries, activeAddress) {
    var live = liveClients(clients);
    var unread = (entries || []).filter(function(entry) { return entry.unread; }).map(function(entry) {
        return notificationTarget(entry, live)?.address;
    });
    return live.filter(function(client) {
        var attention = client.address !== activeAddress && (!!client.urgent || unread.indexOf(client.address) >= 0);
        var tagged = (client.tags || []).indexOf("quickshell-notification") >= 0;
        return attention !== tagged;
    }).map(function(client) {
        return {address: client.address, attention: (client.tags || []).indexOf("quickshell-notification") < 0};
    });
}

function defaultAction(actions) {
    return Array.prototype.find.call(actions || [], function(action) {
        return action.identifier === "default";
    }) || null;
}
