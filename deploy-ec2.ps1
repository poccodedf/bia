# Script de Deploy para EC2 - Windows
# Instance: i-0977cdff42c104d9c
# IP: 100.31.242.214

param(
    [string]$KeyPath = "",
    [string]$User = "ec2-user"
)

$EC2_IP = "100.31.242.214"
$INSTANCE_ID = "i-0977cdff42c104d9c"

Write-Host "=== Deploy BIA para EC2 ===" -ForegroundColor Green
Write-Host "Instance: $INSTANCE_ID" -ForegroundColor Cyan
Write-Host "IP: $EC2_IP" -ForegroundColor Cyan
Write-Host ""

# Verificar se a chave SSH foi fornecida
if ([string]::IsNullOrEmpty($KeyPath)) {
    Write-Host "ERRO: Caminho da chave SSH não fornecido!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Uso: .\deploy-ec2.ps1 -KeyPath 'C:\path\to\key.pem' [-User 'ec2-user']" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Exemplos:" -ForegroundColor Yellow
    Write-Host "  .\deploy-ec2.ps1 -KeyPath 'C:\keys\bia-key.pem'" -ForegroundColor Gray
    Write-Host "  .\deploy-ec2.ps1 -KeyPath 'C:\keys\bia-key.pem' -User 'ubuntu'" -ForegroundColor Gray
    exit 1
}

# Verificar se a chave existe
if (-not (Test-Path $KeyPath)) {
    Write-Host "ERRO: Chave SSH não encontrada: $KeyPath" -ForegroundColor Red
    exit 1
}

Write-Host "Passo 1: Copiando script de deploy para EC2..." -ForegroundColor Yellow
scp -i $KeyPath deploy-ec2.sh "${User}@${EC2_IP}:/home/${User}/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERRO ao copiar script. Verifique:" -ForegroundColor Red
    Write-Host "  - Chave SSH está correta" -ForegroundColor Gray
    Write-Host "  - Security Group permite SSH (porta 22)" -ForegroundColor Gray
    Write-Host "  - Usuário está correto (ec2-user, ubuntu, etc)" -ForegroundColor Gray
    exit 1
}

Write-Host "Passo 2: Executando deploy na EC2..." -ForegroundColor Yellow
ssh -i $KeyPath "${User}@${EC2_IP}" "chmod +x deploy-ec2.sh && ./deploy-ec2.sh"

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "=== Deploy concluído com sucesso! ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "Aplicação disponível em: http://${EC2_IP}:3001" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Comandos úteis:" -ForegroundColor Yellow
    Write-Host "  Conectar SSH: ssh -i $KeyPath ${User}@${EC2_IP}" -ForegroundColor Gray
    Write-Host "  Ver logs: ssh -i $KeyPath ${User}@${EC2_IP} 'cd /opt/bia && docker-compose logs -f'" -ForegroundColor Gray
    Write-Host "  Testar API: curl http://${EC2_IP}:3001/api/versao" -ForegroundColor Gray
} else {
    Write-Host ""
    Write-Host "ERRO durante o deploy. Verifique os logs acima." -ForegroundColor Red
    Write-Host ""
    Write-Host "Para debug, conecte via SSH:" -ForegroundColor Yellow
    Write-Host "  ssh -i $KeyPath ${User}@${EC2_IP}" -ForegroundColor Gray
}
