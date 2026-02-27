import os
import sys
import subprocess
import shutil

# In dev mode, skip hardware checks (GPU etc.)
DEV_MODE = os.environ.get("ENV") == "dev"
REQUIRED_DISK_GB = 10
REQUIRED_RAM_GB = 8

def check(name, fn, skip_in_dev=False):
    if skip_in_dev and DEV_MODE:
        print(f"  ~ {name} (skipped in dev mode)")
        return
    try:
        fn()
        print(f"  ✓ {name}")
    except Exception as e:
        print(f"  ✗ {name}: {e}")
        sys.exit(1)

def check_gpu():
    result = subprocess.run(["nvidia-smi"], capture_output=True)
    if result.returncode != 0:
        raise Exception("nvidia-smi failed")

def check_docker():
    result = subprocess.run(["docker", "info"], capture_output=True)
    if result.returncode != 0:
        raise Exception("docker not running")

def check_disk():
    path = "/var/lib/abacus-llm" if not DEV_MODE else "/"
    usage = shutil.disk_usage(path)
    free_gb = usage.free / (1024 ** 3)
    if free_gb < REQUIRED_DISK_GB:
        raise Exception(f"only {free_gb:.1f}GB free")

def check_config():
    if DEV_MODE:
        return  # no config files in dev
    if not os.path.exists("/etc/abacus-appliance/secrets.env"):
        raise Exception("secrets.env missing")

if __name__ == "__main__":
    mode = "DEV" if DEV_MODE else "PRODUCTION"
    print(f"Running Abacus self-tests [{mode}]...")
    check("GPU available",  check_gpu,    skip_in_dev=True)
    check("Docker running", check_docker, skip_in_dev=True)
    check("Disk space",     check_disk)
    check("Config exists",  check_config)
    print("All checks passed.")
    sys.exit(0)