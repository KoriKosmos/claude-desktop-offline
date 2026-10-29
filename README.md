# Claude desktop offline installer

A mirror of the Claude desktop app's signed Windows MSIX, so it can be
installed on a machine whose proxy blocks downloads.claude.ai. Keep this repo
**private**.

## Install (offline)

```sh
git clone <this repo>
cd claude-desktop-offline
```

From Command Prompt or PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1        # or: .\install.ps1 3.6556.2
```

`install.ps1` joins the MSIX parts, checks the SHA-256 and the Authenticode
signature (it must be signed by Anthropic), then installs it with
`Add-AppxPackage`. The MSIX installs per-user, so no admin is needed. The
script uses no .NET calls, so it also works in Constrained Language Mode.

The app still needs to reach claude.ai over HTTPS. Only the install is offline.

## Update the mirror (online)

In the repo's **Actions** tab, pick **Mirror > Run workflow**. It runs
`mirror.sh` and commits the latest MSIX. Then `git pull` and run the installer
again to upgrade.

From any machine that can reach downloads.claude.ai:

```sh
./mirror.sh                # latest, x64
./mirror.sh x64 arm64      # chosen architectures
git add releases && git commit -m "Mirror Claude desktop <version>" && git push
```

Each version adds a few hundred MB; delete old `releases/<version>/` folders to
keep the repo small.
