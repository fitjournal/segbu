// Service worker: simpan kerangka aplikasi & aset supaya bisa dibuka offline.
const CACHE = "fitapp-v12";
const INTI = ["./", "./index.html", "./manifest.json",
  "./muscle-base.png", "./muscle-index.png"];

self.addEventListener("install", e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(INTI)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", e => {
  e.waitUntil(
    caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", e => {
  const url = new URL(e.request.url);
  if (e.request.method !== "GET") return;
  // Jangan pernah cache panggilan API Supabase — data harus selalu segar.
  if (url.hostname.endsWith("supabase.co")) return;

  // Aset (gambar, video, font): cache dulu, ambil jaringan bila belum ada.
  if (/\.(png|jpe?g|webp|mp4|svg|woff2?)$/i.test(url.pathname)) {
    e.respondWith(
      caches.match(e.request).then(hit => hit || fetch(e.request).then(res => {
        const copy = res.clone();
        caches.open(CACHE).then(c => c.put(e.request, copy));
        return res;
      }).catch(() => hit))
    );
    return;
  }

  // Halaman: coba jaringan, jatuh ke cache saat offline.
  e.respondWith(
    fetch(e.request).then(res => {
      const copy = res.clone();
      caches.open(CACHE).then(c => c.put(e.request, copy));
      return res;
    }).catch(() => caches.match(e.request).then(hit => hit || caches.match("./index.html")))
  );
});
