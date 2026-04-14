# gamemode-steam-fix

![Tested on Fedora 43](https://img.shields.io/badge/tested%20on-Fedora%2043-blue)
![License MIT](https://img.shields.io/badge/license-MIT-green)
![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen)

Fix for `libgamemode.so` dlopen failures when running Steam games via Proton on Fedora Linux.

---

## The Problem

Steam runs games inside a **pressure-vessel** container for runtime isolation.
The container mounts the host filesystem under `/run/host/`, but GameMode's
`libgamemode.so` lives in `/usr/lib64/` — a path the container does not expose
by default.

When a game tries to load GameMode at startup, it fails silently:

```
gamemodeauto: dlopen failed - libgamemode.so: cannot open shared object file: No such file or directory
```

You will see this in `~/.steam/steam/logs/` or via `PROTON_LOG=1` output.

The `gamemoded` daemon is running fine on the host and accepting connections,
but the **in-process client library** (`libgamemode.so`) cannot be loaded
inside the container, so the game never registers with the daemon.

Upstream references:
- [ValveSoftware/steam-runtime](https://github.com/ValveSoftware/steam-runtime)
- [FeralInteractive/gamemode](https://github.com/FeralInteractive/gamemode)

---

## Why This Matters

Without a working `libgamemode.so` inside the container, the game misses all
GameMode optimisations:

- **CPU governor switching** — switches to `performance` governor for the
  duration of the game session (most impactful on CPU-bound titles)
- **Process priority** — raises the game process's `nice` value and
  `SCHED_BATCH` flags
- **I/O priority** — sets `ionice` class for the game process
- **Split-lock mitigation** — disables the kernel's split-lock detection
  to avoid micro-stutter
- **GPU performance mode** — requests high-performance GPU clocks via the
  NVIDIA or AMD driver interface

The daemon (`gamemoded`) is alive and accepting D-Bus connections — GameMode
is not "off". The in-process library injection is what fails, meaning the game
never calls `gamemode_request_start()` and the daemon never applies the
optimisations for that PID.

---

## Prerequisites

- **Fedora** with RPM Fusion enabled
  ([RPM Fusion Steam setup guide](https://rpmfusion.org/Howto/Steam))
- **GameMode** (both 64-bit and 32-bit):
  ```bash
  sudo dnf install gamemode gamemode.i686
  ```
  Package: [src.fedoraproject.org/rpms/gamemode](https://src.fedoraproject.org/rpms/gamemode)
- **Steam** installed via RPM Fusion
- `gamemoderun %command%` already set as a launch option for the game
  (this fix supplements that — it doesn't replace it)

---

## Installation

```bash
git clone https://github.com/atiradonet/gamemode-steam-fix.git
cd gamemode-steam-fix
bash install.sh
```

The script will:
1. Copy `libgamemode.so` (32-bit and 64-bit) into `~/.steam-runtime-libs/gamemode/`
2. Verify ELF classes are correct
3. Print the launch options string to add in Steam

Then add the printed `LD_LIBRARY_PATH` line to each game's **Steam launch options**:

> Steam → Library → Right-click game → Properties → Launch Options

```
LD_LIBRARY_PATH="$HOME/.steam-runtime-libs/gamemode/Lib:$HOME/.steam-runtime-libs/gamemode/Lib64:$LD_LIBRARY_PATH" MANGOHUD=1 gamemoderun %command%
```

---

## Verifying It Works

After launching the game, check the Steam log for a successful registration
line instead of the `dlopen failed` line.

**Failure (before fix):**
```
gamemodeauto: dlopen failed - libgamemode.so: cannot open shared object file: No such file or directory
```

**Success (after fix):**
```
gamemoded: Entering Game Mode...
gamemoded: governor was initially set to [powersave]
gamemoded: Requesting update of governor policy to performance
gamemoded: Requesting update of split_lock_mitigate to 0
```

Check with `journalctl --user -b --no-pager | grep -i gamemode`.

> **Note on ioprio errors:** Lines like `ERROR: Skipping ioprio on client […]: ioprio was (0) but we expected (4)` may appear after the success lines above. These are expected and benign — some short-lived Proton/Wine child processes exit before GameMode can set their I/O priority. The CPU governor switch (the most impactful optimisation) has already succeeded at that point.

You can also query the daemon from a terminal while the game is running:

```bash
gamemoded -s $GAMEPID
```

Replace `$GAMEPID` with the game's process ID (find it with `pgrep -a Fallout4`
or `pgrep -a proton`). If GameMode is active for that PID, the daemon will
report `active`.

---

## Maintenance

After `sudo dnf upgrade` updates the `gamemode` package, re-run:

```bash
bash update-gamemode-libs.sh
```

This compares the installed version against the staged version and re-copies
the libraries only if needed.

Check the currently installed version:
```bash
rpm -q gamemode
```

**Optional automation (dnf post-transaction hook):** You can configure a
`dnf` plugin hook to run `update-gamemode-libs.sh` automatically after any
upgrade that touches `gamemode`. See [`docs/security-notes.md`](docs/security-notes.md)
for the hook configuration and a transparent discussion of the security
tradeoffs before enabling it.

---

## Performance Impact

See [`docs/benchmarks.md`](docs/benchmarks.md) for before/after frame time data.

**Summary:** The primary benefit is reduced **micro-stutter** (1% and 0.1%
lows), not raw average FPS. CPU governor switching has the most measurable
impact on CPU-intensive titles like **DCS World**, **MSFS 2020**, and
**Elite Dangerous**. GPU-limited titles see smaller but consistent
improvements in frame time consistency.

---

## Upstream Fix

This is a **workaround**. The correct fix is for Valve to expose host
`libgamemode.so` inside the pressure-vessel container automatically, so no
user-space staging is needed.

If you want this fixed upstream, please comment or react on the relevant
issue in the Valve steam-runtime tracker:
[github.com/ValveSoftware/steam-runtime/issues](https://github.com/ValveSoftware/steam-runtime/issues)

When Valve ships that fix, this repository becomes unnecessary.

---

## Credits

- **[Arcturis144](https://github.com/Arcturis144/Nobara-Steam-NV-Gamemode-fix)** —
  original research and fix approach
- **[Feral Interactive](https://github.com/FeralInteractive/gamemode)** —
  GameMode
- **[Valve](https://github.com/ValveSoftware/steam-runtime)** —
  Steam, Proton, pressure-vessel

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

Verified test reports from other distributions (Arch, openSUSE, Ubuntu) are
welcome — open an issue with your environment details.
