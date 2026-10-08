# ==============================================================================
# Sincronizador de Datos de Producción (FTP -> Local) para OSPulso
# Descarga la carpeta ~/public_html/dat/ desde el servidor de producción
# hacia c:\xampp\htdocs\ospulso\dat\
# ==============================================================================

param(
    [string]$FtpServer = "ftp.ospulso.com",
    [int]$FtpPort = 21,
    [string]$FtpUser = "ospulso",
    [string]$RemoteDir = "public_html/dat",
    [string]$LocalDir = "$PSScriptRoot\dat",
    [switch]$SkipBackup,
    [switch]$ForceOverwrite
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   SINCRONIZADOR DE DATOS DE PRODUCCION (OSPULSO FTP)    " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Servidor: $($FtpServer):$($FtpPort)"
Write-Host " Usuario:  $FtpUser"
Write-Host " Origen:   /home/$FtpUser/$RemoteDir"
Write-Host " Destino:  $LocalDir"
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Solicitar contraseña de forma segura (sin mostrarla en pantalla)
$securePass = Read-Host -Prompt "Ingresa la contrasena de cPanel/FTP para '$FtpUser'" -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePass)
$PlainPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

if ([string]::IsNullOrWhiteSpace($PlainPass)) {
    Write-Host "Contrasena vacia. Operacion cancelada." -ForegroundColor Red
    exit 1
}

# 2. Respaldo local preventivo de dat/
if (-not $SkipBackup -and (Test-Path $LocalDir)) {
    $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
    $backupDir = "$PSScriptRoot\dat_backup_$timestamp"
    Write-Host "[+] Creando respaldo de seguridad local en: $backupDir ..." -ForegroundColor Yellow
    Copy-Item -Path $LocalDir -Destination $backupDir -Recurse -Force
    Write-Host "[OK] Respaldo creado correctamente." -ForegroundColor Green
}

# 3. Configuracion de conexion FTP
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
try {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]'Tls12,Tls13'
} catch {}

$global:totalDescargados = 0
$global:totalErrores = 0

function Sync-FtpFolder($remoteRelPath, $localSubPath) {
    if (-not (Test-Path $localSubPath)) {
        New-Item -ItemType Directory -Path $localSubPath -Force | Out-Null
    }

    $cleanRemote = $remoteRelPath.TrimEnd('/')
    $uriString = "ftp://$($FtpServer):$($FtpPort)/$cleanRemote/"

    Write-Host ""
    Write-Host "[*] Explorando: $cleanRemote ..." -ForegroundColor Cyan

    $lines = @()
    try {
        $req = [System.Net.FtpWebRequest]::Create($uriString)
        $req.Credentials = New-Object System.Net.NetworkCredential($FtpUser, $PlainPass)
        $req.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectoryDetails
        $req.UseBinary = $true
        $req.UsePassive = $true
        $req.KeepAlive = $false
        $req.Timeout = 15000

        $resp = $req.GetResponse()
        $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
        while (-not $reader.EndOfStream) {
            $line = $reader.ReadLine()
            if ($line) { $lines += $line }
        }
        $reader.Close()
        $resp.Close()
    } catch {
        Write-Host "    [!] Error al listar $cleanRemote : $($_.Exception.Message)" -ForegroundColor Red
        $global:totalErrores++
        return
    }

    foreach ($entry in $lines) {
        $entry = $entry.Trim()
        if ([string]::IsNullOrWhiteSpace($entry)) { continue }

        # Formato estandar UNIX: drwxr-xr-x ... nombre  O  -rw-r--r-- ... nombre
        $isDir = $entry.StartsWith("d")
        
        # Extraer nombre (ultimo elemento tras fecha/hora)
        $tokens = ($entry -split '\s+')
        if ($tokens.Count -lt 9) {
            $isDir = ($entry -match "<DIR>")
            $itemName = $tokens[-1]
        } else {
            $itemName = ($tokens[8..($tokens.Count - 1)] -join " ")
        }

        if ($itemName -eq "." -or $itemName -eq ".." -or $itemName -eq "backups") {
            continue
        }

        $subRemote = "$cleanRemote/$itemName"
        $subLocal = Join-Path $localSubPath $itemName

        if ($isDir) {
            Sync-FtpFolder $subRemote $subLocal
        } else {
            Write-Host "    -> Descargando: $itemName ... " -NoNewline
            try {
                $fileUrl = "ftp://$($FtpServer):$($FtpPort)/$subRemote"
                $fileReq = [System.Net.FtpWebRequest]::Create($fileUrl)
                $fileReq.Credentials = New-Object System.Net.NetworkCredential($FtpUser, $PlainPass)
                $fileReq.Method = [System.Net.WebRequestMethods+Ftp]::DownloadFile
                $fileReq.UseBinary = $true
                $fileReq.UsePassive = $true
                $fileReq.KeepAlive = $false
                $fileReq.Timeout = 20000

                $fileResp = $fileReq.GetResponse()
                $inStream = $fileResp.GetResponseStream()

                $memStream = New-Object System.IO.MemoryStream
                $inStream.CopyTo($memStream)
                $inStream.Close()
                $fileResp.Close()

                $downloadBytes = $memStream.ToArray()
                $memStream.Close()

                # Blindaje anti-vaciado: Proteger universalmente archivos .dat si el remoto está vacío o truncado
                $criticalFiles = @('negocios.dat', 'negocios_config.dat', 'perfiles.dat', 'usuarios.dat', 'estado_cuenta.dat', 'pacientes.dat', 'citas.dat', 'cotizaciones.dat', 'cotizaciones_items.dat', 'gastos.dat', 'historial_correos.dat', 'folios_recibos_privados.dat', 'folios_recibos_publicos.dat')
                if ((Test-Path $subLocal) -and (-not $ForceOverwrite)) {
                    $localSize = (Get-Item $subLocal).Length
                    $remoteSize = $downloadBytes.Length
                    
                    # 1. Regla universal: Archivo remoto vacío o solo con cabecera (<= 250 bytes) vs local con datos operativos
                    if ($itemName.EndsWith(".dat") -and $remoteSize -lt $localSize -and $remoteSize -le 250 -and $localSize -gt 250) {
                        Write-Host "SALTADO (PROTEGIDO: Remoto vacío/solo encabezado [$remoteSize B] vs Local con datos [$localSize B])" -ForegroundColor Yellow
                        continue
                    }
                    
                    # 2. Regla para tablas críticas: Pérdida masiva de más del 50% de volumen
                    if ($criticalFiles -contains $itemName -and $remoteSize -lt ($localSize * 0.5) -and $localSize -gt 300) {
                        Write-Host "SALTADO (PROTEGIDO: Alerta de reduccion de tamano critica en ${itemName} - Remoto [$remoteSize B] vs Local [$localSize B])" -ForegroundColor Yellow
                        continue
                    }
                }

                [System.IO.File]::WriteAllBytes($subLocal, $downloadBytes)
                Write-Host "OK ($($downloadBytes.Length) bytes)" -ForegroundColor Green
                $global:totalDescargados++
            } catch {
                Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
                $global:totalErrores++
            }
        }
    }
}

# 4. Iniciar sincronizacion recursiva
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Sync-FtpFolder $RemoteDir $LocalDir
$stopwatch.Stop()

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   SINCRONIZACION FINALIZADA                              " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Archivos descargados: $($global:totalDescargados)" -ForegroundColor Green
if ($global:totalErrores -gt 0) {
    Write-Host " Errores encontrados:  $($global:totalErrores)" -ForegroundColor Red
} else {
    Write-Host " Errores:              0" -ForegroundColor Green
}
Write-Host " Tiempo total:         $($stopwatch.Elapsed.TotalSeconds.ToString('F1')) segundos"
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
