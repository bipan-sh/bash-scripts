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

# Get per-core CPU usage if available (using powermetrics - requires sudo)
CPU_PER_CORE=""
if command -v powermetrics &> /dev/null; then
    CPU_PER_CORE_CMD="sudo powermetrics --samplers cpu_power -n 1 -i 1000 2>/dev/null | grep 'CPU Power' | sed 's/^[ \t]*//' | head -$CPU_LOGICAL"
    CPU_PER_CORE="This requires sudo permissions. Run 'sudo powermetrics' separately to view."
fi

# Get memory information
TOTAL_MEM=$(sysctl -n hw.memsize | awk '{print $0/1073741824 " GB"}')
MEM_PRESSURE=$(memory_pressure | grep "System-wide memory pressure" | cut -d ':' -f2 | xargs)
MEM_FREE_PCT=$(memory_pressure | grep "System-wide memory free percentage" | cut -d ':' -f2 | xargs)
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

# Get swap usage
SWAP_USAGE=$(sysctl vm.swapusage 2>/dev/null | sed 's/vm.swapusage://' | xargs)

# Get disk information
DISK_INFO=$(df -h | grep -v "map\|com.apple")

# Get SMART status for physical disks
SMART_STATUS=""
for disk in $(diskutil list | grep "/dev/disk" | grep -v "virtual\|disk image" | awk '{print $1}'); do
    if [[ $disk == /dev/disk* ]]; then
        disk_name=$(echo $disk | sed 's/\/dev\///')
        smart_info=$(diskutil info $disk | grep "SMART Status" | xargs)
        if [[ -n $smart_info ]]; then
            SMART_STATUS+="$disk_name: $smart_info<br>"
        fi
    fi
done

# Get network information
IP_INFO=$(ifconfig | grep "inet " | grep -v 127.0.0.1)
PUBLIC_IP=$(curl -s https://api.ipify.org 2>/dev/null || echo "Cannot determine public IP")
WIFI_INFO=$(networksetup -getairportnetwork en0 2>/dev/null || echo "Wi-Fi not available")

# Get network usage (requires nettop, result may vary)
NETWORK_USAGE="This requires the 'nettop' command to be run separately with sudo privileges."

# Get load average
LOAD_AVG=$(sysctl -n vm.loadavg | awk '{print $2 " " $3 " " $4}')

# Get battery information if available
BATTERY_INFO="No battery information available"
BATTERY_CYCLES=""
BATTERY_CONDITION=""
BATTERY_CAPACITY=""

if system_profiler SPPowerDataType | grep -q "Battery Information"; then
    BATTERY_INFO=$(system_profiler SPPowerDataType | grep -A 15 "Battery Information" | grep -E "Cycle Count|Condition|Charge|Remaining")
    
    # Get detailed battery info with ioreg if available
    if command -v ioreg &> /dev/null; then
        BATTERY_CYCLES=$(ioreg -rn AppleSmartBattery | grep "\"CycleCount\"" | awk '{print $3}')
        BATTERY_CONDITION=$(ioreg -rn AppleSmartBattery | grep "\"BatteryHealth\"" | awk '{print $3}' | sed 's/"//g')
        MAX_CAPACITY=$(ioreg -rn AppleSmartBattery | grep "\"MaxCapacity\"" | awk '{print $3}')
        DESIGN_CAPACITY=$(ioreg -rn AppleSmartBattery | grep "\"DesignCapacity\"" | awk '{print $3}')
        
        if [[ -n $MAX_CAPACITY && -n $DESIGN_CAPACITY ]]; then
            BATTERY_CAPACITY=$(bc <<< "scale=1; $MAX_CAPACITY * 100 / $DESIGN_CAPACITY")
            BATTERY_CAPACITY="$BATTERY_CAPACITY% of original capacity"
        fi
    fi
fi

# Get temperature and fan information (requires iStats gem)
TEMP_INFO="Temperature monitoring requires the iStats gem. Install with: sudo gem install iStats"
if command -v istats &> /dev/null; then
    TEMP_INFO=$(istats 2>/dev/null | grep -E "CPU temp|Fan" || echo "iStats output not available")
fi

# Get top 5 processes by CPU
TOP_PROCESSES_CPU=$(ps -eo pcpu,pid,user,args | sort -k 1 -r | head -6 | tail -5 | awk '{print "<tr><td>" $1 "%</td><td>" $2 "</td><td>" $3 "</td><td>" substr($0, index($0,$4)) "</td></tr>"}')

# Get top 5 processes by memory
TOP_PROCESSES_MEM=$(ps -eo pmem,pid,user,args | sort -k 1 -r | head -6 | tail -5 | awk '{print "<tr><td>" $1 "%</td><td>" $2 "</td><td>" $3 "</td><td>" substr($0, index($0,$4)) "</td></tr>"}')

# Check for software updates
SW_UPDATES=$(softwareupdate -l 2>/dev/null | grep -A 1 "Software Update found" || echo "No updates available")

# Get security status
SIP_STATUS=$(csrutil status 2>/dev/null || echo "SIP status check requires sudo")
GATEKEEPER_STATUS=$(spctl --status 2>/dev/null || echo "Gatekeeper status check requires sudo")
FIREWALL_STATUS=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null || echo "Firewall status check requires sudo")

# Get recent system logs
SYSTEM_LOGS=$(log show --style compact --predicate 'eventMessage contains "error" OR eventMessage contains "failure"' --last 1h 2>/dev/null | tail -20 || echo "Log access may require additional permissions")

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
        h1, h2, h3 {
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
            padding: .5em;
            border-radius: 3px;
            max-height: 200px;
            overflow: auto;
        }
        .timestamp {
            font-style: italic;
            color: #666;
            text-align: right;
        }
        .collapse-button {
            background: #f8f8f8;
            border: none;
            padding: 5px 10px;
            margin: 5px 0;
            border-radius: 3px;
            cursor: pointer;
        }
        .collapse-content {
            display: none;
        }
        .collapse-content.open {
            display: block;
        }
    </style>
    <script>
        function toggleCollapse(id) {
            const content = document.getElementById(id);
            if (content.classList.contains('open')) {
                content.classList.remove('open');
            } else {
                content.classList.add('open');
            }
        }
        
        window.onload = function() {
            // Open the first few sections by default
            document.getElementById('system-info').classList.add('open');
            document.getElementById('memory-info').classList.add('open');
            document.getElementById('cpu-info').classList.add('open');
        }
    </script>
</head>
<body>
    <h1>Mac Health Report</h1>
    <p class="timestamp">Generated on: $TIMESTAMP</p>
    
    <div class="section">
        <h2 onclick="toggleCollapse('system-info')" style="cursor:pointer;">
            System Information ▼
        </h2>
        <div id="system-info" class="collapse-content">
            <div class="grid">
                <div>
                    <p><strong>Hostname:</strong> $HOSTNAME</p>
                    <p><strong>Model:</strong> $MACHINE_TYPE</p>
                    <p><strong>OS Version:</strong> macOS $OS_VERSION</p>
                    <p><strong>Kernel:</strong> $KERNEL_VERSION</p>
                    <p><strong>Uptime:</strong> $UPTIME</p>
                </div>
                <div>
                    <p><strong>Load Average (1/5/15 min):</strong> $LOAD_AVG</p>
                    <h3>Software Updates</h3>
                    <pre>$SW_UPDATES</pre>
                </div>
            </div>
        </div>
    </div>
    
    <div class="section">
        <h2 onclick="toggleCollapse('cpu-info')" style="cursor:pointer;">
            CPU Information ▼
        </h2>
        <div id="cpu-info" class="collapse-content">
            <div class="grid">
                <div>
                    <p><strong>CPU Model:</strong> $CPU_MODEL</p>
                    <p><strong>CPU Cores:</strong> $CPU_CORES physical, $CPU_LOGICAL logical</p>
                    <p><strong>CPU Usage:</strong> $CPU_USAGE</p>
                </div>
                <div>
                    <h3>Per-Core Usage</h3>
                    <pre>$CPU_PER_CORE</pre>
                    
                    <h3>Temperature Information</h3>
                    <pre>$TEMP_INFO</pre>
                </div>
            </div>
            
            <h3>Top Processes by CPU</h3>
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
    </div>
    
    <div class="section">
        <h2 onclick="toggleCollapse('memory-info')" style="cursor:pointer;">
            Memory Usage ▼
        </h2>
        <div id="memory-info" class="collapse-content">
            <div class="grid">
                <div>
                    <p><strong>Total Memory:</strong> $TOTAL_MEM</p>
                    <p><strong>Used Memory:</strong> $USED_MEM GB ($MEM_USED_PCT%)</p>
                    <p><strong>Free Memory:</strong> $FREE_MEM GB</p>
                    <p><strong>Memory Pressure:</strong> $MEM_PRESSURE</p>
                    <p><strong>Free Percentage:</strong> $MEM_FREE_PCT</p>
                    
                    <div class="meter">
                        <span style="width: $MEM_USED_PCT%" class="$([ $(echo "$MEM_USED_PCT > 80" | bc -l) -eq 1 ] && echo "danger" || [ $(echo "$MEM_USED_PCT > 60" | bc -l) -eq 1 ] && echo "warning")"></span>
                    </div>
                </div>
                <div>
                    <h3>Swap Usage</h3>
                    <pre>$SWAP_USAGE</pre>
                    
                    <h3>Top Processes by Memory</h3>
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
            </div>
        </div>
    </div>
    
    <div class="section">
        <h2 onclick="toggleCollapse('disk-info')" style="cursor:pointer;">
            Storage Information ▼
        </h2>
        <div id="disk-info" class="collapse-content">
            <h3>Disk Usage</h3>
            <pre>$DISK_INFO</pre>
            
            <h3>SMART Status</h3>
            <p>$SMART_STATUS</p>
        </div>
    </div>
    
    <div class="section">
        <h2 onclick="toggleCollapse('network-info')" style="cursor:pointer;">
            Network Information ▼
        </h2>
        <div id="network-info" class="collapse-content">
            <p><strong>Wi-Fi:</strong> $WIFI_INFO</p>
            <p><strong>Public IP:</strong> $PUBLIC_IP</p>
            
            <h3>Network Interfaces</h3>
            <pre>$IP_INFO</pre>
            
            <h3>Network Usage</h3>
            <p>$NETWORK_USAGE</p>
        </div>
    </div>
    
    <div class="section">
        <h2 onclick="toggleCollapse('battery-info')" style="cursor:pointer;">
            Battery Information ▼
        </h2>
        <div id="battery-info" class="collapse-content">
            <div class="grid">
                <div>
                    <pre>$BATTERY_INFO</pre>
                </div>
                <div>
                    <p><strong>Battery Cycles:</strong> $BATTERY_CYCLES</p>
                    <p><strong>Battery Health:</strong> $BATTERY_CONDITION</p>
                    <p><strong>Battery Capacity:</strong> $BATTERY_CAPACITY</p>
                </div>
            </div>
        </div>
    </div>
    
    <div class="section">
        <h2 onclick="toggleCollapse('security-info')" style="cursor:pointer;">
            Security Status ▼
        </h2>
        <div id="security-info" class="collapse-content">
            <p><strong>System Integrity Protection (SIP):</strong> <pre>$SIP_STATUS</pre></p>
            <p><strong>Gatekeeper:</strong> <pre>$GATEKEEPER_STATUS</pre></p>
            <p><strong>Firewall:</strong> <pre>$FIREWALL_STATUS</pre></p>
        </div>
    </div>
    
    <div class="section">
        <h2 onclick="toggleCollapse('logs-info')" style="cursor:pointer;">
            Recent System Logs ▼
        </h2>
        <div id="logs-info" class="collapse-content">
            <p>Last hour's error and failure messages:</p>
            <pre>$SYSTEM_LOGS</pre>
        </div>
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
