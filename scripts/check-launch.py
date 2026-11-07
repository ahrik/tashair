#!/usr/bin/env python3
"""Hold a real app process open, check it stays alive, terminate only that process."""
import argparse
from pathlib import Path
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument('--seconds', type=int, default=30)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
logfile = root / 'temp/launch.log'
with logfile.open('w') as log:
    process = subprocess.Popen([str(root / 'temp/outputs/TashAir.app/Contents/MacOS/TashAir'), '--preview'], stdout=log, stderr=log)
    try:
        deadline = time.monotonic() + args.seconds
        while time.monotonic() < deadline:
            if process.poll() is not None:
                raise RuntimeError(f'TashAir exited {process.returncode}: {logfile.read_text()}')
            time.sleep(0.25)
        print(f'TashAir stayed running for {args.seconds}s; startup log: {logfile}')
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
