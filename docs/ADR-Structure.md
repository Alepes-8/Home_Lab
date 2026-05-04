# ADR-001: Use Docker Compose Instead of Kubernetes

## Status
Accepted

## Context
The project requires container orchestration for:
- API
- Database
- Reverse proxy
- Monitoring stack

Expected scale:
- Single host
- Low traffic
- Personal portfolio project
- Limited maintenance overhead

## Decision
Use Docker Compose for service orchestration.

## Alternatives Considered

### Kubernetes
Pros:
- Industry standard
- Scalable
- Self-healing

Cons:
- High operational complexity
- Overkill for single-node deployment
- Slower development velocity

### Manual systemd services
Pros:
- Lightweight

Cons:
- Poor portability
- Harder dependency management

## Consequences

Positive:
- Fast deployment
- Easy local development
- Lower maintenance burden

Negative:
- Limited horizontal scaling
- Fewer advanced orchestration features

## Review Trigger
Revisit if traffic exceeds single-host capacity or multi-node deployment is needed.