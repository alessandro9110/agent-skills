---
name: azure-ai-foundry-agents
description: Guides creation and deployment of AI agents and multi-agent systems on Azure AI Foundry using Microsoft Agent Framework. Use when building agents with function calling, Databricks Genie, vector databases (Azure AI Search), or multi-agent orchestration. Triggers on phrases like "create agent on Azure", "deploy agent Foundry", "multi-agent Azure", "agent with tools Azure", "Databricks Genie agent", "vector search agent Foundry", "Azure AI agent", "Microsoft Agent Framework".
license: MIT
compatibility: Requires Azure subscription and azure-ai-projects Python SDK (>=2.0.0b4) or Microsoft.Agents.AI .NET package. Works with Claude Code, Claude Desktop, VS Code with GitHub Copilot, and Cursor.
metadata:
  author: Alessandro Armillotta
  version: 1.0.0
  category: azure-ai
  tags: [azure, ai-foundry, agents, multi-agent, databricks, vector-db, microsoft-agent-framework]
  dependencies:
    - name: azure-ai-foundry-local
      repo: MicrosoftDocs/Agent-Skills
      raw_base: https://raw.githubusercontent.com/MicrosoftDocs/Agent-Skills/main/skills/azure-ai-foundry-local
      files: [SKILL.md]
    - name: azure-cognitive-search
      repo: MicrosoftDocs/Agent-Skills
      raw_base: https://raw.githubusercontent.com/MicrosoftDocs/Agent-Skills/main/skills/azure-cognitive-search
      files: [SKILL.md]
    - name: azure-ai-services
      repo: MicrosoftDocs/Agent-Skills
      raw_base: https://raw.githubusercontent.com/MicrosoftDocs/Agent-Skills/main/skills/azure-ai-services
      files: [SKILL.md]
---

# Azure AI Foundry Agents

Guide for creating, configuring, and deploying AI agents and multi-agent systems on Azure AI Foundry using Microsoft Agent Framework.

> **Live documentation:** If `mcp_microsoftdocs:microsoft_docs_fetch` is available (VS Code with MCP enabled), use it to retrieve live Microsoft docs for limits, quotas, SDK references, and changelogs. This skill handles the implementation workflow; the MicrosoftDocs skills (`azure-ai-foundry-local`, `azure-cognitive-search`, `azure-ai-services`) handle live documentation retrieval.

## Prerequisites

Before starting, gather from the user:
1. **Azure project endpoint** — format: `https://<resource>.ai.azure.com/api/projects/<project>`
2. **Model deployment name** — e.g. `gpt-4o`, `gpt-4o-mini`, `claude-sonnet`
3. **Agent type** — single agent or multi-agent orchestration
4. **Integrations needed** — function calling, Databricks Genie, Azure AI Search (vector DB), MCP tools
5. **Language** — Python or C#

CRITICAL: Always ask these questions before generating any code.

## Instructions

### Step 1: Project Setup

**Python:**
```bash
pip install "azure-ai-projects>=2.0.0b4" azure-identity
```

**C#:**
```bash
dotnet add package Azure.AI.Projects --prerelease
dotnet add package Azure.Identity
```

Initialize the client:

**Python:**
```python
from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential

project = AIProjectClient(
    endpoint="https://<resource>.ai.azure.com/api/projects/<project>",
    credential=DefaultAzureCredential()
)
openai = project.get_openai_client()
```

### Step 2: Create a Single Agent

**Minimal agent (Python):**
```python
from azure.ai.projects.models import PromptAgentDefinition

agent = project.agents.create_version(
    agent_name="my-agent",
    definition=PromptAgentDefinition(
        model="gpt-4o-mini",
        instructions="You are a helpful assistant.",
        tools=[]
    )
)
```

**Invoke the agent:**
```python
response = openai.responses.create(
    input="Hello, what can you do?",
    extra_body={"agent_reference": {"name": agent.name, "type": "agent_reference"}}
)
print(response.output_text)
```

**Cleanup (always delete agent versions when done testing):**
```python
project.agents.delete_version(agent_name=agent.name, agent_version=agent.version)
```

### Step 3: Add Tools (Function Calling)

For each custom tool, define name, description, and JSON schema parameters. The agent decides when to invoke each tool.

See `references/function-calling.md` for the complete 5-step workflow and full examples.

**Quick example:**
```python
from azure.ai.projects.models import FunctionTool

weather_tool = FunctionTool(
    name="get_weather",
    description="Get current weather for a city",
    parameters={
        "type": "object",
        "properties": {
            "location": {"type": "string", "description": "City and state, e.g. Milan, IT"},
            "unit": {"type": "string", "enum": ["celsius", "fahrenheit"]}
        },
        "required": ["location"],
        "additionalProperties": False
    },
    strict=True
)

agent = project.agents.create_version(
    agent_name="weather-agent",
    definition=PromptAgentDefinition(
        model="gpt-4o-mini",
        instructions="You are a weather assistant. Use get_weather to answer weather questions.",
        tools=[weather_tool]
    )
)
```

After the agent responds with a function call, execute the function and submit output:
```python
from openai.types.responses.response_input_param import FunctionCallOutput
import json

for item in response.output:
    if item.type == "function_call" and item.name == "get_weather":
        result = get_weather(**json.loads(item.arguments))
        final = openai.responses.create(
            input=[FunctionCallOutput(type="function_call_output", call_id=item.call_id, output=json.dumps(result))],
            previous_response_id=response.id,
            extra_body={"agent_reference": {"name": agent.name, "type": "agent_reference"}}
        )
        print(final.output_text)
```

### Step 4: Add Vector Search (Azure AI Search)

For RAG (Retrieval-Augmented Generation) use cases, attach Azure AI Search as vector store.

See `references/vector-db.md` for full configuration.

```python
from azure.ai.projects.models import FileSearchTool, VectorStore

# Attach file search tool to agent
file_search = FileSearchTool(vector_store_ids=["<vector_store_id>"])

agent = project.agents.create_version(
    agent_name="rag-agent",
    definition=PromptAgentDefinition(
        model="gpt-4o",
        instructions="Answer questions using the knowledge base. Always cite sources.",
        tools=[file_search]
    )
)
```

### Step 5: Add Databricks Genie Integration

Databricks Genie exposes data analytics through natural language via MCP or direct API.

See `references/databricks-genie.md` for full setup.

**Key constraints:**
- Rate limit: 5 questions per minute
- Authentication via Entra ID (brokered automatically in Azure)
- Requires Azure Databricks workspace with Genie enabled

```python
# Connect Databricks Genie via MCP tool endpoint
from azure.ai.projects.models import McpTool

genie_tool = McpTool(
    server_label="databricks-genie",
    server_url="https://<workspace>.azuredatabricks.net/api/2.0/genie/mcp",
    allowed_tools=["genie_query"]
)
```

### Step 6: Multi-Agent Orchestration

Build an orchestrator agent that delegates to specialist sub-agents.

See `references/multi-agent-patterns.md` for full patterns.

**Architecture:**
```
User Request
    ↓
Orchestrator Agent
    ├→ Data Agent (Databricks Genie + Azure AI Search)
    ├→ Analysis Agent (function calling + code interpreter)
    └→ Report Agent (document generation)
    ↓
Aggregated Response
```

**Orchestrator definition:**
```python
# Create specialist agents first
data_agent = project.agents.create_version(
    agent_name="data-specialist",
    definition=PromptAgentDefinition(
        model="gpt-4o",
        instructions="You are a data specialist. Query Databricks Genie and Azure AI Search to answer data questions.",
        tools=[genie_tool, file_search]
    )
)

# Create orchestrator with connected agents
from azure.ai.projects.models import ConnectedAgentTool

orchestrator = project.agents.create_version(
    agent_name="orchestrator",
    definition=PromptAgentDefinition(
        model="gpt-4o",
        instructions="""You are an orchestrator. Delegate tasks to specialist agents:
- Data questions → data-specialist
- Analysis tasks → analysis-specialist
Always synthesize results into a coherent final response.""",
        tools=[
            ConnectedAgentTool(agent_name="data-specialist", description="Handles data queries and retrieval"),
            ConnectedAgentTool(agent_name="analysis-specialist", description="Performs data analysis and calculations")
        ]
    )
)
```

## IDE Compatibility Notes

### VS Code / GitHub Copilot
- Place this skill in `.github/` as `copilot-instructions.md` to use with Copilot Chat
- Reference Azure SDK docs via `@docs` in Copilot Chat
- Use `#codebase` to let Copilot analyze existing agent code

### Cursor
- Add skill content to `.cursor/rules/azure-agents.mdc`
- Works with Cursor's `@azure` context for SDK autocompletion

## Common Issues

**Error: `DefaultAzureCredential` fails**
- Run `az login` in terminal
- Or set `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID` env vars

**Error: Model not found**
- Verify the deployment name in Azure AI Foundry portal (Settings > Models)
- Model name ≠ deployment name (e.g., deployment `my-gpt4o` runs model `gpt-4o`)

**Function calls not triggered**
- Improve tool `description` — be explicit about when to use it
- Add example phrases to the description
- Set `strict=True` in FunctionTool definition

**Databricks Genie rate limit exceeded**
- Implement exponential backoff: wait 60s after 5 calls/minute
- Cache frequent queries in Azure AI Search vector store

**Multi-agent: sub-agent not invoked**
- Improve `description` in `ConnectedAgentTool`
- Be explicit in orchestrator instructions about which agent handles what

## Performance Notes
- Take time to correctly define tool schemas — precision here prevents errors downstream
- For multi-agent systems, always define clear boundaries between agents in their instructions
- Do not skip cleanup of agent versions after testing
