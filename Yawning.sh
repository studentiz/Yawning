#!/bin/bash
# Yawning.sh – A simple, friendly power‑saving helper 💤
#
# Overview:
#   It uses macOS's built‑in `taskpolicy` to assign matching processes to Apple Silicon efficiency cores,
#   reducing power draw and heat so your Mac can relax 😴.
#
# Highlights:
#   • Support matching process names or operating on all user processes.
#   • Optional foreground detection: also assign the current frontmost app to efficiency cores.
#   • Optional balance mode: intelligently switch between efficiency/performance cores based on CPU usage.
#   • Provide start/stop commands for one‑shot start and graceful stop; safe defaults for beginners.

set -e

# PID file for the background loop so the stop command can terminate it
PIDFILE="/tmp/yawning.pid"

# Default options (beginner‑friendly): equivalent to -g -f -B -b 80 -c 150
DEFAULT_GLOBAL=true
DEFAULT_FRONT=true
DEFAULT_BALANCE=true
DEFAULT_BAL_THRESHOLD=80
DEFAULT_CPU_THRESHOLD=150

usage() {
    cat <<'USAGE'
Yawning – let your Mac take a nap 💤

Usage:
  ./Yawning.sh start [options]   Start the background power‑saving loop
  ./Yawning.sh stop              Stop the running Yawning instance and clean the PID file
  ./Yawning.sh help              Show this help message

If no arguments are provided, running "./Yawning.sh" is equivalent to:
  sudo ./Yawning.sh start

Options (for the 'start' subcommand):
  -p PATTERN     Add a process name pattern to match (repeatable). Examples:
                 -p "Google Chrome" -p "Electron"
  -g             Global scan: operate on all non‑root user processes (not only by name)
  -f             Foreground detection: also assign the current frontmost app to efficiency cores
  -B             Balance mode: under heavy load, temporarily move hot processes to performance cores
  -b THRESHOLD   Per‑process CPU threshold for balance mode (default 80)
  -c THRESHOLD   Total system CPU threshold for balance mode (default 150)

Examples:
  Start with defaults (recommended):
    sudo ./Yawning.sh start
  Only manage browsers & Electron with balance mode:
    sudo ./Yawning.sh start -p "Google Chrome" -p "Electron" -B -b 80 -c 150 -f
  Stop the background loop:
    sudo ./Yawning.sh stop

Notes:
  - Apple Silicon Mac required (efficiency/performance cores).
  - Depending on your security settings, some operations may require sudo.
USAGE
}

# Parse options and run the main loop.
# This function runs in a background process and continuously monitors/adjusts target processes.
run_loop() {
    local patterns=("${RUN_PATTERNS[@]}")
    local global_search="$RUN_GLOBAL"
    local enable_front="$RUN_FRONT"
    local enable_balance="$RUN_BALANCE"
    local balance_threshold="$RUN_BAL_THRESHOLD"
    local cpu_threshold="$RUN_CPU_THRESHOLD"

    # Pin this shell process to efficiency cores
    taskpolicy -b -p $$

    local assigned_eff=()
    local assigned_perf=()
    local sleep_time=50

    while true; do
        local timestamp=$(date "+%H:%M:%S")
        echo "[$timestamp] Scanning processes..."

        # 获取待处理 PID 列表
        local pid_list
        if [[ "$global_search" == true ]]; then
            pid_list=$(ps aux | awk '$1!="root" && $1!="Apple" && $1!~ /^_/ { print $2 }')
        else
            local regex
            regex=$(printf "|%s" "${patterns[@]}")
            regex=${regex:1}
            pid_list=$(ps aux | grep -E "$regex" | grep -v grep | awk '{print $2}')
        fi

        # Foreground app detection
        if [[ "$enable_front" == true ]]; then
            local front_pid
            front_pid=$(osascript -e 'tell application "System Events" to get unix id of first process whose frontmost is true' 2>/dev/null || true)
            if [[ -n "$front_pid" ]]; then
                taskpolicy -b -p "$front_pid" && echo "Frontmost app PID $front_pid assigned to efficiency cores"
            fi
        fi

        for pid in $pid_list; do
            [[ "$pid" =~ ^[0-9]+$ ]] || continue

            if [[ "$enable_balance" == true ]]; then
                local total_cpu
                total_cpu=$(ps -A -o %cpu | awk 'NR>1 {s+=$1} END {printf "%.0f", s/NR*100}')
                local cpu_usage
                cpu_usage=$(ps -p "$pid" -o %cpu= | awk '{print $1}' || echo 0)
                local cpu_int=${cpu_usage%.*}
                if [[ "$total_cpu" -gt "$cpu_threshold" && "$cpu_int" -gt "$balance_threshold" ]]; then
                    if [[ ! " ${assigned_perf[*]} " =~ " ${pid} " ]]; then
                        taskpolicy -B -p "$pid" && echo "[BALANCE] PID $pid using CPU ${cpu_usage}% ，assigned to performance cores"
                        assigned_perf+=("$pid")
                        assigned_eff=("${assigned_eff[@]/$pid}")
                    fi
                    continue
                fi
            fi

            # Default case: assign to efficiency cores
            if [[ ! " ${assigned_eff[*]} " =~ " ${pid} " ]]; then
                if taskpolicy -b -p "$pid"; then
                    local cmd
                    cmd=$(ps -p "$pid" -o comm= | sed -E 's#.*/([^/]*\.app)/.*MacOS/##')
                    echo "已将 \"${cmd:-PID}\" (PID $pid) 分配到效率核心"
                    assigned_eff+=("$pid")
                    assigned_perf=("${assigned_perf[@]/$pid}")
                fi
                if [[ $sleep_time -gt 15 ]]; then
                    ((sleep_time-=3))
                fi
            fi
        done

        # Dynamically adjust the sleep interval to avoid high system load【242746668458481†L125-L144】
        if [[ $sleep_time -lt 1 ]]; then
            sleep_time=10
        elif [[ $sleep_time -lt 15 ]]; then
            ((sleep_time+=25))
        elif [[ $sleep_time -gt 90 && $sleep_time -le 120 ]]; then
            ((sleep_time+=1))
        elif [[ $sleep_time -gt 120 && $sleep_time -le 180 ]]; then
            ((sleep_time+=2))
        elif [[ $sleep_time -gt 180 && $sleep_time -le 200 ]]; then
            ((sleep_time+=3))
        elif [[ $sleep_time -gt 200 ]]; then
            ((sleep_time+=5))
        else
            ((sleep_time+=1))
        fi
        echo "Next scan in ${sleep_time} seconds..."
        sleep "$sleep_time"
    done
}

# Stop the running background process
stop_running() {
    if [[ -f "$PIDFILE" ]]; then
        local pid
        pid=$(cat "$PIDFILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" && echo "Yawning stopped (PID: $pid)."
        else
            echo "Found PID file but process not running; cleaned up."
        fi
        rm -f "$PIDFILE"
    else
        echo "No running Yawning instance found."
    fi
}

# Main entry: parse command and options
cmd="$1"
shift || true

case "$cmd" in
    stop)
        stop_running
        exit 0
        ;;
    help|-h|--help)
        usage
        exit 0
        ;;
    start|"")
        # If a background instance is already running, inform the user
        if [[ -f "$PIDFILE" ]]; then
            pid=$(cat "$PIDFILE")
            if kill -0 "$pid" 2>/dev/null; then
                echo "Yawning is already running (PID: $pid). To stop: $0 stop"
                exit 0
            else
                rm -f "$PIDFILE"
            fi
        fi

        # Initialize options to default values
        RUN_PATTERNS=()
        RUN_GLOBAL="$DEFAULT_GLOBAL"
        RUN_FRONT="$DEFAULT_FRONT"
        RUN_BALANCE="$DEFAULT_BALANCE"
        RUN_BAL_THRESHOLD="$DEFAULT_BAL_THRESHOLD"
        RUN_CPU_THRESHOLD="$DEFAULT_CPU_THRESHOLD"

        # If explicit options are provided after 'start', override defaults
        if [[ "$cmd" == "start" ]]; then
            # 如果用户在 start 后提供参数，则覆盖默认
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    -p)
                        shift
                        RUN_PATTERNS+=("$1")
                        ;;
                    -g)
                        RUN_GLOBAL=true
                        ;;
                    -f)
                        RUN_FRONT=true
                        ;;
                    -B)
                        RUN_BALANCE=true
                        ;;
                    -b)
                        shift
                        RUN_BAL_THRESHOLD="$1"
                        ;;
                    -c)
                        shift
                        RUN_CPU_THRESHOLD="$1"
                        ;;
                    *)
                        echo "Unknown option: $1" >&2
                        usage
                        exit 1
                        ;;
                esac
                shift
            done
            # If custom patterns are specified, disable global search
            if [[ ${#RUN_PATTERNS[@]} -gt 0 ]]; then
                RUN_GLOBAL=false
            fi
        fi

        # Start the background loop
        (
            run_loop
        ) &
        child_pid=$!
        echo "$child_pid" > "$PIDFILE"
        echo "Yawning started (PID: $child_pid). Use '$0 stop' to stop."
        ;;
    *)
        echo "Unknown command: $cmd" >&2
        usage
        exit 1
        ;;
esac
