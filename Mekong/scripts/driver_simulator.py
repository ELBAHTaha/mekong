#!/usr/bin/env python3
"""
Simple driver simulator that POSTs latitude/longitude to the backend every N seconds.
Usage example:
  pip install requests
  python scripts/driver_simulator.py --url http://127.0.0.1:8000 --id 123 --lat 33.5 --lng -7.6
"""

import argparse
import time
import random
import datetime
import sys

try:
    import requests
except ImportError:
    print("Missing dependency 'requests'. Install with: pip install requests")
    sys.exit(1)


def iso_now():
    return datetime.datetime.utcnow().replace(microsecond=0).isoformat() + "Z"


def main():
    p = argparse.ArgumentParser(description="Driver position simulator")
    p.add_argument("--url", required=True, help="Base backend URL, e.g. http://127.0.0.1:8000")
    p.add_argument("--id", required=True, type=int, help="Livraison id to update")
    p.add_argument("--lat", required=True, type=float, help="Starting latitude")
    p.add_argument("--lng", required=True, type=float, help="Starting longitude")
    p.add_argument("--interval", type=float, default=20.0, help="Seconds between updates (default: 20)")
    p.add_argument("--jitter", type=float, default=0.0005, help="Max random movement per step (degrees)")
    args = p.parse_args()

    url = args.url.rstrip('/')
    endpoint = f"{url}/api/livraisons/{args.id}/position"
    lat = args.lat
    lng = args.lng
    interval = args.interval
    jitter = args.jitter

    print(f"Simulating livraison {args.id} -> POST {endpoint} every {interval}s")
    try:
        while True:
            lat += random.uniform(-jitter, jitter)
            lng += random.uniform(-jitter, jitter)
            payload = {
                "latitude": round(lat, 7),
                "longitude": round(lng, 7),
                "timestamp": iso_now(),
            }
            try:
                r = requests.post(endpoint, json=payload, timeout=10)
                status = r.status_code
                text = r.text.strip()
            except Exception as e:
                status = None
                text = f"error: {e}"

            print(f"[{iso_now()}] POST -> {endpoint} payload={payload} status={status} resp={text}")
            time.sleep(interval)
    except KeyboardInterrupt:
        print("Simulator stopped by user")


if __name__ == '__main__':
    main()
