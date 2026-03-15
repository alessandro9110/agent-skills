# agent-skills

A community repository of Agent Skills for Claude, GitHub Copilot, and Cursor — reusable cross-tool AI workflows for Databricks, Azure AI Foundry, and more.

## What are Skills?

Skills are reusable instruction sets (SKILL.md files) that teach AI assistants how to handle specific workflows consistently. They work across Claude Code, Claude Desktop, VS Code with GitHub Copilot, and Cursor.

## Available Skills

### Azure & Cloud

| Skill | Description | Tools |
|-------|-------------|-------|
| [azure-ai-foundry-agents](./skills/azure-ai-foundry-agents/) | Create and deploy AI agents and multi-agent systems on Azure AI Foundry | Function calling, Databricks Genie, Azure AI Search, Multi-agent orchestration |

### Databricks

| Skill | Description | Tools |
|-------|-------------|-------|
| [databricks-mosaic-ai-agents](./skills/databricks-mosaic-ai-agents/) | Build and deploy custom AI agents on Databricks using Mosaic AI with LangGraph or LangChain | MLflow tracing, Unity Catalog tools, Vector Search, Asset Bundle job deployment |

## Prerequisites

### System
| Requirement | macOS | Linux | Windows |
|-------------|-------|-------|---------|
| Python 3.10+ | `brew install python` | `sudo apt install python3` | [python.org](https://www.python.org/downloads/) |
| `uv` | see below | see below | see below |
| `curl` | built-in | `sudo apt install curl` | built-in (Win 10+) |
| bash shell | built-in | built-in | WSL or Git Bash required |

> **Windows:** `install.sh` is a bash script and does not run in PowerShell or CMD.
> Use [WSL](https://learn.microsoft.com/en-us/windows/wsl/install) (`wsl bash install.sh`) or [Git Bash](https://git-scm.com/downloads) (open Git Bash terminal and run the script normally).

**Install `uv`:**

macOS / Linux:
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Windows (PowerShell):
```powershell
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

### Python libraries per skill

**Azure AI Foundry agents:**
```bash
pip install "azure-ai-projects>=2.0.0b4" azure-identity
```

**Databricks Mosaic AI agents:**
```bash
pip install databricks-langchain langgraph mlflow databricks-agents databricks-sdk
```

## Installation

The installer automatically downloads our skills **and all dependencies** (databricks ai-dev-kit skills + langchain-skills). At the end it will ask whether to configure MCP servers.

### Quick install
```bash
bash <(curl -sL https://raw.githubusercontent.com/alessandro9110/agent-skills/main/install.sh)
```

The installer is fully interactive — it will ask you at the end:
```
What would you like to install?
  [1] Skills only
  [2] Skills + MCP servers (configures live tool access)
```

If you choose **[2]**, it will prompt you for:
1. **Path to ai-dev-kit repo** — press Enter to auto-clone to `~/.databricks-ai-dev-kit`
2. **DATABRICKS_HOST** — your workspace URL (e.g. `https://adb-xxx.azuredatabricks.net`)
3. **DATABRICKS_TOKEN** — your personal access token (press Enter to use `~/.databrickscfg`)

The MCP server is configured automatically in `.claude/settings.json` (or `~/.claude/settings.json` with `--global`).

### VS Code with Claude Code

1. Install the [Claude Code extension](https://marketplace.visualstudio.com/items?itemName=Anthropic.claude-code) in VS Code
2. Open your project folder in VS Code
3. Run the installer from the VS Code terminal:
```bash
bash <(curl -sL https://raw.githubusercontent.com/alessandro9110/agent-skills/main/install.sh)
```

### Install for multiple tools
```bash
# Clone and run with options
git clone https://github.com/alessandro9110/agent-skills
cd agent-skills
bash install.sh --tools claude,cursor,copilot
```

### Options
```
--global, -g         Install globally (~/.claude/skills, ~/.cursor/rules, etc.)
--tools, -t TOOLS    Tools to install for: claude,cursor,copilot (default: claude)
--yes, -y            Skip confirmation prompts (installs skills only, no MCP)
```

### What gets installed
| Skill | Source |
|-------|--------|
| `azure-ai-foundry-agents` | This repo |
| `databricks-mosaic-ai-agents` | This repo |
| `azure-microsoft-foundry` | MicrosoftDocs/Agent-Skills |
| `azure-cognitive-search` | MicrosoftDocs/Agent-Skills |
| `azure-ai-services` | MicrosoftDocs/Agent-Skills |
| `databricks-asset-bundles` | databricks-solutions/ai-dev-kit |
| `databricks-model-serving` | databricks-solutions/ai-dev-kit |
| `databricks-vector-search` | databricks-solutions/ai-dev-kit |
| `databricks-mlflow-evaluation` | databricks-solutions/ai-dev-kit |
| `langgraph-fundamentals` | langchain-ai/langchain-skills |
| `langgraph-persistence` | langchain-ai/langchain-skills |
| `langchain-fundamentals` | langchain-ai/langchain-skills |
| `framework-selection` | langchain-ai/langchain-skills |

> **Note:** MicrosoftDocs skills require the `mcp_microsoftdocs` MCP server to be configured for live documentation fetching. Without it, the implementation workflows in our skills are still fully functional.

## Contributing

1. Fork this repository
2. Create your skill folder under `skills/` using kebab-case naming
3. Include a `SKILL.md` with valid YAML frontmatter (`name` + `description` required)
4. Open a pull request

See the [Skills Guide](https://claude.ai/skills) for how to structure SKILL.md files.

## License

MIT
