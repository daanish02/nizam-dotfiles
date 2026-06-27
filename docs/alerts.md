# Grafana Alerts

Unified alerting via Grafana → Discord. Two severity levels, two contact points.

## Contact Points

| Name | Channel | Trigger |
|---|---|---|
| `nizam-warn` | #alerts (warning webhook) | `severity=warning` |
| `nizam-crit` | #alerts (critical webhook) | `severity=critical` |

Webhooks are stored in Grafana's database. To update: Grafana → Alerting → Contact points.

## Routing

| Severity | Group wait | Repeat |
|---|---|---|
| warning | 30s | 4h |
| critical | 10s | 1h |

Critical fires fast and repeats often. Warning batches and stays quiet once acknowledged.

## Alert Rules

All rules live in folder `nizam-alerts`, group `nizam-system`.

| Rule | Query | Warning | Critical | For |
|---|---|---|---|---|
| CPU High | `rate(node_cpu_seconds_total{mode='idle'}[5m])` | >70% | >90% | 5m |
| RAM High | `1 - MemAvailable / MemTotal` | >75% | >90% | 5m |
| Disk Full | `/` usage % | >70% | >90% | 1m |
| Load Avg High | `node_load5` | >2.0 | >4.0 | 3m |
| Fail2ban Spike | `increase(nizam_fail2ban_bans_total[5m])` | >5 new | >20 new | 1m |

Each threshold has a separate rule with a `severity` label — routing picks the right channel automatically.

## Managing Alerts

**View rules:** Grafana → Alerting → Alert rules → folder `nizam-alerts`

**Silence an alert:** Grafana → Alerting → Silences → Add silence (set matcher + duration)

**Test a contact point:** Grafana → Alerting → Contact points → `nizam-warn` or `nizam-crit` → Test

**Change a threshold:** Grafana → Alert rules → edit rule → adjust evaluator value → Save. Or re-run the provisioning script with updated values.

## Adding New Rules

Use the Grafana API — same pattern as the existing rules. Label `severity=warning` or `severity=critical` is all the routing needs.

```bash
# Example: alert if a custom metric exceeds a threshold
curl -s -X POST http://localhost:3000/api/v1/provisioning/alert-rules \
  -H 'Content-Type: application/json' \
  -u admin:admin \
  -d '{ ... }'
```
