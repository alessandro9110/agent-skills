---
name: databricks-mosaic-ai-agents
description: Guides building and deploying custom AI agents on Databricks using Mosaic AI Agent Framework with LangGraph or LangChain. Use when creating agents with MLflow tracing, Unity Catalog functions as tools, Vector Search retrieval, or deploying agents via Databricks Asset Bundle jobs. Triggers on phrases like "build agent Databricks", "LangGraph Mosaic AI", "LangChain Databricks agent", "deploy agent MLflow", "UC function tool", "agent asset bundle", "Databricks agent job deployment", "Mosaic AI LangGraph".
license: MIT
compatibility: Requires Databricks workspace with Unity Catalog, MLflow 3.1.3+, databricks-langchain, langgraph or langchain, databricks-agents SDK. MCP server requires uv (install: curl -LsSf https://astral.sh/uv/install.sh | sh) — the ai-dev-kit repo is auto-cloned to ~/.databricks-ai-dev-kit during install. Works with Claude Code, Claude Desktop, VS Code with GitHub Copilot, and Cursor. Complements databricks-asset-bundles and langgraph-fundamentals skills.
metadata:
  author: Alessandro Armillotta
  version: 1.0.0
  category: databricks
  tags: [databricks, mosaic-ai, langgraph, langchain, mlflow, unity-catalog, agents, asset-bundle]
  dependencies:
    - name: databricks-asset-bundles
      repo: databricks-solutions/ai-dev-kit
      raw_base: https://raw.githubusercontent.com/databricks-solutions/ai-dev-kit/main/databricks-skills/databricks-asset-bundles
      files: [SKILL.md]
    - name: databricks-model-serving
      repo: databricks-solutions/ai-dev-kit
      raw_base: https://raw.githubusercontent.com/databricks-solutions/ai-dev-kit/main/databricks-skills/databricks-model-serving
      files: [SKILL.md]
    - name: databricks-vector-search
      repo: databricks-solutions/ai-dev-kit
      raw_base: https://raw.githubusercontent.com/databricks-solutions/ai-dev-kit/main/databricks-skills/databricks-vector-search
      files: [SKILL.md]
    - name: databricks-mlflow-evaluation
      repo: databricks-solutions/ai-dev-kit
      raw_base: https://raw.githubusercontent.com/databricks-solutions/ai-dev-kit/main/databricks-skills/databricks-mlflow-evaluation
      files: [SKILL.md]
    - name: langgraph-fundamentals
      repo: langchain-ai/langchain-skills
      raw_base: https://raw.githubusercontent.com/langchain-ai/langchain-skills/main/config/skills/langgraph-fundamentals
      files: [SKILL.md]
    - name: langgraph-persistence
      repo: langchain-ai/langchain-skills
      raw_base: https://raw.githubusercontent.com/langchain-ai/langchain-skills/main/config/skills/langgraph-persistence
      files: [SKILL.md]
    - name: langchain-fundamentals
      repo: langchain-ai/langchain-skills
      raw_base: https://raw.githubusercontent.com/langchain-ai/langchain-skills/main/config/skills/langchain-fundamentals
      files: [SKILL.md]
    - name: framework-selection
      repo: langchain-ai/langchain-skills
      raw_base: https://raw.githubusercontent.com/langchain-ai/langchain-skills/main/config/skills/framework-selection
      files: [SKILL.md]
    - name: databricks-lakebase-provisioned
      repo: databricks-solutions/ai-dev-kit
      raw_base: https://raw.githubusercontent.com/databricks-solutions/ai-dev-kit/main/databricks-skills/databricks-lakebase-provisioned
      files: [SKILL.md]
  mcp_servers:
    - name: databricks
      type: stdio
      command: uv
      args: run --directory AI_DEV_KIT_PATH python databricks-mcp-server/run_server.py
      path_var: AI_DEV_KIT_PATH
      path_hint: "Path to ai-dev-kit repo (press Enter to auto-clone to ~/.databricks-ai-dev-kit)"
      auto_clone: https://github.com/databricks-solutions/ai-dev-kit.git
      auto_clone_dir: ~/.databricks-ai-dev-kit
      setup_cmds: "uv pip install -e ./databricks-tools-core && uv pip install -e ./databricks-mcp-server"
      env_vars: "DATABRICKS_HOST:Databricks workspace URL (e.g. https://adb-xxx.azuredatabricks.net),DATABRICKS_TOKEN:Personal access token (leave empty to use ~/.databrickscfg profile)"
---

# Databricks Mosaic AI Agents

Guide for building custom AI agents on Databricks using LangGraph or LangChain, logging them with MLflow, and deploying via Databricks Asset Bundle jobs.

> **Related skills to load alongside this one:**
> - `databricks-asset-bundles` (from databricks-solutions/ai-dev-kit) — for bundle structure and deployment commands
> - `langgraph-fundamentals` (from langchain-ai/langchain-skills) — for LangGraph graph design patterns
> - `databricks-model-serving` (from databricks-solutions/ai-dev-kit) — for serving endpoint concepts
> - `databricks-lakebase-provisioned` (from databricks-solutions/ai-dev-kit) — for persistent agent memory via managed PostgreSQL

## Prerequisites

Ask the user for:
1. **Workspace URL** — `https://<workspace>.azuredatabricks.net`
2. **Unity Catalog target** — `catalog.schema` for model registration
3. **Agent framework** — LangGraph (recommended for stateful/multi-step) or LangChain
4. **Model endpoint** — e.g. `databricks-meta-llama-3-70b-instruct` or custom
5. **Tools needed** — UC functions, Vector Search, custom Python tools, Genie
6. **Deployment target** — Model Serving endpoint name

CRITICAL: Always confirm the UC catalog.schema before generating any deployment code.

## Instructions

### Step 1: Install Dependencies

```bash
pip install databricks-langchain langgraph mlflow databricks-agents databricks-sdk
```

### Step 2: Choose the Agent Framework

| Use LangGraph when | Use LangChain when |
|--------------------|--------------------|
| Multi-step reasoning with state | Simple ReAct agent loop |
| Human-in-the-loop needed | Straightforward tool calling |
| Complex conditional routing | Rapid prototyping |
| Persistent memory across turns | Chain-based workflows |

### Step 3: Build the Agent (Models from Code Pattern)

Create a standalone `agent.py` file — MLflow logs the file, not an object.

**LangGraph agent (`src/agent.py`):**
```python
import mlflow
from databricks_langchain import ChatDatabricks
from langchain_core.tools import tool
from langgraph.prebuilt import create_react_agent

mlflow.langchain.autolog()

# Define tools
@tool
def query_catalog(sql: str) -> str:
    """Execute a SQL query against Unity Catalog tables.
    Use for structured data retrieval, aggregations, and business metrics.

    Args:
        sql: Valid Spark SQL query against Unity Catalog tables
    Returns:
        Query results as formatted string
    """
    from databricks import sql as dbsql
    from databricks.sdk import WorkspaceClient
    ws = WorkspaceClient()
    conn = dbsql.connect(
        server_hostname=ws.config.host,
        http_path="/sql/1.0/warehouses/<warehouse-id>",
        credentials_provider=lambda: {"Authorization": f"Bearer {ws.config.token}"}
    )
    cursor = conn.cursor()
    cursor.execute(sql)
    rows = cursor.fetchall()
    cols = [d[0] for d in cursor.description]
    cursor.close(); conn.close()
    return "\n".join([str(dict(zip(cols, r))) for r in rows])

# Initialize model
llm = ChatDatabricks(
    endpoint="databricks-meta-llama-3-70b-instruct",
    temperature=0.1,
    max_tokens=2000
)

# Create agent
tools = [query_catalog]
agent = create_react_agent(
    llm,
    tools,
    state_modifier="You are a data analyst assistant. Use query_catalog to answer data questions. Always explain your SQL logic."
)

# REQUIRED: set_model so MLflow knows what to log
mlflow.models.set_model(agent)
```

### Step 4: Log Agent with MLflow

Create a driver notebook or script (`src/deploy_agent.py`):

```python
import mlflow

mlflow.set_registry_uri("databricks-uc")
mlflow.set_tracking_uri("databricks")

UC_MODEL_NAME = "catalog.schema.agent_name"  # Replace with actual UC path
AGENT_CODE_PATH = "./src/agent.py"

input_example = {
    "messages": [{"role": "user", "content": "How many orders were placed last month?"}]
}

# Log agent as MLflow model
with mlflow.start_run():
    logged_info = mlflow.langchain.log_model(
        lc_model=AGENT_CODE_PATH,
        artifact_path="agent",
        input_example=input_example,
        example_no_conversion=True,
        pip_requirements=[
            "databricks-langchain",
            "langgraph",
            "mlflow",
            "databricks-agents",
        ]
    )
    print(f"Logged model URI: {logged_info.model_uri}")

# Register in Unity Catalog
model_version = mlflow.register_model(
    model_uri=logged_info.model_uri,
    name=UC_MODEL_NAME
)
print(f"Registered: {UC_MODEL_NAME} version {model_version.version}")
```

### Step 5: Deploy via Asset Bundle Job

See `references/bundle-deployment.md` for the complete bundle structure.

**Key bundle files:**

`databricks.yml` (main config):
```yaml
bundle:
  name: my-agent-bundle

include:
  - resources/*.yml

variables:
  catalog:
    default: "dev_catalog"
  schema:
    default: "dev_schema"
  endpoint_name:
    default: "my-agent-endpoint-dev"
  model_name:
    default: "my_agent"

targets:
  dev:
    default: true
    mode: development
    workspace:
      profile: dev-profile
    variables:
      catalog: "dev_catalog"
      schema: "dev_schema"
      endpoint_name: "my-agent-endpoint-dev"

  prod:
    mode: production
    workspace:
      profile: prod-profile
    variables:
      catalog: "prod_catalog"
      schema: "prod_schema"
      endpoint_name: "my-agent-endpoint"
```

`resources/deploy_job.yml` (deployment job):
```yaml
resources:
  jobs:
    deploy_agent:
      name: "[${bundle.target}] Deploy Agent - ${var.model_name}"
      tasks:
        - task_key: log_and_register
          python_wheel_task:
            package_name: "my_agent"
            entry_point: "deploy"
          libraries:
            - pypi:
                package: "databricks-langchain"
            - pypi:
                package: "langgraph"
            - pypi:
                package: "mlflow"
            - pypi:
                package: "databricks-agents"
          new_cluster:
            spark_version: "15.4.x-cpu-ml-scala2.12"
            node_type_id: "i3.xlarge"
            num_workers: 1
            spark_env_vars:
              UC_CATALOG: "${var.catalog}"
              UC_SCHEMA: "${var.schema}"
              ENDPOINT_NAME: "${var.endpoint_name}"
              MODEL_NAME: "${var.model_name}"
      permissions:
        - level: CAN_MANAGE_RUN
          group_name: "users"
```

**Deploy and run:**
```bash
# Validate
databricks bundle validate -t dev

# Deploy bundle (creates job)
databricks bundle deploy -t dev

# Run the deployment job
databricks bundle run deploy_agent -t dev

# Deploy to prod
databricks bundle deploy -t prod
databricks bundle run deploy_agent -t prod
```

### Step 6: Add Unity Catalog Functions as Tools

For reusable, governed tools stored in Unity Catalog:

See `references/uc-tools.md` for full setup.

```python
from databricks_langchain import UCFunctionToolkit
from databricks.sdk import WorkspaceClient

ws = WorkspaceClient()

# Load all functions from a UC schema as tools
toolkit = UCFunctionToolkit(
    warehouse_id="<warehouse-id>",
    client=ws
)
uc_tools = toolkit.get_tools(
    tool_names=["catalog.schema.calculate_metrics", "catalog.schema.get_customer_info"]
)

agent = create_react_agent(llm, uc_tools)
```

### Step 7: Add Vector Search (RAG)

```python
from databricks_langchain import DatabricksVectorSearch
from langchain.tools.retriever import create_retriever_tool

vs = DatabricksVectorSearch(
    index_name="catalog.schema.my_vector_index"
)
retriever = vs.as_retriever(search_kwargs={"k": 5})

search_tool = create_retriever_tool(
    retriever,
    "search_knowledge_base",
    "Search internal documentation and knowledge base. Use for policy questions, product info, and unstructured content."
)

agent = create_react_agent(llm, [search_tool, query_catalog])
```

## Step 8: Persistent Memory with Lakebase

Model Serving endpoints are stateless — LangGraph state does not persist across invocations. Use **Lakebase Provisioned** (managed PostgreSQL on Databricks) as the external store for agent memory, chat history, and LangGraph checkpoints.

### Create Lakebase Instance

If the `databricks` MCP server is active, create the instance directly from the IDE:

```
Tool: create_or_update_lakebase_database
Input: {
  "type": "provisioned",
  "name": "my-agent-memory",
  "capacity": "CU_1",
  "stopped": false
}
```

Or via SDK:

```python
from databricks.sdk import WorkspaceClient

w = WorkspaceClient()
instance = w.database.create_database_instance(
    name="my-agent-memory",
    capacity="CU_1",
    stopped=False
)
print(f"Endpoint: {instance.read_write_dns}")
```

### Install Memory Dependencies

```bash
pip install "databricks-langchain[memory]" "psycopg[binary]>=3.0"
```

### LangGraph Checkpointer (Stateful Agent)

Use a PostgreSQL checkpointer to persist the LangGraph state across invocations:

```python
import mlflow
from databricks_langchain import ChatDatabricks
from langgraph.prebuilt import create_react_agent
from langgraph.checkpoint.postgres import PostgresSaver
from databricks.sdk import WorkspaceClient
import uuid

mlflow.langchain.autolog()

w = WorkspaceClient()
instance = w.database.get_database_instance(name="my-agent-memory")
cred = w.database.generate_database_credential(
    request_id=str(uuid.uuid4()),
    instance_names=["my-agent-memory"]
)

conn_string = (
    f"host={instance.read_write_dns} "
    f"dbname=postgres "
    f"user={w.current_user.me().user_name} "
    f"password={cred.token} "
    f"sslmode=require"
)

checkpointer = PostgresSaver.from_conn_string(conn_string)
checkpointer.setup()  # Creates checkpoint tables on first run

llm = ChatDatabricks(endpoint="databricks-meta-llama-3-70b-instruct")
agent = create_react_agent(llm, tools, checkpointer=checkpointer)

# Invoke with thread_id to maintain state across calls
config = {"configurable": {"thread_id": "user-session-123"}}
result = agent.invoke({"messages": [{"role": "user", "content": "Hello"}]}, config)

mlflow.models.set_model(agent)
```

### Declare Lakebase as MLflow Resource

This enables automatic credential provisioning on the serving endpoint — no manual token management needed:

```python
from mlflow.models.resources import DatabricksLakebase

with mlflow.start_run():
    logged_info = mlflow.langchain.log_model(
        lc_model="./src/agent.py",
        artifact_path="agent",
        input_example=input_example,
        example_no_conversion=True,
        resources=[
            DatabricksLakebase(database_instance_name="my-agent-memory")
        ],
        pip_requirements=[
            "databricks-langchain[memory]",
            "langgraph",
            "mlflow",
            "databricks-agents",
            "psycopg[binary]>=3.0",
        ]
    )
```

### Check Instance Status via MCP

```
Tool: get_lakebase_database
Input: { "type": "provisioned", "name": "my-agent-memory" }
```

### Generate Credentials via MCP

```
Tool: generate_lakebase_credential
Input: { "instance_names": ["my-agent-memory"] }
```

## MLflow Tracing

MLflow auto-tracing captures every agent step. View traces in the Databricks UI:
- **Experiments** → select your experiment → **Traces** tab
- Each trace shows: input, tool calls, intermediate steps, output, latency

```python
# Enable auto-tracing (add to agent.py)
mlflow.langchain.autolog()

# Or manually set experiment
mlflow.set_experiment("/Shared/my-agent-experiment")
```

## Common Issues

**`ModuleNotFoundError` on serving endpoint**
- Add all dependencies to `pip_requirements` in `log_model()`
- Pin versions: `databricks-langchain==0.3.0`

**MLflow tracing not working from Git folder**
- Set experiment before deployment:
  ```python
  mlflow.set_experiment("/Shared/my-agent-experiment")  # non-Git path
  ```

**UC function tool not found**
- Verify the function exists: `SELECT * FROM system.information_schema.routines WHERE routine_name = 'my_function'`
- Check warehouse has access to the catalog

**Deployment job times out**
- Model Serving deployment takes ~15 min — use async `deploy()` and poll status
- Do not set job timeout below 20 minutes
- If the `databricks` MCP is active, use `get_serving_endpoint_status` to check readiness:
  ```
  Tool: get_serving_endpoint_status
  Input: { "endpoint_name": "my-agent-endpoint" }
  ```
  Or list all endpoints: `list_serving_endpoints` (no input required)

**LangGraph state not persisting across invocations**
- Use Lakebase Provisioned as PostgreSQL checkpointer — see **Step 8: Persistent Memory with Lakebase**
- Declare `DatabricksLakebase` as MLflow resource for automatic credential provisioning on the endpoint
