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

## Installation

The installer automatically downloads our skills **and all dependencies** (databricks ai-dev-kit skills + langchain-skills).

### Quick install (Claude Code — project scope)
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
--yes, -y            Skip confirmation prompts
```

### What gets installed
| Skill | Source |
|-------|--------|
| `azure-ai-foundry-agents` | This repo |
| `databricks-mosaic-ai-agents` | This repo |
| `databricks-asset-bundles` | databricks-solutions/ai-dev-kit |
| `databricks-model-serving` | databricks-solutions/ai-dev-kit |
| `databricks-vector-search` | databricks-solutions/ai-dev-kit |
| `databricks-mlflow-evaluation` | databricks-solutions/ai-dev-kit |
| `langgraph-fundamentals` | langchain-ai/langchain-skills |
| `langgraph-persistence` | langchain-ai/langchain-skills |
| `langchain-fundamentals` | langchain-ai/langchain-skills |
| `framework-selection` | langchain-ai/langchain-skills |

## Contributing

1. Fork this repository
2. Create your skill folder under `skills/` using kebab-case naming
3. Include a `SKILL.md` with valid YAML frontmatter (`name` + `description` required)
4. Open a pull request

See the [Skills Guide](https://claude.ai/skills) for how to structure SKILL.md files.

## License

MIT
