# Contributing to gamemode-steam-fix

Thank you for your interest in contributing. This project exists as a
workaround while the correct fix is made upstream in pressure-vessel/Steam.
The goal is to keep it minimal, reliable, and well-documented — not to grow
into a permanent maintenance burden.

---

## Reporting a Tested Distribution

If you have verified that this fix works (or does not work) on a distribution
other than Fedora, please open an issue with the following information:

- **Distribution and version** (e.g. Arch Linux, openSUSE Tumbleweed, Ubuntu 24.04)
- **Kernel version** (`uname -r`)
- **Steam version** (`steam --version` or package version)
- **GameMode version** (`gamemoded --version`)
- **Proton version** used for testing
- **Result**: working / not working / partially working
- **Notes**: anything unusual about your setup or the output of `install.sh`

---

## Submitting a Fix or Improvement

1. Fork the repository and create a branch from `main`
2. Make your changes
3. Test on your hardware — at minimum, run `bash install.sh` and verify that
   a game registers with `gamemoded` successfully
4. Open a pull request with your test environment documented in the PR description
   (same fields as the distribution report above)

---

## Code Style

- **Shell:** bash only (`#!/usr/bin/env bash`)
- **Linting:** all scripts must be clean under `shellcheck` with no warnings
  or errors. Run `shellcheck install.sh update-gamemode-libs.sh uninstall.sh`
  before submitting
- **Dependencies:** coreutils and `file` only — no additional packages,
  no Python, no curl, no external downloads
- **No sudo:** this is a user-space fix; scripts must not require or request
  root privileges
- **Idempotency:** scripts that modify state (`install.sh`,
  `update-gamemode-libs.sh`) must be safe to run multiple times

---

## Scope

This repository is intentionally narrow:

- **In scope:** the library staging mechanism, documentation, and verified
  distribution support
- **Out of scope:** Flatpak Steam, MangoHud installation, GameMode installation,
  any modification to Steam's runtime files

If you have a related but separate fix (e.g. for Flatpak Steam), please
maintain it in a separate repository and we can link to it.

---

## Upstream Goal

The ideal resolution is for Valve to expose host `libgamemode.so` inside the
pressure-vessel container automatically. If that happens, this repository
becomes unnecessary and will be archived. Contributions that help users
understand and track the upstream issue are as valuable as code contributions.
