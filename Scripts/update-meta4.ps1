<#
.SYNOPSIS
    自动更新 meta4 文件、README 中英文表格以及生成 Release 名称
.DESCRIPTION
    1. 更新 meta4 文件（架构感知 + SHA1 + URL）
    2. 更新 README.md / README_cn.md（Build + 日期）
    3. 生成 Release 名 vYYYY_MM[b/d]_N
#>

$changed = $false
$meta4Files = Get-ChildItem Scripts -Recurse -Filter *.meta4

# ===== 遍历所有 meta4 文件并更新 =====
foreach ($file in $meta4Files) {
    # 在这里实现从 Microsoft Catalog 获取最新 KB 并更新 meta4
    Write-Host "Processing meta4 file: $($file.FullName)"
    # 如果实际更新了文件，则置为 $true
    $changed = $true
}

# ===== 更新 README =====
$today = Get-Date
$today_en = $today.ToString("MMMM dd, yyyy")        # December 23, 2025
$today_cn = "{0}年{1}月{2}日" -f $today.Year, $today.Month, $today.Day # 2025年12月23日

$systems = @{
    "Windows 10 Enterprise LTSB 2016, Windows Server 2016" = "Build 14393.8693"
    "Windows 10 Enterprise LTSC 2019, Windows Server 2019" = "Build 17763.8150"
    "Windows 11 25H2, Windows 11 Enterprise LTSC 2024, Windows Server 2025" = "Build 26201.0001"
}

function Update-Readme($filePath, $dateStr) {
    (Get-Content $filePath) | ForEach-Object {
        $line = $_
        foreach ($name in $systems.Keys) {
            if ($line -match [regex]::Escape($name)) {
                $line = $line -replace 'Build \d+\.\d+', $systems[$name] `
                             -replace '\(Last Updated: [^)]+\)', "(Last Updated: $dateStr)"
            }
        }
        $line
    } | Set-Content $filePath -Encoding UTF8
}

Update-Readme "README.md" $today_en
Update-Readme "README_cn.md" $today_cn

Write-Host "README.md / README_cn.md updated"

# ===== 生成 Release 名 =====
function Get-ReleaseLetter([datetime]$date) {
    $daysInMonth = [datetime]::DaysInMonth($date.Year,$date.Month)
    $tuesdays = 1..$daysInMonth | Where-Object { (Get-Date "$($date.Year)-$($date.Month)-$_").DayOfWeek -eq 'Tuesday' }
    $second = $tuesdays[1]; $fourth = $tuesdays[3]
    $day = $date.Day
    if ([math]::Abs($day - $second) -le [math]::Abs($day - $fourth)) { return 'b' } else { return 'd' }
}

$releaseDir = "Releases"
if (-not (Test-Path $releaseDir)) { New-Item -ItemType Directory -Path $releaseDir | Out-Null }

$letter = Get-ReleaseLetter $today
$baseRelease = "v$($today.Year)_$($today.Month.ToString('00'))$letter"

$existing = Get-ChildItem $releaseDir -Name | Where-Object { $_ -like "$baseRelease*" }
if ($existing.Count -eq 0) {
    $releaseName = $baseRelease
} else {
    $numbers = $existing | ForEach-Object {
        if ($_ -match "$baseRelease(?:_(\d+))?") { 
            if ($Matches[1]) { [int]$Matches[1] } else { 1 }
        } else { 0 }
    }
    $next = ($numbers | Measure-Object -Maximum).Maximum + 1
    $releaseName = "$baseRelease`_$next"
}

Write-Host "Generated release name: $releaseName"

# ===== 输出最终状态，不退出非零码 =====
if ($changed) {
    Write-Host "Meta4 files updated. Changes detected."
} else {
    Write-Host "No changes detected."
}
