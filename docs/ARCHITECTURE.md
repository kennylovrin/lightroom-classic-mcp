# Architecture

`lightroom-classic-mcp` works well locally because the runtime is split into
three pieces with a clean boundary between them:

1. A Lightroom Classic plugin bundle in `plugin/LightroomMCPCustom.lrplugin`
2. A localhost bridge implemented inside Lightroom with `LrSocket`
3. A Python MCP server that exposes stable tools over stdio

The MCP layer should be thought of as two separate capabilities:

1. Lightroom-backed metadata and editing operations
2. direct file-path inspection that the agent can perform once Lightroom returns the original image path

## Why The Current Setup Is Reliable

### 1. Lightroom owns the catalog writes

The plugin executes mutations inside Lightroom itself, using the SDK and
catalog write gates. That avoids direct `.lrcat` mutation and keeps edits
inside the host application's supported transaction model.

### 2. The Python process never touches Lightroom internals directly

The Python side only speaks JSON over localhost sockets. That keeps the MCP
server simple, avoids application embedding, and makes reconnection logic much
easier to reason about.

It can still return Lightroom-provided absolute file paths so the agent can
inspect originals directly without forcing every visual check through an export.

### 3. The handshake is explicit

When the plugin bridge starts, it writes the active send/receive ports into
`/tmp/lightroom_mcp_custom_ports.json`. The Python bridge waits for that file,
reads the ports, and then connects. That makes startup deterministic and keeps
the plugin and MCP server loosely coupled.

### 4. The managed startup script closes the reliability gap

`scripts/start_managed_server.sh` does four important things:

1. refreshes the plugin install
2. optionally launches Lightroom if the user enabled auto-launch
3. waits until the bridge is ready
4. launches the long-lived MCP server

That wrapper is the main reason the setup feels smooth day to day on the
original machine, but clean-install testing showed that automatic app launch
should be opt-in, not the default.

### 5. Validation happens before Lightroom writes

The Python side validates and clamps develop parameters before they reach the
plugin. That reduces bad writes, gives better error messages, and makes MCP
clients safer to use.

## Operational Lessons

The clean-install and packaging pass surfaced a few concrete lessons:

- multiple local checkouts can silently create path drift in MCP registration
- Claude `local` scope is project-scoped, so verification has to happen inside the repo
- auto-launching Lightroom from the MCP wrapper is convenient for demos but noisy in daily use
- version strings must be updated in the Lightroom plugin code, not just package metadata
- the project should be tested from a true fresh clone, not only from a long-lived working tree
- export is best treated as verification/output, not the default path for inspection
- the MCP should stay low-level and general-purpose; examples belong in docs rather than new opinionated workflow APIs

## Public Release Constraints

The current design is intentionally local-first:

- macOS only
- Adobe Lightroom Classic only
- assumes the user can install a Lightroom plugin bundle
- assumes a local MCP client will launch the managed server

That is acceptable for an open-source release, but the install path has to be
documented clearly and tested as a fresh checkout, not just as a developer's
existing machine.

## Release Strategy

For public release, keep the architecture the same:

- do not split the plugin and Python server into separate repos yet
- do not replace the socket bridge
- do not add more runtime layers

The highest-value work is packaging and reliability:

- cleaner install instructions
- safer release scripts
- CI for unit tests
- optional live integration tests
- removal of local artifacts from source control
