param($Dir,$Agent,$Port)
Set-Location $Dir
$env:PORT = $Port
if (Test-Path package.json) { pnpm install }
$b = Get-Content -Raw docs\redesign-brief.md
if ($Agent -eq 'fable') {
  $b | claude -p --allowedTools "Read,Edit,Write,Bash" --bare *> run.log
} else {
  codex exec --model gpt-6-astra --reasoning-effort high $b *> run.log
}
