# Quick script to check indentation issues in run.ps1
$filePath = ".\Receive-Alert\run.ps1"
$lines = Get-Content $filePath
$inMainTry = $false
$issueLines = @()

for ($i = 0; $i -lt $lines.Count; $i++) {
    $lineNum = $i + 1
    $line = $lines[$i]
    
    if ($line -match '^\s*try\s*{' -and $lineNum -eq 15) {
        $inMainTry = $true
        continue
    }
    
    if ($line -match '^\s*catch\s*{' -and $lineNum -eq 436) {
        $inMainTry = $false
        continue
    }
    
    if ($inMainTry -and $line -match '^[^\s]' -and $line.Trim() -ne '') {
        $issueLines += "Line $lineNum`: $line"
    }
}

Write-Host "Lines with indentation issues (should start with 4 spaces):"
$issueLines | Select-Object -First 20
