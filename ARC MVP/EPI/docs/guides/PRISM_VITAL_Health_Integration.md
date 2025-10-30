# PRISM‑VITAL Health Integration (MCP + ARCX)

This guide describes how EPI integrates Apple HealthKit (and later Android Health Connect) via PRISM‑VITAL, writes PII‑reduced health JSON into MCP, and seals exports with ARCX.

## Overview
- PRISM‑VITAL: local health ingest and reduction (no cloud), producing canonical JSON.
- MCP: logical container for journal/media/health nodes and pointers.
- ARCX: AES‑256‑GCM encryption and Ed25519 signing over the MCP bundle.
- Privacy: user‑controlled redaction before encryption (timestamp clamping, vitals quantization; PII excluded by design).

## File Map (added)
- `lib/prism/vital/`
  - `prism_vital.dart` (API)
  - `models/` (`vital_metrics.dart`, `vital_window.dart`)
  - `reducers/` (`health_window_aggregator.dart`, `trend_analyzer.dart`)
  - `bridges/` (`healthkit_bridge_ios.dart`, `healthconnect_bridge_android.dart`)
- `lib/mcp/schema/` (`pointer_health.dart`, `node_health_summary.dart`, `mcp_redaction_policy.dart`)
- `lib/arc/ui/timeline/widgets/health_chip.dart`, `lib/arc/ui/health/health_detail_view.dart`
- `lib/settings/privacy/privacy_settings.dart`
- Tests under `test/prism_vital/`

## MCP Schemas
### PointerHealthV1 (pointer/health)
- `id`, `media_type: "health"`, `descriptor.interval`, `descriptor.unit_map`
- `sampling_manifest.windows[]` each with `start`, `end`, `summary`
- `integrity.content_hash` (sha256 of canonical JSON)
- `created_at`, `provenance`, `privacy.contains_pii=false`, `schema_version="pointer.v1"`

### NodeHealthSummaryV1 (health)
- `id`, `type: "health_summary"`, `timestamp`
- `content_summary`, `keywords[]`, `pointer_ref`, optional `embedding_ref`
- `provenance`, `schema_version="node.v1"`

Manifest should increment `counts.health_items` when present.

## PRISM‑VITAL Pipeline
1) Ingest raw samples via platform bridges as `VitalSample(metric, start, end, value)`
2) Aggregate into windows (1h/1d) using `HealthWindowAggregator`
3) Compute stats per window (avg/min/max HR, HRV median, steps sum, sleep metrics)
4) Optional trend tags (simple rules) via `TrendAnalyzer`
5) Emit `PointerHealthV1` and `NodeHealthSummaryV1`

## iOS HealthKit (first)
- Permissions: heart rate, HRV (SDNN/rMSSD), steps, sleep analysis
- Queries: `HKObserverQuery` + `HKAnchoredObjectQuery` for background delivery
- Units: bpm (HR), ms (HRV), count (steps), enum for sleep stages
- Security: no HK UUIDs or bundle IDs stored; NSFileProtectionComplete for temp
- Bridge: `lib/prism/vital/bridges/healthkit_bridge_ios.dart` (MethodChannel)

## Android Health Connect (second)
- Scaffold with feature flag and mock provider until device available
- Mirror normalization and output contract

## Privacy & Redaction (MCP layer)
- Settings: `removePII` (not applicable to health JSON—already excluded), `timestampPrecision: full|date_only`, `quantizeVitals: bool`
- Policy: `mcp_redaction_policy.dart` applies time clamping and HR/HRV quantization before writing JSON.
- Header privacy in ARCX reflects: `include_photos`, `photo_labels`, `timestamp_precision`, `pii_removed`, and can extend with `quantized` for health.

## ARCX Export/Import
- Export: include health pointers/nodes in MCP payload, compute `bundle_digest`, encrypt (AES‑256‑GCM), sign (Ed25519), package `.arcx`.
- Import: verify signature and AAD, decrypt, validate `bundle_digest`, load health items, ensure adapters/registrations as needed.
- No crypto changes required; only bundling canonicalization includes health directories:
  - `nodes/pointer/health/*.json`, `nodes/health/*.json`

## Minimal UI Hooks
- `HealthChip(summary, onTap)` for timeline row
- `HealthDetailView(pointerJson)` to render window summaries

## Testing
- Reducer aggregation unit test
- Redaction policy unit test (timestamp clamping, quantization)
- ARCX round‑trip placeholder (full integration on device/CI)

## Acceptance Criteria
- Schemas compile; health counts reflected in manifest
- iOS ingest returns pointer within ~2 seconds for 24h of hourly windows (with mock if needed)
- Privacy redaction applied pre‑encryption
- ARCX export/import preserves health data, validates digests
- Background updates trigger reduction and timeline update
- No PII fields present in health JSON
- Tests pass

## Security Notes
- Health JSON excludes personal identifiers by design
- Redaction controls are applied before ARCX encryption
- ARCX uses AES‑256‑GCM and Ed25519 with iOS Keychain/Secure Enclave

## Platform Setup (iOS)
- Xcode entitlements: HealthKit capability
- Info.plist usage descriptions for Health access
- Enable background delivery in app init once permissions granted

## Platform Setup (Android)
- Health Connect permissions in manifest (when enabling real device integration)
- Gate with feature flag; default to mock provider until permissions approved

## Troubleshooting
- If counts mismatch in manifest/ARCX header, ensure health directories are included before zipping
- If timestamps leak time with `date_only`, confirm policy applied before JSON serialization
- If signature verification fails, confirm header and payload canonicalization unchanged
