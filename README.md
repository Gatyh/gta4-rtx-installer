# GTA IV — RTX Remix Path Tracing : guide d'installation complet

Installation pas à pas du **GTAIV RTX Remix Compatibility Mod** de [xoxor4d](https://github.com/xoxor4d/gta4-rtx), avec les deux blocages que rencontrent la plupart des gens et que les tutos oublient.

> ⚠️ **Ce guide ne fournit aucune DLL DLSS 5.** Voir la section [DLSS 5](#dlss-5--neural-rendering).

---

## 🚀 Installation automatique (recommandé)

1. Télécharge `INSTALLER.bat` et `Install-GTA4RTX.ps1` — **garde-les dans le même dossier**
2. Double-clique sur **`INSTALLER.bat`**
3. Accepte l'élévation UAC
4. Réponds aux deux questions
5. Attends la fin des téléchargements (~5,3 Go)

Le script liste les installations de GTA IV trouvées avec leur version et te demande laquelle moder, vérifie que c'est bien la `1.2.0.59`, règle les permissions, télécharge les trois mods **avec une barre de progression** (Mo, vitesse, temps restant), installe, puis vérifie les 16 composants.

Il est **bilingue** : français ou anglais selon la langue de Windows.

**Il ne modifie jamais ton antivirus.** Voir [Piège n°2](#piège-n2--windows-defender-met-le-mod-en-quarantaine) — cette commande-là, c'est à toi de la lancer, en connaissance de cause.

```powershell
# Désinstaller proprement — sans droits admin
.\Install-GTA4RTX.ps1 -Uninstall

# Installation minimale : path tracing seul, 549 Mo au lieu de 5,3 Go
.\Install-GTA4RTX.ps1 -NoContentMods

# Vérifier une installation existante — sans droits admin, ne modifie rien
.\Install-GTA4RTX.ps1 -VerifyOnly

# Forcer la langue
.\Install-GTA4RTX.ps1 -Language en

# Forcer le dossier du jeu
.\Install-GTA4RTX.ps1 -GamePath "D:\Jeux\Grand Theft Auto IV"
```

### Installation minimale — `-NoContentMods`

Si tu veux **uniquement le path tracing** (et DLSS 5 si tu as le fichier), sans les packs de textures et de matériaux :

| Couche | Taille | Rôle | Sautable ? |
|---|---|---|---|
| **Compatibility Mod** | 549 Mo | Crée le pipeline Vulkan path-tracé | ❌ **non** |
| base-mod | 4,1 Go | Matériaux PBR, végétation, eau, verre | ✅ |
| AutoPBR | 2,2 Go | PBR automatique sur toutes les textures | ✅ |

Le Compatibility Mod n'est pas un mod visuel : c'est le moteur de rendu. **DLSS 5 s'insère dans le pipeline qu'il fabrique** — sans lui, GTA IV reste un jeu DX9 et il n'y a nulle part où la passe Neural Rendering puisse s'exécuter.

Les deux autres sont du contenu pur. Les sauter donne le path tracing complet sur les textures d'origine, pour **549 Mo au lieu de 5,3 Go**.

> Le script est lisible et court. **Ouvre-le avant de le lancer** — c'est un script qui demande les droits admin, tu as le droit de vouloir savoir ce qu'il fait.

Le reste de ce document décrit l'installation manuelle, ce que fait le script étape par étape, et le dépannage.

---

## Sommaire

- [Prérequis](#prérequis)
- [Téléchargements](#téléchargements)
- [Installation](#installation)
- [Piège n°1 — Permissions NTFS](#piège-n1--permissions-ntfs-rockstar-launcher)
- [Piège n°2 — Windows Defender](#piège-n2--windows-defender-met-le-mod-en-quarantaine)
- [En jeu](#en-jeu)
- [Performance](#performance)
- [DLSS 5 — Neural Rendering](#dlss-5--neural-rendering)
- [Désinstaller](#désinstaller)
- [Dépannage](#dépannage)

---

## 🛡️ Bonus — `Test-GameModdability.ps1`

Avant d'injecter DLSS 5 ou ReShade dans **n'importe quel** jeu, passe-le au scanner :

```powershell
.\Test-GameModdability.ps1 -Path "D:\SteamLibrary\steamapps\common\Mon Jeu"
```

Il analyse le dossier et rend un verdict :

- **Anti-triche** — EasyAntiCheat, BattlEye, Vanguard, Denuvo, nProtect, XignCode, PunkBuster
- **API graphique** et moteur
- **Upscaler présent** → quel mode DLSS 5 s'applique (Direct / OptiScaler / Feeder)
- **Empaquetage Microsoft Store / MSIX**
- **Droits d'écriture**
- **RTX Remix** → te dit que le fichier va dans `.trex\` et qu'il ne faut surtout pas y mettre ReShade

⚠️ **Si un anti-triche est détecté, n'injecte rien.** Injecter dans un processus surveillé peut faire bannir ton compte — et le plus souvent l'anti-triche bloque simplement le lancement, donc tu ne gagnes rien. Choisis un jeu solo : même résultat à l'image, zéro risque.

Le script est en lecture seule, hormis un fichier temporaire pour tester l'écriture. Il ne modifie aucun jeu.

---

## Prérequis

| | |
|---|---|
| **Jeu** | Grand Theft Auto IV: **The Complete Edition**, version **1.2.0.59** exactement |
| **GPU** | NVIDIA RTX. RTX 40/50 recommandé, RTX 30 jouable en basse résolution |
| **Espace disque** | ~30 Go (jeu 22 Go + mods 6,3 Go) |
| **OS** | Windows 10 / 11 64-bit |

**Vérifier la version du jeu :** clic droit sur `GTAIV.exe` → Propriétés → Détails → *Version du fichier*. Ce doit être `1.2.0.59`. Les anciennes versions 1.0.7.0 / 1.0.8.0 conseillées pour le modding classique sont **incompatibles**.

**Lance le jeu une fois en vanille** jusqu'au menu principal, puis quitte. Ça valide que le launcher est connecté, que les redistribuables sont posés et que le jeu de base tourne. Si tu modes avant et que ça plante, tu ne sauras pas d'où ça vient.

---

## Téléchargements

| Fichier | Source | Taille |
|---|---|---|
| `GTAIV-Remix-CompatibilityMod-1.5.1.zip` | [Releases xoxor4d/gta4-rtx](https://github.com/xoxor4d/gta4-rtx/releases) | 549 Mo |
| `gta4-rtx-base-mod` (master.zip) | [Dépôt base-mod](https://github.com/xoxor4d/gta4-rtx-base-mod/archive/refs/heads/master.zip) | ~2,7 Go |
| `gta4-rtx-autopbr-mod` (master.zip) | [Dépôt AutoPBR](https://github.com/xoxor4d/gta4-rtx-autopbr-mod/archive/refs/heads/master.zip) | ~2 Go |

> 💡 **Le fork FusionFix est déjà inclus** dans le zip du CompMod, sous `_installer_options\FusionFix_RTXRemixFork\`. Inutile de le télécharger ailleurs — et surtout, n'installe pas le FusionFix original, il a des incompatibilités avec RTX Remix.

---

## Installation

L'installeur `.exe` fourni fonctionne très bien. Ce guide décrit l'**installation manuelle**, plus transparente et plus facile à déboguer.

Appelons `[JEU]` le dossier qui contient `GTAIV.exe`.

**1. Compatibility Mod** — copier tout le contenu de `GTAIV-Remix-CompatibilityMod\` vers `[JEU]\`

**2. Fork FusionFix** — copier tout le contenu de `_installer_options\FusionFix_RTXRemixFork\` vers `[JEU]\`

**3. Mode d'affichage** — copier tout le contenu de `_installer_options\mode_fullscreen\` vers `[JEU]\`
*(borderless fullscreen + intro skippée. Prendre `mode_windowed` pour du fenêtré.)*

**4. Base mod** — le dossier `mods\gta4rtx\` de l'archive vers `[JEU]\rtx-remix\mods\gta4rtx\`

**5. AutoPBR** — le dossier `mods\z_gta4rtx_autopbr\` de l'archive vers `[JEU]\rtx-remix\mods\z_gta4rtx_autopbr\`

### Arborescence finale

```
[JEU]\
├── GTAIV.exe
├── a_gta4-rtx.asi          ← le mod
├── d3d9.dll                ← bridge Remix
├── dinput8.dll             ← Ultimate ASI Loader
├── rtx.conf  dxvk.conf  commandline.txt
├── _toggle-gta4-rtx.bat
├── .trex\                  ← runtime Remix (NvRemixBridge.exe, DLL NGX)
├── plugins\                ← FusionFix
├── update\                 ← remix_fixes, light_tweaks, FusionFix .img
└── rtx-remix\mods\
    ├── gta4rtx\            ← base mod
    └── z_gta4rtx_autopbr\  ← AutoPBR
```

**Aucun fichier d'origine du jeu n'est écrasé.** Tout est ajouté.

---

## Piège n°1 — Permissions NTFS (Rockstar Launcher)

**Symptôme :** « Accès refusé » en copiant les fichiers, alors que tu es admin de ta machine.

**Cause :** le Rockstar Launcher installe le jeu avec des droits restreints. Le dossier appartient à `BUILTIN\Administrateurs` et ton compte n'a que `ReadAndExecute`.

**Correctif** — PowerShell **en administrateur** :

```powershell
icacls "C:\Chemin\Vers\Grand Theft Auto IV" /grant "$env:COMPUTERNAME\$env:USERNAME:(OI)(CI)M" /T
```

Ce n'est pas optionnel : RTX Remix écrit ses caches de shaders, ses logs et `user.conf` dans le dossier du jeu **pendant que tu joues**. Même une install faite en admin planterait ensuite.

Pour annuler : `icacls "chemin" /remove "$env:COMPUTERNAME\$env:USERNAME" /T`

---

## Piège n°2 — Windows Defender met le mod en quarantaine

**Symptôme :** `a_gta4-rtx.asi` disparaît juste après l'extraction. Le jeu se lance en vanille.

**Détection :** `Trojan:Win32/Wacatac.B!ml`

**C'est un faux positif.** Les éléments vérifiables, plutôt qu'une simple affirmation :

- Le suffixe **`!ml`** = détection par machine learning, la classe de plus faible confiance de Defender.
- Sur **VirusTotal : 4 détections sur 75**, et les 4 sont des heuristiques — Microsoft (`!ml`), Cynet (`score: 100`, sans nom de famille), McAfeeD (`ti!` suivi du hash du fichier), VBA32 (`BScope.`, son préfixe heuristique). **Aucune signature.**
- **Propres :** Kaspersky, BitDefender, ESET, Avast, AVG, Symantec, Sophos, TrendMicro, F-Secure, Malwarebytes, SentinelOne, Google, Fortinet, Panda, GData, Emsisoft.
- Analyse statique du binaire : **zéro API réseau importée**, zéro résolue dynamiquement, aucune IP, aucun domaine, aucune injection dans un autre processus, aucune persistance, non packé (entropie 6,75). Un binaire sans capacité réseau ne peut rien exfiltrer.
- Les 36 URLs qu'il contient sont les dépôts GitHub des bibliothèques créditées (imgui, minhook, toml11, rapidjson, miniz, rtx-remix…).

**Pourquoi c'est flaggé :** DLL x86 non signée, qui hooke des appels D3D9 (`VirtualProtect` + `LoadLibrary` + `GetProcAddress`) et s'injecte dans un autre processus via un ASI loader. C'est le profil comportemental d'un injecteur — sauf que c'est simplement comment fonctionne un mod graphique.

**Correctif** — PowerShell **en administrateur**, puis relancer l'installeur (les archives restent en cache) :

```powershell
Add-MpPreference -ExclusionPath "C:\Chemin\Vers\Grand Theft Auto IV\a_gta4-rtx.asi"
```

Pour annuler : `Remove-MpPreference -ExclusionPath "...\a_gta4-rtx.asi"`

> Vérifie par toi-même plutôt que de me croire : `Get-FileHash "a_gta4-rtx.asi" -Algorithm SHA256`, puis colle le hash dans la recherche VirusTotal.

### Pourquoi l'installeur ne le fait pas à ta place

Une première version du script ajoutait l'exclusion automatiquement. **Windows l'a bloquée :**

```
Ce script dont le contenu est malveillant a été bloqué par votre logiciel antivirus.
FullyQualifiedErrorId : ScriptContainedMaliciousContent
```

C'est **AMSI**, l'analyse de scripts intégrée à Windows. Aucun élément pris isolément ne déclenchait — j'ai vérifié un par un. C'est la *combinaison* qui est flaggée : élévation UAC + téléchargement depuis Internet + écriture dans un dossier de jeu + **modification des réglages antivirus** + extraction d'archives. C'est le profil exact d'un dropper.

Retirer l'appel `Add-MpPreference` du script lève le blocage. Aucune obfuscation, aucun contournement d'AMSI : le script ne fait simplement plus la chose qui pose problème.

**Et c'est mieux ainsi.** Un installeur téléchargé sur Internet qui modifie ton antivirus sans que tu tapes la commande toi-même, ce n'est pas un comportement à normaliser — même quand l'intention est bonne. Le script t'affiche la commande exacte, avec les preuves du faux positif ; tu décides.

---

## En jeu

| Touche | Menu |
|---|---|
| **Alt+X** | RTX Remix — path tracing, DLSS, Ray Reconstruction, Frame Generation |
| **F4** | Compatibility Mod — culling, lumières, ciel, timecycle |

**Le premier lancement est lent et saccadé** : compilation des shaders. Laisse tourner 5 minutes avant de juger quoi que ce soit.

**À activer en priorité :**

- **DLSS Ray Reconstruction** (RR 4.5) — le débruiteur. Sur une image path-tracée c'est lui qui fait la plus grosse différence visuelle.
- **Frame Generation** — RTX 40/50 uniquement. Quasi obligatoire, le mod est CPU-limité.

### ⚠️ `user.conf` prime sur `rtx.conf`

Les réglages changés dans les menus sont sauvés dans `user.conf`, qui **écrase** `rtx.conf`. Si tu édites `rtx.conf` à la main et que rien ne change, c'est ça. Passe par les menus.

### Stuttering

```
_LaunchWithProcessorAffinity_2Cores_GTA4.bat            → 2 cœurs au jeu, le reste à Remix
_LaunchWithProcessorAffinity_Half_GTA4__Half_Remix.bat  → répartition 50/50
```

---

## Performance

Le mod est **CPU-limité** — la quantité de meshes détaillés que le jeu envoie sature un cœur avant que le GPU ne sature. Un CPU à forte performance mono-cœur aide plus qu'un gros GPU.

| GPU | À quoi s'attendre |
|---|---|
| RTX 50 | Confortable, Frame Gen + Multi-Frame Gen |
| RTX 40 | Bon, Frame Gen disponible |
| RTX 30 | Jouable en basse résolution, **pas de Frame Generation** (RTX 40+ uniquement) |
| RTX 20 | Non recommandé |

Défauts connus et assumés par l'auteur : stuttering en traversant la ville, pas de sang sur les PNJ.

---

## DLSS 5 — Neural Rendering

Le CompMod **1.5.1 intègre nativement** la passe DLSS-NR. Tout est déjà là : le runtime Remix compilé avec l'intégration, l'interface, le trampoline `remix_nvngx.dll`.

Il manque un seul fichier : **`nvngx_dlssnr.dll`**, qui va dans `[JEU]\.trex\`.

**Ce fichier n'est pas fourni ici, et il n'y aura pas de lien.** DLSS 5 n'est pas sorti — NVIDIA l'annonce pour l'automne 2026, exclusif RTX 50. Toutes les copies en circulation viennent d'un leak. xoxor4d fait le même choix dans ses releases : *« This release does not ship any unofficial dll's »*.

Sans le fichier, le menu affiche `Unavailable: nvngx_dlssnr.dll was not found next to [JEU]\.trex\`. Ce n'est pas un bug, c'est l'état normal.

**Rien d'autre n'est nécessaire.** Pas de ReShade, pas de RenoDX, pas de Streamline, pas d'OptiScaler, pas de swapper. Ces outils servent aux jeux **sans** intégration native — les utiliser ici risque d'écraser les DLL du runtime Remix et de casser une install qui fonctionne.

---

## Désinstaller

```
_toggle-gta4-rtx.bat    → désactive / réactive le mod en renommant 4 fichiers
```

Suppression complète : effacer `d3d9.dll`, `a_gta4-rtx.asi`, `dinput8.dll`, `.trex\`, `rtx_comp\`, `rtx-remix\`, `plugins\`, `update\`, et les `.img` commençant par `1__remix`.

---

## Dépannage

| Symptôme | Piste |
|---|---|
| Le jeu se lance en vanille | `a_gta4-rtx.asi` absent → Piège n°2 |
| « Accès refusé » à l'install | Piège n°1 |
| Plante avant le menu | Version du jeu ≠ 1.2.0.59, ou FusionFix original installé |
| Plante au chargement | Vider `GTAIV.dxvk-cache`, relancer |
| Stuttering permanent | `_LaunchWithProcessorAffinity_2Cores_GTA4.bat` |
| Un réglage ne s'applique pas | `user.conf` prime sur `rtx.conf` |

Logs : `[JEU]\rtx-remix\logs\remix-dxvk.log`, `bridge32.log`, `bridge64.log`

---

## Crédits

- **[xoxor4d](https://github.com/xoxor4d)** — Compatibility Mod, base mod, AutoPBR. Tout le travail est le sien.
- [NVIDIA RTX Remix](https://github.com/NVIDIAGameWorks/rtx-remix)
- [ThirteenAG](https://github.com/ThirteenAG/GTAIV.EFLC.FusionFix) — FusionFix
- Discord officiel du mod : https://discord.gg/FMnfhpfZy9

Ce dépôt n'est qu'un guide d'installation. Va soutenir xoxor4d sur [Ko-fi](https://ko-fi.com/xoxor4d) ou [Patreon](https://patreon.com/xoxor4d).
