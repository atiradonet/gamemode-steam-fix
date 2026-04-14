# Why the Fix Works — A Technical Deep Dive

This document explains the root cause of the `libgamemode.so` dlopen failure
and why the library staging approach resolves it.

---

## What is pressure-vessel?

**pressure-vessel** is the container runtime Steam uses to run games via Proton
on Linux. It is a lightweight OCI-like container that provides a consistent,
distribution-independent runtime environment (Steam Linux Runtime) regardless
of what is installed on the host.

Valve ships it primarily to solve the "works on my machine" problem: game
developers can target the Steam Linux Runtime instead of every possible host
distribution. The container bundles a predictable set of libraries and runtime
components.

Steam launches Proton games inside pressure-vessel using `bwrap`
(bubblewrap) to create the sandbox.

---

## How `/run/host/` works

Inside the pressure-vessel container, the host's root filesystem is mounted
read-only at `/run/host/`. This means that from inside the container:

```
/run/host/usr/lib64/libgamemode.so  ← the real host library, visible but not on LD_LIBRARY_PATH
/usr/lib64/...                      ← the container's own runtime libraries
```

The container's dynamic linker (`ld.so`) searches its own `LD_LIBRARY_PATH`
and standard library paths — **not** `/run/host/`. So even though the host
library is technically accessible at `/run/host/usr/lib64/libgamemode.so`,
`dlopen("libgamemode.so", ...)` inside the container will not find it there.

---

## Why `~/.steam-runtime-libs/` is special

Steam's pressure-vessel configuration explicitly bind-mounts certain
user-writable directories into the container so that the container and the
host share them. `~/.steam-runtime-libs/` is one of these
container-exposed user paths.

Files placed here are visible to the container's dynamic linker when their
parent directory is on `LD_LIBRARY_PATH`. This is the mechanism this fix
exploits: by staging `libgamemode.so` under `~/.steam-runtime-libs/gamemode/`
and prepending those paths to `LD_LIBRARY_PATH` in the Steam launch options,
the container can find and load the library.

---

## Why `cp -avL` instead of symlinks to `/usr/lib`

You might think: why not just create symlinks like
`~/.steam-runtime-libs/gamemode/Lib64/libgamemode.so → /usr/lib64/libgamemode.so`?

The problem is path translation. Inside the container, `/usr/lib64/` refers
to the **container's** runtime library directory, not the host's. A symlink
pointing to `/usr/lib64/libgamemode.so` would resolve to the container's
`/usr/lib64/` — which does not contain `libgamemode.so` (it is a host package,
not part of the Steam Linux Runtime).

`cp -avL` dereferences symlinks at copy time, producing actual regular files
in the staging directory. The copied files contain the real library binary.
The symlinks we then create (`libgamemode.so → libgamemode.so.0 → libgamemode.so.X.Y`)
all resolve **within** `~/.steam-runtime-libs/gamemode/`, which is
bind-mounted into the container as a real directory — so these relative
symlinks work correctly both on the host and inside the container.

---

## Why both 32-bit and 64-bit libraries are needed

Proton includes a 32-bit compatibility layer for running Windows games that
were built as 32-bit executables. Even on a 64-bit system, the 32-bit Wine
prefix and its associated processes use 32-bit libraries.

`libgamemodeauto.so` is injected into the game process via `LD_PRELOAD` by
`gamemoderun`. For a 32-bit game process, the injected library must also be
32-bit. For a 64-bit game process, it must be 64-bit.

If only the 64-bit library is staged:
- 64-bit games: work correctly
- 32-bit games: `dlopen` fails (ELF class mismatch — the dynamic linker
  refuses to load a 64-bit `.so` into a 32-bit process)

Both `Lib/` (32-bit, from `/usr/lib/`) and `Lib64/` (64-bit, from `/usr/lib64/`)
must be staged, and both must appear on `LD_LIBRARY_PATH`.

---

## The ELF class verification step

After staging, `install.sh` runs:

```bash
file -L Lib/libgamemode.so.0    # must report: ELF 32-bit
file -L Lib64/libgamemode.so.0  # must report: ELF 64-bit
```

This catches the most common setup mistake: having only `gamemode` (64-bit)
installed and not `gamemode.i686` (32-bit), which leaves `/usr/lib/` without
any `libgamemode.so*` files — or worse, having a stale 64-bit file there from
a previous installation.

If there is a mismatch, the script exits with an error and a clear message
rather than silently staging the wrong binary, which would cause confusing
runtime failures.
