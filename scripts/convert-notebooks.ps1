[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$jupytext = Join-Path $repoRoot '.venv\Scripts\jupytext.exe'
$notebooks = @(
    Get-ChildItem -LiteralPath (Join-Path $repoRoot 'notebooks') -Filter '*.py' -File |
        Where-Object { $_.Name -match '^\d.*\.py$' } |
        Sort-Object Name
)

if (-not (Test-Path -LiteralPath $jupytext -PathType Leaf)) {
    throw "jupytext not found at $jupytext. Run 'make setup-lite' first."
}
if ($notebooks.Count -eq 0) {
    throw 'No numbered Jupytext notebook sources were found.'
}

& $jupytext --to notebook --update @($notebooks.FullName)
if ($LASTEXITCODE -ne 0) {
    & $jupytext --to notebook @($notebooks.FullName)
    if ($LASTEXITCODE -ne 0) { throw 'Jupytext conversion failed.' }
}
