[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$env:PYTHONUTF8 = '1'
$env:PYTHONIOENCODING = 'utf-8'
$repoRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'convert-notebooks.ps1')

$jupyter = Join-Path $repoRoot '.venv\Scripts\jupyter.exe'
$notebooks = @(
    Get-ChildItem -LiteralPath (Join-Path $repoRoot 'notebooks') -Filter '*.ipynb' -File |
        Where-Object { $_.Name -match '^\d.*\.ipynb$' } |
        Sort-Object Name
)
$failed = $false

foreach ($notebook in $notebooks) {
    Write-Host -NoNewline ('{0,-42}' -f $notebook.FullName.Substring($repoRoot.Length + 1))
    & $jupyter nbconvert --to notebook --execute --inplace $notebook.FullName '--ExecutePreprocessor.timeout=900' *> $null
    if ($LASTEXITCODE -eq 0) {
        Write-Host 'PASS'
    } else {
        Write-Host 'FAIL'
        $failed = $true
    }
}

if ($failed) { throw 'One or more notebooks failed to execute.' }
