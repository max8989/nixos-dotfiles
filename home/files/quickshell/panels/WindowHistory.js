// Workspace identity is a label: named/special workspaces need no numeric ID.
function snapshot(clients) {
    if (!Array.isArray(clients)) return [];
    return clients.filter(c => c.mapped && !c.hidden
        && /^0x[0-9a-f]+$/i.test(c.address)
        && Number.isInteger(c.focusHistoryID) && c.focusHistoryID >= 0)
        .sort((a, b) => a.focusHistoryID - b.focusHistoryID)
        .map(c => ({address: c.address, title: c.title || c.class || "Window",
            app: c.class || "Application", workspace: c.workspace?.name || ""}));
}

function advance(index, delta, count) {
    return count ? ((index + delta) % count + count) % count : -1;
}
