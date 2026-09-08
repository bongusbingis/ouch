"""Install the isolated native gate without moving credentials or durable requests."""

import os
from pathlib import Path
import subprocess
import sys
import winreg

from workflow_common import ROOT, atomic_write, digest, file_lock, write_json


def main():
    if sys.version_info[:2] != (3, 12):
        raise SystemExit("Use the project's Python 3.12 environment")
    home = Path(os.environ["LOCALAPPDATA"]) / "RobloxAssetGate"
    home.mkdir(parents=True, exist_ok=True)
    with file_lock(home / "gate.lock"):
        python = home / "venv/Scripts/python.exe"
        if not python.exists():
            subprocess.run([sys.executable, "-m", "venv", str(home / "venv")], check=True)
        subprocess.run([str(python), "-m", "pip", "install", "Pillow==12.3.0", "httpx==0.28.1", "keyring==25.7.0"], check=True)
        files = {}
        for name in ("gate_runtime.py", "asset_policy.py", "workflow_common.py"):
            data = (ROOT / "tools" / name).read_bytes()
            atomic_write(home / "app" / name, data)
            files[name] = digest(data)
        launcher = 'import sys\nfrom pathlib import Path\nsys.path.insert(0, str(Path(__file__).resolve().parent / "app"))\nfrom gate_runtime import main\nmain()\n'
        atomic_write(home / "run.py", launcher)
        command = f'@echo off\r\n"{python}" -I "{home / "run.py"}" %*\r\n'
        atomic_write(home / "bin/rbx-asset-gate.cmd", command)
        write_json(home / "installation.json", {"schema_version": 1, "source_files": files, "python": str(python)})
        with winreg.CreateKey(winreg.HKEY_CURRENT_USER, "Environment") as key:
            try:
                path, _ = winreg.QueryValueEx(key, "Path")
            except FileNotFoundError:
                path = ""
            target = str(home / "bin")
            if target.casefold() not in {item.rstrip("\\").casefold() for item in path.split(";")}:
                winreg.SetValueEx(key, "Path", 0, winreg.REG_EXPAND_SZ, path.rstrip(";") + ";" + target)
        import ctypes

        result = ctypes.c_size_t()
        ctypes.windll.user32.SendMessageTimeoutW(0xFFFF, 0x001A, 0, "Environment", 2, 5000, ctypes.byref(result))
    print(f"Installed: {home}\nOpen a new PowerShell for PATH changes. Existing SQLite state is preserved.")


if __name__ == "__main__":
    main()
