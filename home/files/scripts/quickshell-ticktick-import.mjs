#!@node@
// Import only the configured owner's saved authorization, without logging it.
import { createDecipheriv, randomUUID } from 'node:crypto';
import { mkdirSync, writeFileSync, renameSync, rmSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

let temporary;
try {
    if (process.argv.length !== 3) throw new Error('Pass the Personal Agent repository directory.');
    const remote = /^([a-zA-Z0-9_.@-]+):(\/.*)$/.exec(process.argv[2]);
    const source = remote ? remote[2] : resolve(process.argv[2]);
    const script = `
import json, shlex, sqlite3, sys
from pathlib import Path
source = Path(${JSON.stringify(source)})
env = {}
for line in (source / '.env').read_text().splitlines():
    for item in shlex.split(line, comments=True):
        if '=' in item:
            key, value = item.split('=', 1)
            env[key] = value
path = (source / 'pocketbase/pb_data/data.db').resolve().as_uri() + '?mode=ro'
db = sqlite3.connect(path, uri=True)
rows = db.execute('SELECT i.data FROM integrations i JOIN users u ON u.id=i.owner WHERE u.email=? AND i.key=?', (env['OWNER_EMAIL'], 'ticktick')).fetchall()
if len(rows) != 1: sys.exit(1)
print(json.dumps({'token': json.loads(rows[0][0])['token'], 'key': env['TOKEN_ENCRYPTION_KEY']}))
`;
    const result = remote
        ? spawnSync('@ssh@', ['-o', 'BatchMode=yes', '-o', 'ConnectTimeout=8', '--', remote[1], 'python3 -'], { input: script, encoding: 'utf8', timeout: 20000 })
        : spawnSync('@python@', ['-c', script], { encoding: 'utf8', timeout: 10000 });
    if (result.status !== 0)
        throw new Error('Connect TickTick in Personal Agent Profile first; no saved connection was found for OWNER_EMAIL.');
    let token;
    try {
        const saved = JSON.parse(result.stdout);
        const encrypted = Buffer.from(saved.token, 'base64');
        const decipher = createDecipheriv('aes-256-gcm', Buffer.from(saved.key, 'base64'), encrypted.subarray(0, 12));
        decipher.setAuthTag(encrypted.subarray(12, 28));
        token = Buffer.concat([decipher.update(encrypted.subarray(28)), decipher.final()]).toString('utf8');
        if (!token || /\s/.test(token)) throw new Error();
    } catch {
        throw new Error('Could not decrypt the saved connection with this Personal Agent configuration.');
    }
    const directory = join(process.env.XDG_CONFIG_HOME || join(homedir(), '.config'), 'quickshell');
    mkdirSync(directory, { recursive: true, mode: 0o700 });
    temporary = join(directory, '.ticktick-' + randomUUID());
    writeFileSync(temporary, JSON.stringify({ accessToken: token }) + '\n', { flag: 'wx', mode: 0o600 });
    renameSync(temporary, join(directory, 'ticktick.json'));
    temporary = undefined;
    console.log('TickTick connection imported. Refresh the reminders menu.');
} catch (error) {
    // Filesystem/crypto errors may contain values from private inputs.
    const safe = ['Pass the Personal Agent', 'Personal Agent needs', 'Connect TickTick in', 'Could not decrypt'];
    console.error(safe.some(prefix => error.message.startsWith(prefix)) ? error.message : 'Could not import the TickTick connection. Check the local files and permissions.');
    process.exitCode = 1;
} finally {
    if (temporary) rmSync(temporary, { force: true });
}
