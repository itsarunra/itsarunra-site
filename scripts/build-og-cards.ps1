$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Web

$Root = Split-Path -Parent $PSScriptRoot
$Domain = 'https://itsarunra.com'
$SiteName = 'itsarunra.com'
$Author = 'Arun R. Arunothayan'
$OutputDir = Join-Path $Root 'assets\og'
$PostsDir = Join-Path $Root 'posts'
$ProfilePath = Join-Path $Root 'profile.jpg'

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

function ConvertTo-PlainText {
  param([string]$Html)

  $text = [regex]::Replace($Html, '<script[\s\S]*?</script>', '', 'IgnoreCase')
  $text = [regex]::Replace($text, '<style[\s\S]*?</style>', '', 'IgnoreCase')
  $text = [regex]::Replace($text, '<[^>]+>', ' ')
  $text = [System.Web.HttpUtility]::HtmlDecode($text)
  $text = [regex]::Replace($text, '\s*\[\d+\]', '')
  $text = [regex]::Replace($text, '\s+', ' ').Trim()
  return $text
}

function ConvertTo-AttributeValue {
  param([string]$Text)

  return [System.Web.HttpUtility]::HtmlAttributeEncode($Text)
}

function New-SolidBrush {
  param([string]$Hex)

  return New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($Hex))
}

function New-RoundedPath {
  param(
    [float]$X,
    [float]$Y,
    [float]$Width,
    [float]$Height,
    [float]$Radius
  )

  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $diameter = $Radius * 2
  $path.AddArc($X, $Y, $diameter, $diameter, 180, 90)
  $path.AddArc($X + $Width - $diameter, $Y, $diameter, $diameter, 270, 90)
  $path.AddArc($X + $Width - $diameter, $Y + $Height - $diameter, $diameter, $diameter, 0, 90)
  $path.AddArc($X, $Y + $Height - $diameter, $diameter, $diameter, 90, 90)
  $path.CloseFigure()
  return $path
}

function Get-WrappedLines {
  param(
    [System.Drawing.Graphics]$Graphics,
    [string]$Text,
    [System.Drawing.Font]$Font,
    [float]$MaxWidth,
    [int]$MaxLines
  )

  $lines = New-Object System.Collections.Generic.List[string]
  $words = $Text -split ' '
  $line = ''
  $truncated = $false

  foreach ($word in $words) {
    $candidate = if ($line.Length -eq 0) { $word } else { "$line $word" }
    if ($Graphics.MeasureString($candidate, $Font).Width -le $MaxWidth -or $line.Length -eq 0) {
      $line = $candidate
    } else {
      $lines.Add($line)
      if ($lines.Count -ge $MaxLines) {
        $truncated = $true
        break
      }
      $line = $word
    }
  }

  if (-not $truncated -and $lines.Count -lt $MaxLines -and $line.Length -gt 0) {
    $lines.Add($line)
  }

  if ($truncated -and $lines.Count -eq $MaxLines) {
    $lastIndex = $lines.Count - 1
    while ($Graphics.MeasureString($lines[$lastIndex] + '...', $Font).Width -gt $MaxWidth -and $lines[$lastIndex].Length -gt 0) {
      $lines[$lastIndex] = $lines[$lastIndex].Substring(0, $lines[$lastIndex].Length - 1).TrimEnd()
    }
    if (-not $lines[$lastIndex].EndsWith('...')) {
      $lines[$lastIndex] = $lines[$lastIndex].TrimEnd('.') + '...'
    }
  }

  return $lines
}

function Draw-WrappedText {
  param(
    [System.Drawing.Graphics]$Graphics,
    [string]$Text,
    [System.Drawing.Font]$Font,
    [System.Drawing.Brush]$Brush,
    [float]$X,
    [float]$Y,
    [float]$MaxWidth,
    [float]$LineHeight,
    [int]$MaxLines
  )

  $lines = Get-WrappedLines -Graphics $Graphics -Text $Text -Font $Font -MaxWidth $MaxWidth -MaxLines $MaxLines
  foreach ($line in $lines) {
    $Graphics.DrawString($line, $Font, $Brush, $X, $Y)
    $Y += $LineHeight
  }
}

function Draw-CircularImage {
  param(
    [System.Drawing.Graphics]$Graphics,
    [string]$ImagePath,
    [float]$X,
    [float]$Y,
    [float]$Size
  )

  $image = [System.Drawing.Image]::FromFile($ImagePath)
  $diameter = [int]$Size
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.AddEllipse($X, $Y, $Size, $Size)

  $previousClip = $Graphics.Clip
  $Graphics.SetClip($path)

  $sourceSize = [Math]::Min($image.Width, $image.Height)
  $sourceX = ($image.Width - $sourceSize) / 2
  $sourceY = ($image.Height - $sourceSize) / 2
  $destRect = New-Object System.Drawing.Rectangle([int]$X, [int]$Y, [int]$Size, [int]$Size)
  $Graphics.DrawImage($image, $destRect, $sourceX, $sourceY, $sourceSize, $sourceSize, [System.Drawing.GraphicsUnit]::Pixel)

  $Graphics.Clip = $previousClip
  $path.Dispose()
  $image.Dispose()
}

function New-ArticleOgImage {
  param(
    [string]$Title,
    [string]$Description,
    [string]$Slug,
    [string]$OutputPath
  )

  $width = 1200
  $height = 630
  $bitmap = New-Object System.Drawing.Bitmap $width, $height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
  $graphics.Clear([System.Drawing.Color]::FromArgb(255, 255, 255))

  $cardBrush = New-SolidBrush '#ffffff'
  $textBrush = New-SolidBrush '#24292f'
  $mutedBrush = New-SolidBrush '#57606a'
  $softBrush = New-SolidBrush '#f6f8fa'
  $borderPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(208, 215, 222)), 2
  $photoBorderPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(208, 215, 222)), 3

  $cardPath = New-RoundedPath 60 60 1080 510 32
  $graphics.FillPath($cardBrush, $cardPath)
  $graphics.DrawPath($borderPen, $cardPath)

  $fontFamily = 'Segoe UI'
  $siteFont = New-Object System.Drawing.Font($fontFamily, 28, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
  $titleFont = New-Object System.Drawing.Font($fontFamily, 56, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
  $bodyFont = New-Object System.Drawing.Font($fontFamily, 31, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
  $authorFont = New-Object System.Drawing.Font($fontFamily, 26, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
  $markFont = New-Object System.Drawing.Font('Georgia', 26, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)

  $left = 126
  $textWidth = 695
  $graphics.DrawString($SiteName, $siteFont, $mutedBrush, $left, 136)
  Draw-WrappedText -Graphics $graphics -Text $Title -Font $titleFont -Brush $textBrush -X $left -Y 202 -MaxWidth $textWidth -LineHeight 66 -MaxLines 2
  Draw-WrappedText -Graphics $graphics -Text $Description -Font $bodyFont -Brush $mutedBrush -X $left -Y 340 -MaxWidth $textWidth -LineHeight 45 -MaxLines 3
  $graphics.DrawString($Author, $authorFont, $mutedBrush, $left, 506)

  $photoSize = 220
  $photoX = 876
  $photoY = 196
  $photoBg = New-RoundedPath ($photoX - 14) ($photoY - 14) ($photoSize + 28) ($photoSize + 28) 34
  $graphics.FillPath($softBrush, $photoBg)
  $graphics.DrawPath($borderPen, $photoBg)
  Draw-CircularImage -Graphics $graphics -ImagePath $ProfilePath -X $photoX -Y $photoY -Size $photoSize
  $graphics.DrawEllipse($photoBorderPen, $photoX, $photoY, $photoSize, $photoSize)

  $markPath = New-RoundedPath 994 448 70 70 16
  $graphics.FillPath($softBrush, $markPath)
  $graphics.DrawPath($borderPen, $markPath)
  $format = New-Object System.Drawing.StringFormat
  $format.Alignment = [System.Drawing.StringAlignment]::Center
  $format.LineAlignment = [System.Drawing.StringAlignment]::Center
  $markRect = New-Object System.Drawing.RectangleF 994, 446, 70, 70
  $graphics.DrawString('AR', $markFont, $textBrush, $markRect, $format)

  $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)

  $format.Dispose()
  $markPath.Dispose()
  $photoBg.Dispose()
  $cardPath.Dispose()
  $siteFont.Dispose()
  $titleFont.Dispose()
  $bodyFont.Dispose()
  $authorFont.Dispose()
  $markFont.Dispose()
  $cardBrush.Dispose()
  $textBrush.Dispose()
  $mutedBrush.Dispose()
  $softBrush.Dispose()
  $borderPen.Dispose()
  $photoBorderPen.Dispose()
  $graphics.Dispose()
  $bitmap.Dispose()
}

function Set-ArticleMetaTags {
  param(
    [string]$Html,
    [string]$Title,
    [string]$Description,
    [string]$Slug
  )

  $url = "$Domain/posts/$Slug.html"
  $imageUrl = "$Domain/assets/og/$Slug.png"
  $alt = "Social preview card for $Title by $Author."
  $pageTitle = [System.Web.HttpUtility]::HtmlEncode("$Title | Arun RA")
  $titleAttr = ConvertTo-AttributeValue $Title
  $descriptionAttr = ConvertTo-AttributeValue $Description
  $urlAttr = ConvertTo-AttributeValue $url
  $imageAttr = ConvertTo-AttributeValue $imageUrl
  $altAttr = ConvertTo-AttributeValue $alt

  $block = @"
  <!-- Social sharing metadata generated by scripts/build-og-cards.ps1 -->
  <meta name="description" content="$descriptionAttr">
  <meta property="og:type" content="article">
  <meta property="og:site_name" content="$SiteName">
  <meta property="og:title" content="$titleAttr">
  <meta property="og:description" content="$descriptionAttr">
  <meta property="og:url" content="$urlAttr">
  <meta property="og:image" content="$imageAttr">
  <meta property="og:image:type" content="image/png">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta property="og:image:alt" content="$altAttr">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="$titleAttr">
  <meta name="twitter:description" content="$descriptionAttr">
  <meta name="twitter:image" content="$imageAttr">
  <meta name="twitter:image:alt" content="$altAttr">
  <!-- End social sharing metadata -->
"@

  $pattern = '\s*<!-- Social sharing metadata generated by scripts/build-og-cards\.ps1 -->[\s\S]*?<!-- End social sharing metadata -->'
  $metadataRegex = [regex]::new($pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  $titleRegex = [regex]::new('(<title>[\s\S]*?</title>)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  $html = $metadataRegex.Replace($Html, '')
  $html = $titleRegex.Replace($html, "<title>$pageTitle</title>`r`n$block", 1)
  return $html
}

Get-ChildItem -Path $PostsDir -Filter '*.html' | Sort-Object Name | ForEach-Object {
  $postPath = $_.FullName
  $slug = $_.BaseName
  $html = Get-Content -Raw -Encoding UTF8 $postPath

  $titleMatch = [regex]::Match($html, '<article[\s\S]*?<h1[^>]*>([\s\S]*?)</h1>', 'IgnoreCase')
  if (-not $titleMatch.Success) {
    throw "Could not find article title in $($_.Name)"
  }
  $title = ConvertTo-PlainText $titleMatch.Groups[1].Value

  $articleMatch = [regex]::Match($html, '<article[\s\S]*?</article>', 'IgnoreCase')
  if (-not $articleMatch.Success) {
    throw "Could not find article body in $($_.Name)"
  }
  $paragraphMatches = [regex]::Matches($articleMatch.Value, '<p(?![^>]*class="[^"]*\bmuted\b[^"]*")[^>]*>([\s\S]*?)</p>', 'IgnoreCase')
  if ($paragraphMatches.Count -eq 0) {
    throw "Could not find article excerpt in $($_.Name)"
  }
  $description = ConvertTo-PlainText $paragraphMatches[0].Groups[1].Value

  $outputPath = Join-Path $OutputDir "$slug.png"
  New-ArticleOgImage -Title $title -Description $description -Slug $slug -OutputPath $outputPath

  $updatedHtml = Set-ArticleMetaTags -Html $html -Title $title -Description $description -Slug $slug
  if ($updatedHtml -ne $html) {
    Set-Content -NoNewline -Encoding UTF8 -Path $postPath -Value $updatedHtml
  }

  Write-Output "Generated $outputPath"
}
