#!/usr/bin/env python3
import os
import sys
import subprocess
import shutil
import socket
from datetime import datetime

# ── ANSI colors ───────────────────────────────────────────────────────────────
RESET  = "\033[0m"
BOLD   = "\033[1m"
DIM    = "\033[2m"
PURPLE = "\033[35m"
CYAN   = "\033[36m"
GREEN  = "\033[32m"
RED    = "\033[31m"
YELLOW = "\033[33m"
WHITE  = "\033[37m"

DEV_MODE = os.environ.get("ENV") == "dev"

def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    return r.returncode, r.stdout.strip()

def check(label, fn):
    try:
        value = fn()
        return True, value
    except Exception as e:
        return False, str(e)

# ── Checks ────────────────────────────────────────────────────────────────────
def get_gpu():
    if DEV_MODE:
        return "Mock GPU (dev mode)"
    code, out = run(["nvidia-smi", "--query-gpu=name,memory.total", "--format=csv,noheader"])
    if code != 0:
        raise Exception("nvidia-smi failed")
    return out.split(",")[0].strip()

def get_disk():
    path = "/" if DEV_MODE else "/var/lib/abacus-llm"
    usage = shutil.disk_usage(path)
    free  = usage.free  / (1024 ** 3)
    total = usage.total / (1024 ** 3)
    if free < 10:
        raise Exception(f"only {free:.1f}GB free")
    return f"{free:.1f}GB free / {total:.0f}GB total"

def get_docker():
    if DEV_MODE:
        return "running (dev mode)"
    code, _ = run(["docker", "info"])
    if code != 0:
        raise Exception("not running")
    return "running"

def get_config():
    if DEV_MODE:
        return "dev mode"
    p = "/etc/abacus-appliance/secrets.env"
    if not os.path.exists(p):
        raise Exception("secrets.env missing")
    return "ok"

def get_gateway():
    import urllib.request
    try:
        urllib.request.urlopen("http://localhost/healthz", timeout=2)
        return "up"
    except:
        raise Exception("not responding")

# ── Banner ────────────────────────────────────────────────────────────────────
def print_banner():
    version = "dev"
    try:
        version = open("/etc/abacus-version").read().strip()
    except:
        pass

    hostname = socket.gethostname()
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    print(f"""
{PURPLE}{BOLD}
  █████╗ ██████╗  █████╗  ██████╗██╗   ██╗███████╗
 ██╔══██╗██╔══██╗██╔══██╗██╔════╝██║   ██║██╔════╝
 ███████║██████╔╝███████║██║     ██║   ██║███████╗
 ██╔══██║██╔══██╗██╔══██║██║     ██║   ██║╚════██║
 ██║  ██║██████╔╝██║  ██║╚██████╗╚██████╔╝███████║
 ╚═╝  ╚═╝╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝
{RESET}{CYAN}{BOLD} LLM Appliance{RESET}{DIM}  v{version}{RESET}
""")
    print(f"  {DIM}Hostname : {RESET}{WHITE}{hostname}{RESET}")
    print(f"  {DIM}Time     : {RESET}{WHITE}{now}{RESET}")
    print(f"  {DIM}Mode     : {RESET}{WHITE}{'DEV' if DEV_MODE else 'PRODUCTION'}{RESET}")
    print()

# ── Self-test output ──────────────────────────────────────────────────────────
def print_checks():
    print(f"  {BOLD}System Checks{RESET}")
    print(f"  {DIM}{'─' * 40}{RESET}")

    checks = [
        ("GPU",         get_gpu,     True),
        ("Disk Space",  get_disk,    False),
        ("Docker",      get_docker,  True),
        ("Config",      get_config,  True),
        ("Gateway",     get_gateway, True),
    ]

    all_passed = True
    for label, fn, skippable in checks:
        if skippable and DEV_MODE:
            print(f"  {YELLOW}~{RESET}  {label:<14} {DIM}skipped (dev){RESET}")
            continue
        ok, val = check(label, fn)
        if ok:
            print(f"  {GREEN}✓{RESET}  {label:<14} {DIM}{val}{RESET}")
        else:
            print(f"  {RED}✗{RESET}  {label:<14} {RED}{val}{RESET}")
            all_passed = False

    print(f"  {DIM}{'─' * 40}{RESET}")
    if all_passed:
        print(f"  {GREEN}{BOLD}All checks passed.{RESET}")
    else:
        print(f"  {RED}{BOLD}Some checks failed. Run: journalctl -u abacus-selftest{RESET}")
    print()

# ── Main ──────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print_banner()
    print_checks()