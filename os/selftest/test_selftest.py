import os
from pathlib import Path

import pytest
import yaml

@pytest.fixture(scope="session")
def spec():
    spec_file = Path(
        os.environ.get("SELFTEST_SPEC_FILE", "/etc/abacus-appliance/specs.yaml")
    )
    if not spec_file.exists():
        spec_file = Path("/opt/abacus-appliance/selftest/specs.yaml")
    assert spec_file.exists(), f"spec file not found: {spec_file}"
    with spec_file.open() as fh:
        return yaml.safe_load(fh)


def test_required_files_exist(host, spec):
    for path in spec["host"]["required_files"]:
        assert host.file(path).exists, f"missing required file: {path}"


def test_min_ram(host, spec):
    required_gb = float(spec["host"]["min_ram_gb"])
    mem_total_kb = int(host.check_output("awk '/MemTotal/ {print $2}' /proc/meminfo"))
    mem_gb = mem_total_kb / 1024 / 1024
    assert mem_gb >= required_gb, f"RAM too low: {mem_gb:.2f}GB < {required_gb}GB"


def test_root_free_space(host, spec):
    required_gb = float(spec["host"]["min_root_free_gb"])
    # Avoid shell-escaping issues by extracting only digits from df's avail column.
    free_gb = int(
        host.check_output("df -BG --output=avail / | tail -n1 | tr -dc '0-9'")
    )
    assert free_gb >= required_gb, f"Root free space too low: {free_gb}GB < {required_gb}GB"


def test_docker_running(host, spec):
    if not spec["services"].get("docker_must_be_running", True):
        pytest.skip("docker check disabled")
    assert host.service("docker").is_running, "docker service is not running"


def test_nvidia_gpu_present(host, spec):
    nvidia_spec = spec.get("nvidia", {})
    if not nvidia_spec.get("required", False):
        pytest.skip("GPU not required by spec")

    cmd = host.run("nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits")
    assert cmd.rc == 0, f"nvidia-smi failed: {cmd.stderr}"
    lines = [ln.strip() for ln in cmd.stdout.strip().splitlines() if ln.strip()]
    assert lines, "nvidia-smi returned no GPU entries"
    gpu_data = []
    for line in lines:
        name, mem = [x.strip() for x in line.split(",", 1)]
        gpu_data.append({"name": name, "memory_mb": int(mem)})

    required_vram_gb = float(nvidia_spec.get("min_vram_gb", 0))
    required_vram_mb = int(required_vram_gb * 1024)
    assert any(g["memory_mb"] >= required_vram_mb for g in gpu_data), (
        f"No GPU meets min VRAM {required_vram_gb}GB"
    )

    expected_name = nvidia_spec.get("expected_name_contains", "").strip().lower()
    if expected_name:
        assert any(expected_name in g["name"].lower() for g in gpu_data), (
            f"No GPU name contains '{expected_name}'"
        )


def test_nvidia_container_access(host, spec):
    nvidia_spec = spec.get("nvidia", {})
    if not nvidia_spec.get("required", False):
        pytest.skip("GPU not required by spec")
    if not nvidia_spec.get("require_container_gpu", False):
        pytest.skip("container GPU check disabled")

    cmd = host.run(
        "docker run --rm --gpus all nvidia/cuda:12.4.0-base-ubuntu24.04 nvidia-smi --query-gpu=name --format=csv,noheader"
    )
    assert cmd.rc == 0, f"container GPU access failed: {cmd.stderr}"
    assert cmd.stdout.strip(), "container nvidia-smi returned empty output"
