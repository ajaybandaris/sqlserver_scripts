# Infra Metrics – For Reference

This section lists commonly monitored **infrastructure-level metrics** for SQL Server environments, along with healthy ranges, warning signs, and how to interpret them during performance investigations.

| Metric Name | What It Measures | Healthy Range | Warning / Bad | Example Interpretation |
|------------|------------------|---------------|---------------|------------------------|
| **CPUUtilization** | Percentage of CPU used | 0–60% | >80% = high CPU pressure | CPU = 92% → queries are CPU-bound (missing indexes or heavy scans) |
| **FreeableMemory** | Free OS memory available | >2 GB | <500 MB = memory pressure | FreeableMemory = 150 MB → SQL reads from disk → slow performance |
| **DatabaseConnections** | Total SQL Server connections | <200 | >500 = risk of throttling | DatabaseConnections = 900 → no connection pooling |
| **ReadLatency** | Time to service read requests (ms) | <10 ms | >20 ms slow; >50 ms bad | ReadLatency = 80 ms → storage too slow, increase IOPS |
| **WriteLatency** | Time for write operations (ms) | <10 ms | >20 ms slow; >50 ms bad | WriteLatency = 70 ms → checkpoint/log writes delayed |
| **ReadIOPS** | Read operations per second | Within provisioned IOPS | Exceeding provisioned → throttling | ReadIOPS = 3000 but only 1000 provisioned → disk bottleneck |
| **WriteIOPS** | Write operations per second | Within provisioned IOPS | Exceeding provisioned → throttling | WriteIOPS = 2500 but storage supports 1500 → throttling |
| **ReadThroughput** | MB/s read from storage | ≤ storage max | Spikes = scans/large reads | ReadThroughput = 200 MB/s → large table scan |
| **WriteThroughput** | MB/s written to storage | ≤ storage max | Spikes = rebuilds/log pressure | WriteThroughput = 250 MB/s → index rebuild running |
| **DiskQueueDepth** | Pending I/O requests | 0–10 | >50 = disk saturated | DiskQueueDepth = 120 → IOPS insufficient |
| **ReplicaLag** | Sync delay for AlwaysOn replicas | <1 sec | >5 sec = replica behind | ReplicaLag = 10s → read replica stale |
| **BurstBalance** | Remaining burst credits (gp2/gp3) | 80–100% | <20% = severe throttling | BurstBalance = 5% → burst credits exhausted, storage slowed |
| **NetworkReceiveThroughput** | Data received by DB instance | Below instance max | Near limit = network bottleneck | Receive = 480 Mbps (limit ~500) → network saturated |
| **NetworkTransmitThroughput** | Data sent by DB instance | Below instance max | Near limit = network bottleneck | High transmit → backups or heavy SELECT queries |

---

### Notes
- Infrastructure metrics **do not fail fast** — they degrade slowly and mask deeper query or design issues.
- Always correlate infra metrics with **query execution plans, waits, and index usage**.
- Sustained pressure is more dangerous than short spikes.
