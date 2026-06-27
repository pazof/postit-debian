# postit-debian

Paquet Debian pour [PostIt.Desktop](../yavsc), le client desktop
Avalonia de la plateforme Yavsc.Org.

Le paquet expose la commande `postit` sur le système, installe
l'entrée `.desktop` dans le menu, et enregistre le scheme URI
`postit://` comme MIME handler (utilisé par l'OIDC Authorization
Code + PKCE pour le hand-off du callback — RFC 8252 §7.1).

Cible : Debian 13 (trixie). Testé également sur Ubuntu 24.04 LTS
(equivalent ABI).

## Construction

Pré-requis :

```bash
sudo apt install build-essential debhelper imagemagick librsvg2-bin \
    dotnet-sdk-10.0 git
```

Sur Debian 13, installer .NET 10 depuis le dépôt officiel Microsoft :

```bash
wget https://packages.microsoft.com/config/debian/13/packages-microsoft-prod.deb \
    -O /tmp/ms-prod.deb
sudo dpkg -i /tmp/ms-prod.deb
sudo apt update
sudo apt install dotnet-sdk-10.0
```

Puis :

```bash
make deb
```

Le `.deb` atterrit dans le répertoire parent (ou `$POSTIT_OUT_DIR`).

Pour bumper la version amont sans modifier ce dépôt :

```bash
make deb POSTIT_GIT_TAG=1.0.1
make deb POSTIT_GIT_URL=https://github.com/fork/yavsc.git POSTIT_GIT_TAG=my-branch
```

## Installation

```bash
sudo apt install ./postit_1.0.0-1_amd64.deb
```

ou directement :

```bash
sudo dpkg -i postit_1.0.0-1_amd64.deb
sudo apt -f install     # résout les dépendances manquantes
```

Pour installer sur **arm64** :

```bash
# Sur une machine arm64 :
make clean && make deb   # le .deb sera _arm64.deb
```

Le `debian/rules` publie avec `--runtime linux-x64` pour
amd64. Pour produire un .deb arm64, override :

```bash
make deb POSTIT_RUNTIME=linux-arm64
```

(le paramètre est exposé par `debian/rules` ; bump à ajouter si
besoin). À noter : **un seul runtime par build** — le `--runtime`
exclut les autres plateformes, donc le .deb est portable mais
mono-architecture.

## Vérification

Après installation :

```bash
$ which postit
/usr/bin/postit
$ postit --help          # (l'application Avalonia ouvre sa fenêtre)
$ xdg-mime query default x-scheme-handler/postit
postit.desktop
$ xdg-open postit://callback?code=test
```

Le scheme handler lance PostIt avec l'URL en argument. En interne,
PostIt (PostIt.Desktop) appelle `SingleInstance.TryHandOffAsync`
puis sort, transferrant l'URL au process PostIt déjà actif via
un named pipe.

## Désinstallation

```bash
sudo apt remove postit
```

Le `postrm` du paquet rafraîchit la base `.desktop`. Le scheme
handler `postit://` n'est pas explicitement désenregistré
(système — par utilisateur c'est `xdg-mime default ...`).

## Maintenance

- Bumper `debian/changelog` à chaque release, conformément à la
  Debian Policy §4.4 (entries datées, signées par le mainteneur).
- Mettre à jour `POSTIT_GIT_TAG` par défaut dans `debian/rules`
  et `Makefile` à chaque release amont.
- Rebuild après changement de licence amont.

## Liens

- [pazof/yavsc](https://github.com/pazof/yavsc) — source amont.
- [doc/postit-oidc.md](https://github.com/pazof/yavsc/blob/main/doc/architecture/postit-oidc.md)
  — flow OIDC + custom URI scheme.
- [Debian Policy Manual](https://www.debian.org/doc/debian-policy/)
  — référence pour la structure d'un paquet.
