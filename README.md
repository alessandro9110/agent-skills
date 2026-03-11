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

## How to Use a Skill

### Claude Code / Claude Desktop
1. Download the skill folder
2. Zip the folder
3. Upload via **Settings > Capabilities > Skills**

### VS Code / GitHub Copilot
- Copy the skill content to `.github/copilot-instructions.md`

### Cursor
- Add skill content to `.cursor/rules/<skill-name>.mdc`

## Contributing

1. Fork this repository
2. Create your skill folder under `skills/` using kebab-case naming
3. Include a `SKILL.md` with valid YAML frontmatter (`name` + `description` required)
4. Open a pull request

See the [Skills Guide](https://claude.ai/skills) for how to structure SKILL.md files.

## License

MIT
