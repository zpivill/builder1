# Runs build, lint, format check and tests. Exits non-zero on first failure.
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
$steps = @(
	@("Build", { New-Item -ItemType Directory -Force build | Out-Null; rojo build default.project.json -o build/test.rbxl }),
	@("Lint", { selene src tests }),
	@("Format", { stylua --check src tests }),
	@("Test", { lune run tests/run })
)
foreach ($s in $steps) {
	Write-Host "== $($s[0]) ==" -ForegroundColor Cyan
	& $s[1]
	if ($LASTEXITCODE -ne 0) { Write-Host "$($s[0]) FAILED" -ForegroundColor Red; exit $LASTEXITCODE }
}
Write-Host "All checks passed" -ForegroundColor Green
