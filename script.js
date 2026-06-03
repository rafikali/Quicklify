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

  // ---- Animated walkthrough — mirrors the real CaptureScreen flow ----
  (function initDemo() {
    const screen = $('.ql-screen[data-state="0"]');
    if (!screen) return;

    const stepEls = $$('.demo-step', screen.closest('.demo'));
    const typedEl = $('.ql-url-typed', screen);
    const extractTitleEl = $('#qlExtractTitle', screen);
    const pipeEls = $$('.ql-pipe', screen);
    const ringBar = $('.ql-ring-bar', screen);
    const ringPct = $('.ql-ring-pct', screen);
    const streamSpans = $$('.ql-streams span', screen);
    const tap = $('.demo-tap', screen);
    const replayBtn = $('#demoReplay');

    const URL_STR = 'https://youtu.be/dQw4w9WgXcQ';
    const RING_CIRCUMFERENCE = 276.46; // 2π * r(44)
    let runId = 0;

    const sleep = (ms) => new Promise((res) => setTimeout(res, ms));

    function setState(state, step) {
      screen.dataset.state = String(state);
      for (const el of stepEls) {
        const s = parseInt(el.dataset.step, 10);
        el.classList.toggle('active', s === step);
        el.classList.toggle('done', s < step);
      }
    }

    function tapAt(x, y) {
      tap.style.setProperty('--tap-x', x);
      tap.style.setProperty('--tap-y', y);
      tap.classList.remove('go');
      void tap.offsetWidth; // restart animation
      tap.classList.add('go');
    }

    async function typeUrl(myId) {
      typedEl.textContent = '';
      for (let i = 1; i <= URL_STR.length; i++) {
        if (myId !== runId) return;
        typedEl.textContent = URL_STR.slice(0, i);
        await sleep(26 + Math.random() * 22);
      }
    }

    function setPipeline(activeIdx) {
      for (const el of pipeEls) {
        const i = parseInt(el.dataset.pipe, 10);
        el.classList.toggle('active', i === activeIdx);
        el.classList.toggle('done', i < activeIdx);
      }
    }

    function setRingProgress(p) {
      ringBar.style.strokeDashoffset = String(RING_CIRCUMFERENCE * (1 - p));
      ringPct.textContent = `${Math.floor(p * 100)}%`;
      const lit = Math.ceil(p * streamSpans.length);
      streamSpans.forEach((s, i) => s.classList.toggle('on', i < lit));
    }

    async function tickRing(myId, durationMs) {
      setRingProgress(0);
      const start = performance.now();
      while (true) {
        if (myId !== runId) return;
        const p = Math.min(1, (performance.now() - start) / durationMs);
        setRingProgress(p);
        if (p >= 1) return;
        await sleep(40);
      }
    }

    async function run() {
      const myId = ++runId;

      // Reset transient bits
      typedEl.textContent = '';
      setPipeline(-1);
      setRingProgress(0);

      // 0. Idle (step 1)
      setState(0, 1);
      await sleep(1500);
      if (myId !== runId) return;

      // 1. Link detected — URL types into the card (step 2)
      setState(1, 2);
      await sleep(450);
      if (myId !== runId) return;
      await typeUrl(myId);
      if (myId !== runId) return;
      await sleep(900);
      if (myId !== runId) return;
      tapAt('50%', '78%'); // Capture Stream button
      await sleep(420);
      if (myId !== runId) return;

      // 2. Extracting (pipeline cycles) (step 3)
      setState(2, 3);
      const titles = [
        'Detecting media source',
        'Capturing stream data',
        'Merging audio & video',
        'Optimizing download',
      ];
      for (let i = 0; i < 3; i++) {
        if (myId !== runId) return;
        extractTitleEl.textContent = titles[i];
        setPipeline(i);
        await sleep(700);
      }
      if (myId !== runId) return;

      // 3. Downloading (ring fills) (step 3)
      setState(3, 3);
      await tickRing(myId, 2400);
      if (myId !== runId) return;
      await sleep(350);
      if (myId !== runId) return;

      // 4. Captured (step 4)
      setState(4, 4);
      await sleep(2800);
      if (myId !== runId) return;

      // Loop
      run();
    }

    function stop() {
      runId++; // any in-flight chain bails
    }

    const io = new IntersectionObserver(
      (entries) => {
        for (const e of entries) {
          if (e.isIntersecting) run();
          else stop();
        }
      },
      { threshold: 0.35 },
    );
    io.observe(screen);

    if (replayBtn) {
      replayBtn.addEventListener('click', () => run());
    }
  })();

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
