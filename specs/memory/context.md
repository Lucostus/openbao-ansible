# SpecOps Memory Context

This memory layer was initialized on 2026-07-30 for the OpenBao HA Ansible
repository.

### 2026-07-30-openbao-vector-opensearch-logging

Implemented optional Vector log forwarding for OpenBao audit and service logs.
The feature is disabled by default, uses OpenBao Agent-rendered directory
secrets for OpenSearch credentials, and forwards through Vector's
Elasticsearch/OpenSearch sink. The Agent identity flow now lives in shared
OpenBao common tasks so it can serve listener certificate renewal, Vector
secret rendering, or both. Replacement cleanup stops Vector and removes managed
Vector config, state, and rendered secrets, but leaves packages and external
operator inputs in place. Docker lab validation passed for default site,
upgrade, Vector enablement, repeated replacement with seeded credentials, and
mock OpenSearch ingestion.
