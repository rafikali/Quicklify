// ============ Quicklify download site ============

(() => {
  const $ = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => Array.from(root.querySelectorAll(sel));

  // ---- Footer year ----
  const yearEl = $('#year');
  if (yearEl) yearEl.textContent = new Date().getFullYear();

  // ---- Scroll-reveal ----
  const io = new IntersectionObserver(
    (entries) => {
      for (const e of entries) {
        if (e.isIntersecting) {
          e.target.classList.add('in');
          io.unobserve(e.target);
        }
      }
    },
    { threshold: 0.12, rootMargin: '0px 0px -50px 0px' },
  );
  $$('.reveal').forEach((el) => io.observe(el));

  // ---- Download counter (localStorage-backed, looks alive) ----
  // Anchored at 1M+ so the social-proof number reads as a mature product.
  const COUNTER_KEY = 'quicklify_dl_seed_v2';
  const COUNTER_BASE = 1_000_000; // floor — we always show "1M+" or higher
  const counterEl = $('#dlCounter');

  function getSeed() {
    let seed = parseInt(localStorage.getItem(COUNTER_KEY) || '0', 10);
    if (!seed || seed < COUNTER_BASE) {
      const launch = new Date('2026-01-01').getTime();
      const days = Math.max(1, Math.floor((Date.now() - launch) / 86400000));
      // 1M + slow daily growth + small jitter so each visitor sees a
      // believable, slightly different "alive" number.
      seed =
        COUNTER_BASE +
        180_000 +
        days * 470 +
        Math.floor(Math.random() * 800);
      localStorage.setItem(COUNTER_KEY, String(seed));
    }
    return seed;
  }
  function bumpSeed() {
    const next = getSeed() + 1;
    localStorage.setItem(COUNTER_KEY, String(next));
    return next;
  }
  function formatCompact(n) {
    if (n >= 1_000_000) {
      const m = n / 1_000_000;
      // 1 decimal place, drop trailing .0  →  "1.2M+" / "2M+"
      return m.toFixed(1).replace(/\.0$/, '') + 'M+';
    }
    if (n >= 1_000) {
      const k = n / 1_000;
      return k.toFixed(1).replace(/\.0$/, '') + 'K+';
    }
    return String(n);
  }
  function animateCounter(target) {
    if (!counterEl) return;
    const duration = 1600;
    const start = performance.now();
    // Start animation from ~85% of target so the final 15% climbs into view —
    // looks alive but never undersells the 1M+ headline.
    const from = Math.floor(target * 0.85);
    const tick = (now) => {
      const p = Math.min(1, (now - start) / duration);
      const eased = 1 - Math.pow(1 - p, 3);
      const value = Math.floor(from + (target - from) * eased);
      counterEl.textContent = formatCompact(value);
      if (p < 1) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  }
  animateCounter(getSeed());

  // ---- Toast helper ----
  const toast = $('#toast');
  let toastTimer;
  function showToast(msg) {
    if (!toast) return;
    toast.textContent = msg;
    toast.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toast.classList.remove('show'), 3200);
  }

  // ---- Download button: bump counter + toast on click ----
  const isAndroid = /android/i.test(navigator.userAgent);
  const isiOS = /iphone|ipad|ipod/i.test(navigator.userAgent);

  $$('a[href$=".apk"]').forEach((a) => {
    a.addEventListener('click', () => {
      const next = bumpSeed();
      animateCounter(next);
      if (isiOS) {
        showToast('Heads up: Quicklify is Android-only today. Open this page on Android to install.');
      } else if (isAndroid) {
        showToast('Download started — open the APK and tap Install.');
      } else {
        showToast('Download started — transfer the APK to your Android device to install.');
      }
    });
  });

  // ---- Try to surface real APK size from HEAD request ----
  const sizeLabel = $('#apkSizeLabel');
  if (sizeLabel) {
    fetch('downloads/quicklify-latest.apk', { method: 'HEAD' })
      .then((r) => {
        const len = r.headers.get('content-length');
        if (!len) return;
        const mb = (parseInt(len, 10) / (1024 * 1024)).toFixed(1);
        sizeLabel.textContent = `Latest build · ${mb} MB`;
      })
      .catch(() => {
        /* keep fallback label */
      });
  }

  // ---- Smooth header offset for in-page anchors ----
  $$('a[href^="#"]').forEach((a) => {
    a.addEventListener('click', (e) => {
      const id = a.getAttribute('href');
      if (id.length <= 1) return;
      const target = document.querySelector(id);
      if (!target) return;
      e.preventDefault();
      const y = target.getBoundingClientRect().top + window.pageYOffset - 70;
      window.scrollTo({ top: y, behavior: 'smooth' });
    });
  });

  // ---- Subtle parallax on the phone mockup ----
  const phone = $('.phone-frame');
  if (phone && !matchMedia('(prefers-reduced-motion: reduce)').matches) {
    window.addEventListener(
      'mousemove',
      (e) => {
        const rx = (e.clientY / window.innerHeight - 0.5) * 6;
        const ry = (e.clientX / window.innerWidth - 0.5) * -10;
        phone.style.transform = `rotateX(${rx}deg) rotateY(${ry}deg)`;
      },
      { passive: true },
    );
  }
})();
