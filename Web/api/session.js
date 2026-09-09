import { put, head } from "@vercel/blob";

/// Telefon tur listesini ve her turun ayrintili izini POST eder, laptoptaki
/// sayfa GET ile okur. Indeks `sessions/ID.json`, tur izleri
/// `sessions/ID/laps/N.json` olarak ayri blob'larda durur; boylece bir tur
/// bir kez yuklenir ve sayfa yalnizca sectigi turlari indirir.
export default async function handler(request, response) {
  response.setHeader("Access-Control-Allow-Origin", "*");
  response.setHeader("Access-Control-Allow-Headers", "content-type");
  response.setHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
  if (request.method === "OPTIONS") return response.status(204).end();

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
        return response.status(200).json({ ok: true });
      }

      await store(`sessions/${id}.json`, JSON.stringify({
        id,
        updatedAt: new Date().toISOString(),
        laps: Array.isArray(body.laps) ? body.laps.slice(-200) : [],
        best: body.best ?? null,
        track: body.track ?? null
      }));
      return response.status(200).json({ ok: true });
    }

    const id = sanitise(request.query?.id);
    if (!id) return response.status(400).json({ error: "id required" });

    const lap = request.query?.lap;
    if (lap !== undefined) {
      const number = Number(lap);
      if (!Number.isInteger(number)) return response.status(400).json({ error: "bad lap" });
      const trace = await read(`sessions/${id}/laps/${number}.json`);
      return response.status(trace ? 200 : 404).json(trace ?? { error: "no trace" });
    }

    const index = await read(`sessions/${id}.json`);
    return response.status(200).json(index ?? { laps: [], waiting: true });
  } catch (error) {
    return response.status(500).json({ error: String(error?.message ?? error) });
  }
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
