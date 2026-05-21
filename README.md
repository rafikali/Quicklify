# Quicklify download site

Static landing page that serves the Quicklify Android APK.

```
website/
├── index.html         landing page
├── styles.css         brand styles (cyan/purple/pink on #0A0A0F)
├── script.js          download counter, toast, parallax, scroll-reveal
├── assets/            icon + favicon
└── downloads/
    └── quicklify-latest.apk    ← the file users actually download
```

## Run locally

From the repo root:

```bash
cd website
python3 -m http.server 8080
```

Open <http://localhost:8080>.

## Replace the APK

Build a release APK and drop it in `downloads/` with the same filename:

```bash
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk website/downloads/quicklify-latest.apk
```

The site's "size" label auto-updates from a `HEAD` request — no manual edits
needed.

## Deploy (pick one — all free)

**Netlify** (easiest, drag-and-drop)
1. Go to <https://app.netlify.com/drop>
2. Drag the entire `website/` folder onto the page
3. Done — you get a `*.netlify.app` URL. Add a custom domain in Site settings.

**Vercel** (CLI)
```bash
cd website
npx vercel --prod
```

**GitHub Pages** (if this repo is on GitHub)
```bash
git subtree push --prefix website origin gh-pages
```
Then enable Pages on the `gh-pages` branch in repo settings.

**Cloudflare Pages** (best for big APKs — generous bandwidth)
- New project → Connect Git → set build output directory to `website` → deploy.

## Recommended host

For an APK download site, **Cloudflare Pages** is the strongest pick:
unmetered bandwidth, global CDN, free TLS. Netlify is the fastest to ship
the very first version (literally drag-and-drop).

## Custom domain

Once deployed, point a domain like `quicklify.app` or `getquicklify.com` at
the host. The site is fully static — no DNS gymnastics needed beyond the
provider's standard CNAME / A record instructions.
