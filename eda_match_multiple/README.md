# EDA Match Multiple Rules

## What this sample demonstrates

In **ansible-rulebook**, ALL rules whose conditions match an incoming event will fire
simultaneously — there is no "stop after first match" behaviour by default.

This is different from how `when:` conditions work in playbooks, where you use
`elif`-style exclusivity. In EDA, each rule is fully independent.

The **difference** between single-match and multi-match is entirely in how you
write your conditions:

| Pattern | Conditions | Behaviour | Use when |
|---------|-----------|-----------|----------|
| **Single-match** | Mutually exclusive (non-overlapping) | Only ONE rule fires per event | Routing events to different handlers |
| **Multi-match** | Overlapping | ALL matching rules fire | Same event needs multiple actions (remediate AND notify) |

---

## Files

```
eda_match_multiple/
├── README.md                     ← This file
├── rulebook_single_match.yml     ← Mutually exclusive conditions → one rule fires
├── rulebook_multi_match.yml      ← Overlapping conditions → multiple rules fire
├── setup_aap.yml                 ← Creates AAP Controller + EDA objects
└── playbooks/
    ├── action_a.yml              ← Remediation action (job template target)
    └── action_b.yml              ← Notification action (job template target)

rulebooks/
├── eda-match-single.yml          ← AAP-activatable (same as rulebook_single_match.yml)
└── eda-match-multiple.yml        ← AAP-activatable (same as rulebook_multi_match.yml)
```

---

## Key Concepts

### 1. Rules Are Independent

```
Incoming event: { "severity": "critical", "event_type": "alert" }

Rule 1 condition: severity == "critical"   ✅ MATCHES → fires Action A
Rule 2 condition: severity == "critical"   ✅ MATCHES → fires Action B
Rule 3 condition: event_type is defined    ✅ MATCHES → fires debug log
```

All three rules fire for the **same event**. There is no "break" after the first match.

### 2. Achieving Effective Single-Match (Mutual Exclusivity)

Use conditions that cannot both be true at the same time:

```yaml
# Rule 1: fires only when severity is "critical"
condition: event.payload.severity == "critical"

# Rule 2: fires only when severity is "high" — cannot overlap with Rule 1
condition: event.payload.severity == "high"
```

A "critical" event triggers Rule 1 only. A "high" event triggers Rule 2 only.

### 3. Intentional Multi-Match (Overlapping Conditions)

Use the same (or overlapping) condition across multiple rules when you need
multiple actions for the same event:

```yaml
# Rule 1: Remediate — fires for critical or high
condition: event.payload.severity == "critical" or event.payload.severity == "high"
action: run_job_template: EDA-Match-Multiple-Action-A

# Rule 2: Notify — fires for critical or high (SAME condition!)
condition: event.payload.severity == "critical" or event.payload.severity == "high"
action: run_job_template: EDA-Match-Multiple-Action-B
```

Both rules fire for the same "critical" event → TWO job templates start.

### 4. Throttling Repeated Firings (`once_within`)

If you want a rule to fire at most once per time window (e.g., noisy alert streams):

```yaml
- name: "Throttled rule"
  condition: event.payload.severity == "high"
  throttle:
    once_within: 5 minutes
    group_by_attributes:
      - event.payload.event_type
  action:
    debug:
      msg: "Fires at most once per 5 min per event_type"
```

This is orthogonal to single/multi-match — it's about rate limiting, not exclusivity.

---

## Differences Table

| Feature | Single-Match Pattern | Multi-Match Pattern |
|---------|---------------------|---------------------|
| Conditions | Non-overlapping (`==` exact values) | Overlapping (`or` / broader) |
| Rules fired per event | 1 | Many |
| Use case | Event routing / classification | Remediate AND notify |
| AAP jobs launched | 1 per event | N (one per matching rule) |
| Throttling | Optional | Optional (`once_within`) |
| EDA built-in toggle | None — it's a condition design choice | None — same mechanism |

### Playbook vs EDA comparison

| Playbook concept | EDA equivalent |
|-----------------|----------------|
| `when: severity == 'critical'` | `condition: event.payload.severity == "critical"` |
| `elif: severity == 'high'` | **No elif** — write a separate rule |
| Only one `when` block executes | **All** matching rules execute |
| `block:` with multiple tasks | Multiple rules, each with its own action |

---

## Setup

```bash
source ~/.bashrc_eda_session
ansible-playbook eda_match_multiple/setup_aap.yml
```

## Test

```bash
# Single-match activation: only one rule fires
curl -X POST https://eda-match-single-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{"event_type":"alert","severity":"critical","event_id":"EVT-001"}'

# Multi-match activation: TWO rules fire → TWO job templates launched
curl -X POST https://eda-match-multiple-activation.apps-crc.testing \
  -H "Content-Type: application/json" \
  -d '{
    "event_type": "alert",
    "severity": "critical",
    "event_id": "EVT-002",
    "notification_channel": "slack"
  }'
```

Check AAP Controller → Jobs. The multi-match test should show **two** simultaneous
jobs (Action-A and Action-B) launched from a single webhook event.
