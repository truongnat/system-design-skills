# SRE & Incident Management

Use this file to design Monitoring (Observability) systems and Incident Response processes.

## 📊 Observability (3 Pillars)

### 1. Metrics
Monitor system health through quantitative data.
- **Tools:** Prometheus + Grafana, Datadog.
- **RED Metrics:** Requests (Rate), Errors, Duration (Latency).

### 2. Logs
Used for debugging and root cause analysis.
- **Tools:** ELK Stack (Elasticsearch, Logstash, Kibana), Loki.
- **Structured Logging:** Record logs in JSON for easy querying.

### 3. Tracing
Track a single request across multiple microservices.
- **Tools:** Jaeger, Tempo.
- **Standard:** OpenTelemetry (Vendor-neutral).

---

## 📈 SRE Principles

### 1. SLI / SLO / SLA
- **SLI (Indicator):** Real-world metrics (e.g., HTTP 200 rate).
- **SLO (Objective):** Target goal (e.g., 99.9% success rate).
- **SLA (Agreement):** Business commitment to customers (e.g., 99.5% - compensation if violated).

### 2. Error Budget
The allowed margin for failure within a month (e.g., 1 - 99.9% = 0.1%).
- **If budget is exhausted:** Stop new feature deploys, focus on fixes/Reliability.

---

## 🚒 Incident Response

### 1. 4-Step Process
1. **Detection:** Alerting systems (Slack/PagerDuty) notify the team.
2. **Triage:** Assess priority (P0, P1, P2).
3. **Mitigation:** Roll back code immediately (Priority #1: Minimize damage).
4. **Resolution:** Fix the bug and push the hotfix.

### 2. Post-mortem
Conduct "Blameless" post-mortem reports.
- **Content:** What happened? Why? How to prevent it? Lessons learned?

---

## 🔴 SRE Checklist
- [ ] Are **Alerting** (Slack/Email/Phone) mechanisms configured?
- [ ] Are **Dashboards** in place for critical metrics (Golden Signals)?
- [ ] Is there an **On-call** process (Who is on duty at night/weekends)?
- [ ] Is a **Post-mortem** record created for every P0/P1 incident?
