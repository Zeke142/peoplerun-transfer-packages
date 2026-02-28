#!/usr/bin/env python3
import json,sys,os
from datetime import datetime

MON="wp-content/uploads/peoplerun/monitor_status.jsonl"
objs=[]
if not os.path.isfile(MON):
    print("[]")
    sys.exit(0)

for ln in open(MON,'r', encoding='utf-8'):
    s = ln.strip()
    if not s:
        continue
    try:
        objs.append(json.loads(s))
    except Exception:
        # best-effort replace common placeholders
        s2 = s.replace("$(date -u +'%Y-%m-%dT%H:%M:%SZ')", datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"))
        s2 = s2.replace("$(date -u +%s)", str(int(datetime.utcnow().timestamp())))
        try:
            objs.append(json.loads(s2))
        except Exception:
            # skip broken line
            continue

# Optional: if WINDOW_START env var is set, filter out older records
ws_env = os.environ.get("WINDOW_START")
if ws_env:
    try:
        ws = datetime.fromisoformat(ws_env.replace("Z","+00:00"))
        filtered = []
        for o in objs:
            ts = o.get("ts")
            if not ts:
                continue
            try:
                t = datetime.fromisoformat(ts.replace("Z","+00:00"))
                if t >= ws:
                    filtered.append(o)
            except Exception:
                # if ts unparsable, keep conservative (include)
                filtered.append(o)
        objs = filtered
    except Exception:
        pass

print(json.dumps(objs))
