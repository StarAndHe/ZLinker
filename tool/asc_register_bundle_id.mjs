#!/usr/bin/env node
// Register App Store Connect bundle IDs via the ASC API.
// Pure node:crypto ES256 JWT (ieee-p1363 signature encoding) + fetch — no deps.
//
// Env:
//   ASC_KEY_PATH     path to the .p8 API key
//   ASC_KEY_ID       API key id (10 chars)
//   ASC_ISSUER_ID    issuer uuid
//   ASC_IDENTIFIERS  comma-separated identifiers, e.g. org.songsong.qiandazi
//   ASC_PLATFORM     IOS (default) | MAC_OS | UNIVERSAL
//   ASC_NAME_PREFIX optional prefix for the human-readable resource name
import { readFileSync } from 'node:fs';
import { createSign } from 'node:crypto';

const keyPath = process.env.ASC_KEY_PATH;
const keyId = process.env.ASC_KEY_ID;
const issuerId = process.env.ASC_ISSUER_ID;
const identifiers = (process.env.ASC_IDENTIFIERS || '').split(',').map(s => s.trim()).filter(Boolean);
const platform = process.env.ASC_PLATFORM || 'IOS';
const namePrefix = process.env.ASC_NAME_PREFIX || '';

if (!keyPath || !keyId || !issuerId || identifiers.length === 0) {
  console.error('need ASC_KEY_PATH, ASC_KEY_ID, ASC_ISSUER_ID, ASC_IDENTIFIERS');
  process.exit(1);
}

const b64url = buf => Buffer.from(buf).toString('base64url');

function makeToken() {
  const header = { alg: 'ES256', kid: keyId, typ: 'JWT' };
  const now = Math.floor(Date.now() / 1000);
  // aud claim is REQUIRED for ASC API keys (2024+), 401 without it.
  const payload = { iss: issuerId, iat: now, exp: now + 1200, aud: 'appstoreconnect-v1' };
  const signingInput = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(payload))}`;
  const signer = createSign('SHA256');
  signer.update(signingInput);
  // JOSE ES256 wants raw r||s (64 bytes), not ASN.1 DER:
  const sig = signer.sign({ key: readFileSync(keyPath, 'utf8'), dsaEncoding: 'ieee-p1363' });
  return `${signingInput}.${b64url(sig)}`;
}

const token = makeToken();
const api = 'https://api.appstoreconnect.apple.com/v1/bundleIds';

async function existingId(identifier) {
  const res = await fetch(`${api}?filter[identifier]=${encodeURIComponent(identifier)}&limit=1`,
    { headers: { Authorization: `Bearer ${token}` } });
  if (!res.ok) return null;
  const body = await res.json();
  return body.data?.[0] ?? null;
}

let failed = false;
for (const identifier of identifiers) {
  const name = `${namePrefix}${identifier.split('.').pop()}`;
  try {
    const res = await fetch(api, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        data: { type: 'bundleIds', attributes: { identifier, name, platform } },
      }),
    });
    if (res.status === 201) {
      const body = await res.json();
      console.log(`OK  ${identifier} -> bundleId resource ${body.data?.id} (name "${name}", platform ${platform})`);
      continue;
    }
    if (res.status === 409) {
      const dup = await existingId(identifier);
      console.log(`DUP ${identifier} already registered${dup ? ` (resource ${dup.id}, name "${dup.attributes?.name}")` : ''} — skipped`);
      continue;
    }
    const text = await res.text();
    console.error(`ERR ${identifier}: HTTP ${res.status} ${text.slice(0, 400)}`);
    failed = true;
  } catch (e) {
    console.error(`ERR ${identifier}: ${e.message}`);
    failed = true;
  }
}
process.exit(failed ? 1 : 0);
