#!/bin/bash

# my_health.sh - Generate a static HTML page with Mac system health information

# Set output file path - default to current directory
OUTPUT_FILE="mac_health.html"
REFRESH_RATE=30  # Auto-refresh page every 30 seconds

# Get timestamp
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

# Get system information
HOSTNAME=$(hostname)
MACHINE_TYPE=$(sysctl -n hw.model)
OS_VERSION=$(sw_vers -productVersion)
UPTIME=$(uptime | awk '{print $3,$4,$5}' | sed 's/,//g')
KERNEL_VERSION=$(uname -v)

# Get CPU information
CPU_MODEL=$(sysctl -n machdep.cpu.brand_string)
CPU_CORES=$(sysctl -n hw.physicalcpu)
CPU_LOGICAL=$(sysctl -n hw.logicalcpu)
CPU_USAGE=$(top -l 1 -n 0 | grep "CPU usage" | awk '{print $3 " " $4 " " $5 " " $7 " " $8}')

# Get memory information
TOTAL_MEM=$(sysctl -n hw.memsize | awk '{print $0/1073741824 " GB"}')
MEM_PRESSURE=$(memory_pressure | grep "System-wide memory pressure" | cut -d ':' -f2 | xargs)
VM_STATS=$(vm_stat)
PAGE_SIZE=$(vm_stat | head -1 | awk '{print $8}' | sed 's/\.$//')

# Calculate memory usage from vm_stat
PAGES_FREE=$(echo "$VM_STATS" | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
PAGES_ACTIVE=$(echo "$VM_STATS" | grep "Pages active" | awk '{print $3}' | sed 's/\.//')
PAGES_INACTIVE=$(echo "$VM_STATS" | grep "Pages inactive" | awk '{print $3}' | sed 's/\.//')
PAGES_SPECULATIVE=$(echo "$VM_STATS" | grep "Pages speculative" | awk '{print $3}' | sed 's/\.//')
PAGES_WIRED=$(echo "$VM_STATS" | grep "Pages wired down" | awk '{print $4}' | sed 's/\.//')
PAGES_COMPRESSED=$(echo "$VM_STATS" | grep "Pages occupied by compressor" | awk '{print $5}' | sed 's/\.//')

# Calculate used memory
USED_MEM=$(bc <<< "scale=2; ($PAGES_ACTIVE + $PAGES_WIRED + $PAGES_COMPRESSED) * $PAGE_SIZE / 1073741824")
FREE_MEM=$(bc <<< "scale=2; ($PAGES_FREE + $PAGES_INACTIVE + $PAGES_SPECULATIVE) * $PAGE_SIZE / 1073741824")
MEM_USED_PCT=$(bc <<< "scale=1; $USED_MEM * 100 / ($USED_MEM + $FREE_MEM)")

# Get disk information
DISK_INFO=$(df -h | grep -v "map\|com.apple")

# Get network information
IP_INFO=$(ifconfig | grep "inet " | grep -v 127.0.0.1)
PUBLIC_IP=$(curl -s https://api.ipify.org 2>/dev/null || echo "Cannot determine public IP")
WIFI_INFO=$(networksetup -getairportnetwork en0 2>/dev/null || echo "Wi-Fi not available")

# Get load average
LOAD_AVG=$(sysctl -n vm.loadavg | awk '{print $2 " " $3 " " $4}')

# Get battery information if available
if system_profiler SPPowerDataType | grep -q "Battery Information"; then
    BATTERY_INFO=$(system_profiler SPPowerDataType | grep -A 15 "Battery Information" | grep -E "Cycle Count|Condition|Charge|Remaining")
else
    BATTERY_INFO="No battery information available"
fi

# Get top 5 processes by CPU
TOP_PROCESSES_CPU=$(ps -eo pcpu,pid,user,args | sort -k 1 -r | head -6 | tail -5 | awk '{print "<tr><td>" $1 "%</td><td>" $2 "</td><td>" $3 "</td><td>" substr($0, index($0,$4)) "</td></tr>"}')

# Get top 5 processes by memory
TOP_PROCESSES_MEM=$(ps -eo pmem,pid,user,args | sort -k 1 -r | head -6 | tail -5 | awk '{print "<tr><td>" $1 "%</td><td>" $2 "</td><td>" $3 "</td><td>" substr($0, index($0,$4)) "</td></tr>"}')

# Create HTML content
cat > "$OUTPUT_FILE" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="refresh" content="$REFRESH_RATE">
    <title>Mac Health Report - $HOSTNAME</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Open Sans', sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f8f8f8;
        }
        h1, h2 {
            color: #333;
            border-bottom: 1px solid #eaeaea;
            padding-bottom: 10px;
        }
        .section {
            background-color: white;
            padding: 20px;
            margin-bottom: 20px;
            border-radius: 5px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
        }
        .meter {
            height: 20px;
            background: #e6e6e6;
            border-radius: 10px;
            padding: 1px;
            box-shadow: inset 0 1px 3px rgba(0,0,0,.2);
            margin-top: 5px;
        }
        .meter > span {
            display: block;
            height: 100%;
            border-radius: 10px;
            background-color: #2196F3;
            position: relative;
            overflow: hidden;
        }
        .meter > span.warning {
            background-color: #FF9800;
        }
        .meter > span.danger {
            background-color: #F44336;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 10px;
        }
        th, td {
            text-align: left;
            padding: 8px;
            border-bottom: 1px solid #eee;
        }
        th {
            background-color: #f2f2f2;
        }
        .footer {
            text-align: center;
            color: #666;
            font-size: 0.8em;
            margin-top: 40px;
        }
        code {
            background: #f4f4f4;
            padding: 0.2em 0.4em;
            border-radius: 3px;
            font-size: 0.9em;
            font-family: SFMono-Regular, Consolas, 'Liberation Mono', Menlo, monospace;
        }
        pre {
            background: #f4f4f4;
            padding:.5em;
            border-radius: 3px;
            max-height: 200px;
            overflow: auto;
        }
        .timestamp {
            font-style: italic;
            color: #666;
            text-align: right;
        }
    </style>
</head>
<body>
    <h1>Mac Health Report</h1>
    <p class="timestamp">Generated on: $TIMESTAMP</p>
    
    <div class="section">
        <h2>System Information</h2>
        <div class="grid">
            <div>
                <p><strong>Hostname:</strong> $HOSTNAME</p>
                <p><strong>Model:</strong> $MACHINE_TYPE</p>
                <p><strong>OS Version:</strong> macOS $OS_VERSION</p>
                <p><strong>Kernel:</strong> $KERNEL_VERSION</p>
                <p><strong>Uptime:</strong> $UPTIME</p>
            </div>
            <div>
                <p><strong>CPU Model:</strong> $CPU_MODEL</p>
                <p><strong>CPU Cores:</strong> $CPU_CORES physical, $CPU_LOGICAL logical</p>
                <p><strong>CPU Usage:</strong> $CPU_USAGE</p>
                <p><strong>Load Average:</strong> $LOAD_AVG</p>
            </div>
        </div>
    </div>
    
    <div class="section">
        <h2>Memory Usage</h2>
        <p><strong>Total Memory:</strong> $TOTAL_MEM</p>
        <p><strong>Used Memory:</strong> $USED_MEM GB ($MEM_USED_PCT%)</p>
        <p><strong>Free Memory:</strong> $FREE_MEM GB</p>
        <p><strong>Memory Pressure:</strong> $MEM_PRESSURE</p>
        
        <div class="meter">
            <span style="width: $MEM_USED_PCT%" class="$([ $(echo "$MEM_USED_PCT > 80" | bc -l) -eq 1 ] && echo "danger" || [ $(echo "$MEM_USED_PCT > 60" | bc -l) -eq 1 ] && echo "warning")"></span>
        </div>
    </div>
    
    <div class="section">
        <h2>Disk Usage</h2>
        <pre>$DISK_INFO</pre>
    </div>
    
    <div class="section">
        <h2>Network Information</h2>
        <p><strong>Wi-Fi:</strong> $WIFI_INFO</p>
        <p><strong>Public IP:</strong> $PUBLIC_IP</p>
        <h3>Network Interfaces</h3>
        <pre>$IP_INFO</pre>
    </div>
    
    <div class="section">
        <h2>Battery Information</h2>
        <pre>$BATTERY_INFO</pre>
    </div>
    
    <div class="section">
        <h2>Top Processes by CPU</h2>
        <table>
            <tr>
                <th>CPU %</th>
                <th>PID</th>
                <th>User</th>
                <th>Command</th>
            </tr>
            $TOP_PROCESSES_CPU
        </table>
    </div>
    
    <div class="section">
        <h2>Top Processes by Memory</h2>
        <table>
            <tr>
                <th>MEM %</th>
                <th>PID</th>
                <th>User</th>
                <th>Command</th>
            </tr>
            $TOP_PROCESSES_MEM
        </table>
    </div>
    
    <div class="footer">
        <p>Generated by my_health.sh • Page auto-refreshes every $REFRESH_RATE seconds</p>
    </div>
</body>
</html>
EOF

echo "Mac health report generated at: $OUTPUT_FILE"

# Optional: Open the file in the default browser
open "$OUTPUT_FILE"