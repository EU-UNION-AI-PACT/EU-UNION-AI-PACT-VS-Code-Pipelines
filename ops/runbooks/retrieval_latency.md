# Runbook: Slow Vector Queries

Alert: SlowVectorQueries (p95 > 600ms)

## Checks

1. Vector store I/O:

```bash
iostat -xz 1 5
```

2. Chroma process CPU & memory.
3. Disk saturation (fs stats).
4. Model embedding backlog (queue length metrics if instrumented).

## Quick Fixes

- Increase Chroma retention config / optimize index.
- Add ephemeral SSD node pool, move vector store.
- Enable hybrid retrieval only when needed (reduce k or alpha tuning).
