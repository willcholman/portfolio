/* ==========================================================================
   intro.js — homepage entrance
   Graphics fly in from off-screen, accumulate, then blast out and the
   overlay wipes away to leave the visitor on the home page.
   Runs once per browser session.
   ========================================================================== */
(function () {
  "use strict";

  var overlay = document.querySelector("[data-intro]");
  if (!overlay) return;

  var SESSION_KEY = "wh-intro-played";
  var reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  var played = false;
  try { played = sessionStorage.getItem(SESSION_KEY) === "1"; } catch (e) {}

  function finish(instant) {
    overlay.setAttribute("hidden", "");
    document.body.classList.remove("intro-lock");
    if (window.WH && window.WH.revealHero) window.WH.revealHero();
    if (instant) {
      var lines = document.querySelectorAll("[data-hero-line]");
      for (var i = 0; i < lines.length; i++) {
        lines[i].style.transform = "none";
        lines[i].style.opacity = "1";
      }
    }
  }

  if (played || reduceMotion || typeof window.gsap === "undefined") {
    finish(true);
    return;
  }

  try { sessionStorage.setItem(SESSION_KEY, "1"); } catch (e) {}
  document.body.classList.add("intro-lock");

  var gsap = window.gsap;
  var stage = overlay.querySelector("[data-intro-stage]");
  var mark = overlay.querySelector("[data-intro-mark]");
  var counter = overlay.querySelector("[data-intro-count]");
  var tickerA = overlay.querySelector("[data-ticker='project']");
  var tickerB = overlay.querySelector("[data-ticker='client']");
  var rule = overlay.querySelector("[data-intro-rule]");
  var meta = overlay.querySelector("[data-intro-meta]");

  var sources = (window.WH_DATA && window.WH_DATA.introImages) || [];
  var credits = (window.WH_DATA && window.WH_DATA.introCredits) || [];

  /* deterministic pseudo-random so the layout is stable across reloads */
  function mulberry32(a) {
    return function () {
      a |= 0; a = (a + 0x6d2b79f5) | 0;
      var t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }
  var rnd = mulberry32(20260805);

  var vw = window.innerWidth;
  var vh = window.innerHeight;
  var far = Math.max(vw, vh) * 1.15;
  var small = vw < 720;

  /* ---------- build the flying graphics -------------------------------- */
  var nodes = [];
  var count = Math.min(sources.length, small ? 14 : 20);

  for (var i = 0; i < count; i++) {
    var img = document.createElement("img");
    img.className = "intro__img";
    img.src = sources[i];
    img.alt = "";
    img.setAttribute("aria-hidden", "true");
    img.decoding = "async";
    stage.appendChild(img);

    var ang = rnd() * Math.PI * 2;
    var spreadX = vw * (small ? 0.30 : 0.34);
    var spreadY = vh * (small ? 0.26 : 0.30);

    nodes.push({
      el: img,
      // where it lands
      fx: (rnd() * 2 - 1) * spreadX,
      fy: (rnd() * 2 - 1) * spreadY,
      fr: (rnd() * 2 - 1) * 26,
      fs: 0.62 + rnd() * 0.62,
      // where it comes from / flies out to
      sx: Math.cos(ang) * far,
      sy: Math.sin(ang) * far,
      sr: (rnd() * 2 - 1) * 90
    });
  }

  /* ---------- credit tickers ------------------------------------------- */
  var tickerTimer = null;
  function startTicker() {
    if (!credits.length || !tickerA || !tickerB) return;
    var n = 0;
    tickerTimer = window.setInterval(function () {
      var c = credits[n % credits.length];
      tickerA.textContent = c[0];
      tickerB.textContent = c[1];
      n++;
    }, 110);
  }
  function stopTicker() {
    if (tickerTimer) window.clearInterval(tickerTimer);
    tickerTimer = null;
  }

  /* ---------- preload, then play --------------------------------------- */
  function preload(list, done) {
    var left = list.length;
    if (!left) return done();
    var settled = false;
    var finishOnce = function () {
      if (settled) return;
      settled = true;
      done();
    };
    var tick = function () { if (--left <= 0) finishOnce(); };
    for (var k = 0; k < list.length; k++) {
      var im = new Image();
      im.onload = tick;
      im.onerror = tick;
      im.src = list[k];
    }
    window.setTimeout(finishOnce, 1600); // never block for long
  }

  var tl = null;

  function play() {
    startTicker();

    var counterObj = { v: 0 };

    tl = gsap.timeline({
      defaults: { ease: "expo.out" },
      onComplete: function () {
        stopTicker();
        finish(false);
      }
    });

    gsap.set(
      nodes.map(function (n) { return n.el; }),
      { xPercent: -50, yPercent: -50, opacity: 0 }
    );

    // wordmark rises into view
    if (mark) {
      gsap.set(mark, { yPercent: 108 });
      tl.to(mark, { yPercent: 0, duration: 1.0 }, 0);
    }
    if (rule) {
      gsap.set(rule, { scaleX: 0 });
      tl.to(rule, { scaleX: 1, duration: 2.3, ease: "power2.inOut" }, 0.05);
    }
    if (meta) tl.fromTo(meta, { opacity: 0 }, { opacity: 1, duration: 0.5 }, 0.15);

    // graphics fly in
    nodes.forEach(function (n, idx) {
      tl.fromTo(
        n.el,
        { x: n.sx, y: n.sy, rotate: n.sr, scale: 0.34, opacity: 0 },
        {
          x: n.fx, y: n.fy, rotate: n.fr, scale: n.fs,
          opacity: 1, duration: 0.92, ease: "expo.out"
        },
        0.34 + idx * 0.072
      );
    });

    // counter
    if (counter) {
      tl.to(
        counterObj,
        {
          v: 100,
          duration: 2.5,
          ease: "power1.inOut",
          onUpdate: function () {
            var s = String(Math.round(counterObj.v));
            counter.textContent = (s.length < 2 ? "0" + s : s) + "%";
          }
        },
        0.2
      );
    }

    // everything blasts back out
    tl.to(
      nodes.map(function (n) { return n.el; }),
      {
        x: function (i) { return nodes[i].sx * 0.9; },
        y: function (i) { return nodes[i].sy * 0.9; },
        rotate: function (i) { return nodes[i].sr * 1.4; },
        scale: 0.3,
        opacity: 0,
        duration: 0.72,
        ease: "power3.in",
        stagger: { each: 0.022, from: "random" }
      },
      "+=0.18"
    );

    if (mark) tl.to(mark, { yPercent: -112, duration: 0.72, ease: "expo.in" }, "<");
    if (meta) tl.to(meta, { opacity: 0, duration: 0.4 }, "<");

    // overlay wipes up to reveal the page
    tl.to(overlay, { yPercent: -100, duration: 0.95, ease: "expo.inOut" }, "-=0.22");

    // hero copy rises in behind it
    tl.add(function () {
      if (window.WH && window.WH.revealHero) window.WH.revealHero();
    }, "-=0.55");
  }

  /* Escape bails out of the intro at any point */
  function onKey(e) {
    if (e.key !== "Escape") return;
    if (tl) tl.progress(1);
    else finish(true);
    stopTicker();
    document.removeEventListener("keydown", onKey);
  }
  document.addEventListener("keydown", onKey);

  preload(
    sources.slice(0, count),
    function () {
      // wait for fonts so the wordmark doesn't reflow mid-animation
      if (document.fonts && document.fonts.ready) {
        document.fonts.ready.then(play, play);
      } else {
        play();
      }
    }
  );
})();
