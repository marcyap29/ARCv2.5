# Golden Bundle — mcp_chats_2025-09_mixed_versions

This bundle proves backward compatibility:
- Legacy **node.v1** records (journal Entry + Keyword nodes)
- New **node.v2** records (ChatSession + ChatMessage)
- Mixed in the **same** month and bundle

## Contents
- `nodes.jsonl`: 3 legacy node.v1 + 3 chat node.v2 records
- `edges.jsonl`: `mentions` edges for legacy; `contains` edges for chat with zero-based `metadata.order`
- `pointers.jsonl`: optional pointer to the session
- `manifest.json`: file inventory + checksums (fill via script)

## Validation

Validate both versions. Readers must accept `node.v1` and `node.v2` in the same bundle.

```bash
# Validate node.v2 chat records
ajv validate -s ../../bundle/schemas/node.v2.json -d nodes.jsonl --spec=draft2020

# Validate chat profiles strictly (optional)
ajv validate -s ../../bundle/schemas/chat_session.v1.json -d nodes.jsonl --spec=draft2020
ajv validate -s ../../bundle/schemas/chat_message.v1.json -d nodes.jsonl --spec=draft2020

# Validate node.v1 legacy records with the original schema
ajv validate -s ../../bundle/schemas/node.v1.json -d nodes.jsonl --spec=draft2020

# Edges
ajv validate -s ../../bundle/schemas/edge.v1.json -d edges.jsonl --spec=draft2020
```

## Notes

* Do not mutate version fields. Writers must preserve node.v1 records as-is.
* Importers should route node.v1 entries/keywords into MIRA using existing adapters.
* IDs are stable (ULIDs or deterministic IDs) to maintain graph continuity.
