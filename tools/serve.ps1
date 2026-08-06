# =============================================================================
#  serve.ps1 - tiny local preview server (no dependencies)
#
#      powershell -ExecutionPolicy Bypass -File tools\serve.ps1
#      then open http://localhost:8123
#
#  Ctrl+C to stop.
# =============================================================================

param([int]$Port = 8123)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot

$types = @{
  '.html' = 'text/html; charset=utf-8'
  '.css'  = 'text/css; charset=utf-8'
  '.js'   = 'text/javascript; charset=utf-8'
  '.json' = 'application/json; charset=utf-8'
  '.jpg'  = 'image/jpeg'
  '.jpeg' = 'image/jpeg'
  '.png'  = 'image/png'
  '.gif'  = 'image/gif'
  '.svg'  = 'image/svg+xml'
  '.ico'  = 'image/x-icon'
  '.webp' = 'image/webp'
  '.txt'  = 'text/plain; charset=utf-8'
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Output "serving $Root on http://localhost:$Port  (Ctrl+C to stop)"

try {
  while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $req = $ctx.Request
    $res = $ctx.Response

    try {
      $rel = [Uri]::UnescapeDataString($req.Url.AbsolutePath).TrimStart('/')
      if ([string]::IsNullOrWhiteSpace($rel)) { $rel = 'index.html' }

      $path = Join-Path $Root ($rel -replace '/', '\')
      if (Test-Path $path -PathType Container) { $path = Join-Path $path 'index.html' }

      # Match GitHub Pages: /about serves about.html, so extensionless links
      # behave the same locally as they do live.
      if (-not (Test-Path $path -PathType Leaf) -and -not [IO.Path]::GetExtension($path)) {
        if (Test-Path "$path.html" -PathType Leaf) { $path = "$path.html" }
      }

      # keep requests inside the site folder
      $full = [IO.Path]::GetFullPath($path)
      if (-not $full.StartsWith([IO.Path]::GetFullPath($Root), [StringComparison]::OrdinalIgnoreCase)) {
        $res.StatusCode = 403; $res.Close(); continue
      }

      if (Test-Path $full -PathType Leaf) {
        $ext = [IO.Path]::GetExtension($full).ToLower()
        $res.ContentType = if ($types.ContainsKey($ext)) { $types[$ext] } else { 'application/octet-stream' }
        $res.Headers.Add('Cache-Control', 'no-cache')
        $bytes = [IO.File]::ReadAllBytes($full)
        $res.ContentLength64 = $bytes.Length
        $res.OutputStream.Write($bytes, 0, $bytes.Length)
        Write-Output ("200  " + $rel)
      }
      else {
        $res.StatusCode = 404
        $msg = [Text.Encoding]::UTF8.GetBytes('404 - not found')
        $res.ContentType = 'text/plain; charset=utf-8'
        $res.OutputStream.Write($msg, 0, $msg.Length)
        Write-Output ("404  " + $rel)
      }
    }
    catch {
      $res.StatusCode = 500
      Write-Output ("500  " + $_.Exception.Message)
    }
    finally { $res.Close() }
  }
}
finally {
  $listener.Stop()
  $listener.Close()
}
