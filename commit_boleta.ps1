# commit_boleta.ps1
# Script para enviar automaticamente arquivos para o GitHub

# ============================
# 🔧 MENSAGEM DO COMMIT
# ============================
$msg = "Primeira nova versao"

# ============================
# 🔎 Caminho absoluto do bol.mq5
# ============================
$bolFile = "$env:APPDATA\MetaQuotes\Terminal\38FF261A42172F3478E54D3A1A8FE02B\MQL5\Experts\bol\bol.mq5"

# ============================
# 📂 Arquivos a serem enviados
# ============================
$arquivos = @(
    "Experts/Boleta2.mq5",
    "commit_boleta.ps1",
    $bolFile
)

Write-Host "🔄 Adicionando arquivos..." -ForegroundColor Cyan
git add $arquivos

Write-Host "📌 Commitando com a mensagem: $msg" -ForegroundColor Yellow
git commit -m "$msg"

Write-Host "⬆️ Enviando para GitHub..." -ForegroundColor Green
git push

Write-Host "✅ Finalizado com sucesso!" -ForegroundColor Green
