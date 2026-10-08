# ==============================================================================
# Sincronizador de Datos de Producción (FTP / FTPS -> Local) para OSPulso
# Descarga la carpeta ~/public_html/dat/ desde el servidor de producción
# hacia c:\xampp\htdocs\ospulso\dat\
# ==============================================================================

param(
    [string]$FtpServer = "ftp.ospulso.com",
    [int]$FtpPort = 21,
    [string]$FtpUser = "ospulso",
    [string]$RemoteDir = "",
    [string]$LocalDir = "$PSScriptRoot\dat",
    [switch]$UseSsl,
    [switch]$NoSsl,
    [switch]$SkipBackup,
    [switch]$ForceOverwrite
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   SINCRONIZADOR DE DATOS DE PRODUCCION (OSPULSO FTP)    " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Servidor: $($FtpServer):$($FtpPort)"
Write-Host " Destino:  $LocalDir"
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Confirmar o ingresar el usuario FTP
Write-Host "Usuario predeterminado: [$FtpUser]" -ForegroundColor Yellow
$userInput = Read-Host -Prompt "Presiona [ENTER] para '$FtpUser' o escribe otro usuario (ej: ospulso@ospulso.com)"
if (-not [string]::IsNullOrWhiteSpace($userInput)) {
    $FtpUser = $userInput.Trim()
}

# 2. Solicitar contraseña de forma segura (sin mostrarla en pantalla)
$securePass = Read-Host -Prompt "Ingresa la contrasena de cPanel/FTP para '$FtpUser'" -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePass)
$PlainPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

if ([string]::IsNullOrWhiteSpace($PlainPass)) {
    Write-Host "Contrasena vacia. Operacion cancelada." -ForegroundColor Red
    exit 1
}

# 3. Respaldo local preventivo de dat/
if (-not $SkipBackup -and (Test-Path $LocalDir)) {
    $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
    $backupDir = "$PSScriptRoot\dat_backup_$timestamp"
    Write-Host ""
    Write-Host "[+] Creando respaldo de seguridad local en: $backupDir ..." -ForegroundColor Yellow
    Copy-Item -Path $LocalDir -Destination $backupDir -Recurse -Force
    Write-Host "[OK] Respaldo creado correctamente." -ForegroundColor Green
}

# 4. Configuracion de protocolos SSL/TLS en .NET
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
try {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]'Tls12,Tls13'
} catch {}

# Determinar estrategia de SSL/TLS (FTPS explícito vs FTP plano)
$modesToTry = @()
if ($UseSsl) {
    $modesToTry = @($true)
} elseif ($NoSsl) {
    $modesToTry = @($false)
} else {
    # Por defecto probar FTPS (seguro) primero, luego FTP estándar
    $modesToTry = @($true, $false)
}

$activeSsl = $false
$connected = $false
$lastError = ""

Write-Host ""
Write-Host "[*] Verificando credenciales y conexion..." -ForegroundColor Cyan

foreach ($sslFlag in $modesToTry) {
    $sslName = if ($sslFlag) { "FTPS (TLS Cifrado)" } else { "FTP (Texto Plano)" }
    Write-Host "    -> Probando modo $sslName ..." -NoNewline
    try {
        $testUri = "ftp://$($FtpServer):$($FtpPort)/"
        $req = [System.Net.FtpWebRequest]::Create($testUri)
        $req.Credentials = New-Object System.Net.NetworkCredential($FtpUser, $PlainPass)
        $req.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectory
        $req.EnableSsl = $sslFlag
        $req.UseBinary = $true
        $req.UsePassive = $true
        $req.KeepAlive = $false
        $req.Timeout = 12000

        $resp = $req.GetResponse()
        $resp.Close()

        Write-Host " [OK]" -ForegroundColor Green
        $activeSsl = $sslFlag
        $connected = $true
        break
    } catch {
        $lastError = $_.Exception.Message
        Write-Host " [FALLO: $lastError]" -ForegroundColor Yellow
    }
}

if (-not $connected) {
    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Red
    Write-Host "   ERROR DE AUTENTICACION / CONEXION CON EL SERVIDOR      " -ForegroundColor Red
    Write-Host "==========================================================" -ForegroundColor Red
    Write-Host " Mensaje del servidor: $lastError" -ForegroundColor Red
    Write-Host ""
    Write-Host " DIAGNOSTICO Y GUIA DE SOLUCION:" -ForegroundColor Yellow
    Write-Host " 1. Si estas usando una cuenta creada en cPanel -> 'Cuentas de FTP':"
    Write-Host "    El usuario DEBE incluir '@ospulso.com'." -ForegroundColor Cyan
    Write-Host "    Ejemplo: ospulso@ospulso.com  o  admin@ospulso.com" -ForegroundColor Cyan
    Write-Host ""
    Write-Host " 2. Si estas usando el usuario principal de cPanel ('$FtpUser'):"
    Write-Host "    Asegurate de que la contrasena sea exactamente la del panel cPanel." -ForegroundColor Cyan
    Write-Host ""
    Write-Host " 3. Si hubo varios intentos fallidos, cPanel (cPHulk) podria haber"
    Write-Host "    bloqueado temporalmente la IP local por 5 a 15 minutos." -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Red
    exit 1
}

# 5. Deteccion automatica de la ruta remota
$candidatePaths = @()
if (-not [string]::IsNullOrWhiteSpace($RemoteDir)) {
    $candidatePaths += $RemoteDir.Trim('/')
} else {
    $candidatePaths += @("public_html/dat", "dat", "")
}

$detectedRemoteDir = ""
Write-Host ""
Write-Host "[*] Detectando ubicacion de la carpeta 'dat' remota..." -ForegroundColor Cyan

foreach ($cand in $candidatePaths) {
    $candUri = if ($cand -ne "") { "ftp://$($FtpServer):$($FtpPort)/$cand/" } else { "ftp://$($FtpServer):$($FtpPort)/" }
    try {
        $req = [System.Net.FtpWebRequest]::Create($candUri)
        $req.Credentials = New-Object System.Net.NetworkCredential($FtpUser, $PlainPass)
        $req.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectory
        $req.EnableSsl = $activeSsl
        $req.UseBinary = $true
        $req.UsePassive = $true
        $req.KeepAlive = $false
        $req.Timeout = 12000

        $resp = $req.GetResponse()
        $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
        $items = @()
        while (-not $reader.EndOfStream) {
            $items += $reader.ReadLine()
        }
        $reader.Close()
        $resp.Close()

        # Verificar si contiene tablas clinicas de dat (ej: usuarios.dat, pacientes.dat o carpetas)
        $hasDatFiles = $items | Where-Object { $_ -match "\.dat$" }
        if ($hasDatFiles.Count -gt 0) {
            $detectedRemoteDir = $cand
            $displayPath = if ($cand -eq "") { "/" } else { "/$cand" }
            Write-Host "    [OK] Carpeta detectada con $($hasDatFiles.Count) tablas .dat en: $displayPath" -ForegroundColor Green
            break
        }
    } catch {}
}

if ($detectedRemoteDir -eq "" -and $candidatePaths.Count -gt 0) {
    # Usar el primer candidato por defecto si no pudo validar
    $detectedRemoteDir = $candidatePaths[0]
}

Write-Host " Origen remoto final: $(if ($detectedRemoteDir -eq '') { '/' } else { '/' + $detectedRemoteDir })" -ForegroundColor Cyan

$global:totalDescargados = 0
$global:totalErrores = 0

function Sync-FtpFolder($remoteRelPath, $localSubPath) {
    if (-not (Test-Path $localSubPath)) {
        New-Item -ItemType Directory -Path $localSubPath -Force | Out-Null
    }

    $cleanRemote = $remoteRelPath.Trim('/')
    $uriString = if ($cleanRemote -ne "") { "ftp://$($FtpServer):$($FtpPort)/$cleanRemote/" } else { "ftp://$($FtpServer):$($FtpPort)/" }

    Write-Host ""
    Write-Host "[*] Explorando: $(if ($cleanRemote -eq '') { '/' } else { $cleanRemote }) ..." -ForegroundColor Cyan

    $lines = @()
    try {
        $req = [System.Net.FtpWebRequest]::Create($uriString)
        $req.Credentials = New-Object System.Net.NetworkCredential($FtpUser, $PlainPass)
        $req.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectoryDetails
        $req.EnableSsl = $activeSsl
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

        $subRemote = if ($cleanRemote -ne "") { "$cleanRemote/$itemName" } else { $itemName }
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
                $fileReq.EnableSsl = $activeSsl
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
                        Write-Host "SALTADO (PROTEGIDO: Remoto vacio/solo encabezado [$remoteSize B] vs Local con datos [$localSize B])" -ForegroundColor Yellow
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

# 6. Iniciar sincronizacion recursiva
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Sync-FtpFolder $detectedRemoteDir $LocalDir
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
