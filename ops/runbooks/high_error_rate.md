# Runbook: HighErrorRate

Alert Name: HighErrorRate  
Severity: page  
Owner: NLP SRE Team

## 1. Triage
- Check Grafana Panel "Error Rate %".
- Confirm spike vs steady incline (compare 1h vs 24h).
- Inspect recent deploys: `git log -n 5` & CD pipeline status.

## 2. Quick Diagnostics
```bash
kubectl get pods -l app=gateway
kubectl logs deploy/gateway --tail=200 | grep -i error
```
Check upstream services (docproc, embedding).

## 3. Common Causes
| Cause | Check | Mitigation |
|-------|-------|------------|
| Upstream embed model timeout | Gateway logs timeout | Increase timeout / scale embedding |
| DB latency | pg_stat_statements, CPU saturation | Add index / scale CPU |
| Vault latency (sign/encrypt) | ip-guard / docproc logs | Enable caching / batch sign |

## 4. Mitigation Steps
- Rollback last deployment (Blue/Green) if correlated.
- Scale embedding replicas:
```bash
kubectl scale deploy/embedding --replicas=+2
```
- Reduce per-request concurrency / enforce queue.

## 5. Post-Incident
- Update SLO burn report
- Root Cause Doc in incident/<ID>.md
- Add test or synthetic probe replicating failure.

## 6. Escalation
- If unresolved in 30m: escalate to Platform Lead.
