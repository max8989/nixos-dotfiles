.pragma library
var MONTHS = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
function pad2(value) { return (value < 10 ? "0" : "") + value; }
function overdue(list, now) { return list.filter(function(task) { return task.due !== null && task.due <= now; }); }
function taskKey(task) { return task.projectId + "/" + task.id + "|" + task.due; }
function dayKey(date) { return date.getFullYear() + "-" + pad2(date.getMonth()+1) + "-" + pad2(date.getDate()); }
function cpuSample(text) {
    var fields = (text.split("\n")[0] || "").trim().split(/\s+/).slice(1, 9).map(Number);
    return { total: fields.reduce(function(a, b) { return a+b; }, 0), idle: (fields[3] || 0) + (fields[4] || 0) };
}
function cpuUsage(previous, next) {
    var total = next.total - previous.total;
    return total > 0 && previous.total > 0 ? Math.max(0, Math.min(100, 100*(1-(next.idle-previous.idle)/total))) : 0;
}
function memory(text) {
    var result = {};
    text.split("\n").forEach(function(line) { var m = /^(\w+):\s+(\d+)/.exec(line); if (m) result[m[1]] = Number(m[2]); });
    var total = result.MemTotal || 0;
    var used = Math.max(0, total-(result.MemAvailable || result.MemFree || 0));
    return { total: total, used: used, percent: total ? Math.round(used*100/total) : 0 };
}
function networkSample(text) {
    var result = {};
    text.split("\n").forEach(function(line) {
        var pair = line.trim().split(":");
        if (pair.length !== 2 || pair[0] === "lo") return;
        var fields = pair[1].trim().split(/\s+/).map(Number);
        if (fields.length >= 9) result[pair[0]] = {rx: fields[0], tx: fields[8]};
    });
    return result;
}
function networkRate(previous, next, seconds) {
    var rx=0, tx=0;
    Object.keys(next).forEach(function(key) {
        if (previous[key] && seconds > 0) { rx += Math.max(0,next[key].rx-previous[key].rx)/seconds; tx += Math.max(0,next[key].tx-previous[key].tx)/seconds; }
    });
    return "↓ " + bytes(rx) + "/s  ↑ " + bytes(tx) + "/s";
}
function bytes(value) { return value < 1024 ? Math.round(value)+" B" : value < 1048576 ? (value/1024).toFixed(1)+" KiB" : (value/1048576).toFixed(1)+" MiB"; }
function batteryBand(percent, onBattery, present) {
    if (!present) return "absent";
    if (!onBattery) return percent >= 99 ? "full" : "charging";
    return percent <= 10 ? "critical" : percent <= 20 ? "low" : "normal";
}
function restoreState(value) {
    if (!value || typeof value !== "object" || Array.isArray(value)) value = {};
    return { nightlight: value.nightlight === true, temperature: Math.max(2500,Math.min(6000,Number(value.temperature)||4000)), dnd: value.dnd === true,
        barHidden: value.barHidden === true, audioSink: typeof value.audioSink === "string" ? value.audioSink : "",
        audioSource: typeof value.audioSource === "string" ? value.audioSource : "",
        panelTextSize: Math.max(12, Math.min(20, Math.round(Number(value.panelTextSize) || 12))),
        monitorScales: value.monitorScales && typeof value.monitorScales === "object" && !Array.isArray(value.monitorScales) ? value.monitorScales : {},
        appLaunchCounts: restoreAppLaunchCounts(value.appLaunchCounts),
        workspaceNames: restoreWorkspaceNames(value.workspaceNames),
        folder: typeof value.folder === "string" ? value.folder : "" };
}
function validWorkspaceId(id) {
    return /^[1-9]\d*$/.test(String(id)) && Number(id) <= 2147483647;
}
function restoreWorkspaceNames(value) {
    var names = Object.create(null);
    if (value && typeof value === "object" && !Array.isArray(value)) {
        Object.keys(value).forEach(function(id) {
            if (!validWorkspaceId(id) || typeof value[id] !== "string") return;
            var name = value[id].replace(/[\u0000-\u001f\u007f]/g, " ").trim().slice(0, 80);
            if (name) names[id] = name;
        });
    }
    return names;
}
function workspaceEntries(workspaces, names) {
    var ids = Object.create(null);
    for (var id = 1; id <= 10; id++) ids[id] = true;
    Object.keys(names).forEach(function(id) { if (validWorkspaceId(id)) ids[id] = true; });
    workspaces.forEach(function(workspace) { if (validWorkspaceId(workspace.id)) ids[workspace.id] = true; });
    return Object.keys(ids).map(Number).sort(function(a, b) { return a - b; }).map(function(id) {
        return {id: id, name: names[id] || "", workspace: workspaces.find(function(workspace) { return workspace.id === id; }) || null};
    });
}
function restoreAppLaunchCounts(value) {
    var counts = Object.create(null);
    if (value && typeof value === "object" && !Array.isArray(value)) {
        Object.keys(value).forEach(function(id) {
            if (Number.isSafeInteger(value[id]) && value[id] > 0) counts[id] = value[id];
        });
    }
    return counts;
}
function rankApplications(items, counts) {
    return items.slice().sort(function(a, b) {
        return (counts[b.id] || 0) - (counts[a.id] || 0)
            || a.name.localeCompare(b.name) || a.id.localeCompare(b.id);
    });
}
function parseJson(text, fallback) { try { return JSON.parse(text); } catch (error) { return fallback; } }
function clipboardEntries(text) {
    return text.split("\n").map(function(line) {
        var match = /^(\d+)\t(.*)$/.exec(line);
        return match ? {id: match[1], title: match[2], image: /^\[\[ binary data .*\b(png|jpe?g|gif|webp|bmp|tiff)\b/i.test(match[2])} : null;
    }).filter(Boolean);
}
function clipboardThumbs(text) {
    var paths = {};
    text.split("\n").forEach(function(line) {
        var match = /^(\d+)\t(\/.+)$/.exec(line);
        if (match) paths[match[1]] = match[2];
    });
    return paths;
}
function search(items, query) {
    var tokens = query.toLocaleLowerCase().trim().split(/\s+/).filter(Boolean);
    if (!tokens.length) return items;
    var phrase = tokens.join(" ");
    return items.map(function(item, index) {
        var title = item.title.toLocaleLowerCase();
        var text = title + " " + (item.subtitle || "").toLocaleLowerCase() + " " + (item.keywords || "").toLocaleLowerCase();
        var score = title === phrase ? 0 : title.indexOf(phrase) === 0 ? 1 : tokens.every(function(token) { return title.indexOf(token) !== -1; }) ? 2 : 3;
        return {item: item, index: index, score: score, matches: tokens.every(function(token) { return text.indexOf(token) !== -1; })};
    }).filter(function(match) { return match.matches; })
        .sort(function(a, b) { return a.score - b.score || a.index - b.index; })
        .map(function(match) { return match.item; });
}

function batteryAlert(previous, band) {
    var next={low:!!previous.low,critical:!!previous.critical,full:!!previous.full};
    var alert="";
    if (band==="charging" || band==="absent") next={low:false,critical:false,full:false};
    else if (band==="full") { if (!next.full) alert="full"; next.full=true; next.low=false; next.critical=false; }
    else { next.full=false; if (band==="critical" && !next.critical) { alert="critical"; next.critical=true; next.low=true; } else if (band==="low" && !next.low) { alert="low"; next.low=true; } }
    return {state:next,alert:alert};
}
