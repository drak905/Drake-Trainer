// Extract selected source files from a local ASAR copy without executing them.
// Usage: node snapshot.cjs <analysis directory containing app.asar>
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const root = path.resolve(process.argv[2]);
const archive = fs.readFileSync(path.join(root, 'app.asar'));
const hash = data => crypto.createHash('sha256').update(data).digest('hex');
const headerSize = archive.readUInt32LE(4);
const jsonSize = archive.readUInt32LE(12);
if (archive.readUInt32LE(0) !== 4 || jsonSize > headerSize - 8 || 8 + headerSize > archive.length) {
  throw new Error('Unexpected ASAR header');
}
const header = JSON.parse(archive.toString('utf8', 16, 16 + jsonSize));
const output = path.join(root, 'extracted');
fs.mkdirSync(output, { recursive: true });
const manifest = [];

function walk(node, prefix = '') {
  for (const [name, entry] of Object.entries(node.files || {})) {
    if (!name || name === '.' || name === '..' || /[\\/:]/.test(name)) {
      throw new Error(`Unsafe archive entry: ${name}`);
    }
    const relative = prefix + name;
    if (entry.files) { walk(entry, relative + '/'); continue; }
    const record = { path: relative, size: entry.size, unpacked: !!entry.unpacked };
    manifest.push(record);
    if (entry.link || entry.unpacked || !/\.(js|json|html|map|proto)$/i.test(name)) continue;
    const start = 8 + headerSize + Number(entry.offset);
    const end = start + entry.size;
    if (!Number.isSafeInteger(start) || !Number.isSafeInteger(end) || start < 8 + headerSize || end > archive.length) {
      throw new Error(`Invalid archive range: ${relative}`);
    }
    const target = path.resolve(output, relative);
    if (!target.startsWith(output + path.sep)) throw new Error(`Unsafe destination: ${relative}`);
    const data = archive.subarray(start, end);
    record.sha256 = hash(data);
    record.archiveOffset = start;
    fs.mkdirSync(path.dirname(target), { recursive: true });
    // Exclusive creation prevents overwriting existing analysis work.
    fs.writeFileSync(target, data, { flag: 'wx' });
  }
}
walk(header);
const binaries = [];
function binaryManifest(directory) {
  for (const item of fs.readdirSync(directory, { withFileTypes: true })) {
    const full = path.join(directory, item.name);
    if (item.isDirectory()) binaryManifest(full);
    else if (item.isFile()) {
      const bytes = fs.readFileSync(full);
      binaries.push({ path: path.relative(root, full), size: bytes.length, sha256: hash(bytes) });
    }
  }
}
for (const name of ['trainerlib', 'auxiliary']) binaryManifest(path.join(root, name));
const result = { archiveSha256: hash(archive), archiveBytes: archive.length, files: manifest, binaries };
fs.writeFileSync(path.join(root, 'manifest.json'), JSON.stringify(result, null, 2), { flag: 'wx' });
console.log(JSON.stringify({ root, archiveSha256: result.archiveSha256, entries: manifest.length,
  extracted: manifest.filter(x => x.sha256).length, binaries: binaries.length }));
