# MCP Setup Guide

This guide helps you configure the mcp-atlassian MCP server to connect your AI client with Agora's Jira and Confluence.

## Prerequisites

**Check if uvx is installed:**
```bash
uvx --version
```

**If not installed:**
```bash
# macOS/Linux
curl -LsSf https://astral.sh/uv/install.sh | sh

# Windows
powershell -c "irm https://astral.sh/uv/install.ps1 | iex"
```

Restart your terminal after installation.

---

## Step 1: Gather Your Information

You'll need:

| Field | Example | Where to Find |
|-------|---------|---------------|
| Jira URL | `https://jira.agoralab.co` | Browser address bar |
| Confluence URL | `https://confluence.agoralab.co` | Browser address bar |
| Username | `yourname@agora.io` | Your Agora email |
| Password | Your Agora password | Your login credentials |
| OAuth Client ID | `QLKKe9NPZyrLualq8dUGZVYHu6bM6Wu1` | Public, use as-is |
| OAuth Client Secret | `NdNXlLvAmTFBMHAtzm8xeu890yUUJNQD` | Public, use as-is |

---

## Step 2: Configure MCP

Agora uses browser-based OAuth SSO for authentication. The first time you use it, a browser window will open for you to log in with your Agora SSO credentials.

For JSON-based MCP clients, the config block below is shared across tools — just put it in the right file.

```json
{
  "mcpServers": {
    "mcp-atlassian": {
      "command": "uvx",
      "args": ["git+https://github.com/LichKing-2234/mcp-atlassian"],
      "env": {
        "JIRA_URL": "https://jira.agoralab.co",
        "JIRA_USERNAME": "yourname@agora.io",
        "JIRA_API_TOKEN": "your-password",
        "CONFLUENCE_URL": "https://confluence.agoralab.co",
        "CONFLUENCE_USERNAME": "yourname@agora.io",
        "CONFLUENCE_API_TOKEN": "your-password",
        "AGORA_OAUTH_GRANT_TYPE": "authorization_code",
        "AGORA_OAUTH_BASE_URL": "https://oauth.agoralab.co/oauth",
        "AGORA_OAUTH_CLIENT_ID": "<AGORA_OAUTH_CLIENT_ID>",
        "AGORA_OAUTH_CLIENT_SECRET": "<AGORA_OAUTH_CLIENT_SECRET>",
        "TOOLSETS": "default"
      }
    }
  }
}
```

**Config file locations:**

| Tool | File Path |
|------|-----------|
| Codex | `~/.codex/config.toml` |
| Claude Code | `~/.claude.json` (or use `claude mcp add-json`) |
| Kiro (global) | `~/.kiro/settings/mcp.json` |
| Kiro (project) | `.kiro/settings/mcp.json` |
| Claude Desktop (macOS) | `~/Library/Application Support/Claude/claude_desktop_config.json` |
| Cursor | `.cursor/mcp.json` |

### Codex Configuration

Codex does **not** read `.kiro/settings/mcp.json`, `.cursor/mcp.json`, or other clients' MCP config files. If you are using Codex, add the server to `~/.codex/config.toml`.

Codex uses TOML rather than JSON:

```toml
[mcp_servers.mcp-atlassian]
command = "uvx"
args = ["git+https://github.com/LichKing-2234/mcp-atlassian"]
enabled = true

[mcp_servers.mcp-atlassian.env]
JIRA_URL = "https://jira.agoralab.co"
JIRA_USERNAME = "yourname@agora.io"
JIRA_API_TOKEN = "your-password"
CONFLUENCE_URL = "https://confluence.agoralab.co"
CONFLUENCE_USERNAME = "yourname@agora.io"
CONFLUENCE_API_TOKEN = "your-password"
AGORA_OAUTH_GRANT_TYPE = "authorization_code"
AGORA_OAUTH_BASE_URL = "https://oauth.agoralab.co/oauth"
AGORA_OAUTH_CLIENT_ID = "<AGORA_OAUTH_CLIENT_ID>"
AGORA_OAUTH_CLIENT_SECRET = "<AGORA_OAUTH_CLIENT_SECRET>"
TOOLSETS = "default"
```

If `~/.codex/config.toml` already contains other MCP servers, append the new `mcp_servers.mcp-atlassian` block instead of replacing the file.

---

## Environment Variables

| Variable | Description |
|----------|-------------|
| `JIRA_URL` | Agora Jira Server URL |
| `JIRA_USERNAME` | Your Agora email |
| `JIRA_API_TOKEN` | Your Agora password |
| `CONFLUENCE_URL` | Agora Confluence Server URL |
| `CONFLUENCE_USERNAME` | Your Agora email |
| `CONFLUENCE_API_TOKEN` | Your Agora password |
| `AGORA_OAUTH_GRANT_TYPE` | Use `authorization_code` for browser-based SSO |
| `AGORA_OAUTH_BASE_URL` | OAuth server base URL (`https://oauth.agoralab.co/oauth`) |
| `AGORA_OAUTH_CLIENT_ID` | OAuth application client ID |
| `AGORA_OAUTH_CLIENT_SECRET` | OAuth application client secret |
| `TOOLSETS` | Controls which tool groups are loaded (see below) |

### TOOLSETS Recommendations

21 toolsets (73 tools) in total. Loading all of them consumes significant context. Choose based on your needs:

- **`default`** (recommended) — 6 core toolsets for everyday use:
  - Jira: `jira_issues`, `jira_fields`, `jira_comments`, `jira_transitions`
  - Confluence: `confluence_pages`, `confluence_comments`
- **`default,jira_agile`** — when you need sprint/board operations
- **`default,jira_links`** — when you need to manage issue links
- **`all`** — all 21 toolsets, highest context cost

---

## How OAuth SSO Works

1. When you first use the MCP server, a browser window opens automatically
2. Log in with your Agora SSO credentials
3. The server receives an access token and auto-refreshes it in the background (~2 hours)
4. Subsequent requests use the cached token (no more browser popups)

---

## Step 3: Restart and Verify

1. **Restart** your AI tool (Codex, Claude Code, Kiro, Claude Desktop, etc.)
   - **Codex:** fully restart the app after editing `~/.codex/config.toml`
   - Codex does not hot-reload MCP servers into the current session
2. **Test** by asking: "Search Jira for my open issues"

Expected: Returns a list of issues or "no results" (not an error).

---

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `command not found: uvx` | uv not installed | Install uv, restart terminal |
| `Authentication failed` | Wrong credentials | Check username/password |
| `Connection timeout` | Network/VPN issue | Check you can access Jira in browser |
| `MCP server not found` | Config not loaded | Check JSON syntax, restart AI tool |
| `MCP server not found` in Codex after editing another tool's config | Codex uses its own MCP config file | Add the server to `~/.codex/config.toml`, then restart Codex |
| `MCP server not found` in Codex right after editing `config.toml` | Current Codex session did not reload MCP servers | Fully restart Codex and try again |
| `Permission denied` | Account lacks access | Contact IT for permissions |
| `Timed out waiting for authorization callback` | Browser OAuth SSO timed out | Restart AI tool, complete SSO login within 5 minutes |
| `State mismatch` | OAuth security check failed | Clear browser cache, restart AI tool |

---

## Security Notes

- Never commit passwords or OAuth secrets to git
- Use environment variables for sensitive data in shared configs
- OAuth tokens auto-refresh; if issues persist, restart AI tool to re-authenticate
