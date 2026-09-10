$files = Get-ChildItem -Path dat\pacientes_privados__*.dat
foreach ($file in $files) {
    $clue = $file.Name -replace 'pacientes_privados__','' -replace '\.dat',''
    $targetDir = "dat\catalogos_CLUE\$clue"
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    }
    $dest = "$targetDir\pacientes_privados_$clue.dat"
    Move-Item -Path $file.FullName -Destination $dest -Force
}
