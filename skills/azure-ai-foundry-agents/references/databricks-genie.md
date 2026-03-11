# Databricks Genie Integration — Azure AI Foundry

## Overview
Databricks Genie allows Azure AI Foundry agents to query structured data using natural language. Available via MCP (Model Context Protocol) in public preview.

## Constraints
- **Rate limit**: 5 questions per minute (enforced at API level)
- **Authentication**: Brokered by Microsoft Entra ID (Azure AD)
- **Requires**: Azure Databricks workspace with Genie spaces enabled

## Setup via MCP Tool

```python
from azure.ai.projects.models import McpTool

genie_mcp = McpTool(
    server_label="databricks-genie",
    server_url="https://<workspace-url>.azuredatabricks.net/api/2.0/genie/mcp",
    allowed_tools=["genie_query"],
    # Auth handled via project connection
)

agent = project.agents.create_version(
    agent_name="genie-agent",
    definition=PromptAgentDefinition(
        model="gpt-4o",
        instructions="""You are a data analyst with access to Databricks Genie.
Use Genie to answer questions about business data.
Important: Genie has a rate limit of 5 questions/minute.
For complex requests, batch related questions together when possible.""",
        tools=[genie_mcp]
    )
)
```

## Direct Genie API (without MCP)

```python
import requests
import time
from azure.identity import DefaultAzureCredential

WORKSPACE_URL = "https://<workspace>.azuredatabricks.net"
GENIE_SPACE_ID = "<space-id>"

def query_genie(question: str, conversation_id: str = None) -> dict:
    """Query Databricks Genie with rate limit handling."""
    credential = DefaultAzureCredential()
    token = credential.get_token("2ff814a6-3304-4ab8-85cb-cd0e6f879c1d/.default")

    headers = {
        "Authorization": f"Bearer {token.token}",
        "Content-Type": "application/json"
    }

    if conversation_id:
        # Continue existing conversation
        url = f"{WORKSPACE_URL}/api/2.0/genie/spaces/{GENIE_SPACE_ID}/conversations/{conversation_id}/messages"
    else:
        # Start new conversation
        url = f"{WORKSPACE_URL}/api/2.0/genie/spaces/{GENIE_SPACE_ID}/conversations/start"

    payload = {"content": question}
    response = requests.post(url, headers=headers, json=payload)
    response.raise_for_status()
    return response.json()

# Rate limit handler
class GenieClient:
    def __init__(self):
        self.calls = []

    def query(self, question: str, conversation_id: str = None) -> dict:
        now = time.time()
        # Remove calls older than 60 seconds
        self.calls = [t for t in self.calls if now - t < 60]

        if len(self.calls) >= 5:
            wait_time = 60 - (now - self.calls[0])
            time.sleep(wait_time + 1)
            self.calls = []

        result = query_genie(question, conversation_id)
        self.calls.append(time.time())
        return result
```

## As Function Tool in Agent

```python
genie_client = GenieClient()
active_conversation = {}

def ask_genie(question: str) -> str:
    """Query Databricks Genie. Use for structured data questions, business metrics, SQL-queryable data."""
    conv_id = active_conversation.get("id")
    result = genie_client.query(question, conv_id)

    # Save conversation ID for follow-ups
    if "conversation_id" in result:
        active_conversation["id"] = result["conversation_id"]

    return result.get("answer", "No answer returned from Genie")

genie_tool = FunctionTool(
    name="ask_genie",
    description="Query business data using natural language via Databricks Genie. Use for questions about sales, inventory, customers, financial metrics, or any structured data in Databricks. Rate limited to 5 questions/minute.",
    parameters={
        "type": "object",
        "properties": {
            "question": {
                "type": "string",
                "description": "Natural language question about the data, e.g. 'What were total sales in Q4 2024?'"
            }
        },
        "required": ["question"],
        "additionalProperties": False
    },
    strict=True
)
```

## Common Issues

**401 Unauthorized**
- Ensure Entra ID credentials have Databricks Contributor role
- Check that the Azure Databricks workspace is linked to Azure AI Foundry project

**Rate limit hit (429)**
- Implement exponential backoff
- Cache common query results in Azure AI Search vector store
- Batch multiple questions into single Genie conversation when possible

**Genie returns empty answer**
- Verify the Genie space has relevant data tables
- Check that the natural language question maps to available data
- Try rephrasing to be more specific about table/metric names
