import { put, head } from "@vercel/blob";

/// Telefon turlari POST eder, laptoptaki sayfa GET ile okur.
/// Veri, oturum kimligiyle adlandirilmis tek bir JSON blob'unda durur.
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

      const payload = JSON.stringify({
        id,
        updatedAt: new Date().toISOString(),
        laps: Array.isArray(body.laps) ? body.laps.slice(-200) : [],
        best: body.best ?? null,
        track: body.track ?? null
      });

      await put(`sessions/${id}.json`, payload, {
        access: "private",
        addRandomSuffix: false,
        allowOverwrite: true,
        contentType: "application/json",
        cacheControlMaxAge: 0
      });
      return response.status(200).json({ ok: true });
    }

    const id = sanitise(request.query?.id);
    if (!id) return response.status(400).json({ error: "id required" });

    const blob = await head(`sessions/${id}.json`).catch(() => null);
    if (!blob) return response.status(200).json({ laps: [], waiting: true });

    // Depo private oldugu icin indirme adresine token ile gidiliyor.
    const content = await fetch(blob.downloadUrl ?? blob.url, {
      cache: "no-store",
      headers: { authorization: `Bearer ${process.env.BLOB_READ_WRITE_TOKEN}` }
    });
    if (!content.ok) return response.status(200).json({ laps: [], waiting: true });
    return response.status(200).json(await content.json());
  } catch (error) {
    return response.status(500).json({ error: String(error?.message ?? error) });
  }
}

/// Kimlik yalnizca harf ve rakam; blob yolunu disaridan yonlendiremesinler.
function sanitise(value) {
  if (typeof value !== "string") return null;
  const clean = value.trim().toUpperCase().replace(/[^A-Z0-9]/g, "");
  return clean.length >= 4 && clean.length <= 12 ? clean : null;
}
