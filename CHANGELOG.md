# Changelog

Toutes les modifications notables du paquet Debian `postit` sont
documentées dans ce fichier.

Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/),
et ce paquet adhère au [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
de l'amont (`pazof/yavsc`). La version du paquet Debian est
`<POSTIT_GIT_TAG>-1` — le suffixe `-1` ne change pas tant que le
packaging lui-même n'évolue pas.

À noter : la **parité du numéro de patch** porte une signification de canal,
partagée avec le dépôt [`pazof/yavsc`](https://github.com/pazof/yavsc) :

- **patch pair** (ex. `1.0.0`, `1.0.2`) → **stable**
- **patch impair** (ex. `1.0.1`, `1.0.3`) → **preview**
- **suffixe** (ex. `1.0.0-rc1`, `1.0.0-alpha`) → **instable**

Cette convention est appliquée par le workflow
`.github/workflows/build-and-release-deb.yml`, qui refuse de publier
une release sans section `## [<tag>] - <canal>` cohérente.

## [Unreleased]

### Added

### Changed

### Fixed

### Removed

## [1.0.6] - stable

### Added
- Paquet Debian `postit` buildé par GitHub Actions via
  `.github/workflows/build-and-release-deb.yml`. Le workflow produit
  deux artefacts `.deb` (linux-x64 et linux-arm64, matrix) à partir
  d'un tag `1.0.6` poussé sur ce dépôt, et publie une GitHub Release
  qui les attache comme assets. La version `1.0.6` correspond au tag
  `1.0.6` de [`pazof/yavsc`](https://github.com/pazof/yavsc) — c'est
  l'amont qui fixe le numéro, ce dépôt ne le bump pas.
