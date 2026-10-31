$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$bitmap = New-Object Drawing.Bitmap 256,256
$graphics = [Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = 'AntiAlias'
$graphics.Clear([Drawing.Color]::FromArgb(16,17,19))
$metal = New-Object Drawing.Drawing2D.LinearGradientBrush ([Drawing.Point]::new(30,20)),([Drawing.Point]::new(230,240)),([Drawing.Color]::FromArgb(248,249,251)),([Drawing.Color]::FromArgb(108,112,121))
$pen = New-Object Drawing.Pen $metal,13
$pen.StartCap = 'Round'
$pen.EndCap = 'Round'
$graphics.DrawArc($pen,50,54,156,156,-52,284)
$graphics.DrawLine($pen,128,40,128,119)
$small = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(110,218,221,226)),2
$graphics.DrawEllipse($small,28,28,200,200)
$icon = [Drawing.Icon]::FromHandle($bitmap.GetHicon())
$stream = [IO.File]::Create((Join-Path $PSScriptRoot 'rework.ico'))
$icon.Save($stream)
$stream.Dispose()
$icon.Dispose()
$small.Dispose()
$pen.Dispose()
$metal.Dispose()
$graphics.Dispose()
$bitmap.Dispose()
