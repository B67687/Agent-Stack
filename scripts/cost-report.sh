#!/usr/bin/env bash
set -euo pipefail

DB="${XDG_DATA_HOME:-$HOME/.local/share}/opencode/opencode.db"
echo "=== Cost Report ==="
echo ""

if [ ! -f "$DB" ]; then
    echo "DB not found at $DB"
    exit 0
fi

python3 -c "
import sqlite3, os
db = os.path.expanduser('$DB')
conn = sqlite3.connect(db)
cur = conn.cursor()

cur.execute(\"SELECT name FROM sqlite_master WHERE type='table' AND name='session'\")
if not cur.fetchone():
    print('No session table found — schema not supported')
    os._exit(0)

from datetime import datetime, timedelta
cutoff = (datetime.now() - timedelta(days=30)).isoformat()
cur.execute('SELECT model, tokens_input, tokens_output, cost, time_created FROM session WHERE time_created > ? ORDER BY time_created DESC', (cutoff,))
rows = cur.fetchall()

if not rows:
    print('No sessions in last 30 days')
    os._exit(0)

total_cost = 0.0
total_in = 0
total_out = 0
models = {}
print(f'Sessions ({len(rows)}) in last 30 days:')
print()
for r in rows[:20]:
    model = r[0] or 'unknown'
    tin = r[1] or 0
    tout = r[2] or 0
    cost = r[3] or 0.0
    total_in += tin
    total_out += tout
    total_cost += cost
    models[model] = models.get(model, 0) + 1
    created = (r[4] or '')[:10]
    in_m = tin / 1_000_000
    out_m = tout / 1_000_000
    print(f'  {created} | {model:40s} | in:{in_m:6.2f}M  out:{out_m:6.2f}M  | \${cost:.4f}')
print()
print(f'Sum: {total_in/1_000_000:.2f}M in + {total_out/1_000_000:.2f}M out = \${total_cost:.2f}')
print()
print('By model:')
for m, c in sorted(models.items()):
    print(f'  {m:40s} {c} sessions')
"
