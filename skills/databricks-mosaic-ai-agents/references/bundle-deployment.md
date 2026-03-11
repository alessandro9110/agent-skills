# Agent Deployment via Asset Bundle

> For general DABs syntax and commands, see the `databricks-asset-bundles` skill from databricks-solutions/ai-dev-kit.
> This file covers the agent-specific deployment patterns only.

## Complete Bundle Structure for Agent Deployment

```
my-agent/
├── databricks.yml              # Bundle config + targets
├── resources/
│   └── deploy_job.yml          # Deployment job definition
└── src/
    ├── agent.py                # Agent code (logged by MLflow)
    └── deploy_agent.py         # Driver script: log → register → deploy
```

## deploy_agent.py — Full Script

```python
"""
Driver script for logging, registering, and deploying the agent.
Run via Databricks job in the Asset Bundle.
"""
import os
import mlflow
from databricks.agents import deploy, get_deploy_client

# Read from job environment variables (set in bundle)
UC_CATALOG = os.environ["UC_CATALOG"]
UC_SCHEMA = os.environ["UC_SCHEMA"]
ENDPOINT_NAME = os.environ["ENDPOINT_NAME"]
MODEL_NAME = os.environ["MODEL_NAME"]
UC_MODEL_NAME = f"{UC_CATALOG}.{UC_SCHEMA}.{MODEL_NAME}"

mlflow.set_registry_uri("databricks-uc")
mlflow.set_experiment(f"/Shared/{MODEL_NAME}-experiment")

# 1. Log agent
input_example = {
    "messages": [{"role": "user", "content": "test question"}]
}

with mlflow.start_run():
    logged_info = mlflow.langchain.log_model(
        lc_model="./src/agent.py",
        artifact_path="agent",
        input_example=input_example,
        example_no_conversion=True,
        pip_requirements=[
            "databricks-langchain>=0.3.0",
            "langgraph>=0.2.0",
            "mlflow>=3.1.3",
            "databricks-agents>=1.1.0",
            "databricks-sdk",
        ]
    )
    print(f"Logged: {logged_info.model_uri}")

# 2. Register in Unity Catalog
model_version = mlflow.register_model(
    model_uri=logged_info.model_uri,
    name=UC_MODEL_NAME
)
version_number = model_version.version
print(f"Registered: {UC_MODEL_NAME} v{version_number}")

# 3. Deploy to Model Serving
deployment = deploy(
    model_name=UC_MODEL_NAME,
    model_version=version_number,
    endpoint_name=ENDPOINT_NAME,
    scale_to_zero=True,
    environment_vars={
        "DATABRICKS_HOST": "{{secrets/scope/databricks_host}}",
        "DATABRICKS_TOKEN": "{{secrets/scope/databricks_token}}"
    }
)
print(f"Deployment started: {ENDPOINT_NAME}")
print(f"Status: {deployment.state}")
```

## Bundle YAML — model_serving_endpoints Alternative

Instead of a job, you can declare the endpoint directly in the bundle (infrastructure-as-code):

```yaml
# resources/serving_endpoint.yml
resources:
  model_serving_endpoints:
    agent_endpoint:
      name: "${var.endpoint_name}"
      config:
        served_entities:
          - entity_name: "${var.catalog}.${var.schema}.${var.model_name}"
            entity_version: "1"         # Pin version or use latest
            workload_size: "Small"
            scale_to_zero_enabled: true
        traffic_config:
          routes:
            - served_model_name: "${var.catalog}.${var.schema}.${var.model_name}-1"
              traffic_percentage: 100
      tags:
        - key: "environment"
          value: "${bundle.target}"
```

## When to Use Job vs. Direct Endpoint Declaration

| Pattern | When to Use |
|---------|-------------|
| **Job (log → register → deploy)** | New model version on every deploy, CI/CD pipeline, need MLflow run tracking |
| **Endpoint declaration in bundle** | Endpoint already exists, just updating config/routing, infrastructure changes |

## Recommended CI/CD Flow

```
git push → CI pipeline:
  1. databricks bundle validate -t prod
  2. databricks bundle deploy -t prod        # Creates/updates job
  3. databricks bundle run deploy_agent -t prod  # Runs log+register+deploy
  4. Poll endpoint until READY
```

## Poll Endpoint Status

```python
from databricks.agents import get_deploy_client

client = get_deploy_client("databricks")
endpoint = client.get_endpoint(ENDPOINT_NAME)

import time
while endpoint["state"]["config_update"] == "IN_PROGRESS":
    print(f"Waiting... status: {endpoint['state']}")
    time.sleep(30)
    endpoint = client.get_endpoint(ENDPOINT_NAME)

print(f"Endpoint ready: {endpoint['state']}")
```
