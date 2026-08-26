// Reproducible vendoring of MapLibre GL JS/CSS/License into web/vendor/maplibre-gl/.
//
// The committed assets must match the pinned version and SHA-256 below. Running this
// script re-downloads the pinned release and VERIFIES each file against the committed
// checksums, so an upstream change or corrupted download fails loudly instead of
// silently replacing the vendored files.
//
// Usage:
//   node tool/update_maplibre_vendor.mjs            # verify + (re)write pinned files
//   node tool/update_maplibre_vendor.mjs --check    # verify only, no writes
//
// Upgrade: bump VERSION, replace the sha256 entries with the real hashes of the new
// release (https://unpkg.com/maplibre-gl@VERSION/dist/...), then run this script.

import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const VERSION = '5.24.0';

const FILES = [
  {
    name: 'maplibre-gl.js',
    url: `https://unpkg.com/maplibre-gl@${VERSION}/dist/maplibre-gl.js`,
    sha256: '45a9b07a9189ce56054c620a947ccf41e291e58c95e9b61533b740aaa65ee5cb',
  },
  {
    name: 'maplibre-gl.css',
    url: `https://unpkg.com/maplibre-gl@${VERSION}/dist/maplibre-gl.css`,
    sha256: 'ab1e70d59ec40465bae7e7030da2f3ccf28133fd502e62bd598eefbadfd7a732',
  },
  {
    name: 'LICENSE.txt',
    url: `https://unpkg.com/maplibre-gl@${VERSION}/LICENSE.txt`,
    sha256: 'ee5fc05a0677eaf69601d2c7db0d9ecd6cc27c3abc1d0733bc9ed34707cf8ef2',
  },
];

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const vendorDir = join(repoRoot, 'web', 'vendor', 'maplibre-gl');

function sha256Hex(buffer) {
  return createHash('sha256').update(buffer).digest('hex');
}

async function checkOnly() {
  let ok = true;
  for (const file of FILES) {
    const path = join(vendorDir, file.name);
    const existing = await readFile(path).catch(() => null);
    const actual = existing ? sha256Hex(existing) : '';
    const match = actual === file.sha256;
    console.log(`${match ? 'ok  ' : 'FAIL'} ${file.name}  ${actual}`);
    if (!match) ok = false;
  }
  if (!ok) {
    console.error('\nVendored MapLibre files do not match the pinned checksums.');
    process.exit(1);
  }
  console.log('\nAll vendored MapLibre files match the pinned checksums.');
}

async function update() {
  await mkdir(vendorDir, { recursive: true });
  for (const file of FILES) {
    const res = await fetch(file.url);
    if (!res.ok) {
      throw new Error(`failed to download ${file.url}: HTTP ${res.status}`);
    }
    const buffer = Buffer.from(await res.arrayBuffer());
    const actual = sha256Hex(buffer);
    if (actual !== file.sha256) {
      throw new Error(
        `checksum mismatch for ${file.name}: expected ${file.sha256}, got ${actual}. ` +
          'Refusing to overwrite the vendored asset.',
      );
    }
    const path = join(vendorDir, file.name);
    await writeFile(path, buffer);
    console.log(`wrote ${path} (${buffer.length} bytes)`);
  }
  console.log('\nVendored MapLibre assets are up to date.');
}

const check = process.argv.includes('--check');
if (check) {
  await checkOnly();
} else {
  await update();
}
