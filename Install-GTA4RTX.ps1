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
    [switch] $Uninstall,
    [switch] $Console,
    [ValidateSet('full', 'min')] [string] $AutoInstall
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

# Table de messages EN / FR.
# Anglais par defaut. Francais avec -Language fr.

function Get-Messages {
    param([string] $Language)

    if (-not $Language) { $Language = 'en' }

    $fr = @{
        Lang            = 'fr'
        Title           = 'GTA IV - RTX Remix Path Tracing : installation automatisee'
        Subtitle        = 'Compatibility Mod {0} par xoxor4d'
        NoDlss          = "Ce script ne fournit AUCUNE DLL DLSS 5 et ne la telechargera pas."
        LangHint        = 'Langue : francais'

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
        LangHint        = 'Language: English (French with -Language fr)'

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

function Test-ResumeSupport {
    <#
      .SYNOPSIS  Le serveur accepte-t-il une reprise (HTTP Range) ?
      Les archives de branche GitHub (codeload) sont generees a la volee :
      elles repondent 200 a une requete Range au lieu de 206. Une coupure
      reseau oblige alors a tout recommencer -- il faut le dire clairement
      au lieu de relancer trois fois 3,5 Go dans le vide.
    #>
    param([Parameter(Mandatory)] [string] $Url)
    try {
        $r = [Net.HttpWebRequest]::Create($Url)
        $r.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
        $r.Timeout = 20000
        $r.AllowAutoRedirect = $true
        $r.AddRange(0, 1023)
        $resp = $r.GetResponse()
        $code = $resp.StatusCode
        $resp.Close()
        return ($code -eq [Net.HttpStatusCode]::PartialContent)
    } catch { return $false }
}

function Find-PreDownloaded {
    <#
      .SYNOPSIS  Cherche une archive deja telechargee a la main par l'utilisateur.
      Quand la reprise est impossible, telecharger dans un navigateur (qui, lui,
      sait reprendre) puis laisser le script ramasser le fichier est la seule
      voie fiable sur une connexion instable.
      .PARAMETER Names  Noms acceptes, du plus probable au moins probable.
    #>
    param(
        [Parameter(Mandatory)] [string[]] $Names,
        [long] $MinSize = 1MB
    )
    $dirs = @()
    if ($PSScriptRoot)   { $dirs += $PSScriptRoot }
    $dirs += (Join-Path $env:USERPROFILE 'Downloads')
    $dirs += (Join-Path $env:USERPROFILE 'Desktop')
    $dirs += (Join-Path $env:TEMP 'gta4rtx-install')
    foreach ($d in $dirs) {
        if (-not (Test-Path $d)) { continue }
        foreach ($n in $Names) {
            $p = Join-Path $d $n
            if (-not (Test-Path $p)) { continue }
            if ((Get-Item $p).Length -lt $MinSize) { continue }
            try {
                Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
                $z = [IO.Compression.ZipFile]::OpenRead($p)
                $c = $z.Entries.Count
                $z.Dispose()
                if ($c -gt 0) { return $p }
            } catch { }
        }
    }
    return $null
}

function Get-FreeSpaceGB {
    param([Parameter(Mandatory)] [string] $Path)
    try {
        $root = [IO.Path]::GetPathRoot((Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path)
        return ([double](Get-PSDrive -Name $root.Substring(0,1) -ErrorAction Stop).Free / 1GB)
    } catch { return -1 }
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
        [int]       $Retries = 5,
        [hashtable] $Messages
    )

    $msgRetry = if ($Messages) { $Messages.DlRetry } else { 'Failed ({0}) - retry {1}/{2}...' }
    $msgFail  = if ($Messages) { $Messages.DlFail  } else { 'Could not download {0} after {1} attempts: {2}' }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $tmp = "$Destination.part"

    # Une seule sonde : inutile de retenter une reprise que le serveur refuse.
    $canResume = Test-ResumeSupport -Url $Url
    if (-not $canResume) {
        Say (T2 ("  $Label : ce serveur ne gere pas la reprise -- une coupure = reprise a zero.") `
                ("  $Label : this server has no resume support -- a drop restarts from zero.")) DarkYellow
    }

    for ($attempt = 1; $attempt -le $Retries; $attempt++) {

        $resume = 0
        if ($canResume -and (Test-Path $tmp)) { $resume = (Get-Item $tmp).Length }
        elseif (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }

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
                    if ($script:GuiProgress) {
                        if ($total -gt 0) {
                            $script:GuiProgress.Style = 'Continuous'
                            $script:GuiProgress.Value = [math]::Min(100, [math]::Max(0, $pct))
                        } else { $script:GuiProgress.Style = 'Marquee' }
                        if ($script:GuiStatus) { $script:GuiStatus.Text = $line.Trim() }
                        [System.Windows.Forms.Application]::DoEvents()
                    } else {
                        Write-Host "`r$line" -NoNewline -ForegroundColor DarkCyan
                    }
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
            $done = ("   {0} : {1} en {2} ({3}/s)" -f $Label, (Format-Size $final), (Format-Duration $sw.Elapsed.TotalSeconds), (Format-Size $avg))
            if ($script:GuiProgress) {
                $script:GuiProgress.Value = 100
                if ($script:GuiStatus) { $script:GuiStatus.Text = '' }
                Ok $done.Trim()
            } else {
                Write-Host ("`r$done                              ") -ForegroundColor Green
            }
            return $true
        }
        catch {
            if ($out)  { try { $out.Close()  } catch {} }
            if ($in)   { try { $in.Close()   } catch {} }
            if ($resp) { try { $resp.Close() } catch {} }
            Write-Progress -Activity $Label -Completed
            Write-Host ''
            if ($attempt -lt $Retries) {
                $wait = [math]::Min(30, 4 * $attempt)
                Emit ('   ' + ($msgRetry -f $_.Exception.Message, ($attempt + 1), $Retries)) Yellow
                if ($canResume -and (Test-Path $tmp)) {
                    Emit (T2 ("   Reprise a " + (Format-Size (Get-Item $tmp).Length) + ".") `
                             ("   Resuming from " + (Format-Size (Get-Item $tmp).Length) + ".")) DarkGray
                }
                Start-Sleep -Seconds $wait
            } else {
                throw ($msgFail -f $Label, $Retries, $_.Exception.Message)
            }
        }
    }
    return $false
}

# =====================================================================  interface graphique

function Show-Gui {
    param($Root)

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()

    # Filet de securite : sans ca, la moindre exception qui remonte jusqu'a la
    # boucle de messages affiche la boite .NET "Une exception non geree s'est
    # produite dans un composant de votre application", illisible pour un
    # joueur et impossible a diagnostiquer. On la rattrape et on l'ecrit dans
    # le journal de la fenetre.
    try {
        [System.Windows.Forms.Application]::SetUnhandledExceptionMode(
            [System.Windows.Forms.UnhandledExceptionMode]::CatchException)
        [System.Windows.Forms.Application]::add_ThreadException({
            param($src, $e)
            if ($script:GuiBox) { Bad ($e.Exception.GetType().Name + ' : ' + $e.Exception.Message) }
            else { Write-Host $e.Exception.Message -ForegroundColor Red }
        })
    } catch { }

    $bg     = [System.Drawing.ColorTranslator]::FromHtml('#1B1F24')
    $panel  = [System.Drawing.ColorTranslator]::FromHtml('#22272E')
    $accent = [System.Drawing.ColorTranslator]::FromHtml('#3A9AB8')
    $fg     = [System.Drawing.ColorTranslator]::FromHtml('#E6E6E6')
    $dim    = [System.Drawing.ColorTranslator]::FromHtml('#8A8A8A')

    $form                 = New-Object System.Windows.Forms.Form
    $form.Text            = 'GTA IV - RTX Remix Path Tracing'
    $form.Size            = New-Object System.Drawing.Size(940, 716)
    $form.StartPosition   = 'CenterScreen'
    $form.BackColor       = $bg
    $form.ForeColor       = $fg
    $form.Font            = New-Object System.Drawing.Font('Segoe UI', 9)
    $form.FormBorderStyle = 'FixedSingle'
    $form.MaximizeBox     = $false

    # ---- bandeau
    $head            = New-Object System.Windows.Forms.Panel
    $head.Size       = New-Object System.Drawing.Size(940, 74)
    $head.Location   = New-Object System.Drawing.Point(0, 0)
    $head.BackColor  = $panel
    $form.Controls.Add($head)

    $title           = New-Object System.Windows.Forms.Label
    $title.Text      = 'GTA IV  -  RTX Remix Path Tracing'
    $title.Font      = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)
    $title.ForeColor = $fg
    $title.Location  = New-Object System.Drawing.Point(20, 12)
    $title.AutoSize  = $true
    $head.Controls.Add($title)

    $sub             = New-Object System.Windows.Forms.Label
    $sub.Text        = ($L.Subtitle -f $COMPMOD_VERSION) + '   |   ' + (T2 'aucune DLL DLSS 5 fournie' 'no DLSS 5 DLL shipped')
    $sub.ForeColor   = $dim
    $sub.Location    = New-Object System.Drawing.Point(23, 44)
    $sub.AutoSize    = $true
    $head.Controls.Add($sub)

    # ---- ligne jeu
    $lblGame           = New-Object System.Windows.Forms.Label
    $lblGame.Text      = (T2 'Jeu :' 'Game:')
    $lblGame.Location  = New-Object System.Drawing.Point(20, 90)
    $lblGame.AutoSize  = $true
    $lblGame.ForeColor = $dim
    $form.Controls.Add($lblGame)

    $txtGame                 = New-Object System.Windows.Forms.TextBox
    $txtGame.Location        = New-Object System.Drawing.Point(70, 87)
    $txtGame.Size            = New-Object System.Drawing.Size(680, 24)
    $txtGame.ReadOnly        = $true
    $txtGame.BackColor       = $panel
    $txtGame.ForeColor       = $fg
    $txtGame.BorderStyle     = 'FixedSingle'
    $form.Controls.Add($txtGame)

    $btnBrowse              = New-Object System.Windows.Forms.Button
    $btnBrowse.Text         = (T2 'Changer...' 'Change...')
    $btnBrowse.Location     = New-Object System.Drawing.Point(760, 86)
    $btnBrowse.Size         = New-Object System.Drawing.Size(150, 26)
    $btnBrowse.FlatStyle    = 'Flat'
    $btnBrowse.BackColor    = $panel
    $btnBrowse.ForeColor    = $fg
    $form.Controls.Add($btnBrowse)

    # ---- boutons d'action
    $script:Buttons = @()
    function New-ActionButton {
        param($Text, $Sub, $X, $Y, $W, $H, $Main)
        $b               = New-Object System.Windows.Forms.Button
        $b.Text          = if ($Sub) { "$Text`r`n$Sub" } else { $Text }
        $b.Location      = New-Object System.Drawing.Point($X, $Y)
        $b.Size          = New-Object System.Drawing.Size($W, $H)
        $b.FlatStyle     = 'Flat'
        $b.TextAlign     = 'MiddleCenter'
        $b.ForeColor     = $fg
        $b.BackColor     = if ($Main) { $accent } else { $panel }
        $b.Font          = New-Object System.Drawing.Font('Segoe UI', 9.5)
        $b.FlatAppearance.BorderColor = [System.Drawing.ColorTranslator]::FromHtml('#3A4250')
        $script:Buttons += $b
        return $b
    }

    $btnFull = New-ActionButton (T2 'Installation complete' 'Full install')  (T2 'path tracing + textures PBR - 5,3 Go' 'path tracing + PBR textures - 5.3 GB') 20 128 300 56 $true
    $btnMin  = New-ActionButton (T2 'Installation minimale' 'Minimal install') (T2 'path tracing seul - 549 Mo' 'path tracing only - 549 MB')            330 128 300 56 $false
    $btnDiag = New-ActionButton (T2 'Diagnostic' 'Diagnose') (T2 'ca ne marche pas ? commence ici' 'broken? start here')                                640 128 270 56 $false
    $btnNr   = New-ActionButton (T2 'Ajouter le fichier DLSS 5...' 'Add DLSS 5 file...') (T2 'nvngx_dlssnr.dll - a fournir toi-meme' 'nvngx_dlssnr.dll - bring your own') 20 194 300 56 $false
    $btnRep  = New-ActionButton (T2 'Affichage et reparations' 'Display and repairs') (T2 'mode, resolution, shaders, cache' 'mode, resolution, shaders, cache') 330 194 300 56 $false
    $btnVer  = New-ActionButton (T2 'Verifier' 'Verify')   '' 640 194 270 56 $false
    $btnUn   = New-ActionButton (T2 'Desinstaller' 'Uninstall') '' 20 260 300 42 $false
    $btnFaq  = New-ActionButton (T2 'Questions frequentes' 'FAQ') '' 330 260 300 42 $false
    $btnGit  = New-ActionButton 'GitHub' '' 640 260 270 42 $false
    foreach ($b in $script:Buttons) { $form.Controls.Add($b) }

    # ---- journal
    $box                = New-Object System.Windows.Forms.RichTextBox
    $box.Location       = New-Object System.Drawing.Point(20, 314)
    $box.Size           = New-Object System.Drawing.Size(890, 320)
    $box.BackColor      = [System.Drawing.ColorTranslator]::FromHtml('#14181D')
    $box.ForeColor      = $fg
    $box.Font           = New-Object System.Drawing.Font('Consolas', 9.5)
    $box.ReadOnly       = $true
    $box.BorderStyle    = 'FixedSingle'
    $box.ScrollBars     = 'Vertical'
    $form.Controls.Add($box)

    # ---- barre de progression
    $bar             = New-Object System.Windows.Forms.ProgressBar
    $bar.Location    = New-Object System.Drawing.Point(20, 646)
    $bar.Size        = New-Object System.Drawing.Size(890, 16)
    $bar.Style       = 'Continuous'
    $form.Controls.Add($bar)

    $status            = New-Object System.Windows.Forms.Label
    $status.Location   = New-Object System.Drawing.Point(20, 668)
    $status.Size       = New-Object System.Drawing.Size(890, 20)
    $status.ForeColor  = $dim
    $status.Text       = ''
    $form.Controls.Add($status)

    $script:GuiForm     = $form

    $script:GuiBox      = $box
    $script:GuiProgress = $bar
    $script:GuiStatus   = $status

    function Set-Busy { param([bool] $On)
        foreach ($b in $script:Buttons) { $b.Enabled = -not $On }
        $btnBrowse.Enabled = -not $On
        $form.Cursor = if ($On) { 'WaitCursor' } else { 'Default' }
        [System.Windows.Forms.Application]::DoEvents()
    }

    function Refresh-Game {
        $v = Get-GameVersion $script:GamePath
        $txtGame.Text = "$($script:GamePath)    [$v]"
        if ($v -ne $REQUIRED_VERSION) {
            $txtGame.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#FF6B6B')
            $status.Text = (T2 "Version $v -- il faut $REQUIRED_VERSION (Complete Edition)" "Version $v -- $REQUIRED_VERSION required (Complete Edition)")
        } else {
            $txtGame.ForeColor = $fg
            $status.Text = ''
        }
    }

    function Run-Action { param($Block)
        Set-Busy $true
        $box.Clear()
        try { & $Block }
        catch {
            Bad $_.Exception.Message
            if ($_.InvocationInfo -and $_.InvocationInfo.ScriptLineNumber) {
                Say ("       " + (T2 'ligne' 'line') + " $($_.InvocationInfo.ScriptLineNumber) : $($_.InvocationInfo.Line.Trim())") DarkGray
            }
        }
        $bar.Value = 0; $bar.Style = 'Continuous'; $status.Text = ''
        Set-Busy $false

        # Une instance elevee vient de prendre le relais : on ferme celle-ci.
        if ($script:ElevatedRelaunch) {
            $script:ElevatedRelaunch = $false
            $form.Close()
        }
    }

    $btnBrowse.Add_Click({
        $d = New-Object System.Windows.Forms.FolderBrowserDialog
        $d.Description = $L.DialogTitle
        if ($d.ShowDialog() -eq 'OK') {
            if (Test-Path (Join-Path $d.SelectedPath 'GTAIV.exe')) { $script:GamePath = $d.SelectedPath; Refresh-Game }
            else { [System.Windows.Forms.MessageBox]::Show(($L.NoExe -f $d.SelectedPath) + "`r`n" + $L.NoExeHint, 'GTA IV RTX') | Out-Null }
        }
    })

    $btnFull.Add_Click({ Run-Action { Invoke-Install $script:GamePath $true } })
    $btnMin.Add_Click({  Run-Action { Invoke-Install $script:GamePath $false } })
    $btnDiag.Add_Click({ Run-Action { Invoke-Diagnose $script:GamePath } })
    $btnRep.Add_Click({  Run-Action { Invoke-Repair $script:GamePath } })

    $btnUn.Add_Click({   Run-Action { Invoke-Uninstall $script:GamePath } })
    $btnFaq.Add_Click({  Run-Action { Show-Faq } })
    $btnVer.Add_Click({  Run-Action {
        Step $L.StepVerify
        $m = Invoke-Verify $script:GamePath
        Say ''
        if ($m.Core.Count -eq 0) { Ok $L.VerifyOk } else { Warn ($L.VerifyMissing -f $m.Core.Count) }
    } })
    $btnGit.Add_Click({ Start-Process $URL_MOD })

    $btnNr.Add_Click({
        $nr = Get-NrStatus $script:GamePath
        $msg = if ($nr.Present) {
            (T2 "nvngx_dlssnr.dll est deja en place ($([math]::Round($nr.Size/1MB,1)) Mo).`r`n`r`nLe remplacer par un autre fichier ?" `
                "nvngx_dlssnr.dll is already in place ($([math]::Round($nr.Size/1MB,1)) MB).`r`n`r`nReplace it with another file?")
        } else {
            (T2 @"
Ce programme ne fournit PAS le fichier DLSS 5 et ne le telechargera pas.

Tu dois te procurer nvngx_dlssnr.dll par tes propres moyens.
DLSS 5 n'est pas encore sorti officiellement (automne 2026, RTX 50).

Une fois que tu l'as, selectionne-le : il sera verifie puis copie
dans le sous-dossier .trex du jeu.

Continuer ?
"@ @"
This program does NOT provide the DLSS 5 file and will not download it.

You must obtain nvngx_dlssnr.dll yourself.
DLSS 5 has not been officially released yet (fall 2026, RTX 50).

Once you have it, select it here: it will be validated and copied
into the game's .trex subfolder.

Continue?
"@)
        }
        $r = [System.Windows.Forms.MessageBox]::Show($msg, 'DLSS 5',
             [System.Windows.Forms.MessageBoxButtons]::OKCancel, [System.Windows.Forms.MessageBoxIcon]::Information)
        if ($r -ne [System.Windows.Forms.DialogResult]::OK) { return }

        $d = New-Object System.Windows.Forms.OpenFileDialog
        $d.Title  = (T2 'Selectionne nvngx_dlssnr.dll' 'Select nvngx_dlssnr.dll')
        $d.Filter = 'nvngx_dlssnr.dll|nvngx_dlssnr.dll|DLL (*.dll)|*.dll'
        if ($d.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
        Run-Action { Install-NrRuntime $script:GamePath $d.FileName | Out-Null }
        Refresh-Nr
    })

    function Refresh-Nr {
        $nr = Get-NrStatus $script:GamePath
        if ($nr.Present) {
            $btnNr.Text = (T2 "DLSS 5 : present`r`nremplacer le fichier..." "DLSS 5: present`r`nreplace the file...")
            $btnNr.ForeColor = [System.Drawing.ColorTranslator]::FromHtml('#5FD75F')
        } else {
            $btnNr.Text = (T2 "Ajouter le fichier DLSS 5...`r`nnvngx_dlssnr.dll - a fournir toi-meme" "Add DLSS 5 file...`r`nnvngx_dlssnr.dll - bring your own")
            $btnNr.ForeColor = $fg
        }
    }

    $form.Add_Shown({
        Refresh-Game
        Refresh-Nr
        Say ''
        Say (T2 '  Choisis une action ci-dessus.' '  Pick an action above.') White
        Say (T2 "  Si quelque chose ne fonctionne pas, commence par Diagnostic." '  If something is broken, start with Diagnose.') DarkGray
        Say ''
        Say (T2 '  Ce programme ne fournit aucune DLL DLSS 5 et ne la telechargera pas.' '  This program ships no DLSS 5 DLL and will not download one.') DarkGray
        Say (T2 '  Mod par xoxor4d - github.com/xoxor4d/gta4-rtx' '  Mod by xoxor4d - github.com/xoxor4d/gta4-rtx') DarkGray
        # Relance apres elevation UAC : on enchaine directement sur l'installation demandee
        if ($AutoInstall) { Run-Action { Invoke-Install $script:GamePath ($AutoInstall -eq 'full') } }
    })

    [void]$form.ShowDialog()
    $script:GuiBox = $null; $script:GuiProgress = $null; $script:GuiStatus = $null; $script:GuiForm = $null
}

# =====================================================================  main

$L = Get-Messages -Language $Language

function T2   { param($fr, $en) if ($L.Lang -eq 'fr') { $fr } else { $en } }

# Les fonctions d'affichage ecrivent dans la console OU dans la fenetre,
# selon que $script:GuiBox est defini (voir Show-Gui).
$script:GuiBox = $null
function Emit {
    param($Text, $Color = 'Gray')
    if ($script:GuiBox) {
        $map = @{ Gray='#C8C8C8'; DarkGray='#8A8A8A'; White='#FFFFFF'; Green='#5FD75F'
                  Yellow='#E8C547'; Red='#FF6B6B'; Cyan='#5FD7FF'; DarkCyan='#3A9AB8' }
        $hex = if ($map[$Color]) { $map[$Color] } else { '#C8C8C8' }
        $script:GuiBox.SelectionStart = $script:GuiBox.TextLength
        $script:GuiBox.SelectionColor = [System.Drawing.ColorTranslator]::FromHtml($hex)
        $script:GuiBox.AppendText("$Text`r`n")
        $script:GuiBox.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()
    } else {
        Write-Host $Text -ForegroundColor $Color
    }
}
function Say  { param($m, $c = 'Gray') Emit $m $c }
function Step { param($m) Emit '' ; Emit "  $m" Cyan; Emit ('  ' + ('-' * $m.Length)) DarkCyan }
function Ok   { param($m) Emit "  [OK]   $m" Green }
function Warn { param($m) Emit "  [!]    $m" Yellow }
function Bad  { param($m) Emit "  [X]    $m" Red }

function Ask {
    param([string] $Question)
    if ($script:GuiBox) {
        $r = [System.Windows.Forms.MessageBox]::Show($Question, 'GTA IV RTX',
             [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        return ($r -eq [System.Windows.Forms.DialogResult]::Yes)
    }
    while ($true) {
        $r = Read-Host "  $Question $($L.YesNo)"
        if ([string]::IsNullOrWhiteSpace($r)) { return $true }
        if ($r[0] -cmatch "[$($L.YesChars)]") { return $true }
        if ($r[0] -cmatch "[$($L.NoChars)]")  { return $false }
    }
}
function Pause2 {
    if ($script:GuiBox) { return }
    Write-Host ''; Read-Host (T2 "  Entree pour revenir au menu" "  Press Enter to return to the menu") | Out-Null
}

function Banner {
    Clear-Host
    Write-Host ''
    Write-Host '  ==============================================================' -ForegroundColor DarkCyan
    Write-Host "   $($L.Title)" -ForegroundColor White
    Write-Host "   $($L.Subtitle -f $COMPMOD_VERSION)" -ForegroundColor DarkGray
    Write-Host '  ==============================================================' -ForegroundColor DarkCyan
    Write-Host ''
    Say "  $($L.NoDlss)" DarkGray
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

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
                         'Jeux\Grand Theft Auto IV', 'Jeu\Grand Theft Auto IV',
                         'Program Files\Rockstar Games\Grand Theft Auto IV',
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

function Resolve-Game {
    if ($script:GamePath) { return $script:GamePath }
    $found = @(Find-GameCandidates)
    if ($found.Count -eq 0) {
        Warn $L.NoneFound
        Say  "  $($L.PickFolder)" DarkGray
        return (Select-GameFolder)
    }
    if ($found.Count -eq 1) { return $found[0] }
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
            if ($n -eq ($found.Count + 1)) { return (Select-GameFolder) }
            return $found[$n - 1]
        }
    }
}

# ---------------------------------------------------------------- actions

function Invoke-Verify {
    param($Root, [switch] $Quiet)
    $list = $EXPECTED_CORE + $EXPECTED_CONTENT
    $missCore = @(); $missContent = @()
    foreach ($f in $EXPECTED_CORE)    { if (Test-Path (Join-Path $Root $f)) { if (-not $Quiet) { Ok $f } } else { if (-not $Quiet) { Bad $f }; $missCore += $f } }
    foreach ($f in $EXPECTED_CONTENT) { if (Test-Path (Join-Path $Root $f)) { if (-not $Quiet) { Ok $f } } else { if (-not $Quiet) { Warn "$f  (" + (T2 "pack de contenu, optionnel" "content pack, optional") + ")" }; $missContent += $f } }
    return @{ Core = $missCore; Content = $missContent }
}

function Invoke-Diagnose {
    param($Root)
    Step (T2 "Diagnostic" "Diagnostics")

    $ver = Get-GameVersion $Root
    if ($ver -eq $REQUIRED_VERSION) { Ok (T2 "Version du jeu : $ver" "Game version: $ver") }
    else { Bad (T2 "Version $ver -- il faut $REQUIRED_VERSION (Complete Edition)" "Version $ver -- $REQUIRED_VERSION required (Complete Edition)") }

    $w = $false
    try { $t = Join-Path $Root ('.w_' + [guid]::NewGuid().ToString('N')); [IO.File]::WriteAllText($t,'x'); [IO.File]::Delete($t); $w = $true } catch {}
    if ($w) { Ok (T2 "Droits d'ecriture" "Write access") }
    else { Bad (T2 "Dossier en lecture seule -- voir l'option 1 du menu" "Folder is read-only -- see menu option 1") }

    $m = Invoke-Verify $Root -Quiet
    if ($m.Core.Count -eq 0) { Ok (T2 "Tous les composants du mod sont presents" "All mod components present") }
    else {
        Bad (T2 "$($m.Core.Count) composant(s) manquant(s) :" "$($m.Core.Count) component(s) missing:")
        $m.Core | ForEach-Object { Say "         $_" Red }
        if ($m.Core -contains 'a_gta4-rtx.asi') {
            Write-Host ''
            Warn (T2 "a_gta4-rtx.asi absent = Windows Defender l'a mis en quarantaine." "a_gta4-rtx.asi missing = Windows Defender quarantined it.")
            Say  (T2 "  Faux positif Wacatac.B!ml (4/75 sur VirusTotal, toutes heuristiques)." "  Wacatac.B!ml false positive (4/75 on VirusTotal, all heuristic).") DarkGray
            Say  (T2 "  Lance ceci dans un PowerShell ADMIN, puis reinstalle :" "  Run this in an ADMIN PowerShell, then reinstall:") White
            Say  ("    " + ('Add-MpPreference' + ' -ExclusionPath "' + (Join-Path $Root 'a_gta4-rtx.asi') + '"')) Yellow
        }
    }
    if ($m.Content.Count -gt 0 -and $m.Core.Count -eq 0) {
        Warn (T2 "Packs de contenu absents (installation minimale) -- path tracing actif, sans materiaux PBR." "Content packs absent (minimal install) -- path tracing active, no PBR materials.")
    }

    # FusionFix d'origine (incompatible)
    $ff = Join-Path $Root 'plugins\GTAIV.EFLC.FusionFix.RTXRemix.txt'
    if ((Test-Path (Join-Path $Root 'plugins\GTAIV.EFLC.FusionFix.asi')) -and -not (Test-Path $ff)) {
        Warn (T2 "FusionFix present mais ce n'est pas le fork RTX -- source frequente de crash." "FusionFix present but not the RTX fork -- a common crash cause.")
        Say  (T2 "  Reinstalle via ce script, il pose le bon fork." "  Reinstall through this script, it installs the right fork.") DarkGray
    }

    # DLSS 5
    $nr = Join-Path $Root '.trex\nvngx_dlssnr.dll'
    if (Test-Path $nr) { Ok (T2 "nvngx_dlssnr.dll present -- Neural Rendering disponible" "nvngx_dlssnr.dll present -- Neural Rendering available") }
    else { Say (T2 "  nvngx_dlssnr.dll absent -- normal, ce script ne le fournit pas." "  nvngx_dlssnr.dll absent -- expected, this script does not ship it.") DarkGray }

    # -- Chaine de demarrage. C'est ici que se joue le "Could not find 'grcWindow'" :
    # le mod attend la fenetre de rendu du jeu, qui n'arrive jamais si le pont
    # Remix 32/64 bits n'a pas abouti. Le message est le symptome, pas la cause.

    Write-Host ''
    Say (T2 "  Chaine de demarrage" "  Startup chain") White

    # 1. le serveur 64 bits du pont
    $srv = Join-Path $Root '.trex\NvRemixBridge.exe'
    if (Test-Path $srv) {
        Ok (T2 "NvRemixBridge.exe present" "NvRemixBridge.exe present")
    } else {
        Bad (T2 "NvRemixBridge.exe ABSENT de .trex -- le pont Remix ne peut pas demarrer." "NvRemixBridge.exe MISSING from .trex -- the Remix bridge cannot start.")
        Say (T2 "  L'antivirus l'emporte souvent apres coup : l'exclusion ne couvre que le .asi." "  Antivirus often takes it later: the exclusion only covers the .asi.") DarkGray
        Say (T2 "  PowerShell ADMIN, puis reinstalle :" "  ADMIN PowerShell, then reinstall:") White
        Say ("    " + ('Add-MpPreference' + ' -ExclusionPath "' + (Join-Path $Root '.trex') + '"')) Yellow
    }

    # 2. le journal du mod de compatibilite
    $clog = Join-Path $Root 'rtx_comp\logfile.txt'
    if (Test-Path $clog) {
        $txt = Get-Content -LiteralPath $clog -Raw -ErrorAction SilentlyContinue

        $miss = @(Select-String -Path $clog -Pattern 'Could not find pattern' -ErrorAction SilentlyContinue)
        if ($miss.Count -gt 0) {
            Bad (T2 "$($miss.Count) motif(s) memoire introuvable(s) -- mauvaise version du jeu, ou un autre mod dessus." "$($miss.Count) memory pattern(s) not found -- wrong game version, or another mod on top.")
            Say (T2 "  Il faut la Complete Edition $REQUIRED_VERSION sur une installation propre." "  Complete Edition $REQUIRED_VERSION on a clean install is required.") DarkGray
        } elseif ($txt -match 'Found all .(\d+). Patterns') {
            Ok (T2 "Motifs memoire : tous trouves ($($Matches[1]))" "Memory patterns: all found ($($Matches[1]))")
        }

        if ($txt -match "Could not find 'grcWindow'") {
            Bad (T2 "La fenetre de rendu n'est jamais apparue (grcWindow)." "The render window never appeared (grcWindow).")
            Say (T2 "  Le mod a attendu puis abandonne : le jeu n'a pas fini de creer son device D3D9." "  The mod waited then gave up: the game never finished creating its D3D9 device.") DarkGray
            Say (T2 "  Causes confirmees, dans l'ordre a essayer :" "  Confirmed causes, in the order to try them:") White
            Say (T2 "    1. Lancer le jeu en tant qu'administrateur." "    1. Run the game as administrator.") DarkGray
            Say (T2 "    2. Un FusionFix d'origine deja en place : tout supprimer, puis reinstaller." "    2. A stock FusionFix already installed: delete it all, then reinstall.") DarkGray
            Say (T2 "    3. Jeu dans Program Files ou sur le disque systeme : le deplacer ailleurs." "    3. Game inside Program Files or on the system drive: move it elsewhere.") DarkGray
            Say (T2 "    4. Runtime DirectX 9 de juin 2010 absent." "    4. June 2010 DirectX 9 runtime missing.") DarkGray
            Say (T2 "    5. Logiciel de capture en fond (Medal, Bandicam, RTSS...) : le fermer." "    5. Background capture software (Medal, Bandicam, RTSS...): close it.") DarkGray
        } elseif ($txt -match 'Class: grcWindow') {
            Ok (T2 "Fenetre de rendu detectee (grcWindow)" "Render window detected (grcWindow)")
        }
    }

    # 3. la poignee de main du pont 32 <-> 64 bits
    $b32 = Join-Path $Root 'rtx-remix\logs\bridge32.log'
    if (Test-Path $b32) {
        $t32 = Get-Content -LiteralPath $b32 -Raw -ErrorAction SilentlyContinue
        if ($t32 -match 'Handshake completed') {
            Ok (T2 "Pont Remix : poignee de main reussie" "Remix bridge: handshake completed")
        } elseif ($t32 -match 'Sending SYN command') {
            Bad (T2 "Pont Remix : SYN envoye, aucune reponse du serveur 64 bits." "Remix bridge: SYN sent, no answer from the 64-bit server.")
            Say (T2 "  NvRemixBridge.exe n'a pas demarre. Antivirus, ou dossier du jeu non inscriptible." "  NvRemixBridge.exe never started. Antivirus, or a non-writable game folder.") DarkGray
            Say (T2 "  Un joueur a resolu ce cas exact en deplacant le jeu sur un autre disque." "  One player fixed this exact case by moving the game to another drive.") DarkGray
        }
    }

    # 4. runtime DX9 juin 2010 (le jeu est 32 bits -> SysWOW64)
    $dxDir = if ([Environment]::Is64BitOperatingSystem) { "$env:WINDIR\SysWOW64" } else { "$env:WINDIR\System32" }
    if (Test-Path (Join-Path $dxDir 'd3dx9_43.dll')) {
        Ok (T2 "Runtime DirectX 9 (juin 2010) installe" "DirectX 9 runtime (June 2010) installed")
    } else {
        Bad (T2 "Runtime DirectX 9 de juin 2010 absent -- cause frequente d'echec au demarrage." "June 2010 DirectX 9 runtime missing -- a frequent startup failure.")
        Say  "    https://www.microsoft.com/download/details.aspx?id=8109" Yellow
    }

    # 5. emplacement du jeu
    if ($Root -like '*:\Program Files*') {
        Bad (T2 "Le jeu est dans Program Files -- emplacement deconseille par l'auteur du mod." "The game sits in Program Files -- the mod author advises against it.")
        Say (T2 "  Deplace-le, par exemple dans D:\Jeux\Grand Theft Auto IV." "  Move it, for example to D:\Games\Grand Theft Auto IV.") DarkGray
    }

    # 6. captures et overlays en fond : cause documentee de crash et de blocage
    $bad = @{
        'Medal'          = 'Medal'
        'obs64'          = 'OBS'
        'bdcam'          = 'Bandicam'
        'RTSS'           = 'RivaTuner Statistics Server'
        'MSIAfterburner' = 'MSI Afterburner'
        'Fraps'          = 'Fraps'
        'Outplayed'      = 'Outplayed'
    }
    $running = @()
    foreach ($k in $bad.Keys) { if (Get-Process -Name $k -ErrorAction SilentlyContinue) { $running += $bad[$k] } }
    if ($running.Count -gt 0) {
        Warn (T2 ("Logiciel de capture actif : " + ($running -join ', ')) ("Capture software running: " + ($running -join ', ')))
        Say (T2 "  Ferme-le avant de lancer le jeu : cause documentee de crash avec Remix." "  Close it before launching: a documented crash cause with Remix.") DarkGray
    }

    # logs Remix
    $log = Join-Path $Root 'rtx-remix\logs\remix-dxvk.log'
    if (Test-Path $log) {
        $errs = @(Select-String -Path $log -Pattern '^\s*err:' -ErrorAction SilentlyContinue | Select-Object -Last 5)
        if ($errs.Count -gt 0) {
            Write-Host ''
            Warn (T2 "Dernieres erreurs dans remix-dxvk.log :" "Last errors in remix-dxvk.log:")
            $errs | ForEach-Object { Say ("         " + $_.Line.Trim().Substring(0, [Math]::Min(110, $_.Line.Trim().Length))) DarkGray }
        } else { Ok (T2 "Aucune erreur dans le log Remix" "No errors in the Remix log") }
    } else {
        Say (T2 "  Pas encore de log Remix -- lance le jeu une fois." "  No Remix log yet -- launch the game once.") DarkGray
    }

    # reglages perf
    $uc = Join-Path $Root 'user.conf'
    if (Test-Path $uc) {
        Write-Host ''
        Say (T2 "  Reglages actifs (user.conf, prime sur rtx.conf) :" "  Active settings (user.conf, overrides rtx.conf):") White
        foreach ($k in 'rtx.dlfg.enable', 'rtx.upscalerType', 'rtx.qualityDLSS', 'rtx.graphicsPreset', 'rtx.reflexMode') {
            $line = Select-String -Path $uc -Pattern ([regex]::Escape($k) + '\s*=') -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($line) { Say ("    " + $line.Line.Trim()) DarkGray }
        }
        $fg = Select-String -Path $uc -Pattern 'rtx\.dlfg\.enable\s*=\s*False' -ErrorAction SilentlyContinue
        if ($fg) { Warn (T2 "Frame Generation desactivee -- active-la dans Alt+X (RTX 40/50 seulement)." "Frame Generation is off -- enable it in Alt+X (RTX 40/50 only).") }
    }
}

function Invoke-Uninstall {
    param($Root)
    Step (T2 "Desinstallation" "Uninstall")
    $found = @()
    foreach ($f in $MOD_FILES) { if (Test-Path (Join-Path $Root $f)) { $found += $f } }
    foreach ($d in $MOD_DIRS)  { if (Test-Path (Join-Path $Root $d)) { $found += "$d\" } }
    if ($found.Count -eq 0) { Ok (T2 "Rien a retirer, le jeu est deja vanille." "Nothing to remove, the game is already vanilla."); return }
    Say (T2 "  Sera retire de $Root :" "  Will be removed from ${Root}:") White
    $found | ForEach-Object { Say "    $_" DarkGray }
    Write-Host ''
    Say (T2 "  Tes sauvegardes et les fichiers du jeu ne sont pas touches." "  Your saves and the game files are not touched.") DarkGray
    Write-Host ''
    if (-not (Ask (T2 "Confirmer ?" "Confirm?"))) { Say (T2 "  Annule." "  Cancelled.") DarkGray; return }
    $ko = 0
    foreach ($f in $MOD_FILES) { $p = Join-Path $Root $f; if (Test-Path $p) { try { Remove-Item -LiteralPath $p -Force -ErrorAction Stop; Ok $f } catch { Bad $f; $ko++ } } }
    foreach ($d in $MOD_DIRS)  { $p = Join-Path $Root $d; if (Test-Path $p) { try { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop; Ok "$d\" } catch { Bad "$d\"; $ko++ } } }
    Write-Host ''
    if ($ko -eq 0) { Ok (T2 "Termine, le jeu est revenu en vanille." "Done, the game is back to vanilla.") }
    else { Warn (T2 "$ko element(s) bloques -- le jeu tourne peut-etre encore." "$ko item(s) blocked -- the game may still be running.") }
}

function Invoke-Install {
    param($Root, [bool] $WithContent)

    # -- permissions
    # On teste AVANT de songer a l'elevation : dans la majorite des cas le
    # dossier est deja inscriptible, et un UAC gratuit fait fuir la moitie des
    # gens pour rien.
    Step $L.StepPerms
    $canWrite = $false
    try { $t = Join-Path $Root ('.w_' + [guid]::NewGuid().ToString('N') + '.tmp'); [IO.File]::WriteAllText($t, 'x'); [IO.File]::Delete($t); $canWrite = $true } catch {}

    if (-not $canWrite -and -not (Test-Admin)) {
        Warn $L.NeedAdmin
        Say  "  $($L.Elevating)" DarkGray
        $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-GamePath', "`"$Root`"")
        if ($script:GuiBox) { $a += @('-AutoInstall', $(if ($WithContent) { 'full' } else { 'min' })) }
        elseif (-not $WithContent) { $a += '-NoContentMods' }
        if ($Console)  { $a += '-Console' }
        if ($Language) { $a += @('-Language', $Language) }
        try {
            Start-Process powershell.exe -Verb RunAs -ArgumentList $a
            # Surtout pas 'exit' ici. En mode graphique on tourne dans un
            # gestionnaire d'evenement WinForms : quitter le runspace depuis la
            # boucle de messages leve l'exception non geree de .NET, celle qui
            # affiche "Une exception non geree s'est produite dans un composant
            # de votre application". On leve un drapeau, Run-Action fermera la
            # fenetre proprement.
            if ($script:GuiBox) { $script:ElevatedRelaunch = $true; return }
            exit 0
        }
        catch { Bad $L.ElevRefused; return }
    }

    if ($canWrite) { Ok $L.PermsOk }
    else {
        $acct = "$env:COMPUTERNAME\$env:USERNAME"
        Warn $L.PermsReadOnly
        Say "  $($L.PermsWhy1)" DarkGray
        Say "  $($L.PermsWhy2)" DarkGray
        Write-Host ''
        Say ("  " + ($L.PermsAction -f $acct, $Root)) White
        Say ("  " + ($L.PermsUndo -f "icacls `"$Root`" /remove `"$acct`" /T")) DarkGray
        Write-Host ''
        if (Ask $L.PermsAsk) {
            & icacls "$Root" /grant "${acct}:(OI)(CI)M" /T /C | Out-Null
            if ($LASTEXITCODE -eq 0) { Ok $L.PermsDone } else { Bad $L.PermsFail; return }
        } else { Bad $L.PermsRequired; return }
    }

    # -- defender
    Step $L.StepDefender
    $asiPath = Join-Path $Root 'a_gta4-rtx.asi'
    $exclusionCmd = 'Add-MpPreference' + ' -ExclusionPath "' + $asiPath + '"'
    Warn $L.DefIntro
    Write-Host ''
    Say "  $($L.DefFalsePos)" White
    foreach ($k in 'DefE1','DefE2','DefE3','DefE4','DefE5','DefE6') { Say "    $($L[$k])" DarkGray }
    Write-Host ''
    Say "  $($L.DefNoAuto)"  White
    Say "  $($L.DefNoAuto2)" DarkGray
    Say "  $($L.DefNoAuto3)" DarkGray
    Write-Host ''
    Say "  $($L.DefManual)"  White
    Say "  $($L.DefManual2)" White
    Say "    $exclusionCmd"  Yellow

    # -- telechargement
    $sources = @(
        @{ Key = 'NameCompMod'; File = 'compmod.zip'
           Url = "https://github.com/xoxor4d/gta4-rtx/releases/download/v$COMPMOD_VERSION/GTAIV-Remix-CompatibilityMod-$COMPMOD_VERSION.zip" }
    )
    if ($WithContent) {
        $sources += @{ Key = 'NameBase';    File = 'basemod.zip'
                       Url  = 'https://github.com/xoxor4d/gta4-rtx-base-mod/archive/refs/heads/master.zip'
                       Alt  = @('gta4-rtx-base-mod-master.zip', 'basemod.zip') }
        $sources += @{ Key = 'NameAutoPbr'; File = 'autopbr.zip'
                       Url  = 'https://github.com/xoxor4d/gta4-rtx-autopbr-mod/archive/refs/heads/master.zip'
                       Alt  = @('gta4-rtx-autopbr-mod-master.zip', 'autopbr.zip') }
    }
    $work = Join-Path $env:TEMP 'gta4rtx-install'
    New-Item -ItemType Directory -Force -Path $work | Out-Null

    # Place disponible : l'extraction double le volume telecharge.
    $needGB = if ($WithContent) { 14 } else { 3 }
    $freeGB = Get-FreeSpaceGB $work
    if ($freeGB -ge 0 -and $freeGB -lt $needGB) {
        Bad (T2 ("Place insuffisante sur le disque de $work : " + [math]::Round($freeGB,1) + " Go libres, il en faut ~$needGB.") `
                ("Not enough space on the drive holding ${work}: " + [math]::Round($freeGB,1) + " GB free, ~$needGB GB needed."))
        return
    }
    Step ("$($L.StepDownload) (" + $(if ($WithContent) { '~5,3 Go' } else { '~549 Mo' }) + ")")
    Say "  $($L.DlCached)" DarkGray
    Write-Host ''
    foreach ($s in $sources) {
        $dest  = Join-Path $work $s.File
        $label = $L[$s.Key]
        if (Test-Path $dest) { Ok ($L.DlPresent -f $label, (Format-Size (Get-Item $dest).Length)); continue }

        # Archive deja recuperee a la main (navigateur, gestionnaire de telechargement) ?
        if ($s.Alt) {
            $local = Find-PreDownloaded -Names $s.Alt
            if ($local) {
                Ok (T2 ("$label : archive trouvee, telechargement evite -- $local") `
                       ("${label}: archive found, download skipped -- $local"))
                Copy-Item -LiteralPath $local -Destination $dest -Force
                continue
            }
        }

        try { Invoke-Download -Url $s.Url -Destination $dest -Label $label -Messages $L | Out-Null }
        catch {
            Bad $_.Exception.Message
            Write-Host ''
            Warn (T2 "Telechargement impossible depuis ce script." "The script could not download this file.")
            Say  (T2 "  Solution fiable : telecharge-le dans ton navigateur, qui sait reprendre" `
                     "  Reliable route: download it in your browser, which can resume") White
            Say  (T2 "  un transfert coupe, puis relance ce script -- il ramassera le fichier." `
                     "  a broken transfer, then re-run this script -- it will pick the file up.") White
            Write-Host ''
            Say  ("    " + $s.Url) Yellow
            Say  (T2 "  Depose-le ensuite, sans le renommer, dans :" "  Then drop it, unrenamed, into:") White
            Say  ("    " + (Join-Path $env:USERPROFILE 'Downloads')) Yellow
            return
        }
    }

    # -- installation
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    Step $L.StepInstall
    $stage = Join-Path $work 'stage'
    if (Test-Path $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $stage | Out-Null
    [IO.Compression.ZipFile]::ExtractToDirectory((Join-Path $work 'compmod.zip'), (Join-Path $stage 'compmod'))
    Ok $L.InstExtracted
    $src = Join-Path $stage 'compmod'
    Copy-Item "$src\GTAIV-Remix-CompatibilityMod\*"              $Root -Recurse -Force; Ok $L.InstCompMod
    Copy-Item "$src\_installer_options\FusionFix_RTXRemixFork\*" $Root -Recurse -Force; Ok $L.InstFusion
    Copy-Item "$src\_installer_options\mode_fullscreen\*"        $Root -Recurse -Force; Ok $L.InstFullscreen

    $modsDir = Join-Path $Root 'rtx-remix\mods'
    if (-not (Test-Path $modsDir)) { New-Item -ItemType Directory -Force -Path $modsDir | Out-Null }
    if ($WithContent) {
        Expand-ModsInto (Join-Path $work 'basemod.zip') $modsDir $L.NameBase
        Expand-ModsInto (Join-Path $work 'autopbr.zip') $modsDir $L.NameAutoPbr
    } else {
        Warn $L.SkipContent
        Say  "  $($L.SkipContent2)" DarkGray
    }
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue

    # -- bilan
    Step $L.StepVerify
    $m = Invoke-Verify $Root
    Write-Host ''
    if ($m.Core.Count -eq 0) {
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
        Warn ($L.VerifyMissing -f $m.Core.Count)
        $m.Core | ForEach-Object { Say "    $_" Red }
        if ($m.Core -contains 'a_gta4-rtx.asi') {
            Write-Host ''
            Warn $L.MissingAsi
            Say "  $($L.DefManual)"  White
            Say "  $($L.DefManual2)" White
            Say "    $exclusionCmd" Yellow
        }
    }
}

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

function Get-NrStatus {
    param($Root)
    $p = Join-Path $Root '.trex\nvngx_dlssnr.dll'
    if (Test-Path $p) { return @{ Present = $true; Path = $p; Size = (Get-Item $p).Length } }
    return @{ Present = $false; Path = $p; Size = 0 }
}

# Place un nvngx_dlssnr.dll fourni par l'utilisateur dans .trex\.
# Ce programme ne telecharge ni ne distribue ce fichier : l'utilisateur l'apporte.
function Install-NrRuntime {
    param($Root, $SourceFile)

    Step (T2 "Ajout du fichier DLSS 5" "Adding the DLSS 5 file")

    if (-not (Test-Path $SourceFile)) { Bad (T2 "Fichier introuvable." "File not found."); return $false }
    $fi = Get-Item $SourceFile

    if ($fi.Name -ne 'nvngx_dlssnr.dll') {
        Warn (T2 "Le fichier ne s'appelle pas nvngx_dlssnr.dll (recu : $($fi.Name))." "The file is not named nvngx_dlssnr.dll (got: $($fi.Name)).")
        Say  (T2 "  Il sera copie sous le bon nom." "  It will be copied under the correct name.") DarkGray
    }

    # verification PE 64-bit
    try {
        $fs = [IO.File]::OpenRead($fi.FullName)
        $b  = New-Object byte[] 2; [void]$fs.Read($b, 0, 2)
        if ($b[0] -ne 0x4D -or $b[1] -ne 0x5A) { $fs.Close(); Bad (T2 "Ce n'est pas un fichier DLL valide (en-tete MZ absent)." "Not a valid DLL (missing MZ header)."); return $false }
        $fs.Position = 0x3C
        $o = New-Object byte[] 4; [void]$fs.Read($o, 0, 4)
        $pe = [BitConverter]::ToInt32($o, 0)
        $fs.Position = $pe + 4
        $m = New-Object byte[] 2; [void]$fs.Read($m, 0, 2)
        $mach = [BitConverter]::ToUInt16($m, 0)
        $fs.Close()
        if ($mach -ne 0x8664) { Bad (T2 "Ce fichier n'est pas en 64 bits." "This file is not 64-bit."); return $false }
        Ok (T2 "DLL 64 bits valide" "Valid 64-bit DLL")
    } catch { Bad (T2 "Lecture impossible : $($_.Exception.Message)" "Cannot read the file: $($_.Exception.Message)"); return $false }

    Ok (T2 "Taille : $([math]::Round($fi.Length/1MB,1)) Mo" "Size: $([math]::Round($fi.Length/1MB,1)) MB")
    if ($fi.Length -lt 50MB) {
        Warn (T2 "Taille inhabituelle -- le runtime attendu fait environ 158 Mo." "Unusual size -- the expected runtime is about 158 MB.")
    }

    $trex = Join-Path $Root '.trex'
    if (-not (Test-Path $trex)) {
        Bad (T2 "Le dossier .trex n'existe pas : installe d'abord le Compatibility Mod." "The .trex folder does not exist: install the Compatibility Mod first.")
        return $false
    }

    $dst = Join-Path $trex 'nvngx_dlssnr.dll'
    try {
        Copy-Item -LiteralPath $fi.FullName -Destination $dst -Force -ErrorAction Stop
        Unblock-File -LiteralPath $dst -ErrorAction SilentlyContinue
        Ok (T2 "Copie dans $dst" "Copied to $dst")
    } catch { Bad (T2 "Copie impossible : $($_.Exception.Message)" "Copy failed: $($_.Exception.Message)"); return $false }

    Say ''
    Say (T2 "  En jeu : Alt+X -> menu developpeur -> Rendering -> Post-Processing -> Neural Rendering" "  In game: Alt+X -> developer menu -> Rendering -> Post-Processing -> Neural Rendering") White
    Say (T2 "  F6 active / desactive le Neural Rendering, F5 capture une paire avant/apres." "  F6 toggles Neural Rendering, F5 captures a before/after pair.") DarkGray
    return $true
}

function Get-ResolutionList {
    # L'ecran detecte en premier, puis les formats courants, sans doublon.
    Add-Type -AssemblyName System.Windows.Forms
    $s = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $list = @()
    $list += @{ W = $s.Width; H = $s.Height; Tag = (T2 'ecran detecte' 'detected screen') }
    foreach ($r in @(@(1280,720), @(1600,900), @(1920,1080), @(2560,1080), @(2560,1440), @(3440,1440), @(3840,2160))) {
        if ($r[0] -eq $s.Width -and $r[1] -eq $s.Height) { continue }
        $ar = $r[0] / $r[1]
        $ratio = if ($ar -gt 2.2) { '21:9' } elseif ($ar -gt 1.7) { '16:9' } else { '16:10' }
        $list += @{ W = $r[0]; H = $r[1]; Tag = $ratio }
    }
    return $list
}

function Select-DisplayOptions {
    <#
      .SYNOPSIS  Demande mode d'affichage, resolution et shaders.
      Renvoie $null si l'utilisateur annule.
      Le mod ne propose que deux modes -- 'mode_fullscreen' pose en realite un
      borderless (Windowed=1 + BorderlessWindowed=1), 'mode_windowed' une vraie
      fenetre. Il n'y a pas d'exclusif plein ecran : Remix presente via DXVK.
    #>
    $res = Get-ResolutionList

    if (-not $script:GuiBox) {
        Write-Host ''
        Say (T2 "  Mode d'affichage :" "  Display mode:") White
        Say (T2 "    1. Plein ecran sans bordure  (recommande)" "    1. Borderless fullscreen  (recommended)") DarkGray
        Say (T2 "    2. Fenetre" "    2. Windowed") DarkGray
        $m = Read-Host (T2 "  Choix [1]" "  Choice [1]")
        $mode = if ($m.Trim() -eq '2') { 'windowed' } else { 'borderless' }

        Write-Host ''
        Say (T2 "  Resolution de rendu :" "  Render resolution:") White
        for ($i = 0; $i -lt $res.Count; $i++) {
            Say ("    $($i + 1). $($res[$i].W) x $($res[$i].H)   [$($res[$i].Tag)]") DarkGray
        }
        Say (T2 "    0. Autre (saisie manuelle)" "    0. Other (type it in)") DarkGray
        $c = (Read-Host (T2 "  Choix [1]" "  Choice [1]")).Trim()
        if ($c -eq '0') {
            $w = Read-Host (T2 "  Largeur" "  Width")
            $h = Read-Host (T2 "  Hauteur" "  Height")
        } else {
            $i = 0
            if ($c -match '^\d+$' -and [int]$c -ge 1 -and [int]$c -le $res.Count) { $i = [int]$c - 1 }
            $w = $res[$i].W; $h = $res[$i].H
        }

        Write-Host ''
        Say (T2 "  Appliquer aussi les shaders atidx10 ? Corrige normales, ombres et reflets," `
                "  Also apply the atidx10 shaders? Fixes normals, shadows and reflections,") White
        Say (T2 "  mais ecrase ceux du fork FusionFix. Sauvegarde automatique." `
                "  but overwrites the FusionFix fork's own. Backed up automatically.") DarkGray
        $sh = (Read-Host (T2 "  o / N" "  y / N")).Trim().ToLower()
        $shaders = ($sh -eq 'o' -or $sh -eq 'y')

        return @{ Mode = $mode; Width = [int]$w; Height = [int]$h; Shaders = $shaders }
    }

    # ---- version graphique
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $bg     = [System.Drawing.ColorTranslator]::FromHtml('#1B1F26')
    $panel  = [System.Drawing.ColorTranslator]::FromHtml('#252A33')
    $fgc    = [System.Drawing.ColorTranslator]::FromHtml('#E6E9EF')
    $dimc   = [System.Drawing.ColorTranslator]::FromHtml('#98A2B3')

    $dlg                 = New-Object System.Windows.Forms.Form
    $dlg.Text            = (T2 'Affichage' 'Display')
    $dlg.Size            = New-Object System.Drawing.Size(440, 320)
    $dlg.StartPosition   = 'CenterParent'
    $dlg.FormBorderStyle = 'FixedDialog'
    $dlg.MaximizeBox     = $false
    $dlg.MinimizeBox     = $false
    $dlg.BackColor       = $bg
    $dlg.ForeColor       = $fgc

    $l1           = New-Object System.Windows.Forms.Label
    $l1.Text      = (T2 'Mode' 'Mode')
    $l1.Location  = New-Object System.Drawing.Point(20, 20)
    $l1.AutoSize  = $true
    $l1.ForeColor = $dimc
    $dlg.Controls.Add($l1)

    $cbMode               = New-Object System.Windows.Forms.ComboBox
    $cbMode.Location      = New-Object System.Drawing.Point(20, 42)
    $cbMode.Size          = New-Object System.Drawing.Size(380, 26)
    $cbMode.DropDownStyle = 'DropDownList'
    $cbMode.BackColor     = $panel
    $cbMode.ForeColor     = $fgc
    [void]$cbMode.Items.Add((T2 'Plein ecran sans bordure  (recommande)' 'Borderless fullscreen  (recommended)'))
    [void]$cbMode.Items.Add((T2 'Fenetre' 'Windowed'))
    $cbMode.SelectedIndex = 0
    $dlg.Controls.Add($cbMode)

    $l2           = New-Object System.Windows.Forms.Label
    $l2.Text      = (T2 'Resolution de rendu' 'Render resolution')
    $l2.Location  = New-Object System.Drawing.Point(20, 84)
    $l2.AutoSize  = $true
    $l2.ForeColor = $dimc
    $dlg.Controls.Add($l2)

    $cbRes               = New-Object System.Windows.Forms.ComboBox
    $cbRes.Location      = New-Object System.Drawing.Point(20, 106)
    $cbRes.Size          = New-Object System.Drawing.Size(380, 26)
    $cbRes.DropDownStyle = 'DropDown'
    $cbRes.BackColor     = $panel
    $cbRes.ForeColor     = $fgc
    foreach ($r in $res) { [void]$cbRes.Items.Add("$($r.W) x $($r.H)   [$($r.Tag)]") }
    $cbRes.SelectedIndex = 0
    $dlg.Controls.Add($cbRes)

    $hint           = New-Object System.Windows.Forms.Label
    $hint.Text      = (T2 'Tu peux aussi taper une resolution, par exemple 3440 x 1440.' `
                          'You can also type a resolution, for example 3440 x 1440.')
    $hint.Location  = New-Object System.Drawing.Point(20, 136)
    $hint.Size      = New-Object System.Drawing.Size(380, 20)
    $hint.ForeColor = $dimc
    $dlg.Controls.Add($hint)

    $chk           = New-Object System.Windows.Forms.CheckBox
    $chk.Text      = (T2 'Appliquer les shaders atidx10 (normales, ombres, reflets)' `
                         'Apply atidx10 shaders (normals, shadows, reflections)')
    $chk.Location  = New-Object System.Drawing.Point(20, 166)
    $chk.Size      = New-Object System.Drawing.Size(390, 22)
    $chk.ForeColor = $fgc
    $dlg.Controls.Add($chk)

    $warn           = New-Object System.Windows.Forms.Label
    $warn.Text      = (T2 'Ecrase ceux du fork FusionFix. Sauvegarde automatique.' `
                          "Overwrites the FusionFix fork's own. Backed up automatically.")
    $warn.Location  = New-Object System.Drawing.Point(40, 188)
    $warn.Size      = New-Object System.Drawing.Size(370, 20)
    $warn.ForeColor = $dimc
    $dlg.Controls.Add($warn)

    $ok              = New-Object System.Windows.Forms.Button
    $ok.Text         = (T2 'Appliquer' 'Apply')
    $ok.Location     = New-Object System.Drawing.Point(220, 226)
    $ok.Size         = New-Object System.Drawing.Size(90, 32)
    $ok.FlatStyle    = 'Flat'
    $ok.BackColor    = [System.Drawing.ColorTranslator]::FromHtml('#2D6CDF')
    $ok.ForeColor    = $fgc
    $ok.DialogResult = 'OK'
    $dlg.Controls.Add($ok)

    $ko              = New-Object System.Windows.Forms.Button
    $ko.Text         = (T2 'Annuler' 'Cancel')
    $ko.Location     = New-Object System.Drawing.Point(318, 226)
    $ko.Size         = New-Object System.Drawing.Size(90, 32)
    $ko.FlatStyle    = 'Flat'
    $ko.BackColor    = $panel
    $ko.ForeColor    = $fgc
    $ko.DialogResult = 'Cancel'
    $dlg.Controls.Add($ko)

    $dlg.AcceptButton = $ok
    $dlg.CancelButton = $ko

    # Sans proprietaire, 'CenterParent' se comporte mal et la boite peut s'ouvrir
    # DERRIERE la fenetre principale : l'utilisateur croit que rien ne se passe.
    if ($script:GuiForm) {
        $r = $dlg.ShowDialog($script:GuiForm)
    } else {
        $dlg.StartPosition = 'CenterScreen'
        $dlg.TopMost = $true
        $r = $dlg.ShowDialog()
    }
    if ($r -ne [System.Windows.Forms.DialogResult]::OK) { return $null }

    $txt = $cbRes.Text
    if ($txt -match '(\d+)\s*[xX]\s*(\d+)') { $w = [int]$Matches[1]; $h = [int]$Matches[2] }
    else { $w = $res[0].W; $h = $res[0].H }

    return @{
        Mode    = if ($cbMode.SelectedIndex -eq 1) { 'windowed' } else { 'borderless' }
        Width   = $w
        Height  = $h
        Shaders = $chk.Checked
    }
}

function Set-IniValue {
    param([string] $Path, [string] $Key, [string] $Value)
    if (-not (Test-Path $Path)) { return $false }
    $t = [IO.File]::ReadAllText($Path)
    if ($t -match ('(?im)^\s*' + [regex]::Escape($Key) + '\s*=')) {
        $t = [regex]::Replace($t, ('(?im)^\s*' + [regex]::Escape($Key) + '\s*=.*$'), "$Key = $Value")
    } else {
        $t = $t.TrimEnd() + "`r`n$Key = $Value`r`n"
    }
    [IO.File]::WriteAllText($Path, $t)
    return $true
}

function Invoke-Repair {
    <#
      .SYNOPSIS  Mode d'affichage, resolution de rendu, shaders, cache DXVK.
      Repond aux trois plaintes les plus frequentes : bloque en 4K, impossible
      de sortir du mode fenetre, et reflets / ombres casses.
    #>
    param($Root)
    Step (T2 "Affichage et reparations" "Display and repairs")

    $opt = Select-DisplayOptions
    if (-not $opt) { Say (T2 "  Annule." "  Cancelled.") DarkGray; return }
    $w = $opt.Width; $h = $opt.Height

    # -- 1. resolution de rendu.
    # comp_settings.toml pilote ce que le mod demande au jeu ; -width/-height
    # pilotent ce que le jeu demande a Windows. Les deux doivent concorder,
    # sinon on retombe sur les plantages DxvkMemoryAllocator au demarrage.
    $toml = Join-Path $Root 'rtx_comp\comp_settings.toml'
    if (Test-Path $toml) {
        $t = [IO.File]::ReadAllText($toml)
        $t = [regex]::Replace($t, 'manual_game_resolution_enabled\s*=\s*\w+', 'manual_game_resolution_enabled = true')
        $t = [regex]::Replace($t, 'manual_game_resolution\s*=\s*\[[^\]]*\]', ('manual_game_resolution = [ {0}.00, {1}.00 ]' -f $w, $h))
        [IO.File]::WriteAllText($toml, $t)
        Ok (T2 "comp_settings.toml : rendu en ${w}x${h}" "comp_settings.toml: rendering at ${w}x${h}")
    } else {
        Warn (T2 "rtx_comp\comp_settings.toml introuvable -- mod pas installe ?" "rtx_comp\comp_settings.toml not found -- mod not installed?")
    }

    # -- 2. mode d'affichage.
    $cl = Join-Path $Root 'commandline.txt'
    if (Test-Path $cl) {
        $c = [IO.File]::ReadAllText($cl)
        foreach ($flag in '-width\s+\d+', '-height\s+\d+', '-windowed') {
            $c = [regex]::Replace($c, ('(?im)^\s*' + $flag + '\s*$\r?\n?'), '')
        }
        $c = $c.TrimEnd() + "`r`n"
        if ($opt.Mode -eq 'windowed') { $c = "-windowed`r`n" + $c }
        $c += "-width $w`r`n-height $h`r`n"
        [IO.File]::WriteAllText($cl, $c)
        Ok (T2 "commandline.txt : -width $w -height $h" "commandline.txt: -width $w -height $h")
    }

    $cfg = Join-Path $Root 'plugins\GTAIV.EFLC.FusionFix.cfg'
    if (Test-Path $cfg) {
        [void](Set-IniValue $cfg 'Windowed' '1')
        [void](Set-IniValue $cfg 'BorderlessWindowed' $(if ($opt.Mode -eq 'windowed') { '0' } else { '1' }))
        if ($opt.Mode -eq 'windowed') { Ok (T2 "Mode fenetre" "Windowed mode") }
        else { Ok (T2 "Mode plein ecran sans bordure" "Borderless fullscreen mode") }
    } else {
        Warn (T2 "plugins\GTAIV.EFLC.FusionFix.cfg introuvable -- mode d'affichage non modifie." "plugins\GTAIV.EFLC.FusionFix.cfg not found -- display mode unchanged.")
    }

    # -- 3. shaders, sur demande seulement.
    # Le dossier 'update' prime sur 'common' : copier dans common\shaders ne
    # sert a rien tant que le fork FusionFix pose ses propres shaders dans
    # update\common\shaders\win32_30. C'est donc celui-la qu'il faut viser.
    if ($opt.Shaders) {
        $from = Join-Path $Root 'common\shaders\win32_30_atidx10'
        $to   = Join-Path $Root 'update\common\shaders\win32_30'
        if (-not (Test-Path $to)) { $to = Join-Path $Root 'common\shaders\win32_30' }
        if ((Test-Path $from) -and (Test-Path $to)) {
            $bak = "$to.backup_gta4rtx"
            if (-not (Test-Path $bak)) {
                Copy-Item -LiteralPath $to -Destination $bak -Recurse -Force
                Ok (T2 "Shaders d'origine sauvegardes" "Original shaders backed up")
            }
            Copy-Item (Join-Path $from '*') $to -Recurse -Force
            Ok (T2 "Shaders atidx10 appliques dans $to" "atidx10 shaders applied to $to")
            Say (T2 "  Pour annuler : remplace ce dossier par $bak" "  To undo: replace that folder with $bak") DarkGray
        } else {
            Warn (T2 "Dossiers de shaders introuvables -- etape ignoree." "Shader folders not found -- step skipped.")
        }
    }

    # -- 4. cache DXVK : un cache ecrit par une autre version du runtime
    # provoque ecran noir et plantages au chargement.
    $cache = Join-Path $Root 'GTAIV.dxvk-cache'
    if (Test-Path $cache) {
        try { Remove-Item -LiteralPath $cache -Force -ErrorAction Stop; Ok (T2 "Cache DXVK vide (il se reconstruira)" "DXVK cache cleared (it rebuilds itself)") }
        catch { Warn (T2 "Cache DXVK verrouille -- ferme le jeu et relance." "DXVK cache locked -- close the game and retry.") }
    }

    Write-Host ''
    Say (T2 "  Relance le jeu." "  Relaunch the game.") DarkGray
}

function Show-Faq {
    Step (T2 "Questions frequentes" "Frequently asked questions")
    $q = @(
        @{ Q = T2 "Le jeu ne demarre pas : 'Could not find grcWindow'." "The game will not start: 'Could not find grcWindow'."
           A = T2 "Ce message est un symptome, pas la cause : le mod attend la fenetre de rendu, que le jeu ne cree jamais. Dans l'ordre : (1) lance le jeu en administrateur ; (2) si tu avais deja FusionFix, supprime TOUS ses fichiers puis reinstalle via ce script ; (3) sors le jeu de Program Files ou du disque systeme -- un joueur a resolu ce cas precis en le deplacant sur un autre disque ; (4) installe le runtime DirectX 9 de juin 2010 ; (5) ferme Medal, Bandicam, RTSS et tout logiciel de capture. L'option Diagnostic lit les logs et dit ou la chaine casse." "This message is a symptom, not the cause: the mod waits for the render window and the game never creates it. In order: (1) run the game as administrator; (2) if you already had FusionFix, delete ALL of its files then reinstall through this script; (3) move the game out of Program Files or off the system drive -- one player fixed this exact case by moving it to another drive; (4) install the June 2010 DirectX 9 runtime; (5) close Medal, Bandicam, RTSS and any capture software. The Diagnostics option reads the logs and tells you where the chain breaks." }
        @{ Q = T2 "Le telechargement echoue toujours vers 50-80 %." "The download keeps failing around 50-80%."
           A = T2 "Le gros paquet de contenu (3,5 Go) vient d'une archive de branche GitHub, qui ne gere pas la reprise : toute coupure repart de zero. Telecharge-le dans ton navigateur, qui sait reprendre un transfert, depose le .zip dans ton dossier Telechargements sans le renommer, et relance ce script : il le ramassera. Sinon, l'installation minimale (option 2) evite ce fichier." "The big content pack (3.5 GB) comes from a GitHub branch archive, which has no resume support: any drop restarts from zero. Download it in your browser, which can resume, drop the .zip in your Downloads folder without renaming it, and re-run this script: it will pick it up. Otherwise the minimal install (option 2) skips that file entirely." }
        @{ Q = T2 "Quelle version du jeu faut-il ?" "Which game version is required?"
           A = T2 "Grand Theft Auto IV: The Complete Edition, exactement 1.2.0.59. Les versions 1.0.7.0 / 1.0.8.0 et 1.2.0.43 ne fonctionnent PAS." "Grand Theft Auto IV: The Complete Edition, exactly 1.2.0.59. Versions 1.0.7.0 / 1.0.8.0 and 1.2.0.43 do NOT work." }
        @{ Q = T2 "Je ne trouve pas le menu Neural Rendering." "I cannot find the Neural Rendering menu."
           A = T2 "Alt+X ouvre le menu simplifie. Il faut basculer sur le menu DEVELOPPEUR, puis Rendering > Post-Processing > Neural Rendering." "Alt+X opens the simplified menu. Switch to the DEVELOPER menu, then Rendering > Post-Processing > Neural Rendering." }
        @{ Q = T2 "J'ai deja FusionFix installe, ca marche ?" "I already have FusionFix installed, will it work?"
           A = T2 "Il faut le FORK RTX, fourni par ce script. Le FusionFix d'origine a des incompatibilites avec Remix et provoque des crashs. Desinstalle-le d'abord." "You need the RTX FORK, shipped by this script. Original FusionFix has Remix incompatibilities and causes crashes. Remove it first." }
        @{ Q = T2 "Mon antivirus dit que c'est un virus." "My antivirus says it is a virus."
           A = T2 "Wacatac.B!ml sur a_gta4-rtx.asi : 4 detections sur 75 sur VirusTotal, toutes heuristiques, aucune signature. Le binaire n'importe aucune API reseau. Il est flagge parce qu'il hooke du D3D9 et s'injecte via un ASI loader - le fonctionnement normal d'un mod graphique." "Wacatac.B!ml on a_gta4-rtx.asi: 4 of 75 detections on VirusTotal, all heuristic, not one signature. The binary imports no network API at all. It is flagged because it hooks D3D9 and injects via an ASI loader - how a graphics mod works." }
        @{ Q = T2 "Puis-je avoir DLSS 5 sans les mods de textures ?" "Can I get DLSS 5 without the texture mods?"
           A = T2 "Oui : option 2 du menu. 549 Mo au lieu de 5,3 Go. Le Compatibility Mod reste indispensable - c'est lui qui cree le pipeline path-trace dans lequel DLSS 5 s'insere." "Yes: menu option 2. 549 MB instead of 5.3 GB. The Compatibility Mod itself is mandatory - it builds the path-traced pipeline DLSS 5 plugs into." }
        @{ Q = T2 "Ca marche sur d'autres jeux DX9 ?" "Does it work on other DX9 games?"
           A = T2 "Non. Chaque jeu compatible RTX Remix a besoin de son propre mod de compatibilite. Celui-ci est specifique a GTA IV." "No. Every RTX Remix game needs its own compatibility mod. This one is specific to GTA IV." }
        @{ Q = T2 "Mes FPS sont tres bas, c'est normal ?" "My FPS is very low, is that normal?"
           A = T2 "Oui. Le path tracing complet est extremement lourd, et le mod est CPU-limite. Ordres de grandeur remontes par les joueurs : RTX 4060 ~18-20 fps, RTX 3090 ~6 fps, RTX 5070 ~20 fps, RTX 5080 ~38 fps. Active la Frame Generation (RTX 40/50 uniquement), baisse la resolution, et mets DLSS en mode Performance." "Yes. Full path tracing is extremely heavy and the mod is CPU-limited. Player-reported ballpark: RTX 4060 ~18-20 fps, RTX 3090 ~6 fps, RTX 5070 ~20 fps, RTX 5080 ~38 fps. Enable Frame Generation (RTX 40/50 only), lower the resolution, set DLSS to Performance." }
        @{ Q = T2 "Ecran noir, mais le HUD et la minimap s'affichent." "Black screen, but HUD and minimap show."
           A = T2 "Remix se charge mais ne rend rien. Verifie que le fork FusionFix est bien installe (option 4 le detecte), supprime GTAIV.dxvk-cache, et relance. Si ca persiste, le log rtx-remix\logs\remix-dxvk.log donnera la cause." "Remix loads but renders nothing. Check the FusionFix fork is installed (option 4 detects this), delete GTAIV.dxvk-cache, relaunch. If it persists, rtx-remix\logs\remix-dxvk.log has the cause." }
        @{ Q = T2 "Le jeu stutter en permanence." "The game stutters constantly."
           A = T2 "Lance-le via _LaunchWithProcessorAffinity_2Cores_GTA4.bat, dans le dossier du jeu. Il donne 2 coeurs au jeu et le reste a Remix." "Launch it through _LaunchWithProcessorAffinity_2Cores_GTA4.bat in the game folder. It gives 2 cores to the game and the rest to Remix." }
        @{ Q = T2 "Un reglage ne s'applique pas." "A setting does not apply."
           A = T2 "user.conf prime sur rtx.conf. Les changements faits en jeu vont dans user.conf et ecrasent le fichier de base. Passe par les menus en jeu, pas par l'edition manuelle." "user.conf overrides rtx.conf. In-game changes are saved to user.conf and override the base file. Use the in-game menus, not manual editing." }
        @{ Q = T2 "Ou va le fichier DLSS 5 ?" "Where does the DLSS 5 file go?"
           A = T2 "nvngx_dlssnr.dll se place dans le sous-dossier .trex du jeu. Ce script ne le fournit pas et ne le telechargera pas." "nvngx_dlssnr.dll goes in the game's .trex subfolder. This script does not ship it and will not download it." }
        @{ Q = T2 "Mes reglages graphiques sont bloques (qualite, filtrage tri-linear)." "My graphics settings are locked (quality, trilinear filtering)."
           A = T2 "GTA IV bride ses menus selon la VRAM qu'il croit voir, et sous Remix il en voit tres peu. Ajoute -availablevidmem 4096 et -nomemrestrict dans commandline.txt. Cela dit, ces reglages ne servent presque plus a rien : c'est Remix qui rend l'image, et tout se regle dans Alt+X." "GTA IV limits its menus based on the VRAM it thinks it sees, and under Remix it sees very little. Add -availablevidmem 4096 and -nomemrestrict to commandline.txt. That said, those settings barely matter any more: Remix does the rendering, and everything is tuned in Alt+X." }
        @{ Q = T2 "Impossible de passer en plein ecran, ou bloque en 4K." "Cannot go fullscreen, or stuck at 4K."
           A = T2 "Option Affichage : elle te fait choisir le mode -- plein ecran sans bordure ou fenetre -- et la resolution de rendu, y compris une saisie libre pour l'ultrawide. Elle ecrit les deux endroits qui comptent : manual_game_resolution dans rtx_comp\comp_settings.toml, et -width / -height plus BorderlessWindowed dans commandline.txt et plugins\GTAIV.EFLC.FusionFix.cfg. Il n'existe pas de vrai plein ecran exclusif : Remix presente via DXVK, le borderless est le mode natif." "Display option: it lets you pick the mode -- borderless fullscreen or windowed -- and the render resolution, with free entry for ultrawide. It writes both places that matter: manual_game_resolution in rtx_comp\comp_settings.toml, and -width / -height plus BorderlessWindowed in commandline.txt and plugins\GTAIV.EFLC.FusionFix.cfg. There is no true exclusive fullscreen: Remix presents through DXVK, borderless is the native mode." }
        @{ Q = T2 "Le jeu plante au bout de quelques minutes." "The game crashes after a few minutes."
           A = T2 "Premiere cause : un logiciel de capture en fond (Medal, Outplayed, Bandicam, RivaTuner). Ferme-les. Ensuite, baisse la distance d'affichage : l'auteur du mod le dit sans detour, ne joue pas avec la qualite et la distance a 100. Enfin, supprime GTAIV.dxvk-cache -- l'option Reparer le fait." "First cause: capture software in the background (Medal, Outplayed, Bandicam, RivaTuner). Close them. Then lower the view distance: the mod author puts it bluntly, do not play with quality and view distance at 100. Finally delete GTAIV.dxvk-cache -- the Repair option does it." }
        @{ Q = T2 "Reflets, ombres ou normales casses." "Broken reflections, shadows or normals."
           A = T2 "Le jeu choisit un jeu de shaders selon le GPU detecte, et sous Remix seule la variante atidx10 est correcte. Case a cocher dans l'option Affichage. Attention : le dossier update prime sur common, donc les shaders sont poses dans update\common\shaders\win32_30 -- copier dans common ne changerait rien. Cela ecrase ceux du fork FusionFix, d'ou la sauvegarde automatique et le fait que ce ne soit pas coche par defaut." "The game picks a shader set from the detected GPU, and under Remix only the atidx10 variant is correct. Checkbox in the Display option. Note: the update folder overrides common, so the shaders go into update\common\shaders\win32_30 -- copying into common would change nothing. It overwrites the FusionFix fork's own, hence the automatic backup and why it is not ticked by default." }
        @{ Q = T2 "Comment desinstaller proprement ?" "How do I cleanly uninstall?"
           A = T2 "L'option Desinstaller de ce script retire tous les fichiers du mod et rend le jeu vanille. Tes sauvegardes ne sont pas touchees. Pour juste couper le mod le temps d'une partie, sans rien supprimer, lance _toggle-gta4-rtx.bat dans le dossier du jeu." "The Uninstall option in this script removes every mod file and returns the game to vanilla. Your saves are untouched. To just switch the mod off for one session without deleting anything, run _toggle-gta4-rtx.bat in the game folder." }
        @{ Q = T2 "Ca tourne sur une RTX 3060 / 3080 ?" "Will it run on an RTX 3060 / 3080?"
           A = T2 "Ca demarre, mais la Frame Generation est reservee aux RTX 40 et 50 : sur une RTX 30 il reste le path tracing brut, autour de 15-25 fps en 1080p avec DLSS Performance. Le Neural Rendering de DLSS 5, lui, demande une RTX 50." "It starts, but Frame Generation is RTX 40 and 50 only: on an RTX 30 you get raw path tracing, roughly 15-25 fps at 1080p with DLSS Performance. DLSS 5 Neural Rendering itself requires an RTX 50." }
    )
    foreach ($x in $q) {
        Write-Host ''
        Say ("  Q. " + $x.Q) White
        Say ("     " + $x.A) DarkGray
    }
}

# ---------------------------------------------------------------- entree

$gui = -not $Console -and -not $VerifyOnly -and -not $Uninstall -and -not $NoContentMods
if (-not $gui) { Banner }

# Mode non interactif : un parametre a ete passe
$direct = $VerifyOnly -or $Uninstall -or $NoContentMods
$game = if ($GamePath) { $GamePath } else { $null }

if (-not $game) {
    if (-not $gui) { Step $L.StepDetect }
    $found = @(Find-GameCandidates)
    if ($gui) { $game = if ($found.Count -gt 0) { $found[0] } else { $null } }
    else      { $game = Resolve-Game }
    if (-not $game -and $gui) {
        Add-Type -AssemblyName System.Windows.Forms
        $d = New-Object System.Windows.Forms.FolderBrowserDialog
        $d.Description = $L.DialogTitle
        if ($d.ShowDialog() -eq 'OK') { $game = $d.SelectedPath }
    }
    if (-not $game) { Bad $L.NoFolder; Quit 1 }
}
$exe = Join-Path $game 'GTAIV.exe'
if (-not (Test-Path $exe)) { Bad ($L.NoExe -f $game); Say "  $($L.NoExeHint)" DarkGray; Quit 1 }
$script:GamePath = $game
$ver = Get-GameVersion $game

function Quit { param([int] $Code = 0) Write-Host ''; Read-Host "  $($L.PressEnter)" | Out-Null; exit $Code }

if ($gui) {
    Show-Gui $game
    exit 0
}

Write-Host ''
Say (T2 "  Jeu detecte :" "  Game detected:") White
Say "    $game" Yellow
if ($ver -eq $REQUIRED_VERSION) { Say ("    " + (T2 "version $ver -- conforme" "version $ver -- OK")) DarkGray }
else { Bad ($L.BadVersion -f $ver, $REQUIRED_VERSION); Say "  $($L.BadVersionHint)" DarkGray }

if ($direct) {
    if ($Uninstall)   { Invoke-Uninstall $game }
    elseif ($VerifyOnly) { Step $L.StepVerify; $m = Invoke-Verify $game; Write-Host ''; if ($m.Core.Count -eq 0) { Ok $L.VerifyOk } else { Warn ($L.VerifyMissing -f $m.Core.Count) } }
    else { Invoke-Install $game $false }
    Quit 0
}

# ---------------------------------------------------------------- menu

while ($true) {
    Write-Host ''
    Write-Host '  --------------------------------------------------------------' -ForegroundColor DarkCyan
    Say (T2 "   1. Installation complete   (path tracing + textures PBR, 5,3 Go)" "   1. Full install        (path tracing + PBR textures, 5.3 GB)") White
    Say (T2 "   2. Installation minimale   (path tracing seul, 549 Mo)" "   2. Minimal install     (path tracing only, 549 MB)") White
    Say (T2 "   3. Verifier l'installation" "   3. Verify installation") White
    Say (T2 "   4. Diagnostic  (ca ne marche pas -- commence ici)" "   4. Diagnose    (something is broken -- start here)") White
    Say (T2 "   5. Affichage   (mode, resolution, shaders, cache)" "   5. Display     (mode, resolution, shaders, cache)") White
    Say (T2 "   6. Desinstaller" "   6. Uninstall") White
    Say (T2 "   7. Questions frequentes" "   7. Frequently asked questions") White
    Say (T2 "   0. Quitter" "   0. Quit") DarkGray
    Write-Host '  --------------------------------------------------------------' -ForegroundColor DarkCyan
    $c = Read-Host (T2 "  Ton choix" "  Your choice")
    switch ($c.Trim()) {
        '1' { Invoke-Install $game $true;  Pause2; Banner }
        '2' { Invoke-Install $game $false; Pause2; Banner }
        '3' { Step $L.StepVerify; $m = Invoke-Verify $game; Write-Host ''
              if ($m.Core.Count -eq 0) { Ok $L.VerifyOk } else { Warn ($L.VerifyMissing -f $m.Core.Count) }
              Pause2; Banner }
        '4' { Invoke-Diagnose $game; Pause2; Banner }
        '5' { Invoke-Repair $game; Pause2; Banner }
        '6' { Invoke-Uninstall $game; Pause2; Banner }
        '7' { Show-Faq; Pause2; Banner }
        '0' { Write-Host ''
              Say ("  " + ($L.FootMod     -f $URL_MOD))     DarkGray
              Say ("  " + ($L.FootDiscord -f $URL_DISCORD)) DarkGray
              Say ("  " + ($L.FootSupport -f $URL_KOFI))    DarkGray
              Write-Host ''
              exit 0 }
        default { }
    }
}
