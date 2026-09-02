<#
.SYNOPSIS
    Checks whether a PC game can safely receive a DLSS 5 / ReShade injection.
    Verifie si un jeu PC peut recevoir sans risque une injection DLSS 5 / ReShade.

.DESCRIPTION
    EN: Scans a game folder and reports: anti-cheat presence (EasyAntiCheat, BattlEye,
        Vanguard, Denuvo, nProtect, XignCode), graphics API, Microsoft Store packaging,
        write access, and which DLSS 5 injection mode applies. Read-only apart from a
        single temp file used to test write access.
    FR: Analyse un dossier de jeu et rapporte : presence d'anti-triche, API graphique,
        empaquetage Microsoft Store, droits d'ecriture, et le mode d'injection DLSS 5
        applicable. Lecture seule, hormis un fichier temporaire pour tester l'ecriture.

.PARAMETER Path
    Game folder. A folder picker opens if omitted.

.EXAMPLE
    .\Test-GameModdability.ps1 -Path "D:\SteamLibrary\steamapps\common\DEATH STRANDING"
#>

[CmdletBinding()]
param(
    [string] $Path,
    [ValidateSet('fr', 'en')] [string] $Language
)

$ErrorActionPreference = 'Stop'
if (-not $Language) { $Language = if ("$PSUICulture" -like 'fr*') { 'fr' } else { 'en' } }
$FR = $Language -eq 'fr'
function T { param($fr, $en) if ($FR) { $fr } else { $en } }

function Say  { param($m, $c = 'Gray') Write-Host $m -ForegroundColor $c }
function Head { param($m) Write-Host ''; Write-Host "  $m" -ForegroundColor Cyan; Write-Host ('  ' + ('-' * $m.Length)) -ForegroundColor DarkCyan }

# ------------------------------------------------------------------ signatures

$ANTICHEAT = @(
    @{ Name = 'EasyAntiCheat'; Sev = 'HIGH'
       Files = @('EasyAntiCheat.exe','EasyAntiCheat_EOS_Setup.exe','EasyAntiCheat_x64.dll','easyanticheat_x64.dll','start_protected_game.exe')
       Dirs  = @('EasyAntiCheat','EasyAntiCheat_EOS') }
    @{ Name = 'BattlEye'; Sev = 'HIGH'
       Files = @('BEService.exe','BEClient_x64.dll','BELauncher.exe'); Dirs = @('BattlEye','BE') }
    @{ Name = 'Riot Vanguard'; Sev = 'HIGH'
       Files = @('vgc.exe','vgk.sys','vgtray.exe'); Dirs = @('Riot Vanguard') }
    @{ Name = 'nProtect GameGuard'; Sev = 'HIGH'
       Files = @('GameGuard.des','npggNT.des'); Dirs = @('GameGuard') }
    @{ Name = 'XignCode3'; Sev = 'HIGH'
       Files = @('xhunter1.sys','xigncode3.dll'); Dirs = @('xigncode') }
    @{ Name = 'Denuvo Anti-Cheat'; Sev = 'HIGH'
       Files = @('denuvo-anti-cheat.sys','AntiCheatBootstrapper.exe'); Dirs = @('AntiCheat') }
    @{ Name = 'PunkBuster'; Sev = 'MED'
       Files = @('PnkBstrA.exe','PnkBstrB.exe'); Dirs = @('pb') }
)

$API_HINTS = @(
    @{ Api = 'DirectX 12'; Files = @('d3d12.dll','D3D12Core.dll') }
    @{ Api = 'DirectX 11'; Files = @('d3d11.dll') }
    @{ Api = 'Vulkan';     Files = @('vulkan-1.dll') }
    @{ Api = 'DirectX 9';  Files = @('d3d9.dll','d3dx9_43.dll') }
)

$UPSCALERS = @(
    @{ Name = 'DLSS (native)'; Mode = 'Direct';   Files = @('nvngx_dlss.dll','sl.dlss.dll','_nvngx.dll') }
    @{ Name = 'FSR 2/3';       Mode = 'OptiScaler'; Files = @('ffx_fsr2_api_x64.dll','amd_fidelityfx_dx12.dll','ffx_fsr3upscaler_x64.dll') }
    @{ Name = 'XeSS';          Mode = 'OptiScaler'; Files = @('libxess.dll') }
)

$STORE_MARKERS = @('appxmanifest.xml','MicrosoftGame.config','resources.pri')

# ------------------------------------------------------------------ folder

if (-not $Path) {
    Add-Type -AssemblyName System.Windows.Forms
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.Description = T "Selectionne le dossier du jeu" "Select the game folder"
    if ($d.ShowDialog() -ne 'OK') { return }
    $Path = $d.SelectedPath
}
if (-not (Test-Path $Path)) { Say (T "Dossier introuvable : $Path" "Folder not found: $Path") Red; return }
$Path = (Resolve-Path $Path).Path

Write-Host ''
Write-Host '  ==============================================================' -ForegroundColor DarkCyan
Write-Host (T "   Analyse de moddabilite - DLSS 5 / ReShade" "   Moddability check - DLSS 5 / ReShade") -ForegroundColor White
Write-Host '  ==============================================================' -ForegroundColor DarkCyan
Say "  $Path" DarkGray

$files = @()
try { $files = Get-ChildItem $Path -Recurse -File -Force -ErrorAction SilentlyContinue } catch {}
$dirs  = @()
try { $dirs = Get-ChildItem $Path -Recurse -Directory -Force -ErrorAction SilentlyContinue } catch {}
$fnames = @{}; $files | ForEach-Object { $fnames[$_.Name.ToLower()] = $_.FullName }
$dnames = @{}; $dirs  | ForEach-Object { $dnames[$_.Name.ToLower()] = $_.FullName }

Say (("  {0:N0} " -f $files.Count) + (T "fichiers analyses" "files scanned")) DarkGray

# ------------------------------------------------------------------ anti-cheat

Head (T "Anti-triche" "Anti-cheat")

$hits = @()
foreach ($ac in $ANTICHEAT) {
    $found = @()
    foreach ($f in $ac.Files) { if ($fnames.ContainsKey($f.ToLower())) { $found += $fnames[$f.ToLower()] } }
    foreach ($d in $ac.Dirs)  { if ($dnames.ContainsKey($d.ToLower())) { $found += $dnames[$d.ToLower()] } }
    if ($found.Count) { $hits += @{ Name = $ac.Name; Sev = $ac.Sev; Paths = ($found | Select-Object -Unique) } }
}

if ($hits.Count -eq 0) {
    Write-Host (T "  [OK]   Aucun anti-triche detecte" "  [OK]   No anti-cheat detected") -ForegroundColor Green
} else {
    foreach ($h in $hits) {
        Write-Host ("  [!!]   " + $h.Name + "  (" + $h.Sev + ")") -ForegroundColor Red
        $h.Paths | Select-Object -First 3 | ForEach-Object { Say ("         " + $_.Replace($Path, '.')) DarkGray }
    }
}

# ------------------------------------------------------------------ api

Head (T "API graphique" "Graphics API")
$apis = @()
foreach ($a in $API_HINTS) { foreach ($f in $a.Files) { if ($fnames.ContainsKey($f.ToLower()) -and $apis -notcontains $a.Api) { $apis += $a.Api } } }
$ue = $fnames.ContainsKey('ue4commandline.txt') -or ($dnames.Keys -match '^engine$')
if ($apis.Count) { $apis | ForEach-Object { Write-Host "  [OK]   $_" -ForegroundColor Green } }
else { Say (T "  Indeterminee (DLL systeme non embarquees - normal)" "  Undetermined (system DLLs not bundled - normal)") DarkGray }
if ($ue) { Say (T "  Moteur : Unreal Engine" "  Engine: Unreal Engine") DarkGray }

# ------------------------------------------------------------------ upscalers

# RTX Remix : cas particulier, l'integration est native, ReShade n'a rien a faire ici
$remix = $dnames.ContainsKey('.trex') -or $dnames.ContainsKey('rtx-remix') -or $fnames.ContainsKey('remix_nvngx.dll')
if ($remix) {
    Head (T "RTX Remix detecte" "RTX Remix detected")
    Write-Host (T "  [OK]   Runtime Remix present (.trex\)" "  [OK]   Remix runtime present (.trex\)") -ForegroundColor Green
    Write-Host ''
    Say (T "  DLSS 5 est integre nativement au runtime. Le fichier va dans :" "  DLSS 5 is natively integrated in the runtime. The file goes in:") White
    Say ("    " + (Join-Path $Path '.trex\nvngx_dlssnr.dll')) Yellow
    Write-Host ''
    Write-Host (T "  [!!]   N'utilise NI ReShade NI RenoDX NI un swapper ici." "  [!!]   Do NOT use ReShade, RenoDX or any swapper here.") -ForegroundColor Red
    Say (T "         Ils ecraseraient les DLL du runtime Remix et casseraient l'install." "         They would overwrite the Remix runtime DLLs and break the install.") DarkGray
    Write-Host ''
    Write-Host '  ==============================================================' -ForegroundColor DarkCyan
    Write-Host (T "   VERDICT : jeu RTX Remix - voie dediee, pas ReShade" "   VERDICT: RTX Remix game - dedicated path, not ReShade") -ForegroundColor Green
    Write-Host '  ==============================================================' -ForegroundColor DarkCyan
    Write-Host ''
    return
}

Head (T "Upscaler present -> mode DLSS 5" "Upscaler present -> DLSS 5 mode")
$mode = 'Feeder'
$modeWhy = T "aucun upscaler : profondeur et vecteurs de mouvement synthetiques" "no upscaler: synthetic depth and motion vectors"
foreach ($u in $UPSCALERS) {
    foreach ($f in $u.Files) {
        if ($fnames.ContainsKey($f.ToLower())) {
            Write-Host ("  [OK]   " + $u.Name + "  -> mode " + $u.Mode) -ForegroundColor Green
            if ($u.Mode -eq 'Direct') { $mode = 'Direct'; $modeWhy = T "donnees exactes du moteur, meilleure qualite" "exact engine data, best quality" }
            elseif ($mode -ne 'Direct') { $mode = 'OptiScaler'; $modeWhy = T "donnees reelles converties" "real data, converted" }
            break
        }
    }
}
Say ("  => " + $mode + "  (" + $modeWhy + ")") White

# ------------------------------------------------------------------ packaging + write

Head (T "Empaquetage et droits" "Packaging and permissions")
$store = $STORE_MARKERS | Where-Object { $fnames.ContainsKey($_.ToLower()) }
if ($store) {
    Write-Host (T "  [!]    Paquet Microsoft Store / MSIX" "  [!]    Microsoft Store / MSIX package") -ForegroundColor Yellow
    $store | ForEach-Object { Say "         $_" DarkGray }
} else {
    Write-Host (T "  [OK]   Installation classique" "  [OK]   Regular installation") -ForegroundColor Green
}

$canWrite = $false
try { $t = Join-Path $Path ("_w_" + [guid]::NewGuid().ToString('N') + ".tmp"); [IO.File]::WriteAllText($t, 'x'); [IO.File]::Delete($t); $canWrite = $true } catch {}
if ($canWrite) { Write-Host (T "  [OK]   Ecriture autorisee" "  [OK]   Write access granted") -ForegroundColor Green }
else { Write-Host (T "  [!!]   Ecriture refusee - injection impossible en l'etat" "  [!!]   Write denied - injection not possible as-is") -ForegroundColor Red }

# ------------------------------------------------------------------ verdict

Write-Host ''
Write-Host '  ==============================================================' -ForegroundColor DarkCyan
if ($hits.Count -gt 0) {
    Write-Host (T "   VERDICT : NE PAS INJECTER" "   VERDICT: DO NOT INJECT") -ForegroundColor Red
    Write-Host ''
    Say (T "   $($hits[0].Name) est present. Injecter ReShade ou un add-on DLSS 5" "   $($hits[0].Name) is present. Injecting ReShade or a DLSS 5 add-on") Yellow
    Say (T "   dans un processus surveille peut faire bannir ton compte, et" "   into a monitored process can get your account banned, and") Yellow
    Say (T "   le plus souvent l'anti-triche bloque simplement le lancement." "   more often the anti-cheat will simply block the game from starting.") Yellow
    Write-Host ''
    Say (T "   Choisis un jeu solo sans anti-triche : meme resultat a l'image," "   Pick a single-player game with no anti-cheat: same visual result,") DarkGray
    Say (T "   aucun risque." "   zero risk.") DarkGray
} elseif (-not $canWrite) {
    Write-Host (T "   VERDICT : BLOQUE (droits d'ecriture)" "   VERDICT: BLOCKED (write permissions)") -ForegroundColor Yellow
} else {
    Write-Host (T "   VERDICT : OK -> mode $mode" "   VERDICT: OK -> $mode mode") -ForegroundColor Green
    Write-Host ''
    Say (T "   Aucun anti-triche, ecriture possible. Tu peux injecter." "   No anti-cheat, write access available. You can inject.") DarkGray
}
Write-Host '  ==============================================================' -ForegroundColor DarkCyan
Write-Host ''
