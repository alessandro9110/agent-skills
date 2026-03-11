# Multi-Agent Patterns — Azure AI Foundry

## Core Patterns

### Pattern 1: Orchestrator + Specialists (Sequential)
Best for tasks with clear domain separation.

```
User → Orchestrator → Specialist A → Specialist B → Orchestrator → User
```

### Pattern 2: Parallel Execution
Best for independent analyses that can run concurrently.

```
User → Orchestrator ─┬→ Agent A ─┐
                      ├→ Agent B ─┤→ Aggregator → User
                      └→ Agent C ─┘
```

### Pattern 3: Hierarchical (Multi-Level)
Best for complex enterprise workflows.

```
User → Top Orchestrator
          ├→ Sub-Orchestrator 1
          │     ├→ Worker A
          │     └→ Worker B
          └→ Sub-Orchestrator 2
                ├→ Worker C
                └→ Worker D
```

## Full Python Implementation

```python
from azure.ai.projects import AIProjectClient
from azure.ai.projects.models import (
    PromptAgentDefinition,
    ConnectedAgentTool,
    FunctionTool,
    FileSearchTool,
    McpTool
)
from azure.identity import DefaultAzureCredential

PROJECT_ENDPOINT = "https://<resource>.ai.azure.com/api/projects/<project>"
project = AIProjectClient(endpoint=PROJECT_ENDPOINT, credential=DefaultAzureCredential())
openai = project.get_openai_client()

# 1. Create Data Specialist
data_agent = project.agents.create_version(
    agent_name="data-specialist",
    definition=PromptAgentDefinition(
        model="gpt-4o",
        instructions="""You are a data specialist.
- Use Databricks Genie for structured data queries
- Use Azure AI Search for document retrieval
- Return data in structured JSON format
- Always include data source in your response""",
        tools=[
            # Add genie_tool and file_search here
        ]
    )
)

# 2. Create Analysis Specialist
analysis_agent = project.agents.create_version(
    agent_name="analysis-specialist",
    definition=PromptAgentDefinition(
        model="gpt-4o",
        instructions="""You are an analysis specialist.
- Perform statistical analysis on provided data
- Generate insights and recommendations
- Format output as structured report with sections:
  * Executive Summary
  * Key Findings
  * Recommendations""",
        tools=[]  # Add code interpreter if needed
    )
)

# 3. Create Orchestrator
orchestrator = project.agents.create_version(
    agent_name="main-orchestrator",
    definition=PromptAgentDefinition(
        model="gpt-4o",
        instructions="""You are the main orchestrator. Route tasks to the right specialist:

ROUTING RULES:
- Data retrieval, queries, search → data-specialist
- Analysis, insights, calculations → analysis-specialist

WORKFLOW:
1. Understand user request
2. Break into sub-tasks
3. Delegate to appropriate specialist(s)
4. Synthesize results into coherent final answer
5. Always cite which specialist provided each piece of information""",
        tools=[
            ConnectedAgentTool(
                agent_name="data-specialist",
                description="Retrieves data from Databricks Genie and Azure AI Search. Use for data queries, document search, structured data retrieval."
            ),
            ConnectedAgentTool(
                agent_name="analysis-specialist",
                description="Analyzes data and generates insights. Use for statistical analysis, trend identification, recommendations."
            )
        ]
    )
)

# 4. Invoke orchestrator
response = openai.responses.create(
    input="Analyze sales data from Q4 and provide key trends and recommendations",
    extra_body={"agent_reference": {"name": orchestrator.name, "type": "agent_reference"}}
)
print(response.output_text)

# 5. Cleanup (in reverse order)
project.agents.delete_version(agent_name=orchestrator.name, agent_version=orchestrator.version)
project.agents.delete_version(agent_name=analysis_agent.name, agent_version=analysis_agent.version)
project.agents.delete_version(agent_name=data_agent.name, agent_version=data_agent.version)
```

## Key Design Principles

1. **Clear boundaries** — each agent has a specific, non-overlapping responsibility
2. **Explicit routing rules** — orchestrator instructions must clearly define when to use each specialist
3. **Structured outputs** — specialists return structured data; orchestrator synthesizes for user
4. **Cleanup order** — always delete in reverse creation order (orchestrator first, then specialists)

## ConnectedAgentTool — Description Best Practices

```python
# GOOD — specific about when to use
ConnectedAgentTool(
    agent_name="data-specialist",
    description="Retrieves and queries structured data. Use for: SQL-like queries, data aggregation, document search, Databricks data, Azure AI Search retrieval."
)

# BAD — too vague
ConnectedAgentTool(
    agent_name="data-specialist",
    description="Handles data tasks."
)
```

## Deployment Considerations

- Each agent version is independently deployed
- Orchestrator should be created LAST (after all specialists exist)
- Use consistent model versions across all agents for predictability
- Monitor with Application Insights to trace inter-agent calls
