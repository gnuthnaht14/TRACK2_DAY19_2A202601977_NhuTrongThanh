[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$env:PYTHONUTF8 = '1'
$env:PYTHONIOENCODING = 'utf-8'

Write-Host '[docker] Day 19 full Docker setup'
Write-Host '[docker] Stack: Qdrant (server) + Redis + Postgres + bge-m3 embeddings'
Write-Host '[docker] Note: bge-m3 downloads about 2.2 GB on first use.'
Write-Host ''

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "[docker] Docker not found. Install/start Docker Desktop, or run '.\setup-lite.ps1'."
}
& docker compose version *> $null
if ($LASTEXITCODE -ne 0) { throw '[docker] Docker Compose v2 is unavailable.' }
& docker info *> $null
if ($LASTEXITCODE -ne 0) { throw '[docker] Docker Desktop is not running.' }

Write-Host '[docker] using docker compose'
& docker compose up -d
if ($LASTEXITCODE -ne 0) { throw '[docker] Unable to start the Docker services.' }
Write-Host '[docker] Waiting up to 30s for services to become healthy...'
for ($i = 1; $i -le 30; $i++) {
    $status = (& docker compose ps --format json 2>$null) -join "`n"
    if ($status -match '"Health"\s*:\s*"healthy"') { break }
    Start-Sleep -Seconds 1
}

$venvPython = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $venvPython -PathType Leaf)) {
    if (Get-Command uv -ErrorAction SilentlyContinue) {
        & uv venv .venv
    } elseif (Get-Command py -ErrorAction SilentlyContinue) {
        & py -3 -m venv .venv
    } elseif (Get-Command python -ErrorAction SilentlyContinue) {
        & python -c 'import sys' *> $null
        if ($LASTEXITCODE -ne 0) {
            throw '[docker] The python command is only a Microsoft Store alias. Install Python 3.10+, or install uv.'
        }
        & python -m venv .venv
    } else {
        throw '[docker] Python not found. Install Python 3.10+, or install uv.'
    }
    if ($LASTEXITCODE -ne 0) { throw '[docker] Failed to create virtual environment.' }
}

$venvVersion = & $venvPython -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
if ($LASTEXITCODE -ne 0) { throw '[docker] The virtual-environment Python is not runnable.' }
Write-Host "[docker] venv Python $venvVersion"
$needsDillOverride = (& $venvPython -c "import sys; print(1 if sys.version_info >= (3,14) else 0)") -eq '1'
if ($needsDillOverride) { Write-Host '[docker] venv Python >= 3.14 -> applying dill>=0.4 override' }

if (Get-Command uv -ErrorAction SilentlyContinue) {
    $installArgs = @('pip', 'install', '--python', $venvPython)
    if ($needsDillOverride) { $installArgs += @('--overrides', 'overrides-py314.txt') }
    $installArgs += @('-r', 'requirements.txt', '-r', 'requirements-full.txt')
    & uv @installArgs
} else {
    & $venvPython -m pip install -q -U pip
    if ($LASTEXITCODE -eq 0) { & $venvPython -m pip install -q -r requirements.txt -r requirements-full.txt }
    if ($LASTEXITCODE -eq 0 -and $needsDillOverride) {
        & $venvPython -m pip install -q --upgrade 'dill>=0.4,<1.0'
    }
}
if ($LASTEXITCODE -ne 0) { throw '[docker] Dependency installation failed.' }

& (Join-Path $PSScriptRoot 'scripts\convert-notebooks.ps1')

$envPath = Join-Path $PSScriptRoot '.env'
if (-not (Test-Path -LiteralPath $envPath)) {
    $envText = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot '.env.example')
    $envText = $envText -replace '(?m)^QDRANT_MODE=memory', 'QDRANT_MODE=server'
    $envText = $envText -replace '(?m)^EMBEDDING_BACKEND=fastembed', 'EMBEDDING_BACKEND=bge-m3'
    $envText = $envText -replace '(?m)^FEAST_ONLINE_STORE=sqlite', 'FEAST_ONLINE_STORE=redis'
    $envText = $envText -replace '(?m)^FEAST_OFFLINE_STORE=file', 'FEAST_OFFLINE_STORE=postgres'
    $utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($envPath, $envText, $utf8WithoutBom)
}

& $venvPython scripts\seed_corpus.py
if ($LASTEXITCODE -ne 0) { throw '[docker] Corpus generation failed.' }
Write-Host '  - seeding advanced-mission data (NB6 + NB8)...'
& $venvPython scripts\gen_agent_queries.py
if ($LASTEXITCODE -ne 0) { throw '[docker] Agent-query generation failed.' }
& $venvPython scripts\gen_spend.py
if ($LASTEXITCODE -ne 0) { throw '[docker] Spend-data generation failed.' }
& $venvPython scripts\verify_docker.py
if ($LASTEXITCODE -ne 0) { throw '[docker] Smoke test failed.' }

Write-Host ''
Write-Host '[docker] Done. Services running:'
Write-Host '  Qdrant   -> http://localhost:6333'
Write-Host '  Redis    -> redis://localhost:6379'
Write-Host '  Postgres -> postgresql://feast:feast@localhost:5432/feast_offline'
Write-Host ''
Write-Host 'Activate the venv with .\.venv\Scripts\Activate.ps1'
Write-Host 'Stop with make docker-down, or reset with make docker-clean.'
