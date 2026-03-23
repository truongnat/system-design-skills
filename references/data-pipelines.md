# Data Pipelines & Analytics Engineering — Reference

Data engineering là discipline xây dựng infrastructure để collect, transform,
và deliver data reliably. Ngày càng overlap với backend khi mọi product đều cần analytics.

---

## 1. Mental Model — Landscape

```
Data Sources          Ingestion         Storage            Serving
──────────────────────────────────────────────────────────────────
PostgreSQL       →    CDC (Debezium) →  Data Warehouse  →  BI Tools
MySQL            →    Kafka          →  Data Lake       →  Dashboards
APIs             →    Airbyte        →  Data Lakehouse  →  ML Models
Events (Kafka)   →    Spark          →  Feature Store   →  APIs
S3 files         →    Flink          →  Vector DB       →  Reports
Webhooks         →    dbt            →

OLTP (transactions)                    OLAP (analytics)
  Low latency reads/writes               Complex aggregations
  Normalized schema                      Denormalized, wide tables
  PostgreSQL, MySQL                      BigQuery, Snowflake, Redshift
  Cannot run analytics queries           Cannot handle OLTP write load
```

---

## 2. ETL vs ELT

```
ETL (Extract, Transform, Load) — Traditional:
  Extract from source → Transform in middleware → Load clean data to DW
  Transform xảy ra TRƯỚC khi load
  Tools: Informatica, Talend, custom scripts
  Phù hợp: Legacy systems, limited DW compute, strict data governance

ELT (Extract, Load, Transform) — Modern default:
  Extract from source → Load raw to DW → Transform using DW compute
  Transform xảy ra SAU KHI load (raw data preserved)
  Tools: dbt + BigQuery/Snowflake/Redshift
  Phù hợp: Cloud DW với elastic compute, cần data lineage, iterative transforms

Tại sao ELT thắng hiện nay:
  Cloud DW rẻ compute (pay per query)
  Raw data preserved → re-transform khi logic thay đổi
  SQL-based transforms → accessible cho analytics engineers
  dbt làm ELT dễ hơn nhiều (versioning, testing, documentation)
```

---

## 3. Change Data Capture (CDC)

### Tại sao CDC

```
Problem: Copy data từ operational DB (PostgreSQL) sang Data Warehouse
  Option 1: Full dump mỗi đêm → slow, expensive, data delay 24h
  Option 2: Query WHERE updated_at > last_run → miss deletes, unreliable
  Option 3: CDC → capture mọi change (insert/update/delete) trong real-time

CDC reads the database transaction log (WAL trong PostgreSQL, binlog trong MySQL)
→ Zero impact on operational DB performance
→ Captures DELETES (impossible với updated_at approach)
→ Real-time: sub-second latency
```

### Debezium — most popular CDC tool

```yaml
# Debezium PostgreSQL connector config
{
  "name": "postgres-source",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "database.hostname": "postgres",
    "database.port": "5432",
    "database.user": "debezium",
    "database.password": "password",
    "database.dbname": "production",
    "database.server.name": "prod-db",
    "table.include.list": "public.orders,public.users,public.products",
    "plugin.name": "pgoutput",     # WAL decoder plugin
    "slot.name": "debezium_slot",  # Replication slot name
    "publication.name": "dbz_publication"
  }
}
```

**Debezium event format:**
```json
{
  "before": { "id": 1, "status": "pending" },
  "after":  { "id": 1, "status": "confirmed" },
  "op": "u",           // u=update, c=create, d=delete, r=snapshot
  "ts_ms": 1704067200000,
  "source": {
    "table": "orders",
    "lsn": 123456789   // WAL position — use for exactly-once
  }
}
```

### CDC edge cases

```
Replication slot lag:
  Problem: Debezium slow consumer → WAL không được cleaned → Disk full → DB crash
  Monitor: pg_replication_slots view, slot lag metric
  Alert: slot lag > 1GB → investigate
  Fix: Scale consumer, or drop slot and re-snapshot if caught up

Schema evolution:
  ADD COLUMN: Debezium handles automatically → downstream cần handle null
  RENAME COLUMN: Breaking change → pause connector, migrate downstream, resume
  DROP COLUMN: Same as rename
  Best practice: Expand-Contract pattern (add new, migrate, drop old)

Initial snapshot:
  First time setup → Debezium snapshot toàn bộ table rồi switch to WAL
  Large tables: Snapshot có thể mất hours → không block production WAL reading
  Chunked snapshot (Debezium 2.0+): Snapshot in chunks, resumable

Exactly-once delivery:
  Debezium: At-least-once (may re-deliver on restart)
  Consumer phải be idempotent: Use source LSN as dedup key
  Kafka → DW: Use upsert với primary key
```

---

## 4. Batch Processing — Apache Spark

### Spark fundamentals cho data engineers

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import *

spark = SparkSession.builder \
    .appName("daily-order-aggregation") \
    .config("spark.sql.adaptive.enabled", "true")  # AQE — auto-optimize
    .getOrCreate()

# Read from S3 Data Lake (Parquet partitioned by date)
orders = spark.read.parquet("s3://data-lake/orders/")

# Transformation: Daily revenue by category
daily_revenue = orders \
    .filter(F.col("status") == "confirmed") \
    .filter(F.col("created_date") == "2024-01-15") \
    .groupBy("category", "created_date") \
    .agg(
        F.sum("total").alias("revenue"),
        F.count("*").alias("order_count"),
        F.avg("total").alias("avg_order_value"),
        F.countDistinct("user_id").alias("unique_buyers")
    ) \
    .orderBy(F.desc("revenue"))

# Write to Data Warehouse (Iceberg format)
daily_revenue.write \
    .format("iceberg") \
    .mode("overwrite") \
    .partitionBy("created_date") \
    .saveAsTable("analytics.daily_revenue_by_category")
```

### Spark optimization patterns

```python
# Partitioning — critical for performance
# BAD: 1 huge partition → 1 task, no parallelism
df.write.parquet("s3://output/")

# GOOD: Partition by date/category → parallel processing
df.write \
  .partitionBy("year", "month", "day") \
  .parquet("s3://output/")

# Partition pruning: Spark reads only relevant partitions
spark.read.parquet("s3://output/") \
  .filter(F.col("year") == 2024)   # ← Only reads 2024 partitions
  # Without partitioning: scans ALL data

# Broadcast join: Small table (< 10MB) replicated to all executors
# BAD: 1B rows × 1000 rows join → shuffle 1B rows
large.join(small, "category_id")

# GOOD: Broadcast small table
from pyspark.sql.functions import broadcast
large.join(broadcast(small), "category_id")  # Small replicated, no shuffle

# Avoid data skew: 1 key has 90% of records → 1 task 100× slower
# Fix: Salt the key
import hashlib
df.withColumn(
    "salted_key",
    F.concat(F.col("user_id"), F.lit("_"), (F.rand() * 10).cast("int"))
)
# Aggregate with salted key first, then re-aggregate without salt
```

### Spark cluster sizing

```
Rule: 1 executor per core, memory = data_partition_size × 3-4

Example: Process 100GB daily orders
  Partition size target: 128MB → 800 partitions
  Parallelism: 800 tasks
  Cluster: 20 executors × 4 cores = 80 cores (10× slower tasks acceptable)
  Memory per executor: 8GB (128MB × 4 replicas + overhead)
  Total: 20 × 8GB = 160GB memory

Spark on Kubernetes:
  Dynamic allocation: Scale executors up during job, down after
  Cost: Pay only for job duration (vs always-on cluster)
  Tools: Spark Operator for K8s, EMR Serverless (AWS)
```

---

## 5. Stream Processing

### Kafka Streams vs Apache Flink

```
Kafka Streams:
  Library (không cluster) — chạy trong application process
  Stateful processing với RocksDB local state
  Exactly-once semantics với Kafka transactions
  Phù hợp: Stream processing gắn với Kafka ecosystem, simple transformations
  Limitation: Only sources/sinks = Kafka, bounded by app JVM heap

Apache Flink:
  Distributed stream processing engine
  Event time processing với watermarks
  State backends: RocksDB (production), HashMap (testing)
  Exactly-once với checkpointing
  Phù hợp: Complex stateful stream processing, multiple sources/sinks
  Latency: Sub-second (Kafka Streams) vs milliseconds (Flink native)
```

### Flink — production patterns

```java
// Real-time fraud detection pipeline
StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();

// Source: Kafka payments topic
DataStream<Payment> payments = env
    .addSource(new FlinkKafkaConsumer<>(
        "payments",
        new PaymentDeserializer(),
        kafkaProps
    ))
    .assignTimestampsAndWatermarks(
        WatermarkStrategy.<Payment>forBoundedOutOfOrderness(Duration.ofSeconds(5))
            .withTimestampAssigner((p, ts) -> p.getTimestamp())
    );

// Stateful aggregation: count payments per user in 5-minute window
DataStream<FraudAlert> alerts = payments
    .keyBy(Payment::getUserId)
    .window(TumblingEventTimeWindows.of(Time.minutes(5)))
    .aggregate(new PaymentCountAggregator())
    .filter(count -> count.getTotal() > 10_000_000)  // > 10M VND in 5 min
    .map(count -> new FraudAlert(count.getUserId(), count.getTotal()));

// Sink: Kafka alerts topic
alerts.addSink(new FlinkKafkaProducer<>("fraud-alerts", new AlertSerializer(), kafkaProps));

env.execute("Fraud Detection Pipeline");
```

### Event time vs processing time

```
Processing time: Thời gian event được xử lý bởi system
  Simple, no watermarks needed
  Problem: Out-of-order events → wrong aggregations

Event time: Thời gian event thực sự xảy ra (từ event payload)
  Correct results kể cả khi events arrive late/out-of-order
  Cần watermarks: "I believe I've seen all events up to time T"

Watermark strategies:
  forMonotonousTimestamps: Events always in order (rare in practice)
  forBoundedOutOfOrderness(Duration.ofSeconds(10)):
    Allow events up to 10s late
    Events > 10s late → dropped or sent to side output

Late events handling:
  dropLate: Discard (simple, lose data)
  sideOutput: Route to separate stream for reprocessing
  allowedLateness: Refire window when late events arrive (complex)
```

---

## 6. dbt — Data Build Tool

### Tại sao dbt là standard

```
Before dbt: SQL transformations scattered, no versioning, no testing
After dbt:
  SQL transforms trong Git (version controlled)
  Auto-generated documentation và data lineage
  Built-in testing (not null, unique, relationships)
  Modular: Models reference other models
  Runs on DW compute (ELT pattern)
```

### dbt project structure

```
dbt_project/
  models/
    staging/          ← Clean raw data, 1:1 với source tables
      stg_orders.sql
      stg_users.sql
      stg_products.sql
    intermediate/     ← Business logic, joins
      int_orders_with_users.sql
      int_order_items_enriched.sql
    marts/            ← Final analytics tables
      finance/
        fct_revenue.sql       ← Facts (events, transactions)
        dim_customers.sql     ← Dimensions (entities)
      marketing/
        fct_user_acquisition.sql
  tests/             ← Custom data quality tests
  macros/            ← Reusable SQL snippets
  seeds/             ← Static CSV reference data
```

**Staging model — stg_orders.sql:**
```sql
-- models/staging/stg_orders.sql
{{ config(materialized='view') }}  -- Lightweight, no storage

with source as (
    select * from {{ source('production', 'orders') }}  -- Reference source table
),

renamed as (
    select
        id                                    as order_id,
        user_id                               as customer_id,
        status,
        total_amount / 100.0                  as total_amount_vnd,  -- Convert cents
        created_at                            as order_placed_at,
        updated_at                            as order_updated_at,
        -- Derived fields
        date_trunc('day', created_at)         as order_date,
        date_part('hour', created_at)         as order_hour
    from source
    where created_at >= '2020-01-01'  -- Filter old/bad data
)

select * from renamed
```

**Fact model — fct_revenue.sql:**
```sql
-- models/marts/finance/fct_revenue.sql
{{ config(
    materialized='incremental',        -- Only process new rows
    unique_key='order_id',
    on_schema_change='sync_all_columns'
) }}

with orders as (
    select * from {{ ref('stg_orders') }}  -- Reference staging model
    {% if is_incremental() %}
    where order_placed_at > (select max(order_placed_at) from {{ this }})
    {% endif %}
),
customers as (
    select * from {{ ref('dim_customers') }}
)

select
    o.order_id,
    o.customer_id,
    c.customer_segment,
    c.acquisition_channel,
    o.total_amount_vnd,
    o.order_date,
    o.order_hour,
    case
        when o.total_amount_vnd >= 1000000 then 'high_value'
        when o.total_amount_vnd >= 200000  then 'medium_value'
        else 'low_value'
    end as order_tier
from orders o
left join customers c using (customer_id)
```

### dbt testing

```yaml
# models/staging/schema.yml
version: 2
models:
  - name: stg_orders
    description: "Cleaned orders from production DB"
    columns:
      - name: order_id
        tests:
          - not_null
          - unique                          # No duplicate order IDs
      - name: customer_id
        tests:
          - not_null
          - relationships:                  # FK integrity
              to: ref('stg_users')
              field: user_id
      - name: status
        tests:
          - accepted_values:
              values: ['pending', 'confirmed', 'shipped', 'delivered', 'cancelled']
      - name: total_amount_vnd
        tests:
          - not_null
          - dbt_utils.expression_is_true:
              expression: ">= 0"           # No negative amounts
```

**Run commands:**
```bash
dbt run                   # Run all models
dbt run --select marts.+  # Run marts and their dependencies
dbt test                  # Run all tests
dbt docs generate         # Generate documentation
dbt docs serve            # Serve docs locally
dbt source freshness      # Check if source data is fresh
```

---

## 7. Data Lakehouse Architecture

### Evolution: Lake → Warehouse → Lakehouse

```
Data Lake:
  Store raw data cheaply (S3/GCS/ADLS)
  All formats: JSON, CSV, Parquet, images, video
  Problem: No ACID, no schema enforcement, "data swamp"

Data Warehouse:
  Structured, typed, fast queries (BigQuery, Snowflake, Redshift)
  ACID transactions, strong schema
  Problem: Expensive storage, siloed from ML/AI

Data Lakehouse (Apache Iceberg, Delta Lake, Apache Hudi):
  Best of both: cheap lake storage + DW features
  ACID transactions on S3/GCS
  Schema enforcement và evolution
  Time travel (query data as of yesterday)
  Supports SQL queries (Spark, Trino, Athena) AND ML (Python)
  2024: Iceberg won the format war — adopted by Snowflake, BigQuery, Databricks
```

### Apache Iceberg — key features

```python
# Time travel: Query data as of specific snapshot
df = spark.read \
    .option("as-of-timestamp", "2024-01-01T00:00:00") \
    .table("orders")

# Schema evolution: Add column without rewriting data
spark.sql("""
    ALTER TABLE orders
    ADD COLUMN delivery_notes STRING
""")
-- Existing Parquet files unaffected (column returns null)

# UPSERT (MERGE INTO) — critical for CDC
spark.sql("""
    MERGE INTO orders t
    USING updates s ON t.order_id = s.order_id
    WHEN MATCHED THEN UPDATE SET *
    WHEN NOT MATCHED THEN INSERT *
""")

# Compaction: Merge many small files (from streaming) into larger files
spark.sql("CALL system.rewrite_data_files('orders')")

# Expire old snapshots to reclaim storage
spark.sql("""
    CALL system.expire_snapshots(
        table => 'orders',
        older_than => TIMESTAMP '2024-01-01 00:00:00',
        retain_last => 10
    )
""")
```

---

## 8. Data Quality

### Expectations — Great Expectations

```python
import great_expectations as gx

context = gx.get_context()
batch = context.sources.pandas_default.read_dataframe(df)

# Define expectations
batch.expect_column_values_to_not_be_null("order_id")
batch.expect_column_values_to_be_unique("order_id")
batch.expect_column_values_to_be_between("total_amount", 0, 100_000_000)
batch.expect_column_values_to_be_in_set(
    "status",
    ["pending", "confirmed", "shipped", "delivered", "cancelled"]
)
batch.expect_column_pair_values_to_be_equal(
    "created_at", "updated_at",
    mostly=0.0  # created_at should never be after updated_at
)

# Run validation
results = batch.validate()
if not results.success:
    raise DataQualityError(f"Data quality check failed: {results}")
```

### Data freshness monitoring

```sql
-- dbt source freshness check
-- dbt_project.yml
sources:
  - name: production
    database: prod_db
    freshness:
      warn_after: {count: 6, period: hour}   # Warn if data > 6h old
      error_after: {count: 24, period: hour} # Error if data > 24h old
    loaded_at_field: updated_at
    tables:
      - name: orders
      - name: payments

-- Run: dbt source freshness
-- Output: Pass/Warn/Error per source table
```

---

## 9. Feature Store

### Tại sao cần Feature Store

```
Problem trong ML engineering:
  Data scientist compute feature trong Jupyter → duplicate trong serving
  Training-serving skew: Feature computed differently in training vs production
  Recomputing same features across teams → wasted compute

Feature Store giải quyết:
  Central repository cho ML features
  Same feature definition → training và serving
  Offline store: Historical features cho training (S3 + Parquet)
  Online store: Low-latency features cho inference (Redis, DynamoDB)
  Point-in-time correct: Feature value as of prediction time (no future leakage)
```

### Feast — open source feature store

```python
from feast import FeatureStore, Entity, FeatureView, Field, ValueType
from feast.types import Float32, Int64

# Define entity
user = Entity(name="user", value_type=ValueType.INT64, description="User ID")

# Define feature view (offline)
user_stats_fv = FeatureView(
    name="user_stats",
    entities=[user],
    ttl=timedelta(days=90),
    schema=[
        Field(name="total_orders_30d", dtype=Int64),
        Field(name="avg_order_value_30d", dtype=Float32),
        Field(name="days_since_last_order", dtype=Int64),
    ],
    source=BigQuerySource(
        table="analytics.user_order_features",
        timestamp_field="feature_timestamp"
    )
)

store = FeatureStore(repo_path=".")

# Materialize to online store (Redis)
store.materialize_incremental(end_date=datetime.now())

# Serving: Fetch features for prediction (low latency from Redis)
feature_vector = store.get_online_features(
    features=["user_stats:total_orders_30d", "user_stats:avg_order_value_30d"],
    entity_rows=[{"user": 123}, {"user": 456}]
).to_df()
```

---

## 10. Decision Trees — Data Engineering

```
Muốn analyze data từ production DB?
  Real-time (< 1 minute lag)?
    → Kafka → Flink → OLAP store (ClickHouse, Druid)
  Near real-time (minutes)?
    → CDC (Debezium) → Kafka → streaming aggregation → DW
  Batch (daily)?
    → ELT: airbyte/fivetran → raw layer → dbt → marts

Data size?
  < 10GB: PostgreSQL analytics queries đủ (EXPLAIN ANALYZE trước)
  < 100GB: dbt + BigQuery/Snowflake (serverless, pay-per-query)
  > 100GB: Apache Spark + data lake (Iceberg on S3)
  > 1TB: Spark cluster, partition carefully

Transform tool?
  SQL-centric team → dbt (ELT, version-controlled SQL)
  Python-heavy → Spark (complex transformations, ML pipeline)
  Real-time → Flink / Kafka Streams

Data lake format?
  2025 default: Apache Iceberg (ACID, time travel, schema evolution)
  Already on Databricks: Delta Lake (same features, Delta-native)
  Legacy / Hudi: Apache Hudi (older, more limited)

Feature engineering cho ML?
  < 10 features, simple: Compute inline in prediction service
  Many features, reused across models: Feature store (Feast, Hopsworks)
  Real-time features: Online feature store + Redis
```

---

---

## 11. Pipeline Orchestration

### Tại sao cần orchestration

```
dbt + Spark không tự chạy đúng giờ, đúng thứ tự, với retry khi fail.
Orchestration giải quyết:
  Scheduling:     Chạy pipeline đúng giờ (cron) hoặc khi có trigger
  Dependencies:   Task B chỉ chạy khi Task A thành công
  Retry:          Auto-retry khi fail (exponential backoff)
  Alerting:       Notify khi pipeline fail
  Monitoring:     Dashboard pipeline status, duration, lineage
  Backfill:       Re-run historical periods khi logic thay đổi
```

### Apache Airflow — most mature

```python
# Airflow DAG: Daily revenue pipeline
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.providers.postgres.operators.postgres import PostgresOperator
from airflow.providers.amazon.aws.operators.glue import GlueJobOperator
from datetime import datetime, timedelta

default_args = {
    'owner': 'data-team',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': True,
    'email': ['data-team@company.com'],
    'retries': 3,
    'retry_delay': timedelta(minutes=5),
    'retry_exponential_backoff': True,
}

with DAG(
    'daily_revenue_pipeline',
    default_args=default_args,
    description='Daily revenue aggregation',
    schedule_interval='0 6 * * *',   # Run at 6am daily
    catchup=False,                    # Don't backfill missed runs
    max_active_runs=1,                # Only 1 run at a time
    tags=['revenue', 'finance'],
) as dag:

    # Step 1: Check source data freshness
    check_source = PostgresOperator(
        task_id='check_source_freshness',
        postgres_conn_id='production_db',
        sql="""
        SELECT CASE
            WHEN MAX(created_at) < NOW() - INTERVAL '2 hours'
            THEN 1/0  -- Raise error if data is stale
        END FROM orders
        """,
    )

    # Step 2: Run dbt staging models
    dbt_staging = BashOperator(
        task_id='dbt_run_staging',
        bash_command='dbt run --select staging.+ --profiles-dir /etc/dbt',
    )

    # Step 3: Run dbt mart models
    dbt_marts = BashOperator(
        task_id='dbt_run_marts',
        bash_command='dbt run --select marts.finance.+ --profiles-dir /etc/dbt',
    )

    # Step 4: Run dbt tests
    dbt_tests = BashOperator(
        task_id='dbt_test',
        bash_command='dbt test --select marts.finance.+ --profiles-dir /etc/dbt',
    )

    # Step 5: Refresh BI dashboard cache
    refresh_dashboard = BashOperator(
        task_id='refresh_dashboard',
        bash_command='curl -X POST https://bi-tool/api/refresh-cache',
    )

    # Dependencies: define execution order
    check_source >> dbt_staging >> dbt_marts >> dbt_tests >> refresh_dashboard
```

### Prefect — modern Python-first

```python
# Prefect: simpler than Airflow, better DX
from prefect import flow, task
from prefect.tasks import task_input_hash
from datetime import timedelta

@task(
    retries=3,
    retry_delay_seconds=60,
    cache_key_fn=task_input_hash,   # Cache result for same inputs
    cache_expiration=timedelta(hours=1),
)
def run_dbt_models(models: str) -> bool:
    import subprocess
    result = subprocess.run(
        ['dbt', 'run', '--select', models],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        raise Exception(f"dbt failed: {result.stderr}")
    return True

@task(retries=2)
def check_data_freshness(table: str, max_age_hours: int = 2) -> bool:
    from sqlalchemy import create_engine, text
    engine = create_engine(os.environ['DATABASE_URL'])
    with engine.connect() as conn:
        result = conn.execute(text(
            f"SELECT MAX(created_at) < NOW() - INTERVAL '{max_age_hours} hours' FROM {table}"
        ))
        is_stale = result.scalar()
    if is_stale:
        raise Exception(f"Data in {table} is more than {max_age_hours}h old")
    return True

@flow(
    name="daily-revenue-pipeline",
    description="Daily revenue aggregation pipeline",
)
def daily_revenue_pipeline():
    # Tasks run in order, with dependency tracking
    freshness = check_data_freshness("orders", max_age_hours=2)

    staging = run_dbt_models("staging.+")
    marts = run_dbt_models("marts.finance.+")

    # Concurrent tasks where possible
    from prefect import allow_failure
    tests = run_dbt_models.submit("test:marts.finance.+")
    tests.result()

# Schedule: every day at 6am
from prefect.deployments import Deployment
deployment = Deployment.build_from_flow(
    flow=daily_revenue_pipeline,
    name="daily-6am",
    schedule={"cron": "0 6 * * *", "timezone": "Asia/Ho_Chi_Minh"},
)
```

### Dagster — asset-centric (2024 trend)

```python
# Dagster: Think in ASSETS, not tasks
# "What data do I want to exist?" not "What jobs should run?"
from dagster import asset, AssetIn, define_asset_job, ScheduleDefinition

@asset(
    description="Cleaned orders from production DB",
    group_name="staging",
)
def stg_orders(context):
    """Staging orders table."""
    context.log.info("Running stg_orders dbt model")
    run_dbt_model("stg_orders")
    return MaterializeResult(
        metadata={"rows_updated": get_row_count("stg_orders")}
    )

@asset(
    ins={"stg_orders": AssetIn()},   # Explicit dependency on stg_orders
    description="Daily revenue by category",
    group_name="marts",
)
def fct_revenue(context, stg_orders):
    """Finance mart: daily revenue."""
    run_dbt_model("fct_revenue")
    return MaterializeResult(
        metadata={"rows": get_row_count("fct_revenue")}
    )

# Auto-generated lineage graph!
# Dagster UI shows: stg_orders → fct_revenue → [downstream assets]

# Job + Schedule
revenue_job = define_asset_job("daily_revenue", selection=["fct_revenue"])
daily_schedule = ScheduleDefinition(
    job=revenue_job,
    cron_schedule="0 6 * * *",
)
```

### Airflow vs Prefect vs Dagster

```
Airflow:
  Model: Task-centric (DAG of tasks)
  Maturity: Most mature (Airbnb, 2014), huge ecosystem
  Ops: Heavy — needs dedicated infra, complex setup
  Backfill: Excellent
  Phù hợp: Teams already using it, need mature ecosystem

Prefect:
  Model: Task-centric, Python-first
  Maturity: Modern (2018), growing fast
  DX: Much simpler than Airflow — deploy without K8s
  Prefect Cloud: Managed option ($)
  Phù hợp: Python teams wanting simpler Airflow alternative

Dagster:
  Model: Asset-centric (think about DATA, not tasks)
  Maturity: Modern (2019), strong enterprise adoption 2024
  Asset lineage: Best-in-class visualization
  Testing: First-class support for testing assets
  Phù hợp: Teams wanting data lineage, software engineering best practices

dbt + simple cron:
  No orchestrator: Just cron + dbt Cloud CI
  Phù hợp: Small teams, simple pipelines, < 10 dbt models
  Limitation: No complex dependencies, no retry logic, no monitoring
```

### Observability for pipelines

```
What to monitor:
  Pipeline success/failure rate (per DAG/flow)
  Duration: Is pipeline getting slower over time?
  Data freshness: When did this table last update?
  Row counts: Significant change = possible upstream issue
  Schema drift: New/removed columns from source

Tools:
  Airflow: Built-in Flower UI, Prometheus metrics, Datadog integration
  Prefect: Prefect Cloud dashboard (managed)
  Dagster: Dagster Cloud or OSS UI with asset health
  Monte Carlo: Data observability platform (enterprise)
  Elementary: dbt-native data observability (open source, good)

Elementary dbt integration:
  # Add to packages.yml:
  packages:
    - package: elementary-data/elementary
      version: 0.14.0

  # Run after dbt run:
  elementary report  # Generates HTML report with:
    # - Failed tests
    # - Data freshness per model
    # - Row count anomalies
    # - Column-level lineage
```


---

## 12. Data Catalog & Lineage

### Why data discovery matters

```
Without catalog:
  "Where is our revenue data?" → 2-day investigation, 5 Slack threads
  "Is this column still used?" → Nobody knows, afraid to delete
  "Who owns the orders table?" → Mystery
  "Did data change after the migration?" → Discover in production

With catalog:
  Search "revenue" → find fct_revenue, see description, owner, freshness
  Column usage: See which dashboards/models reference orders.status
  Lineage: "orders.status comes from production.orders via stg_orders"
  Ownership: Team + Slack channel per dataset
```

### DataHub — open source, enterprise-grade

```yaml
# catalog-info approach: Tag datasets in dbt
# models/marts/finance/fct_revenue.sql config block:

{{ config(
    meta={
        "owner": "data-team@company.com",
        "team": "Finance",
        "tier": "tier1",
        "pii": false,
        "description": "Daily revenue by category, updated 6am",
        "slack_channel": "#data-finance",
    }
) }}

# DataHub ingestion config (datahub-ingestion):
source:
  type: dbt
  config:
    manifest_path: ./target/manifest.json
    catalog_path: ./target/catalog.json
    sources_path: ./target/sources.json

sink:
  type: datahub-rest
  config:
    server: http://datahub-gms:8080

# Run: datahub ingest -c datahub-config.yml
# → All dbt models auto-discovered with lineage, descriptions, owners
```

### Column-level lineage

```
Column lineage answers: "Where does orders.shipping_address come from?"
  fct_orders.shipping_address
    ← int_orders.shipping_address
      ← stg_orders.shipping_address
        ← production.orders.address (raw source)

Tools:
  dbt: Model-level lineage built-in (dbt lineage graph)
  OpenLineage: Standard for column-level lineage across tools
  DataHub: Ingests OpenLineage events → column-level lineage UI
  Marquez: Lightweight, good OpenLineage support
  SQLLineage: Parse SQL → extract column lineage (open source)

Why column lineage matters:
  Impact analysis: "If we change orders.status values, what breaks?"
  PII tracking: "Which columns contain email addresses?"
    → List all downstream models using that column
  Compliance: GDPR erasure path — what needs to be updated?
```

### Elementary — dbt-native observability

```yaml
# packages.yml (dbt project)
packages:
  - package: elementary-data/elementary
    version: 0.14.1

# dbt_project.yml
models:
  elementary:
    +schema: elementary  # Store monitoring data in separate schema

# Run after dbt run:
# elementary report → generates standalone HTML report

# What Elementary monitors automatically:
# - dbt test results (pass/fail per model per run)
# - Row count anomalies (sudden drop/spike)
# - Null rate anomalies
# - Schema changes (new/removed columns)
# - Data freshness (last updated timestamp)
# - Execution time trends

# Alert config (elementary/config.yml):
alerts:
  slack:
    webhook: !env SLACK_WEBHOOK_URL
    channel: "#data-alerts"
  alert_on:
    - dbt_test_failures
    - schema_changes
    - anomalies
```

---

## 13. Reverse ETL

### What is Reverse ETL

```
Traditional ETL: Operational DB → Warehouse (for analysis)
Reverse ETL:     Warehouse → Operational tools (CRM, marketing, support)

Why: Data team computes rich customer segments in warehouse (BigQuery/Snowflake)
     Sales team needs those segments in Salesforce
     Support needs customer tier in Zendesk
     Without Reverse ETL: Manual CSV exports, API scripts, one-off jobs

Use cases:
  CRM enrichment:    customer_ltv, segment, risk_score → Salesforce
  Marketing:         User cohorts, behavioral segments → Braze, Marketo
  Support:           Customer tier, recent orders → Zendesk, Intercom
  Product:           Feature flag eligibility → LaunchDarkly
  Finance:           Invoice status, payment history → billing system
```

### Tools comparison

```
Hightouch (category leader, managed):
  Connect: BigQuery/Snowflake → 100+ destinations
  Scheduling: Triggered or cron-based
  Transformations: SQL-based model as source
  Price: $350/month starter
  Best for: Marketing/CRM use cases, non-technical users

Census (strong alternative):
  Similar feature set to Hightouch
  Better dbt integration (read dbt models directly)
  Segment Connections: Unify customer data across sources
  Price: Similar to Hightouch

Airbyte Destinations (open source option):
  If already using Airbyte for ingestion
  Not purpose-built for Reverse ETL but workable

Custom (Python/dbt):
  Simple cases: dbt model → Python script → API calls
  Viable for: 1-3 destinations, low volume, technical team
  Breaks down at: Complex sync logic, high volume, many destinations
```

### Reverse ETL architecture

```
Source: Warehouse (BigQuery/Snowflake/Redshift)
  SQL query: SELECT user_id, ltv_segment, risk_score, last_order_date FROM dim_customers

Sync strategy:
  Full sync: Replace all records (small tables, < 100K rows)
  Incremental: Only send changed records (using updated_at or snapshot comparison)
  Event-triggered: Sync immediately when specific condition met

Destination: Salesforce, HubSpot, Intercom, etc.
  Match records: By email, user_id, or custom field
  Upsert: Update existing, create if not found

Monitoring:
  Sync status per destination
  Failed records (schema mismatch, API errors)
  Sync latency (how fresh is CRM vs warehouse?)
```


## Checklist Data Engineering

> 🔴 MUST | 🟠 SHOULD | 🟡 NICE

🔴 MUST:
- [ ] CDC replication slot lag monitored (alert > 1GB lag)
- [ ] Data quality checks trên critical pipelines (not_null, unique, range)
- [ ] Pipeline failures alert on-call (không silent failure)
- [ ] PII data không trong raw layer unencrypted (masking hoặc tokenization)
- [ ] Incremental processing cho large tables (không full reload mỗi ngày)

🟠 SHOULD:
- [ ] dbt tests trên tất cả staging models (not_null, unique, accepted_values)
- [ ] Data freshness monitoring (warn nếu source > 6h old)
- [ ] Idempotent pipelines (retry-safe, same output for same input)
- [ ] Partition strategy documented và enforced (prevent full scans)
- [ ] Schema evolution policy (expand-contract cho CDC downstream)
- [ ] Cost monitoring per pipeline / per model (query cost alert)

🟡 NICE:
- [ ] Data lineage documentation (Marquez, dbt lineage graph)
- [ ] Feature store cho ML features (avoid training-serving skew)
- [ ] Great Expectations hoặc Soda cho data quality assertions
- [ ] Column-level data encryption cho sensitive fields
- [ ] Query cost optimization (materialized views, clustering keys)
