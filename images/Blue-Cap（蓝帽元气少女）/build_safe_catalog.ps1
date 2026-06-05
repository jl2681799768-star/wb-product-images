Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'

$Root = if ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    (Get-Location).Path
}
$OutDir = Join-Path $Root 'TPE-DOLL-100CM-14KG-SOFT-SKELETON'
$Photo2 = Join-Path $Root '主图\2.jpg'
$Photo4 = Join-Path $Root '主图\4.jpg'
$Photo5 = Join-Path $Root '主图\5.jpg'

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function Color([string]$hex, [int]$alpha = 255) {
    $hex = $hex.TrimStart('#')
    return [System.Drawing.Color]::FromArgb(
        $alpha,
        [Convert]::ToInt32($hex.Substring(0, 2), 16),
        [Convert]::ToInt32($hex.Substring(2, 2), 16),
        [Convert]::ToInt32($hex.Substring(4, 2), 16)
    )
}

function Font([single]$size, [System.Drawing.FontStyle]$style = [System.Drawing.FontStyle]::Regular) {
    return [System.Drawing.Font]::new('Segoe UI', $size, $style, [System.Drawing.GraphicsUnit]::Pixel)
}

function Rect([single]$x, [single]$y, [single]$w, [single]$h) {
    return [System.Drawing.RectangleF]::new($x, $y, $w, $h)
}

function RoundPath([single]$x, [single]$y, [single]$w, [single]$h, [single]$r) {
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $d = $r * 2
    $path.AddArc($x, $y, $d, $d, 180, 90)
    $path.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $path.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $path.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    return $path
}

function Fill-RoundRect($g, $brush, [single]$x, [single]$y, [single]$w, [single]$h, [single]$r) {
    $path = RoundPath $x $y $w $h $r
    try { $g.FillPath($brush, $path) } finally { $path.Dispose() }
}

function Stroke-RoundRect($g, $pen, [single]$x, [single]$y, [single]$w, [single]$h, [single]$r) {
    $path = RoundPath $x $y $w $h $r
    try { $g.DrawPath($pen, $path) } finally { $path.Dispose() }
}

function Fill-Gradient($g, [string]$from, [string]$to) {
    $brush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
        (Rect 0 0 1400 1800),
        (Color $from),
        (Color $to),
        90
    )
    try { $g.FillRectangle($brush, 0, 0, 1400, 1800) } finally { $brush.Dispose() }
}

function Draw-Blob($g, [string]$hex, [int]$alpha, [single]$x, [single]$y, [single]$w, [single]$h) {
    $brush = [System.Drawing.SolidBrush]::new((Color $hex $alpha))
    try { $g.FillEllipse($brush, $x, $y, $w, $h) } finally { $brush.Dispose() }
}

function Draw-Text($g, [string]$text, $font, [string]$hex, [System.Drawing.RectangleF]$box,
    [System.Drawing.StringAlignment]$align = [System.Drawing.StringAlignment]::Near) {
    $brush = [System.Drawing.SolidBrush]::new((Color $hex))
    $format = [System.Drawing.StringFormat]::new()
    $format.Alignment = $align
    $format.LineAlignment = [System.Drawing.StringAlignment]::Near
    $format.Trimming = [System.Drawing.StringTrimming]::Word
    try { $g.DrawString($text, $font, $brush, $box, $format) } finally {
        $brush.Dispose()
        $format.Dispose()
    }
}

function Draw-Photo($g, [string]$path, [System.Drawing.RectangleF]$dest, [single]$radius = 36,
    [System.Drawing.RectangleF]$src = [System.Drawing.RectangleF]::Empty) {
    $image = [System.Drawing.Image]::FromFile($path)
    $state = $g.Save()
    $clip = RoundPath $dest.X $dest.Y $dest.Width $dest.Height $radius
    $border = [System.Drawing.Pen]::new((Color 'FFFFFF' 215), 5)
    try {
        $g.SetClip($clip)
        if ($src.IsEmpty) {
            $g.DrawImage($image, $dest)
        } else {
            $g.DrawImage($image, $dest, $src, [System.Drawing.GraphicsUnit]::Pixel)
        }
    } finally {
        $g.Restore($state)
        $clip.Dispose()
        $image.Dispose()
    }
    try { Stroke-RoundRect $g $border $dest.X $dest.Y $dest.Width $dest.Height $radius } finally { $border.Dispose() }
}

function Draw-Card($g, [single]$x, [single]$y, [single]$w, [single]$h, [string]$fill = 'FFFFFF',
    [int]$alpha = 220, [single]$radius = 34) {
    $shadow = [System.Drawing.SolidBrush]::new((Color '537A88' 24))
    $brush = [System.Drawing.SolidBrush]::new((Color $fill $alpha))
    try {
        Fill-RoundRect $g $shadow ($x + 8) ($y + 12) $w $h $radius
        Fill-RoundRect $g $brush $x $y $w $h $radius
    } finally {
        $shadow.Dispose()
        $brush.Dispose()
    }
}

function Draw-Chip($g, [string]$text, [single]$x, [single]$y, [single]$w, [string]$fill = 'EAF6F8',
    [string]$textColor = '355E67') {
    $brush = [System.Drawing.SolidBrush]::new((Color $fill 240))
    $f = Font 27 ([System.Drawing.FontStyle]::Bold)
    try {
        Fill-RoundRect $g $brush $x $y $w 62 31
        Draw-Text $g $text $f $textColor (Rect ($x + 20) ($y + 12) ($w - 40) 42)
    } finally {
        $brush.Dispose()
        $f.Dispose()
    }
}

function Draw-Rule($g, [single]$x, [single]$y, [single]$h, [string]$hex = '66A5AF') {
    $pen = [System.Drawing.Pen]::new((Color $hex), 5)
    try {
        $g.DrawLine($pen, $x, $y, $x, $y + $h)
        $g.DrawLine($pen, $x - 24, $y, $x + 24, $y)
        $g.DrawLine($pen, $x - 24, $y + $h, $x + 24, $y + $h)
    } finally { $pen.Dispose() }
}

function Draw-Icon($g, [string]$kind, [single]$x, [single]$y, [string]$hex = '5C8790') {
    $pen = [System.Drawing.Pen]::new((Color $hex), 5)
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    try {
        switch ($kind) {
            'drop' {
                $g.DrawEllipse($pen, $x + 16, $y + 28, 34, 38)
                $g.DrawLine($pen, $x + 33, $y + 2, $x + 18, $y + 34)
                $g.DrawLine($pen, $x + 33, $y + 2, $x + 49, $y + 34)
            }
            'hair' {
                $g.DrawEllipse($pen, $x + 12, $y + 10, 46, 46)
                $g.DrawArc($pen, $x + 6, $y + 22, 58, 58, 205, 130)
                $g.DrawLine($pen, $x + 18, $y + 50, $x + 10, $y + 72)
                $g.DrawLine($pen, $x + 52, $y + 50, $x + 60, $y + 72)
            }
            'shield' {
                $g.DrawPolygon($pen, @(
                    [System.Drawing.PointF]::new($x + 35, $y + 5),
                    [System.Drawing.PointF]::new($x + 62, $y + 16),
                    [System.Drawing.PointF]::new($x + 56, $y + 53),
                    [System.Drawing.PointF]::new($x + 35, $y + 72),
                    [System.Drawing.PointF]::new($x + 14, $y + 53),
                    [System.Drawing.PointF]::new($x + 8, $y + 16)
                ))
                $g.DrawLine($pen, $x + 24, $y + 38, $x + 32, $y + 46)
                $g.DrawLine($pen, $x + 32, $y + 46, $x + 49, $y + 28)
            }
            'box' {
                $g.DrawRectangle($pen, $x + 8, $y + 20, 56, 48)
                $g.DrawLine($pen, $x + 8, $y + 20, $x + 35, $y + 6)
                $g.DrawLine($pen, $x + 64, $y + 20, $x + 35, $y + 6)
                $g.DrawLine($pen, $x + 35, $y + 6, $x + 35, $y + 54)
            }
            'sun' {
                $g.DrawEllipse($pen, $x + 20, $y + 20, 34, 34)
                foreach ($a in 0,45,90,135,180,225,270,315) {
                    $r = $a * [Math]::PI / 180
                    $x1 = $x + 37 + [Math]::Cos($r) * 26
                    $y1 = $y + 37 + [Math]::Sin($r) * 26
                    $x2 = $x + 37 + [Math]::Cos($r) * 35
                    $y2 = $y + 37 + [Math]::Sin($r) * 35
                    $g.DrawLine($pen, $x1, $y1, $x2, $y2)
                }
            }
            default {
                $g.DrawEllipse($pen, $x + 8, $y + 8, 56, 56)
                $g.DrawLine($pen, $x + 22, $y + 36, $x + 33, $y + 47)
                $g.DrawLine($pen, $x + 33, $y + 47, $x + 52, $y + 25)
            }
        }
    } finally { $pen.Dispose() }
}

function Draw-Footer($g, [string]$index) {
    $small = Font 23 ([System.Drawing.FontStyle]::Bold)
    $line = [System.Drawing.Pen]::new((Color '6A939B' 125), 2)
    try {
        $g.DrawLine($line, 90, 1725, 1310, 1725)
        Draw-Text $g 'TPE-КУКЛА  /  100 СМ  /  14 КГ' $small '52747B' (Rect 92 1740 900 42)
        Draw-Text $g $index $small '52747B' (Rect 1120 1740 190 42) ([System.Drawing.StringAlignment]::Far)
    } finally {
        $small.Dispose()
        $line.Dispose()
    }
}

function New-Page([string]$file, [scriptblock]$render) {
    $bitmap = [System.Drawing.Bitmap]::new(1400, 1800)
    $g = [System.Drawing.Graphics]::FromImage($bitmap)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    try {
        & $render $g
        $target = Join-Path $OutDir $file
        $bitmap.Save($target, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $g.Dispose()
        $bitmap.Dispose()
    }
}

New-Page '01-HERO.png' {
    param($g)
    Fill-Gradient $g 'F9F1E9' 'DCEFF3'
    Draw-Blob $g 'A7D9E2' 75 760 120 760 760
    Draw-Blob $g 'FFD6DF' 70 -160 1240 620 620
    Draw-Card $g 560 235 730 1390 'FFFFFF' 115 54
    Draw-Photo $g $Photo5 (Rect 605 285 640 1290) 42 (Rect 95 0 610 800)
    $title = Font 85 ([System.Drawing.FontStyle]::Bold)
    $sub = Font 32
    $meta = Font 42 ([System.Drawing.FontStyle]::Bold)
    try {
        Draw-Text $g "РЕАЛИСТИЧНАЯ`nTPE-КУКЛА" $title '315F68' (Rect 95 170 760 260)
        Draw-Text $g "TPE ГОЛОВА С ПАРИКОМ`nTPE ТЕЛО`nМЯГКИЙ КАРКАС" $sub '4C6C72' (Rect 100 500 450 200)
        Draw-Card $g 95 800 370 205 'FFFFFF' 218 36
        Draw-Text $g '100 СМ' $meta '315F68' (Rect 135 840 300 60)
        Draw-Text $g '14 КГ' $meta '315F68' (Rect 135 915 300 60)
        Draw-Chip $g 'КОМПАКТНЫЙ РАЗМЕР' 95 1080 400
        Draw-Chip $g 'УДОБНО ХРАНИТЬ' 95 1160 345 'F9E5E8' '795B63'
    } finally {
        $title.Dispose()
        $sub.Dispose()
        $meta.Dispose()
    }
    Draw-Footer $g '01 / 08'
}

New-Page '02-FULL-BODY.png' {
    param($g)
    Fill-Gradient $g 'E8F3F5' 'FBF3EA'
    Draw-Blob $g 'B9E1E6' 90 -120 1180 600 600
    Draw-Card $g 105 260 720 1330 'FFFFFF' 150 52
    Draw-Photo $g $Photo5 (Rect 150 310 630 1230) 44 (Rect 95 0 610 800)
    Draw-Rule $g 930 370 1050
    $title = Font 62 ([System.Drawing.FontStyle]::Bold)
    $big = Font 85 ([System.Drawing.FontStyle]::Bold)
    $body = Font 34
    try {
        Draw-Text $g "КОМПАКТНЫЙ`nРАЗМЕР" $title '315F68' (Rect 875 175 500 180)
        Draw-Text $g '100 СМ' $big '315F68' (Rect 985 775 380 110)
        Draw-Card $g 890 1030 410 280 'FFFFFF' 225 36
        Draw-Text $g "РОСТ  100 СМ`nВЕС  14 КГ" (Font 39 ([System.Drawing.FontStyle]::Bold)) '315F68' (Rect 940 1085 330 140)
        Draw-Text $g "ЛЕГЧЕ ПЕРЕМЕЩАТЬ`nИ ХРАНИТЬ" $body '52747B' (Rect 895 1370 410 110)
    } finally {
        $title.Dispose()
        $big.Dispose()
        $body.Dispose()
    }
    Draw-Footer $g '02 / 08'
}

New-Page '03-FACE-DETAIL.png' {
    param($g)
    Fill-Gradient $g 'FBEDF0' 'E9F4F6'
    Draw-Blob $g 'F3BDCC' 82 780 -130 700 700
    Draw-Card $g 80 340 900 1160 'FFFFFF' 130 56
    Draw-Photo $g $Photo4 (Rect 125 385 810 1070) 45 (Rect 70 0 660 620)
    Draw-Card $g 720 160 600 390 'FFFFFF' 235 42
    $title = Font 36 ([System.Drawing.FontStyle]::Bold)
    $body = Font 31
    try {
        Draw-Text $g "ДЕТАЛИЗИРОВАННОЕ`nЛИЦО" $title '315F68' (Rect 770 220 500 135)
        Draw-Text $g "TPE ГОЛОВА`nПАРИК`nАККУРАТНЫЙ ОБРАЗ" $body '52747B' (Rect 770 380 480 140)
        Draw-Chip $g 'МЯГКАЯ ТЕКСТУРА' 905 650 370
        Draw-Chip $g 'ЕДИНЫЙ ОБРАЗ' 945 735 310 'F9E5E8' '795B63'
    } finally {
        $title.Dispose()
        $body.Dispose()
    }
    Draw-Footer $g '03 / 08'
}

New-Page '04-TPE-MATERIAL.png' {
    param($g)
    Fill-Gradient $g 'F8F1E8' 'E4F1F3'
    Draw-Blob $g 'B6DEE3' 85 -170 950 650 650
    Draw-Card $g 90 310 710 1210 'FFFFFF' 138 50
    Draw-Photo $g $Photo2 (Rect 135 355 620 1120) 42 (Rect 95 0 610 800)
    Draw-Card $g 850 510 410 410 'FFFFFF' 185 205
    Draw-Photo $g $Photo5 (Rect 875 535 360 360) 180 (Rect 300 610 140 180)
    Draw-Card $g 890 1030 330 330 'FFFFFF' 185 165
    Draw-Photo $g $Photo2 (Rect 915 1055 280 280) 140 (Rect 495 250 190 190)
    $title = Font 70 ([System.Drawing.FontStyle]::Bold)
    $body = Font 34
    try {
        Draw-Text $g "МЯГКИЙ`nTPE-МАТЕРИАЛ" $title '315F68' (Rect 90 150 920 175)
        Draw-Text $g "TPE ТЕЛО`nЕСТЕСТВЕННАЯ ТЕКСТУРА" $body '52747B' (Rect 845 380 480 110)
        Draw-Chip $g 'МЯГКАЯ ТЕКСТУРА' 855 1450 390
    } finally {
        $title.Dispose()
        $body.Dispose()
    }
    Draw-Footer $g '04 / 08'
}

New-Page '05-SOFT-SKELETON.png' {
    param($g)
    Fill-Gradient $g 'E7F2F4' 'F9EEE7'
    Draw-Blob $g 'A8D9DF' 80 930 90 620 620
    $title = Font 67 ([System.Drawing.FontStyle]::Bold)
    $body = Font 31
    try {
        Draw-Text $g "МЯГКИЙ КАРКАС`nДЛЯ ПОЗ" $title '315F68' (Rect 95 145 860 165)
        Draw-Text $g 'ФИКСАЦИЯ ПОЗЫ  /  СИДЯ  /  СТОЯ' $body '52747B' (Rect 100 315 950 60)
    } finally {
        $title.Dispose()
        $body.Dispose()
    }
    Draw-Card $g 85 430 570 915 'FFFFFF' 150 48
    Draw-Photo $g $Photo2 (Rect 130 475 480 825) 40 (Rect 105 0 590 800)
    Draw-Card $g 745 430 570 915 'FFFFFF' 150 48
    Draw-Photo $g $Photo5 (Rect 790 475 480 825) 40 (Rect 125 0 550 800)
    Draw-Card $g 250 1420 900 175 'FFFFFF' 225 40
    Draw-Chip $g 'ЕСТЕСТВЕННЫЕ ДВИЖЕНИЯ' 340 1474 720
    Draw-Footer $g '05 / 08'
}

New-Page '06-PACKAGING.png' {
    param($g)
    Fill-Gradient $g 'FBF2E9' 'E6F2F3'
    Draw-Blob $g 'F0C9CF' 70 880 -180 700 700
    $title = Font 67 ([System.Drawing.FontStyle]::Bold)
    $big = Font 62 ([System.Drawing.FontStyle]::Bold)
    $body = Font 34
    try {
        Draw-Text $g 'УПАКОВКА' $title '315F68' (Rect 95 145 700 90)
        Draw-Text $g '93 X 29 X 27 СМ' $big '315F68' (Rect 95 245 750 95)
        Draw-Text $g "РАЗМЕР КОРОБКИ`n93 X 29 X 27 СМ`n`nВЕС ИЗДЕЛИЯ`n14 КГ" $body '52747B' (Rect 105 1080 480 310)
        Draw-Text $g 'УДОБНО ХРАНИТЬ ДОМА' $body '52747B' (Rect 100 1480 700 55)
    } finally {
        $title.Dispose()
        $big.Dispose()
        $body.Dispose()
    }
    Draw-Card $g 95 430 740 560 'FFFFFF' 218 42
    $pen = [System.Drawing.Pen]::new((Color '5C8790'), 8)
    try {
        $g.DrawRectangle($pen, 220, 620, 430, 235)
        $g.DrawLine($pen, 220, 620, 390, 515)
        $g.DrawLine($pen, 650, 620, 790, 525)
        $g.DrawLine($pen, 390, 515, 790, 525)
        $g.DrawLine($pen, 650, 855, 790, 750)
        $g.DrawLine($pen, 790, 525, 790, 750)
        $g.DrawLine($pen, 390, 515, 390, 620)
    } finally { $pen.Dispose() }
    $dim = Font 30 ([System.Drawing.FontStyle]::Bold)
    try {
        Draw-Text $g '93 СМ' $dim '315F68' (Rect 360 875 190 45)
        Draw-Text $g '29 СМ' $dim '315F68' (Rect 685 780 150 45)
        Draw-Text $g '27 СМ' $dim '315F68' (Rect 560 535 150 45)
    } finally { $dim.Dispose() }
    Draw-Card $g 900 520 370 940 'FFFFFF' 150 44
    Draw-Photo $g $Photo5 (Rect 940 570 290 840) 38 (Rect 170 0 460 800)
    Draw-Footer $g '06 / 08'
}

function Draw-InfoCard($g, [single]$x, [single]$y, [single]$w, [single]$h, [string]$icon,
    [string]$heading, [string]$body, [string]$accent = '5C8790') {
    Draw-Card $g $x $y $w $h 'FFFFFF' 225 36
    Draw-Icon $g $icon ($x + 30) ($y + 30) $accent
    $head = Font 28 ([System.Drawing.FontStyle]::Bold)
    $copy = Font 24
    try {
        Draw-Text $g $heading $head '315F68' (Rect ($x + 125) ($y + 34) ($w - 155) 74)
        Draw-Text $g $body $copy '52747B' (Rect ($x + 35) ($y + 128) ($w - 70) ($h - 155))
    } finally {
        $head.Dispose()
        $copy.Dispose()
    }
}

New-Page '07-CARE-GUIDE.png' {
    param($g)
    Fill-Gradient $g 'FAF1E7' 'EDF4F3'
    Draw-Blob $g 'B8DEE3' 75 935 -150 650 650
    Draw-Card $g 990 100 300 390 'FFFFFF' 145 42
    Draw-Photo $g $Photo4 (Rect 1020 130 240 330) 32 (Rect 190 0 420 560)
    $title = Font 61 ([System.Drawing.FontStyle]::Bold)
    $sub = Font 29
    try {
        Draw-Text $g "ПОЛНЫЙ УХОД`nЗА TPE-КУКЛОЙ" $title '315F68' (Rect 92 140 840 155)
        Draw-Text $g 'TPE МАТЕРИАЛ  /  ГОЛОВА С ПАРИКОМ  /  МЯГКИЙ КАРКАС' $sub '52747B' (Rect 98 315 840 85)
    } finally {
        $title.Dispose()
        $sub.Dispose()
    }
    Draw-InfoCard $g 90 555 585 405 'drop' 'ЕЖЕДНЕВНАЯ ОЧИСТКА' "ТЁПЛАЯ ВОДА 30-40 °C`nМЯГКОЕ СРЕДСТВО`nПОСЛЕ СУШКИ НАНЕСТИ`nПУДРУ ДЛЯ TPE"
    Draw-InfoCard $g 725 555 585 405 'hair' 'УХОД ЗА ГОЛОВОЙ И ПАРИКОМ' "ПАРИК СНИМАТЬ АККУРАТНО`nМЫТЬ ОТДЕЛЬНО`nГОЛОВУ ПРОТИРАТЬ`nВЛАЖНЫМ ПОЛОТЕНЦЕМ" '8B6D76'
    Draw-InfoCard $g 90 1010 585 405 'shield' 'ВО ВРЕМЯ ИСПОЛЬЗОВАНИЯ' "ТОЛЬКО СРЕДСТВА`nНА ВОДНОЙ ОСНОВЕ`nИЗБЕГАТЬ МАСЛА`nИ СИЛИКОНА"
    Draw-InfoCard $g 725 1010 585 405 'check' 'ГЛАВНЫЕ ПРАВИЛА' "БЕЗ ГРУБОГО ТРЕНИЯ`nБЕРЕЧЬ ОТ ОСТРЫХ ПРЕДМЕТОВ`nВЕРНУТЬ ЕСТЕСТВЕННОЕ`nПОЛОЖЕНИЕ" '8B6D76'
    Draw-Footer $g '07 / 08'
}

New-Page '08-STORAGE-PROTECTION.png' {
    param($g)
    Fill-Gradient $g 'EDF5F5' 'FAF0E7'
    Draw-Blob $g 'F1C9D0' 70 980 1000 520 520
    $title = Font 64 ([System.Drawing.FontStyle]::Bold)
    $sub = Font 31
    try {
        Draw-Text $g "ХРАНЕНИЕ`nИ ЗАЩИТА" $title '315F68' (Rect 95 140 760 160)
        Draw-Text $g 'КАК ПРОДЛИТЬ СРОК СЛУЖБЫ TPE-КУКЛЫ' $sub '52747B' (Rect 100 330 950 55)
    } finally {
        $title.Dispose()
        $sub.Dispose()
    }
    Draw-InfoCard $g 90 505 585 365 'sun' 'УСЛОВИЯ ХРАНЕНИЯ' "ТЕМПЕРАТУРА 10-25 °C`nВЛАЖНОСТЬ 40-60%`nСУХОЕ МЕСТО"
    Draw-InfoCard $g 725 505 585 365 'shield' 'ПРАВИЛЬНОЕ ХРАНЕНИЕ' "ХРАНИТЬ ЛЁЖА`nРОВНАЯ ПОВЕРХНОСТЬ`nНАКРЫВАТЬ ХЛОПКОВОЙ ТКАНЬЮ" '8B6D76'
    Draw-InfoCard $g 90 920 585 365 'check' 'БЫСТРЫЙ УХОД' "ОБНОВЛЯТЬ ПУДРУ`nКАЖДЫЕ 1-2 МЕСЯЦА`nМЯГКО РАЗРАБАТЫВАТЬ СУСТАВЫ"
    Draw-InfoCard $g 725 920 585 365 'box' 'СТРОГО ЗАПРЕЩЕНО' "АЛКОГОЛЬ / БЕНЗИН`nМАСЛА / СИЛИКОН`nСИЛЬНАЯ НАГРУЗКА" '8B6D76'
    Draw-Card $g 930 1335 330 320 'FFFFFF' 150 44
    Draw-Photo $g $Photo5 (Rect 970 1370 250 250) 34 (Rect 155 0 490 500)
    Draw-Chip $g 'УХОД И ХРАНЕНИЕ' 110 1460 410
    Draw-Footer $g '08 / 08'
}

Get-ChildItem -LiteralPath $OutDir -Filter '*.png' |
    Sort-Object Name |
    Select-Object Name, Length
