class LightroomClassicMcp < Formula
  include Language::Python::Virtualenv

  desc "MCP bridge for Adobe Lightroom Classic on macOS"
  homepage "https://github.com/4xiomdev/lightroom-classic-mcp"
  url "https://github.com/4xiomdev/lightroom-classic-mcp/releases/download/v0.4.0/lightroom-classic-mcp-0.4.0-source.zip"
  sha256 "3698c1a63726e660f010dac2c94406fae83304b53a73cbebcde571b783d22db3"
  license "MIT"
  head "https://github.com/4xiomdev/lightroom-classic-mcp.git", branch: "main"

  depends_on "python@3.12"

  def install
    libexec.install Dir["*"]

    (bin/"lightroom-classic-mcp").write_env_script libexec/"scripts/start_managed_server.sh", {}
    (bin/"lightroom-classic-mcp-install").write_env_script libexec/"scripts/install_for_ai.sh", {}
    (bin/"lightroom-classic-mcp-config").write_env_script libexec/"scripts/print_mcp_config.sh", {}
  end

  def caveats
    <<~EOS
      Next steps:
        1. Install the Lightroom plugin and register the MCP client:
             lightroom-classic-mcp-install --client both

        2. Or configure clients manually:
             codex mcp add lightroom-classic -- bash -lc 'cd "#{opt_libexec}" && ./scripts/start_managed_server.sh'
             claude mcp add -s local lightroom-classic -- bash -lc 'cd "#{opt_libexec}" && ./scripts/start_managed_server.sh'

        3. Print a raw MCP config snippet if needed:
             lightroom-classic-mcp-config
    EOS
  end

  test do
    assert_match "mcpServers", shell_output("#{bin}/lightroom-classic-mcp-config")
  end
end
