param(
    [string]$msg = "Atualização da Boleta L&S"
)

# Caminho da boleta
$boleta = "Experts/Boleta-L&S.mq5"

# Adiciona a boleta ao commit
git add "$boleta"

# Cria o commit
git commit -m "$msg"

# Envia para o GitHub
git push

#.\commit_boleta.ps1 -msg 