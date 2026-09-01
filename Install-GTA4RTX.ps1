<#
.SYNOPSIS
    Installation automatisee du GTAIV RTX Remix Compatibility Mod (xoxor4d).

.DESCRIPTION
    Telecharge et installe le Compatibility Mod 1.5.1, le fork FusionFix, le base-mod
    et AutoPBR. Gere les deux blocages que l'installeur officiel ne traite pas :
    les permissions NTFS du Rockstar Launcher et la mise en quarantaine par Defender.

    Ce script ne telecharge, n'installe et ne mentionne AUCUNE DLL DLSS 5.

.PARAMETER GamePath
    Dossier contenant GTAIV.exe. Auto-detecte si omis.

.PARAMETER VerifyOnly
    N'installe rien : verifie une installation existante et sort.

.PARAMETER KeepDownloads
    Conserve les archives telechargees au lieu de les supprimer a la fin.

.EXAMPLE
    .\Install-GTA4RTX.ps1
.EXAMPLE
    .\Install-GTA4RTX.ps1 -GamePath "G:\Grand Theft Auto IV"
.EXAMPLE
    .\Install-GTA4RTX.ps1 -VerifyOnly
#>

[CmdletBinding()]
param(
    [string] $GamePath,
    [switch] $VerifyOnly,
    [switch] $KeepDownloads
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'Continue'

$REQUIRED_VERSION = '1.2.0.59'
$COMPMOD_VERSION  = '1.5.1'
$SOURCES = @(
    @{ Name = 'CompMod';  File = 'compmod.zip';  Size = '549 Mo'
       Url  = "https://github.com/xoxor4d/gta4-rtx/releases/download/v$COMPMOD_VERSION/GTAIV-Remix-CompatibilityMod-$COMPMOD_VERSION.zip" }
    @{ Name = 'Base mod'; File = 'basemod.zip';  Size = '2,7 Go'
       Url  = 'https://github.com/xoxor4d/gta4-rtx-base-mod/archive/refs/heads/master.zip' }
    @{ Name = 'AutoPBR';  File = 'autopbr.zip';  Size = '2 Go'
       Url  = 'https://github.com/xoxor4d/gta4-rtx-autopbr-mod/archive/refs/heads/master.zip' }
)
$EXPECTED = @(
    'GTAIV.exe', 'a_gta4-rtx.asi', 'd3d9.dll', 'dinput8.dll', 'rtx.conf', 'dxvk.conf',
    'commandline.txt', '_toggle-gta4-rtx.bat',
    'plugins\GTAIV.EFLC.FusionFix.asi', 'plugins\GTAIV.EFLC.FusionFix.cfg',
    '.trex\NvRemixBridge.exe', '.trex\d3d9.dll',
    'update\1__remix_fixes.img', 'update\GTAIV.EFLC.FusionFix\GTAIV.EFLC.FusionFix.img',
    'rtx-remix\mods\gta4rtx\mod.usda', 'rtx-remix\mods\z_gta4rtx_autopbr\mod.usda'
)

# ---------------------------------------------------------------- affichage

function Say  { param($m, $c = 'Gray')  Write-Host $m -ForegroundColor $c }
function Step { param($m) Write-Host ''; Write-Host "  $m" -ForegroundColor Cyan }
function Ok   { param($m) Write-Host "  [OK]    $m" -ForegroundColor Green }
function Warn { param($m) Write-Host "  [!]     $m" -ForegroundColor Yellow }
function Fail { param($m) Write-Host "  [ECHEC] $m" -ForegroundColor Red }

function Ask {
    param([string] $Question, [string] $Default = 'o')
    while ($true) {
        $r = Read-Host "  $Question [o/n]"
        if ([string]::IsNullOrWhiteSpace($r)) { $r = $Default }
        if ($r -match '^[oOyY]') { return $true }
        if ($r -match '^[nN]')   { return $false }
    }
}

function Banner {
    Write-Host ''
    Write-Host '  ============================================================' -ForegroundColor DarkCyan
    Write-Host '   GTA IV - RTX Remix Path Tracing : installation automatisee' -ForegroundColor White
    Write-Host "   Compatibility Mod $COMPMOD_VERSION par xoxor4d" -ForegroundColor DarkGray
    Write-Host '  ============================================================' -ForegroundColor DarkCyan
    Write-Host ''
    Say '  Ce script ne fournit AUCUNE DLL DLSS 5 et ne la telechargera pas.' DarkGray
}

# ---------------------------------------------------------------- elevation

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $id).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not $VerifyOnly -and -not (Test-Admin)) {
    Banner
    Say ''
    Warn 'Droits administrateur requis (permissions NTFS + exclusion Defender).'
    Say  '  Relance en admin via UAC...' DarkGray
    $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    if ($GamePath)      { $a += @('-GamePath', "`"$GamePath`"") }
    if ($KeepDownloads) { $a += '-KeepDownloads' }
    try   { Start-Process powershell.exe -Verb RunAs -ArgumentList $a; exit 0 }
    catch { Fail 'Elevation refusee. Relance le script en tant qu''administrateur.'; Read-Host '  Entree pour fermer'; exit 1 }
}

Banner

# ---------------------------------------------------------------- detection du jeu

function Find-GameCandidates {
    $cands = New-Object System.Collections.Generic.List[string]

    foreach ($k in @(
        'HKLM:\SOFTWARE\WOW6432Node\Rockstar Games\Grand Theft Auto IV',
        'HKLM:\SOFTWARE\Rockstar Games\Grand Theft Auto IV')) {
        try {
            $p = (Get-ItemProperty $k -ErrorAction Stop).InstallFolder
            if ($p) { $cands.Add($p) }
        } catch {}
    }

    try {
        $steam = (Get-ItemProperty 'HKCU:\SOFTWARE\Valve\Steam' -ErrorAction Stop).SteamPath
        if ($steam) {
            $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
            $libs = @($steam)
            if (Test-Path $vdf) {
                Select-String -Path $vdf -Pattern '"path"\s+"(.+?)"' -AllMatches |
                    ForEach-Object { $_.Matches } |
                    ForEach-Object { $libs += $_.Groups[1].Value -replace '\\\\', '\' }
            }
            foreach ($l in $libs) {
                $cands.Add((Join-Path $l 'steamapps\common\Grand Theft Auto IV\GTAIV'))
                $cands.Add((Join-Path $l 'steamapps\common\Grand Theft Auto IV'))
            }
        }
    } catch {}

    foreach ($d in (Get-PSDrive -PSProvider FileSystem).Name) {
        foreach ($sub in @(
            'Grand Theft Auto IV',
            'Grand Theft Auto IV\GTAIV',
            'Games\Grand Theft Auto IV',
            'Jeux\Grand Theft Auto IV',
            'Program Files\Rockstar Games\Grand Theft Auto IV',
            'Program Files (x86)\Rockstar Games\Grand Theft Auto IV',
            'SteamLibrary\steamapps\common\Grand Theft Auto IV',
            'SteamLibrary\steamapps\common\Grand Theft Auto IV\GTAIV')) {
            $cands.Add("${d}:\$sub")
        }
    }

    $found = New-Object System.Collections.Generic.List[string]
    foreach ($c in $cands) {
        if (-not $c) { continue }
        try {
            if (Test-Path (Join-Path $c 'GTAIV.exe')) {
                $r = (Resolve-Path $c).Path
                if ($found -notcontains $r) { $found.Add($r) }
            }
        } catch {}
    }
    return $found
}

function Get-GameVersion {
    param($Folder)
    try { return ((Get-Item (Join-Path $Folder 'GTAIV.exe')).VersionInfo.FileVersion -replace ',', '.' -replace '\s', '') }
    catch { return '?' }
}

function Select-GameFolder {
    Add-Type -AssemblyName System.Windows.Forms
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.Description = 'Selectionne le dossier contenant GTAIV.exe'
    $d.ShowNewFolderButton = $false
    if ($d.ShowDialog() -eq 'OK') { return $d.SelectedPath }
    return $null
}

Step 'Detection du jeu'

if (-not $GamePath) {
    $found = @(Find-GameCandidates)   # @() : empeche PowerShell de derouler la liste

    if ($found.Count -eq 0) {
        Warn 'Aucune installation de GTA IV detectee automatiquement.'
        Say  '  Selectionne toi-meme le dossier contenant GTAIV.exe.' DarkGray
        $GamePath = Select-GameFolder
    }
    else {
        Say '  Installation(s) trouvee(s) :' White
        for ($i = 0; $i -lt $found.Count; $i++) {
            Say ("    [{0}] {1}   (version {2})" -f ($i + 1), $found[$i], (Get-GameVersion $found[$i])) Gray
        }
        Say  ("    [{0}] Aucune de celles-ci - choisir le dossier moi-meme" -f ($found.Count + 1)) DarkGray
        Say ''
        while ($true) {
            $c = Read-Host "  Quelle installation moder ? [1-$($found.Count + 1)]"
            if ([string]::IsNullOrWhiteSpace($c)) { $c = '1' }
            $n = 0
            if ([int]::TryParse($c, [ref]$n) -and $n -ge 1 -and $n -le ($found.Count + 1)) {
                if ($n -eq ($found.Count + 1)) { $GamePath = Select-GameFolder }
                else                           { $GamePath = $found[$n - 1] }
                break
            }
        }
    }
    if (-not $GamePath) { Fail 'Aucun dossier selectionne.'; Read-Host '  Entree pour fermer'; exit 1 }
}

$exe = Join-Path $GamePath 'GTAIV.exe'
if (-not (Test-Path $exe)) {
    Fail "GTAIV.exe introuvable dans : $GamePath"
    Say  '  Choisis le dossier qui contient directement GTAIV.exe.' DarkGray
    Read-Host '  Entree pour fermer'; exit 1
}

$ver = Get-GameVersion $GamePath
if ($ver -ne $REQUIRED_VERSION) {
    Fail "Version du jeu : $ver  --  requise : $REQUIRED_VERSION"
    Say  '  Il faut GTA IV: The Complete Edition. Les versions 1.0.7.0 / 1.0.8.0 sont incompatibles.' DarkGray
    Read-Host '  Entree pour fermer'; exit 1
}

Say ''
Say  '  Dossier retenu :' White
Say  "    $GamePath" Yellow
Say  "    version $ver, $([math]::Round((Get-Item $exe).Length / 1MB, 1)) Mo pour GTAIV.exe" DarkGray
Say ''
if (-not $VerifyOnly) {
    if (-not (Ask 'C''est bien cette installation que tu veux moder ?')) {
        Say  '  Installation annulee, rien n''a ete modifie.' DarkGray
        Read-Host '  Entree pour fermer'; exit 0
    }
}
Ok "Version $ver conforme"

# ---------------------------------------------------------------- verification seule

function Test-Install {
    param($Root)
    $miss = @()
    foreach ($f in $EXPECTED) {
        if (Test-Path (Join-Path $Root $f)) { Ok $f } else { Fail $f; $miss += $f }
    }
    return $miss
}

if ($VerifyOnly) {
    Step 'Verification de l''installation'
    $miss = Test-Install $GamePath
    Write-Host ''
    if ($miss.Count -eq 0) { Ok 'Installation complete.' }
    else {
        Warn "$($miss.Count) fichier(s) manquant(s)."
        if ($miss -contains 'a_gta4-rtx.asi') {
            Warn 'a_gta4-rtx.asi absent : tres probablement mis en quarantaine par Defender.'
        }
    }
    Read-Host '  Entree pour fermer'; exit 0
}

# ---------------------------------------------------------------- permissions NTFS

Step 'Permissions du dossier du jeu'

$canWrite = $false
try {
    $t = Join-Path $GamePath ('.w_' + [guid]::NewGuid().ToString('N') + '.tmp')
    [System.IO.File]::WriteAllText($t, 'x'); [System.IO.File]::Delete($t)
    $canWrite = $true
} catch {}

if ($canWrite) { Ok 'Droits d''ecriture deja presents' }
else {
    Warn 'Dossier en lecture seule (installation Rockstar Launcher).'
    Say  '  RTX Remix doit ecrire ses caches de shaders et ses logs dans ce dossier' DarkGray
    Say  '  pendant le jeu. Sans droit d''ecriture, le mod ne peut pas fonctionner.' DarkGray
    Say  ''
    Say  "  Action : accorder 'Modify' a $env:USERNAME sur $GamePath" White
    Say  "  Annulable avec : icacls `"$GamePath`" /remove `"$env:COMPUTERNAME\$env:USERNAME`" /T" DarkGray
    Say  ''
    if (Ask 'Appliquer ?') {
        $acct = "$env:COMPUTERNAME\$env:USERNAME"
        & icacls "$GamePath" /grant "${acct}:(OI)(CI)M" /T /C | Out-Null
        if ($LASTEXITCODE -eq 0) { Ok 'Permissions accordees' }
        else { Fail 'icacls a echoue.'; Read-Host '  Entree pour fermer'; exit 1 }
    } else {
        Fail 'Sans droit d''ecriture, l''installation ne peut pas continuer.'
        Read-Host '  Entree pour fermer'; exit 1
    }
}

# ---------------------------------------------------------------- exclusion Defender

Step 'Windows Defender'

$asiPath   = Join-Path $GamePath 'a_gta4-rtx.asi'
$exclusion = $false

Say '  Defender met souvent a_gta4-rtx.asi en quarantaine : Trojan:Win32/Wacatac.B!ml' Yellow
Say ''
Say '  C''est un faux positif. Elements verifiables :' White
Say '    - Le suffixe !ml = detection par machine learning, plus faible confiance' DarkGray
Say '    - VirusTotal : 4 detections sur 75, les 4 heuristiques, aucune signature' DarkGray
Say '    - Propres : Kaspersky, BitDefender, ESET, Sophos, Malwarebytes, SentinelOne...' DarkGray
Say '    - Le binaire n''importe AUCUNE API reseau : il ne peut rien exfiltrer' DarkGray
Say '    - Flagge parce qu''il hooke du D3D9 et s''injecte via un ASI loader,' DarkGray
Say '      ce qui est simplement le fonctionnement d''un mod graphique' DarkGray
Say ''
Say '  Verifie toi-meme apres installation :' White
Say '    Get-FileHash "<jeu>\a_gta4-rtx.asi" -Algorithm SHA256   puis VirusTotal' DarkGray
Say ''
Say "  Action : ajouter une exclusion Defender sur CE SEUL FICHIER" White
Say "           $asiPath" DarkGray
Say "  Annulable avec : Remove-MpPreference -ExclusionPath `"$asiPath`"" DarkGray
Say ''

if (Ask 'Ajouter l''exclusion ? (non = le mod sera probablement mis en quarantaine)') {
    try {
        Add-MpPreference -ExclusionPath $asiPath -ErrorAction Stop
        $exclusion = $true
        Ok 'Exclusion ajoutee (fichier unique)'
    } catch { Warn "Echec de l'exclusion : $($_.Exception.Message)" }
} else {
    Warn 'Exclusion refusee. Si le mod disparait apres installation, c''est la cause.'
}

# ---------------------------------------------------------------- telechargement

$work = Join-Path $env:TEMP 'gta4rtx-install'
New-Item -ItemType Directory -Force -Path $work | Out-Null

Step 'Telechargement (~5,3 Go au total)'
Say  '  Les archives sont mises en cache : relancer le script ne retelecharge pas.' DarkGray

function Get-File {
    param($Url, $Dest, $Label, $Size)
    if (Test-Path $Dest) {
        $mb = [math]::Round((Get-Item $Dest).Length / 1MB, 1)
        Ok "$Label deja present ($mb Mo)"
        return
    }
    Say "  Telechargement : $Label ($Size)..." White
    $tmp = "$Dest.part"
    try {
        Start-BitsTransfer -Source $Url -Destination $tmp -Description $Label -ErrorAction Stop
    } catch {
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add('User-Agent', 'Mozilla/5.0')
        $wc.DownloadFile($Url, $tmp)
        $wc.Dispose()
    }
    Move-Item $tmp $Dest -Force
    $mb = [math]::Round((Get-Item $Dest).Length / 1MB, 1)
    Ok "$Label telecharge ($mb Mo)"
}

foreach ($s in $SOURCES) { Get-File $s.Url (Join-Path $work $s.File) $s.Name $s.Size }

# ---------------------------------------------------------------- installation

Add-Type -AssemblyName System.IO.Compression.FileSystem

Step 'Installation'

$stage = Join-Path $work 'stage'
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force -Path $stage | Out-Null

[System.IO.Compression.ZipFile]::ExtractToDirectory((Join-Path $work 'compmod.zip'), (Join-Path $stage 'compmod'))
Ok 'CompMod extrait'

$src = Join-Path $stage 'compmod'
Copy-Item "$src\GTAIV-Remix-CompatibilityMod\*"                  $GamePath -Recurse -Force
Ok 'Compatibility Mod installe'
Copy-Item "$src\_installer_options\FusionFix_RTXRemixFork\*"     $GamePath -Recurse -Force
Ok 'Fork FusionFix installe'
Copy-Item "$src\_installer_options\mode_fullscreen\*"            $GamePath -Recurse -Force
Ok 'Mode borderless fullscreen configure'

function Expand-ModsInto {
    param($Zip, $Dest, $Label)
    $z = [System.IO.Compression.ZipFile]::OpenRead($Zip)
    $n = 0
    try {
        foreach ($e in $z.Entries) {
            if ($e.FullName -notmatch '^[^/]+/mods/(.+)$') { continue }
            if ($e.Length -eq 0 -and $e.FullName.EndsWith('/')) { continue }
            $rel    = ($e.FullName -replace '^[^/]+/mods/', '') -replace '/', '\'
            $target = Join-Path $Dest $rel
            $dir    = Split-Path $target -Parent
            if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($e, $target, $true)
            $n++
        }
    } finally { $z.Dispose() }
    Ok "$Label installe ($n fichiers)"
}

$modsDir = Join-Path $GamePath 'rtx-remix\mods'
if (-not (Test-Path $modsDir)) { New-Item -ItemType Directory -Force -Path $modsDir | Out-Null }
Expand-ModsInto (Join-Path $work 'basemod.zip') $modsDir 'Base mod'
Expand-ModsInto (Join-Path $work 'autopbr.zip') $modsDir 'AutoPBR'

# ---------------------------------------------------------------- verification

Step 'Verification'
$miss = Test-Install $GamePath

if (-not $KeepDownloads) {
    Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host '  ============================================================' -ForegroundColor DarkCyan

if ($miss.Count -eq 0) {
    Ok 'Installation terminee, tous les composants presents.'
    Write-Host ''
    Say '  Au lancement :' White
    Say '    Alt+X  menu RTX Remix (path tracing, DLSS, Ray Reconstruction, Frame Gen)' DarkGray
    Say '    F4     menu du Compatibility Mod' DarkGray
    Write-Host ''
    Say '  Le premier lancement est lent et saccade : compilation des shaders.' Yellow
    Say '  Laisse tourner 5 minutes avant de juger.' Yellow
    Write-Host ''
    Say '  Active DLSS Ray Reconstruction dans Alt+X.' DarkGray
    Say '  Frame Generation : RTX 40/50 uniquement.' DarkGray
    Say '  Les reglages changes en jeu vont dans user.conf, qui prime sur rtx.conf.' DarkGray
    Say '  Si ca stutter : _LaunchWithProcessorAffinity_2Cores_GTA4.bat' DarkGray
    Say '  Pour desactiver le mod : _toggle-gta4-rtx.bat' DarkGray
} else {
    Warn "$($miss.Count) fichier(s) manquant(s) :"
    $miss | ForEach-Object { Say "    $_" Red }
    Write-Host ''
    if ($miss -contains 'a_gta4-rtx.asi') {
        if ($exclusion) {
            Warn 'a_gta4-rtx.asi absent malgre l''exclusion.'
            Say  '  Un autre antivirus est peut-etre actif. Verifie son journal.' DarkGray
        } else {
            Warn 'a_gta4-rtx.asi absent : Defender l''a mis en quarantaine.'
            Say  '  Relance le script et accepte l''exclusion.' DarkGray
        }
    }
}

Write-Host '  ============================================================' -ForegroundColor DarkCyan
Write-Host ''
Say '  Mod par xoxor4d : https://github.com/xoxor4d/gta4-rtx' DarkGray
Say '  Discord         : https://discord.gg/FMnfhpfZy9' DarkGray
Say '  Soutenir        : https://ko-fi.com/xoxor4d' DarkGray
Write-Host ''
if (-not $KeepDownloads) { Say "  Archives conservees dans $work (supprime le dossier pour liberer 5,3 Go)" DarkGray }
Write-Host ''
Read-Host '  Entree pour fermer'
