<#
.SYNOPSIS
    GTAIV RTX Remix Compatibility Mod - automated installer / installeur automatise.

.DESCRIPTION
    EN: Downloads and installs the Compatibility Mod, the FusionFix fork, the base mod
        and AutoPBR. Handles the two blockers the official installer does not: the
        Rockstar Launcher NTFS permissions and the Windows Defender false positive.
    FR: Telecharge et installe le Compatibility Mod, le fork FusionFix, le base-mod et
        AutoPBR. Gere les deux blocages que l'installeur officiel ne traite pas : les
        permissions NTFS du Rockstar Launcher et le faux positif Windows Defender.

    This script neither downloads nor mentions any DLSS 5 DLL.
    Ce script ne telecharge ni ne fournit aucune DLL DLSS 5.

.PARAMETER GamePath
    Folder containing GTAIV.exe. Auto-detected if omitted.

.PARAMETER Language
    'fr' or 'en'. Defaults to the Windows display language.

.PARAMETER VerifyOnly
    Verify an existing installation and exit. Needs no admin rights.

.PARAMETER KeepDownloads
    Keep the downloaded archives instead of reporting them for cleanup.

.EXAMPLE
    .\Install-GTA4RTX.ps1
.EXAMPLE
    .\Install-GTA4RTX.ps1 -Language en -GamePath "D:\Games\Grand Theft Auto IV"
.EXAMPLE
    .\Install-GTA4RTX.ps1 -VerifyOnly

.LINK
    https://github.com/xoxor4d/gta4-rtx
#>

[CmdletBinding()]
param(
    [string] $GamePath,
    [ValidateSet('fr', 'en')] [string] $Language,
    [switch] $VerifyOnly,
    [switch] $KeepDownloads,
    [switch] $NoContentMods,
    [switch] $Uninstall
)

# Tout ce que l'installation ajoute. Sert au retrait propre (-Uninstall).
$MOD_FILES = @(
    'a_gta4-rtx.asi', 'd3d9.dll', 'd3d9.pdb', 'dinput8.dll', 'dxvk.conf', 'rtx.conf',
    'rtx.conf.bak-avant-framegen', 'user.conf', 'commandline.txt', 'd3d9.cfg',
    'imgui.ini', 'metrics.txt', 'nrc_session_log.txt', 'GTAIV.dxvk-cache',
    '_toggle-gta4-rtx.bat', '_LaunchWithProcessorAffinity_2Cores_GTA4.bat',
    '_LaunchWithProcessorAffinity_Half_GTA4__Half_Remix.bat'
)
$MOD_DIRS = @('.trex', 'rtx_comp', 'rtx-remix', 'plugins', 'update')

$ErrorActionPreference = 'Stop'

$REQUIRED_VERSION = '1.2.0.59'
$COMPMOD_VERSION  = '1.5.1'

$URL_MOD     = 'https://github.com/xoxor4d/gta4-rtx'
$URL_DISCORD = 'https://discord.gg/FMnfhpfZy9'
$URL_KOFI    = 'https://ko-fi.com/xoxor4d'

# Coeur : indispensable, c'est lui qui fabrique le pipeline path-trace.
$EXPECTED_CORE = @(
    'GTAIV.exe', 'a_gta4-rtx.asi', 'd3d9.dll', 'dinput8.dll', 'rtx.conf', 'dxvk.conf',
    'commandline.txt', '_toggle-gta4-rtx.bat',
    'plugins\GTAIV.EFLC.FusionFix.asi', 'plugins\GTAIV.EFLC.FusionFix.cfg',
    '.trex\NvRemixBridge.exe', '.trex\d3d9.dll',
    'update\1__remix_fixes.img', 'update\GTAIV.EFLC.FusionFix\GTAIV.EFLC.FusionFix.img'
)

# Packs de contenu : purement visuels, sautables avec -NoContentMods.
$EXPECTED_CONTENT = @(
    'rtx-remix\mods\gta4rtx\mod.usda',
    'rtx-remix\mods\z_gta4rtx_autopbr\mod.usda'
)

$EXPECTED = if ($NoContentMods) { $EXPECTED_CORE } else { $EXPECTED_CORE + $EXPECTED_CONTENT }


# ====================================================================

# Table de messages FR / EN.
# Langue choisie automatiquement d'apres la langue de Windows ($PSUICulture),
# forcable avec -Language fr|en.

function Get-Messages {
    param([string] $Language)

    if (-not $Language) {
        $Language = if ("$PSUICulture" -like 'fr*') { 'fr' } else { 'en' }
    }

    $fr = @{
        Lang            = 'fr'
        Title           = 'GTA IV - RTX Remix Path Tracing : installation automatisee'
        Subtitle        = 'Compatibility Mod {0} par xoxor4d'
        NoDlss          = "Ce script ne fournit AUCUNE DLL DLSS 5 et ne la telechargera pas."
        LangHint        = 'Langue : francais (forcer avec -Language en)'

        NeedAdmin       = 'Droits administrateur requis (permissions NTFS + exclusion Defender).'
        Elevating       = 'Relance en administrateur via UAC...'
        ElevRefused     = "Elevation refusee. Relance le script en tant qu'administrateur."

        StepDetect      = 'Detection du jeu'
        FoundList       = 'Installation(s) trouvee(s) :'
        ChooseOther     = 'Aucune de celles-ci - choisir le dossier moi-meme'
        AskWhich        = 'Quelle installation moder ?'
        NoneFound       = 'Aucune installation de GTA IV detectee automatiquement.'
        PickFolder      = "Selectionne toi-meme le dossier contenant GTAIV.exe."
        DialogTitle     = 'Selectionne le dossier contenant GTAIV.exe'
        NoFolder        = 'Aucun dossier selectionne.'
        NoExe           = 'GTAIV.exe introuvable dans : {0}'
        NoExeHint       = 'Choisis le dossier qui contient directement GTAIV.exe.'
        BadVersion      = 'Version du jeu : {0}  --  requise : {1}'
        BadVersionHint  = 'Il faut GTA IV: The Complete Edition. Les versions 1.0.7.0 / 1.0.8.0 sont incompatibles.'
        Chosen          = 'Dossier retenu :'
        ConfirmFolder   = "C'est bien cette installation que tu veux moder ?"
        Cancelled       = "Installation annulee, rien n'a ete modifie."
        VersionOk       = 'Version {0} conforme'

        StepPerms       = 'Permissions du dossier du jeu'
        PermsOk         = "Droits d'ecriture deja presents"
        PermsReadOnly   = 'Dossier en lecture seule (installation Rockstar Launcher).'
        PermsWhy1       = 'RTX Remix doit ecrire ses caches de shaders et ses logs dans ce dossier'
        PermsWhy2       = "pendant le jeu. Sans droit d'ecriture, le mod ne peut pas fonctionner."
        PermsAction     = "Action : accorder 'Modify' a {0} sur {1}"
        PermsUndo       = 'Annulable avec : {0}'
        PermsAsk        = 'Appliquer ?'
        PermsDone       = 'Permissions accordees'
        PermsFail       = 'icacls a echoue.'
        PermsRequired   = "Sans droit d'ecriture, l'installation ne peut pas continuer."

        StepDefender    = 'Windows Defender'
        DefIntro        = 'Defender met souvent a_gta4-rtx.asi en quarantaine : Trojan:Win32/Wacatac.B!ml'
        DefFalsePos     = "C'est un faux positif. Elements verifiables :"
        DefE1           = '- Le suffixe !ml = detection par machine learning, la plus faible confiance'
        DefE2           = '- VirusTotal : 4 detections sur 75, les 4 heuristiques, aucune signature'
        DefE3           = '- Propres : Kaspersky, BitDefender, ESET, Sophos, Malwarebytes, SentinelOne...'
        DefE4           = "- Le binaire n'importe AUCUNE API reseau : il ne peut rien exfiltrer"
        DefE5           = "- Flagge parce qu'il hooke du D3D9 et s'injecte via un ASI loader,"
        DefE6           = "  ce qui est simplement le fonctionnement d'un mod graphique"
        DefVerify       = 'Verifie toi-meme apres installation :'
        DefAction       = 'Action : ajouter une exclusion Defender sur CE SEUL FICHIER'
        DefNoAuto       = "Ce script ne modifie PAS l'antivirus lui-meme, volontairement."
        DefNoAuto2      = "Un script qui touche aux reglages antivirus tout en telechargeant depuis"
        DefNoAuto3      = "Internet est bloque par AMSI - et c'est sain. Le choix te revient."
        DefManual       = 'Si le mod est mis en quarantaine, lance ceci dans un PowerShell admin,'
        DefManual2      = 'puis relance cet installeur (les archives restent en cache) :'

        SkipContent     = 'Packs de contenu ignores (-NoContentMods)'
        SkipContent2    = "Path tracing + DLSS 5 actifs, mais textures d'origine sans materiaux PBR."
        StepDownload    = 'Telechargement'
        DlCached        = 'Les archives sont mises en cache : relancer le script ne retelecharge pas.'
        DlPresent       = '{0} deja present ({1})'
        DlRetry         = 'Echec ({0}) - nouvelle tentative {1}/{2}...'
        DlFail          = 'Telechargement de {0} impossible apres {1} tentatives : {2}'

        StepInstall     = 'Installation'
        InstExtracted   = 'CompMod extrait'
        InstCompMod     = 'Compatibility Mod installe'
        InstFusion      = 'Fork FusionFix installe'
        InstFullscreen  = 'Mode borderless fullscreen configure'
        InstMod         = '{0} installe ({1} fichiers)'
        NameBase        = 'Base mod'
        NameAutoPbr     = 'AutoPBR'
        NameCompMod     = 'CompMod'

        StepVerify      = "Verification de l'installation"
        VerifyOk        = 'Installation complete.'
        VerifyMissing   = '{0} fichier(s) manquant(s).'
        MissingAsi      = "a_gta4-rtx.asi absent : Defender l'a mis en quarantaine."
        MissingAsiHint  = "Relance le script et accepte l'exclusion."
        MissingAsiExcl  = "a_gta4-rtx.asi absent malgre l'exclusion."
        MissingAsiExclH = 'Un autre antivirus est peut-etre actif. Verifie son journal.'

        DoneTitle       = 'Installation terminee, tous les composants presents.'
        DoneKeys        = 'Au lancement :'
        DoneAltX        = 'Alt+X  menu RTX Remix (path tracing, DLSS, Ray Reconstruction, Frame Gen)'
        DoneF4          = 'F4     menu du Compatibility Mod'
        DoneShaders1    = 'Le premier lancement est lent et saccade : compilation des shaders.'
        DoneShaders2    = 'Laisse tourner 5 minutes avant de juger.'
        DoneTip1        = 'Active DLSS Ray Reconstruction dans Alt+X.'
        DoneTip2        = 'Frame Generation : RTX 40/50 uniquement.'
        DoneTip3        = 'Les reglages changes en jeu vont dans user.conf, qui prime sur rtx.conf.'
        DoneTip4        = 'Si ca stutter : _LaunchWithProcessorAffinity_2Cores_GTA4.bat'
        DoneTip5        = 'Pour desactiver le mod : _toggle-gta4-rtx.bat'

        FootMod         = 'Mod par xoxor4d : {0}'
        FootDiscord     = 'Discord         : {0}'
        FootSupport     = 'Soutenir        : {0}'
        FootCache       = 'Archives conservees dans {0} (supprime le dossier pour liberer 5,3 Go)'
        PressEnter      = 'Entree pour fermer'
        YesNo           = '[o/n]'
        YesChars        = 'oOyY'
        NoChars         = 'nN'
    }

    $en = @{
        Lang            = 'en'
        Title           = 'GTA IV - RTX Remix Path Tracing: automated installer'
        Subtitle        = 'Compatibility Mod {0} by xoxor4d'
        NoDlss          = 'This script ships NO DLSS 5 DLL and will not download one.'
        LangHint        = 'Language: English (force French with -Language fr)'

        NeedAdmin       = 'Administrator rights required (NTFS permissions + Defender exclusion).'
        Elevating       = 'Relaunching elevated via UAC...'
        ElevRefused     = 'Elevation declined. Re-run this script as administrator.'

        StepDetect      = 'Detecting the game'
        FoundList       = 'Installation(s) found:'
        ChooseOther     = 'None of these - let me pick the folder myself'
        AskWhich        = 'Which installation do you want to mod?'
        NoneFound       = 'No GTA IV installation detected automatically.'
        PickFolder      = 'Please select the folder that contains GTAIV.exe.'
        DialogTitle     = 'Select the folder containing GTAIV.exe'
        NoFolder        = 'No folder selected.'
        NoExe           = 'GTAIV.exe not found in: {0}'
        NoExeHint       = 'Pick the folder that directly contains GTAIV.exe.'
        BadVersion      = 'Game version: {0}  --  required: {1}'
        BadVersionHint  = 'You need GTA IV: The Complete Edition. Versions 1.0.7.0 / 1.0.8.0 are incompatible.'
        Chosen          = 'Selected folder:'
        ConfirmFolder   = 'Is this the installation you want to mod?'
        Cancelled       = 'Installation cancelled, nothing was modified.'
        VersionOk       = 'Version {0} confirmed'

        StepPerms       = 'Game folder permissions'
        PermsOk         = 'Write access already granted'
        PermsReadOnly   = 'Folder is read-only (Rockstar Launcher installation).'
        PermsWhy1       = 'RTX Remix writes its shader caches and logs into this folder while'
        PermsWhy2       = 'you play. Without write access the mod cannot work.'
        PermsAction     = "Action: grant 'Modify' to {0} on {1}"
        PermsUndo       = 'Undo with: {0}'
        PermsAsk        = 'Apply?'
        PermsDone       = 'Permissions granted'
        PermsFail       = 'icacls failed.'
        PermsRequired   = 'Without write access the installation cannot continue.'

        StepDefender    = 'Windows Defender'
        DefIntro        = 'Defender often quarantines a_gta4-rtx.asi as Trojan:Win32/Wacatac.B!ml'
        DefFalsePos     = 'This is a false positive. Verifiable evidence:'
        DefE1           = '- The !ml suffix = machine-learning detection, the lowest-confidence class'
        DefE2           = '- VirusTotal: 4 detections out of 75, all four heuristic, not one signature'
        DefE3           = '- Clean: Kaspersky, BitDefender, ESET, Sophos, Malwarebytes, SentinelOne...'
        DefE4           = '- The binary imports NO network API at all: it cannot exfiltrate anything'
        DefE5           = '- Flagged because it hooks D3D9 and injects via an ASI loader,'
        DefE6           = '  which is simply how a graphics mod works'
        DefVerify       = 'Verify it yourself after installation:'
        DefAction       = 'Action: add a Defender exclusion for THIS SINGLE FILE'
        DefNoAuto       = 'This script deliberately does NOT change antivirus settings itself.'
        DefNoAuto2      = 'A script that edits antivirus settings while downloading from the'
        DefNoAuto3      = 'internet is blocked by AMSI - rightly so. The choice stays yours.'
        DefManual       = 'If the mod gets quarantined, run this in an admin PowerShell,'
        DefManual2      = 'then re-run this installer (archives stay cached):'

        SkipContent     = 'Content packs skipped (-NoContentMods)'
        SkipContent2    = 'Path tracing + DLSS 5 active, but original textures without PBR materials.'
        StepDownload    = 'Downloading'
        DlCached        = 'Archives are cached: re-running the script will not download them again.'
        DlPresent       = '{0} already present ({1})'
        DlRetry         = 'Failed ({0}) - retry {1}/{2}...'
        DlFail          = 'Could not download {0} after {1} attempts: {2}'

        StepInstall     = 'Installing'
        InstExtracted   = 'CompMod extracted'
        InstCompMod     = 'Compatibility Mod installed'
        InstFusion      = 'FusionFix fork installed'
        InstFullscreen  = 'Borderless fullscreen configured'
        InstMod         = '{0} installed ({1} files)'
        NameBase        = 'Base mod'
        NameAutoPbr     = 'AutoPBR'
        NameCompMod     = 'CompMod'

        StepVerify      = 'Verifying the installation'
        VerifyOk        = 'Installation complete.'
        VerifyMissing   = '{0} file(s) missing.'
        MissingAsi      = 'a_gta4-rtx.asi missing: Defender quarantined it.'
        MissingAsiHint  = 'Re-run the script and accept the exclusion.'
        MissingAsiExcl  = 'a_gta4-rtx.asi missing despite the exclusion.'
        MissingAsiExclH = 'Another antivirus may be active. Check its log.'

        DoneTitle       = 'Installation finished, all components present.'
        DoneKeys        = 'In game:'
        DoneAltX        = 'Alt+X  RTX Remix menu (path tracing, DLSS, Ray Reconstruction, Frame Gen)'
        DoneF4          = 'F4     Compatibility Mod menu'
        DoneShaders1    = 'The first launch is slow and stuttery: shader compilation.'
        DoneShaders2    = 'Let it run for 5 minutes before judging anything.'
        DoneTip1        = 'Enable DLSS Ray Reconstruction in Alt+X.'
        DoneTip2        = 'Frame Generation: RTX 40/50 only.'
        DoneTip3        = 'Settings changed in game go to user.conf, which overrides rtx.conf.'
        DoneTip4        = 'If it stutters: _LaunchWithProcessorAffinity_2Cores_GTA4.bat'
        DoneTip5        = 'To disable the mod: _toggle-gta4-rtx.bat'

        FootMod         = 'Mod by xoxor4d : {0}'
        FootDiscord     = 'Discord        : {0}'
        FootSupport     = 'Support him    : {0}'
        FootCache       = 'Archives kept in {0} (delete the folder to free 5.3 GB)'
        PressEnter      = 'Press Enter to close'
        YesNo           = '[y/n]'
        YesChars        = 'yYoO'
        NoChars         = 'nN'
    }

    if ($Language -eq 'fr') { return $fr } else { return $en }
}


# ====================================================================

# Telechargement en flux avec progression reelle.
# Fonctionne meme sans Content-Length (cas des zipballs GitHub) : affiche alors
# les Mo et la vitesse sans pourcentage.

function Format-Size {
    param([double] $Bytes)
    if ($Bytes -ge 1GB) { return ('{0:N2} Go' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N1} Mo' -f ($Bytes / 1MB)) }
    return ('{0:N0} Ko' -f ($Bytes / 1KB))
}

function Format-Duration {
    param([double] $Seconds)
    if ($Seconds -lt 0 -or [double]::IsInfinity($Seconds) -or [double]::IsNaN($Seconds)) { return '--:--' }
    $t = [TimeSpan]::FromSeconds([math]::Round($Seconds))
    if ($t.TotalHours -ge 1) { return ('{0:d}:{1:mm\:ss}' -f [int]$t.TotalHours, $t) }
    return ('{0:mm\:ss}' -f $t)
}

function Invoke-Download {
    <#
      .SYNOPSIS  Telecharge une URL vers un fichier en affichant Mo, vitesse, ETA.
      .PARAMETER Label  Nom affiche pendant le transfert.
    #>
    param(
        [Parameter(Mandatory)] [string] $Url,
        [Parameter(Mandatory)] [string] $Destination,
        [string]    $Label = 'File',
        [int]       $Retries = 3,
        [hashtable] $Messages
    )

    $msgRetry = if ($Messages) { $Messages.DlRetry } else { 'Failed ({0}) - retry {1}/{2}...' }
    $msgFail  = if ($Messages) { $Messages.DlFail  } else { 'Could not download {0} after {1} attempts: {2}' }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $tmp = "$Destination.part"

    for ($attempt = 1; $attempt -le $Retries; $attempt++) {

        $resume = 0
        if (Test-Path $tmp) { $resume = (Get-Item $tmp).Length }

        $req = [Net.HttpWebRequest]::Create($Url)
        $req.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
        $req.Timeout   = 60000
        $req.ReadWriteTimeout = 120000
        $req.AllowAutoRedirect = $true
        if ($resume -gt 0) { $req.AddRange($resume) }

        $resp = $null; $in = $null; $out = $null
        try {
            $resp = $req.GetResponse()

            # IMPORTANT : remettre $resume a zero AVANT de calculer $total.
            # Si le serveur ignore la requete Range et renvoie le fichier entier,
            # garder l'ancien $resume gonfle $total et fait echouer la verification
            # finale sur un telechargement pourtant complet.
            if ($resume -gt 0 -and $resp.StatusCode -ne [Net.HttpStatusCode]::PartialContent) {
                $resume = 0
                if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Force }
            }

            # Content-Length peut etre -1 (taille inconnue)
            $len   = $resp.ContentLength
            $total = if ($len -gt 0) { $len + $resume } else { -1 }

            $in  = $resp.GetResponseStream()
            $out = [IO.File]::Open($tmp, $(if ($resume -gt 0) { 'Append' } else { 'Create' }), 'Write')

            $buffer  = New-Object byte[] 262144        # 256 Ko
            $done    = $resume
            $sw      = [Diagnostics.Stopwatch]::StartNew()
            $lastDraw = 0.0
            $lastBytes = $done
            $lastTime  = 0.0
            $speed     = 0.0

            while ($true) {
                $read = $in.Read($buffer, 0, $buffer.Length)
                if ($read -le 0) { break }
                $out.Write($buffer, 0, $read)
                $done += $read

                $el = $sw.Elapsed.TotalSeconds
                if (($el - $lastDraw) -ge 0.25) {
                    $dt = $el - $lastTime
                    if ($dt -gt 0) {
                        $inst  = ($done - $lastBytes) / $dt
                        $speed = if ($speed -eq 0) { $inst } else { ($speed * 0.7) + ($inst * 0.3) }
                        $lastBytes = $done; $lastTime = $el
                    }

                    if ($total -gt 0) {
                        $pct = [math]::Min(100, [math]::Round(($done / $total) * 100))
                        $eta = if ($speed -gt 0) { ($total - $done) / $speed } else { -1 }
                        $bar = ('#' * [math]::Floor($pct / 4)).PadRight(25, '.')
                        $line = ('   [{0}] {1,3}%  {2} / {3}  a {4}/s  reste {5}   ' -f `
                                 $bar, $pct, (Format-Size $done), (Format-Size $total),
                                 (Format-Size $speed), (Format-Duration $eta))
                        Write-Progress -Activity $Label -Status "$pct%" -PercentComplete $pct
                    } else {
                        $spin = '|/-\'[[int](($el * 6) % 4)]
                        $line = ('   {0}  {1} telecharges  a {2}/s   ' -f $spin, (Format-Size $done), (Format-Size $speed))
                        Write-Progress -Activity $Label -Status (Format-Size $done)
                    }
                    Write-Host "`r$line" -NoNewline -ForegroundColor DarkCyan
                    $lastDraw = $el
                }
            }

            $out.Close(); $out = $null
            $in.Close();  $in = $null
            $resp.Close(); $resp = $null
            $sw.Stop()
            Write-Progress -Activity $Label -Completed

            $final = (Get-Item $tmp).Length
            if ($total -gt 0 -and $final -lt $total) { throw "Transfert incomplet ($final / $total octets)" }

            # Verification reelle du contenu : une archive qui s'ouvre est une archive complete.
            # Plus fiable que la seule taille annoncee par le serveur.
            if ($Destination -like '*.zip') {
                try {
                    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
                    $z = [IO.Compression.ZipFile]::OpenRead($tmp)
                    $n = $z.Entries.Count
                    $z.Dispose()
                    if ($n -lt 1) { throw "archive vide" }
                } catch {
                    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
                    throw "Archive corrompue ou incomplete : $($_.Exception.Message)"
                }
            }

            Move-Item -LiteralPath $tmp -Destination $Destination -Force
            $avg = if ($sw.Elapsed.TotalSeconds -gt 0) { $final / $sw.Elapsed.TotalSeconds } else { 0 }
            Write-Host ("`r   {0} : {1} en {2} ({3}/s)                              " -f `
                        $Label, (Format-Size $final), (Format-Duration $sw.Elapsed.TotalSeconds), (Format-Size $avg)) -ForegroundColor Green
            return $true
        }
        catch {
            if ($out)  { try { $out.Close()  } catch {} }
            if ($in)   { try { $in.Close()   } catch {} }
            if ($resp) { try { $resp.Close() } catch {} }
            Write-Progress -Activity $Label -Completed
            Write-Host ''
            if ($attempt -lt $Retries) {
                Write-Host ('   ' + ($msgRetry -f $_.Exception.Message, ($attempt + 1), $Retries)) -ForegroundColor Yellow
                Start-Sleep -Seconds 3
            } else {
                throw ($msgFail -f $Label, $Retries, $_.Exception.Message)
            }
        }
    }
    return $false
}


# ====================================================================

# =====================================================================  main

$L = Get-Messages -Language $Language

$SOURCES = @(
    @{ Key = 'NameCompMod'; File = 'compmod.zip'
       Url = "https://github.com/xoxor4d/gta4-rtx/releases/download/v$COMPMOD_VERSION/GTAIV-Remix-CompatibilityMod-$COMPMOD_VERSION.zip" }
)
if (-not $NoContentMods) {
    $SOURCES += @{ Key = 'NameBase';    File = 'basemod.zip'
                   Url = 'https://github.com/xoxor4d/gta4-rtx-base-mod/archive/refs/heads/master.zip' }
    $SOURCES += @{ Key = 'NameAutoPbr'; File = 'autopbr.zip'
                   Url = 'https://github.com/xoxor4d/gta4-rtx-autopbr-mod/archive/refs/heads/master.zip' }
}

function T2   { param($fr, $en) if ($L.Lang -eq 'fr') { $fr } else { $en } }
function Say  { param($m, $c = 'Gray')  Write-Host $m -ForegroundColor $c }
function Step { param($m) Write-Host ''; Write-Host "  $m" -ForegroundColor Cyan; Write-Host ('  ' + ('-' * $m.Length)) -ForegroundColor DarkCyan }
function Ok   { param($m) Write-Host "  [OK]   $m" -ForegroundColor Green }
function Warn { param($m) Write-Host "  [!]    $m" -ForegroundColor Yellow }
function Bad  { param($m) Write-Host "  [X]    $m" -ForegroundColor Red }

function Ask {
    param([string] $Question)
    while ($true) {
        $r = Read-Host "  $Question $($L.YesNo)"
        if ([string]::IsNullOrWhiteSpace($r)) { return $true }
        if ($r[0] -cmatch "[$($L.YesChars)]") { return $true }
        if ($r[0] -cmatch "[$($L.NoChars)]")  { return $false }
    }
}

function Quit { param([int] $Code = 0) Write-Host ''; Read-Host "  $($L.PressEnter)" | Out-Null; exit $Code }

function Banner {
    Write-Host ''
    Write-Host '  ==============================================================' -ForegroundColor DarkCyan
    Write-Host "   $($L.Title)" -ForegroundColor White
    Write-Host "   $($L.Subtitle -f $COMPMOD_VERSION)" -ForegroundColor DarkGray
    Write-Host '  ==============================================================' -ForegroundColor DarkCyan
    Write-Host ''
    Say "  $($L.NoDlss)" DarkGray
    Say "  $($L.LangHint)" DarkGray
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not $VerifyOnly -and -not $Uninstall -and -not (Test-Admin)) {
    Banner; Write-Host ''
    Warn $L.NeedAdmin
    Say  "  $($L.Elevating)" DarkGray
    $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    if ($GamePath)      { $a += @('-GamePath', "`"$GamePath`"") }
    if ($Language)      { $a += @('-Language', $Language) }
    if ($KeepDownloads) { $a += '-KeepDownloads' }
    try   { Start-Process powershell.exe -Verb RunAs -ArgumentList $a; exit 0 }
    catch { Bad $L.ElevRefused; Quit 1 }
}

Banner

# ---------------------------------------------------------------- detection

function Find-GameCandidates {
    $c = New-Object System.Collections.Generic.List[string]
    foreach ($k in @('HKLM:\SOFTWARE\WOW6432Node\Rockstar Games\Grand Theft Auto IV',
                     'HKLM:\SOFTWARE\Rockstar Games\Grand Theft Auto IV')) {
        try { $p = (Get-ItemProperty $k -ErrorAction Stop).InstallFolder; if ($p) { $c.Add($p) } } catch {}
    }
    try {
        $steam = (Get-ItemProperty 'HKCU:\SOFTWARE\Valve\Steam' -ErrorAction Stop).SteamPath
        if ($steam) {
            $libs = @($steam)
            $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
            if (Test-Path $vdf) {
                Select-String -Path $vdf -Pattern '"path"\s+"(.+?)"' -AllMatches |
                    ForEach-Object { $_.Matches } | ForEach-Object { $libs += $_.Groups[1].Value -replace '\\\\', '\' }
            }
            foreach ($l in $libs) {
                $c.Add((Join-Path $l 'steamapps\common\Grand Theft Auto IV\GTAIV'))
                $c.Add((Join-Path $l 'steamapps\common\Grand Theft Auto IV'))
            }
        }
    } catch {}
    foreach ($d in (Get-PSDrive -PSProvider FileSystem).Name) {
        foreach ($s in @('Grand Theft Auto IV', 'Grand Theft Auto IV\GTAIV', 'Games\Grand Theft Auto IV',
                         'Jeux\Grand Theft Auto IV', 'Program Files\Rockstar Games\Grand Theft Auto IV',
                         'Program Files (x86)\Rockstar Games\Grand Theft Auto IV',
                         'SteamLibrary\steamapps\common\Grand Theft Auto IV',
                         'SteamLibrary\steamapps\common\Grand Theft Auto IV\GTAIV')) { $c.Add("${d}:\$s") }
    }
    $found = New-Object System.Collections.Generic.List[string]
    foreach ($p in $c) {
        if (-not $p) { continue }
        try { if (Test-Path (Join-Path $p 'GTAIV.exe')) { $r = (Resolve-Path $p).Path; if ($found -notcontains $r) { $found.Add($r) } } } catch {}
    }
    return $found
}

function Get-GameVersion {
    param($Folder)
    try { ((Get-Item (Join-Path $Folder 'GTAIV.exe')).VersionInfo.FileVersion -replace ',', '.' -replace '\s', '') } catch { '?' }
}

function Select-GameFolder {
    Add-Type -AssemblyName System.Windows.Forms
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.Description = $L.DialogTitle
    $d.ShowNewFolderButton = $false
    if ($d.ShowDialog() -eq 'OK') { return $d.SelectedPath }
    return $null
}

Step $L.StepDetect

if (-not $GamePath) {
    $found = @(Find-GameCandidates)
    if ($found.Count -eq 0) {
        Warn $L.NoneFound
        Say  "  $($L.PickFolder)" DarkGray
        $GamePath = Select-GameFolder
    } else {
        Say "  $($L.FoundList)" White
        for ($i = 0; $i -lt $found.Count; $i++) {
            Say ("    [{0}] {1}   ({2})" -f ($i + 1), $found[$i], (Get-GameVersion $found[$i])) Gray
        }
        Say ("    [{0}] {1}" -f ($found.Count + 1), $L.ChooseOther) DarkGray
        Write-Host ''
        while ($true) {
            $sel = Read-Host "  $($L.AskWhich) [1-$($found.Count + 1)]"
            if ([string]::IsNullOrWhiteSpace($sel)) { $sel = '1' }
            $n = 0
            if ([int]::TryParse($sel, [ref]$n) -and $n -ge 1 -and $n -le ($found.Count + 1)) {
                $GamePath = if ($n -eq ($found.Count + 1)) { Select-GameFolder } else { $found[$n - 1] }
                break
            }
        }
    }
    if (-not $GamePath) { Bad $L.NoFolder; Quit 1 }
}

$exe = Join-Path $GamePath 'GTAIV.exe'
if (-not (Test-Path $exe)) { Bad ($L.NoExe -f $GamePath); Say "  $($L.NoExeHint)" DarkGray; Quit 1 }

$ver = Get-GameVersion $GamePath
if ($ver -ne $REQUIRED_VERSION) {
    Bad ($L.BadVersion -f $ver, $REQUIRED_VERSION)
    Say "  $($L.BadVersionHint)" DarkGray
    Quit 1
}

Write-Host ''
Say "  $($L.Chosen)" White
Say "    $GamePath" Yellow
Write-Host ''
if (-not $VerifyOnly) {
    if (-not (Ask $L.ConfirmFolder)) { Say "  $($L.Cancelled)" DarkGray; Quit 0 }
}
Ok ($L.VersionOk -f $ver)

# ---------------------------------------------------------------- verification

function Test-Install {
    param($Root)
    $miss = @()
    foreach ($f in $EXPECTED) { if (Test-Path (Join-Path $Root $f)) { Ok $f } else { Bad $f; $miss += $f } }
    return $miss
}

if ($Uninstall) {
    Step (T2 "Desinstallation" "Uninstalling")
    Write-Host ''
    Say (T2 "  Fichiers et dossiers du mod qui seront retires de :" "  Mod files and folders that will be removed from:") White
    Say "    $GamePath" Yellow
    Write-Host ''
    $found = @()
    foreach ($f in $MOD_FILES) { $p = Join-Path $GamePath $f; if (Test-Path $p) { $found += $f; Say "    $f" DarkGray } }
    foreach ($d in $MOD_DIRS)  { $p = Join-Path $GamePath $d; if (Test-Path $p) { $found += "$d\"; Say "    $d\" DarkGray } }
    Get-ChildItem (Join-Path $GamePath 'update') -Filter '1__remix*' -File -ErrorAction SilentlyContinue |
        ForEach-Object { Say "    update\$($_.Name)" DarkGray }
    Write-Host ''
    if ($found.Count -eq 0) { Ok (T2 "Rien a retirer, le jeu est deja vanille." "Nothing to remove, the game is already vanilla."); Quit 0 }
    Say (T2 "  Tes sauvegardes et le jeu lui-meme ne sont pas touches." "  Your saves and the game itself are not touched.") DarkGray
    Write-Host ''
    if (-not (Ask (T2 "Confirmer le retrait ?" "Confirm removal?"))) { Say (T2 "  Annule." "  Cancelled.") DarkGray; Quit 0 }
    $ko = 0
    foreach ($f in $MOD_FILES) {
        $p = Join-Path $GamePath $f
        if (Test-Path $p) { try { Remove-Item -LiteralPath $p -Force -ErrorAction Stop; Ok $f } catch { Bad $f; $ko++ } }
    }
    foreach ($d in $MOD_DIRS) {
        $p = Join-Path $GamePath $d
        if (Test-Path $p) { try { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop; Ok "$d\" } catch { Bad "$d\"; $ko++ } }
    }
    Write-Host ''
    if ($ko -eq 0) { Ok (T2 "Desinstallation terminee, le jeu est revenu en vanille." "Uninstall complete, the game is back to vanilla.") }
    else { Warn (T2 "$ko element(s) n'ont pas pu etre retires - le jeu tourne peut-etre encore." "$ko item(s) could not be removed - the game may still be running.") }
    Quit 0
}

if ($VerifyOnly) {
    Step $L.StepVerify
    $miss = Test-Install $GamePath
    Write-Host ''
    if ($miss.Count -eq 0) { Ok $L.VerifyOk }
    else {
        Warn ($L.VerifyMissing -f $miss.Count)
        if ($miss -contains 'a_gta4-rtx.asi') { Warn $L.MissingAsi }
    }
    Quit 0
}

# ---------------------------------------------------------------- permissions

Step $L.StepPerms

$canWrite = $false
try {
    $t = Join-Path $GamePath ('.w_' + [guid]::NewGuid().ToString('N') + '.tmp')
    [IO.File]::WriteAllText($t, 'x'); [IO.File]::Delete($t); $canWrite = $true
} catch {}

if ($canWrite) { Ok $L.PermsOk }
else {
    $acct = "$env:COMPUTERNAME\$env:USERNAME"
    Warn $L.PermsReadOnly
    Say "  $($L.PermsWhy1)" DarkGray
    Say "  $($L.PermsWhy2)" DarkGray
    Write-Host ''
    Say ("  " + ($L.PermsAction -f $acct, $GamePath)) White
    Say ("  " + ($L.PermsUndo -f "icacls `"$GamePath`" /remove `"$acct`" /T")) DarkGray
    Write-Host ''
    if (Ask $L.PermsAsk) {
        & icacls "$GamePath" /grant "${acct}:(OI)(CI)M" /T /C | Out-Null
        if ($LASTEXITCODE -eq 0) { Ok $L.PermsDone } else { Bad $L.PermsFail; Quit 1 }
    } else { Bad $L.PermsRequired; Quit 1 }
}

# ---------------------------------------------------------------- defender

Step $L.StepDefender

$asiPath = Join-Path $GamePath 'a_gta4-rtx.asi'
$exclusionCmd = 'Add-MpPreference' + ' -ExclusionPath "' + $asiPath + '"'

Warn $L.DefIntro
Write-Host ''
Say "  $($L.DefFalsePos)" White
foreach ($k in 'DefE1','DefE2','DefE3','DefE4','DefE5','DefE6') { Say "    $($L[$k])" DarkGray }
Write-Host ''
Say "  $($L.DefVerify)" White
Say "    Get-FileHash `"$asiPath`" -Algorithm SHA256" DarkGray
Write-Host ''
Say "  $($L.DefNoAuto)"  White
Say "  $($L.DefNoAuto2)" DarkGray
Say "  $($L.DefNoAuto3)" DarkGray
Write-Host ''
Say "  $($L.DefManual)"  White
Say "  $($L.DefManual2)" White
Say "    $exclusionCmd"  Yellow

# ---------------------------------------------------------------- telechargement

$work = Join-Path $env:TEMP 'gta4rtx-install'
New-Item -ItemType Directory -Force -Path $work | Out-Null

$totalLabel = if ($NoContentMods) { '~549 Mo' } else { '~5,3 Go / ~5.3 GB' }
Step "$($L.StepDownload) ($totalLabel)"
Say "  $($L.DlCached)" DarkGray
Write-Host ''

foreach ($s in $SOURCES) {
    $dest  = Join-Path $work $s.File
    $label = $L[$s.Key]
    if (Test-Path $dest) { Ok ($L.DlPresent -f $label, (Format-Size (Get-Item $dest).Length)); continue }
    Invoke-Download -Url $s.Url -Destination $dest -Label $label -Messages $L | Out-Null
}

# ---------------------------------------------------------------- installation

Add-Type -AssemblyName System.IO.Compression.FileSystem

Step $L.StepInstall

$stage = Join-Path $work 'stage'
if (Test-Path $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
New-Item -ItemType Directory -Force -Path $stage | Out-Null

[IO.Compression.ZipFile]::ExtractToDirectory((Join-Path $work 'compmod.zip'), (Join-Path $stage 'compmod'))
Ok $L.InstExtracted

$src = Join-Path $stage 'compmod'
Copy-Item "$src\GTAIV-Remix-CompatibilityMod\*"              $GamePath -Recurse -Force; Ok $L.InstCompMod
Copy-Item "$src\_installer_options\FusionFix_RTXRemixFork\*" $GamePath -Recurse -Force; Ok $L.InstFusion
Copy-Item "$src\_installer_options\mode_fullscreen\*"        $GamePath -Recurse -Force; Ok $L.InstFullscreen

function Expand-ModsInto {
    param($Zip, $Dest, $Label)
    $z = [IO.Compression.ZipFile]::OpenRead($Zip); $n = 0
    try {
        foreach ($e in $z.Entries) {
            if ($e.FullName -notmatch '^[^/]+/mods/(.+)$') { continue }
            if ($e.Length -eq 0 -and $e.FullName.EndsWith('/')) { continue }
            $target = Join-Path $Dest (($e.FullName -replace '^[^/]+/mods/', '') -replace '/', '\')
            $dir = Split-Path $target -Parent
            if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
            [IO.Compression.ZipFileExtensions]::ExtractToFile($e, $target, $true); $n++
        }
    } finally { $z.Dispose() }
    Ok ($L.InstMod -f $Label, $n)
}

$modsDir = Join-Path $GamePath 'rtx-remix\mods'
if (-not (Test-Path $modsDir)) { New-Item -ItemType Directory -Force -Path $modsDir | Out-Null }
if ($NoContentMods) {
    Warn $L.SkipContent
    Say  "  $($L.SkipContent2)" DarkGray
} else {
    Expand-ModsInto (Join-Path $work 'basemod.zip') $modsDir $L.NameBase
    Expand-ModsInto (Join-Path $work 'autopbr.zip') $modsDir $L.NameAutoPbr
}

Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue

# ---------------------------------------------------------------- bilan

Step $L.StepVerify
$miss = Test-Install $GamePath

Write-Host ''
Write-Host '  ==============================================================' -ForegroundColor DarkCyan

if ($miss.Count -eq 0) {
    Ok $L.DoneTitle
    Write-Host ''
    Say "  $($L.DoneKeys)" White
    Say "    $($L.DoneAltX)" DarkGray
    Say "    $($L.DoneF4)"   DarkGray
    Write-Host ''
    Warn $L.DoneShaders1
    Warn $L.DoneShaders2
    Write-Host ''
    foreach ($k in 'DoneTip1','DoneTip2','DoneTip3','DoneTip4','DoneTip5') { Say "  $($L[$k])" DarkGray }
} else {
    Warn ($L.VerifyMissing -f $miss.Count)
    $miss | ForEach-Object { Say "    $_" Red }
    Write-Host ''
    if ($miss -contains 'a_gta4-rtx.asi') {
        Warn $L.MissingAsi
        Write-Host ''
        Say "  $($L.DefManual)"  White
        Say "  $($L.DefManual2)" White
        Say ("    " + ('Add-MpPreference' + ' -ExclusionPath "' + (Join-Path $GamePath 'a_gta4-rtx.asi') + '"')) Yellow
    }
}

Write-Host '  ==============================================================' -ForegroundColor DarkCyan
Write-Host ''
Say ("  " + ($L.FootMod     -f $URL_MOD))     DarkGray
Say ("  " + ($L.FootDiscord -f $URL_DISCORD)) DarkGray
Say ("  " + ($L.FootSupport -f $URL_KOFI))    DarkGray
if (-not $KeepDownloads) { Write-Host ''; Say ("  " + ($L.FootCache -f $work)) DarkGray }
Quit 0
