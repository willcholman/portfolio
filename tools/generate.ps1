# =============================================================================
#  generate.ps1
#  Rebuilds assets/js/data.js, work.html and work/<project>.html from whatever
#  is currently in assets/img/. Re-run after adding or removing artwork.
#
#      powershell -ExecutionPolicy Bypass -File tools\generate.ps1
# =============================================================================

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Img  = Join-Path $Root 'assets\img'

function Write-Utf8([string]$Path, [string]$Text) {
  $enc = New-Object System.Text.UTF8Encoding($false)
  [IO.File]::WriteAllText($Path, $Text, $enc)
}

function HtmlEnc([string]$s) {
  if ($null -eq $s) { return '' }
  return ($s -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;')
}

# --- project definitions -----------------------------------------------------
$Projects = @(
  [ordered]@{
    slug   = 'tour-posters'
    title  = 'Tour Posters'
    client = ''
    desc   = "Tour and show posters built around each artist's visual world."
    target = 'samurai-tour'
    pile   = @('yeat-tour', 'zillakami-tour', 'opium-tour', 'takanaka-tour', 'joji-tour', 'samurai-tour')
  },
  [ordered]@{
    slug   = 'sports-posters'
    title  = 'Sports Posters'
    client = ''
    desc   = 'Posters for UFC fights and other events.'
    target = 'ufc-329-concept'
    pile   = @('ufc-300-concept', 'ufc-320-concept', 'ufc-mexico-concept', 'ufc-313-concept', 'ufc-van-vs-taira-concept', 'ufc-329-concept')
  },
  [ordered]@{
    slug   = 'merch-designs'
    title  = 'Merch Designs'
    client = ''
    desc   = "I've created over 100 designs for clients in the past few years - here are some of my favorites."
    target = 'design-for-kamaara-villains'
    pile   = @('design-for-zillakami', 'design-for-klean-up-krew-racing', 'design-for-sosmula-nyc', 'official-design-for-zumiez-dog-years', 'official-design-for-city-morgue-band', 'design-for-kamaara-villains')
  },
  [ordered]@{
    slug   = 'social-media'
    title  = 'Social Media'
    client = 'The Design Group'
    desc   = 'Work produced for clients during my time while interning at The Design Group.'
    target = 'illumis-2'
    pile   = @('tdg-1', 'rcm-3', 'greener-2', 'coggin-2', 'seabrook-1', 'illumis-2')
  },
  [ordered]@{
    slug   = 'usc-esports'
    title  = 'USC Esports'
    client = 'Gamecock Esports'
    desc   = 'Designs created from my time as Gamecock Esports Social Media Manager.'
    target = 'necc-champions-for-usc-esports'
    pile   = @('playoffs-gameday-graphic-for-usc-gamecok-esports-smash-bros', 'season-start-usc-esports', 'usc-pubg-1st-place', 'gameday-usc-cs2', 'necc-usc-cs2-qualified', 'necc-champions-for-usc-esports')
  },
  [ordered]@{
    slug   = 'promotional-material'
    title  = 'Promotional Material'
    client = ''
    desc   = 'Print, out-of-home, and direct mail for clients across insurance, healthcare, automotive, and nonprofit.'
    target = 'honda-3'
    pile   = @('honda-1', 'honda-2', 'engage', 'unausa', 'carver-insurance-1', 'honda-3')
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
<link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><rect width='100' height='100' fill='%23000'/><text x='50' y='50' font-family='Helvetica,Arial' font-size='52' font-weight='700' fill='%23fff' text-anchor='middle' dominant-baseline='central' letter-spacing='-4'>WH</text></svg>">
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
  return @"
<header class="header">
  <div class="header__inner">
    <a class="logo" href="${prefix}index.html" aria-label="Will Holman - home"><span>W</span><span>H</span></a>
    <nav class="nav" aria-label="Primary">
      <a class="nav__link" data-section="work" href="${prefix}work.html">Work<span class="nav__arrow" aria-hidden="true">&#8599;</span></a>
      <a class="nav__link" data-section="about" href="${prefix}about.html">About<span class="nav__arrow" aria-hidden="true">&#8599;</span></a>
      <a class="nav__link" data-section="contact" href="${prefix}contact.html">Contact<span class="nav__arrow" aria-hidden="true">&#8599;</span></a>
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
    <p>&copy; 2026 Will Holman</p>
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
#  work.html - the piles
# =============================================================================
$pileBlocks = @()
foreach ($p in $Projects) {
  $map = Get-ProjectImages $p.slug

  # target always last so it sits on top of the stack
  $order = @($p.pile | Where-Object { $_ -ne $p.target }) + @($p.target)

  $cards = @()
  foreach ($s in $order) {
    if (-not $map.ContainsKey($s)) { Write-Warning "  missing pile image: $($p.slug)/$s"; continue }
    $isTarget = ($s -eq $p.target)
    $attr = if ($isTarget) { ' data-target' } else { '' }
    $src = "assets/img/$($p.slug)/$($map[$s].sm)"
    $cards += "        <img class=`"pile__card`"$attr src=`"$src`" alt=`"`" aria-hidden=`"true`" loading=`"lazy`" decoding=`"async`">"
  }

  $maskSrc = "assets/img/$($p.slug)/$($map[$p.target].sm)"
  $label = HtmlEnc $p.title
  $aria = HtmlEnc "$($p.title) - view project"
  $cardsHtml = ($cards -join "`n")

  $pileBlocks += @"
      <a class="pile" data-pile href="work/$($p.slug).html" aria-label="$aria">
        <div class="pile__stage" data-pile-stage>
$cardsHtml
          <div class="pile__shape" data-pile-shape style="-webkit-mask-image:url('$maskSrc');mask-image:url('$maskSrc')"></div>
          <span class="pile__label" data-pile-label>$label</span>
        </div>
      </a>
"@
}

$workHtml = @"
<!DOCTYPE html>
<html lang="en" data-theme="dark">
<head>
$(Get-Head '' 'Work - Will Holman' 'Selected poster, merch, social and campaign design by Will Holman.')
</head>
<body class="no-js">

<a class="skip-link" href="#main">Skip to content</a>

$(Get-Header '')

<main class="main" id="main">
  <div class="shell">

    <div class="page-head">
      <p class="page-head__label">Work</p>
      <h1 class="page-head__title">Selected<br>projects</h1>
      <p class="page-head__sub">Hover a stack to bring it together. Click to open the project.</p>
    </div>

    <div class="piles">
$($pileBlocks -join "`n")
    </div>

  </div>

$(Get-Footer)
</main>

<script src="assets/vendor/gsap.min.js"></script>
<script src="assets/js/site.js"></script>
<script src="assets/js/pile.js"></script>
</body>
</html>
"@

Write-Utf8 (Join-Path $Root 'work.html') $workHtml
Write-Output "wrote work.html ($($Projects.Count) piles)"

# =============================================================================
#  work/<project>.html
# =============================================================================
$workDir = Join-Path $Root 'work'
New-Item -ItemType Directory -Force -Path $workDir | Out-Null

for ($i = 0; $i -lt $Projects.Count; $i++) {
  $p = $Projects[$i]
  $map = Get-ProjectImages $p.slug

  # pile picks lead, then everything else alphabetically
  $lead = @($p.pile | Where-Object { $map.ContainsKey($_) })
  $rest = @($map.Keys | Where-Object { $lead -notcontains $_ } | Sort-Object)
  $all = $lead + $rest

  $items = @()
  for ($k = 0; $k -lt $all.Count; $k++) {
    $s = $all[$k]
    $span = $SpanPattern[$k % $SpanPattern.Count]
    $src = "../assets/img/$($p.slug)/$($map[$s].lg)"
    $alt = HtmlEnc ("{0} - {1}" -f $p.title, ($s -replace '-', ' '))
    $items += @"
        <figure class="grid__item" data-span="$span">
          <img src="$src" alt="$alt" loading="lazy" decoding="async">
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
$(Get-Head '../' "$($p.title) - Will Holman" $p.desc)
</head>
<body class="no-js">

<a class="skip-link" href="#main">Skip to content</a>

$(Get-Header '../')

<main class="main" id="main">
  <div class="shell">

    <div class="page-head">
      <p class="page-head__label"><a href="../work.html">Work</a> / $num</p>
      <h1 class="page-head__title">$(HtmlEnc $p.title)</h1>
$clientHtml      <p class="page-head__sub">$(HtmlEnc $p.desc)</p>
    </div>

    <div class="$gridClass">
$($items -join "`n")
    </div>

    <nav class="project-nav" aria-label="Projects">
      <div class="project-nav__prev">
        <p class="project-nav__label">Previous</p>
        <a class="project-nav__link" href="$($prev.slug).html">$(HtmlEnc $prev.title)</a>
      </div>
      <div>
        <p class="project-nav__label">Next</p>
        <a class="project-nav__link" href="$($next.slug).html">$(HtmlEnc $next.title)</a>
      </div>
    </nav>

  </div>

$(Get-Footer)
</main>

<script src="../assets/vendor/gsap.min.js"></script>
<script src="../assets/js/site.js"></script>
</body>
</html>
"@

  Write-Utf8 (Join-Path $workDir "$($p.slug).html") $page
  Write-Output "wrote work/$($p.slug).html ($($all.Count) images)"
}

# =============================================================================
#  assets/js/data.js  - intro payload
# =============================================================================
$IntroPicks = @(
  'tour-posters/samurai-tour', 'sports-posters/ufc-329-concept', 'merch-designs/design-for-kamaara-villains',
  'social-media/illumis-2', 'usc-esports/necc-champions-for-usc-esports', 'promotional-material/honda-3',
  'tour-posters/yeat-tour', 'sports-posters/ufc-300-concept', 'merch-designs/design-for-zillakami',
  'social-media/rcm-3', 'usc-esports/season-start-usc-esports', 'promotional-material/honda-1',
  'tour-posters/zillakami-tour', 'sports-posters/ufc-320-concept', 'merch-designs/design-for-klean-up-krew-racing',
  'social-media/seabrook-1', 'usc-esports/playoffs-gameday-graphic-for-usc-gamecok-esports-smash-bros',
  'promotional-material/engage', 'tour-posters/takanaka-tour', 'sports-posters/ufc-mexico-concept',
  'merch-designs/official-design-for-zumiez-dog-years', 'social-media/tdg-1', 'tour-posters/joji-tour'
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
Write-Output 'done.'
