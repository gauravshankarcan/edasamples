# EDA Regex Sample — CI/CD Image Tag Router

Demonstrates the two complementary ways to use regular expressions in EDA:

| Where | Operator / Filter | What it does |
|-------|-------------------|--------------|
| **Condition field** | `is match("pattern")` | Anchored match (like `re.match`) — the pattern must match from the start |
| **Condition field** | `is search("pattern")` | Substring match (like `re.search`) — pattern can appear anywhere |
| **Condition field** | `is regex("pattern")` | Alias for `is match` |
| **Action extra_vars** | `\| regex_replace("pat","repl")` | Jinja2 filter — transforms extracted data before passing to the job template |

> **Important**: `regex_replace` is **not** available as a condition operator — only in
> Jinja2 template expressions inside `extra_vars`. Use `is match` / `is search` in
> conditions and `regex_replace` in the extra_vars that follow.

---

## Scenario

A container registry webhook fires every time an image tag is pushed.
The tag format determines which pipeline to run and what environment to target:

| Tag format | Rule matched | Target env | Notes |
|------------|--------------|------------|-------|
| `v2.5.0` | Stable release | production | Exact semver `vX.Y.Z` |
| `v2.5.0-rc.1` | Release candidate | staging | `is match("v\\d+\\.\\d+\\.\\d+-rc\\.\\d+.*")` |
| `v1.0.0-beta.3` | Beta pre-release | dev | `is search("-beta\\.")` |
| `hotfix/v2.4.9` | Hotfix | production (high) | `is match("hotfix/v\\d+\\..*")` |
| `feature/add-oauth` | Feature branch | dev | `is match("feature/.*")` |

### `regex_replace` extractions per rule

| Extra var | `regex_replace` used | Example |
|-----------|----------------------|---------|
| `clean_version` | Strip `v` or `hotfix/v` prefix | `v2.5.0` → `2.5.0` |
| `major_minor` | Extract `X.Y` | `v2.5.0` → `2.5` |
| `base_version` | Strip prerelease suffix | `v2.5.0-rc.1` → `2.5.0` |
| `rc_number` | Extract RC counter | `v2.5.0-rc.1` → `1` |
| `branch_slug` | Slugify branch name | `feature/Add OAuth!` → `add-oauth-` |
| `k8s_safe_tag` | Sanitize for k8s labels | `hotfix/v2.4.9` → `hotfix-v2.4.9` |
| `major`/`minor`/`patch` | Split semver components | `v2.5.0` → `2`, `5`, `0` |

---

## Files

```
eda_regex_samples/
├── README.md                          ← this file
└── playbooks/
    └── process_with_regex.yml         ← displays routing decision + audit record

rulebooks/
└── eda-regex-demo.yml                 ← 6 rules using is match / is search / regex_replace
```

---

## AAP Setup

The setup is done by `setup_all_aap.sh`. Manually:

```bash
AAP_BASE="https://aap-aap.apps-crc.testing"
AAP_PASS="uCrmAIFPissa1gD1KnYfqJmcI5tw4iIs"
CTRL="$AAP_BASE/api/controller/v2"

# Create job template (reuses existing inventory + project)
curl -sk -X POST "$CTRL/job_templates/" -u "admin:$AAP_PASS" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "EDA-Regex-Demo",
    "job_type": "run",
    "inventory": <INVENTORY_ID>,
    "project": <PROJECT_ID>,
    "playbook": "eda_regex_samples/playbooks/process_with_regex.yml",
    "ask_variables_on_launch": true,
    "ask_limit_on_launch": true
  }'
```

---

## Test Payloads

```bash
WEBHOOK="https://eda-regex-demo-activation.apps-crc.testing"

# 1. Stable production release  →  Rule 5  (is match "v\d+\.\d+\.\d+$")
curl -X POST "$WEBHOOK" -H "Content-Type: application/json" \
  -d '{"image_tag":"v2.5.0","repo":"org/payment-service","pushed_by":"ci-bot"}'

# 2. Release candidate  →  Rule 2  (is match "v\d+\.\d+\.\d+-rc\.\d+")
curl -X POST "$WEBHOOK" -H "Content-Type: application/json" \
  -d '{"image_tag":"v2.5.0-rc.1","repo":"org/payment-service","pushed_by":"ci-bot"}'

# 3. Hotfix  →  Rule 1  (is match "hotfix/v\d+\.\d+\.\d+")
curl -X POST "$WEBHOOK" -H "Content-Type: application/json" \
  -d '{"image_tag":"hotfix/v2.4.9","repo":"org/payment-service","pushed_by":"sre-alice"}'

# 4. Feature branch  →  Rule 4  (is match "feature/.*")
curl -X POST "$WEBHOOK" -H "Content-Type: application/json" \
  -d '{"image_tag":"feature/add-oauth","repo":"org/payment-service","pushed_by":"dev-bob"}'

# 5. Unknown tag  →  Rule 6 catch-all (debug/reject)
curl -X POST "$WEBHOOK" -H "Content-Type: application/json" \
  -d '{"image_tag":"latest","repo":"org/payment-service","pushed_by":"unknown"}'
```

---

## Key EDA Concepts Illustrated

### Regex in conditions — `is match` vs `is search`

```yaml
# Anchored match: pattern must match from the START of the string
condition: event.payload.image_tag is match("v\\d+\\.\\d+\\.\\d+$")
# → matches "v2.5.0"  ✓
# → does NOT match "prefix/v2.5.0" ✗

# Substring match: pattern can be anywhere in the string
condition: event.payload.image_tag is search("-beta\\.")
# → matches "v1.0.0-beta.3"  ✓
# → matches "something-beta.1-suffix" ✓
```

### `regex_replace` in extra_vars

```yaml
extra_vars:
  # Strip leading 'v' prefix
  clean_version: "{{ event.payload.image_tag | regex_replace('^v', '') }}"

  # Extract major.minor only
  major_minor: "{{ event.payload.image_tag | regex_replace('^v(\\d+\\.\\d+)\\..*', '\\1') }}"

  # Sanitize for k8s label (no slashes, lowercase)
  k8s_safe_tag: "{{ event.payload.image_tag | regex_replace('[^a-zA-Z0-9._-]', '-') | lower }}"
```

### YAML escaping rules

In **conditions** (unquoted or single-quoted YAML strings):
- `is match("v\\d+\\.\\d+")` — inside double-quoted YAML, `\\d` → `\d`, `\\.` → `\.`

In **extra_vars** (Jinja2 template inside double-quoted YAML):
- `regex_replace('^v(\\d+)\\..*', '\\1')` — `\\d` → `\d`, `\\.` → `\.`, `\\1` → `\1` (backreference)
