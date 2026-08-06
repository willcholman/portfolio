/* ==========================================================================
   site.js — theme, nav state, scroll reveals, contact form, copy-to-clipboard
   ========================================================================== */
(function () {
  "use strict";

  var root = document.documentElement;
  var STORE_KEY = "wh-theme";

  document.body.classList.remove("no-js");

  var reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (reduceMotion) document.body.classList.add("reduce-motion");

  /* ---------- Theme ---------------------------------------------------- */
  function setTheme(theme, animate) {
    if (!animate) {
      document.body.classList.add("no-transition");
      window.setTimeout(function () {
        document.body.classList.remove("no-transition");
      }, 60);
    }
    root.setAttribute("data-theme", theme);
    try { localStorage.setItem(STORE_KEY, theme); } catch (e) {}

    var btn = document.querySelector(".toggle");
    if (btn) {
      btn.setAttribute("aria-pressed", String(theme === "light"));
      btn.setAttribute(
        "aria-label",
        theme === "dark" ? "Switch to light mode" : "Switch to dark mode"
      );
    }
  }

  // The pre-paint script in <head> already set the attribute; sync the button.
  setTheme(root.getAttribute("data-theme") === "light" ? "light" : "dark", false);

  var toggle = document.querySelector(".toggle");
  if (toggle) {
    toggle.addEventListener("click", function () {
      setTheme(root.getAttribute("data-theme") === "light" ? "dark" : "light", true);
    });
  }

  /* ---------- Current nav item ----------------------------------------- */
  (function markCurrent() {
    // each page declares itself on <body data-page>, so this doesn't depend
    // on how the site happens to be hosted or what the path looks like
    var page = document.body.getAttribute("data-page");
    if (!page) return;
    var links = document.querySelectorAll(".nav__link");
    for (var i = 0; i < links.length; i++) {
      if (links[i].getAttribute("data-section") === page) {
        links[i].setAttribute("aria-current", "page");
      }
    }
  })();

  /* ---------- Scroll reveal -------------------------------------------- */
  (function reveals() {
    var items = document.querySelectorAll(".grid__item");
    if (!items.length) return;

    if (reduceMotion || !("IntersectionObserver" in window)) {
      for (var i = 0; i < items.length; i++) items[i].classList.add("is-in");
      return;
    }

    var io = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          var el = entry.target;
          var delay = parseInt(el.getAttribute("data-delay") || "0", 10);
          window.setTimeout(function () { el.classList.add("is-in"); }, delay);
          io.unobserve(el);
        });
      },
      { rootMargin: "0px 0px -8% 0px", threshold: 0.06 }
    );

    for (var j = 0; j < items.length; j++) {
      // stagger within each visual row
      items[j].setAttribute("data-delay", String((j % 3) * 90));
      io.observe(items[j]);
    }
  })();

  /* ---------- Copy to clipboard ---------------------------------------- */
  (function copyButtons() {
    var btns = document.querySelectorAll("[data-copy]");
    for (var i = 0; i < btns.length; i++) {
      btns[i].addEventListener("click", function (e) {
        var btn = e.currentTarget;
        var text = btn.getAttribute("data-copy");
        var done = function () {
          var original = btn.getAttribute("data-label") || btn.textContent;
          btn.setAttribute("data-label", original);
          btn.textContent = "Copied";
          btn.classList.add("is-done");
          window.setTimeout(function () {
            btn.textContent = original;
            btn.classList.remove("is-done");
          }, 1600);
        };

        // execCommand path — also the fallback when the async API rejects,
        // which it does if the document isn't focused or permission is denied
        var legacyCopy = function () {
          var ta = document.createElement("textarea");
          ta.value = text;
          ta.setAttribute("readonly", "");
          ta.style.position = "absolute";
          ta.style.left = "-9999px";
          document.body.appendChild(ta);
          ta.select();
          var ok = false;
          try { ok = document.execCommand("copy"); } catch (err) {}
          document.body.removeChild(ta);
          if (ok) done();
          return ok;
        };

        if (navigator.clipboard && navigator.clipboard.writeText) {
          navigator.clipboard.writeText(text).then(done, legacyCopy);
        } else {
          legacyCopy();
        }
      });
    }
  })();

  /* ---------- Home hero entrance --------------------------------------- */
  window.WH = window.WH || {};
  var heroRevealed = false;

  window.WH.revealHero = function () {
    if (heroRevealed) return;          // intro calls this twice by design; only land it once
    heroRevealed = true;

    var lines = document.querySelectorAll("[data-hero-line]");
    if (!lines.length) return;

    if (reduceMotion || typeof window.gsap === "undefined") {
      for (var i = 0; i < lines.length; i++) {
        lines[i].style.transform = "none";
        lines[i].style.opacity = "1";
      }
      return;
    }

    /* Declare the from-state explicitly. The pre-paint script writes
       `translateY(110%)`, which GSAP resolves to a pixel `y` — animating
       `yPercent` alone would leave that offset baked in. */
    window.gsap.fromTo(
      lines,
      { yPercent: 110, y: 0, opacity: 0 },
      {
        yPercent: 0,
        y: 0,
        opacity: 1,
        duration: 1.05,
        ease: "expo.out",
        stagger: 0.09,
        clearProps: "transform"
      }
    );
  };
})();
