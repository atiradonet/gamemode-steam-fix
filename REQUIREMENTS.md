# gamemode-steam-fix — Implementation Requirements

## Project Overview

A repository that documents and fixes the `libgamemode.so` dlopen failure
that occurs when running Steam games via Proton on Fedora Linux. The fix
stages GameMode client libraries in a container-visible path so Steam's
pressure-vessel sandbox can find them.

**Original research credit:** Arcturis144
https://github.com/Arcturis144/Nobara-Steam-NV-Gamemode-fix

**Upstream issue (Valve):** The fix is a workaround pending a proper fix
in pressure-vessel. The ideal upstream resolution is for Valve to expose
host `libgamemode.so` inside the container automatically.

---

## Verified Environment

This fix has been tested and verified on:

- **Hardware:** Razer Blade 16 RZ09-0528, AMD Ryzen AI 9 HX 370, NVIDIA RTX 5090 Max-Q
- **OS:** Fedora Linux 43 (Workstation Edition)
- **Kernel:** 6.19.10-200.fc43.x86_64
- **Steam:** 1.0.0.85 (RPM Fusion)
- **GameMode:** 1.8.2 (Fedora repos)
- **Proton:** Experimental

---

## Repository Structure

```
gamemode-steam-fix/
├── README.md
├── CONTRIBUTING.md
├── LICENSE                         # MIT
├── install.sh                      # One-shot setup script
├── update-gamemode-libs.sh         # Maintenance script (run after dnf upgrades)
├── uninstall.sh                    # Clean removal script
└── docs/
    ├── problem-explained.md        # Deep dive on pressure-vessel isolation
    ├── security-notes.md           # Security considerations for the hook approach
    └── benchmarks.md               # Before/after GameMode performance data (placeholder)
```

---

## File Specifications

### `install.sh`

**Purpose:** One-shot script that stages GameMode libraries in a
container-visible directory and updates Steam launch options guidance.

**Requirements:**
- Must be idempotent (safe to run multiple times)
- Must detect if GameMode is installed before proceeding; exit with clear
  error if not
- Must detect if Steam is installed; warn but do not exit if not
- Must create `~/.steam-runtime-libs/gamemode/Lib` (32-bit)
- Must create `~/.steam-runtime-libs/gamemode/Lib64` (64-bit)
- Must copy libraries using `cp -avL` (resolves symlinks at copy time)
  from `/usr/lib/libgamemode.so*` and `/usr/lib64/libgamemode.so*`
- Must fix symlinks so they resolve *within* the staging directory
  (not back to /usr/lib), using this logic:
  ```bash
  real="$(ls -1 libgamemode.so.* | sort -V | tail -n 1)"
  ln -sf "$real" libgamemode.so.0
  ln -sf libgamemode.so.0 libgamemode.so
  ```
- Must verify ELF class after staging:
  - `Lib/libgamemode.so.0` must be ELF 32-bit
  - `Lib64/libgamemode.so.0` must be ELF 64-bit
  - Print result of verification, exit with error if mismatch
- Must print the Steam launch options string the user needs to add:
  ```
  LD_LIBRARY_PATH="$HOME/.steam-runtime-libs/gamemode/Lib:$HOME/.steam-runtime-libs/gamemode/Lib64:$LD_LIBRARY_PATH" MANGOHUD=1 gamemoderun %command%
  ```
- Must use coloured output (green INFO, yellow WARN, red ERROR) matching
  Proton Pass CLI install script style
- Must not require sudo

**Shell:** bash

---

### `update-gamemode-libs.sh`

**Purpose:** Re-stages libraries after a `dnf upgrade` that updates gamemode.
Should be run manually after upgrades (see security note on hooks).

**Requirements:**
- Same library staging logic as `install.sh`
- Must compare installed gamemode version against staged library version
  and report whether an update was needed
- Must be safe to run as a cron job or manually
- No sudo required
- Print clear summary: "GameMode libs updated from X to Y" or
  "GameMode libs already current (vX)"

**Shell:** bash

---

### `uninstall.sh`

**Purpose:** Removes the staging directory cleanly.

**Requirements:**
- Remove `~/.steam-runtime-libs/gamemode/` only
- Warn if `~/.steam-runtime-libs/` contains other content (don't remove
  the parent)
- Print reminder to remove the LD_LIBRARY_PATH line from Steam launch options
- No sudo required

---

### `README.md`

**Purpose:** The primary user-facing document. Must be clear enough for a
Fedora user who has followed the standard Steam setup guide.

**Required sections (in order):**

#### 1. Title and badges
- Repo name: `gamemode-steam-fix`
- Badges: tested on Fedora 43, License MIT, PRs welcome

#### 2. The Problem
- Explain in plain language: Steam runs games inside a pressure-vessel
  container. The container mounts the host at `/run/host/` but GameMode's
  `libgamemode.so` is not in a path the container exposes.
- Show the error log lines users will recognise:
  ```
  gamemodeauto: dlopen failed - libgamemode.so: cannot open shared object file: No such file or directory
  ```
- Link to: https://github.com/ValveSoftware/steam-runtime (upstream)
- Link to: https://github.com/FeralInteractive/gamemode (GameMode upstream)

#### 3. Why This Matters
- List the GameMode optimisations that are missed without this fix:
  CPU governor switching, process priority, I/O priority, split lock
  mitigation, GPU performance mode request
- Note that gamemoded runs and accepts connections — GameMode is active
  at the daemon level — but the in-process library injection fails,
  so games don't register with the daemon correctly

#### 4. Prerequisites
- Fedora with RPM Fusion enabled
- Link: https://rpmfusion.org/Howto/Steam
- GameMode installed: `sudo dnf install gamemode gamemode.i686`
- Link: https://src.fedoraproject.org/rpms/gamemode (Fedora package)
- Steam installed via RPM Fusion
- `gamemoderun %command%` in Steam launch options for the game

#### 5. Installation
```bash
git clone https://github.com/atiradonet/gamemode-steam-fix.git
cd gamemode-steam-fix
bash install.sh
```
Then add the printed LD_LIBRARY_PATH line to each game's Steam launch options.

#### 6. Verifying It Works
- What to look for in Steam logs to confirm GameMode activated
- Log line that confirms success (contrast with the dlopen failed line)
- How to check with `gamemoded -s $GAMEPID`

#### 7. Maintenance
- Run `update-gamemode-libs.sh` after `sudo dnf upgrade` updates gamemode
- Check current gamemode version: `rpm -q gamemode`
- Note on dnf hooks: explain the optional automation approach and the
  security tradeoff (see `docs/security-notes.md`)

#### 8. Performance Impact
- Link to `docs/benchmarks.md`
- Summary: primary benefit is reduced micro-stutter (1% lows), not raw
  FPS. CPU governor switching most impactful on CPU-intensive titles
  (DCS World, MSFS, Elite Dangerous)

#### 9. Upstream Fix
- This is a workaround. The correct fix is in pressure-vessel.
- Link to Valve steam-runtime issue tracker:
  https://github.com/ValveSoftware/steam-runtime/issues
- Encourage users to upvote or comment on the relevant issue
- When Valve fixes this, this repo becomes unnecessary

#### 10. Credits
- **Arcturis144** — original research and fix approach
  https://github.com/Arcturis144/Nobara-Steam-NV-Gamemode-fix
- Feral Interactive — GameMode
- Valve — Steam, Proton, pressure-vessel

#### 11. Contributing
- Link to CONTRIBUTING.md
- Tested distributions welcome (Arch, openSUSE, Ubuntu)

---

### `CONTRIBUTING.md`

**Requirements:**
- How to report a tested distribution (open an issue with distro, kernel,
  Steam version, GameMode version, result)
- How to submit a fix (fork, branch, PR with test environment documented)
- Note that the goal is upstream resolution via Valve, not permanent
  maintenance of this workaround
- Code style: bash, shellcheck-clean, no external dependencies beyond
  coreutils and `file`

---

### `docs/problem-explained.md`

**Purpose:** Technical deep dive for users who want to understand why
the fix works.

**Must cover:**
- What pressure-vessel is and why Steam uses it
- How `/run/host/` works as the host filesystem mount inside the container
- Why `~/.steam-runtime-libs/` is special (container-exposed user path)
- Why `cp -avL` is used instead of symlinks to `/usr/lib`
- Why both 32-bit and 64-bit libraries are needed (Steam's 32-bit
  compatibility layer)
- The ELF class verification step and what a mismatch means

---

### `docs/security-notes.md`

**Purpose:** Transparent discussion of the security tradeoffs.

**Must cover:**
- The optional dnf post-transaction hook approach (what it is, how it works)
- Why hooks have a bad reputation in security contexts (supply chain attack
  surface, npm post-install analogy)
- Why this specific hook is lower risk (runs after GPG-verified RPM
  transaction, only copies files, no network access)
- Recommendation: manual `update-gamemode-libs.sh` for security-conscious
  users; hook as opt-in for convenience
- Example hook configuration if user chooses to enable it

---

### `docs/benchmarks.md`

**Purpose:** Before/after performance data. Placeholder initially,
populated from real hardware testing.

**Structure:**
- Test environment section (hardware, OS, kernel, driver versions)
- Methodology (MangoHud frame time capture, n=3 runs, same save point)
- Results table: game, metric (avg fps, 1% low, 0.1% low), without GameMode,
  with GameMode, delta %
- Games tested: Fallout 4, Elite Dangerous (placeholder), DCS World
  (placeholder), MSFS 2020 (placeholder)
- Note that results will vary by hardware and game

---

### `LICENSE`

MIT License. Copyright Antonio Tirado.

---

## Implementation Notes for Claude Code

1. All shell scripts must pass `shellcheck` with no warnings
2. Scripts must handle spaces in `$HOME` paths correctly (quote all variables)
3. The `file -L` command is used for ELF verification — ensure it's
   available (part of `file` package, present on all Fedora installs)
4. Do not use `sudo` anywhere — this is a user-space fix
5. The `LD_LIBRARY_PATH` string printed by `install.sh` must use literal
   `$HOME` (not expanded) so users can paste it directly into Steam's
   launch options field
6. All scripts should have a `--help` flag that prints usage
7. README must render correctly on GitHub (test with standard markdown)
8. The repo name on GitHub is `atiradonet/gamemode-steam-fix`

---

## Out of Scope

- Flatpak Steam (different container mechanism, separate problem)
- Non-Fedora distributions (welcome as contributions, not in initial scope)
- MangoHud installation (separate concern, user already has it)
- GameMode installation (prerequisite, not this repo's job)
- Any modification to Steam's runtime files
