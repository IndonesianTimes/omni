#!/usr/bin/env python3
import argparse, json
from pathlib import Path

DEFAULT_ENABLE = {"takeover","file-upload"}
VALID_EXTRA = {"ssrf","rfi","hhi"}

def base_url_from_evidence(evidence, target):
    if evidence and evidence.startswith("http"):
        try:
            from urllib.parse import urlparse
            u = urlparse(evidence)
            return f"{u.scheme}://{u.netloc}" if u.netloc else None
        except:
            return None
    return f"http://{target}"

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-i","--input",required=True)
    ap.add_argument("-o","--output",required=True)
    ap.add_argument("--job",required=True)
    ap.add_argument("--include",default="takeover,file-upload")
    args=ap.parse_args()

    enabled=set(x.strip() for x in args.include.split(",") if x.strip())
    allowed=set(DEFAULT_ENABLE)
    for x in enabled:
        if x in DEFAULT_ENABLE or x in VALID_EXTRA:
            allowed.add(x)

    lines=Path(args.input).read_text(encoding="utf-8").splitlines()
    items=[]
    for ln in lines:
        if not ln.strip(): continue
        try: o=json.loads(ln)
        except: continue
        cat=o.get("category")
        target=(o.get("target") or "").strip().lower()
        evidence=o.get("evidence")
        base=base_url_from_evidence(evidence,target)

        if not base: continue
        if cat=="takeover" and "takeover" in allowed:
            items.append({"job_id":args.job,"target":base,"kind":"nuclei-takeover","tool":"nuclei","args":{"tags":"takeovers","severities":"high,critical"},"priority":95})
        if cat in ("file-upload","rfi") and "file-upload" in allowed:
            items.append({"job_id":args.job,"target":base,"kind":"nuclei-file-upload","tool":"nuclei","args":{"tags":"file-upload","severities":"high,critical"},"priority":90})
        if cat=="ssrf" and "ssrf" in allowed:
            items.append({"job_id":args.job,"target":base,"kind":"ssrf-probe","tool":"custom","args":{"mode":"safe"},"priority":70})
        if cat=="hhi" and "hhi" in allowed:
            items.append({"job_id":args.job,"target":base,"kind":"hhi-probe","tool":"custom","args":{"mode":"safe"},"priority":60})

    outp=Path(args.output)
    with outp.open("w",encoding="utf-8") as f:
        for it in items: f.write(json.dumps(it,ensure_ascii=False)+"\n")

    print(f"[OK] wrote queue: {outp} ({len(items)} items)")

if __name__=="__main__":
    main()
