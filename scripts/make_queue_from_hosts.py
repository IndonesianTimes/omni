#!/usr/bin/env python3
import csv, json, argparse
from pathlib import Path

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-i","--input", required=True, help="recon_hosts.csv")
    ap.add_argument("-o","--output", required=True, help="pentest_queue.jsonl")
    ap.add_argument("--job", required=True, help="JOB_ID")
    ap.add_argument("--schemes", default="https,http", help="comma list (default: https,http)")
    ap.add_argument("--include", default="takeover,file-upload", help="categories to enqueue")
    args = ap.parse_args()

    include = set(x.strip() for x in args.include.split(",") if x.strip())
    schemes = [s for s in args.schemes.split(",") if s]

    rows = []
    with open(args.input, newline="", encoding="utf-8") as f:
        for i, r in enumerate(csv.DictReader(f)):
            host = (r.get("target") or "").strip().lower()
            if not host: continue
            for sch in schemes:
                base = f"{sch}://{host}"
                if "takeover" in include:
                    rows.append({
                        "job_id": args.job, "target": base, "kind": "nuclei-takeover",
                        "tool": "nuclei", "args": {"tags":"takeovers","severities":"high,critical"},
                        "priority": 95
                    })
                if "file-upload" in include:
                    rows.append({
                        "job_id": args.job, "target": base, "kind": "nuclei-file-upload",
                        "tool": "nuclei", "args": {"tags":"file-upload","severities":"high,critical"},
                        "priority": 90
                    })

    outp = Path(args.output)
    with outp.open("w", encoding="utf-8") as f:
        for it in rows:
            f.write(json.dumps(it, ensure_ascii=False) + "\n")
    print(f"[OK] wrote queue: {outp} ({len(rows)} items))")

if __name__ == "__main__":
    main()
