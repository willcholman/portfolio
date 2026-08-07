# =============================================================================
#  generate.ps1
#  Rebuilds index.html (the projects landing page), projects/<slug>.html and
#  assets/js/data.js from whatever is currently in assets/img/.
#  Re-run after adding or removing artwork.
#
#      powershell -ExecutionPolicy Bypass -File tools\generate.ps1
# =============================================================================

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Img  = Join-Path $Root 'assets\img'

# Built from code points so this file stays pure ASCII on disk — PowerShell 5.1
# misreads UTF-8 without a BOM, which would mangle literal typographic marks.
$em = [char]0x2014   # em dash
$rq = [char]0x2019   # right single quote
$bar = [char]0x2502  # box-drawing vertical bar, as used in the tagline

function Write-Utf8([string]$Path, [string]$Text) {
  $enc = New-Object System.Text.UTF8Encoding($false)
  [IO.File]::WriteAllText($Path, $Text, $enc)
}

function HtmlEnc([string]$s) {
  if ($null -eq $s) { return '' }
  return ($s -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;')
}

# --- project definitions -----------------------------------------------------
#  Array order drives the grid order on the landing page, the 01..06 numbering,
#  and the previous/next links.
#
#  pile     = the six cards, in z-order from BACK to FRONT
#  target   = the front card, which the stack collapses onto and which becomes
#             the solid shape carrying the project name (must be last in pile)
#  label    = optional raw HTML for the hover label, for controlling line breaks
#  gridLead = optional running order for the top of the project page grid.
#             Without it the grid follows `pile`, but that array also fixes the
#             stacking order, so set this when the two need to differ.
#             Anything not listed is appended alphabetically.
$Projects = @(
  [ordered]@{
    slug   = 'social-media'
    title  = 'Social Media'
    label  = ''
    client = 'The Design Group'
    desc   = 'Work produced for clients during my time while interning at The Design Group.'
    target = 'illumis-1'
    pile   = @('tdg-1', 'rcm-3', 'greener-2', 'coggin-2', 'seabrook-1', 'illumis-1')
  },
  [ordered]@{
    slug   = 'usc-esports'
    title  = 'USC Esports'
    label  = ''
    client = ''
    desc   = 'Designs created from my time as Gamecock Esports Social Media Manager.'
    target = 'necc-champions-for-usc-esports'
    # player introduction post sits mid-stack, near the centre, tucked behind the front card
    pile   = @('playoffs-gameday-graphic-for-usc-gamecok-esports-smash-bros', 'season-start-usc-esports', 'usc-pubg-1st-place', 'gameday-usc-cs2', 'usc-player-introduction-post', 'necc-champions-for-usc-esports')
    # ... but runs second on the project page grid
    gridLead = @('playoffs-gameday-graphic-for-usc-gamecok-esports-smash-bros', 'usc-player-introduction-post', 'season-start-usc-esports', 'usc-pubg-1st-place', 'gameday-usc-cs2', 'necc-champions-for-usc-esports')
  },
  [ordered]@{
    slug   = 'promotional-material'
    title  = 'Promotional Material'
    label  = ''
    client = ''
    desc   = 'Print, out-of-home, and direct mail for clients across insurance, healthcare, automotive, and nonprofit.'
    target = 'honda-3'
    pile   = @('honda-1', 'honda-2', 'engage', 'unausa', 'carver-insurance-1', 'honda-3')
  },
  [ordered]@{
    slug   = 'merch-designs'
    title  = 'Merch Designs'
    label  = 'Merch<br>Designs'
    client = ''
    desc   = "I${rq}ve created over 100 designs for clients in the past few years${em}here are some of my favorites."
    target = 'official-design-for-zumiez-dog-years'
    pile   = @('design-for-zillakami', 'design-for-klean-up-krew-racing', 'design-for-sosmula-nyc', 'design-for-kamaara-villains', 'official-design-for-city-morgue-band', 'official-design-for-zumiez-dog-years')
  },
  [ordered]@{
    slug   = 'sports-posters'
    title  = 'Sports Posters'
    label  = ''
    client = ''
    desc   = 'Posters for UFC fights and other events.'
    target = 'ufc-van-vs-taira-concept'
    pile   = @('ufc-300-concept', 'ufc-320-concept', 'ufc-mexico-concept', 'ufc-313-concept', 'ufc-329-concept', 'ufc-van-vs-taira-concept')
  },
  [ordered]@{
    slug   = 'tour-posters'
    title  = 'Tour Posters'
    label  = ''
    client = ''
    desc   = "Tour and show posters built around each artist${rq}s visual world."
    target = 'samurai-tour'
    pile   = @('yeat-tour', 'zillakami-tour', 'opium-tour', 'takanaka-tour', 'joji-tour', 'samurai-tour')
  }
)

# --- resolve slug -> actual files -------------------------------------------
function Get-ProjectImages([string]$projectSlug) {
  $dir = Join-Path $Img $projectSlug
  $map = @{}
  foreach ($f in Get-ChildItem $dir -File) {
    $n = $f.Name
    if ($n -match '^(.+)-lg\.(jpg|png)$') {
      $base = $Matches[1]; $ext = $Matches[2]
      if (-not $map.ContainsKey($base)) { $map[$base] = @{} }
      $map[$base].lg = "$base-lg.$ext"
      $map[$base].sm = "$base-sm.$ext"
    }
    elseif ($n -match '^(.+)\.gif$') {
      $base = $Matches[1]
      if (-not $map.ContainsKey($base)) { $map[$base] = @{} }
      $map[$base].lg = $n
      $map[$base].sm = $n
    }
  }
  return $map
}

# --- editorial grid rhythm (each run of spans sums to 12) --------------------
$SpanPattern = @(7, 5, 5, 7, 4, 4, 4, 6, 6, 8, 4, 4, 8)

# --- shared chrome -----------------------------------------------------------
function Get-Head([string]$prefix, [string]$title, [string]$desc) {
  $t = HtmlEnc $title
  $d = HtmlEnc $desc
  return @"
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$t</title>
<meta name="description" content="$d">
<meta name="theme-color" content="#000000">
<link rel="icon" type="image/svg+xml" href="${prefix}assets/favicon.svg">
<link rel="stylesheet" href="${prefix}assets/css/site.css">
<script>
  (function () {
    try {
      var t = localStorage.getItem('wh-theme');
      document.documentElement.setAttribute('data-theme', t === 'light' ? 'light' : 'dark');
    } catch (e) {
      document.documentElement.setAttribute('data-theme', 'dark');
    }
  })();
</script>
"@
}

function Get-Header([string]$prefix) {
  # Extensionless links: GitHub Pages resolves /about to about.html, and
  # tools/serve.ps1 does the same locally. An empty prefix would give href="",
  # so the site root is written as "./".
  # NB: $home is read-only in PowerShell, hence $homeHref
  $homeHref = if ($prefix) { $prefix } else { './' }
  return @"
<header class="header">
  <div class="header__inner">
    <div class="header__brand">
      <a class="logo" href="$homeHref" aria-label="Will Holman $em home"><span>W</span><span>H</span></a>
      <time class="clock" data-clock></time>
    </div>
    <nav class="nav" aria-label="Primary">
      <a class="nav__link" data-section="projects" href="$homeHref">Projects<span class="nav__arrow" aria-hidden="true">&#8599;&#65038;</span></a>
      <a class="nav__link" data-section="about" href="${prefix}about">About<span class="nav__arrow" aria-hidden="true">&#8599;&#65038;</span></a>
      <a class="nav__link" data-section="contact" href="${prefix}contact">Contact<span class="nav__arrow" aria-hidden="true">&#8599;&#65038;</span></a>
      <button class="toggle" type="button" aria-pressed="false" aria-label="Switch to light mode">
        <span class="toggle__knob" aria-hidden="true"></span>
        <span class="toggle__icon toggle__icon--sun" aria-hidden="true">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="4.2"/><path d="M12 2.4v2.2M12 19.4v2.2M2.4 12h2.2M19.4 12h2.2M5 5l1.6 1.6M17.4 17.4L19 19M19 5l-1.6 1.6M6.6 17.4L5 19"/></svg>
        </span>
        <span class="toggle__icon toggle__icon--moon" aria-hidden="true">
          <svg viewBox="0 0 24 24" fill="currentColor"><path d="M20.4 14.9A8.6 8.6 0 0 1 9.1 3.6a8.6 8.6 0 1 0 11.3 11.3Z"/></svg>
        </span>
      </button>
    </nav>
  </div>
</header>
"@
}

function Get-Footer() {
  return @"
  <footer class="footer shell">
    <p>&copy;&#65038; 2026 Will Holman</p>
    <nav class="footer__social" aria-label="Social">
      <a href="https://www.linkedin.com/in/willcholman/" target="_blank" rel="noopener noreferrer">LinkedIn</a>
      <a href="https://www.instagram.com/willcholman" target="_blank" rel="noopener noreferrer">Instagram</a>
      <a href="https://github.com/willcholman" target="_blank" rel="noopener noreferrer">GitHub</a>
      <a href="mailto:willcholman@gmail.com">Email</a>
    </nav>
  </footer>
"@
}

# =============================================================================
#  index.html - intro, masthead, and the piles
# =============================================================================
$pileBlocks = @()
foreach ($p in $Projects) {
  $map = Get-ProjectImages $p.slug

  # honour the declared z-order; guarantee the target ends up on top
  $order = @($p.pile | Where-Object { $_ -ne $p.target }) + @($p.target)

  $cards = @()
  foreach ($s in $order) {
    if (-not $map.ContainsKey($s)) { Write-Warning "  missing pile image: $($p.slug)/$s"; continue }
    $attr = if ($s -eq $p.target) { ' data-target' } else { '' }
    $src = "assets/img/$($p.slug)/$($map[$s].sm)"
    $cards += "        <img class=`"pile__card`"$attr src=`"$src`" alt=`"`" aria-hidden=`"true`" loading=`"lazy`" decoding=`"async`">"
  }

  $maskSrc = "assets/img/$($p.slug)/$($map[$p.target].sm)"
  # `label` is raw HTML when set, so a project can control its own line breaks
  $label = if ($p.label) { $p.label } else { HtmlEnc $p.title }
  $aria = HtmlEnc "$($p.title) $em view project"
  $cardsHtml = ($cards -join "`n")

  $pileBlocks += @"
      <a class="pile" data-pile href="projects/$($p.slug)" aria-label="$aria">
        <div class="pile__stage" data-pile-stage>
$cardsHtml
          <div class="pile__shape" data-pile-shape style="-webkit-mask-image:url('$maskSrc');mask-image:url('$maskSrc')"></div>
          <span class="pile__label" data-pile-label>$label</span>
        </div>
      </a>
"@
}

$indexHtml = @"
<!DOCTYPE html>
<html lang="en" data-theme="dark">
<head>
$(Get-Head '' "Will Holman $em Marketing & Design" "Will Holman $em Marketing & Design. Poster, merch, social and campaign design.")
</head>
<body class="no-js" data-page="projects">

<a class="skip-link" href="#main">Skip to content</a>

<div class="intro" data-intro>
  <div class="intro__stage" data-intro-stage></div>

  <strong class="intro__mark"><span data-intro-mark>WH</span></strong>

  <div class="intro__rule" data-intro-rule></div>
  <div class="intro__meta" data-intro-meta>
    <div class="intro__ticker"><span data-ticker="project">PROJECT</span></div>
    <div class="intro__ticker" style="text-align:center"><span data-ticker="client">CLIENT</span></div>
    <div class="intro__count" data-intro-count>00%</div>
  </div>
</div>

$(Get-Header '')

<main class="main" id="main">

  <div class="home-head">
    <div class="home-head__blur" aria-hidden="true"></div>
    <div class="shell">
      <section class="hero">
        <h1 class="hero__name reveal-line"><span data-hero-line>Will Holman</span></h1>
        <p class="hero__tagline reveal-line"><span data-hero-line>Marketing &amp; Design</span></p>
      </section>
    </div>
  </div>

  <div class="shell">
    <div class="piles">
$($pileBlocks -join "`n")
    </div>
  </div>

$(Get-Footer)
</main>

<script>
  // hide the masthead copy before first paint so it can rise in behind the intro
  (function () {
    var lines = document.querySelectorAll('[data-hero-line]');
    for (var i = 0; i < lines.length; i++) {
      lines[i].style.transform = 'translateY(110%)';
      lines[i].style.opacity = '0';
    }
  })();
</script>

<script src="assets/vendor/gsap.min.js"></script>
<script src="assets/js/data.js"></script>
<script src="assets/js/site.js"></script>
<script src="assets/js/pile.js"></script>
<script src="assets/js/intro.js"></script>
</body>
</html>
"@

Write-Utf8 (Join-Path $Root 'index.html') $indexHtml
Write-Output "wrote index.html ($($Projects.Count) piles)"

# =============================================================================
#  projects/<project>.html
# =============================================================================
$projDir = Join-Path $Root 'projects'
New-Item -ItemType Directory -Force -Path $projDir | Out-Null

for ($i = 0; $i -lt $Projects.Count; $i++) {
  $p = $Projects[$i]
  $map = Get-ProjectImages $p.slug

  # gridLead if given, otherwise the pile order; then everything else alphabetically
  $order = if ($p.gridLead) { $p.gridLead } else { $p.pile }
  $lead = @($order | Where-Object { $map.ContainsKey($_) })
  $rest = @($map.Keys | Where-Object { $lead -notcontains $_ } | Sort-Object)
  $all = $lead + $rest

  $items = @()
  for ($k = 0; $k -lt $all.Count; $k++) {
    $s = $all[$k]
    $span = $SpanPattern[$k % $SpanPattern.Count]
    $src = "../assets/img/$($p.slug)/$($map[$s].lg)"
    $alt = HtmlEnc ("{0} {1} {2}" -f $p.title, $em, ($s -replace '-', ' '))
    $items += @"
        <figure class="grid__item" data-span="$span">
          <button class="grid__zoom" type="button" data-zoom aria-label="$alt $em view larger">
            <img src="$src" alt="$alt" loading="lazy" decoding="async">
          </button>
        </figure>
"@
  }

  $prev = $Projects[($i - 1 + $Projects.Count) % $Projects.Count]
  $next = $Projects[($i + 1) % $Projects.Count]

  $clientHtml = ''
  if ($p.client) { $clientHtml = "      <p class=`"page-head__client`">$(HtmlEnc $p.client)</p>`n" }

  $gridClass = if ($p.slug -eq 'merch-designs') { 'grid grid--cutout' } else { 'grid' }
  $num = '{0:00}' -f ($i + 1)

  $page = @"
<!DOCTYPE html>
<html lang="en" data-theme="dark">
<head>
$(Get-Head '../' "$($p.title) $em Will Holman" $p.desc)
</head>
<body class="no-js" data-page="projects">

<a class="skip-link" href="#main">Skip to content</a>

$(Get-Header '../')

<main class="main" id="main">
  <div class="shell">

    <div class="page-head">
      <a class="back-link" href="../" aria-label="Back to projects">
        <span class="back-link__icon" aria-hidden="true">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 4L7 12l8 8"/></svg>
        </span>
      </a>
      <p class="page-head__label">Projects / $num</p>
      <h1 class="page-head__title">$(HtmlEnc $p.title)</h1>
$clientHtml      <p class="page-head__sub">$(HtmlEnc $p.desc)</p>
    </div>

    <div class="$gridClass">
$($items -join "`n")
    </div>

    <nav class="project-nav" aria-label="Projects">
      <div class="project-nav__prev">
        <p class="project-nav__label">Previous</p>
        <a class="project-nav__link" href="$($prev.slug)">$(HtmlEnc $prev.title)</a>
      </div>
      <div>
        <p class="project-nav__label">Next</p>
        <a class="project-nav__link" href="$($next.slug)">$(HtmlEnc $next.title)</a>
      </div>
    </nav>

  </div>

$(Get-Footer)
</main>

<script src="../assets/vendor/gsap.min.js"></script>
<script src="../assets/js/site.js"></script>
<script src="../assets/js/lightbox.js"></script>
</body>
</html>
"@

  Write-Utf8 (Join-Path $projDir "$($p.slug).html") $page
  Write-Output "wrote projects/$($p.slug).html ($($all.Count) images)"
}

# =============================================================================
#  assets/js/data.js  - intro payload
# =============================================================================
$IntroPicks = @(
  'tour-posters/samurai-tour', 'sports-posters/ufc-van-vs-taira-concept', 'merch-designs/official-design-for-zumiez-dog-years',
  'social-media/illumis-1', 'usc-esports/necc-champions-for-usc-esports', 'promotional-material/honda-3',
  'tour-posters/yeat-tour', 'sports-posters/ufc-300-concept', 'merch-designs/design-for-zillakami',
  'social-media/rcm-3', 'usc-esports/season-start-usc-esports', 'promotional-material/honda-1',
  'tour-posters/zillakami-tour', 'sports-posters/ufc-320-concept', 'merch-designs/design-for-klean-up-krew-racing',
  'social-media/seabrook-1', 'usc-esports/usc-player-introduction-post',
  'promotional-material/engage', 'tour-posters/takanaka-tour', 'sports-posters/ufc-mexico-concept',
  'merch-designs/design-for-kamaara-villains', 'social-media/tdg-1', 'tour-posters/joji-tour'
)

$introPaths = @()
$maps = @{}
foreach ($p in $Projects) { $maps[$p.slug] = Get-ProjectImages $p.slug }

foreach ($pick in $IntroPicks) {
  $parts = $pick.Split('/')
  $proj = $parts[0]; $slug = $parts[1]
  if ($maps[$proj].ContainsKey($slug)) {
    $introPaths += "assets/img/$proj/$($maps[$proj][$slug].sm)"
  } else {
    Write-Warning "  missing intro image: $pick"
  }
}

$Credits = @(
  @('TOUR POSTER', 'JOJI'), @('TOUR POSTER', 'THE WEEKND'), @('TOUR POSTER', 'YEAT'),
  @('TOUR POSTER', 'ZILLAKAMI'), @('TOUR POSTER', 'TAKANAKA'), @('TOUR POSTER', 'WICCA PHASE'),
  @('FIGHT POSTER', 'UFC 300'), @('FIGHT POSTER', 'UFC 313'), @('FIGHT POSTER', 'UFC 316'),
  @('FIGHT POSTER', 'UFC MEXICO'), @('FIGHT POSTER', 'UFC RIO'),
  @('MERCH', 'KAMAARA'), @('MERCH', 'SOSMULA'), @('MERCH', 'CITY MORGUE'),
  @('MERCH', 'ZUMIEZ'), @('MERCH', 'KLEAN UP KREW'),
  @('SOCIAL', 'ILLUMIS GLOBAL'), @('SOCIAL', 'RCM MARITIME'), @('SOCIAL', 'SEABROOK ISLAND'),
  @('SOCIAL', 'COGGIN'), @('SOCIAL', 'GREENER CORP'),
  @('ESPORTS', 'USC GAMECOCKS'), @('ESPORTS', 'NECC'),
  @('OUT-OF-HOME', 'HONDA'), @('PRINT', 'CARVER INSURANCE'),
  @('PRINT', 'UNA-USA'), @('BRAND', 'ENGAGE')
)

$imgJs = ($introPaths | ForEach-Object { "    `"$_`"" }) -join ",`n"
$credJs = ($Credits | ForEach-Object { "    [`"$($_[0])`", `"$($_[1])`"]" }) -join ",`n"

$dataJs = @"
/* Generated by tools/generate.ps1 - do not edit by hand. */
window.WH_DATA = {
  introImages: [
$imgJs
  ],
  introCredits: [
$credJs
  ]
};
"@

Write-Utf8 (Join-Path $Root 'assets\js\data.js') $dataJs
Write-Output "wrote assets/js/data.js ($($introPaths.Count) intro images)"

# --- clear out the previous structure ---------------------------------------
$oldWorkPage = Join-Path $Root 'work.html'
if (Test-Path $oldWorkPage) { Remove-Item $oldWorkPage -Force; Write-Output 'removed work.html (index.html is the projects page now)' }
$oldWorkDir = Join-Path $Root 'work'
if (Test-Path $oldWorkDir) { Remove-Item $oldWorkDir -Recurse -Force; Write-Output 'removed work/ (moved to projects/)' }

Write-Output 'done.'
