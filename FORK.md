# Running this fork with its own binaries

This repository is a fork of [Servosity/msp-skills](https://github.com/Servosity/msp-skills).
Its installers download binaries from **this fork's** GitHub Releases, not upstream's:

- every `skills/<slug>/install.sh` and `install.ps1` defaults to `MSP_SKILLS_OWNER=prajwalstark`
- `skills/connect-tool/bootstrap.sh` and `bootstrap.ps1` pull connect-tool from this fork

Setting `MSP_SKILLS_OWNER=servosity` before running an installer still installs
upstream's binaries.

The README and per-skill docs are generated from upstream and still show
`raw.githubusercontent.com/Servosity/...` install URLs. Those fetch upstream's
installer, which installs upstream's binaries. To get this fork's binaries, fetch
the installer from this fork instead (see "Install" below).

## One-time GitHub setup

1. **Enable Actions.** Settings > Actions > General > allow actions. GitHub keeps
   a fork's workflows off until you do.
2. **Enable immutable releases.** Settings > General > Releases > Immutable releases.
   The installers refuse any release that is not sealed. Without this, every user
   would need `MSP_SKILLS_ALLOW_MUTABLE=1`.
3. **Disable "MCP Registry Publish".** Actions > MCP Registry Publish > ... > Disable
   workflow. It publishes to the public MCP Registry under the `io.github.Servosity`
   namespace, which this fork cannot (and should not) write to.

## Cut releases

From a clean checkout of `main`, after the setup above:

```bash
tools/maintainer/fork_release.sh origin/main               # all 67 connectors
tools/maintainer/fork_release.sh origin/main servosity     # or just some
```

Each tag starts one run of the Release workflow, which builds 6 targets
(linux, macOS, windows x amd64, arm64) plus an `.mcpb` bundle into a draft,
checks the set is complete, and only then publishes. A release that fails
mid-way stays a draft: re-run the Release workflow for that tag. Never delete a
published release and re-cut the same version; bump the version instead
(`tools/maintainer/release_batch.sh --slug <slug>`).

Until a connector has a published release here, `tools/maintainer/verify_all.sh`
reports its "install.sh URL" check as FAIL ("No <slug>-v* release found ... of
prajwalstark/msp-skills"). That is accurate, not a bug: it turns PASS once the
release exists.

Check for releases that never finished (expect no output):

```bash
gh api repos/prajwalstark/msp-skills/releases --paginate -q '.[] | select(.draft) | .tag_name'
```

## Install

macOS / Linux / WSL:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/prajwalstark/msp-skills/main/skills/servosity/install.sh)
```

Windows PowerShell:

```powershell
iwr -useb https://raw.githubusercontent.com/prajwalstark/msp-skills/main/skills/servosity/install.ps1 | iex
```

Swap `servosity` for any connector slug.

## Pulling upstream changes

```bash
git remote add upstream https://github.com/Servosity/msp-skills.git
git fetch upstream && git merge upstream/main
```

If upstream regenerates the installers, a merge conflict on the `OWNER` line is
expected: keep `prajwalstark`, then confirm all installers still match with
`python3 tools/maintainer/installer_fixtures/render_fleet.py --check`.
