import test from 'node:test';
import assert from 'node:assert/strict';
import { releaseInfo, packagePaths, selectGameVersion, metadata, publish } from './release.mjs';

const toc = '## Interface: 16001\n## Version: 1.2.3\nMain.lua\nData/Routes.lua\n';
const notes = '# Bel Toolbox 1.2.3\n\n- Current fix.\n\n# Bel Toolbox 1.2.2\n\n- Old fix.\n';
const info = releaseInfo(toc, notes);
const config = { curseforgeProjectId: 1754497, gameVersionName: '1.60.1', requiredDependency: { slug: 'ellesmereui', projectID: '1477613', type: 'requiredDependency' } };

test('only stable matching versions release, with only this version changelog', () => {
  assert.equal(info.tag, 'v1.2.3');
  assert.match(info.notes, /Current fix/);
  assert.doesNotMatch(info.notes, /Old fix/);
  assert.throws(() => releaseInfo(toc.replace('1.2.3', '1.2.3-dev'), notes), /stable/);
  assert.throws(() => releaseInfo(toc, notes.replace('1.2.3', '1.2.4')), /heading/);
  assert.throws(() => releaseInfo(toc, '# Bel Toolbox 1.2.3\n'), /non-empty/);
});

test('package excludes automation, local data and developer files; every TOC entry exists', () => {
  const paths = ['BelToolbox.toc', 'Main.lua', 'Data/Routes.lua', 'Media/Logo.tga', 'LICENSE', 'THIRD_PARTY_NOTICES.md', '.github/workflows/release.yml', 'AGENTS.md', 'WTF/Secrets.lua', 'work/test.lua'];
  const result = packagePaths(paths, toc);
  assert.deepEqual(result, ['BelToolbox.toc', 'Data/Routes.lua', 'LICENSE', 'Main.lua', 'Media/Logo.tga', 'THIRD_PARTY_NOTICES.md']);
  assert.throws(() => packagePaths(paths.filter(p => p !== 'Main.lua'), toc), /TOC entry/);
});

test('CF receives exact client, EUI required dependency and identical Markdown notes', () => {
  assert.equal(selectGameVersion([{ name: '12.1.0', id: 1 }, { name: '1.60.1', id: 42 }], '1.60.1'), 42);
  assert.throws(() => selectGameVersion([], '1.60.1'), /exactly one/);
  assert.throws(() => selectGameVersion([{ name: '1.60.1', id: 1 }, { name: '1.60.1', id: 2 }], '1.60.1'), /exactly one/);
  assert.equal(selectGameVersion([{ name: '1.60.1', id: 1, gameVersionTypeID: 517 }, { name: '1.60.1', id: 2, gameVersionTypeID: 88568 }], '1.60.1', 88568), 2);
  const data = metadata(config, info, 42);
  assert.equal(data.changelog, info.notes);
  assert.equal(data.changelogType, 'markdown');
  assert.deepEqual(data.gameVersions, [42]);
  assert.equal(data.relations.projects[0].type, 'requiredDependency');
});

function harness({ cfFailure = false, published = false, receipt = false, uncertain = false, conflict = false } = {}) {
  const calls = [];
  const assets = [];
  const state = { id: 7, tag_name: info.tag, draft: !published };
  const archive = Buffer.from('ZIP bytes');
  const manifest = { commit: 'abc', sha256: 'test-hash', projectId: 1754497, filename: 'BelToolbox-1.2.3.zip' };
  if (receipt || uncertain || published) assets.push({ name: 'release-manifest.json', id: 1 });
  if (receipt) assets.push({ name: 'curseforge-upload.json', id: 2 });
  if (uncertain) assets.push({ name: 'curseforge-upload-started.json', id: 3 });
  const request = async (url, opts = {}) => {
    calls.push({ url, ...opts });
    if (url.endsWith('/api/game/wow/versions')) return [{ name: '1.60.1', id: 42 }];
    if (url.includes('/git/ref/')) return conflict ? { object: { type: 'commit', sha: 'other' } } : null;
    if (url.includes('/releases?')) return receipt || uncertain || published ? [state] : [];
    if (url.endsWith('/releases') && opts.method === 'POST') {
      assert.equal(JSON.parse(opts.body).body, info.notes);
      assert.equal(JSON.parse(opts.body).draft, true);
      return state;
    }
    if (url.includes('/assets?per_page')) return [...assets];
    if (url.startsWith('https://uploads.github.com/')) {
      const name = new URL(url).searchParams.get('name');
      const asset = { id: assets.length + 10, name };
      assets.push(asset);
      return asset;
    }
    if (url.endsWith('/upload-file')) {
      if (cfFailure) throw new Error('HTTP 503');
      assert.equal(opts.body.get('file').size, archive.length);
      assert.equal(JSON.parse(opts.body.get('metadata')).changelog, info.notes);
      return { id: 999 };
    }
    if (opts.method === 'PATCH') return { ...state, draft: false };
    throw new Error(`Unexpected test request ${url}`);
  };
  const raw = async url => ({ ok: true, json: async () => url.endsWith('/2') ? { projectId: 1754497, sha256: manifest.sha256, fileId: 999 } : manifest });
  return { calls, request, raw, bundle: { config, info, manifest, archive } };
}
const env = { GITHUB_REF: 'refs/heads/main', GITHUB_REPOSITORY: 'vickyhoo/BelToolbox', GH_TOKEN: 'fake-gh', CF_API_TOKEN: 'fake-cf' };

test('publishing never runs from dev or without secrets', async () => {
  const h = harness();
  await assert.rejects(publish(h.bundle, { ...env, GITHUB_REF: 'refs/heads/dev' }, h.request), /only from main/);
  await assert.rejects(publish(h.bundle, { ...env, CF_API_TOKEN: '' }, h.request), /required/);
  assert.equal(h.calls.length, 0);
});

test('one CF upload; GH publishes only after receipt; CF failure keeps draft', async () => {
  const h = harness();
  await publish(h.bundle, env, h.request);
  const post = h.calls.findIndex(c => c.url.endsWith('/upload-file'));
  const saved = h.calls.findIndex(c => c.url.includes('name=curseforge-upload.json'));
  const published = h.calls.findIndex(c => c.method === 'PATCH');
  assert.ok(post >= 0 && saved > post && published > saved);
  assert.equal(h.calls.filter(c => c.url.endsWith('/upload-file')).length, 1);
  const failure = harness({ cfFailure: true });
  await assert.rejects(publish(failure.bundle, env, failure.request), /503/);
  assert.ok(!failure.calls.some(c => c.method === 'PATCH'));
  assert.equal(failure.calls.filter(c => c.url.endsWith('/upload-file')).length, 1);
});

test('receipt avoids repeat CF upload, uncertain attempt blocks duplicates, tags cannot change', async t => {
  const h = harness({ receipt: true });
  t.mock.method(globalThis, 'fetch', h.raw);
  await publish(h.bundle, env, h.request);
  assert.ok(!h.calls.some(c => c.url.endsWith('/upload-file')));
  const uncertain = harness({ uncertain: true });
  await assert.rejects(publish(uncertain.bundle, env, uncertain.request), /uncertain result/);
  assert.ok(!uncertain.calls.some(c => c.url.endsWith('/upload-file')));
  const conflict = harness({ conflict: true });
  await assert.rejects(publish(conflict.bundle, env, conflict.request), /another commit/);
});
