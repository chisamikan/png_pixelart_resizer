# resize_nn.ps1
# 指定した複数フォルダ内のPNG画像を、ニアレストネイバー法で指定倍率に拡大し、
# 1つの出力フォルダにまとめて保存する。
# 同名ファイルが複数フォルダに存在する場合は、末尾に (1), (2) ... を付けて保存する。
# 保存時にEXIF等のメタデータは自動的に削除される。
#
# 使い方:
#   powershell -ExecutionPolicy Bypass -File resize_nn.ps1 -DirList "C:\images1;C:\images2" -OutDir "C:\output" -Scale 2

param(
    [Parameter(Mandatory=$true)][string]$DirList,
    [Parameter(Mandatory=$true)][string]$OutDir,
    [Parameter(Mandatory=$true)][double]$Scale
)

Add-Type -AssemblyName System.Drawing

if ($Scale -le 0) {
    Write-Host "拡大倍率は正の数で指定してください。"
    exit 1
}

# セミコロン区切りのフォルダ一覧を配列に分解（空要素・前後の空白は除去）
$dirs = $DirList -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }

if ($dirs.Count -eq 0) {
    Write-Host "入力元フォルダが指定されていません。"
    exit 1
}

if ($OutDir.Trim() -eq '') {
    Write-Host "出力先フォルダが指定されていません。"
    exit 1
}

# 出力先フォルダを作成（なければ）
if (-not (Test-Path $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir | Out-Null
}

# --- optipng（ロスレスPNG圧縮ツール）の検出 ---
# 1. このスクリプトと同じフォルダにある optipng.exe
# 2. システムのPATHに登録されている optipng.exe
# のいずれかが見つかれば、保存後の追加圧縮に利用する。
$optipngPath = $null
$localOptipng = Join-Path $PSScriptRoot "optipng.exe"
if (Test-Path $localOptipng) {
    $optipngPath = $localOptipng
} else {
    $found = Get-Command "optipng.exe" -ErrorAction SilentlyContinue
    if ($found) {
        $optipngPath = $found.Source
    }
}

if ($optipngPath) {
    Write-Host "optipng が見つかりました ($optipngPath)。"
    Write-Host "保存後に画質を維持したままファイルサイズを圧縮します。"
} else {
    Write-Host "optipng が見つからないため、追加のファイルサイズ圧縮はスキップされます。"
    Write-Host "圧縮を有効にしたい場合は、optipng.exe をダウンロードして"
    Write-Host "このスクリプトと同じフォルダに置いてください。"
    Write-Host "入手先: https://optipng.sourceforge.net/"
}
Write-Host ""

$totalBeforeBytes = 0
$totalAfterBytes  = 0

# 出力先フォルダ内で重複しないファイル名を決定する関数
# 既に同名ファイルが存在する場合は "ファイル名(1).png" のように連番を付ける
function Get-UniqueOutputPath {
    param(
        [string]$OutDir,
        [string]$FileName
    )

    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
    $ext      = [System.IO.Path]::GetExtension($FileName)

    $candidate = Join-Path $OutDir $FileName
    $counter = 1

    while (Test-Path $candidate) {
        $candidate = Join-Path $OutDir ("{0}({1}){2}" -f $baseName, $counter, $ext)
        $counter++
    }

    return $candidate
}

$totalCount = 0

foreach ($dir in $dirs) {

    Write-Host "==================================================="
    Write-Host "入力元フォルダ: $dir"
    Write-Host "==================================================="

    if (-not (Test-Path $dir)) {
        Write-Host "  -> フォルダが見つかりません。スキップします。"
        Write-Host ""
        continue
    }

    $pngFiles = Get-ChildItem -Path $dir -Filter *.png -File

    if ($pngFiles.Count -eq 0) {
        Write-Host "  -> PNG画像が見つかりませんでした。"
        Write-Host ""
        continue
    }

    Write-Host "  対象ファイル数: $($pngFiles.Count)"
    Write-Host "  拡大倍率: x$Scale"
    Write-Host ""

    foreach ($file in $pngFiles) {
        try {
            $srcImage = [System.Drawing.Image]::FromFile($file.FullName)
            $srcWidth  = $srcImage.Width
            $srcHeight = $srcImage.Height

            $newWidth  = [int]([math]::Round($srcWidth  * $Scale))
            $newHeight = [int]([math]::Round($srcHeight * $Scale))

            if ($newWidth -lt 1) { $newWidth = 1 }
            if ($newHeight -lt 1) { $newHeight = 1 }

            $destImage = New-Object System.Drawing.Bitmap $newWidth, $newHeight
            $graphics = [System.Drawing.Graphics]::FromImage($destImage)

            # ニアレストネイバー法（最近傍補間）で拡大
            $graphics.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
            $graphics.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
            $graphics.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::None
            $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighSpeed

            $graphics.DrawImage($srcImage, 0, 0, $newWidth, $newHeight)

            # メタデータ（EXIF、撮影情報、カラープロファイル情報など）を確実に削除
            # 新規Bitmapへの描画のため通常は元のメタデータを引き継がないが、
            # 念のため念入りにプロパティ情報を明示的に削除する
            foreach ($propId in @($destImage.PropertyIdList)) {
                try { $destImage.RemovePropertyItem($propId) } catch {}
            }

            # 出力先フォルダ内で重複しないファイル名を決定
            $outPath = Get-UniqueOutputPath -OutDir $OutDir -FileName $file.Name

            $destImage.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)

            $graphics.Dispose()
            $destImage.Dispose()
            $srcImage.Dispose()

            $sizeBeforeCompress = (Get-Item $outPath).Length

            # optipng が見つかっている場合は、画質・サイズを変えずに
            # ファイルサイズだけをロスレスで圧縮する
            if ($optipngPath) {
                try {
                    & $optipngPath -o4 -quiet "$outPath" 2>$null
                } catch {
                    Write-Host "  警告: optipngによる圧縮に失敗しました - $_"
                }
            }

            $sizeAfterCompress = (Get-Item $outPath).Length
            $totalBeforeBytes += $sizeBeforeCompress
            $totalAfterBytes  += $sizeAfterCompress

            $savedName = [System.IO.Path]::GetFileName($outPath)
            $sizeInfo = "{0:N0}KB" -f ($sizeAfterCompress / 1KB)
            if ($optipngPath -and $sizeBeforeCompress -gt 0) {
                $reducePercent = [math]::Round((1 - ($sizeAfterCompress / $sizeBeforeCompress)) * 100, 1)
                $sizeInfo = "{0:N0}KB -> {1:N0}KB (-{2}%)" -f ($sizeBeforeCompress / 1KB), ($sizeAfterCompress / 1KB), $reducePercent
            }

            Write-Host "  OK: $($file.Name)  (${srcWidth}x${srcHeight} -> ${newWidth}x${newHeight})  -> $savedName  [$sizeInfo]"
            $totalCount++
        }
        catch {
            Write-Host "  エラー: $($file.Name) の処理に失敗しました - $_"
        }
    }

    Write-Host ""
}

Write-Host "==================================================="
Write-Host "すべての処理が完了しました。（合計 $totalCount 枚、メタデータは削除済み）"
if ($optipngPath -and $totalBeforeBytes -gt 0) {
    $totalReducePercent = [math]::Round((1 - ($totalAfterBytes / $totalBeforeBytes)) * 100, 1)
    $beforeMB = "{0:N2}" -f ($totalBeforeBytes / 1MB)
    $afterMB  = "{0:N2}" -f ($totalAfterBytes  / 1MB)
    Write-Host "圧縮結果: ${beforeMB}MB -> ${afterMB}MB（-${totalReducePercent}%）"
}
Write-Host "出力先フォルダ: $OutDir"
Write-Host "==================================================="
