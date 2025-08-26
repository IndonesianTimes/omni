#!/usr/bin/env python3
# parse_recon.py — Parse output RECON (flat *.txt) jadi:
#   - recon_summary.jsonl (satu temuan/line)
#   - recon_hosts.csv     (host, server, x_powered_by, wp_hint)
#
# Usage:
#   python3 /opt/omni/scripts/parse_recon.py -i <recon_raw_dir> -o <job_dir>
import argparse, json, os, re, csv
from pathlib import Path
from datetime import datetime

CATEGORY_MAP_PATTERNS = [
    (r'\bRFI\b|Remote File Inclusion|/shell\.txt', "rfi", "high"),
    (r'\bSSRF\b|169\.254\.169\.254|metadata\.google\.internal', "ssrf", "high"),
    (r'Host Header Injection|host header reflected', "hhi", "high"),
    (r'Subdomain takeover', "takeover", "critical"),
    (r'File upload', "file-upload", "critical"),
    (r'Clickjacking|No X-Frame-Options', "xframe", "high"),
    (r'Missing security headers|No CSP|No HSTS', "missing-headers", "medium"),
    (r'Reflected parameter|XSS', "xss-reflection", "medium"),
    (r'HTTP Parameter Pollution|HPP', "hpp", "medium"),
    (r'No brute force protection', "no-bruteforce", "medium"),
    (r'No rate limiting', "no-rate-limit", "medium"),
]

def infer_category_and_sev(text: str):
    for pat, cat, sev in CATEGORY_MAP_PATTERNS:
        if re.search(pat, text, re.I):
            return cat, sev
    return "other", "low"

def safe_read(p: Path):
    try:
        return p.read_text(encoding="utf-8", errors="ignore")
    except:
        return ""

def extract_domain_from_filename(name: str):
    # example.com_headers.txt -> domain = example.com
    if "_" in name:
        return name.split("_", 1)[0]
    return None

def guess_wp(txt: str):
    return bool(re.search(r'/wp-login\.php|/wp-admin/|wordpress', txt, re.I))

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-i", "--input", required=True, help="Folder/file recon raw (*.txt)")
    ap.add_argument("-o", "--jobdir", required=True, help="Folder JOB output")
    args = ap.parse_args()

    in_path = Path(args.input)
    jobdir = Path(args.jobdir)
    jobdir.mkdir(parents=True, exist_ok=True)

    out_jsonl = jobdir / "recon_summary.jsonl"
    out_csv   = jobdir / "recon_hosts.csv"

    files = [in_path] if in_path.is_file() else sorted(in_path.glob("*.txt"))
    findings = []
    hosts = {}  # host -> {server,x_powered_by,wp_hint}

    for f in files:
        txt = safe_read(f)
        fname = f.name
        domain = extract_domain_from_filename(fname) or ""

        # headers.txt: deteksi basic issues
        if fname.endswith("_headers.txt"):
            for ln in txt.splitlines():
                cat, sev = infer_category_and_sev(ln)
                if cat in {"xframe","missing-headers"}:
                    findings.append({
                        "target": domain, "module": "headers",
                        "category": cat, "title": ln.strip(),
                        "evidence": ln.strip(), "severity": sev,
                        "confidence": 0.7,
                        "observed_at": datetime.utcnow().isoformat()+"Z",
                        "source": fname
                    })

        # tech.txt: simpan server / x-powered-by
        if fname.endswith("_tech.txt"):
            info = hosts.get(domain, {"server":"","x_powered_by":"","wp_hint":False})
            m1 = re.search(r'Server:\s*([^\r\n]+)', txt, re.I)
            m2 = re.search(r'X-Powered-By:\s*([^\r\n]+)', txt, re.I)
            if m1: info["server"] = m1.group(1).strip()
            if m2: info["x_powered_by"] = m2.group(1).strip()
            hosts[domain] = info

        # wayback/crawl: WP hint
        if fname.endswith("_crawl.txt") or fname.endswith("_wayback.txt"):
            if guess_wp(txt):
                info = hosts.get(domain, {"server":"","x_powered_by":"","wp_hint":False})
                info["wp_hint"] = True
                hosts[domain] = info

        # whois/dns/subdomains: tidak ada issue spesifik, tapi masukkan host kosong supaya muncul di CSV
        if fname.endswith(("_whois.txt","_dns.txt","_subdomains.txt")) and domain:
            hosts.setdefault(domain, {"server":"","x_powered_by":"","wp_hint":False})

    # tulis JSONL (boleh kosong kalau belum ada temuan)
    with out_jsonl.open("w", encoding="utf-8") as f:
        for x in findings:
            f.write(json.dumps(x, ensure_ascii=False) + "\n")

    # tulis CSV host info
    with out_csv.open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(["target","server","x_powered_by","wp_hint"])
        for h in sorted(hosts.keys()):
            info = hosts[h]
            w.writerow([h, info.get("server",""), info.get("x_powered_by",""), "true" if info.get("wp_hint") else "false"])

    print(f"[OK] wrote: {out_jsonl}")
    print(f"[OK] wrote: {out_csv}")

if __name__ == "__main__":
    main()

