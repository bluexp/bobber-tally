#!/usr/bin/env python3
"""Sample WFDB HTTPS without retries, so intermittent failures remain visible."""

import argparse
import datetime
import json
import subprocess
import sys
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="wfdb.cc")
    parser.add_argument("--rounds", type=int, default=5)
    parser.add_argument("--interval", type=float, default=3)
    parser.add_argument("--timeout", type=float, default=15)
    args = parser.parse_args()
    if args.rounds < 1 or args.interval < 0 or args.timeout <= 0:
        parser.error("rounds and timeout must be positive; interval must be nonnegative")
    if not args.host or any(c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-" for c in args.host):
        parser.error("host must be a DNS hostname")

    failures = 0
    total = 0
    paths = ("/", "/downloads/", "/en/downloads/", "/downloads/wfdb-macos-appcast.xml")
    for round_number in range(1, args.rounds + 1):
        for path in paths:
            result = subprocess.run(
                ["curl", "--silent", "--show-error", "--head", "--output", "/dev/null",
                 "--connect-timeout", str(min(8, args.timeout)), "--max-time", str(args.timeout),
                 "--write-out", "%{json}", "https://" + args.host + path],
                capture_output=True, text=True, check=False,
            )
            try:
                metrics = json.loads(result.stdout)
            except json.JSONDecodeError:
                metrics = {}
            ok = result.returncode == 0 and metrics.get("http_code") == 200
            total += 1
            failures += not ok
            print(json.dumps({
                "at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
                "round": round_number, "host": args.host, "path": path, "ok": ok,
                "exit": result.returncode, "status": metrics.get("http_code"),
                "ip": metrics.get("remote_ip"),
                "dns_s": metrics.get("time_namelookup"),
                "tcp_s": metrics.get("time_connect"),
                "tls_s": metrics.get("time_appconnect"),
                "first_byte_s": metrics.get("time_starttransfer"),
                "total_s": metrics.get("time_total"),
                "error": result.stderr.strip(),
            }), flush=True)
        if round_number < args.rounds:
            time.sleep(args.interval)
    print(json.dumps({"total": total, "passed": total - failures, "failed": failures}), flush=True)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
