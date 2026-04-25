#!/bin/bash
#
# Armbian + Docker System Status Script
# Displays system information in a formatted MOTD-style output
#

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Separator line
SEPARATOR="${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Header
print_header() {
    echo -e "\n${SEPARATOR}"
    echo -e "${CYAN}${BOLD}  ╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}  ║           ARMBIAN + DOCKER SYSTEM STATUS                         ║${NC}"
    echo -e "${CYAN}${BOLD}  ╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${SEPARATOR}\n"
}

# System Information
print_system_info() {
    echo -e "${WHITE}${BOLD}📦 SYSTEM INFORMATION${NC}"
    echo -e "${SEPARATOR}"

    # Hostname and OS
    HOSTNAME=$(hostname)
    OS_INFO=$(grep "PRETTY_NAME" /etc/os-release 2>/dev/null | cut -d'"' -f2)
    KERNEL=$(uname -r)
    ARCH=$(uname -m)
    UPTIME=$(uptime -p 2>/dev/null || uptime | awk -F'( |,|:)+' '{print $6,$7",",$8,"hours,",$9,"minutes"}')

    # Armbian specific info
    ARMBIAN_VERSION=""
    if [ -f /etc/armbian-release ]; then
        ARMBIAN_VERSION=$(grep "VERSION" /etc/armbian-release | cut -d'=' -f2)
        BOARD=$(grep "BOARD" /etc/armbian-release | cut -d'=' -f2)
    fi

    printf "  ${CYAN}%-15s${NC} %s\n" "Hostname:" "$HOSTNAME"
    printf "  ${CYAN}%-15s${NC} %s\n" "OS:" "$OS_INFO"
    [ -n "$ARMBIAN_VERSION" ] && printf "  ${CYAN}%-15s${NC} %s\n" "Armbian Ver:" "$ARMBIAN_VERSION"
    [ -n "$BOARD" ] && printf "  ${CYAN}%-15s${NC} %s\n" "Board:" "$BOARD"
    printf "  ${CYAN}%-15s${NC} %s (%s)\n" "Kernel:" "$KERNEL" "$ARCH"
    printf "  ${CYAN}%-15s${NC} %s\n" "Uptime:" "$UPTIME"
    printf "  ${CYAN}%-15s${NC} %s\n" "Date/Time:" "$(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo ""
}

# CPU Information
print_cpu_info() {
    echo -e "${WHITE}${BOLD}🔧 CPU STATUS${NC}"
    echo -e "${SEPARATOR}"

    # CPU Model
    CPU_MODEL=$(grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d':' -f2 | xargs)
    [ -z "$CPU_MODEL" ] && CPU_MODEL=$(grep "Hardware" /proc/cpuinfo | cut -d':' -f2 | xargs)
    CPU_CORES=$(nproc)

    # CPU Load
    LOAD=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
    LOAD_1=$(echo $LOAD | awk '{print $1}')

    # CPU Usage percentage
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 2>/dev/null)
    [ -z "$CPU_USAGE" ] && CPU_USAGE=$(vmstat 1 2 | tail -1 | awk '{print 100-$15}')

    # CPU Temperature (Armbian specific paths)
    CPU_TEMP=""
    for temp_file in /sys/class/thermal/thermal_zone0/temp /sys/devices/virtual/thermal/thermal_zone0/temp; do
        if [ -f "$temp_file" ]; then
            TEMP_RAW=$(cat "$temp_file")
            CPU_TEMP=$((TEMP_RAW / 1000))
            break
        fi
    done

    # Temperature color coding
    TEMP_COLOR=$GREEN
    if [ -n "$CPU_TEMP" ]; then
        [ "$CPU_TEMP" -gt 60 ] && TEMP_COLOR=$YELLOW
        [ "$CPU_TEMP" -gt 75 ] && TEMP_COLOR=$RED
    fi

    printf "  ${CYAN}%-15s${NC} %s (%s cores)\n" "CPU:" "${CPU_MODEL:-Unknown}" "$CPU_CORES"
    printf "  ${CYAN}%-15s${NC} %s\n" "Load Avg:" "$LOAD"
    [ -n "$CPU_USAGE" ] && printf "  ${CYAN}%-15s${NC} %.1f%%\n" "CPU Usage:" "$CPU_USAGE"
    [ -n "$CPU_TEMP" ] && printf "  ${CYAN}%-15s${NC} ${TEMP_COLOR}%s°C${NC}\n" "Temperature:" "$CPU_TEMP"
    echo ""
}

# Memory Information
print_memory_info() {
    echo -e "${WHITE}${BOLD}💾 MEMORY STATUS${NC}"
    echo -e "${SEPARATOR}"

    # Memory stats
    MEM_TOTAL=$(free -m | awk '/^Mem:/ {print $2}')
    MEM_USED=$(free -m | awk '/^Mem:/ {print $3}')
    MEM_FREE=$(free -m | awk '/^Mem:/ {print $4}')
    MEM_AVAILABLE=$(free -m | awk '/^Mem:/ {print $7}')
    MEM_CACHED=$(free -m | awk '/^Mem:/ {print $6}')
    MEM_PERCENT=$((MEM_USED * 100 / MEM_TOTAL))

    # Swap stats
    SWAP_TOTAL=$(free -m | awk '/^Swap:/ {print $2}')
    SWAP_USED=$(free -m | awk '/^Swap:/ {print $3}')

    # Memory color coding
    MEM_COLOR=$GREEN
    [ "$MEM_PERCENT" -gt 70 ] && MEM_COLOR=$YELLOW
    [ "$MEM_PERCENT" -gt 90 ] && MEM_COLOR=$RED

    printf "  ${CYAN}%-15s${NC} %sMB / %sMB (${MEM_COLOR}%s%%${NC})\n" "RAM Used:" "$MEM_USED" "$MEM_TOTAL" "$MEM_PERCENT"
    printf "  ${CYAN}%-15s${NC} %sMB\n" "Available:" "$MEM_AVAILABLE"
    printf "  ${CYAN}%-15s${NC} %sMB\n" "Free:" "$MEM_FREE"
    printf "  ${CYAN}%-15s${NC} %sMB\n" "Cached:" "$MEM_CACHED"

    if [ "$SWAP_TOTAL" -gt 0 ]; then
        SWAP_PERCENT=$((SWAP_USED * 100 / SWAP_TOTAL))
        SWAP_COLOR=$GREEN
        [ "$SWAP_PERCENT" -gt 50 ] && SWAP_COLOR=$YELLOW
        [ "$SWAP_PERCENT" -gt 80 ] && SWAP_COLOR=$RED
        printf "  ${CYAN}%-15s${NC} %sMB / %sMB (${SWAP_COLOR}%s%%${NC})\n" "Swap:" "$SWAP_USED" "$SWAP_TOTAL" "$SWAP_PERCENT"
    else
        printf "  ${CYAN}%-15s${NC} Not configured\n" "Swap:"
    fi
    echo ""
}


# Disk Information
print_disk_info() {
    echo -e "${WHITE}${BOLD}💿 DISK USAGE${NC}"
    echo -e "${SEPARATOR}"

    # Main filesystems
    df -h --output=source,size,used,avail,pcent,target 2>/dev/null | grep -E "^/dev/" | while read line; do
        DEVICE=$(echo $line | awk '{print $1}')
        SIZE=$(echo $line | awk '{print $2}')
        USED=$(echo $line | awk '{print $3}')
        AVAIL=$(echo $line | awk '{print $4}')
        PERCENT=$(echo $line | awk '{print $5}' | tr -d '%')
        MOUNT=$(echo $line | awk '{print $6}')

        # Color coding
        DISK_COLOR=$GREEN
        [ "$PERCENT" -gt 70 ] && DISK_COLOR=$YELLOW
        [ "$PERCENT" -gt 90 ] && DISK_COLOR=$RED

        printf "  ${CYAN}%-20s${NC} %s / %s (${DISK_COLOR}%s%%${NC}) → %s\n" "$DEVICE" "$USED" "$SIZE" "$PERCENT" "$MOUNT"
    done
    echo ""
}

# Network Information
print_network_info() {
    echo -e "${WHITE}${BOLD}🌐 NETWORK STATUS${NC}"
    echo -e "${SEPARATOR}"

    # Get active interfaces
    for iface in $(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo"); do
        IP_ADDR=$(ip -4 addr show "$iface" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
        if [ -n "$IP_ADDR" ]; then
            STATE=$(cat /sys/class/net/$iface/operstate 2>/dev/null)
            STATE_COLOR=$GREEN
            [ "$STATE" != "up" ] && STATE_COLOR=$RED

            printf "  ${CYAN}%-15s${NC} %s (${STATE_COLOR}%s${NC})\n" "$iface:" "$IP_ADDR" "$STATE"
        fi
    done

    # External IP (optional, comment out if not needed)
    EXT_IP=$(curl -s --connect-timeout 2 ifconfig.me 2>/dev/null || echo "N/A")
    [ -n "$EXT_IP" ] && [ "$EXT_IP" != "N/A" ] && printf "  ${CYAN}%-15s${NC} %s\n" "External IP:" "$EXT_IP"
    echo ""
}

# Docker Information
print_docker_info() {
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        echo -e "${WHITE}${BOLD}🐳 DOCKER STATUS${NC}"
        echo -e "${SEPARATOR}"
        echo -e "  ${YELLOW}Docker is not installed${NC}"
        echo ""
        return
    fi

    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        echo -e "${WHITE}${BOLD}🐳 DOCKER STATUS${NC}"
        echo -e "${SEPARATOR}"
        echo -e "  ${RED}Docker daemon is not running${NC}"
        echo ""
        return
    fi

    echo -e "${WHITE}${BOLD}🐳 DOCKER STATUS${NC}"
    echo -e "${SEPARATOR}"

    # Docker version
    DOCKER_VERSION=$(docker version --format '{{.Server.Version}}' 2>/dev/null)
    printf "  ${CYAN}%-15s${NC} %s\n" "Version:" "$DOCKER_VERSION"

    # Container counts
    TOTAL_CONTAINERS=$(docker ps -a --format '{{.ID}}' | wc -l)
    RUNNING_CONTAINERS=$(docker ps --format '{{.ID}}' | wc -l)
    STOPPED_CONTAINERS=$((TOTAL_CONTAINERS - RUNNING_CONTAINERS))

    printf "  ${CYAN}%-15s${NC} ${GREEN}%s running${NC}, ${YELLOW}%s stopped${NC}, %s total\n" \
        "Containers:" "$RUNNING_CONTAINERS" "$STOPPED_CONTAINERS" "$TOTAL_CONTAINERS"

    # Images count
    IMAGES=$(docker images --format '{{.ID}}' | wc -l)
    printf "  ${CYAN}%-15s${NC} %s\n" "Images:" "$IMAGES"

    # Docker disk usage
    DOCKER_DISK=$(docker system df --format '{{.Type}}\t{{.Size}}' 2>/dev/null | head -3)
    if [ -n "$DOCKER_DISK" ]; then
        printf "  ${CYAN}%-15s${NC}\n" "Disk Usage:"
        echo "$DOCKER_DISK" | while read type size; do
            printf "    ${CYAN}%-12s${NC} %s\n" "$type:" "$size"
        done
    fi
    echo ""

    # Container Details
    if [ "$TOTAL_CONTAINERS" -gt 0 ]; then
        echo -e "${WHITE}${BOLD}📋 CONTAINER DETAILS${NC}"
        echo -e "${SEPARATOR}"

        # Header
        printf "  ${BOLD}%-20s %-15s %-10s %-15s %s${NC}\n" "NAME" "IMAGE" "STATUS" "CPU/MEM" "PORTS"
        echo -e "  ${BLUE}────────────────────────────────────────────────────────────────────────${NC}"

        # Get container stats
        docker ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' | while IFS=$'\t' read name image status ports; do
            # Truncate long names/images
            name_short=$(echo "$name" | cut -c1-18)
            image_short=$(echo "$image" | cut -c1-13)

            # Status color
            STATUS_COLOR=$RED
            STATUS_SHORT="stopped"
            if echo "$status" | grep -q "Up"; then
                STATUS_COLOR=$GREEN
                STATUS_SHORT="running"
            elif echo "$status" | grep -q "Paused"; then
                STATUS_COLOR=$YELLOW
                STATUS_SHORT="paused"
            fi

            # Get CPU/MEM for running containers
            CPU_MEM="-"
            if [ "$STATUS_SHORT" = "running" ]; then
                STATS=$(docker stats --no-stream --format "{{.CPUPerc}}/{{.MemPerc}}" "$name" 2>/dev/null)
                [ -n "$STATS" ] && CPU_MEM="$STATS"
            fi

            # Truncate ports
            ports_short=$(echo "$ports" | cut -c1-20)
            [ ${#ports} -gt 20 ] && ports_short="${ports_short}..."

            printf "  %-20s %-15s ${STATUS_COLOR}%-10s${NC} %-15s %s\n" \
                "$name_short" "$image_short" "$STATUS_SHORT" "$CPU_MEM" "$ports_short"
        done
        echo ""
    fi

    # Docker Compose Projects (if docker-compose is available)
    if command -v docker-compose &> /dev/null || docker compose version &> /dev/null 2>&1; then
        COMPOSE_PROJECTS=$(docker ps --format '{{.Labels}}' | grep -oP 'com.docker.compose.project=\K[^,]+' | sort -u)
        if [ -n "$COMPOSE_PROJECTS" ]; then
            echo -e "${WHITE}${BOLD}📁 COMPOSE PROJECTS${NC}"
            echo -e "${SEPARATOR}"
            echo "$COMPOSE_PROJECTS" | while read project; do
                COUNT=$(docker ps --filter "label=com.docker.compose.project=$project" --format '{{.ID}}' | wc -l)
                printf "  ${CYAN}%-20s${NC} %s containers running\n" "$project:" "$COUNT"
            done
            echo ""
        fi
    fi
}

# Services Status (optional)
print_services_status() {
    echo -e "${WHITE}${BOLD}⚙️  KEY SERVICES${NC}"
    echo -e "${SEPARATOR}"

    SERVICES=("ssh" "docker" "cron" "fail2ban" "ufw")

    for service in "${SERVICES[@]}"; do
        if systemctl list-unit-files | grep -q "^${service}"; then
            STATUS=$(systemctl is-active "$service" 2>/dev/null)
            if [ "$STATUS" = "active" ]; then
                printf "  ${CYAN}%-15s${NC} ${GREEN}●${NC} running\n" "$service:"
            else
                printf "  ${CYAN}%-15s${NC} ${RED}●${NC} stopped\n" "$service:"
            fi
        fi
    done
    echo ""
}

# Footer
print_footer() {
    echo -e "${SEPARATOR}"
    echo -e "${CYAN}  Generated: $(date '+%Y-%m-%d %H:%M:%S') | User: $(whoami)@$(hostname)${NC}"
    echo -e "${SEPARATOR}\n"
}

# Main execution
main() {
    clear
    print_header
    print_system_info
    print_cpu_info
    print_memory_info
    print_disk_info
    print_network_info
    print_docker_info
    print_services_status
    print_footer
}

# Run main function
main
