/* ==========================================================================
   lightbox.js — click a project image to view it large

   The image scales up from exactly where the thumbnail sits, the page behind
   blurs out, and arrows step through the rest of that project's designs.
   Close with the ×, Escape, or by clicking the backdrop.
   ========================================================================== */
(function () {
  "use strict";

  var triggers = Array.prototype.slice.call(document.querySelectorAll("[data-zoom]"));
  if (!triggers.length) return;

  var reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  var gsap = window.gsap;
  var animated = !reduceMotion && typeof gsap !== "undefined";

  var items = triggers.map(function (btn) {
    var img = btn.querySelector("img");
    return { btn: btn, src: img.getAttribute("src"), alt: img.getAttribute("alt") || "", img: img };
  });

  /* ---------- build the overlay once ----------------------------------- */
  var box = document.createElement("div");
  box.className = "lightbox";
  box.setAttribute("role", "dialog");
  box.setAttribute("aria-modal", "true");
  box.setAttribute("aria-label", "Image viewer");
  box.innerHTML =
    '<button class="lightbox__backdrop" type="button" tabindex="-1" aria-label="Close viewer"></button>' +
    '<div class="lightbox__figure"><img class="lightbox__img" alt=""></div>' +
    '<button class="lightbox__btn lightbox__close" type="button" aria-label="Close viewer">' +
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M5 5l14 14M19 5L5 19"/></svg>' +
    "</button>" +
    '<button class="lightbox__btn lightbox__prev" type="button" aria-label="Previous design">' +
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 4L7 12l8 8"/></svg>' +
    "</button>" +
    '<button class="lightbox__btn lightbox__next" type="button" aria-label="Next design">' +
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 4l8 8-8 8"/></svg>' +
    "</button>" +
    '<p class="lightbox__count" data-lb-count></p>';
  document.body.appendChild(box);

  var backdrop = box.querySelector(".lightbox__backdrop");
  var figure = box.querySelector(".lightbox__figure");
  var bigImg = box.querySelector(".lightbox__img");
  var btnClose = box.querySelector(".lightbox__close");
  var btnPrev = box.querySelector(".lightbox__prev");
  var btnNext = box.querySelector(".lightbox__next");
  var count = box.querySelector("[data-lb-count]");
  var controls = [btnClose, btnPrev, btnNext];

  var index = -1;
  var isOpen = false;
  var busy = false;
  var lastFocus = null;

  function setCount() {
    count.textContent = (index + 1) + " / " + items.length;
  }

  /* Where the big image will land, once the browser has laid it out. */
  function finalRect() {
    return bigImg.getBoundingClientRect();
  }

  /* Transform that would put the big image exactly over a thumbnail. */
  function deltaFrom(thumb) {
    var t = thumb.getBoundingClientRect();
    var f = finalRect();
    if (!f.width || !f.height || !t.width) return { x: 0, y: 0, scale: 0.94 };
    return {
      x: (t.left + t.width / 2) - (f.left + f.width / 2),
      y: (t.top + t.height / 2) - (f.top + f.height / 2),
      scale: t.width / f.width
    };
  }

  var busyTimer = null;

  function settle() {
    busy = false;
    if (busyTimer) { window.clearTimeout(busyTimer); busyTimer = null; }
  }

  function show(i, fromThumb) {
    index = (i + items.length) % items.length;
    var item = items[index];

    busy = true;
    bigImg.setAttribute("src", item.src);
    bigImg.setAttribute("alt", item.alt);
    setCount();

    var paint = function () {
      if (!animated) {
        gsapSafeSet({ opacity: 1, x: 0, y: 0, scale: 1 });
        settle();
        return;
      }
      var d = fromThumb ? deltaFrom(fromThumb) : null;
      if (d) {
        gsap.fromTo(
          bigImg,
          { x: d.x, y: d.y, scale: d.scale, opacity: 1 },
          { x: 0, y: 0, scale: 1, duration: 0.52, ease: "expo.out", onComplete: settle }
        );
      } else {
        gsap.fromTo(
          bigImg,
          { opacity: 0, scale: 0.965 },
          { opacity: 1, scale: 1, duration: 0.34, ease: "power2.out", onComplete: settle }
        );
      }
    };

    // wait until the swapped-in image has dimensions, so finalRect() is real
    if (bigImg.complete && bigImg.naturalWidth) {
      requestAnimationFrame(paint);
    } else {
      bigImg.onload = function () { requestAnimationFrame(paint); };
      bigImg.onerror = settle;
    }

    // Never let the viewer strand itself: if the frame or the decode never
    // arrives, release the lock anyway so the arrows keep working.
    if (busyTimer) window.clearTimeout(busyTimer);
    busyTimer = window.setTimeout(settle, 900);
  }

  function gsapSafeSet(props) {
    if (animated) { gsap.set(bigImg, props); return; }
    bigImg.style.opacity = props.opacity;
    bigImg.style.transform = "none";
  }

  function open(i) {
    if (isOpen) return;
    isOpen = true;
    busy = true;
    lastFocus = document.activeElement;

    box.classList.add("is-open");
    document.body.classList.add("lightbox-open");

    if (animated) {
      gsap.set(bigImg, { opacity: 0 });
      gsap.to(backdrop, { opacity: 1, duration: 0.34, ease: "power2.out" });
      gsap.to(controls.concat([count]), { opacity: 1, duration: 0.3, delay: 0.14, ease: "power2.out" });
    } else {
      backdrop.style.opacity = "1";
      controls.forEach(function (c) { c.style.opacity = "1"; });
      count.style.opacity = "1";
    }

    show(i, items[i].img);
    btnClose.focus({ preventScroll: true });
  }

  function close() {
    if (!isOpen) return;
    isOpen = false;

    var thumb = index >= 0 ? items[index].img : null;

    var done = function () {
      box.classList.remove("is-open");
      document.body.classList.remove("lightbox-open");
      bigImg.removeAttribute("src");
      settle();
      if (lastFocus && lastFocus.focus) lastFocus.focus({ preventScroll: true });
    };

    if (!animated) {
      backdrop.style.opacity = "0";
      controls.forEach(function (c) { c.style.opacity = "0"; });
      count.style.opacity = "0";
      done();
      return;
    }

    busy = true;
    // shrink back into the thumbnail it came from
    var d = thumb ? deltaFrom(thumb) : { x: 0, y: 0, scale: 0.95 };
    gsap.to(bigImg, { x: d.x, y: d.y, scale: d.scale, opacity: 0, duration: 0.38, ease: "power3.in" });
    gsap.to(controls.concat([count]), { opacity: 0, duration: 0.2, ease: "power2.in" });
    gsap.to(backdrop, { opacity: 0, duration: 0.32, ease: "power2.in", onComplete: done });
  }

  function step(dir) {
    if (!isOpen || busy || items.length < 2) return;
    if (!animated) { show(index + dir, null); return; }
    busy = true;
    gsap.to(bigImg, {
      opacity: 0,
      scale: 0.975,
      duration: 0.16,
      ease: "power2.in",
      onComplete: function () { show(index + dir, null); }
    });
  }

  /* ---------- wiring ---------------------------------------------------- */
  triggers.forEach(function (btn, i) {
    btn.addEventListener("click", function () { open(i); });
  });

  btnClose.addEventListener("click", close);
  backdrop.addEventListener("click", close);
  btnPrev.addEventListener("click", function () { step(-1); });
  btnNext.addEventListener("click", function () { step(1); });

  document.addEventListener("keydown", function (e) {
    if (!isOpen) return;
    if (e.key === "Escape") { e.preventDefault(); close(); }
    else if (e.key === "ArrowLeft") { e.preventDefault(); step(-1); }
    else if (e.key === "ArrowRight") { e.preventDefault(); step(1); }
    else if (e.key === "Tab") {
      // keep focus inside the dialog
      var focusables = controls.filter(function (c) { return c.offsetParent !== null; });
      if (!focusables.length) return;
      var first = focusables[0];
      var last = focusables[focusables.length - 1];
      if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
      else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
    }
  });

  // swipe on touch
  (function swipe() {
    var x0 = null;
    figure.style.pointerEvents = "none";
    box.addEventListener("touchstart", function (e) {
      if (!isOpen || e.touches.length !== 1) return;
      x0 = e.touches[0].clientX;
    }, { passive: true });
    box.addEventListener("touchend", function (e) {
      if (x0 === null) return;
      var dx = e.changedTouches[0].clientX - x0;
      x0 = null;
      if (Math.abs(dx) > 55) step(dx < 0 ? 1 : -1);
    }, { passive: true });
  })();

  window.addEventListener("resize", function () {
    if (isOpen && animated) gsap.set(bigImg, { x: 0, y: 0, scale: 1 });
  });
})();
