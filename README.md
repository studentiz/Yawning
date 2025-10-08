# 💤 Yawning

*A friendly little power‑saving helper for Apple Silicon Macs.*  
Yawning sends selected processes to the **efficiency cores** to lower power draw and heat. When the system gets busy, it can temporarily move heavy tasks to **performance cores** so you stay smooth.

---

## What’s in this repo?
- `Yawning.sh` — the single script you run. It starts/stops a lightweight background loop that manages processes for you.

> **Good to know**
> - Apple Silicon only (big.LITTLE CPUs). Works on macOS where `taskpolicy` exists (preinstalled).
> - You’ll usually run it with `sudo` so the script can manage more processes reliably.

---

## TL;DR (Beginners start here)
1) **Download** this repo (Code ▸ Download ZIP) and unzip it.
2) **Open Terminal** (press `⌘ + Space`, type *Terminal*, hit *Return*).
3) **Give permission** and start with the safe defaults:
```bash
cd /path/to/unzipped/folder
chmod +x Yawning.sh
sudo ./Yawning.sh start
```
That’s it. Yawning runs in the background and uses recommended defaults.

To stop anytime:
```bash
sudo ./Yawning.sh stop
```

---

## What does “defaults” mean?
Running `sudo ./Yawning.sh start` is equivalent to:
```bash
sudo ./Yawning.sh start -g -f -B -b 80 -c 150
```
**Plain English:**
- `-g`  → manage **all user processes** (global mode).
- `-f`  → also manage the **foreground app** (the one you’re using now).
- `-B`  → **balance mode** on (heavy apps flip to performance cores automatically).
- `-b 80`  → if a single app uses **> 80% CPU**, treat it as heavy.
- `-c 150` → if total CPU load is **> 150%**, treat the system as busy.

> These defaults are a good fit for most people. Start with them. If you’re curious, tweak later.

---

## Everyday Use
- **Start (default):**
  ```bash
  sudo ./Yawning.sh start
  ```
- **Stop:**
  ```bash
  sudo ./Yawning.sh stop
  ```
- **Start on battery days, stop when plugged in** — totally fine. Start/stop is safe and immediate.

---

## Custom Settings (optional)
You can pass options after `start`:
- `-p "NAME"` — only manage apps that match this **name** (repeatable). Example:
  ```bash
  sudo ./Yawning.sh start -p "Google Chrome" -p "Electron"
  ```
  When you use `-p`, global mode (`-g`) is automatically disabled.
- `-g` — **global**: manage all non‑root user processes.
- `-f` — also apply rules to the **foreground** app.
- `-B` — **balance mode**: under heavy load, temporarily use performance cores for the heavy process.
- `-b N` — per‑process CPU threshold (default **80**).
- `-c N` — total CPU threshold (default **150**).

### More examples
```bash
# Minimal power saving (no balance logic)
sudo ./Yawning.sh start -g

# Browsers & Electron only, with balance mode
a sudo ./Yawning.sh start -p "Google Chrome" -p "Electron" -B -b 80 -c 150 -f

# Foreground app only
a sudo ./Yawning.sh start -f
```

---

## How do I know it works?
- **Lower fan/heat** and **longer battery life** during light workloads.
- Watch **Activity Monitor ▸ Energy** tab; over time, energy impact should improve.
- The script prints friendly logs to Terminal when started in the foreground. (When started normally, it runs in the background and stores its PID in `/tmp/yawning.pid`.)

> Tip: If you want to watch logs live, you can temporarily run it **without** backgrounding by removing the `&` in the script’s last section. Not necessary for normal use.

---

## Troubleshooting
- **“permission denied” / “operation not permitted”**
  - Make sure you ran `chmod +x Yawning.sh`.
  - Try `sudo`.
- **“command not found: ./Yawning.sh”**
  - Ensure you’re in the folder containing the file: `ls` should show `Yawning.sh`.
- **Nothing seems to happen**
  - That’s normal: Yawning works quietly in the background. Use `sudo ./Yawning.sh stop` to stop.
- **How to fully reset**
  - Stop it: `sudo ./Yawning.sh stop`
  - Remove the file if you don’t want it anymore.

---

## Uninstall
1) Stop the script: `sudo ./Yawning.sh stop`  
2) Delete `Yawning.sh` from your folder.

---

## Safety Notes
- Don’t aim this at critical system services.
- If you’re compiling, rendering, or gaming, consider **disabling** Yawning or balance it with `-B` and appropriate thresholds.

---

## License
MIT. Modify freely. Attribution appreciated.

## Credits
Inspired by the community’s efficiency‑core tools and the idea of smart process assignment on Apple Silicon. Thanks for the inspiration!

