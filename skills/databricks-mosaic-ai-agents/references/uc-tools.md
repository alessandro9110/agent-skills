# Unity Catalog Functions as Agent Tools

## Why Use UC Functions as Tools

- **Governed**: Access control via UC permissions (GRANT/REVOKE)
- **Reusable**: Same function used by multiple agents
- **Auditable**: All invocations logged in Unity Catalog audit logs
- **Discoverable**: Agents can auto-discover tools from a schema

## Define UC Functions (SQL)

```sql
-- Python function
CREATE OR REPLACE FUNCTION catalog.schema.get_sales_by_region(
  region STRING COMMENT 'Region name, e.g. EMEA, APAC, AMER',
  start_date DATE COMMENT 'Start date for the period',
  end_date DATE COMMENT 'End date for the period'
)
RETURNS TABLE(region STRING, total_sales DOUBLE, order_count BIGINT)
LANGUAGE SQL
COMMENT 'Returns sales aggregates by region for a given date range. Use for sales performance questions.'
RETURN
  SELECT region, SUM(amount) as total_sales, COUNT(*) as order_count
  FROM catalog.schema.orders
  WHERE region = get_sales_by_region.region
    AND order_date BETWEEN start_date AND end_date
  GROUP BY region;

-- Simple scalar function
CREATE OR REPLACE FUNCTION catalog.schema.format_currency(
  amount DOUBLE COMMENT 'Amount to format',
  currency STRING COMMENT 'Currency code, e.g. EUR, USD'
)
RETURNS STRING
LANGUAGE SQL
COMMENT 'Formats a numeric amount as a currency string.'
RETURN CONCAT(currency, ' ', FORMAT_NUMBER(amount, 2));
```

## Load UC Tools in Agent

```python
from databricks_langchain import UCFunctionToolkit
from databricks.sdk import WorkspaceClient
from langgraph.prebuilt import create_react_agent
from databricks_langchain import ChatDatabricks

ws = WorkspaceClient()

# Option A: Load specific functions
toolkit = UCFunctionToolkit(
    warehouse_id="<sql-warehouse-id>",
    client=ws
)
tools = toolkit.get_tools(
    tool_names=[
        "catalog.schema.get_sales_by_region",
        "catalog.schema.format_currency",
        "catalog.schema.get_customer_info"
    ]
)

# Option B: Load all functions from a schema
tools = toolkit.get_tools(
    tool_names=["catalog.schema.*"]  # All functions in schema
)

llm = ChatDatabricks(endpoint="databricks-meta-llama-3-70b-instruct")
agent = create_react_agent(llm, tools)
```

## Grant Access to UC Functions

```sql
-- Grant execute to a user
GRANT EXECUTE ON FUNCTION catalog.schema.get_sales_by_region TO `user@company.com`;

-- Grant execute to a group
GRANT EXECUTE ON FUNCTION catalog.schema.get_sales_by_region TO `data-analysts`;

-- Grant execute to a service principal (for agent serving endpoint)
GRANT EXECUTE ON FUNCTION catalog.schema.get_sales_by_region TO `<service-principal-id>`;
```

## Tool Description Best Practices

The function `COMMENT` becomes the tool description — write it as if describing to an LLM:

```sql
-- GOOD: specific, includes trigger conditions and parameter guidance
COMMENT 'Returns monthly revenue breakdown by product category. Use when asked about revenue trends, product performance, or category analysis. Provide month as YYYY-MM format.'

-- BAD: too generic
COMMENT 'Gets revenue data'
```

## Troubleshooting

**Tool not found by agent**
- Verify function exists: `SHOW FUNCTIONS IN catalog.schema`
- Check warehouse has USE CATALOG and USE SCHEMA privileges

**Permission denied on execution**
- Grant EXECUTE to the agent's service principal
- Check UC audit logs: `SELECT * FROM system.access.audit WHERE action_name = 'executeFunction'`

**Incorrect parameter types**
- UC function parameters are strictly typed — ensure the agent passes correct types
- Add type examples in the COMMENT field
