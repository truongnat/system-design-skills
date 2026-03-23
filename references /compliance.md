# Compliance Engineering — Reference

GDPR, HIPAA, PCI-DSS không chỉ là legal document — chúng yêu cầu
technical implementations cụ thể. File này cover WHAT TO BUILD, không legal advice.

---

## 1. GDPR — General Data Protection Regulation (EU)

Áp dụng: Bất kỳ system nào xử lý data của EU residents, bất kể company ở đâu.
Phạt: Đến 4% global annual revenue hoặc €20M (chọn cái cao hơn).

### 8 Rights của data subjects — Technical implications

**Right to Access (Article 15):**
```
User request: "Show me all data you have about me"
Technical requirement:
  - Query across ALL systems (DB, analytics, logs, backups, third-party)
  - Return trong 30 ngày (response time SLA)
  - Machine-readable format (JSON, CSV)

Implementation:
  1. Data inventory: Catalog WHERE user data lives (DB tables, S3 paths, third-party)
  2. User ID mapping: Link user across all systems (email → user_id → analytics_id)
  3. Data export API: POST /users/{id}/data-export → 202 + job_id
     GET /jobs/{job_id} → { status, download_url }
  4. Include: Profile, orders, activity logs, emails sent, support tickets
```

**Right to Erasure / Right to be Forgotten (Article 17):**
```
User request: "Delete all my data"
Technical requirement: Delete hoặc anonymize across ALL systems

Hard to delete:
  - Backups: Cannot selectively delete from backup files
    Solution: Encrypt user data with user-specific key → delete key → data unreadable
  - Audit logs: Legal requirement to keep transaction records
    Solution: Pseudonymize → replace name/email với opaque ID
  - Analytics: Aggregate data OK to keep (no individual identification)

Implementation steps:
  1. Soft delete in primary DB: deleted_at timestamp, cascade to related tables
  2. Remove from search indexes (Elasticsearch)
  3. Remove from CDN/caches (flush relevant cache keys)
  4. Notify third parties: email provider, CRM, analytics
  5. Cryptographic erasure for backups
  6. Create erasure log (ironically, need to log that erasure happened)
  7. Wait for backup rotation (7-90 days depending on retention policy)

Erasure exceptions (allowed to keep):
  - Legal obligation (tax records: 7 years in Vietnam)
  - Fraud prevention (transaction records)
  - Public interest / scientific research (aggregated, anonymized)
```

**Right to Portability (Article 20):**
```
User exports their data to take to another service
Format: Machine-readable (JSON preferred, not PDF)
Scope: Only data user actively provided (not derived/inferred)
  Include: Profile, posts, uploads, order history
  Exclude: Internal analytics, behavioral predictions, model outputs
```

**Right to Rectification (Article 16):**
```
User can correct inaccurate data
Technical: Standard edit functionality + audit trail of changes
```

**Right to Object to Processing (Article 21):**
```
User opts out of specific processing (marketing, profiling)
Technical: Preference flags in user record + propagate to all downstream systems
  user.marketing_opt_out = true → exclude from all marketing pipelines
  user.profiling_opt_out = true → exclude from ML recommendation models
```

### Lawful Basis for Processing

```
Must have ONE valid basis:
  Consent: User explicitly agreed (checkbox, not pre-ticked)
  Contract: Necessary to fulfill contract (shipping address for delivery)
  Legal obligation: Tax, fraud prevention
  Legitimate interest: Security, fraud detection (but can be overridden)

Consent management:
  Explicit, specific, informed, unambiguous
  Granular: Separate consent for marketing, analytics, profiling
  Withdrawable: As easy to withdraw as to give
  Logged: Timestamp, IP, version of consent text

Store consent: { user_id, purpose, granted: true, timestamp, ip, text_version }
```

### Data Residency

```
Some EU data must stay in EU (healthcare, financial)
Technical implementation:
  Multi-region setup with data residency enforcement
  
  User registration: Detect country → assign to correct region
  EU user → eu-west-1 data, không replication sang us-east-1
  
  Database level: Separate clusters per region
  Application level: Route requests to user's home region
  
  Complications:
  - Multi-region authentication (JWT validation cross-region OK)
  - Analytics (aggregate EU data separately, EU-only warehouse)
  - Support access (EU support team accesses EU data only)
  - Third-party services: Verify they have EU data centers
    Alternatives: EU-based vendors (Hetzner, OVH vs AWS/GCP with eu-region config)
```

### PII Data Classification

```
Tier 1 — Direct identifiers (highest sensitivity):
  Name, email, phone, address, national ID, passport number
  → Encrypt at rest, TLS in transit, strict access control, audit all access

Tier 2 — Indirect identifiers (medium sensitivity):
  IP address, device ID, cookie, browsing history, location
  → Pseudonymize, aggregate for analytics, retention limits

Tier 3 — Special categories (strictest — Article 9):
  Health data, biometrics, race/ethnicity, political opinions, religion
  → Explicit consent required, separate storage, minimal collection

Technical controls:
  Column-level encryption (PostgreSQL pgcrypto):
    INSERT INTO users (name, email_encrypted)
    VALUES ('An', pgp_sym_encrypt('an@example.com', $encryption_key))

  Pseudonymization: Replace PII with opaque token
    user_id: 123 → analytics_id: "anon_7x9k2m" (1-way hash, can't reverse)

  Data masking in non-production:
    Staging: all emails replaced with user_{id}@example-test.com
    Logs: email masked as a***@example.com
```

---

## 2. HIPAA — Health Insurance Portability and Accountability Act (US)

Áp dụng: Healthcare providers, insurers, và business associates handling PHI (Protected Health Information).
Phạt: $100–$50,000 per violation, up to $1.9M/year.

### PHI — Protected Health Information

```
Any individually identifiable health information:
  - Medical records, diagnosis, treatment
  - Name + health condition combination
  - Dates (admission, discharge, birth) + individual
  - Geographic data smaller than state
  - Phone, fax, email
  - SSN, account numbers
  - IP address if linked to health data

18 identifiers phải remove để data become "de-identified"
De-identified = no longer PHI = không cần HIPAA controls
```

### Technical Safeguards (Required)

```
Access Control:
  Unique user identification: No shared accounts
  Emergency access procedure: Break-glass access with audit
  Automatic logoff: Session timeout (15-30 min inactivity)
  Encryption: PHI encrypted at rest (AES-256) và in transit (TLS 1.2+)

Audit Controls:
  Log ALL access to PHI: Who, what, when, from where
  Immutable audit logs: Cannot be modified or deleted
  Retention: 6 years minimum
  
  Audit log schema:
  {
    user_id, user_role, action, resource_type, resource_id,
    patient_id, timestamp, ip_address, result (success/denied),
    justification (for emergency access)
  }

Integrity Controls:
  Detect unauthorized modification: Checksums, digital signatures
  Transmission security: TLS required for all PHI transmission

Person Authentication:
  MFA required for remote access
  Password complexity requirements
  Account lockout after failed attempts
```

### Business Associate Agreement (BAA)

```
Any third-party vendor that handles PHI needs a BAA:
  AWS: BAA available (sign before storing PHI in AWS)
  GCP: BAA available
  SendGrid: BAA available for HIPAA customers
  Slack: Enterprise Grid has HIPAA BAA

No BAA = HIPAA violation even if vendor is secure
Never store PHI in:
  - Standard Gmail (no BAA available free tier)
  - Standard Slack (non-enterprise)
  - GitHub issues/comments
  - Unencrypted S3 buckets
  - Application logs in plain text
```

### Minimum Necessary Standard

```
Access only PHI needed for the specific task:
  Customer support: See name, contact, appointment — NOT full medical record
  Billing: See diagnosis codes, insurance — NOT clinical notes
  Developer: See anonymized/synthetic data — NOT real PHI

Technical implementation:
  Role-based access: Define minimum data per role
  Field-level access control: Some roles see masked SSN (***-**-1234)
  PHI tagging: Tag each field with sensitivity level
  Attribute-based access control (ABAC): dynamic rules based on context
```

---

## 3. PCI-DSS — Payment Card Industry Data Security Standard

Áp dụng: Bất kỳ entity nào store, process, hoặc transmit cardholder data.
4 levels dựa trên transaction volume. Level 1 (> 6M transactions/year): strictest.

### Cardholder Data Environment (CDE)

```
PAN (Primary Account Number) = card number = highest sensitivity
Never store:
  - Full magnetic stripe data
  - CVV/CVC/security codes
  - PIN blocks

May store (if needed, encrypted):
  - PAN (truncated: first 6 + last 4 = 1234 56** **** 4321 OK)
  - Cardholder name
  - Expiration date
  - Service code

Scope reduction (critical):
  Fewer systems in CDE scope = smaller audit surface
  Use tokenization: Real card number → opaque token stored in your DB
  Stripe handles PAN → your DB only has stripe_token
  PCI scope reduced dramatically
```

### 12 PCI-DSS Requirements (Technical Focus)

```
Req 2: Secure configurations
  No default vendor passwords
  Document and apply security baseline (CIS benchmarks)

Req 3: Protect stored data
  Encrypt PAN with AES-256 or RSA 2048+
  Truncate PAN nếu không cần full number
  Hash with salt nếu dùng cho comparison

Req 4: Encrypt transmission
  TLS 1.2+ minimum (PCI DSS 4.0: TLS 1.3 recommended)
  No WEP/WPA1, deprecated protocols
  Certificate validation (no self-signed in production)

Req 6: Secure software development
  OWASP Top 10 addressed
  Code review for security
  Web application firewall (WAF)
  Vulnerability scanning before production

Req 7: Access control
  Need-to-know basis
  Deny all, explicitly allow
  Role-based access control

Req 8: Identify and authenticate
  Unique user ID (no shared accounts)
  MFA for all remote access và admin access to CDE
  Passwords: 7+ chars, complexity, 90-day rotation
  Session timeout: 15 min idle

Req 10: Logging and monitoring
  Log all access to CDE systems
  Centralize logs, cannot be modified
  Alert on suspicious activity
  Retain 12 months (3 months immediately accessible)

Req 11: Security testing
  Quarterly external vulnerability scan (ASV-approved)
  Annual penetration test
  File integrity monitoring for CDE
  IDS/IPS for CDE network
```

### Tokenization vs Encryption

```
Encryption: Reversible transformation with key
  Risk: Key compromise → all data compromised
  Use when: Need to recover original value (display masked card to user)

Tokenization: Replace real data with surrogate (token)
  Token has no mathematical relationship to real PAN
  Real PAN stored in Token Vault (separate, highly secured system)
  Risk: Token vault compromise (single target)
  Use when: Need reference but not value (store for recurring payments)

PCI scope:
  With encryption: All systems handling encrypted PAN = in scope
  With tokenization: Only Token Vault in scope → MUCH smaller scope
  Recommendation: Use payment processor tokenization (Stripe, Adyen)
    → Your system never touches real PAN → minimal PCI scope
```

---

## 4. Data Retention & Deletion

### Retention policy matrix

```
Data type              | Retention | Legal basis          | Delete method
──────────────────────────────────────────────────────────────────────────
Transaction records    | 7 years   | Tax law (VN/SG/US)   | Anonymize after
User PII               | Until del.| GDPR consent/contract| Hard delete + notify 3P
Security logs          | 1 year    | Security/fraud       | Purge
Application logs       | 90 days   | Operations           | Purge
Analytics (aggregated) | Indefinite| Legitimate interest  | N/A (no PII)
Payment data           | 12 months | PCI-DSS Req 10       | Hard delete
Health records (PHI)   | 6 years   | HIPAA                | Hard delete + audit
Support tickets        | 3 years   | Legitimate interest  | Anonymize
```

### Automated retention enforcement

```sql
-- PostgreSQL: Scheduled deletion job (run via pg_cron or app scheduler)
-- Purge old application logs
DELETE FROM application_logs
WHERE created_at < NOW() - INTERVAL '90 days';

-- Anonymize old users (GDPR: right to be forgotten after account closure)
UPDATE users
SET
  email = 'deleted_' || id || '@example.com',
  name = 'Deleted User',
  phone = NULL,
  address = NULL,
  deleted_at = NOW()
WHERE
  account_closed_at < NOW() - INTERVAL '30 days'
  AND deleted_at IS NULL;

-- S3 lifecycle policy (Infrastructure as Code)
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    id     = "expire-logs"
    status = "Enabled"
    filter { prefix = "application-logs/" }
    expiration { days = 90 }
    transition {
      days          = 30
      storage_class = "INTELLIGENT_TIERING"
    }
  }
}
```

---

## 5. Cross-Regulation Technical Controls

### Controls that satisfy multiple regulations

```
Control                  | GDPR | HIPAA | PCI-DSS
─────────────────────────────────────────────────
Encryption at rest       |  ✓   |  ✓    |   ✓
TLS in transit           |  ✓   |  ✓    |   ✓
Access control (RBAC)    |  ✓   |  ✓    |   ✓
Audit logging            |  ✓   |  ✓    |   ✓
MFA for admin access     |  ✓   |  ✓    |   ✓
Data minimization        |  ✓   |  ✓    |   ✓
Vulnerability scanning   |  ✓   |  ✓    |   ✓
Incident response plan   |  ✓   |  ✓    |   ✓
Vendor agreements        |  ✓   |  ✓    |   ✓
Retention policies       |  ✓   |  ✓    |   ✓

Implement once, satisfies multiple regulations
```

### Privacy by Design (PbD) — 7 principles

```
1. Proactive: Prevent privacy incidents before they occur
2. Privacy as default: Maximum privacy settings by default
3. Privacy embedded: Built into architecture, not added on
4. Full functionality: Privacy AND functionality (not trade-off)
5. End-to-end security: Throughout entire lifecycle
6. Visibility: Transparent to users and operators
7. User-centric: Respect user privacy as core value

Practical implementation:
  - Data minimization from day 1 (collect only what you need)
  - Consent before collection (not after)
  - Separate PII from behavioral data in schema design
  - Pseudonymization by default in analytics
  - Delete schedules automated (not manual)
```

---

---

## 6. SOC 2 Type II

SOC 2 là audit framework phổ biến nhất cho B2B SaaS — thường được enterprise customers
yêu cầu trước khi ký hợp đồng. Không phải luật nhưng thực tế là điều kiện kinh doanh.

### Trust Service Criteria (TSC)

```
5 criteria, Security là bắt buộc, các criteria khác tùy chọn:

Security (CC):        Bắt buộc cho tất cả SOC 2
  Logical access:     Who can access what, how is it controlled
  Change management:  How code changes are reviewed and deployed
  Risk assessment:    How risks are identified and mitigated
  Incident response:  How incidents are detected and handled

Availability (A):     System available per commitment
  Uptime monitoring, DR plan, capacity management

Confidentiality (C):  Confidential information protected
  Data classification, encryption, access controls

Processing Integrity: Processing complete, accurate, timely
  Input/output validation, error handling

Privacy (P):          PII handled per privacy notice
  Overlaps heavily with GDPR requirements
```

### SOC 2 Type I vs Type II

```
Type I: Point-in-time assessment
  "Controls are designed appropriately as of [date]"
  Faster (1-3 months), cheaper (~$15-30K)
  Less trusted by enterprise buyers

Type II: Period of time assessment (minimum 6 months)
  "Controls operated effectively throughout the period"
  More trusted, required by most enterprise customers
  Timeline: 6-12 months total (3-6 months prep + 6 months audit period)
  Cost: $30-80K for audit + significant engineering time

Recommendation:
  Month 1-3:   Implement controls, fix gaps
  Month 3-9:   Audit period (evidence collection)
  Month 9-12:  Auditor review, report issued
  → Start Year 1, have SOC 2 Type II by Year 2
```

### Technical Controls Required

```
Access Management:
  MFA enforced: All production access, all SaaS tools with prod data
  Least privilege: Role-based, review quarterly
  Offboarding: Account deprovisioned same day as departure
  Password manager: Org-wide (1Password, Bitwarden Teams)
  SSO: Single sign-on for all tools where supported

Change Management:
  Code review: All code changes require review before merge
  CI/CD: Automated testing before production deploy
  Deployment approval: Manual approval gate for production
  Rollback procedure: Documented and tested

Monitoring & Alerting:
  Centralized logging: All systems log to central SIEM
  Intrusion detection: Alert on suspicious access patterns
  Uptime monitoring: External monitoring (PagerDuty, Datadog)
  Vulnerability scanning: Regular scans, remediation SLA

Incident Response:
  Documented IR plan: Roles, escalation, communication
  Incident log: Every security incident documented
  Post-incident review: RCA for P1/P2 incidents
  Customer notification: SLA for breach notification

Vendor Management:
  Vendor inventory: List of all vendors handling company/customer data
  Vendor assessment: Annual review of critical vendors
  DPA/BAA: Signed agreements with data processors

Physical Security:
  If office: Badge access, visitor log
  Cloud-only: AWS/GCP physical security covers this (document evidence)

Encryption:
  At rest: AES-256 for sensitive data
  In transit: TLS 1.2+ everywhere
  Key management: Key rotation policy, documented

Backup & Recovery:
  Regular backups: Automated, tested restore procedure
  Offsite: Backups in separate region/account
  RTO/RPO: Documented and tested
```

### Tools that accelerate SOC 2

```
Compliance automation platforms:
  Vanta: $24K/year — automates evidence collection, integrates with GitHub/AWS/GCP
  Drata: Similar, slightly cheaper
  Secureframe: Mid-market option
  Sprinto: Good for startups
  Manual: ~$80K+ in engineering time vs $24K Vanta — ROI positive

These platforms:
  - Auto-collect evidence from GitHub, AWS, GCP, Okta, etc.
  - Track control status in real-time
  - Generate audit-ready reports
  - Assign control owners, track remediation
  → Reduce audit prep time from 6 months to 6 weeks
```

---

## 7. EU AI Act (2025)

Passed August 2024. High-risk provisions: 2026. General purpose AI: 2025.
Affects ANY AI system deployed to EU users, regardless of company location.

### Risk Classification

```
Unacceptable risk (PROHIBITED):
  - Social scoring by public authorities
  - Real-time biometric surveillance in public spaces (with exceptions)
  - Subliminal manipulation causing harm
  - Exploiting vulnerabilities of specific groups

High risk (STRICT REQUIREMENTS):
  - AI in: healthcare, education, employment, credit scoring,
           law enforcement, migration, critical infrastructure,
           administration of justice
  - Requires: Conformity assessment, CE marking, registration in EU database
  
  Technical requirements for high-risk:
    Risk management system
    Data governance (training data quality, bias checks)
    Technical documentation (how it works, capabilities, limitations)
    Record-keeping (logging for auditability)
    Transparency (users informed when interacting with AI)
    Human oversight (ability to intervene/override)
    Accuracy, robustness, cybersecurity

Limited risk (TRANSPARENCY OBLIGATIONS):
  - Chatbots: Must disclose it's an AI
  - Deepfakes: Must disclose synthetic content
  - Emotion recognition: Must inform people being analyzed

Minimal risk (NO OBLIGATIONS):
  - Spam filters, AI in video games, recommendation systems
  → Most consumer AI features fall here

General Purpose AI (GPAI) models (2025):
  - Any LLM/foundation model: Transparency, copyright compliance, testing
  - Systemic risk models (> 10²⁵ FLOPs): Adversarial testing, incident reporting
  - Affects: OpenAI, Anthropic, Google (and anyone building on these APIs)
```

### Technical Compliance Checklist

```
For high-risk AI systems:
🔴 MUST:
  - [ ] Technical documentation: capabilities, limitations, data used
  - [ ] Risk management system: identify, analyze, mitigate risks
  - [ ] Data governance: training data quality, bias testing documented
  - [ ] Logging: sufficient logs for post-hoc auditing
  - [ ] Human oversight mechanism: operator can intervene or stop AI
  - [ ] Register in EU AI database before deployment

For all AI systems with EU users:
🔴 MUST:
  - [ ] Disclose AI interaction to users (chatbots, automated decisions)
  - [ ] Disclose synthetic/AI-generated content (deepfakes, generated text)

🟠 SHOULD:
  - [ ] Maintain inventory of AI systems and their risk classification
  - [ ] Monitor for bias and performance drift post-deployment
  - [ ] Document training data sources and copyright clearance
  - [ ] Incident reporting process for significant AI failures

Penalties:
  Prohibited AI violations: €35M or 7% global revenue
  High-risk non-compliance: €15M or 3% global revenue
  Incorrect information: €7.5M or 1.5% global revenue
```


---

## 5. Decision Trees — Compliance

```
Đang xây dựng product?
  Có users ở EU không?
    YES → GDPR bắt buộc (bất kể company đặt ở đâu)
    → Minimum: lawful basis, consent, data subject rights endpoint

  Xử lý payment cards không?
    YES → PCI-DSS bắt buộc
    → Dùng Stripe/Adyen tokenization → PCI scope tối thiểu
    → Level 1 (> 6M transactions/year): Require QSA audit

  Xử lý health data ở US không?
    YES → HIPAA bắt buộc
    → Sign BAA với TẤT CẢ vendors TRƯỚC KHI store PHI
    → PHI encryption at rest + in transit mandatory

  Bán cho US federal government hoặc B2B enterprise?
    YES → SOC 2 Type II thường được yêu cầu
    → Audit takes 6-12 months: start early
    → SOC 2 more commonly requested than HIPAA in B2B SaaS

  Dùng AI trong EU (recommendations, automated decisions)?
    YES → EU AI Act 2025 applicable
    → High-risk AI: Conformity assessment, CE marking
    → General purpose AI: Transparency, copyright compliance

Multiple regulations apply?
  → Start với shared controls (encryption, access control, audit logs)
  → 1 implementation covers GDPR + HIPAA + PCI simultaneously
  → Then add regulation-specific requirements

Cần data residency?
  EU health data, financial data: MAY require EU-only storage
  → Check specific sector regulations
  → Technical: separate DB cluster per region, routing by user country

GDPR lawful basis selection:
  User provides data to use service → Contract
  Marketing emails → Consent (explicit, opt-in)
  Fraud detection, security → Legitimate interest
  Legal reporting → Legal obligation
  Healthcare, biometrics → Explicit consent (Art. 9)
```


## Checklist Compliance

> 🔴 MUST | 🟠 SHOULD | 🟡 NICE

**GDPR:**
🔴 MUST:
- [ ] Legal basis documented cho mỗi data processing activity
- [ ] Consent mechanism: Explicit, granular, withdrawable, logged
- [ ] Data subject rights implemented: Access, Erasure, Portability
- [ ] Data breach notification process (72 hours to DPA)
- [ ] DPA (Data Processing Agreements) với tất cả vendors handling EU data
- [ ] Data residency enforced nếu required (EU data trong EU region)

🟠 SHOULD:
- [ ] Privacy notice current và accurate
- [ ] Data inventory / Records of Processing Activities (RoPA)
- [ ] Data retention policy automated (không manual cleanup)
- [ ] PII classification (Tier 1/2/3) applied to schema
- [ ] DPIA (Data Protection Impact Assessment) cho high-risk processing

**HIPAA:**
🔴 MUST:
- [ ] BAA signed với ALL vendors handling PHI (AWS, email, etc.)
- [ ] PHI encrypted at rest (AES-256) và in transit (TLS 1.2+)
- [ ] Unique user IDs (no shared accounts)
- [ ] MFA cho remote/admin access
- [ ] PHI audit logs: All access logged, immutable, 6-year retention
- [ ] Automatic session timeout (15-30 min)
- [ ] No PHI in application logs

🟠 SHOULD:
- [ ] Minimum necessary access enforced (RBAC + field-level)
- [ ] Emergency access procedure (break-glass with audit)
- [ ] Workforce training documented
- [ ] Risk assessment annual

**PCI-DSS:**
🔴 MUST:
- [ ] No CVV/full magnetic stripe stored (ever)
- [ ] PAN encrypted hoặc tokenized (prefer tokenization)
- [ ] TLS 1.2+ cho tất cả cardholder data transmission
- [ ] CDE scope minimized (use Stripe/Adyen tokenization)
- [ ] Unique user IDs, no shared accounts in CDE
- [ ] MFA cho remote/admin access to CDE
- [ ] Audit logs 12 months retention (3 months accessible)

🟠 SHOULD:
- [ ] Quarterly vulnerability scan (ASV-approved)
- [ ] Annual penetration test
- [ ] CIS benchmarks applied to CDE systems
- [ ] WAF in front of payment endpoints
- [ ] File integrity monitoring cho CDE

**General:**
🟡 NICE:
- [ ] Privacy portal: Self-service data access/deletion
- [ ] Consent management platform (OneTrust, Cookiebot)
- [ ] Data lineage tracking (what data flows where)
- [ ] Regular privacy impact assessments
