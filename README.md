# Lightroom Classic MCP

![Lightroom Classic MCP banner](assets/readme-banner.png)

Agentic professional photo editing for **Adobe Lightroom Classic on macOS**.

This project combines a Lightroom Classic plugin bundle and a Python MCP server
so Codex, Claude, and other MCP clients can operate Lightroom through
Lightroom itself. The goal is simple: expose serious editing and catalog
workflows without touching the catalog database directly.

This project is not affiliated with or endorsed by Adobe.

## Install In 2 Minutes

If you want to use this with Codex or Claude, start here:

```bash
git clone https://github.com/4xiomdev/lightroom-classic-mcp.git
cd lightroom-classic-mcp
./scripts/install_for_ai.sh --client both
```

That one command:

- installs the Lightroom plugin bundle
- bootstraps the Python runtime
- registers the MCP server with Codex
- registers the MCP server with Claude

By default, the registered MCP command expects Lightroom to already be open.
That avoids surprising app launches when Codex or Claude probes the server.

Homebrew install:

```bash
brew tap 4xiomdev/tap
brew install lightroom-classic-mcp
lightroom-classic-mcp-install --client both
```

If you prefer the old behavior where the MCP command opens Lightroom for you,
use `--auto-launch` during install.

## Use With Codex

Fast path:

```bash
./scripts/install_for_ai.sh --client codex
```

Manual Codex registration:

```bash
codex mcp add lightroom-classic -- bash -lc 'cd "/absolute/path/to/lightroom-classic-mcp" && ./scripts/start_managed_server.sh'
```

## Use With Claude

Fast path:

```bash
./scripts/install_for_ai.sh --client claude
```

Manual Claude registration:

```bash
claude mcp add -s local lightroom-classic -- bash -lc 'cd "/absolute/path/to/lightroom-classic-mcp" && ./scripts/start_managed_server.sh'
```

More detail: [docs/CLIENT_SETUP.md](docs/CLIENT_SETUP.md)

## Launch Behavior

The MCP wrapper does **not** auto-open Lightroom by default.

That is intentional. During clean-install testing, automatic app launch turned
out to be noisy and surprising, especially when clients probe MCP servers in
the background.

Default behavior:

- open Lightroom yourself
- then let Codex or Claude connect through MCP

If you want the MCP wrapper to launch Lightroom for you, install with:

```bash
./scripts/install_for_ai.sh --client both --auto-launch
```

## Why This Exists

Lightroom Classic is still the center of a lot of real photo workflows, but it
is hard to automate safely from external tools. This project gives an AI agent
a controlled way to:

- inspect the current selection
- read and write metadata
- read and write Develop settings
- apply grouped looks and presets
- work with masks, collections, snapshots, exports, and virtual copies

The key design choice is that Lightroom still performs the actual work. The
Python side acts as a bridge and validation layer, not as a catalog editor.

## What This Feels Like

This is meant to feel like a professional photo editing operator for
Lightroom Classic:

- inspect selected photos and catalog state
- inspect the original file directly from the Lightroom-provided path
- apply structured edit changes safely
- read and write Develop settings through Lightroom
- automate repetitive editing workflows
- stay local, deterministic, and compatible with real Lightroom usage

## Inspection-First Workflow

The preferred workflow is:

1. ask Lightroom for the active photo or current selection
2. use the returned absolute file path to inspect the original image directly
3. decide your edit
4. apply Lightroom changes through MCP
5. export only if you need a rendered before/after or final output

New inspection tools:

- `get_active_photo_file`
- `get_selected_photo_files`

These are read-only MCP tools that return Lightroom metadata plus a normalized
inspection payload:

- absolute file path
- local ID
- filename
- dimensions when available
- file existence / readability / inspectability flags
- basic file metadata like suffix, MIME type, and size when readable

## Example Agent Prompts

Inspect the active image before editing:

```text
Use get_active_photo_file, inspect the image at the returned path, then tell me what edit you would make before changing anything in Lightroom.
```

Snapshot first, then make a targeted edit:

```text
Use get_active_photo_file to inspect the active image, create a Lightroom snapshot, then lift the subject slightly without blowing out highlights.
```

Use export only for verification:

```text
Inspect the active image from its original file path, make the edit in Lightroom, then export a verification JPEG so we can compare before and after.
```

Restore if needed:

```text
If the edit is not an improvement, restore the most recent Lightroom snapshot instead of trying to manually undo each slider.
```

## Who This Is For

- photographers building agentic editing workflows around Lightroom Classic
- creative technologists connecting Codex or Claude to a real editing environment
- developers who want a local-first Lightroom MCP server that is installable and scriptable

## How It Works

`lightroom-classic-mcp` is split into three parts:

1. a Lightroom plugin bundle in `plugin/LightroomMCPCustom.lrplugin`
2. a localhost socket bridge implemented inside Lightroom
3. a Python MCP server in `src/lightroom_mcp_custom/`

When the plugin starts, it opens localhost sockets and writes bridge metadata
to `/tmp/lightroom_mcp_custom_ports.json`. The managed server launcher waits
for that handshake and then starts the MCP server over stdio.

More detail: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

## Requirements

- macOS
- Adobe Lightroom Classic installed locally
- Python `3.10+`
- An MCP client that can launch a local command

## What You Get

- non-destructive Lightroom SDK-driven edits
- localhost-only bridge
- validation before Develop writes
- a one-command managed startup path
- a repo layout that keeps the Lightroom plugin and MCP server together
- direct file-path inspection helpers for active and selected photos

## Repository Layout

- `plugin/LightroomMCPCustom.lrplugin/` - Lightroom plugin bundle
- `src/lightroom_mcp_custom/` - Python MCP server and bridge client
- `scripts/install_plugin.sh` - installs the plugin bundle into Lightroom's plugin folders
- `scripts/start_managed_server.sh` - recommended launcher for daily use
- `scripts/run_server.sh` - starts the MCP server directly
- `scripts/smoke_bridge.py` - verifies local bridge connectivity
- `scripts/print_mcp_config.sh` - prints an MCP config snippet for the current checkout path
- `scripts/package_release.sh` - builds source and plugin zip bundles in `dist/`

## Install From A Release

If you downloaded a release zip instead of cloning the repo:

1. Unzip it anywhere on your Mac.
2. Run `./scripts/install_for_ai.sh --client both`.

If you only want one client, use `--client codex` or `--client claude`.

## Quick Start

1. Clone the repo anywhere on your Mac.

```bash
git clone <your-repo-url>
cd lightroom-classic-mcp
```

2. Run the guided installer.

```bash
./scripts/install_for_ai.sh --client both
```

3. If Lightroom does not already have the plugin loaded:

- Open `File -> Plug-in Manager`
- Add or enable `~/Library/Application Support/Adobe/Lightroom/Modules/LightroomMCPCustom.lrdevplugin`

4. Verify the bridge.

```bash
PYTHONPATH=src python3 scripts/smoke_bridge.py
```

5. Print the MCP config snippet for your actual checkout path.

```bash
./scripts/print_mcp_config.sh
```

6. Use the managed server command in your MCP client.

```bash
./scripts/start_managed_server.sh
```

## Recommended MCP Client Command

The printed config from `scripts/print_mcp_config.sh` is the easiest way to
avoid path mistakes. The generated command uses your current absolute checkout
path and launches the managed server:

```bash
./scripts/start_managed_server.sh
```

That script:

1. refreshes the plugin install
2. checks for a live Lightroom bridge
3. waits for the bridge port file
4. launches the MCP server

## Why The Managed Launcher Matters

The managed launcher is the reason this project behaves reliably on a normal
local Lightroom setup:

- it refreshes the plugin bundle before each run unless you opt out
- it fails fast if Lightroom is closed, unless you explicitly enable auto-launch
- it waits for Lightroom to publish the bridge port file
- it only starts the MCP server after that handshake exists

That preserves the same startup model this project uses successfully in local development.

## Configuration

Optional environment variables:

- `LIGHTROOM_SKIP_INSTALL=1` skips plugin reinstall
- `LIGHTROOM_AUTO_LAUNCH=1` opens Lightroom automatically when the managed server starts
- `LIGHTROOM_FORCE_RESTART=1` force restarts Lightroom before launch
- `LIGHTROOM_WAIT_SECONDS=180` changes the bridge wait timeout
- `LIGHTROOM_ROOT=/custom/path` overrides the default Lightroom support directory during install
- `LIGHTROOM_WRITE_PREFS=0` skips the automatic Lightroom plugin-loader preference update
- `LIGHTROOM_VENV_DIR=/custom/venv/path` overrides the Python runtime location
- `LIGHTROOM_BOOTSTRAP_PYTHON=python3.12` chooses the Python executable used for venv creation

## Safety And Scope

- Python-side validation clamps or rejects invalid Develop settings before they reach Lightroom
- Lightroom writes happen through the Lightroom SDK, not direct `.lrcat` mutation
- The bridge is localhost-only
- This project is intentionally local-first and currently macOS-only
- Snapshot-first is the recommended non-destructive edit pattern, but it is documentation guidance rather than a forced wrapper mode

## Testing

Unit tests run with plain `pytest`.

Live integration tests require a running Lightroom bridge and are opt-in:

```bash
LIGHTROOM_RUN_INTEGRATION=1 pytest -q
```

Without that flag, the integration suite is skipped by default so CI and fresh
contributors do not need Lightroom installed just to contribute.

## Packaging GitHub Releases

To build release bundles:

```bash
./scripts/package_release.sh
```

That creates:

- a source zip for the repo
- a plugin zip containing `LightroomMCPCustom.lrplugin`

Homebrew release notes and packaging guidance live in [docs/DISTRIBUTION.md](docs/DISTRIBUTION.md).


- Lightroom Classic only
- macOS only
- requires the plugin bundle to be installed locally
- live integration tests cannot run in generic CI because they need Lightroom
