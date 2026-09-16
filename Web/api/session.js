import { put, head, list, del } from "@vercel/blob";

/// Telefon tur listesini ve her turun ayrintili izini POST eder, laptoptaki
/// sayfa GET ile okur. Indeks `sessions/ID.json`, tur izleri
/// `sessions/ID/laps/N.json` olarak ayri blob'larda durur; boylece bir tur
/// bir kez yuklenir ve sayfa yalnizca sectigi turlari indirir.
///
/// Oturum kimligi alti karakter: bilen okur. Kaba kuvvet denemesini
/// yavaslatmak icin asagida ornek basina bir hiz siniri var; Vercel her
/// ornegi ayri calistirdigindan bu kesin bir sinir degil, esigi asan
/// taramalari pahali hale getirmeye yarar.
const WINDOW_MS = 60_000;
const LIMITS = { GET: 120, POST: 60 };
const hits = new Map();

/// Bir oturumda saklanan en fazla tur izi; eskiler silinir.
const MAX_TRACES = 60;
/// Bu sureden eski oturumlar okunmaz ve temizlenir.
const SESSION_TTL_MS = 14 * 24 * 60 * 60 * 1000;

export default async function handler(request, response) {
  response.setHeader("Access-Control-Allow-Origin", "*");
  response.setHeader("Access-Control-Allow-Headers", "content-type");
  response.setHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
  if (request.method === "OPTIONS") return response.status(204).end();

  if (!allow(request)) {
    response.setHeader("Retry-After", "60");
    return response.status(429).json({ error: "too many requests" });
  }

  try {
    if (request.method === "POST") {
      const body = typeof request.body === "string" ? JSON.parse(request.body) : request.body;
      const id = sanitise(body?.id);
      if (!id) return response.status(400).json({ error: "id required" });

      if (body.trace) {
        const lap = Number(body.trace.lap);
        if (!Number.isInteger(lap) || lap < 0 || lap > 9999) {
          return response.status(400).json({ error: "bad lap" });
        }
        const rows = Array.isArray(body.trace.rows) ? body.trace.rows.slice(0, 20000) : [];
        await store(`sessions/${id}/laps/${lap}.json`, JSON.stringify({
          lap, time: body.trace.time ?? 0, columns: body.trace.columns ?? [], rows
        }));
        await pruneTraces(id);
        return response.status(200).json({ ok: true });
      }

      const existing = await read(`sessions/${id}.json`);
      await store(`sessions/${id}.json`, JSON.stringify({
        id,
        createdAt: existing?.createdAt ?? new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        // Bos liste yalnizca eslesme bildirimi: kayitli turlar silinmez.
        laps: Array.isArray(body.laps) && body.laps.length ? body.laps.slice(-200) : (existing?.laps ?? []),
        best: body.best || existing?.best || null,
        track: (body.track && body.track.id >= 0 ? body.track : existing?.track) ?? body.track ?? null
      }));
      return response.status(200).json({ ok: true });
    }

    const id = sanitise(request.query?.id);
    if (!id) return response.status(400).json({ error: "id required" });

    const index = await read(`sessions/${id}.json`);
    if (index && expired(index)) {
      await discard(id);
      return response.status(200).json({ laps: [], waiting: true });
    }

    const lap = request.query?.lap;
    if (lap !== undefined) {
      const number = Number(lap);
      if (!Number.isInteger(number)) return response.status(400).json({ error: "bad lap" });
      const trace = await read(`sessions/${id}/laps/${number}.json`);
      return response.status(trace ? 200 : 404).json(trace ?? { error: "no trace" });
    }

    return response.status(200).json(index ?? { laps: [], waiting: true });
  } catch (error) {
    return response.status(500).json({ error: String(error?.message ?? error) });
  }
}

/// Kayan pencere: ornek basina, istemci adresine gore.
function allow(request) {
  const limit = LIMITS[request.method];
  if (!limit) return true;
  const forwarded = request.headers["x-forwarded-for"] ?? "";
  const ip = String(forwarded).split(",")[0].trim() || "unknown";
  const key = `${request.method}:${ip}`;
  const now = Date.now();

  const recent = (hits.get(key) ?? []).filter(t => now - t < WINDOW_MS);
  recent.push(now);
  hits.set(key, recent);

  // Bellek sizintisini onle: eskimis anahtarlari ara sira at.
  if (hits.size > 5_000) {
    for (const [k, times] of hits) {
      if (!times.length || now - times[times.length - 1] > WINDOW_MS) hits.delete(k);
    }
  }
  return recent.length <= limit;
}

function expired(index) {
  const stamp = Date.parse(index.updatedAt ?? index.createdAt ?? "");
  return Number.isFinite(stamp) && Date.now() - stamp > SESSION_TTL_MS;
}

/// Sureli saklama: bir oturumda yalnizca son turlarin izi kalir.
async function pruneTraces(id) {
  const { blobs } = await list({ prefix: `sessions/${id}/laps/`, limit: 1_000 });
  if (blobs.length <= MAX_TRACES) return;
  const doomed = blobs
    .map(b => ({ ...b, lap: Number(b.pathname.split("/").pop().replace(".json", "")) }))
    .sort((a, b) => a.lap - b.lap)
    .slice(0, blobs.length - MAX_TRACES);
  await Promise.all(doomed.map(b => del(b.url).catch(() => null)));
}

async function discard(id) {
  const { blobs } = await list({ prefix: `sessions/${id}`, limit: 1_000 });
  await Promise.all(blobs.map(b => del(b.url).catch(() => null)));
}

async function store(path, payload) {
  await put(path, payload, {
    access: "private",
    addRandomSuffix: false,
    allowOverwrite: true,
    contentType: "application/json",
    cacheControlMaxAge: 0
  });
}

/// Depo private oldugu icin indirme adresine token ile gidiliyor.
async function read(path) {
  const blob = await head(path).catch(() => null);
  if (!blob) return null;
  const content = await fetch(blob.downloadUrl ?? blob.url, {
    cache: "no-store",
    headers: { authorization: `Bearer ${process.env.BLOB_READ_WRITE_TOKEN}` }
  });
  return content.ok ? content.json() : null;
}

/// Kimlik yalnizca harf ve rakam; blob yolunu disaridan yonlendiremesinler.
function sanitise(value) {
  if (typeof value !== "string") return null;
  const clean = value.trim().toUpperCase().replace(/[^A-Z0-9]/g, "");
  return clean.length >= 4 && clean.length <= 12 ? clean : null;
}
