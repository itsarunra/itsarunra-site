$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Web

$Root = Split-Path -Parent $PSScriptRoot
$PostsDir = Join-Path $Root 'posts'
$DataDir = Join-Path $Root 'data'
$OutputPath = Join-Path $DataDir 'posts.json'

New-Item -ItemType Directory -Force -Path $DataDir | Out-Null

function ConvertTo-PlainText {
  param([string]$Html)

  $text = [regex]::Replace($Html, '<script[\s\S]*?</script>', '', 'IgnoreCase')
  $text = [regex]::Replace($text, '<style[\s\S]*?</style>', '', 'IgnoreCase')
  $text = [regex]::Replace($text, '<[^>]+>', ' ')
  $text = [System.Web.HttpUtility]::HtmlDecode($text)
  $text = [regex]::Replace($text, '\s+', ' ').Trim()
  return $text
}

function Convert-DateToIso {
  param([string]$DateText)

  $culture = [System.Globalization.CultureInfo]::GetCultureInfo('en-AU')
  $date = [datetime]::ParseExact($DateText, 'd MMMM yyyy', $culture)
  return $date.ToString('yyyy-MM-dd')
}

$posts = Get-ChildItem -Path $PostsDir -Filter '*.html' |
  Where-Object { $_.Name -ne 'index.html' } |
  ForEach-Object {
    $slug = $_.BaseName
    $html = Get-Content -Raw -Encoding UTF8 $_.FullName

    $articleMatch = [regex]::Match($html, '<article[\s\S]*?</article>', 'IgnoreCase')
    if (-not $articleMatch.Success) {
      throw "Could not find article body in $($_.Name)"
    }

    $titleMatch = [regex]::Match($articleMatch.Value, '<h1[^>]*>([\s\S]*?)</h1>', 'IgnoreCase')
    if (-not $titleMatch.Success) {
      throw "Could not find article title in $($_.Name)"
    }

    $dateMatch = [regex]::Match($articleMatch.Value, '<p[^>]*class="[^"]*\bmeta\b[^"]*"[^>]*>([\s\S]*?)</p>', 'IgnoreCase')
    if (-not $dateMatch.Success) {
      throw "Could not find article date in $($_.Name)"
    }

    $dateText = ConvertTo-PlainText $dateMatch.Groups[1].Value
    [pscustomobject][ordered]@{
      slug = $slug
      title = ConvertTo-PlainText $titleMatch.Groups[1].Value
      date = Convert-DateToIso $dateText
      url = "/posts/$slug.html"
    }
  } |
  Sort-Object date -Descending

$json = $posts | ConvertTo-Json -Depth 4
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($OutputPath, ($json + "`n"), $utf8NoBom)
Write-Output "Generated $OutputPath"
