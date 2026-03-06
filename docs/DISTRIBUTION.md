# Distribution Plan

This project works well as a source checkout, but public distribution should
optimize for "install to use with Codex or Claude" rather than "clone and read
the internals first."

## Best Current Paths

### Source checkout

Good for developers and contributors:

```bash
git clone https://github.com/4xiomdev/lightroom-classic-mcp.git
cd lightroom-classic-mcp
./scripts/install_for_ai.sh --client both
```

### Homebrew tap

Best for semi-technical macOS users:

```bash
brew tap 4xiomdev/tap
brew install lightroom-classic-mcp
lightroom-classic-mcp-install --client both
```

The formula should install the repo into Homebrew `libexec` and expose a small
set of stable commands in `bin`.

## Why Not npm

`npm` is not the natural primary distribution channel for this project because:

- the runtime is Python-based
- the Lightroom integration is a macOS-local plugin bundle
- the real installation work is file placement plus local command registration

An npm wrapper would add another package manager without simplifying the hard
part of the install.

## v1 Product Shape

The minimum user-friendly experience should be:

1. install via release zip or Homebrew
2. run one setup command
3. choose Codex, Claude, or both
4. start using Lightroom through MCP

## Future Improvement

The next major simplification would be a small macOS wrapper app or `.pkg`
installer that:

- installs the plugin bundle
- bootstraps the runtime
- registers Codex and Claude automatically
- shows connection status
