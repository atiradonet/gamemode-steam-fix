# Security Notes

This document discusses the security considerations around the optional
automation approach (dnf post-transaction hook) and why the fix itself is
lower risk than it might initially appear.

---

## The Optional dnf Hook

After `sudo dnf upgrade` updates the `gamemode` package, the staged libraries
at `~/.steam-runtime-libs/gamemode/` become stale until you run
`update-gamemode-libs.sh` manually.

For convenience, you can configure a `dnf` post-transaction plugin hook to
run `update-gamemode-libs.sh` automatically whenever `dnf` upgrades the
`gamemode` package. This is **opt-in** and is not configured by `install.sh`.

### Why hooks have a bad reputation

Package manager post-install hooks are a known supply chain attack surface.
The npm ecosystem's `postinstall` scripts are the canonical cautionary tale:
a malicious package can execute arbitrary code with the privileges of the
user running `npm install`. Hooks can exfiltrate credentials, install
backdoors, or corrupt the system.

The general security advice is: don't run untrusted code as a side-effect
of installing packages.

### Why this specific hook is lower risk

This hook has a much smaller attack surface than npm-style hooks:

1. **It runs after GPG-verified RPM transactions.** The `gamemode` package is
   a Fedora/RPM Fusion package signed with the distributor's GPG key. By the
   time the hook runs, `dnf` has already verified the package signature.
   You are not executing code from an untrusted source.

2. **It only copies files.** `update-gamemode-libs.sh` reads from
   `/usr/lib/libgamemode.so*` and `/usr/lib64/libgamemode.so*` (just
   installed by the verified RPM) and copies them to a directory under `$HOME`.
   There are no network requests, no privilege escalation, and no code
   execution beyond file operations.

3. **It runs as your user, not root.** The hook invokes a user-space script.
   Even if somehow compromised, the blast radius is limited to your home
   directory.

4. **The script is version-controlled and auditable.** Unlike an npm
   `postinstall` that downloads and executes a URL, this hook runs a
   specific local script you can read and audit.

### Recommendation

- **Security-conscious users:** run `update-gamemode-libs.sh` manually after
  `sudo dnf upgrade`. This is the recommended default.
- **Convenience-first users:** the hook is a reasonable opt-in given the
  low risk profile described above.

---

## Hook Configuration (opt-in)

If you choose to enable the hook, create a dnf plugin script at
`/etc/dnf/plugins/post-transaction-actions.d/gamemode-libs.action`:

```
gamemode:in:post-transaction:/bin/su -l YOUR_USERNAME -c "/home/YOUR_USERNAME/projects/gamemode-steam-fix/update-gamemode-libs.sh"
```

Replace `YOUR_USERNAME` and the path to `update-gamemode-libs.sh` with your
actual values.

This requires the `dnf-plugin-post-transaction-actions` package:

```bash
sudo dnf install dnf-plugin-post-transaction-actions
```

The action file format is: `package-glob:transaction-state:action-phase:command`.

- `gamemode:in` — trigger when the `gamemode` package is involved
- `post-transaction` — run after the transaction completes
- The command runs as root by default via `su -l` to drop privileges to your user

> **Note:** Because the hook runs as root calling `su`, verify the script
> path and permissions carefully: `chmod 755 update-gamemode-libs.sh` and
> ensure it is not world-writable.

---

## The Fix Itself

The fix places files in `~/.steam-runtime-libs/gamemode/`, a directory under
your home directory. It does not:

- Modify any system files
- Require or use `sudo`
- Open network connections
- Execute any code from the staged libraries

The staged `libgamemode.so` binaries are copies of the RPM-packaged libraries.
Their only effect is to be `dlopen`'d by game processes inside the
pressure-vessel container — the same libraries that `gamemoderun` would use
on a system without the container isolation.
