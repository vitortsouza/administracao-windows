<#
.SYNOPSIS
    Coleção de comandos e scripts PowerShell para administração de ambientes Windows,
    Hyper-V, Veeam, Kaspersky, monitoramento e automação.

.DESCRIPTION
    Este arquivo funciona como um "caderno de receitas": os blocos são independentes e
    devem ser executados individualmente, após revisão. Nenhum host, IP, usuário ou
    senha real está incluído. Preencha os placeholders no topo ou use config.local.ps1.

.NOTES
    - Execute apenas em ambientes autorizados.
    - Prefira autenticação por chave (SSH) e Get-Credential (Windows).
    - Não execute o arquivo inteiro sem revisar cada seção.
#>

# ============================================================================
# 0. CONFIGURAÇÃO
# ============================================================================
# Valores de exemplo. Para uso real, copie config.example.ps1 para config.local.ps1,
# preencha os valores e mantenha o arquivo fora do Git (já está no .gitignore).
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

$configLocal = Join-Path $PSScriptRoot "config.local.ps1"
if (Test-Path $configLocal) { . $configLocal }

# ============================================================================
# 1. SESSÕES REMOTAS (POWERSHELL REMOTING / WINRM)
# ============================================================================
# Cria a credencial em tempo de execução, sem gravar a senha em disco.
$Credencial = Get-Credential -UserName "$Dominio\$UsuarioAdmin" -Message "Informe a senha administrativa"

# Executa um comando em um servidor remoto.
Invoke-Command -ComputerName $ServidorRemoto -Credential $Credencial -ScriptBlock {
    Get-ChildItem -Path "C:\ProgramData\Veeam\Endpoint"
}

# Abre uma sessão interativa em um servidor do domínio.
Enter-PSSession -ComputerName $ServidorRemoto -Credential $Credencial

# Abre uma sessão interativa em um servidor da DMZ.
Enter-PSSession -ComputerName $ServidorDMZ -Credential $Credencial

# Sai da sessão interativa.
Exit-PSSession

# Cria uma sessão persistente para reutilizar em cópias de arquivos.
$session = New-PSSession -ComputerName $ServidorRemoto -Credential $Credencial

# ============================================================================
# 2. USUÁRIOS E SESSÕES LOCAIS
# ============================================================================
# Lista usuários logados na máquina local.
query user

# Encerra a sessão do usuário pelo ID retornado pelo comando anterior.
logoff 11

# ============================================================================
# 3. ARQUIVOS E DIRETÓRIOS
# ============================================================================
# Lista o conteúdo de uma pasta.
Get-ChildItem -Path "C:\ProgramData\Veeam\Endpoint"

# Pesquisa arquivos .log recursivamente, ignorando erros de acesso.
Get-ChildItem -Path "C:\ProgramData\Veeam\Endpoint" -Filter "*.log" -Recurse -ErrorAction SilentlyContinue -Force

# Copia um arquivo para corrigir o nome duplicado da extensão.
Copy-Item -Path "C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXE\RestartPendente.ps1.ps1" -Destination "C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXE\RestartPendente.ps1"

# Exibe o conteúdo de um arquivo.
Get-Content -Path "C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXE\RestartPendente.ps1.ps1"

# Pesquisa uma string dentro de um arquivo de log (substitua <GUID_DO_JOB> pelo ID real).
Select-String -Path "C:\ProgramData\Veeam\Endpoint\Agent_Backup_Job_1\Agent.Source.<GUID_DO_JOB>.log" -Pattern "job" -CaseSensitive

# Executa um script PowerShell.
& "C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXE\RestartPendente.ps1"

# ============================================================================
# 4. CÓPIA DE ARQUIVOS ENTRE MÁQUINAS
# ============================================================================
# Envia um arquivo local para um servidor remoto.
$session = New-PSSession -ComputerName $ServidorRemoto -Credential $Credencial
Copy-Item -Path "C:\temp\arquivo" -Destination "C:\servidor\arquivo" -ToSession $session -Recurse

# Copia um arquivo do servidor remoto para a máquina local.
$session = New-PSSession -ComputerName $ServidorRemoto -Credential $Credencial
Copy-Item -Path "C:\Users\<USUARIO>\Desktop\ADSelfServicePlusClientSoftware.msi" -Destination "C:\temp\ADSelfServicePlusClientSoftware.msi" -FromSession $session

# ============================================================================
# 5. VEEAM BACKUP
# ============================================================================
# Lista jobs do Veeam Backup & Replication com seus IDs.
Get-VBRJob | Select-Object Name, Id

# Inicia os serviços do Veeam que estiverem parados.
Get-Service -Name "Veeam*" | Where-Object { $_.Status -ne "Running" } | Start-Service -Verbose

# Inicia os serviços do PostgreSQL usados pelo Veeam.
Get-Service -Name "postgres*" | Start-Service -Verbose

# Se o PostgreSQL não iniciar, renomeie C:\Program Files\PostgreSQL\15\data\postmaster.pid
# para postmaster.pid.old, finalize processos órfãos (postgres.exe e pg_ctl.exe) e tente novamente.

# ============================================================================
# 6. KASPERSKY
# ============================================================================
# Força o envio de heartbeat do Network Agent para o Kaspersky Security Center.
& 'C:\Program Files (x86)\Kaspersky Lab\NetworkAgent\klnagchk.exe' -sendhb

# Exibe os últimos eventos do log do Kaspersky.
Get-WinEvent -LogName "Kaspersky Event log" -MaxEvents 20

# Filtra somente eventos de erro (Level 2) do log do Kaspersky.
Get-WinEvent -FilterHashtable @{LogName="Kaspersky Event log"; Level=2} -MaxEvents 10

# Localiza o nome exato de um log relacionado ao Kaspersky.
Get-WinEvent -ListLog * | Where-Object { $_.LogName -like "*Kaspersky*" }

# Descobre qual conta inicia o serviço do Kaspersky.
$serviceName = "kladminserver"
(Get-WmiObject -Class Win32_Service -Filter "Name='$serviceName'").StartName

##############
# Verificação do status de proteção do Kaspersky Endpoint Security (KES).
# Cria um arquivo de flag quando a proteção está parada e remove a flag
# quando a proteção volta a ficar ativa.
##############
$flagPath  = "C:\ProgramData\Company\SecurityState\kaspersky-paused.flag"
$stateDir  = Split-Path $flagPath -Parent
$debugPath = Join-Path $stateDir "kes-status-debug.txt"

# Garante que o diretório de estado exista.
if (-not (Test-Path $stateDir -PathType Container)) {
    New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
}

# Localiza o executável avp.com nas instalações do Kaspersky.
function Get-AVPComPath {
    $roots = @(
        "C:\Program Files (x86)\Kaspersky Lab",
        "C:\Program Files\Kaspersky Lab"
    )

    foreach ($root in $roots) {
        if (Test-Path $root -PathType Container) {
            $found = Get-ChildItem -Path $root -Filter "avp.com" -File -Recurse -ErrorAction SilentlyContinue |
                Sort-Object FullName -Descending |
                Select-Object -First 1 -ExpandProperty FullName

            if ($found) {
                return $found
            }
        }
    }

    return $null
}

# Executa "avp.com STATUS" e grava a saída em um arquivo de depuração.
function Get-KESStatusText {
    $avpCom = Get-AVPComPath

    if (-not $avpCom) {
        "ERROR: avp.com not found" | Set-Content -Path $debugPath -Encoding UTF8
        return $null
    }

    $output = & $avpCom STATUS 2>&1 | Out-String
    "Using avp.com: $avpCom`r`n`r`n$output" | Set-Content -Path $debugPath -Encoding UTF8
    return $output
}

# Verifica se a linha "Protection stopped" aparece na saída do STATUS.
function Test-KESProtectionPaused {
    $status = Get-KESStatusText

    if (-not $status) {
        return $false
    }

    $protectionStopped = $status -split '\r?\n' | Where-Object { $_ -match '^\s*Protection\s+stopped\b' }
    if ($protectionStopped) {
        return $true
    }

    return $false
}

# Cria ou remove a flag conforme o estado da proteção.
if (Test-KESProtectionPaused) {
    if (-not (Test-Path $flagPath -PathType Leaf)) {
        New-Item -Path $flagPath -ItemType File -Force | Out-Null
    }
}
else {
    if (Test-Path $flagPath -PathType Leaf) {
        Remove-Item $flagPath -Force
    }
}

# ============================================================================
# 7. INSTALAÇÃO E ATUALIZAÇÃO DE SOFTWARE
# ============================================================================
# Instala o SpotX (cliente Spotify modificado) via script oficial do projeto.
iex "& { $(iwr -useb 'https://raw.githubusercontent.com/SpotX-Official/spotx-official.github.io/main/run.ps1') } -new_theme"

# Atualiza todos os programas instalados usando Winget, em modo silencioso.
winget upgrade --all --silent --accept-source-agreements --accept-package-agreements

# Baixa e instala o .NET Framework 4.8 silenciosamente.
# Substitua <ID_DO_DOWNLOAD> pelo identificador real do download.
$url = "https://download.visualstudio.microsoft.com/download/pr/<ID_DO_DOWNLOAD>/dotnet-framework-4.8.exe"
$installerPath = "$env:USERPROFILE\Downloads\dotnet-framework-4.8.exe"
Invoke-WebRequest -Uri $url -OutFile $installerPath
Start-Process -FilePath $installerPath -ArgumentList "/quiet", "/norestart" -Wait

# Instala o Chocolatey (executa o instalador oficial).
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Verifica a versão do Chocolatey.
choco --version

# Atualiza todos os pacotes instalados via Chocolatey.
choco upgrade all -y

# ============================================================================
# 8. SNMP E MONITORAMENTO
# ============================================================================
# Instala o serviço SNMP com todas as subfeatures e ferramentas de gerenciamento.
Install-WindowsFeature SNMP-Service -IncludeAllSubFeature -IncludeManagementTools

# Permite consultas SNMP a partir do localhost e de um host de monitoração.
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\PermittedManagers" -Name "1" -Value "localhost"
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\PermittedManagers" -Name "2" -Value $ServidorDMZ

# Cria a comunidade SNMP somente leitura (valor 4).
New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SNMP\Parameters" -Name "ValidCommunities" -Force
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\ValidCommunities" -Name $ComunidadeSNMP -Value 4 -PropertyType DWord -Force

# Reinicia o serviço SNMP para aplicar as alterações.
Restart-Service SNMP

# ============================================================================
# 9. SERVIÇOS DO WINDOWS
# ============================================================================
# Lista serviços em execução.
Get-Service | Where-Object { $_.Status -eq 'Running' }

# Lista serviços parados.
Get-Service | Where-Object { $_.Status -eq 'Stopped' }

# Pesquisa serviços por parte do nome.
Get-Service -Name "*self*" | Select-Object -Property Name, DisplayName, Status

# Lista base de serviços usados com frequência.
$servicos = @('klnagent', 'AVP', 'SNMP', 'winmgmt')

# Serviços do Safetica.
$servicos = @('MSSQL$SAFETICA', 'SQLBrowser', 'klnagent', 'AVP', 'STAService', 'SafeticaService', 'STEventService')

# Serviços do Kaspersky Security Center.
$servicos = @('MSSQL$SQLEXPRESS', 'kladminserver', 'SQLBrowser', 'klnagent', 'SQLAgent$SQLEXPRESS', 'klakaut', 'KPSSVC', 'VIISLA', 'AVP', 'KSCWebConsole', 'KSCWebConsoleManagementService', 'Kaspersky Security Center Web Console Message Queue')

# Inicia cada serviço da lista atual.
foreach ($servico in $servicos) {
    Start-Service -Name $servico
    Write-Host "Serviço $servico iniciado."
}

# Reinicia um serviço específico forçando o encerramento.
Restart-Service -Name ADSelfServicePlus -Force

# Para um serviço específico forçando o encerramento.
Stop-Service -Name spooler -Force

# Exibe a conta que inicia um serviço.
$serviceName = "kladminserver"
Get-WmiObject Win32_Service | Where-Object { $_.Name -eq $serviceName } | Select-Object Name, StartName

# Configura reinício automático após falha em um serviço específico.
sc.exe failure "ADSelfServicePlus" reset= 0 actions= restart/60000

# Configura reinício automático após falha para uma lista de serviços.
$servicos = @('snmp', 'klnagent', 'winmgmt')
foreach ($serviceName in $servicos) {
    $command = "sc.exe failure `"$serviceName`" reset= 0 actions= restart/60000"
    Invoke-Expression $command
    Write-Output "Ação de falha configurada para o serviço $serviceName."
}

# ============================================================================
# 10. AGENDADOR DE TAREFAS (TASK SCHEDULER)
# ============================================================================
##############
# Tarefa agendada para monitorar e iniciar o klnagent no boot.
##############
$scriptPath = Join-Path $env:ProgramData "Scripts\IniciarKlnagentServico.ps1"
$scriptDir = Split-Path -Parent $scriptPath
if (-not (Test-Path $scriptDir)) { New-Item -ItemType Directory -Path $scriptDir -Force | Out-Null }

$scriptContent = @'
# Nome do serviço que você deseja monitorar e iniciar
$serviceName = "klnagent"

# Obtém o status do serviço
$service = Get-Service -Name $serviceName

# Verifica se o serviço está parado
if ($service.Status -eq "Stopped") {
    Start-Service -Name $serviceName
    Write-Output "O serviço $serviceName foi iniciado."
} else {
    Write-Output "O serviço $serviceName já está em execução."
}
'@

Set-Content -Path $scriptPath -Value $scriptContent
Write-Output "Script salvo em $scriptPath"

$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -TaskName "IniciarKlnagentAutomaticamenteNoStartup" -Description "Monitora e inicia o serviço klnagent automaticamente quando o sistema iniciar."

# Remove a tarefa agendada.
Unregister-ScheduledTask -TaskName "IniciarKlnagentAutomaticamenteNoStartup" -Confirm:$false
Get-ScheduledTask -TaskName "IniciarKlnagentAutomaticamenteNoStartup"

##############
# Tarefa agendada para monitorar e iniciar vários serviços no boot.
##############
$scriptPath = Join-Path $env:ProgramData "Scripts\IniciarServicos.ps1"
$scriptDir = Split-Path -Parent $scriptPath
if (-not (Test-Path $scriptDir)) { New-Item -ItemType Directory -Path $scriptDir -Force | Out-Null }

$scriptContent = @'
# Lista dos serviços que você deseja monitorar e iniciar
$servicos = @("klnagent", "AVP", "SNMP", "winmgmt")

foreach ($serviceName in $servicos) {
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

    if ($service) {
        if ($service.Status -eq "Stopped") {
            Start-Service -Name $serviceName
            Write-Output "O serviço $serviceName foi iniciado."
        } else {
            Write-Output "O serviço $serviceName já está em execução."
        }
    } else {
        Write-Output "O serviço $serviceName não foi encontrado."
    }
}
'@

Set-Content -Path $scriptPath -Value $scriptContent
Write-Output "Script salvo em $scriptPath"

$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -TaskName "IniciarServicosAutomaticamenteNoStartup" -Description "Monitora e inicia vários serviços automaticamente quando o sistema iniciar."

# ============================================================================
# 11. LOGS E EVENTOS
# ============================================================================
# Pesquisa no log System eventos de erro que mencionem o klnagent.
Get-WinEvent -LogName System | Where-Object { $_.Message -like "*klnagent*" -and $_.LevelDisplayName -eq "Error" }

# ============================================================================
# 12. HYPER-V
# ============================================================================
# Lista todas as VMs do host.
Get-VM

# Seleciona uma VM específica pelo nome.
$vm = (Get-VM -Name "VM-Exemplo").Name
Get-VM -Name $vm

# Inicia uma VM.
Start-VM -Name $vm

# Reinicia uma VM.
Restart-VM -Name "NomeDaVM"

# Desliga uma VM de forma controlada.
Stop-VM -Name "NomeDaVM"

# Força o desligamento de uma VM.
Stop-VM -Name "NomeDaVM" -Force

# Exibe o consumo de memória da VM.
Get-VM -Name $vm | Select-Object Name, MemoryAssigned, MemoryDemand, MemoryStatus

# ============================================================================
# 13. PERMISSÕES E USUÁRIOS
# ============================================================================
# Exibe a ACL de uma pasta.
Get-Acl -Path "D:\Backup\"
(Get-Acl -Path "D:\Backup\").Access

# Adiciona permissão para um usuário ou grupo.
$folderPath = "D:\Backup\"
$user = "<USUARIO_OU_GRUPO>"
$permission = "FullControl"  # FullControl, Modify, ReadAndExecute, ListDirectory, Read, Write
$acl = Get-Acl -Path $folderPath
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($user, $permission, "Allow")
$acl.SetAccessRule($accessRule)
Set-Acl -Path $folderPath -AclObject $acl

# Remove a permissão adicionada acima.
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($user, $permission, "Allow")
$acl.RemoveAccessRule($accessRule)
Set-Acl -Path $folderPath -AclObject $acl

# Lista os membros de um grupo local administrativo.
Get-LocalGroupMember -Group $GrupoAdmin

# ============================================================================
# 14. WINDOWS UPDATE
# ============================================================================
# Lista atualizações pendentes usando a API COM do Windows Update.
$updateSession = New-Object -ComObject Microsoft.Update.Session
$updateSearcher = $updateSession.CreateUpdateSearcher()
try {
    $searchResult = $updateSearcher.Search("IsInstalled=0")
    if ($searchResult.Updates.Count -eq 0) {
        Write-Host "Nenhuma atualização pendente encontrada."
    } else {
        $searchResult.Updates | Select-Object -Property Title, Description, IsMandatory
    }
} catch {
    Write-Host "Erro ao buscar atualizações: $_"
}

# Lista atualizações já instaladas via WMI.
Get-WmiObject -Query "SELECT * FROM Win32_QuickFixEngineering"

# Lista o histórico de atualizações instaladas com sucesso (ResultCode 2).
$updateSession = New-Object -ComObject Microsoft.Update.Session
$updateSearcher = $updateSession.CreateUpdateSearcher()
$historyCount = $updateSearcher.GetTotalHistoryCount()
$updateSearcher.QueryHistory(0, $historyCount) |
    Where-Object { $_.ResultCode -eq 2 } |
    Select-Object -Property Title, Description, Date, ResultCode

# Instala atualizações sem reiniciar (requer o módulo PSWindowsUpdate).
Install-WindowsUpdate -AcceptAll -IgnoreReboot

# ============================================================================
# 15. LINUX (SSH / PLINK)
# ============================================================================
# Lista de comandos disponíveis para execução remota.
$comandos = @(
    "ls -l",
    "df -h",
    "systemctl restart nginx",
    "uptime",
    "systemctl status klnagent"
)

# Escolhe o comando pelo índice da lista.
$indice = 1
$comando = $comandos[$indice]

# Executa o comando via Plink usando autenticação por chave (sem senha em texto puro).
$output = & "C:\Program Files\PuTTY\plink.exe" -ssh "${UsuarioLinux}@${ServidorLinux}" -P $PortaSSH -i $CaminhoChaveSSH $comando
Write-Output $output

# Abre uma sessão interativa via Plink.
Start-Process "C:\Program Files\PuTTY\plink.exe" -ArgumentList "-ssh ${UsuarioLinux}@${ServidorLinux} -P $PortaSSH -i `"$CaminhoChaveSSH`""

# ============================================================================
# 16. POWERSHELL 7 - RUNSPACE FORA DE PROCESSO
# ============================================================================
# Inicia um processo PWSH oculto.
$Process = Start-Process PWSH -ArgumentList @("-NoExit") -PassThru -WindowStyle Hidden

function New-OutOfProcRunspace {
    param($ProcessId)

    $ci = New-Object -TypeName System.Management.Automation.Runspaces.NamedPipeConnectionInfo -ArgumentList @($ProcessId)
    $tt = [System.Management.Automation.Runspaces.TypeTable]::LoadDefaultTypeFiles()

    $Runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($ci, $Host, $tt)

    $Runspace.Open()
    $Runspace
}

# Cria o runspace conectado ao processo e o empurra para o host.
$Runspace = New-OutOfProcRunspace -ProcessId $Process.Id
$Host.PushRunspace($Runspace)
