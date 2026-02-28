#!/usr/bin/env python3
import csv,os,sys,datetime,re
OUTDIR="/home/customer/www/peoplerun.ai/public_html/wp-content/uploads/peoplerun/recover_reports"
TS=datetime.datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
OUT=os.path.join(OUTDIR,f"pages_audit_summary.{TS}.txt")
CSV_PATTERN=os.path.join(OUTDIR,"pages_http_audit.*.csv")

# find latest CSV
matches = sorted([p for p in __import__("glob").glob(CSV_PATTERN)])
if not matches:
    open(OUT,"w").write(f"{TS} NO_CSV_FOUND\n")
    print(OUT)
    sys.exit(0)
csvf = matches[-1]

def find_status_index(header, first_row):
    # try header names
    headers = [h.strip().lower() for h in header]
    for name in ("status","http_code","code","response","response_code","status_code","http_status","http-status"):
        if name in headers:
            return headers.index(name)
    # fallback: scan first row for a 3-digit numeric field
    for i,val in enumerate(first_row):
        v = re.sub(r'[^0-9]','',val or "")
        if len(v)>=3 and v.isdigit():
            return i
    return None

total=0; ok=0; redir=0; err=0
with open(csvf, newline='', encoding='utf-8') as fh:
    reader = csv.reader(fh)
    try:
        header = next(reader)
    except StopIteration:
        header = []
    first_row = None
    # peek first data row if exists
    rows = []
    for i,row in enumerate(reader):
        if i==0:
            first_row = row
        rows.append(row)
    idx = find_status_index(header if header else [], first_row if first_row else [])
    # if header looks like header line names (contains non-numeric), and first row exists but header might actually be data:
    # if idx is None and header looks like numeric row, treat header as data and search in header+rows
    if idx is None and header and all(re.sub(r'[^0-9]','',c).isdigit() for c in header):
        rows.insert(0, header)
        idx = find_status_index(header if header else [], rows[0])
    # now process rows list
    for row in rows:
        total += 1
        code = None
        if idx is not None and idx < len(row):
            code_field = row[idx]
            code_digits = re.sub(r'[^0-9]','',code_field or "")
            if code_digits=="":
                code = 0
            else:
                try:
                    code = int(code_digits)
                except:
                    code = 0
        else:
            # fallback: try to scan row for a 3-digit code
            code = 0
            for cell in row:
                cd = re.sub(r'[^0-9]','',cell or "")
                if len(cd)>=3 and cd.isdigit():
                    try:
                        code = int(cd)
                        break
                    except:
                        pass
        if code == 200:
            ok += 1
        elif 300 <= code < 400:
            redir += 1
        else:
            err += 1

with open(OUT,"w",encoding="utf-8") as fh:
    fh.write(f"ts={TS} csv={csvf} total={total} ok={ok} redirects={redir} errors={err}\n")
print(OUT)
print(open(OUT,encoding='utf-8').read())
