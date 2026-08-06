# Will Holman — Portfolio

Static site. No build step, no dependencies to install. Black and white, Helvetica,
dark mode by default.

## Preview locally

```
powershell -ExecutionPolicy Bypass -File tools\serve.ps1
```

Then open <http://localhost:8123>. Ctrl+C to stop.

(You can also just double-click `index.html`, but the browser blocks `localStorage`
on `file://`, so the light/dark preference won't stick. Use the server.)

## Structure

```
index.html              landing page — intro animation, masthead, the six piles
about.html              portrait, bio, social icons
contact.html            mailto form + direct links
projects/*.html         one page per project (generated)

assets/css/site.css     all styling, both themes
assets/js/site.js       theme toggle, scroll reveals, contact form
assets/js/intro.js      entrance animation
assets/js/pile.js       pile → morph → shape → scatter interaction
assets/js/lightbox.js   click-to-zoom viewer on project pages
assets/js/data.js       intro payload (generated)
assets/vendor/          GSAP 3.13, vendored locally
assets/img/             web-ready artwork (originals are gitignored)

tools/generate.ps1      rebuilds index.html, projects/*.html and data.js
tools/serve.ps1         local preview server
```

## Adding or changing artwork

1. Drop new full-resolution files into the matching source folder
   (`Tour Posters/`, `Merch Designs/`, …).
2. Run the asset pipeline to produce web-sized copies in `assets/img/`.
3. Run `tools\generate.ps1` to rebuild the project pages and intro payload.

To change which images appear in a pile, or which one the pile morphs into,
edit the `pile` and `target` fields in the `$Projects` block at the top of
`tools/generate.ps1`, then re-run it.

Everything else — copy, links, layout — is plain HTML you can edit directly.

## Deploying to GitHub Pages

Create an empty repo named `willcholman.github.io` on GitHub, then:

```
git remote add origin https://github.com/willcholman/willcholman.github.io.git
git branch -M main
git push -u origin main
```

In the repo's **Settings → Pages**, set Source to `main` / `/ (root)`.
The site goes live at <https://willcholman.github.io>.
