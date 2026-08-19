[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$relativeTargets = @(
    '.venv',
    'data\corpus_vn.jsonl',
    'data\golden_set.jsonl',
    'data\qdrant_storage',
    'data\agent_queries.jsonl',
    'app\feast_repo\data',
    'app\feast_repo\registry.db',
    'app\feast_repo\online_store.db',
    'app\feast_repo_ondemand\data',
    'app\feast_repo_ondemand\registry.db',
    'app\feast_repo_ondemand\online_store.db',
    'notebooks\.ipynb_checkpoints'
)

$targets = foreach ($relativeTarget in $relativeTargets) {
    $resolved = [IO.Path]::GetFullPath((Join-Path $repoRoot $relativeTarget))
    if (-not $resolved.StartsWith($repoRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove path outside repository: $resolved"
    }
    $resolved
}
$targets += Get-ChildItem -LiteralPath (Join-Path $repoRoot 'notebooks') -Filter '*.ipynb' -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName

foreach ($target in $targets) {
    if (Test-Path -LiteralPath $target) {
        Remove-Item -LiteralPath $target -Recurse -Force
        Write-Host "removed $target"
    }
}
