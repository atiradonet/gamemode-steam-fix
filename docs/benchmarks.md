# Performance Benchmarks

Before/after frame time data for GameMode via the library staging fix.
Results are from real hardware testing; placeholder entries will be filled
as testing is completed.

---

## Test Environment

| Component | Detail |
|---|---|
| Hardware | Razer Blade 16 RZ09-0528 |
| CPU | AMD Ryzen AI 9 HX 370 (12 cores, 24 threads) |
| GPU | NVIDIA GeForce RTX 5090 Max-Q (24GB VRAM) |
| iGPU | AMD Radeon 890M |
| RAM | 32GB |
| Storage | Lexar NM790 2TB NVMe (btrfs) |
| OS | Fedora Linux 43 (Workstation Edition) |
| Kernel | 6.19.10-200.fc43.x86_64 |
| NVIDIA Driver | 580.126.18 |
| GameMode | 1.8.2 |
| Steam | 1.0.0.85 |
| Proton | Experimental |

---

## Methodology

- **Frame capture:** MangoHud with `output_folder` set to capture CSV data
- **Runs:** n=3 per condition (GameMode disabled / GameMode enabled via fix)
- **Starting point:** same in-game save point or reproducible starting area
- **Warm-up:** 60-second discard before capture begins
- **Metrics captured:**
  - Average FPS
  - 1% low (99th percentile frame time expressed as FPS)
  - 0.1% low (99.9th percentile frame time expressed as FPS)
- **Conditions kept constant:** display resolution, graphics preset, no
  background applications beyond Steam and MangoHud

Delta % is calculated as `(with - without) / without × 100`. Positive = improvement.

---

## Results

### Fallout 4 (via Proton Experimental)

| Metric       | Without GameMode | With GameMode | Delta  |
|--------------|-----------------|---------------|--------|
| Avg FPS      | 118             | 121           | +2.5%  |
| 1% low       | 74              | 89            | +20.3% |
| 0.1% low     | 51              | 68            | +33.3% |

> The raw FPS improvement is modest. The significant gain is in the 1% and
> 0.1% lows — GameMode's CPU governor switching and split-lock mitigation
> directly reduce the brief stalls that cause visible micro-stutter.

---

### Elite Dangerous (via Proton Experimental)

_Testing in progress — results to be added._

---

### DCS World (via Proton Experimental)

_Testing in progress — results to be added._

---

### Microsoft Flight Simulator 2020 (via Proton Experimental)

_Testing in progress — results to be added._

---

## Notes

- Results will vary significantly by hardware. CPU-bound scenarios benefit
  most from governor switching; GPU-bound scenarios see smaller gains.
- The Ryzen AI 9 HX 370 is a hybrid efficiency-core architecture. GameMode's
  scheduler hints have a measurable effect on which cores handle the game
  thread.
- NVIDIA GPU performance mode requests (`GAMEMODE_GPU_PERF_POLICY`) require
  the NVIDIA driver to support the interface. Gains in GPU-bound scenarios
  depend on whether the driver was already in high-performance mode.
- MangoHud itself has a small (<1%) overhead on CPU frametimes. Both
  conditions include MangoHud, so the comparison is fair.

---

## Compatibility Matrix

GameMode activation confirmed via `journalctl --user` log output.
Success indicator: `Entering Game Mode... Requesting update of governor policy to performance`

| Game | Engine | Native/Proton | CPU/GPU Bound | GameMode Confirmed | Notes |
|---|---|---|---|---|---|
| Winter Burrow | Unity | Native | CPU light | ✅ | |
| Fallout 4 | Gamebryo | Proton | CPU bound | ✅ | |
| Doom Eternal | id Tech 7 | Native Linux | GPU bound | ✅ | Native Linux via SteamLinuxRuntime_sniper container. LD_LIBRARY_PATH fix required. |
| Batman: Arkham Origins | Unreal Engine 3 | Proton | GPU bound | ✅ | Confirmed on two separate runs. First run after Doom Eternal may fail due to GameMode cleanup timing — relaunch if needed. |
| Elite Dangerous | Cobra | Proton | CPU bound | ⏳ Pending | |
| DCS World | DCS Engine | Proton | CPU heavy | ⏳ Pending | |
| Mass Effect Legendary Edition | Unreal Engine 3/4 | Proton | GPU bound | ⏳ Pending | |
| Halo: The Master Chief Collection | Various | Proton | Mixed | ⏳ Pending | |
| STAR WARS Squadrons | Frostbite | Proton | GPU bound | ⏳ Pending | |
| SnowRunner | Swarm Engine | Proton | CPU bound | ⏳ Pending | |
| War Thunder | Dagor Engine | Native Linux | Mixed | ⏳ Pending | |
| Icewind Dale: Enhanced Edition | Infinity Engine | Proton | CPU light | ⏳ Pending | |
| Flashback | Custom | Proton | CPU light | ⏳ Pending | |
| Microsoft Flight Simulator 2020 | Asobo Engine | Proton | CPU heavy | ⚠️ Partial | Two-stage launcher — gamemoderun covers the launcher process but not the FlightSimulator.exe sim process. Known limitation with external launcher games. |

Benchmark frame time data (avg FPS, 1% lows, 0.1% lows) will be added progressively as testing continues. CPU-intensive titles (DCS World, Elite Dangerous) are expected to show the most measurable improvement in frame time consistency.

---

Tested on different hardware? Open an issue or PR with your compatibility results. Include your distro, kernel, GPU, GameMode version, and game.

---

## Known Limitations

### Games with external launchers
Some games use a two-stage launch process where Steam launches a launcher binary,
which then spawns the actual game executable. `gamemoderun` wraps the launcher
but the game process is spawned outside the wrapper chain and does not register
with GameMode.

Affected games confirmed so far:
- Microsoft Flight Simulator 2020

Workaround: none currently. The game still benefits from GameMode optimisations
applied to the launcher process, but the primary game binary does not register.
This is a GameMode/launcher architecture limitation, not a fix issue.

Upstream reference: https://github.com/FeralInteractive/gamemode/issues
