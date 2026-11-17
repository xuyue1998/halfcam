"""macOS CPU/I/O microbenchmarks. These are not iPhone cold-launch/FPS measurements."""

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]


def run(*args):
    result = subprocess.run(args, text=True, capture_output=True, timeout=180)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return json.loads(result.stdout)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--iterations", type=int, default=15)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if args.iterations < 3:
        parser.error("--iterations must be at least 3")
    base = Path(os.environ.get("TMPDIR", tempfile.gettempdir())) / "opencode"
    base.mkdir(parents=True, exist_ok=True)
    files = [
        ROOT / "HalfCam/Models.swift",
        ROOT / "HalfCam/Performance/StoreReader.swift",
        ROOT / "HalfCam/Film/FilmRenderer.swift",
        ROOT / "scripts/performance_benchmark.swift",
        ROOT / "scripts/benchmark_performance.py",
    ]
    report = {
        "scope": "optimized native macOS microbenchmarks; warm OS file cache; not iPhone FPS or cold launch",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "host": {"os": platform.mac_ver()[0], "architecture": platform.machine()},
        "source_sha256": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in files},
        "results": [],
    }
    with tempfile.TemporaryDirectory(prefix="halfcam-perf-", dir=base) as folder:
        work = Path(folder)
        renderer = work / "FilmRenderer.swift"
        # The production implementation uses no UIKit symbol; expose it to the
        # host compiler with Foundation/CoreGraphics instead, without changing its methods.
        renderer.write_text(files[2].read_text().replace(
            "import UIKit", "import Foundation\nimport CoreGraphics"
        ))
        executable = str(work / "benchmark")
        compilation = subprocess.run(
            ["swiftc", "-O", str(files[0]), str(files[1]), str(renderer),
             str(ROOT / "scripts/performance_benchmark.swift"), "-o", executable],
            text=True, capture_output=True, timeout=180,
        )
        if compilation.returncode:
            raise RuntimeError(compilation.stdout + compilation.stderr)
        for rolls in (24, 240):
            fixture = str(work / f"library-{rolls}")
            run(executable, "fixture", fixture, str(rolls))
            # Alternate order to avoid systematically favouring the second variant.
            order = ("baseline", "optimized") if rolls == 24 else ("optimized", "baseline")
            for variant in order:
                result = run(executable, "library", fixture, variant, str(args.iterations))
                result["fixture_rolls"] = rolls
                result["fixture_frames"] = rolls * 72
                report["results"].append(result)
        for variant in ("baseline", "optimized"):
            result = run(executable, "metadata", fixture, variant, str(args.iterations * 2))
            report["results"].append(result)
    text = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text)
    print(text, end="")


if __name__ == "__main__":
    main()
