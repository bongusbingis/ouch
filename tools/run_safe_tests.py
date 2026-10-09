"""Run credential-free offline checks and persist UTF-8 evidence."""

import subprocess
import sys
from workflow_common import ROOT, atomic_write


def main():
    result = subprocess.run([sys.executable, "-m", "unittest", "discover", "-s", "tools", "-p", "test_*.py", "-v"], cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, encoding="utf-8")
    atomic_write(ROOT / ".review/offline-tests.txt", result.stdout)
    print(result.stdout)
    if result.returncode:
        return result.returncode
    return subprocess.run([sys.executable, "tools/validate_assets.py"], cwd=ROOT).returncode


if __name__ == "__main__":
    raise SystemExit(main())
