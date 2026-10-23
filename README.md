# Scripts de Administração Windows

Coleção de comandos e scripts PowerShell para administração de servidores Windows,
Hyper-V, Veeam, Kaspersky, SNMP, monitoramento, tarefas agendadas e Linux via SSH.

O arquivo foi **sanitizado**: não contém nomes reais de hosts, endereços IP, usuários,
senhas ou comunidades SNMP. Todos os dados do ambiente ficam em placeholders ou no
arquivo local `config.local.ps1`, que não é versionado.

> **Aviso:** execute os blocos apenas em ambientes autorizados e após revisar cada
> comando. O `Scripts.ps1` é um caderno de receitas; não execute o arquivo inteiro
> de uma só vez.

## Estrutura do projeto

| Arquivo | Descrição |
| --- | --- |
| `Scripts.ps1` | Comandos e scripts organizados por tópicos. |
| `config.example.ps1` | Modelo de configuração com placeholders. |
| `config.local.ps1` | Configuração real do ambiente (criada por você, ignorada pelo Git). |
| `.gitignore` | Impede o envio de configurações locais, chaves, logs e segredos. |
| `README.md` | Este documento. |

## Como usar

1. Copie o modelo de configuração:

   ```powershell
   Copy-Item config.example.ps1 config.local.ps1
   ```

2. Edite `config.local.ps1` com os dados do seu ambiente (hosts, IPs, usuário etc.).

3. Abra `Scripts.ps1`, revise a seção desejada e execute apenas aquele bloco.

4. Se necessário, libere a execução de scripts apenas para a sessão atual:

   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force
   ```

As credenciais são solicitadas em tempo de execução com `Get-Credential`. Nenhuma
senha deve ser gravada em arquivo.

### Placeholders usados

- `<USUARIO>`, `<USUARIO_OU_GRUPO>`, `<GRUPO_ADMIN>`, `<GUID_DO_JOB>`, `<ID_DO_DOWNLOAD>`.
- IPs de exemplo `192.0.2.x` pertencem à faixa de documentação (TEST-NET-1).
- Hosts de exemplo usam `exemplo.local`.

## Tópicos

### 0. Configuração

Define as variáveis usadas no restante do arquivo: domínio, usuário administrativo,
servidor remoto, servidor da DMZ, comunidade SNMP, usuário/servidor Linux, porta SSH,
caminho da chave e grupo administrativo.

O bloco final carrega `config.local.ps1`, se ele existir, sobrescrevendo os valores
de exemplo.

### 1. Sessões remotas (PowerShell Remoting/WinRM)

- `Get-Credential`: cria o objeto de credencial sem armazenar a senha em texto puro.
- `Invoke-Command -ComputerName ... -ScriptBlock { ... }`: executa um comando em um
  servidor remoto e devolve a saída.
- `Enter-PSSession`: abre uma sessão interativa no servidor remoto.
- `Exit-PSSession`: encerra a sessão interativa.
- `New-PSSession`: cria uma sessão persistente, útil para reutilizar em cópias de
  arquivos.

Requer WinRM habilitado no destino e conectividade nas portas usuais (5985/5986).

### 2. Usuários e sessões locais

- `query user`: lista os usuários logados e seus IDs de sessão.
- `logoff 11`: encerra a sessão com o ID informado. Ajuste o número conforme a saída
  de `query user`.

### 3. Arquivos e diretórios

- `Get-ChildItem`: lista o conteúdo de uma pasta.
- `Get-ChildItem -Filter "*.log" -Recurse -ErrorAction SilentlyContinue -Force`:
  procura logs recursivamente, ignorando erros de acesso e incluindo arquivos ocultos.
- `Copy-Item`: copia/renomeia um arquivo. No exemplo, corrige o nome duplicado
  `RestartPendente.ps1.ps1`.
- `Get-Content`: mostra o conteúdo de um arquivo.
- `Select-String -CaseSensitive`: procura uma string dentro de um arquivo, diferenciando
  maiúsculas de minúsculas. Substitua `<GUID_DO_JOB>` pelo ID real.
- `& "caminho\script.ps1"`: executa um script PowerShell.

### 4. Cópia de arquivos entre máquinas

- `New-PSSession`: abre a sessão remota que será usada na cópia.
- `Copy-Item -ToSession`: envia um arquivo local para o servidor remoto.
- `Copy-Item -FromSession`: traz um arquivo do servidor remoto para a máquina local.

O parâmetro `-Recurse` copia diretórios inteiros.

### 5. Veeam Backup

- `Get-VBRJob`: lista os jobs do Veeam Backup & Replication com nome e ID. Requer os
  módulos do Veeam.
- `Get-Service -Name "Veeam*" | ... | Start-Service`: inicia os serviços do Veeam que
  estiverem parados.
- `Get-Service -Name "postgres*" | Start-Service`: inicia os serviços do PostgreSQL
  usados pelo Veeam.
- O comentário final descreve o procedimento quando o PostgreSQL não inicia: renomear
  `postmaster.pid` para `postmaster.pid.old`, finalizar processos órfãos e tentar de novo.

### 6. Kaspersky

- `klnagchk.exe -sendhb`: força o envio de heartbeat do Network Agent para o
  Kaspersky Security Center.
- `Get-WinEvent -LogName "Kaspersky Event log" -MaxEvents 20`: mostra os últimos 20
  eventos do log do Kaspersky.
- `Get-WinEvent -FilterHashtable @{... Level=2}`: filtra apenas eventos de erro.
- `Get-WinEvent -ListLog * | Where-Object ...`: localiza o nome exato de um log.
- `Get-WmiObject Win32_Service ... StartName`: mostra qual conta inicia o serviço.

#### Verificação do status de proteção do KES

O bloco final da seção verifica se a proteção do Kaspersky Endpoint Security (KES)
está pausada:

- Define `$flagPath` (`C:\ProgramData\Company\SecurityState\kaspersky-paused.flag`) e
  `$debugPath` (`kes-status-debug.txt`) e cria o diretório de estado, se necessário.
- `Get-AVPComPath`: procura o `avp.com` em `C:\Program Files (x86)\Kaspersky Lab` e
  `C:\Program Files\Kaspersky Lab`, retornando o caminho encontrado.
- `Get-KESStatusText`: executa `avp.com STATUS`, grava a saída no arquivo de depuração
  e retorna o texto do status. Se o executável não existir, grava o erro no debug.
- `Test-KESProtectionPaused`: interpreta a saída e retorna `$true` quando encontra a
  linha `Protection stopped`.
- Se a proteção estiver parada, cria o arquivo de flag; se estiver ativa, remove a flag.
  A flag pode ser consumida por ferramentas de monitoração (por exemplo, PRTG/Zabbix).

O comando `avp.com STATUS` pode exigir senha caso o KES esteja protegido por senha.

### 7. Instalação e atualização de software

- `iex (iwr ... run.ps1)`: instala o SpotX executando o script oficial do projeto.
  Revise scripts de terceiros antes de executar.
- `winget upgrade --all --silent ...`: atualiza todos os programas instalados via
  WinGet, aceitando os termos automaticamente.
- `Invoke-WebRequest` + `Start-Process /quiet /norestart`: baixa e instala o
  .NET Framework 4.8 silenciosamente. Substitua `<ID_DO_DOWNLOAD>` pela URL real.
- Instalação do Chocolatey: ajusta a `ExecutionPolicy` da sessão, habilita TLS 1.2 e
  executa o instalador oficial.
- `choco --version`: confirma a versão instalada.
- `choco upgrade all -y`: atualiza todos os pacotes gerenciados pelo Chocolatey.

### 8. SNMP e monitoramento

- `Install-WindowsFeature SNMP-Service -IncludeAllSubFeature -IncludeManagementTools`:
  instala o serviço SNMP e as ferramentas de gerenciamento (Windows Server).
- `Set-ItemProperty ... PermittedManagers`: autoriza consultas SNMP do `localhost` e do
  host de monitoração definido em `$ServidorDMZ`.
- `New-ItemProperty ... ValidCommunities -Value 4`: cria a comunidade SNMP com direito
  somente leitura (`4 = READ ONLY`). O nome vem de `$ComunidadeSNMP`.
- `Restart-Service SNMP`: aplica as alterações reiniciando o serviço.

### 9. Serviços do Windows

- `Get-Service | Where-Object Status -eq ...`: lista serviços em execução ou parados.
- `Get-Service -Name "*self*"`: pesquisa serviços por parte do nome.
- As listas `$servicos` reúnem serviços comuns, do Safetica e do Kaspersky Security
  Center. Foram usadas aspas simples para preservar nomes com `$`, como
  `MSSQL$SAFETICA` e `SQLAgent$SQLEXPRESS`.
- `foreach ... Start-Service`: percorre a lista e inicia cada serviço.
- `Restart-Service -Force` / `Stop-Service -Force`: reinicia ou para um serviço,
  encerrando processos dependentes quando necessário.
- `sc.exe failure ... reset= 0 actions= restart/60000`: configura reinício automático
  60 segundos após uma falha. O `foreach` aplica a mesma regra a vários serviços.

### 10. Agendador de tarefas (Task Scheduler)

Cria scripts em `C:\ProgramData\Scripts` e registra tarefas executadas como `SYSTEM`
no boot:

- `New-ScheduledTaskAction`: define o comando (`PowerShell.exe` com `-NoProfile`,
  `-ExecutionPolicy Bypass` e `-File`).
- `New-ScheduledTaskTrigger -AtStartup`: dispara a tarefa na inicialização.
- `New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest`: executa com a conta
  de sistema e privilégio máximo.
- `Register-ScheduledTask`: registra a tarefa.
- `Unregister-ScheduledTask` / `Get-ScheduledTask`: remove ou consulta a tarefa.

A primeira tarefa monitora apenas o `klnagent`; a segunda percorre uma lista de serviços
e inicia os que estiverem parados.

### 11. Logs e eventos

- `Get-WinEvent -LogName System | Where-Object ...`: procura no log System erros que
  mencionem `klnagent`.

### 12. Hyper-V

- `Get-VM`: lista as VMs do host.
- `$vm = (Get-VM -Name "VM-Exemplo").Name`: obtém o nome de uma VM específica.
- `Start-VM`: liga a VM.
- `Restart-VM`: reinicia a VM.
- `Stop-VM`: desliga a VM de forma controlada.
- `Stop-VM -Force`: força o desligamento.
- `Get-VM | Select-Object MemoryAssigned, MemoryDemand, MemoryStatus`: exibe o consumo
  e o estado da memória.

Requer o módulo Hyper-V e privilégios administrativos.

### 13. Permissões e usuários

- `Get-Acl`: mostra a ACL (permissões) de uma pasta; `.Access` lista as entradas.
- `New-Object FileSystemAccessRule` + `Set-Acl`: adiciona uma permissão para usuário ou
  grupo. Tipos comuns: `FullControl`, `Modify`, `ReadAndExecute`, `ListDirectory`,
  `Read`, `Write`.
- `RemoveAccessRule` + `Set-Acl`: remove a permissão.
- `Get-LocalGroupMember`: lista os membros do grupo administrativo definido em
  `$GrupoAdmin`.

### 14. Windows Update

- `Microsoft.Update.Session` + `Search("IsInstalled=0")`: lista atualizações pendentes.
- `Get-WmiObject Win32_QuickFixEngineering`: lista atualizações já instaladas.
- `QueryHistory` + `ResultCode -eq 2`: mostra o histórico de atualizações instaladas
  com sucesso.
- `Install-WindowsUpdate -AcceptAll -IgnoreReboot`: instala atualizações sem reiniciar.
  Requer o módulo `PSWindowsUpdate`.

### 15. Linux (SSH/Plink)

- `$comandos`: lista de comandos remotos disponíveis.
- `$indice` + `$comandos[$indice]`: escolhe o comando a executar.
- `plink.exe -ssh ... -i chave.ppk`: executa o comando via SSH usando autenticação por
  chave. Não há senha em texto puro.
- `Start-Process plink.exe`: abre uma sessão interativa.

### 16. PowerShell 7 - Runspace fora de processo

- `Start-Process PWSH -NoExit -WindowStyle Hidden`: inicia um processo PowerShell 7
  oculto.
- `New-OutOfProcRunspace`: conecta-se ao processo usando `NamedPipeConnectionInfo`,
  carrega a tabela de tipos padrão, cria e abre o runspace.
- `$Host.PushRunspace($Runspace)`: anexa o runspace ao host atual.

## Pré-requisitos e compatibilidade

- Windows PowerShell 5.1 ou PowerShell 7+.
- WinRM habilitado para os comandos remotos.
- Módulos: Hyper-V, Veeam Backup & Replication, `PSWindowsUpdate`.
- PuTTY/Plink instalado para os comandos Linux.
- WinGet e/ou Chocolatey instalados para as seções de software.
- `Install-WindowsFeature` existe apenas em Windows Server.
- `Get-WmiObject` é legado e não existe no PowerShell 7; nesse caso, use o equivalente
  `Get-CimInstance`.
- Os caminhos de produtos (Veeam, Kaspersky, PRTG, PostgreSQL, PuTTY) devem ser
  ajustados conforme a instalação do ambiente.

## Segurança

- Nunca grave senhas em arquivos `.ps1`; use `Get-Credential` ou cofres de segredos.
- Prefira autenticação por chave SSH em vez de `-pw` no Plink.
- Mantenha `config.local.ps1` fora do Git; ele já está no `.gitignore`.
- Revise scripts baixados da internet (SpotX e Chocolatey) antes de executá-los.
- Aplique o princípio do menor privilégio e teste primeiro em ambiente de homologação.

## Publicando no Git

```bash
git init -b main
git add .
git commit -m "Scripts de administração sanitizados e organizados"
git remote add origin <URL_DO_REPOSITORIO>
git push -u origin main
```

Antes do commit, confirme que `config.local.ps1` não aparece em `git status`.
