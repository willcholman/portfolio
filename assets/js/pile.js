/* ==========================================================================
   pile.js — the project piles

   rest      scattered stack of images
   hover     the stack converges into a single image …
             … which fades to a solid shape (white on dark, black on light)
             carrying the project name in bold Helvetica
   click     the images scatter back out of the shape, then we navigate
   ========================================================================== */
(function () {
  "use strict";

  var piles = document.querySelectorAll("[data-pile]");
  if (!piles.length) return;

  var reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  var hasHover = window.matchMedia("(hover: hover) and (pointer: fine)").matches;

  /* Without GSAP (or on reduced motion) the CSS fallback drives the visuals,
     but the label still has to be sized to the shape — do that either way. */
  var animated = !reduceMotion && typeof window.gsap !== "undefined";
  var gsap = window.gsap;

  // one "snap back to rest" callback per pile, used on back/forward navigation
  var resetters = [];

  /* Resting scatter. Last entry is the target card, so it sits on top and
     nearest the centre — the stack visibly collapses onto it.

     These values are bounded: for the worst case (a square image, which
     spreads furthest once rotated) the extent from the stage centre is
     |offset| + (scale/2)(|cos r| + |sin r|), which stays under 0.5 of the
     stage for every row below. So a card can never escape its own stage,
     and neighbouring collections cannot touch however tight the grid gap is.
     Mirrored in the :nth-child rules in site.css — change both together. */
  var REST = [
    { x: -16, y:  -9, r: -12, s: 0.52 },
    { x:  14, y: -13, r:   8, s: 0.50 },
    { x: -20, y:  11, r:  -5, s: 0.49 },
    { x:  19, y:   9, r:  12, s: 0.50 },
    { x:  -4, y:  -2, r:   4, s: 0.55 },
    { x:   2, y:  13, r:  -3, s: 0.58 }
  ];

  var MERGED_SCALE = 0.82;

  function setup(pile) {
    var stage = pile.querySelector("[data-pile-stage]");
    var cards = Array.prototype.slice.call(pile.querySelectorAll(".pile__card"));
    var shape = pile.querySelector("[data-pile-shape]");
    var label = pile.querySelector("[data-pile-label]");
    var target = pile.querySelector(".pile__card[data-target]");
    if (!stage || !cards.length || !target) return;

    var state = "rest";      // rest | merged | leaving
    var tl = null;

    /* --- keep the label inside the shape's silhouette ------------------- */
    function fitLabel() {
      if (!label) return;
      var box = stage.getBoundingClientRect();
      if (!box.width) return;

      var nw = target.naturalWidth || 3;
      var nh = target.naturalHeight || 4;
      var ar = nw / nh;

      // object-fit: contain inside a square stage
      var w = ar >= 1 ? box.width : box.height * ar;
      var h = ar >= 1 ? box.width / ar : box.height;

      w *= MERGED_SCALE;
      h *= MERGED_SCALE;

      var padX = Math.max(8, (box.width - w) / 2 + box.width * 0.05);
      var padY = Math.max(8, (box.height - h) / 2 + box.height * 0.05);
      label.style.paddingLeft = padX + "px";
      label.style.paddingRight = padX + "px";
      label.style.paddingTop = padY + "px";
      label.style.paddingBottom = padY + "px";
    }

    if (target.complete) fitLabel();
    else target.addEventListener("load", fitLabel);
    window.addEventListener("resize", fitLabel);

    if (!animated) return; // CSS handles the rest state and the hover swap

    /* --- rest layout ----------------------------------------------------
       x/y are pinned to 0 everywhere below on purpose. The :nth-child rules
       in site.css express the same rest state as a percentage translate for
       the no-JS/reduced-motion case; GSAP resolves that into a *pixel* x/y
       when it reads the computed transform, which would then stack on top of
       xPercent/yPercent and offset every card twice. */
    function kill() { if (tl) { tl.kill(); tl = null; } }

    /* Snap straight back to the resting pile with no animation. */
    function applyRest() {
      kill();
      state = "rest";
      cards.forEach(function (card, i) {
        var r = REST[i % REST.length];
        gsap.set(card, {
          xPercent: r.x, yPercent: r.y,
          x: 0, y: 0,
          rotation: r.r, scale: r.s,
          zIndex: i + 1, opacity: 1
        });
      });
      gsap.set(shape, { scale: MERGED_SCALE, opacity: 0, zIndex: 50 });
      gsap.set(label, { opacity: 0, y: 14, zIndex: 51 });
    }

    applyRest();
    resetters.push(applyRest);

    /* --- converge ------------------------------------------------------- */
    function merge() {
      if (state === "merged" || state === "leaving") return;
      state = "merged";
      kill();

      tl = gsap.timeline();

      // everything slides onto the target's footprint
      tl.to(cards, {
        xPercent: 0, yPercent: 0, x: 0, y: 0, rotation: 0, scale: MERGED_SCALE,
        duration: 0.62, ease: "expo.out",
        stagger: { each: 0.022, from: "edges" }
      }, 0);

      // the non-target frames dissolve away, leaving one image
      var others = cards.filter(function (c) { return c !== target; });
      tl.to(others, {
        opacity: 0, duration: 0.34, ease: "power2.inOut",
        stagger: { each: 0.02, from: "edges" }
      }, 0.24);

      // then it snaps to a solid shape …
      tl.to(shape, { opacity: 1, duration: 0.22, ease: "power2.in" }, 0.5);
      tl.to(target, { opacity: 0, duration: 0.16 }, 0.56);

      // … and the name lands on it
      tl.to(label, { opacity: 1, y: 0, duration: 0.42, ease: "expo.out" }, 0.58);
    }

    /* --- back to the pile ----------------------------------------------- */
    function scatter() {
      if (state === "rest" || state === "leaving") return;
      state = "rest";
      kill();

      tl = gsap.timeline();
      tl.to([label], { opacity: 0, y: 14, duration: 0.2, ease: "power2.in" }, 0);
      tl.to(shape, { opacity: 0, duration: 0.24, ease: "power2.in" }, 0.04);
      tl.to(target, { opacity: 1, duration: 0.2 }, 0.12);

      cards.forEach(function (card, i) {
        var r = REST[i % REST.length];
        tl.to(card, {
          xPercent: r.x, yPercent: r.y, x: 0, y: 0,
          rotation: r.r, scale: r.s, opacity: 1,
          duration: 0.68, ease: "expo.out"
        }, 0.1 + i * 0.018);
      });
    }

    /* --- burst out of the shape, then navigate --------------------------- */
    function launch(href) {
      if (state === "leaving") return;
      state = "leaving";
      kill();

      var navigated = false;
      var go = function () {
        if (navigated) return;
        navigated = true;
        window.location.href = href;
      };

      tl = gsap.timeline({ onComplete: go });

      tl.to(label, { opacity: 0, duration: 0.16, ease: "power2.in" }, 0);
      tl.to(shape, { opacity: 0, duration: 0.2, ease: "power2.in" }, 0.06);

      // every image reappears on the shape's footprint …
      tl.set(cards, { opacity: 1, xPercent: 0, yPercent: 0, x: 0, y: 0, rotation: 0, scale: MERGED_SCALE }, 0.1);

      // … and flies outward
      cards.forEach(function (card, i) {
        var ang = (i / cards.length) * Math.PI * 2 + 0.6;
        tl.to(card, {
          xPercent: Math.cos(ang) * 165,
          yPercent: Math.sin(ang) * 165,
          x: 0, y: 0,
          rotation: (i % 2 ? 1 : -1) * (35 + i * 9),
          scale: 0.42,
          opacity: 0,
          duration: 0.62,
          ease: "power3.in"
        }, 0.14 + i * 0.028);
      });

      // don't let a slow frame strand the visitor
      window.setTimeout(go, 900);
    }

    /* --- wiring ---------------------------------------------------------- */
    if (hasHover) {
      pile.addEventListener("pointerenter", merge);
      pile.addEventListener("pointerleave", scatter);
      pile.addEventListener("focusin", merge);
      pile.addEventListener("focusout", scatter);
    } else if ("IntersectionObserver" in window) {
      // touch: the pile performs itself as it scrolls into view
      var io = new IntersectionObserver(
        function (entries) {
          entries.forEach(function (e) {
            if (e.isIntersecting) merge();
            else scatter();
          });
        },
        { threshold: 0.55 }
      );
      io.observe(pile);
    } else {
      merge();
    }

    pile.addEventListener("click", function (e) {
      var href = pile.getAttribute("href");
      if (!href || e.metaKey || e.ctrlKey || e.shiftKey || e.button > 0) return;
      e.preventDefault();
      if (state !== "merged") {
        merge();
        window.setTimeout(function () { launch(href); }, 240);
      } else {
        launch(href);
      }
    });
  }

  Array.prototype.forEach.call(piles, setup);

  /* Clicking a pile scatters its cards off the stage at opacity 0 and then
     navigates. Browsers restore this page from the back/forward cache exactly
     as it was — inline styles and all — so pressing Back brought you to a
     collection that looked like it had vanished. Reset on the way out (so the
     cached snapshot is clean) and again on the way back in. */
  function resetAll() {
    for (var i = 0; i < resetters.length; i++) resetters[i]();
  }
  window.addEventListener("pagehide", resetAll);
  window.addEventListener("pageshow", function (e) {
    if (e.persisted) resetAll();
  });
})();
