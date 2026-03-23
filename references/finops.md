# FinOps — Cloud Financial Operations — Reference

FinOps = Financial + DevOps. Discipline giúp team có financial accountability
cho cloud spend mà không hy sinh speed hoặc reliability.
FinOps Foundation: "Everyone takes ownership of their cloud usage."

---

## 1. FinOps Framework

### 3 phases

```
Phase 1 — Inform (Visibility)
  Know what you're spending and why
  Tools: AWS Cost Explorer, GCP Billing, Azure Cost Management
  Outputs: Cost by team/service/environment, unit economics

Phase 2 — Optimize (Efficiency)
  Identify and act on savings opportunities
  Actions: Right-sizing, reserved instances, waste elimination
  Outputs: 20-40% cost reduction typically

Phase 3 — Operate (Continuous governance)
  Ongoing management, forecasting, culture
  Outcomes: Predictable spend, cost as engineering metric
  Tools: Automation, anomaly detection, showback/chargeback
```

### FOCUS — FinOps personas

```
Engineering teams: Understand cost impact of architecture decisions
Finance: Forecast, budget, variance analysis
Product/Business: Cost per unit metric, business value alignment
Platform/Infra: Central cost optimization, tooling

Common failure: Only finance cares → engineers don't change behavior
Success: Engineers see their costs → autonomy + accountability
```

---

## 2. Unit Economics — The Right Metrics

### Cost per [business metric]

```
Vanity metrics (don't use these alone):
  "We spend $100K/month" → Is that good or bad?
  
Unit economics (actionable):
  Cost per user:          $0.05/MAU → compare to LTV
  Cost per transaction:   $0.002/order → track over time
  Cost per API call:      $0.0003/request
  Cost per GB stored:     $0.023/GB/month
  Cost per compute hour:  $0.10/GPU-hour for ML training

Why unit economics matter:
  $100K/month + 100K users = $1/user (expensive)
  $100K/month + 10M users = $0.01/user (cheap)
  Revenue per user $5 → margin 80% at $0.01/user vs -80% at $1/user

Calculating cost per user:
  1. Tag all resources by product/feature
  2. Allocate shared costs (networking, monitoring, auth)
     by % of requests handled or CPU consumed
  3. Divide total tagged cost by MAU
```

### Unit cost trends

```
Healthy unit economics:
  Unit cost decreasing as scale increases → Economies of scale
  Indicates: Architecture scales well, no linear cost growth

Red flags:
  Unit cost flat as scale increases → Linear cost scaling
    Cause: Paying per user/transaction for external service
    Fix: Negotiate volume discounts, replace with fixed-cost infrastructure
  
  Unit cost increasing as scale increases → Negative economies of scale
    Cause: Architecture not designed for scale, bottleneck components
    Fix: Architecture review, redesign hot paths

Dashboard:
  X-axis: Monthly Active Users (or transactions)
  Y-axis: Monthly cost per unit
  Target: Decreasing curve over time
```

---

## 3. Cost Visibility & Tagging Strategy

### Tagging taxonomy

```
Required tags (enforce via policy — reject resources without these):
  team:         "payments" | "growth" | "platform" | "core-api"
  environment:  "production" | "staging" | "development"
  service:      "order-service" | "user-service" | "ml-pipeline"

Optional (helpful):
  cost-center:  "engineering" | "marketing" | "data"
  project:      "q4-checkout-redesign"
  owner:        "an.nguyen@company.com"

Enforcement:
  AWS: SCP (Service Control Policy) — deny resource creation without required tags
  Terraform: Required variables for tags
  
  # Terraform: enforce tags
  variable "required_tags" {
    type = map(string)
    validation {
      condition = contains(keys(var.required_tags), "team") &&
                  contains(keys(var.required_tags), "environment")
      error_message = "Tags 'team' and 'environment' are required"
    }
  }
```

### Showback vs Chargeback

```
Showback: Show teams their costs → no money movement
  Low friction, good for starting FinOps journey
  Teams aware of cost impact → behavioral change

Chargeback: Teams "pay" from their budget for cloud costs
  Stronger accountability
  Finance complexity increases
  Risk: Teams optimize for cost, not business value

Recommendation: Start với showback → move to chargeback after 6 months
  when teams understand their cost drivers
```

### Cost anomaly detection

```
AWS Cost Anomaly Detection:
  Machine learning: Detect unexpected cost spikes
  Alert: Email/SNS when anomaly detected
  Configure per service, linked account, or tag

Custom alerts (Terraform + CloudWatch):
  resource "aws_budgets_budget" "team_limit" {
    name         = "payments-team-monthly"
    budget_type  = "COST"
    limit_amount = "10000"  # $10K/month
    limit_unit   = "USD"
    time_unit    = "MONTHLY"
    notification {
      comparison_operator = "GREATER_THAN"
      threshold           = 80   # Alert at 80%
      threshold_type      = "PERCENTAGE"
      notification_type   = "ACTUAL"
      subscriber_email_addresses = ["payments-team@company.com"]
    }
  }

Key signals to monitor:
  Daily spend > 1.5× previous 7-day average → anomaly
  Specific service spend doubles week-over-week → investigate
  Data transfer spike (often largest surprise bill)
```

---

## 4. Compute Optimization

### Right-sizing methodology

```
Step 1: Measure (2 weeks minimum)
  CPU: p99 utilization over 2 weeks
  Memory: Max usage over 2 weeks
  Network: Peak in/out

Step 2: Target utilization
  CPU: Target p99 < 50% (headroom for spikes)
  Memory: Target max < 70%

Step 3: Calculate right size
  Current: c6i.2xlarge (8 vCPU, 16 GB) → CPU p99 = 15%, Memory max = 30%
  Right size: c6i.large (2 vCPU, 4 GB) → CPU p99 ~ 60%, Memory max ~ 120% (too small)
  → c6i.xlarge (4 vCPU, 8 GB) → CPU p99 ~ 30%, Memory max ~ 60% → good

Step 4: Monitor after change
  Error rate, latency p99 within 48h after right-sizing
  Rollback plan ready

Tools:
  AWS Compute Optimizer: Automated right-sizing recommendations
  GCP Recommender: Similar
  Datadog / Grafana: Custom utilization analysis
```

### Reserved Instances / Savings Plans

```
On-Demand (baseline):
  Pay full price, cancel anytime
  Use for: Variable, unpredictable workloads

Reserved Instances (RI):
  Commit to 1 or 3 years → 40-72% discount
  Options: All upfront (best discount) / Partial / No upfront
  Use for: Stable, predictable baseline workloads

Savings Plans (AWS):
  Commit to $ amount per hour → applies automatically across eligible usage
  More flexible than RI (applies across instance families, regions)
  Compute Savings Plans: ~66% savings
  Use for: Mix of instance types, if not sure exactly what you'll use

Spot Instances / Preemptible VMs:
  Up to 90% discount
  Can be terminated with 2-min warning
  Use for: Stateless batch jobs, ML training, dev/test environments
  NOT for: Production APIs, stateful workloads, databases

Strategy — right coverage model:
  Baseline (always-on): Reserved 1yr or Savings Plans
  Variable (scales with traffic): On-Demand
  Batch/background: Spot
  
  Example: 10 always-on instances → RI, 0-20 scale-out instances → On-Demand
  Result: 40-50% total savings vs all On-Demand
```

### Kubernetes cost optimization

```
Namespace-level resource quotas:
  resource "kubernetes_resource_quota" "payments_team" {
    metadata { namespace = "payments" }
    spec {
      hard = {
        "requests.cpu"    = "40"   # Limit team to 40 CPU cores
        "requests.memory" = "80Gi"
        "limits.cpu"      = "80"
        "limits.memory"   = "160Gi"
      }
    }
  }

Cluster autoscaler (scale nodes up/down with demand):
  Scale up: Pod pending → add node
  Scale down: Node < 50% utilized for 10 min → drain + terminate
  Config: --scale-down-utilization-threshold=0.5

Karpenter (AWS, more aggressive):
  Provision cheapest instance type that fits pending pods
  Bin-packing: Fewer, larger instances vs many small
  Handles Spot interruptions automatically
  Typical savings: 60% vs static node groups

KEDA (event-driven autoscaling):
  Scale to zero when no traffic
  Scale based on queue depth, HTTP requests, custom metrics
  Perfect for batch workers, low-traffic services

VPA (Vertical Pod Autoscaler):
  Recommend/auto-adjust CPU/memory requests
  Not for production (restarts pods), use for recommendations

Right-size containers:
  requests.cpu = p95 CPU usage (not p99 — too conservative)
  requests.memory = max observed + 20% buffer
  limits.cpu = 2-4× requests (allow burst)
  limits.memory = 1.5× requests (OOM = real problem)
```

---

## 5. Storage & Data Transfer Optimization

### S3 storage tiers

```
Tier               | Access    | Cost/GB/month | Min duration
──────────────────────────────────────────────────────────────
Standard           | Immediate | $0.023        | None
Intelligent-Tiering| Automatic | $0.023→$0.004 | None (S3 manages)
Standard-IA        | Immediate | $0.0125       | 30 days
One Zone-IA        | Immediate | $0.01         | 30 days (single AZ)
Glacier Instant    | Immediate | $0.004        | 90 days
Glacier Flexible   | 3-5 hours | $0.0036       | 90 days
Deep Archive       | 12 hours  | $0.00099      | 180 days

Lifecycle policy:
  0-30 days:    Standard (hot access)
  30-90 days:   Standard-IA (occasional access)
  90-180 days:  Glacier Instant (rare access)
  180+ days:    Deep Archive (compliance/backup only)

S3 Intelligent-Tiering: Pays for itself if access patterns uncertain
  $0.0025/1,000 objects monitoring fee
  Break-even: Objects accessed < 1/month → savings exceed monitoring fee
```

### Data transfer costs (often overlooked)

```
AWS data transfer pricing:
  Internet egress:          $0.09/GB (first 10TB/month)
  Same region, different AZ: $0.02/GB (each direction!)
  Same region, same AZ:     FREE
  CloudFront → Internet:    $0.08/GB (cheaper via CDN)
  S3 → EC2 same region:     FREE
  
  Common surprise bills:
  1. Cross-AZ traffic: App in us-east-1a → DB in us-east-1b → $0.04/GB round trip
     Fix: Pin app and DB to same AZ (sacrifice availability for cost)
          OR accept cost (HA more important)
  
  2. NAT Gateway: $0.045/GB processed + $0.045/hour
     Cost: 1TB/month traffic = $45/month × 3 AZs = $135/month just for NAT!
     Fix: VPC endpoints for S3/DynamoDB (free, bypass NAT)
          Interface endpoints for other services
          S3 Gateway endpoint: FREE, setup once, 0 NAT costs for S3
  
  3. Direct egress vs CloudFront:
     100TB direct egress: 100,000 × $0.09 = $9,000
     100TB via CloudFront: 100,000 × $0.0085 = $850 (+ reduced origin load)

Optimization:
  VPC endpoints cho S3, DynamoDB (no NAT, no egress charge)
  CloudFront cho user-facing traffic
  Same-AZ communication khi cost > availability tradeoff acceptable
  Compress responses (gzip/brotli): Reduce transfer size 70-80%
```

---

## 6. Database Cost Optimization

```
RDS cost structure:
  Instance hours: $0.05-$2.00/hour (biggest cost)
  Storage: $0.115/GB-month (gp3) → much cheaper than gp2
  I/O: gp3: $0.02/million (vs gp2: included but expensive instance)
  Backup: First snapshot free, additional $0.095/GB-month

Migration gp2 → gp3:
  gp2: Performance tied to size (3 IOPS/GB)
  gp3: Decouple storage and performance
  30% cheaper for most workloads
  Set IOPS and throughput independently

Read replicas:
  Useful, but expensive (same cost as primary)
  Question before adding: Is read:write ratio > 10:1?
  Alternative: Better caching (Redis) often cheaper than replica

Aurora Serverless v2:
  Scale to 0 ACUs when idle
  Perfect: Dev/staging (idle most of time)
  Cost: 0.5 ACU minimum ($0.06/hour) vs t3.medium ($0.068/hour)
  Savings: 60-80% vs always-on instance for dev environments

RDS Proxy:
  Connection pooling as a service
  Cost: $0.015/vCPU-hour of protected DB
  ROI: Eliminates PgBouncer infra, reduces DB connection overhead
  Worth it: If managing PgBouncer overhead is significant

Hibernation (dev/staging):
  Stop RDS instances after hours/weekends
  Storage continues to accrue, compute stops
  Script: Stop at 7pm, start at 8am → 13h/day savings = 54% compute cost reduction
  Tools: AWS Instance Scheduler, custom Lambda
```

---

## 7. FinOps Culture & Process

### Engineering team enablement

```
Cost dashboard per team (Grafana/Looker):
  Real-time: Today's spend vs daily budget
  Trend: Week-over-week, month-over-month unit cost
  Breakdown: By service, environment, resource type
  Anomalies: Flagged automatically

Cost review in sprint retrospectives:
  5-minute cost review: "We spent $X this sprint, up/down Y%"
  Root cause for significant changes
  Action items if negative trend

Architecture review checklist (add cost dimension):
  "What's the estimated monthly cost at 1M users?"
  "Are there cheaper alternatives for this data store?"
  "Does this design scale cost-efficiently?"

Cost budgets per team:
  Set monthly budget → team owns staying within budget
  Overage → retrospective, not punishment
  Savings → can redirect to other engineering investment
```

### FinOps maturity model

```
Level 1 — Crawl (Month 1-3):
  Tagging implemented (team, env, service)
  Basic cost dashboard per team
  Monthly cost review meetings start
  Identify top 3 waste areas

Level 2 — Walk (Month 3-6):
  Unit economics tracked (cost per user/transaction)
  Dev/staging auto-shutdown implemented
  Reserved instances for stable workloads
  Anomaly detection alerts active
  Right-sizing first pass complete

Level 3 — Run (Month 6+):
  Budget per team with accountability
  Cost as engineering metric alongside latency/reliability
  Automated optimization (Karpenter, auto-scaling well-tuned)
  Cost efficiency in architecture reviews
  FinOps is part of engineering culture, not separate function
```

---

---

## 8. Serverless Cost Model

### Lambda pricing — very different from EC2

```
Lambda pricing (3 dimensions):
  1. Invocations:    $0.20 per 1M requests (first 1M free)
  2. Duration:       $0.0000166667 per GB-second
  3. Provisioned concurrency: $0.000004646 per GB-second (reserved warm instances)

GB-second = memory_allocated_GB × duration_seconds
  128MB function, 200ms execution:
    0.128 GB × 0.2s = 0.0256 GB-s × $0.0000167 = $0.000000427/invocation
    = $0.43 per 1M invocations

EC2 comparison at 1M requests/day:
  Lambda: 1M × $0.000000427 = $0.43/day + $0.20 = $0.63/day = $19/month
  t3.small (EC2): $0.023/hr × 730hr = $17/month (but always running!)

Break-even analysis:
  Lambda wins: < ~500K requests/day (idle time = $0 cost)
  EC2 wins:    > ~500K requests/day (per-invocation cost exceeds fixed EC2)
  Rule: Spiky/unpredictable traffic → Lambda; sustained high traffic → EC2/containers
```

### Lambda optimization

```python
# Cold start reduction:
# 1. Minimize package size (cold start = download + initialize code)
#    Lambda: < 10MB deployment package → < 100ms cold start
#    Container Lambda: 512MB-1GB → 1-5s cold start

# 2. Keep initialization outside handler (runs once per container, not per invocation)
# BAD:
def handler(event, context):
    db = create_db_connection()        # Cold start every invocation
    result = db.query(event['id'])
    return result

# GOOD:
db = create_db_connection()           # Initialized once per container lifetime

def handler(event, context):
    result = db.query(event['id'])    # Reuse existing connection
    return result

# 3. Provisioned Concurrency: Pre-warm N instances (eliminates cold start)
#    Cost: $0.000004646/GB-s × 24h × N instances
#    Use for: Latency-sensitive endpoints, user-facing APIs

# 4. Memory allocation affects cost AND speed:
#    Lambda CPU scales linearly with memory
#    128MB: slowest, cheapest per-GB-s; more invocations may cost more overall
#    1024MB: 8× faster → if execution time < 1/8 of 128MB → actually cheaper
#    Tip: Test with Lambda Power Tuning (open source) to find optimal memory
```

### Other serverless pricing models

```
API Gateway + Lambda:
  API Gateway: $3.50 per 1M API calls + $0.09/GB data transfer
  Total: Lambda + API Gateway + data transfer

Step Functions (orchestration):
  Standard: $0.025 per 1,000 state transitions (expensive for tight loops)
  Express: $0.00001 per state transition (cheaper, use for high-volume)

DynamoDB on-demand:
  Reads: $0.25 per 1M read request units
  Writes: $1.25 per 1M write request units
  vs. Provisioned: 7× cheaper at sustained load, on-demand wins for spiky

SQS pricing:
  First 1M requests/month: Free
  Next 99B requests: $0.40 per 1M
  → Very cheap, negligible cost in most architectures

Fargate (serverless containers):
  $0.04048/vCPU/hour + $0.004445/GB/hour
  vs EC2: ~20-30% premium for no server management
  Break-even: Short-lived tasks, bursty workloads
```

---

## 9. Multi-Cloud & GCP/Azure Cost Management

### GCP cost optimization

```
Committed Use Discounts (CUDs) — GCP's Reserved Instances:
  1-year: 37% off (Compute Engine VMs)
  3-year: 55% off
  More flexible than AWS RIs: applies to any VM in same region + family
  Sustained Use Discounts (SUDs): Auto-applied after 25% month usage (~20-30% discount)
  No upfront commitment needed for SUDs — GCP unique advantage

GCP-specific tools:
  Active Assist: Automated recommendations (right-sizing, idle VMs, CUD)
  Billing Budget Alerts: Budget + forecast alerts
  BigQuery: Editions pricing (Standard/Enterprise) vs on-demand
    On-demand: $6.25 per TB scanned → expensive for heavy analytics
    Enterprise: Flat monthly compute slots → cheaper at scale
    Slot reservations: Commit to compute capacity → predictable cost
  Cloud Storage classes: Standard → Nearline → Coldline → Archive
    (Same tiers as S3 with different names)

GCP networking:
  Premium tier: Highest performance routing (default, expensive)
  Standard tier: 26% cheaper — use for non-latency-sensitive traffic
```

### Azure cost optimization

```
Azure Reserved Instances / Savings Plans:
  Reserved VMs: 1yr → ~40% off, 3yr → ~60% off
  Savings Plans: Flexible commitment like AWS Savings Plans
  Hybrid Benefit: Windows Server + SQL Server → use existing licenses
    → 40-55% savings if already have Windows Server licenses

Azure-specific tools:
  Azure Advisor: Cost recommendations (right-sizing, idle resources)
  Cost Management + Billing: Budgets, alerts, cost allocation
  Azure Spot VMs: Up to 90% off (similar to AWS Spot)

Key Azure cost differences vs AWS:
  Outbound data transfer: Similar pricing ($0.087/GB first 10TB)
  AKS (managed K8s): Free control plane (AWS EKS: $0.10/hr)
  Storage: Blob Hot/Cool/Archive tiers
    Hot: $0.018/GB/month, Cool: $0.01/GB/month, Archive: $0.00099/GB/month

Azure Hybrid Benefit usage:
  Windows Server Datacenter: Cover unlimited VMs
  SQL Server Enterprise: Cover VMs with up to 24 cores
  Requires active SA (Software Assurance) coverage
```

### Multi-cloud cost management

```
Tools:
  CloudHealth (VMware): Multi-cloud cost visibility, governance
  CloudCheckr: Similar, strong compliance features
  Apptio Cloudability: Enterprise-grade, FinOps workflows
  Infracost: Open source, cost in CI/CD before deploy
    # .github/workflows/cost.yml
    - uses: infracost/actions/setup@v3
    - name: Run Infracost
      run: infracost diff --path=terraform/
    # Comments PR with estimated monthly cost change

Key principle for multi-cloud costs:
  Track per-cloud, per-team, per-product separately
  Egress between clouds is very expensive ($0.08-0.09/GB)
  Design: Minimize cross-cloud traffic (co-locate dependent services)
  Most orgs: Primary cloud for 80%+ workloads, secondary for specific needs
```


## Decision Trees — FinOps

```
Where to start reducing costs?
  Step 1: Check dev/staging environments
    → Auto-shutdown outside business hours → often 40-60% cost reduction on non-prod
  Step 2: Identify idle resources
    → EC2 < 5% CPU for 2 weeks, RDS with 0 connections → terminate
  Step 3: Right-size over-provisioned instances
    → AWS Compute Optimizer recommendations
  Step 4: S3 lifecycle policies
    → Logs, backups, old data → Glacier or Deep Archive
  Step 5: Reserved instances for stable workloads
    → Baseline compute that runs 24/7

Which purchase option?
  Runs 24/7, predictable size?       → Reserved 1yr (40% off)
  Runs 24/7, variable size/type?     → Compute Savings Plan (50% off)
  Batch jobs, fault-tolerant?        → Spot (90% off)
  Dev/test, irregular?               → On-Demand (cancel anytime)
  Always-on + variable?              → RI for baseline + On-Demand for peak

Database too expensive?
  On gp2 storage?                    → Migrate to gp3 (30% cheaper)
  Dev/staging always on?             → Aurora Serverless v2 or RDS schedule stop/start
  Too many connections?              → RDS Proxy or PgBouncer (prevent over-provisioning)
  Read replicas barely used?         → Remove, add Redis caching instead

Data transfer bill high?
  S3 traffic via internet?           → S3 VPC endpoint (free)
  Cross-AZ traffic significant?      → Same-AZ affinity for non-critical
  CDN not in front of assets?        → CloudFront ($0.0085/GB vs $0.09/GB direct)
  NAT Gateway costs high?            → VPC endpoints for AWS services
```

---

## Checklist FinOps

> 🔴 MUST | 🟠 SHOULD | 🟡 NICE

🔴 MUST:
- [ ] Tagging enforced: team, environment, service (no untagged resources)
- [ ] Cost anomaly alerts configured (alert at 150% of weekly average)
- [ ] Dev/staging không chạy 24/7 unnecessarily (auto-shutdown policy)
- [ ] No orphaned resources: unused EBS volumes, old snapshots, idle EIPs

🟠 SHOULD:
- [ ] Unit economics tracked: cost per MAU hoặc cost per transaction
- [ ] S3 lifecycle policies: logs và backups move to cheaper tiers automatically
- [ ] gp3 storage thay gp2 cho tất cả RDS instances
- [ ] Reserved Instances cho stable compute (baseline 24/7 workloads)
- [ ] S3 VPC endpoint (free, eliminates NAT costs cho S3 traffic)
- [ ] Cost dashboard per team (weekly review)
- [ ] AWS Compute Optimizer recommendations reviewed quarterly

🟡 NICE:
- [ ] Karpenter thay managed node groups (bin-packing, Spot integration)
- [ ] Chargeback model: teams see real cost impact
- [ ] Cost as review criterion trong architecture design docs
- [ ] FinOps reviewed trong sprint retrospectives
- [ ] CloudFront trước S3/origin (cheaper egress + better performance)
- [ ] KEDA cho scale-to-zero on batch workers
