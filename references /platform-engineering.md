
# Platform Engineering — Reference

Platform Engineering là discipline xây dựng Internal Developer Platform (IDP) —
lớp self-service giữa infrastructure và product teams.
Mục tiêu: Giảm cognitive load, tăng developer velocity, standardize practices.

Theo DORA 2025: 90% organizations dùng IDP, 76% có dedicated platform teams.
High-maturity platform teams báo cáo 40–50% giảm cognitive load cho developers.

---

## 1. Mental Model

### Platform Engineering ≠ DevOps ≠ Backstage

```
DevOps:               Culture + practices breaking down Dev/Ops silos
Platform Engineering: Specific implementation — dedicated team builds
                      shared tooling that makes DevOps accessible at scale
IDP:                  The product that platform team builds and maintains
Backstage:            Framework cho developer portal (UI layer TRÊN IDP)

Analogy đúng:
  IDP = Operating System cho development teams
  Backstage = UI shell (như Windows Explorer trên Windows)
  Golden Paths = Apps (pre-installed, recommended workflows)

Sai lầm phổ biến nhất:
  "Chúng tôi đã có platform engineering — chúng tôi đã cài Backstage"
  → Backstage là portal framework, không phải platform
  → Platform = toàn bộ backend: orchestration, automation, policies, golden paths
```

### Tại sao Platform Engineering quan trọng 2025

```
AI amplifier problem (DORA 2025):
  AI tools tăng coding speed 20-50%
  Nhưng: Gains bị nuốt bởi bottlenecks downstream:
  testing, security reviews, complex deployment processes
  → Platform là distribution layer cho AI:
    Standardized pathways → AI-generated code được test/secured/deployed tự động

Without Platform:
  Each team manages own CI/CD, infrastructure, security scanning
  → Duplication, inconsistency, cognitive overhead
  → Developer time spent on toil thay vì business value

With mature Platform:
  Developer: viết code → push → platform handle everything else
  Provisioning time: Days → Hours (Backstage-based IDP, thực tế)
  DORA metrics: All 4 improve (frequency, lead time, MTTR, failure rate)
```

---

## 2. IDP Architecture

### 4 layers của Internal Developer Platform

```
Layer 4: Developer Portal (Interface)
  Backstage, Port, Cortex — UI, software catalog, docs
  Developers discover services, scaffold projects, check status

Layer 3: Self-Service Layer (Golden Paths)
  Scaffolding templates, one-click environment provisioning
  Predefined workflows cho common tasks

Layer 2: Orchestration Engine (Automation)
  Humanitec, Crossplane, Terraform + GitOps (ArgoCD/Flux)
  Translates developer intent into infrastructure actions

Layer 1: Infrastructure Foundation
  Kubernetes clusters, cloud resources, security policies
  Developers không cần biết details ở đây

Important:
  Start với Layer 2 (backend/orchestration) trước, KHÔNG Layer 4 (portal)
  Analogy: Build nhà từ móng, không từ cửa trước
```

### IDP Components

```
Software Catalog:
  Registry của tất cả services, libraries, APIs, datasets
  Mỗi entity có: owner, tier, dependencies, docs, runbooks
  Powered by Backstage catalog-info.yaml per repo

Golden Paths:
  Pre-built, opinionated workflow cho common tasks:
  "New microservice" golden path bao gồm:
    - Service template với standard structure (Cookiecutter/Backstage Scaffolder)
    - CI/CD pipeline với security scanning pre-wired
    - Default observability setup (metrics, logging, tracing) auto-connected
    - Kubernetes manifests với resource limits, health probes
    - Runbook template
  
  Developer chọn template → nhập parameters → platform provision everything

Environment Provisioning:
  Self-service: Developer create dev/staging env trong minutes
  Không cần ticket → không cần wait
  Environment-as-Code: env configs trong git
  
Service Deployment:
  Developer push code → platform runs:
    lint → test → security scan → build image → push → deploy → health check
  No manual kubectl, no manual terraform
  
Secret Management:
  Vault, AWS Secrets Manager integration
  Developer request secret type, không thấy actual values
  Rotation automated

Cost Visibility:
  Per-team, per-service cost dashboard
  Budget alerts: "Your service costs $500/month, up 30%"
```

---

## 3. Golden Paths — Design

### Nguyên tắc Golden Path

```
Golden Path = "paved road" — không phải cage, không phải prison
  Paved: Dễ đi, đã được test, secure, compliant by default
  Not mandatory: Teams CAN deviate với justification
  Goal: Make the right thing the easy thing

Anatomy của Golden Path tốt:
  1. Solves real pain (xác định từ developer interviews, data)
  2. Opinionated: choices đã được làm — developer không phải decide
  3. Complete: từ đầu đến cuối, không bỏ gaps
  4. Documented: Why các choices được làm
  5. Measurable: Track adoption, deviation rate, satisfaction
  6. Maintained: Platform team owns và update

Không nên:
  - Build cho mọi use case (golden cage)
  - Cho phép quá nhiều configuration options
  - Abandon sau khi launch
```

### New Microservice Golden Path — ví dụ chi tiết

```
1. Developer chọn "New Service" template trong portal
2. Điền: service_name, team, language (Go/Node/Python), tier (critical/standard)
3. Platform tự động:
   
   GitHub:
     - Create repo từ template với standard structure
     - Branch protection rules
     - Required reviewers, code owners file
     - .github/workflows/ci.yml (pre-built CI pipeline)
   
   CI Pipeline (pre-wired):
     - Lint, type-check, unit tests
     - SAST scan (Semgrep)
     - Dependency audit
     - Docker build + push to registry
     - Image vulnerability scan (Trivy)
   
   Kubernetes:
     - Namespace: {team}-{service}
     - Deployment với resource requests/limits (from tier)
     - HPA config (min 2 replicas cho critical)
     - PodDisruptionBudget
     - NetworkPolicy (deny all, allow only declared)
     - ServiceAccount với minimal permissions
   
   Observability (auto):
     - Prometheus metrics scraping configured
     - Grafana dashboard từ template
     - Alert rules cho 4 golden signals
     - Structured log format + ELK pipeline
     - OpenTelemetry auto-instrumentation
   
   Security:
     - Secret request form (không hardcode secrets)
     - Vault integration
     - mTLS nếu internal service
   
   Documentation:
     - TechDocs page tự generate từ catalog-info.yaml
     - Runbook template pre-filled
     - Architecture Decision Record (ADR) template
   
   Portal:
     - Service entry trong software catalog
     - On-call escalation policy
     - SLO dashboard link

Total time: ~15 minutes vs days of manual setup
```

---

## 4. Backstage — Khi nào và cách dùng

### Build vs Buy decision

```
Backstage từ scratch (Spotify model):
  Pros: Maximum flexibility, full control
  Cons: 6–12 tháng setup, 3–15 FTE maintain
  Phù hợp: Large org (500+ engineers), unique requirements

Managed Backstage (Roadie ~$22/dev/month):
  Pros: Không ops overhead, auto-updates
  Cons: Less control, vendor dependency
  Phù hợp: Medium org, muốn Backstage mà không ops burden

Commercial SaaS IDPs:
  Port: Low-code, fast setup, good UX → team nhỏ, cần nhanh
  Cortex: Service quality scorecards → quality-focused orgs
  OpsLevel: Opinionated defaults → fast adoption
  Atlassian Compass: Nếu đã dùng Jira/Confluence
  Phù hợp: Teams không muốn build, cần time-to-value nhanh

Decision tree:
  < 50 engineers:    Simple docs site + shared runbooks đủ, chưa cần IDP
  50–200 engineers:  SaaS IDP (Port, Cortex) hoặc managed Backstage
  200–1000 engineers: Backstage từ scratch hoặc managed + heavy customization
  > 1000 engineers:  Custom Backstage với full platform team
```

### Backstage Architecture

```
Core components:
  Software Catalog:   Tracks mọi entities (services, libraries, teams, APIs)
    → catalog-info.yaml trong mỗi repo
    → Auto-discovery, không cần manual entry
  
  TechDocs:           Internal docs as code (MkDocs → static site trong Backstage)
    → Docs sống cùng với code, không drift
  
  Scaffolder:         Templates cho new projects/services
    → cookiecutter-style với form UI
    → Backstage actions (create repo, register in catalog, create Jira ticket)
  
  Search:             Unified search qua catalog, docs, incidents
  
  Plugins:            Extension points cho everything else
    Hiện có 1000+ plugins: Kubernetes, ArgoCD, PagerDuty, Datadog, Snyk...

catalog-info.yaml template:
  apiVersion: backstage.io/v1alpha1
  kind: Component
  metadata:
    name: payment-service
    title: Payment Service
    description: Handles all payment processing
    tags: [java, payments, critical]
    annotations:
      github.com/project-slug: myorg/payment-service
      backstage.io/techdocs-ref: dir:.
      pagerduty.com/service-id: P1234XY
      datadoghq.com/dashboard-url: https://app.datadoghq.com/dashboard/xyz
  spec:
    type: service
    lifecycle: production
    owner: team-payments
    tier: critical
    system: order-processing
    dependsOn:
      - component:order-service
      - resource:payments-db
```

---

## 5. GitOps — Infrastructure as Code trong Platform

### GitOps principles

```
1. Declarative: Infrastructure state described as code (YAML/HCL)
2. Versioned: Mọi changes trong Git → history, audit, rollback
3. Pulled: Agent (ArgoCD/Flux) pull từ Git → apply, không push
4. Reconciled: Agent continuously ensure actual state = desired state

Benefits:
  Audit trail: Mỗi change có PR, reviewer, timestamp
  Rollback: git revert → platform restore previous state
  Drift detection: ArgoCD alert khi actual ≠ desired
  Review process: Infrastructure changes cần PR approval
```

### ArgoCD vs Flux

```
ArgoCD:
  Model: Pull-based, GitOps controller
  UI: Excellent visual tree của application state
  Sync: Manual hoặc auto-sync
  Multi-cluster: Supported, hub-spoke model
  RBAC: Built-in, project-level isolation
  Phù hợp: Teams muốn UI visibility, multi-cluster

Flux:
  Model: GitOps Toolkit (composable)
  UI: Less visual (CLI-first)
  Flexibility: More composable, support Helm/Kustomize/plain YAML
  Phù hợp: Teams muốn lightweight, CLI-centric, GitOps purists

Cả hai: 93% organizations plan tiếp tục hoặc tăng GitOps use (2025).
```

### ArgoCD deployment pattern

```yaml
# Application manifest (GitOps):
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: payment-service
  namespace: argocd
spec:
  project: team-payments
  source:
    repoURL: https://github.com/myorg/payment-service
    targetRevision: main
    path: k8s/overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: payments-prod
  syncPolicy:
    automated:
      prune: true       # Xóa resources không còn trong Git
      selfHeal: true    # Restore nếu ai manually change
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
    retry:
      limit: 3
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

---

## 6. Developer Experience (DevEx) Metrics

### Đo lường DX — không chỉ cảm tính

```
DORA Metrics (deployment performance):
  Deployment Frequency:      Bao thường xuyên team deploy to production
  Lead Time for Changes:     Commit → production, target: < 1 ngày (elite)
  Change Failure Rate:       % deployments gây incident, target: < 5%
  Time to Restore Service:   Bao lâu recover từ incident, target: < 1 giờ

SPACE Framework (Nils et al., GitHub Research):
  Satisfaction:   Developer happiness với tools, processes
  Performance:    Outcomes (không chỉ output)
  Activity:       Volume of actions (PRs, commits, deployments)
  Communication:  Collaboration quality, review time
  Efficiency:     Flow, interruptions, context switching

DX Specific Metrics:
  Time to first PR:       New developer → first merged PR (target < 1 day)
  Build time:             Target < 5 minutes cho unit tests
  Time to provision env:  Self-service → working environment (target < 10 min)
  Toil:                   % time on repetitive undifferentiated work (target < 20%)
  
DORA 2025 platform correlation:
  Platform capability most correlated with positive DX:
  "Clear feedback on the outcome of my tasks"
  → Actionable logs, clear error messages, status visibility
```

### Developer satisfaction survey

```
Quarterly DX survey (anonymous, 5-minute):

NPS-style (0-10): "How likely would you recommend working at [company] to another engineer?"

Tooling (1-5):
  "Our CI/CD pipeline enables fast, reliable deployments"
  "I can provision the resources I need without waiting"
  "I can find information about services and systems easily"
  "Debugging production issues is straightforward"

Toil (1-5):
  "I spend too much time on repetitive non-value work"
  "Manual processes slow down my ability to ship"

Open-ended:
  "What is the biggest pain point in your development workflow?"
  "What would make you significantly more productive?"

→ Track trends, không just snapshots
→ Correlate với DORA metrics
→ Prioritize platform roadmap từ feedback
```

---

## 7. Platform as Product

### Platform team structure

```
Dedicated Platform Team (không embedded trong product teams):
  Team size: 1 platform engineer per 8-12 product engineers
  Roles:
    Platform Engineer: Builds và maintains IDP components
    SRE: Reliability, SLOs cho the platform itself
    Developer Advocate: Onboards teams, gathers feedback, writes docs

Product mindset:
  Users = Developer teams (không executives)
  Roadmap = Based on developer pain, adoption data, feedback
  Success metric = Developer adoption, KHÔNG tool existence
  Release cycle = Treat internal releases như external products

Common failure mode:
  Platform team builds what THEY think is best
  → Low adoption → "developers just don't get it"
  → Fix: Interview developers first, build smallest useful thing, iterate
```

### Platform MVP approach

Theo DORA, CNCF maturity guidance và thực tế: start từ pain points thực sự, không từ architecture diagrams.

```
Week 1–2: Discovery
  Interview 5-10 developers: "Bạn mất thời gian nhất ở đâu?"
  Audit hiện tại: Bao lâu để provision env? Bao lâu để deploy? Bao nhiêu manual steps?
  Identify top 3 pain points với ROI cao nhất

Week 3–6: First Golden Path (MVP)
  Pick pain point #1 (thường: new service setup hoặc deployment)
  Build minimum viable golden path với 1 team làm pilot
  Thiết yếu: feedback loop (Slack channel, office hours)

Week 7–10: Portal (optional, sau khi backend works)
  Chỉ build portal nếu adoption data cho thấy nó cần
  CLI + docs thường đủ cho team nhỏ
  Portal ưu tiên: software catalog (visibility) trước scaffolding (automation)

Week 11–16: Production Readiness
  SLOs cho platform itself: uptime, latency của CI pipelines
  On-call rotation cho platform team
  Incident process: Platform down → nhỏ gì production impact?

Ongoing:
  Monthly developer satisfaction survey
  Public roadmap
  Regular office hours / pairing sessions
  Deprecation process cho old tools team đang migrate từ
```

---

## 8. Toil Reduction — Quantifying và Fixing

### Measuring toil

```
Toil definition (Google SRE): Manual, repetitive, automatable work
that grows linearly với service growth và không produce lasting value

Ví dụ toil trong dev workflow:
  - Manual environment provisioning (ticket → wait 2 days)
  - Copy-paste boilerplate khi new service
  - Manually update multiple config files khi cần change
  - "Who owns service X?" → investigate qua Slack, email
  - Check 5 different dashboards để debug 1 issue

Measure toil:
  Time tracking: 2-week sprint → % time on toil categories
  Ticket analysis: Ops tickets per sprint per team (should trend down)
  Interruption tracking: How many "quick questions" about infra/tools per week
  
Target: < 20% engineer time on toil (Google SRE benchmark)
Typical pre-platform: 40-60% on toil in scaling organizations
```

### Toil reduction roadmap

```
Quick wins (1–2 sprints):
  Self-service environment provisioning (giảm 3-5 days wait → minutes)
  Service scaffolding template (giảm 2-3 days boilerplate → 15 minutes)
  Unified service catalog (giảm "who owns X?" investigations)
  Standardized runbooks (giảm incident response time)

Medium-term (1–3 months):
  Automated security scanning in CI (giảm manual reviews)
  Infrastructure drift detection và auto-heal
  Automated dependency updates (Dependabot + auto-merge safe updates)
  Self-service secret rotation

Long-term (3–6 months):
  AI-assisted incident diagnosis (copilot trong runbooks)
  Predictive scaling (giảm manual capacity planning)
  Automated cost optimization suggestions
```

---

## 9. Platform Security

### Security built into Golden Paths (không bolt-on)

```
Golden Path làm security dễ hơn security violation:
  Default: Mọi service có SAST, dependency audit, image scan trong CI
  Default: Secrets từ Vault, không từ env vars hard-coded
  Default: NetworkPolicy deny-all, chỉ declared traffic allowed
  Default: Non-root containers, read-only filesystem
  Default: Resource limits (prevent noisy neighbor, DoS)

Policy as Code (OPA/Gatekeeper):
  Enforce tại Kubernetes admission control:
  - Không deploy image chưa scan
  - Không deploy với latest tag
  - Không deploy với root user
  - Require resource limits
  - Require specific labels (owner, tier, cost-center)

Supply Chain Security:
  SBOM generation: Mỗi image build → generate Software Bill of Materials
  Image signing: Cosign (Sigstore) → verify image chưa bị tamper
  Provenance: SLSA framework → track build provenance
  
  CI pipeline:
    Build → scan (Trivy) → generate SBOM (Syft) → sign (Cosign) → push
    Deploy: Verify signature trước khi allow
```

---

---

## 11. Multi-Cluster Platform Design

### Why multi-cluster

```
Single cluster limits:
  Blast radius: bad deployment affects everything
  Compliance: Data residency requires region-specific clusters
  Scale: etcd limits ~5K nodes, ~150K pods
  Isolation: PCI workloads must be separate
  Lifecycle: Cluster upgrades risky with all workloads together

Common patterns:
  per-environment:  dev / staging / production clusters
  per-region:       ap-southeast-1, eu-west-1, us-east-1
  per-compliance:   PCI cluster, HIPAA cluster, standard cluster
```

### Hub-and-spoke with ArgoCD ApplicationSets

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: payment-service
  namespace: argocd
spec:
  generators:
    - clusters:
        selector:
          matchLabels:
            environment: production
  template:
    metadata:
      name: "{{name}}-payment-service"
    spec:
      source:
        repoURL: https://github.com/myorg/payment-service
        path: k8s/overlays/production
      destination:
        server: "{{server}}"
        namespace: payments
      syncPolicy:
        automated: { prune: true, selfHeal: true }
# Single ApplicationSet → deploys to all production clusters automatically
```

### Crossplane — Kubernetes-native IaC

```
Crossplane vs Terraform:
  Terraform:    State file, plan/apply, not K8s-native
  Crossplane:   Kubernetes CRDs, reconciliation loop, GitOps-native

Use case: Developer self-service database provisioning
  Platform team defines: "PostgresDatabase" CompositeResource
  Developer creates: PostgresDatabase YAML in their namespace
  Crossplane provisions: RDS + security group + IAM + secrets → automatically

Practical: Crossplane for app-level infra (databases, queues, buckets)
           Terraform for org-level infra (VPCs, IAM policies, accounts)
           Both used together in mature platform orgs
```

### Cluster upgrade strategy

```
Blue/Green cluster upgrade (zero downtime):
  1. Provision new cluster with new K8s version via GitOps
  2. ArgoCD auto-deploys all workloads to new cluster
  3. Shift traffic (DNS/LB) gradually: 10% → 50% → 100%
  4. Validate metrics, then decommission old cluster

Pros: Zero downtime, instant rollback (shift DNS back)
Cons: Double cost during transition (~24-48h)
When: Major K8s version upgrades (1.28 → 1.30)
```


## 10. Checklist Platform Engineering

> 🔴 MUST = block ship | 🟠 SHOULD = fix trước prod | 🟡 NICE = tech debt

### Foundation

🔴 MUST:
- [ ] Software catalog có tất cả production services với owner, tier, on-call
- [ ] Golden path cho deployment: không manual kubectl/terraform trong prod
- [ ] Security policies enforced tự động (không optional): SAST, image scan
- [ ] Secret management: không secrets trong code/env vars

🟠 SHOULD:
- [ ] Golden path cho new service scaffolding (< 30 min từ idea → first PR)
- [ ] Self-service environment provisioning (< 10 min, không cần ticket)
- [ ] DORA metrics baseline established và tracked
- [ ] Developer satisfaction survey quarterly
- [ ] GitOps: mọi infrastructure changes qua Git PRs (ArgoCD/Flux)
- [ ] Platform SLOs: uptime của IDP và golden paths

🟡 NICE:
- [ ] AI-assisted scaffolding (generate boilerplate từ description)
- [ ] Automated cost attribution per service/team
- [ ] Drift detection với auto-remediation
- [ ] Developer portal với unified search (Backstage/Port)

### Golden Paths Quality

🔴 MUST:
- [ ] Golden path include security scanning (SAST, dependency, image)
- [ ] Golden path include observability setup (metrics, logs, traces)
- [ ] Golden path tested và maintained (không abandoned)

🟠 SHOULD:
- [ ] Adoption metrics per golden path (detect unused paths)
- [ ] Deviation workflow: documented process khi team cần deviate
- [ ] Feedback mechanism (không "build and forget")
- [ ] Deprecation process cho old patterns

### Developer Experience

🔴 MUST:
- [ ] Build time < 10 phút (unit tests, not E2E)
- [ ] Clear, actionable error messages khi golden path fails
- [ ] Documentation: why decisions were made (không chỉ how)

🟠 SHOULD:
- [ ] Time to first PR < 1 day cho new hire
- [ ] Toil time < 20% of sprint
- [ ] Platform roadmap public và driven by developer feedback
- [ ] Platform team available: office hours, Slack support
