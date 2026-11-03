"""Run native Windows console tools without opening or focusing a terminal."""
import json
import os
import pathlib
import shutil
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent
def local_appdata():
    override = os.environ.get("CTG_WINDOWS_LOCALAPPDATA")
    if override:
        return pathlib.Path(override)
    if os.name == "nt":
        return pathlib.Path(os.environ["LOCALAPPDATA"])
    command = pathlib.Path("/mnt/c/Windows/System32/cmd.exe")
    if not command.exists():
        raise RuntimeError("Native tools require Windows/WSL; set CTG_WINDOWS_LOCALAPPDATA if using another mount.")
    value = subprocess.check_output([str(command), "/d", "/c", "echo", "%LOCALAPPDATA%"], cwd="/mnt/c", text=True).strip().splitlines()[-1]
    return pathlib.Path(subprocess.check_output(["wslpath", "-u", value], text=True).strip())


def native_godot(name="Godot_console.exe"):
    return os.environ.get("GODOT_WINDOWS", str(local_appdata() / "Programs/Godot" / name))


TEMP = local_appdata() / "Temp/CloseTheGapMovie-20261102"


def windows(path):
    return str(pathlib.Path(path).resolve()) if os.name == 'nt' else subprocess.check_output(['wslpath', '-w', str(path)], text=True).strip()


def run_hidden(argv, log, timeout):
    TEMP.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='console-', dir=TEMP) as folder:
        folder = pathlib.Path(folder)
        for name in ['run_windows_console.ps1', 'run_windows_console.vbs']:
            shutil.copy2(ROOT / name, folder / name)
        specification = {'executable': windows(argv[0]), 'arguments': subprocess.list2cmdline(argv[1:]),
                         'log': windows(folder / 'output.log'), 'result': windows(folder / 'result.json'),
                         'timeout_ms': int(timeout * 1000)}
        (folder / 'job.json').write_text(json.dumps(specification))
        script_host = pathlib.Path(os.environ.get('WINDIR', 'C:/Windows')) / 'System32/wscript.exe' if os.name == 'nt' else pathlib.Path('/mnt/c/Windows/System32/wscript.exe')
        process = subprocess.run([str(script_host), '/B', '/Nologo',
                                  windows(folder / 'run_windows_console.vbs'),
                                  windows(folder / 'run_windows_console.ps1'), windows(folder / 'job.json')],
                                 timeout=timeout + 10)
        result_path = folder / 'result.json'
        if not result_path.exists():
            raise RuntimeError(f'Windows console launcher failed ({process.returncode})')
        result = json.loads(result_path.read_text(encoding='utf-8-sig'))
        if (folder / 'output.log').exists():
            shutil.copy2(folder / 'output.log', log)
        if result.get('timed_out'):
            raise TimeoutError(f'Windows tool exceeded {timeout}s: {log}')
        if result.get('error'):
            raise RuntimeError(result['error'])
        return result['exit_code']
