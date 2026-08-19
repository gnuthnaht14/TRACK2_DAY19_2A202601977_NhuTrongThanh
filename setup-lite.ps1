[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$env:PYTHONUTF8 = '1'
$env:PYTHONIOENCODING = 'utf-8'

Write-Host '[lite] Day 19 lightweight setup'
Write-Host '[lite] Stack: fastembed + qdrant-client[memory] + rank-bm25 + feast(sqlite) + FastAPI'
Write-Host ''

$venvPython = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $venvPython -PathType Leaf)) {
    if (Get-Command uv -ErrorAction SilentlyContinue) {
        Write-Host '[lite] Creating venv with uv (faster)'
        & uv venv .venv
    } elseif (Get-Command py -ErrorAction SilentlyContinue) {
        Write-Host '[lite] Creating venv with the Windows Python launcher'
        & py -3 -m venv .venv
    } elseif (Get-Command python -ErrorAction SilentlyContinue) {
        # Windows may expose a non-functional Microsoft Store app-execution
        # alias as python.exe, so verify it before relying on it.
        & python -c 'import sys' *> $null
        if ($LASTEXITCODE -ne 0) {
            throw '[lite] The python command is only a Microsoft Store alias. Install Python 3.10+, or install uv.'
        }
        Write-Host '[lite] Creating venv with python -m venv'
        & python -m venv .venv
    } else {
        throw '[lite] Python not found. Install Python 3.10+, or install uv.'
    }
    if ($LASTEXITCODE -ne 0) { throw '[lite] Failed to create virtual environment.' }
}

$venvVersion = & $venvPython -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
if ($LASTEXITCODE -ne 0) { throw '[lite] The virtual-environment Python is not runnable.' }
$needsDillOverride = (& $venvPython -c "import sys; print(1 if sys.version_info >= (3,14) else 0)") -eq '1'
Write-Host "[lite] venv Python $venvVersion"
if ($needsDillOverride) {
    Write-Host "[lite] Python >= 3.14 -> applying dill>=0.4 override (feast's pin is too old; see requirements.txt)"
}

if (Get-Command uv -ErrorAction SilentlyContinue) {
    $installArgs = @('pip', 'install', '--python', $venvPython)
    if ($needsDillOverride) { $installArgs += @('--overrides', 'overrides-py314.txt') }
    $installArgs += @('-r', 'requirements.txt')
    & uv @installArgs
} else {
    & $venvPython -m pip install -q -U pip
    if ($LASTEXITCODE -eq 0) { & $venvPython -m pip install -q -r requirements.txt }
    if ($LASTEXITCODE -eq 0 -and $needsDillOverride) {
        & $venvPython -m pip install -q --upgrade 'dill>=0.4,<1.0'
    }
}
if ($LASTEXITCODE -ne 0) { throw '[lite] Dependency installation failed.' }

& (Join-Path $PSScriptRoot 'scripts\convert-notebooks.ps1')

$envPath = Join-Path $PSScriptRoot '.env'
if (-not (Test-Path -LiteralPath $envPath)) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '.env.example') -Destination $envPath
}

& $venvPython scripts\seed_corpus.py
if ($LASTEXITCODE -ne 0) { throw '[lite] Corpus generation failed.' }
Write-Host '  - seeding advanced-mission data (NB6 + NB8)...'
& $venvPython scripts\gen_agent_queries.py
if ($LASTEXITCODE -ne 0) { throw '[lite] Agent-query generation failed.' }
& $venvPython scripts\gen_spend.py
if ($LASTEXITCODE -ne 0) { throw '[lite] Spend-data generation failed.' }
& $venvPython scripts\verify_lite.py
if ($LASTEXITCODE -ne 0) { throw '[lite] Smoke test failed.' }

Write-Host ''
Write-Host '[lite] Done. Continue with:'
Write-Host ''
Write-Host '    .\.venv\Scripts\Activate.ps1'
Write-Host '    make api       # start FastAPI on :8000'
Write-Host '    make lab       # open Jupyter on :8888'
Write-Host '    make benchmark # Precision@10 + latency table'
Write-Host ''
Write-Host 'Tip: read VIBE-CODING.md before starting NB1.'
