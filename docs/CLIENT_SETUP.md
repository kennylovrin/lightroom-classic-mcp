# Client Setup

The easiest setup path is the guided installer:

```bash
./scripts/install_for_ai.sh --client both
```

That does three things:

1. installs the Lightroom plugin bundle
2. bootstraps the local Python runtime
3. registers the MCP server with Codex and/or Claude

By default, the registered command expects Lightroom Classic to already be
open. This avoids surprising app launches when an MCP client probes the server.

The preferred operating pattern is:

1. open Lightroom
2. call `get_active_photo_file` or `get_selected_photo_files`
3. inspect the original file from the returned absolute path
4. apply Lightroom edits through MCP
5. export only when you need rendered verification or final output

If you want the MCP registration to open Lightroom automatically, use:

```bash
./scripts/install_for_ai.sh --client both --auto-launch
```

## Codex

If you want to configure Codex manually, use:

```bash
codex mcp add lightroom-classic -- bash -lc 'cd "/absolute/path/to/lightroom-classic-mcp" && ./scripts/start_managed_server.sh'
```

Auto-launch variant:

```bash
codex mcp add lightroom-classic --env LIGHTROOM_AUTO_LAUNCH=1 -- bash -lc 'cd "/absolute/path/to/lightroom-classic-mcp" && ./scripts/start_managed_server.sh'
```

Useful commands:

```bash
codex mcp list
codex mcp get lightroom-classic
codex mcp remove lightroom-classic
```

## Claude Code

The installer defaults to Claude's `local` scope, which keeps the server config
private to your local machine in the current project context.

Manual setup:

```bash
claude mcp add -s local lightroom-classic -- bash -lc 'cd "/absolute/path/to/lightroom-classic-mcp" && ./scripts/start_managed_server.sh'
```

Auto-launch variant:

```bash
claude mcp add -s local -e LIGHTROOM_AUTO_LAUNCH=1 lightroom-classic -- bash -lc 'cd "/absolute/path/to/lightroom-classic-mcp" && ./scripts/start_managed_server.sh'
```

If you want the server available more broadly in Claude Code, use `-s user`
instead of `-s local`.

Useful commands:

```bash
claude mcp list
claude mcp get lightroom-classic
claude mcp remove lightroom-classic -s local
```

## Manual Config Snippet

If your MCP client expects a raw command instead of a CLI helper, use:

```bash
bash -lc 'cd "/absolute/path/to/lightroom-classic-mcp" && ./scripts/start_managed_server.sh'
```

You can also print the repo-local JSON snippet with:

```bash
./scripts/print_mcp_config.sh
```

## Example Usage Pattern

Codex / Claude prompt shape:

```text
Use get_active_photo_file first. Inspect the original image from the returned path. Describe the edit plan before changing Lightroom. Create a snapshot, apply the edit, and only export if I ask for verification.
```

This keeps inspection, editing, and export clearly separated.
