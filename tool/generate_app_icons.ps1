param(
    [string]$Source = (Join-Path $PSScriptRoot '../assets/branding/app_icon.png')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$sourceImage = [System.Drawing.Image]::FromFile((Resolve-Path -LiteralPath $Source).Path)

function Write-Icon([string]$RelativePath, [int]$Size) {
    $destination = Join-Path $projectRoot $RelativePath
    New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
    $bitmap = [System.Drawing.Bitmap]::new($Size, $Size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.Clear([System.Drawing.Color]::White)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.DrawImage($sourceImage, [System.Drawing.Rectangle]::new(0, 0, $Size, $Size))
        $bitmap.Save($destination, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

try {
    # Se conserva la imagen completa y su margen para las máscaras de Android.
    foreach ($density in @(
        @{ Name = 'mdpi'; Legacy = 48; Adaptive = 108 },
        @{ Name = 'hdpi'; Legacy = 72; Adaptive = 162 },
        @{ Name = 'xhdpi'; Legacy = 96; Adaptive = 216 },
        @{ Name = 'xxhdpi'; Legacy = 144; Adaptive = 324 },
        @{ Name = 'xxxhdpi'; Legacy = 192; Adaptive = 432 }
    )) {
        Write-Icon "android/app/src/main/res/mipmap-$($density.Name)/ic_launcher.png" $density.Legacy
        Write-Icon "android/app/src/main/res/mipmap-$($density.Name)/ic_launcher_foreground.png" $density.Adaptive
    }
    Write-Icon 'web/icons/icon-192.png' 192
    Write-Icon 'web/icons/icon-512.png' 512
    Write-Icon 'web/icons/apple-touch-icon.png' 180
    Write-Icon 'web/favicon.png' 32
}
finally {
    $sourceImage.Dispose()
}

Write-Output 'Iconos de Android y web generados desde assets/branding/app_icon.png.'
