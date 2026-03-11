# Function Calling — Azure AI Foundry

## 5-Step Workflow

1. **Define functions** — name, description, JSON schema parameters
2. **Create agent** — register agent with function definitions
3. **Send user prompt** — agent analyzes and requests function calls if needed
4. **Execute & return** — app runs function, submits output back
5. **Get final response** — agent uses output to complete answer

## Tool Types Available

| Tool | Description | Use Case |
|------|-------------|----------|
| `FunctionTool` | Custom stateless functions | Quick operations |
| Azure Functions | Managed stateful functions | Long-running operations |
| `McpTool` | Model Context Protocol endpoints | Standardized integrations |
| `FileSearchTool` | Vector-based document retrieval | RAG / knowledge base |
| Code Interpreter | Execute Python code | Data analysis |
| Browser Automation | Real-world browser interactions | Web automation |

## Full Python Example

```python
from azure.ai.projects import AIProjectClient
from azure.ai.projects.models import PromptAgentDefinition, FunctionTool
from azure.identity import DefaultAzureCredential
from openai.types.responses.response_input_param import FunctionCallOutput
import json

PROJECT_ENDPOINT = "https://<resource>.ai.azure.com/api/projects/<project>"

project = AIProjectClient(endpoint=PROJECT_ENDPOINT, credential=DefaultAzureCredential())
openai = project.get_openai_client()

# 1. Define function implementation
def get_weather(location: str, unit: str = "celsius") -> dict:
    # Replace with real implementation
    return {"temperature": 22, "unit": unit, "condition": "sunny", "location": location}

# 2. Define tool schema
weather_tool = FunctionTool(
    name="get_weather",
    description="Get current weather for a given city. Use when user asks about weather, temperature, or forecast.",
    parameters={
        "type": "object",
        "properties": {
            "location": {
                "type": "string",
                "description": "City and country, e.g. 'Milan, Italy' or 'New York, US'"
            },
            "unit": {
                "type": "string",
                "enum": ["celsius", "fahrenheit"],
                "description": "Temperature unit. Default celsius."
            }
        },
        "required": ["location"],
        "additionalProperties": False
    },
    strict=True
)

# 3. Create agent
agent = project.agents.create_version(
    agent_name="weather-agent",
    definition=PromptAgentDefinition(
        model="gpt-4o-mini",
        instructions="You are a weather assistant. Use get_weather to answer weather questions. Always include the unit in your response.",
        tools=[weather_tool]
    )
)

# 4. Send prompt and handle function call loop
response = openai.responses.create(
    input="What's the weather in Milan?",
    extra_body={"agent_reference": {"name": agent.name, "type": "agent_reference"}}
)

# 5. Process function calls
while any(item.type == "function_call" for item in response.output):
    tool_outputs = []
    for item in response.output:
        if item.type == "function_call":
            args = json.loads(item.arguments)
            if item.name == "get_weather":
                result = get_weather(**args)
                tool_outputs.append(FunctionCallOutput(
                    type="function_call_output",
                    call_id=item.call_id,
                    output=json.dumps(result)
                ))

    response = openai.responses.create(
        input=tool_outputs,
        previous_response_id=response.id,
        extra_body={"agent_reference": {"name": agent.name, "type": "agent_reference"}}
    )

print(f"Final response: {response.output_text}")

# Cleanup
project.agents.delete_version(agent_name=agent.name, agent_version=agent.version)
```

## Multiple Tools Example

```python
tools = [
    FunctionTool(name="get_weather", description="...", parameters={...}),
    FunctionTool(name="get_forecast", description="...", parameters={...}),
    FunctionTool(name="set_alert", description="...", parameters={...}),
]

agent = project.agents.create_version(
    agent_name="weather-pro-agent",
    definition=PromptAgentDefinition(
        model="gpt-4o",
        instructions="You are a weather assistant. Use available tools as needed.",
        tools=tools
    )
)
```

## Best Practices

- **Required parameters**: mark in schema `"required"` array
- **Clear names**: `get_weather` not `gw`
- **Detailed descriptions**: include when to use + examples
- **Structured returns**: return JSON objects, not plain strings
- **Strict mode**: always set `strict=True` to enforce schema
- **Timeout**: function calls must return within 50 seconds; entire run expires in 10 minutes

## Constraints
- Non-streaming function calls: 50-second timeout
- Total agent run lifetime: 10 minutes from creation
- Always return tool outputs promptly to avoid run expiration
