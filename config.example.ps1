# ============================================================================
# CONFIGURAÇÃO LOCAL - MODELO
# ============================================================================
# Copie este arquivo para config.local.ps1 e preencha com os dados do seu
# ambiente. O arquivo config.local.ps1 está no .gitignore e NÃO deve ser
# versionado, pois pode conter nomes de servidores e comunidades SNMP.
#
# Uso:
#   Copy-Item config.example.ps1 config.local.ps1
#   notepad config.local.ps1
# ============================================================================

$Dominio         = "EXEMPLO"
$UsuarioAdmin    = "usuario.admin"
$ServidorRemoto  = "servidor01.exemplo.local"
$ServidorDMZ     = "192.0.2.10"
$ComunidadeSNMP  = "comunidade-exemplo"
$UsuarioLinux    = "root"
$ServidorLinux   = "192.0.2.20"
$PortaSSH        = 22
$CaminhoChaveSSH = "C:\caminho\chave.ppk"
$GrupoAdmin      = "Administradores"
