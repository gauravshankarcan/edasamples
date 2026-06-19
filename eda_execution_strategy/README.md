# EDA Execution Strategy

## What this sample demonstrates

The `execution_strategy` is an **activation-level** setting in AAP EDA that controls
how events are processed when multiple events arrive while an action is still running.

| Strategy | Behaviour | Default |
|----------|-----------|---------|
| `sequential` | Events queue up; each waits for the previous action to finish | Yes |
| `parallel` | Events processed concurrently; new events start immediately | No |

**The rulebook is identical in both cases.** Only the activation configuration differs.

---

## Files

```
eda_execution_strategy/
├── README.md                     ← This file
├── rulebook_sequential.yml       ← Rulebook for sequential activation (local docs)
├── rulebook_parallel.yml         ← Rulebook for parallel activation (local docs)
├── setup_aap.yml                 ← Creates AAP Controller + EDA objects
└── playbooks/
    └── slow_action.yml           ← Sleeps for N seconds to make timing visible

rulebooks/
├── eda-execution-sequential.yml  ← AAP-activatable version
└── eda-execution-parallel.yml    ← AAP-activatable version
```

---

## Key Concepts

### Sequential (default)

```
Time→   0s         10s        20s
        │           │           │
Event 1 ├──[Job A: 10s]──────►│
Event 2 │           ├──[Job B: 10s]──────►│  (waited for Job A)
Event 3 │           │           ├──[Job C: 10s]──────►│  (waited for Job B)
```

- Events are processed in strict arrival order.
- If Job A takes 10s and 3 events arrive, total processing time is 30s minimum.
- No race conditions between jobs.

### Parallel

```
Time→   0s         5s    10s
        │           │      │
Event 1 ├──[Job A: 10s]──────────────►│
Event 2 ├──[Job B: 5s]──────────►│    (started immediately, finished first!)
Event 3 ├──[Job C: 8s]────────────────►│
```

- Events start immediately regardless of what is running.
- Job B (5s) finishes before Job A (10s) even though it arrived later.
- Total wall-clock time ≈ max(job durations) instead of sum.
- Risk: concurrent jobs modifying the same resource may conflict.

---

## When to Use Each

| Scenario | Use |
|----------|-----|
| Database migrations (order matters) | `sequential` |
| Stateful deployments (one at a time) | `sequential` |
| Audit/compliance: events must be ordered | `sequential` |
| Alert processing (high volume, stateless) | `parallel` |
| Patching different hosts concurrently | `parallel` |
| CI/CD pipeline triggers (each repo independent) | `parallel` |
| Events that modify the SAME shared resource | `sequential` |
| Events that each target different hosts | `parallel` |

---

## How to Configure in AAP

### Via the API (used by `setup_aap.yml`)

```json
POST /api/eda/v1/activations/
{
  "name": "my-activation",
  "execution_strategy": "sequential",
  ...
}
```

### Via `aap_config/vars/eda_config.yml`

```yaml
eda_rulebook_activations:
  - name: my-sequential-activation
    execution_strategy: sequential  # ← here
    rulebook: eda-execution-sequential.yml
    ...

  - name: my-parallel-activation
    execution_strategy: parallel    # ← here
    rulebook: eda-execution-parallel.yml
    ...
```

### Via the AAP EDA UI

1. Automation Decisions → Rulebook Activations → Create
2. Select **Execution Strategy**: Sequential or Parallel

---

## Differences vs `match_multiple_rules`

These are orthogonal concepts:

| Concept | What it controls |
|---------|-----------------|
| **Overlapping conditions** (multi-match) | How many rules fire for ONE event |
| **execution_strategy** | How many events are processed at the SAME time |

You can have:
- Sequential + single-match: one event at a time, one rule per event
- Sequential + multi-match: one event at a time, multiple rules per event
- Parallel + single-match: many events at a time, one rule per event
- Parallel + multi-match: many events at a time, multiple rules per event (highest throughput)

---

## Differences Table

| Feature | Sequential | Parallel |
|---------|-----------|----------|
| Event processing | One at a time | Concurrent |
| Queue when busy | Yes (FIFO) | No queue |
| Order preserved | Yes | No |
| Concurrency risk | None | Yes (shared resources) |
| Throughput | Low (limited by slowest job) | High |
| Use for | Ordered, stateful operations | Stateless, high-volume |
| AAP activation setting | `execution_strategy: sequential` | `execution_strategy: parallel` |

### Playbook vs EDA comparison

| Playbook concept | EDA equivalent |
|-----------------|----------------|
| `serial: 1` in play | `execution_strategy: sequential` |
| `serial: 0` (all at once) | `execution_strategy: parallel` |
| `throttle: 1` per host | Sequential per host via `limit` |
| `async` tasks | Parallel strategy |

---

## Setup

```bash
source ~/.bashrc_eda_session
ansible-playbook eda_execution_strategy/setup_aap.yml
```

## Test — Observe the Difference

### Sequential test (second job waits for first):

```bash
# Send first event (10s sleep)
curl -X POST https://eda-execution-sequential-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"event_type":"deploy","event_id":"EVT-SEQ-01","sleep_seconds":10}'

# Send second event immediately (should queue behind first)
curl -X POST https://eda-execution-sequential-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"event_type":"deploy","event_id":"EVT-SEQ-02","sleep_seconds":5}'
```

Expected: EVT-SEQ-02 starts only after EVT-SEQ-01 finishes (~10s delay).

### Parallel test (both jobs start immediately):

```bash
# Send first event (10s sleep)
curl -X POST https://eda-execution-parallel-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"event_type":"alert","event_id":"EVT-PAR-01","sleep_seconds":10}'

# Send second event immediately (should start right away)
curl -X POST https://eda-execution-parallel-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"event_type":"alert","event_id":"EVT-PAR-02","sleep_seconds":5}'
```

Expected: Both jobs start simultaneously. EVT-PAR-02 (5s) finishes before EVT-PAR-01 (10s).

Check AAP Controller → Jobs to verify the timing.
