import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

function escHtml(raw: string): string {
  return String(raw ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

Deno.serve(async (req: Request) => {
  const reqUrl = new URL(req.url);
  const rawSlug =
    reqUrl.searchParams.get("event") ??
    reqUrl.pathname.split("/").filter(Boolean).pop() ??
    "";
  const slug = rawSlug.trim().toLowerCase();

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "https://embicteneumubwlqqfik.supabase.co";
  const supabaseKey =
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
    Deno.env.get("SUPABASE_ANON_KEY") ??
    "";

  let title = "Vészhelyzeti kvíz – Tedd próbára a tudásod!";
  let questionCount = 10;
  let ogImageUrl = "https://hun01usar.hu/quiz-social-card.jpg";
  let canonicalShareUrl = "https://hun01usar.hu/quiz";
  let targetAppUrl = "https://hun01usar.hu/planning/?mode=quiz";

  if (slug && slug !== "quiz-share" && supabaseKey) {
    try {
      const sb = createClient(supabaseUrl, supabaseKey);
      const { data: ev } = await sb
        .from("quiz_events")
        .select("slug, title, question_count")
        .eq("slug", slug)
        .maybeSingle();

      if (ev) {
        title = `${ev.title} – Vészhelyzeti kvíz`;
        questionCount = Number(ev.question_count) || 10;
        canonicalShareUrl = `https://hun01usar.hu/q/${encodeURIComponent(ev.slug)}`;
        targetAppUrl = `https://hun01usar.hu/planning/?mode=quiz&event=${encodeURIComponent(ev.slug)}`;

        // Check if a rendered event poster exists in public `quiz-posters` bucket
        const posterPath = `${ev.slug}.png`;
        const { data: files } = await sb.storage
          .from("quiz-posters")
          .list("", { search: posterPath, limit: 5 });

        const found = (files ?? []).find((f) => f.name === posterPath);
        if (found) {
          const ts = found.updated_at ? new Date(found.updated_at).getTime() : 1;
          ogImageUrl = `${supabaseUrl}/storage/v1/object/public/quiz-posters/${encodeURIComponent(posterPath)}?v=${ts}`;
        } else if (ev.slug === "barcsi-adventi-vasar-2026") {
          ogImageUrl = "https://hun01usar.hu/posters-barcsi-adventi-vasar-2026.jpg";
        } else {
          ogImageUrl = "https://hun01usar.hu/quiz-social-card.jpg";
        }
      } else {
        canonicalShareUrl = `https://hun01usar.hu/q/${encodeURIComponent(slug)}`;
        targetAppUrl = `https://hun01usar.hu/planning/?mode=quiz&event=${encodeURIComponent(slug)}`;
      }
    } catch (_) {
      canonicalShareUrl = `https://hun01usar.hu/q/${encodeURIComponent(slug)}`;
      targetAppUrl = `https://hun01usar.hu/planning/?mode=quiz&event=${encodeURIComponent(slug)}`;
    }
  }

  const description = `${questionCount} gyors kérdés • Azonnali szakmai magyarázat • Regisztráció nélkül! Kattints a képre a kvíz indításához!`;

  const html = `<!doctype html>
<html lang="hu">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta name="theme-color" content="#0B132B">
  <title>${escHtml(title)}</title>
  <meta name="description" content="${escHtml(description)}">
  <link rel="canonical" href="${escHtml(canonicalShareUrl)}">

  <!-- Facebook / Messenger / Viber / WhatsApp Clickable Poster Card -->
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="Vészhelyzeti kvíz">
  <meta property="og:url" content="${escHtml(canonicalShareUrl)}">
  <meta property="og:title" content="🔥 ${escHtml(title)}">
  <meta property="og:description" content="👉 ${escHtml(description)}">
  <meta property="og:image" content="${escHtml(ogImageUrl)}">
  <meta property="og:image:secure_url" content="${escHtml(ogImageUrl)}">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="1600">
  <meta property="og:image:alt" content="${escHtml(title)}">
  <meta property="og:locale" content="hu_HU">

  <!-- Twitter / X Large Card -->
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="🔥 ${escHtml(title)}">
  <meta name="twitter:description" content="👉 ${escHtml(description)}">
  <meta name="twitter:image" content="${escHtml(ogImageUrl)}">

  <script>
    window.location.replace(${JSON.stringify(targetAppUrl)});
  </script>
  <style>
    body {
      margin: 0;
      min-height: 100vh;
      display: grid;
      place-items: center;
      background: #0B132B;
      color: #ffffff;
      font-family: system-ui, -apple-system, sans-serif;
      text-align: center;
      padding: 24px;
    }
    a {
      display: inline-block;
      margin-top: 14px;
      padding: 13px 24px;
      border-radius: 999px;
      background: #EA580C;
      color: #ffffff;
      font-weight: 800;
      text-decoration: none;
    }
  </style>
</head>
<body>
  <div>
    <h1>${escHtml(title)}</h1>
    <p>A kvíz betöltése folyamatban…</p>
    <a href="${escHtml(targetAppUrl)}">KVÍZ INDÍTÁSA →</a>
  </div>
</body>
</html>`;

  return new Response(html, {
    status: 200,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "public, max-age=60, s-maxage=60",
    },
  });
});
