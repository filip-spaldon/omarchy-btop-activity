#!/usr/bin/env python3
"""Measure the current telemetry engine, including its short-lived readers."""

import argparse
import json
import os
from pathlib import Path
import platform
import shutil
import signal
import statistics
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
CLOCK_TICKS = os.sysconf("SC_CLK_TCK")


def tree_usage(pid):
    """Include live children; stat's child times include already-reaped readers."""
    pending, seen = [pid], set()
    cpu = pss = rss = 0
    while pending:
        current = pending.pop()
        if current in seen:
            continue
        seen.add(current)
        directory = Path(f"/proc/{current}")
        try:
            fields = (directory / "stat").read_text().rsplit(")", 1)[1].split()
            cpu += sum(int(fields[i]) for i in (11, 12, 13, 14)) / CLOCK_TICKS
            for task in (directory / "task").iterdir():
                pending.extend(map(int, (task / "children").read_text().split()))
            for line in (directory / "smaps_rollup").read_text().splitlines():
                if line.startswith("Pss:"):
                    pss += int(line.split()[1]) / 1024
                elif line.startswith("Rss:"):
                    rss += int(line.split()[1]) / 1024
        except (FileNotFoundError, ProcessLookupError):
            # A reader can exit between listing it and reading its counters.
            continue
    return cpu, pss, rss


def measure(process, warmup, deadline):
    start = time.monotonic()
    baseline = None
    memory = []
    while True:
        pid, status, usage = os.wait4(process.pid, os.WNOHANG)
        now = time.monotonic()
        if pid:
            process.returncode = os.waitstatus_to_exitcode(status)
            break
        if now - start > deadline:
            raise TimeoutError("telemetry benchmark did not exit")
        if now - start >= warmup:
            cpu, pss, rss = tree_usage(process.pid)
            if baseline is None:
                baseline = (now, cpu)
            if pss > 0:
                memory.append((pss, rss))
        time.sleep(0.02)
    if process.returncode or baseline is None or not memory:
        raise RuntimeError(f"telemetry exited before measurement completed: {process.returncode}")
    elapsed = now - baseline[0]
    cpu_seconds = max(0, usage.ru_utime + usage.ru_stime - baseline[1])
    return {
        "measured_seconds": round(elapsed, 3),
        "cpu_seconds": round(cpu_seconds, 4),
        "cpu_percent_one_core": round(100 * cpu_seconds / elapsed, 2),
        "median_tree_pss_mib": round(statistics.median(m[0] for m in memory), 2),
        "peak_sampled_tree_pss_mib": round(max(m[0] for m in memory), 2),
        "peak_sampled_tree_rss_mib": round(max(m[1] for m in memory), 2),
        "peak_process_rss_mib": round(usage.ru_maxrss / 1024, 2),
        "memory_samples": len(memory),
    }


def benchmark(interval, seconds, warmup, mode):
    with tempfile.TemporaryDirectory(prefix="btop-telemetry-bench-") as directory:
        directory = Path(directory)
        config = directory / "shell.qml"
        shutil.copyfile(ROOT / "tests/telemetry-smoke.qml", config)
        environment = dict(os.environ, QT_QPA_PLATFORM="offscreen",
                           QT_FORCE_STDERR_LOGGING="1", BTOP_PLUGIN_ROOT=str(ROOT),
                           BTOP_SMOKE_UPDATE_MS=str(interval),
                           BTOP_SMOKE_IDLE_AFTER_MS="1000" if mode == "idle" else "0",
                           BTOP_SMOKE_MS=str(round((seconds + warmup) * 1000)))
        log_path = directory / "log"
        with log_path.open("w") as log:
            process = subprocess.Popen(
                ["quickshell", "--no-color", "-p", str(config)],
                stdout=log, stderr=subprocess.STDOUT, env=environment,
                start_new_session=True,
            )
            try:
                result = measure(process, warmup, seconds + warmup + 10)
            except Exception:
                print(log_path.read_text(), flush=True)
                raise
            finally:
                if process.returncode is None:
                    os.killpg(process.pid, signal.SIGTERM)
                    try:
                        process.wait(timeout=2)
                    except subprocess.TimeoutExpired:
                        os.killpg(process.pid, signal.SIGKILL)
                        process.wait()
        samples = [json.loads(line.split("TELEMETRY ", 1)[1])
                   for line in log_path.read_text().splitlines() if "TELEMETRY " in line]
        if not samples or any(sample["updateMs"] != interval for sample in samples):
            raise RuntimeError("telemetry did not confirm the requested interval")
        last = samples[-1]
        if last["active"] != (mode == "active"):
            raise RuntimeError("telemetry did not enter the requested activity state")
        if mode == "idle" and len({sample["lastSample"] for sample in samples[2:]}) != 1:
            raise RuntimeError("telemetry kept polling while idle")
        result.update(interval_ms=interval, mode=mode, gpu_sources=sorted({
            source for gpu in last["gpus"] for source in gpu["sources"].values()
        }), backend_errors=last["errors"], gpu_usage_available=any(
            gpu["usage"] is not None for gpu in last["gpus"]
        ))
        return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--intervals", nargs="+", type=int,
                        default=[100, 250, 500, 1000, 2000, 5000])
    parser.add_argument("--mode", choices=["active", "idle"], default="active",
                        help="idle stops sampling after a one-second hover")
    parser.add_argument("--seconds", type=float, default=10)
    parser.add_argument("--warmup", type=float, default=3)
    parser.add_argument("--json", type=Path, help="write results outside the checkout")
    args = parser.parse_args()
    if args.seconds < 2 or args.warmup < 0 or any(
        interval < 100 or interval > 86400000 for interval in args.intervals
    ):
        parser.error("use at least 2 measurement seconds and intervals from 100 to 86400000 ms")
    if args.mode == "idle" and args.warmup < 3:
        parser.error("idle measurements need at least 3 warmup seconds")
    print(f"Mode: {args.mode}; CPU: percent of one core; memory: process-tree MiB")
    print(" ms     CPU %    median PSS    sampled peak PSS", flush=True)
    results = []
    for interval in args.intervals:
        result = benchmark(interval, args.seconds, args.warmup, args.mode)
        results.append(result)
        print(f"{interval:5} {result['cpu_percent_one_core']:9.2f}"
              f" {result['median_tree_pss_mib']:13.2f}"
              f" {result['peak_sampled_tree_pss_mib']:19.2f}", flush=True)
        if result["backend_errors"] or not result["gpu_usage_available"]:
            print(f"  warning: incomplete GPU readings: {result['backend_errors']}", flush=True)
    report = {"host": platform.node(), "kernel": platform.release(),
              "warmup_seconds": args.warmup, "mode": args.mode, "results": results}
    if args.json:
        args.json.write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
