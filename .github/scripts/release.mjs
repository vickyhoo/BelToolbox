import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { mkdirSync, writeFileSync, appendFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../../', import.meta.url));
const git = (...args) => execFileSync('git', args, { cwd: root });
const committed = path => git('show', `HEAD:${path}`).toString('utf8');
const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');
function requireThat(condition, message) { if (!condition) throw new Error(message); }

export function releaseInfo(toc, changelog) {
  const version = toc.match(/^## Version:\s*(\S+)\s*$/m)?.[1];
  requireThat(/^\d+\.\d+\.\d+$/.test(version || ''), 'Set a stable x.y.z TOC version before merging to main; development versions cannot be released.');
  const first = changelog.trimStart().split(/\r?\n/)[0];
  requireThat(first === `# Bel Toolbox ${version}`, 'The first CHANGELOG.md heading must match the TOC release version.');
  const notes = changelog.trimStart().split(/\r?\n(?=# )/)[0].trim() + '\n';
  requireThat(/^[-*] /m.test(notes), 'The current release needs non-empty changelog entries.');
  return { version, tag: `v${version}`, notes };
}

export function packagePaths(paths, toc) {
  const selected = paths.filter(p => /^[^/]+\.(lua|toc)$/.test(p) || /^(Data|Media)\//.test(p)
    || ['LICENSE', 'THIRD_PARTY_NOTICES.md', 'README.md', 'CHANGELOG.md'].includes(p));
  for (const name of ['BelToolbox.toc', 'Media/Logo.tga', 'LICENSE', 'THIRD_PARTY_NOTICES.md']) {
    requireThat(selected.includes(name), `Required package file missing: ${name}`);
  }
  for (const line of toc.split(/\r?\n/).map(s => s.trim()).filter(s => s && !s.startsWith('#'))) {
    requireThat(selected.includes(line.replaceAll('\\', '/')), `TOC entry missing from package: ${line}`);
  }
  return selected.sort();
}

export function selectGameVersion(versions, name, typeId) {
  const matches = versions.filter(v => v.name === name && Number.isInteger(v.id) && (typeId === undefined || v.gameVersionTypeID === typeId));
  requireThat(matches.length === 1, `Expected exactly one CurseForge game version named ${name}; found ${matches.length}. Update release-config.json rather than guessing a different client.`);
  return matches[0].id;
}

export function metadata(config, info, gameVersionId) {
  requireThat(Number.isInteger(config.requiredDependency.projectID), 'CF dependency projectID must be an integer.');
  return {
    displayName: `Bel Toolbox ${info.version}`,
    changelog: info.notes, changelogType: 'markdown', releaseType: 'release',
    gameVersions: [gameVersionId],
    relations: { projects: [config.requiredDependency] },
  };
}

export function build() {
  const config = JSON.parse(committed('.github/release-config.json'));
  const toc = committed('BelToolbox.toc');
  const info = releaseInfo(toc, committed('CHANGELOG.md'));
  requireThat(toc.match(/^## Interface:\s*(\S+)/m)?.[1] === config.interface, 'TOC Interface and release config differ.');
  requireThat(toc.match(/^## Dependencies:\s*(.+)/m)?.[1].trim() === 'EllesmereUI', 'EllesmereUI must remain a required TOC dependency.');
  const paths = packagePaths(git('ls-tree', '-r', '--name-only', 'HEAD').toString().trim().split('\n'), toc);
  const commit = git('rev-parse', 'HEAD').toString().trim();
  const archive = git('archive', '--format=zip', '--prefix=BelToolbox/', 'HEAD', '--', ...paths);
  const directory = resolve(root, '.release');
  mkdirSync(directory, { recursive: true });
  const filename = `BelToolbox-${info.version}.zip`;
  writeFileSync(resolve(directory, filename), archive);
  writeFileSync(resolve(directory, 'RELEASE_NOTES.md'), info.notes);
  const manifest = { ...info, commit, filename, sha256: sha256(archive), projectId: config.curseforgeProjectId };
  writeFileSync(resolve(directory, 'release-manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
  writeFileSync(resolve(directory, 'SHA256SUMS.txt'), `${manifest.sha256}  ${filename}\n`);
  console.log(`Validated ${info.tag}: ${paths.length} files, ${archive.length} bytes, root BelToolbox/.`);
  return { config, info, manifest, archive, directory };
}

async function jsonRequest(url, { allow404 = false, ...options } = {}) {
  const response = await fetch(url, { ...options, redirect: 'error', signal: AbortSignal.timeout(120000) });
  if (allow404 && response.status === 404) return null;
  // Only expose the API's error message, with tokens redacted; never print headers or raw bodies.
  if (!response.ok) {
    let detail = '';
    try {
      const body = await response.json();
      detail = String(body.errorMessage || body.message || '');
      for (const secret of [process.env.CF_API_TOKEN, process.env.GH_TOKEN]) {
        if (secret) detail = detail.replaceAll(secret, '[REDACTED]');
      }
      detail = detail.replace(/[\r\n]/g, ' ').slice(0, 1000);
    } catch { /* HTML and other non-JSON errors stay private. */ }
    throw new Error(`HTTP ${response.status} from ${new URL(url).hostname}${new URL(url).pathname}${detail ? `: ${detail}` : ''}`);
  }
  return response.status === 204 ? null : response.json();
}

export async function publish(bundle, env = process.env, request = jsonRequest) {
  requireThat(env.GITHUB_REF === 'refs/heads/main', 'Publishing is allowed only from main.');
  requireThat(env.GH_TOKEN && env.CF_API_TOKEN, 'GH_TOKEN and repository Secret CF_API_TOKEN are required.');
  requireThat(env.GITHUB_REPOSITORY === 'vickyhoo/BelToolbox', 'Unexpected publishing repository.');
  const { config, info, manifest, archive } = bundle;
  const api = `https://api.github.com/repos/${env.GITHUB_REPOSITORY}`;
  const ghHeaders = { Authorization: `Bearer ${env.GH_TOKEN}`, Accept: 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28' };
  const gh = (path, method = 'GET', body, allow404 = false) => request(`${api}${path}`, {
    method, allow404, headers: { ...ghHeaders, 'Content-Type': 'application/json' },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  // Resolve the exact supported client before making any releases or uploads.
  const cfHeaders = { 'X-Api-Token': env.CF_API_TOKEN };
  const versions = await request('https://wow.curseforge.com/api/game/wow/versions', { headers: cfHeaders });
  requireThat(Array.isArray(versions), 'CurseForge did not return game versions. Check CF_API_TOKEN and API availability.');
  const gameVersionId = selectGameVersion(versions, config.gameVersionName, config.gameVersionTypeId);
  let ref = await gh(`/git/ref/tags/${info.tag}`, 'GET', undefined, true);
  if (ref) {
    let object = ref.object;
    for (let depth = 0; object.type === 'tag' && depth < 5; depth++) object = (await gh(`/git/tags/${object.sha}`)).object;
    requireThat(object.type === 'commit' && object.sha === manifest.commit, 'This version tag belongs to another commit. Bump the version before publishing.');
  }
  let release;
  for (let page = 1; ; page++) {
    const entries = await gh(`/releases?per_page=100&page=${page}`);
    release = entries.find(r => r.tag_name === info.tag);
    if (release || entries.length < 100) break;
  }
  if (!release) release = await gh('/releases', 'POST', {
    tag_name: info.tag, target_commitish: manifest.commit, name: `Bel Toolbox ${info.version}`,
    body: info.notes, draft: true, prerelease: false,
  });
  const assets = await gh(`/releases/${release.id}/assets?per_page=100`);
  // Read JSON via the asset's raw download endpoint, not its metadata endpoint.
  const rawAsset = async asset => {
    const response = await fetch(`${api}/releases/assets/${asset.id}`, {
      headers: { ...ghHeaders, Accept: 'application/octet-stream' }, signal: AbortSignal.timeout(120000),
    });
    requireThat(response.ok, `Could not read release asset ${asset.name}.`);
    return response.json();
  };
  const addAsset = async (name, bytes, type = 'application/json') => {
    const existing = assets.find(a => a.name === name);
    if (existing) return existing;
    const result = await request(`https://uploads.github.com/repos/${env.GITHUB_REPOSITORY}/releases/${release.id}/assets?name=${encodeURIComponent(name)}`, {
      method: 'POST', headers: { ...ghHeaders, 'Content-Type': type }, body: bytes,
    });
    assets.push(result);
    return result;
  };
  const priorManifest = assets.find(a => a.name === 'release-manifest.json');
  if (priorManifest) {
    const saved = await rawAsset(priorManifest);
    requireThat(saved.commit === manifest.commit && saved.sha256 === manifest.sha256 && saved.projectId === manifest.projectId, 'Release manifest mismatch; refusing to overwrite a version.');
  } else {
    requireThat(release.draft && assets.length === 0, 'Existing release has no matching automation manifest; refusing to overwrite it.');
    await addAsset('release-manifest.json', JSON.stringify(manifest, null, 2));
  }
  await addAsset(manifest.filename, archive, 'application/zip');
  await addAsset('RELEASE_NOTES.md', info.notes, 'text/markdown');
  await addAsset('SHA256SUMS.txt', `${manifest.sha256}  ${manifest.filename}\n`, 'text/plain');
  const receipt = assets.find(a => a.name === 'curseforge-upload.json');
  if (receipt) {
    const saved = await rawAsset(receipt);
    requireThat(saved.projectId === manifest.projectId && saved.sha256 === manifest.sha256 && Number.isInteger(saved.fileId), 'Invalid CurseForge upload receipt.');
    console.log(`CurseForge already accepted file ${saved.fileId}; no duplicate upload.`);
  } else {
    requireThat(release.draft, 'Published release lacks a CF receipt; inspect it manually before retrying.');
    requireThat(!assets.some(a => a.name === 'curseforge-upload-started.json'), 'A previous CF upload has an uncertain result. Check CF before retrying; remove curseforge-upload-started.json only after confirming no file was accepted.');
    await addAsset('curseforge-upload-started.json', JSON.stringify({ projectId: manifest.projectId, sha256: manifest.sha256, commit: manifest.commit }));
    const form = new FormData();
    form.set('metadata', JSON.stringify(metadata(config, info, gameVersionId)));
    form.set('file', new Blob([archive], { type: 'application/zip' }), manifest.filename);
    // A POST is deliberately not automatically retried: a timeout may follow acceptance.
    const uploaded = await request(`https://wow.curseforge.com/api/projects/${config.curseforgeProjectId}/upload-file`, {
      method: 'POST', headers: cfHeaders, body: form,
    });
    requireThat(Number.isInteger(uploaded.id) && uploaded.id > 0, 'CF did not return a valid file ID; inspect CF before retrying.');
    await addAsset('curseforge-upload.json', JSON.stringify({ projectId: manifest.projectId, fileId: uploaded.id, sha256: manifest.sha256 }, null, 2));
    console.log(`CurseForge accepted file ${uploaded.id}; site review may still be pending.`);
  }
  if (release.draft) await gh(`/releases/${release.id}`, 'PATCH', { draft: false, make_latest: 'true', body: info.notes });
  const url = `https://github.com/${env.GITHUB_REPOSITORY}/releases/tag/${info.tag}`;
  console.log(`Published ${url}`);
  if (env.GITHUB_STEP_SUMMARY) appendFileSync(env.GITHUB_STEP_SUMMARY, `## ${info.tag}\n\n- [GitHub Release](${url})\n- Same ZIP and Markdown changelog uploaded to CurseForge project ${config.curseforgeProjectId}.\n- CF upload accepted; approval is handled by CurseForge.\n`);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const bundle = build();
    if (process.argv.includes('--publish')) await publish(bundle);
    else requireThat(process.argv.includes('--build'), 'Use --build or --publish.');
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
