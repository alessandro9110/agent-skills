# Vector DB Integration — Azure AI Foundry

## Overview
Azure AI Foundry agents support Azure AI Search as a managed vector store for RAG (Retrieval-Augmented Generation) workflows.

## Capabilities
- Full-text + vector similarity + semantic reranking in a single query
- Automatic file parsing, chunking, and embedding
- Bring-Your-Own Azure AI Search index and Azure Blob Storage
- Data residency and compliance control

## Setup: File Search Tool (Managed)

```python
from azure.ai.projects.models import FileSearchTool, VectorStoreConfiguration

# Option A: Let Foundry manage the vector store
# Upload files and get a vector store ID from Azure AI Foundry portal
# Settings > Vector Stores > Create

# Option B: Bring your own Azure AI Search index
vector_store_config = VectorStoreConfiguration(
    azure_ai_search={
        "endpoint": "https://<search-service>.search.windows.net",
        "index_name": "<your-index>",
        "connection_name": "<project-connection-name>"  # Defined in AI Foundry project
    }
)

file_search = FileSearchTool(
    vector_store_ids=["<vector_store_id>"]
    # OR use vector_store_configurations=[vector_store_config] for BYOS
)

agent = project.agents.create_version(
    agent_name="rag-agent",
    definition=PromptAgentDefinition(
        model="gpt-4o",
        instructions="""You are a knowledge assistant with access to a document repository.
When answering:
1. Always search the knowledge base before responding
2. Cite the source document for each piece of information
3. If information is not in the knowledge base, say so explicitly
4. Format responses clearly with sections when appropriate""",
        tools=[file_search]
    )
)
```

## Upload Files to Vector Store (Python)

```python
import os

# Upload a single file
with open("document.pdf", "rb") as f:
    uploaded_file = project.agents.upload_file(
        file=f,
        purpose="assistants"
    )

# Create vector store and add file
vector_store = project.agents.create_vector_store(
    name="my-knowledge-base",
    file_ids=[uploaded_file.id]
)

print(f"Vector store ID: {vector_store.id}")
```

## Combined Agent: Vector DB + Function Calling

```python
from azure.ai.projects.models import FunctionTool, FileSearchTool

# Agent that searches knowledge base AND calls APIs
hybrid_agent = project.agents.create_version(
    agent_name="hybrid-agent",
    definition=PromptAgentDefinition(
        model="gpt-4o",
        instructions="""You are an intelligent assistant with:
1. Access to internal documentation (use file search for policy, process, product questions)
2. Access to live data APIs (use functions for real-time data)

Combine both sources when needed for comprehensive answers.""",
        tools=[
            file_search,      # For static knowledge base
            live_data_tool    # FunctionTool for real-time data
        ]
    )
)
```

## Azure AI Search Index Schema (BYOS)

When bringing your own index, ensure it has:
```json
{
  "fields": [
    {"name": "id", "type": "Edm.String", "key": true},
    {"name": "content", "type": "Edm.String", "searchable": true},
    {"name": "content_vector", "type": "Collection(Edm.Single)", "dimensions": 1536, "vectorSearchProfile": "default"},
    {"name": "source", "type": "Edm.String", "filterable": true},
    {"name": "title", "type": "Edm.String", "searchable": true}
  ]
}
```

## Best Practices
- Use semantic ranking (`semantic_configuration`) for better answer quality
- Chunk documents at 512-1024 tokens with 10-20% overlap
- Include metadata fields (source, date, author) for citation
- For large knowledge bases (10k+ documents), use hybrid search (keyword + vector)
- Cache frequent query patterns to reduce search costs
