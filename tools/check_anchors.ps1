$errors = @()
$files = Get-ChildItem -Recurse -Filter *.md (Join-Path $PSScriptRoot '..\docs\02-synthesis')
foreach ($f in $files) {
    $dir = $f.DirectoryName
    $content = Get-Content $f.FullName -Raw -Encoding UTF8
    $matches_ = [regex]::Matches($content, '\]\(([^)\s]+#[^)\s]+)\)')
    foreach ($m in $matches_) {
        $link = $m.Groups[1].Value
        $parts = $link -split '#', 2
        $file = $parts[0]; $anchor = $parts[1]
        if ($file -eq '') { $target = $f.FullName } else { $target = Join-Path $dir $file }
        if (-not (Test-Path $target)) { continue }
        $am = [regex]::Match($anchor, '^(\d+)-')
        if (-not $am.Success) { continue }
        $num = $am.Groups[1].Value
        $tc = Get-Content $target -Raw -Encoding UTF8
        $found = $false
        # try as major section "## N. "
        if ([regex]::IsMatch($tc, "(?m)^##\s+$num\.\s")) { $found = $true }
        # try as subsection "### X.Y" where num = X concatenated with Y (last digit as minor)
        if (-not $found -and $num.Length -ge 2) {
            $maj = $num.Substring(0, $num.Length - 1)
            $min = $num.Substring($num.Length - 1)
            if ([regex]::IsMatch($tc, "(?m)^###\s+$maj\.$min\b")) { $found = $true }
        }
        if (-not $found) { $errors += ("{0} -> {1}" -f $f.Name, $link) }
    }
}
if ($errors) { $errors } else { 'ALL NUMBERED ANCHORS OK' }
