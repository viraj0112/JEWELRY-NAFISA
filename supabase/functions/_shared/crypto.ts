// Symmetric encryption for credentials stored in Postgres.
//
// WHY NOT pgcrypto: encrypting inside the database means the decryption key
// also lives in (or is passed through) the database, so a dump or a leaked
// service-role key gives up both halves. Encrypting here keeps the key in the
// Edge Function / backend environment only — Postgres holds ciphertext it
// cannot itself read.
//
// Format: `v1.<base64 iv>.<base64 ciphertext||tag>`
//   - AES-256-GCM, 12-byte random IV per encryption (never reuse an IV with
//     the same key — GCM catastrophically leaks the keystream if you do, which
//     is exactly why the IV is generated fresh on every call and shipped
//     alongside the ciphertext).
//   - GCM is authenticated: decrypt() throws on any tampering, so a modified
//     row cannot smuggle a substituted key through.
//
// The identical format is implemented in
// DatabasePrefill/backend/services/crypto.py — keep the two in sync.
//
// Setup:  openssl rand -base64 32
//         supabase secrets set AI_FILL_ENC_KEY=<that value>

const VERSION = "v1";

function b64encode(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes));
}

function b64decode(text: string): Uint8Array {
  return Uint8Array.from(atob(text), (c) => c.charCodeAt(0));
}

let cachedKey: CryptoKey | null = null;

async function getKey(): Promise<CryptoKey> {
  if (cachedKey) return cachedKey;
  const raw = Deno.env.get("AI_FILL_ENC_KEY");
  if (!raw) {
    throw new Error(
      "AI_FILL_ENC_KEY is not configured (expected a base64 32-byte key)",
    );
  }
  const keyBytes = b64decode(raw.trim());
  if (keyBytes.length !== 32) {
    throw new Error(
      `AI_FILL_ENC_KEY must decode to 32 bytes for AES-256, got ${keyBytes.length}`,
    );
  }
  cachedKey = await crypto.subtle.importKey(
    "raw",
    keyBytes,
    { name: "AES-GCM" },
    false,
    ["encrypt", "decrypt"],
  );
  return cachedKey;
}

export async function encryptSecret(plaintext: string): Promise<string> {
  const key = await getKey();
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ct = new Uint8Array(
    await crypto.subtle.encrypt(
      { name: "AES-GCM", iv },
      key,
      new TextEncoder().encode(plaintext),
    ),
  );
  return `${VERSION}.${b64encode(iv)}.${b64encode(ct)}`;
}

export async function decryptSecret(payload: string): Promise<string> {
  const parts = payload.split(".");
  if (parts.length !== 3 || parts[0] !== VERSION) {
    throw new Error("Unrecognised ciphertext format");
  }
  const key = await getKey();
  const plain = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv: b64decode(parts[1]) },
    key,
    b64decode(parts[2]),
  );
  return new TextDecoder().decode(plain);
}

/** Hex SHA-256 — used to store a *verifiable* copy of an API key without
 *  storing the key itself. Lookup is `where x_api_key_hash = sha256(header)`. */
export async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/** Master key for B2B users: `dgn_` + 32 lowercase hex chars (128 bits of
 *  entropy from the CSPRNG — brute-forcing it is not a threat model). */
export function generateMasterKey(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  const hex = Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  return `dgn_${hex}`;
}

/** Last 4 characters, for "which key is this?" recognition in the UI. */
export function keyHint(secret: string): string {
  const t = secret.trim();
  return t.length <= 4 ? "****" : `••••${t.slice(-4)}`;
}
