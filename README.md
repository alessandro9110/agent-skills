# agent-skills

A community repository of Agent Skills for Claude, GitHub Copilot, and Cursor — reusable AI workflows for Databricks, Azure AI Foundry, and more.

## What are Skills?

Skills are reusable instruction sets (`SKILL.md` files) that teach AI assistants how to handle specific workflows consistently. They work across Claude Code, Claude Desktop, VS Code with GitHub Copilot, and Cursor.

---

## Available Skills

### Databricks

| Skill | Description |
|-------|-------------|
| [databricks-mosaic-ai-agents](./skills/databricks-mosaic-ai-agents/) | Build and deploy custom AI agents using Mosaic AI with LangGraph or LangChain — MLflow tracing, Unity Catalog tools, Vector Search, Asset Bundle deployment |

### Azure & Cloud

| Skill | Description |
|-------|-------------|
| [azure-ai-foundry-agents](./skills/azure-ai-foundry-agents/) | Create and deploy AI agents on Azure AI Foundry — function calling, Databricks Genie, Azure AI Search, multi-agent orchestration |

---

## Prerequisites

The installer checks these automatically and shows install hints for anything missing.

### Required (installer will fail without these)

| Tool | macOS | Linux | Windows |
|------|-------|-------|---------|
| `bash` | built-in | built-in | WSL or Git Bash |
| `curl` | built-in | `sudo apt install curl` | built-in (Win 10+) |
| `python3` | `brew install python` | `sudo apt install python3` | [python.org](https://www.python.org/downloads/) |
| `git` | `brew install git` | `sudo apt install git` | [git-scm.com](https://git-scm.com/downloads) |

> **Windows:** `install.sh` requires bash. Use [WSL](https://learn.microsoft.com/en-us/windows/wsl/install) (`wsl bash install.sh`) or Git Bash.

### Recommended (needed for MCP server setup)

| Tool | Install |
|------|---------|
| `uv` | `curl -LsSf https://astral.sh/uv/install.sh \| sh` — used to create the Python venv for the MCP server; falls back to `python3 -m venv` if missing |
| `databricks` CLI | `brew tap databricks/tap && brew install databricks` — needed for `~/.databrickscfg` auth; falls back to env-var auth if missing |

### Python libraries (per skill, for your own projects)

**Databricks Mosaic AI agents:**
```bash
pip install databricks-langchain langgraph mlflow databricks-agents databricks-sdk
```

**Azure AI Foundry agents:**
```bash
pip install "azure-ai-projects>=2.0.0b4" azure-identity
```

---

## Installation

### Quick install

```bash
bash <(curl -sL https://raw.githubusercontent.com/alessandro9110/agent-skills/main/install.sh)
```

The installer is fully interactive with arrow-key menus. No flags required.

### What the installer does, step by step

**1. Prerequisites check**

Before any prompts, the installer shows the status of all required and optional tools:

```
Checking prerequisites...

  ✓ curl               /usr/bin/curl
  ✓ python3            /usr/bin/python3
  ✓ git                /usr/bin/git
  ✓ uv                 /Users/you/.cargo/bin/uv
  ✗ databricks         not found
    Install: brew tap databricks/tap && brew install databricks
```

**2. Install scope**

```
Install scope:
▶ Project  (/your/project/.claude/skills)
  Global   (~/.claude/skills)
```

Default is **Project** — skills are installed in the current working directory.

**3. Summary + confirmation**

Lists all skills, external dependencies, and MCP servers that will be configured, then asks to confirm before proceeding.

**4. Skill installation**

Installs all skills from this repo and downloads external dependencies from their source repositories.

**5. MCP server choice**

```
What would you like to install?
▶ Skills only
  Skills + MCP servers (configures live tool access)
```

If **Skills + MCP servers** is chosen, the installer:
- Clones [databricks-solutions/ai-dev-kit](https://github.com/databricks-solutions/ai-dev-kit) to `~/.ai-dev-kit/`
- Creates a Python venv at `~/.ai-dev-kit/.venv/` and installs the MCP server packages
- Prompts for Databricks authentication (see below)
- Writes `.mcp.json` in the project root (or `~/.claude/settings.json` for global installs)

**6. Databricks authentication**

Two options, both safe — credentials are never written into `.mcp.json`:

| Option | How it works | Credentials stored in |
|--------|-------------|----------------------|
| **`~/.databrickscfg`** (recommended) | Runs `databricks auth login --host <url> --profile <name>` — opens browser for OAuth, handles token refresh automatically | `~/.databrickscfg` (outside any git repo) |
| **Environment variables** | Prompts for `DATABRICKS_HOST` + `DATABRICKS_TOKEN`, writes `export` statements to your shell profile (`~/.zprofile`, `~/.zshrc`, etc.) | Shell profile (outside any git repo) |

> If the Databricks CLI is not installed, option 1 is skipped and env-var auth is used automatically.

**Resulting `.mcp.json`:**

```json
{
  "mcpServers": {
    "databricks": {
      "command": "/Users/you/.ai-dev-kit/.venv/bin/python",
      "args": ["/Users/you/.ai-dev-kit/repo/databricks-mcp-server/run_server.py"],
      "env": { "DATABRICKS_CONFIG_PROFILE": "your-profile" }
    }
  }
}
```

> **Token expired?** Re-authenticate at any time:
> ```bash
> databricks auth login --host https://<workspace>.azuredatabricks.net --profile <name>
> ```

---

### Install for multiple AI tools

```bash
git clone https://github.com/alessandro9110/agent-skills
cd agent-skills
bash install.sh --tools claude,cursor,copilot
```

### CLI options

| Flag | Description |
|------|-------------|
| `--global, -g` | Force global install (`~/.claude/skills`) without the scope prompt |
| `--tools, -t TOOLS` | Comma-separated list: `claude`, `cursor`, `copilot` (default: `claude`) |
| `--yes, -y` | Skip all prompts — project scope, skills only, no MCP |

---

## What gets installed

### Skills from this repo

| Skill | Description |
|-------|-------------|
| `databricks-mosaic-ai-agents` | Mosaic AI agent development and deployment |
| `azure-ai-foundry-agents` | Azure AI Foundry agent development and deployment |

### External skill dependencies (auto-downloaded)

| Skill | Source |
|-------|--------|
| `databricks-asset-bundles` | [databricks-solutions/ai-dev-kit](https://github.com/databricks-solutions/ai-dev-kit) |
| `databricks-model-serving` | [databricks-solutions/ai-dev-kit](https://github.com/databricks-solutions/ai-dev-kit) |
| `databricks-vector-search` | [databricks-solutions/ai-dev-kit](https://github.com/databricks-solutions/ai-dev-kit) |
| `databricks-mlflow-evaluation` | [databricks-solutions/ai-dev-kit](https://github.com/databricks-solutions/ai-dev-kit) |
| `databricks-lakebase-provisioned` | [databricks-solutions/ai-dev-kit](https://github.com/databricks-solutions/ai-dev-kit) |
| `langgraph-fundamentals` | [langchain-ai/langchain-skills](https://github.com/langchain-ai/langchain-skills) |
| `langgraph-persistence` | [langchain-ai/langchain-skills](https://github.com/langchain-ai/langchain-skills) |
| `langchain-fundamentals` | [langchain-ai/langchain-skills](https://github.com/langchain-ai/langchain-skills) |
| `framework-selection` | [langchain-ai/langchain-skills](https://github.com/langchain-ai/langchain-skills) |
| `azure-microsoft-foundry` | [MicrosoftDocs/Agent-Skills](https://github.com/MicrosoftDocs/Agent-Skills) |
| `azure-cognitive-search` | [MicrosoftDocs/Agent-Skills](https://github.com/MicrosoftDocs/Agent-Skills) |
| `azure-ai-services` | [MicrosoftDocs/Agent-Skills](https://github.com/MicrosoftDocs/Agent-Skills) |

### MCP servers (optional, configured when choosing Skills + MCP)

| Server | Type | Source |
|--------|------|--------|
| `databricks` | stdio | [databricks-solutions/ai-dev-kit](https://github.com/databricks-solutions/ai-dev-kit) — live access to Databricks workspace (clusters, SQL, jobs, model serving, Vector Search, Lakebase) |
| `microsoft-learn` | http | `https://learn.microsoft.com/api/mcp` — live Microsoft documentation |

> **MicrosoftDocs skills** (`azure-microsoft-foundry`, `azure-cognitive-search`, `azure-ai-services`) work best when the `microsoft-learn` MCP server is active. Without it the skills are still fully functional for implementation guidance.

---

## VS Code with Claude Code

1. Install the [Claude Code extension](https://marketplace.visualstudio.com/items?itemName=Anthropic.claude-code)
2. Open your project folder in VS Code
3. Run the installer from the integrated terminal:

```bash
bash <(curl -sL https://raw.githubusercontent.com/alessandro9110/agent-skills/main/install.sh)
```

---

## Contributing

1. Fork this repository
2. Create your skill folder under `skills/` using kebab-case naming
3. Add a `SKILL.md` with valid YAML frontmatter (`name` + `description` required)
4. If your skill depends on external skills, declare them in the `metadata.dependencies` block and update `install.sh`
5. Open a pull request

See the [Skills Guide](https://claude.ai/skills) for how to structure `SKILL.md` files.

---

## License

MIT
