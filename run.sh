#!/bin/bash

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# IP 범위 계산 함수
calculate_ip_range() {
    local subnet=$1
    if [ "$subnet" == "-" ]; then
        echo "-"
        return
    fi
    
    local ip=$(echo $subnet | cut -d'/' -f1)
    local cidr=$(echo $subnet | cut -d'/' -f2)
    
    # IP를 배열로 분리
    IFS='.' read -r -a octets <<< "$ip"
    
    # CIDR에 따른 호스트 수 계산
    local hosts=$((2**(32-$cidr)))
    
    # 시작 IP (보통 .2부터, .1은 게이트웨이)
    local start_ip="${octets[0]}.${octets[1]}.${octets[2]}.2"
    
    # 종료 IP 계산
    case $cidr in
        16)
            end_ip="${octets[0]}.${octets[1]}.255.254"
            ;;
        20)
            # /20 = 4096 IPs, 255.255.240.0 마스크
            local last_octet3=$(( ${octets[2]} + 15 ))
            end_ip="${octets[0]}.${octets[1]}.$last_octet3.254"
            ;;
        24)
            end_ip="${octets[0]}.${octets[1]}.${octets[2]}.254"
            ;;
        *)
            # 기타 CIDR 값에 대한 일반적인 계산
            if [ $cidr -le 24 ]; then
                local range=$((2**(24-$cidr)))
                local last_octet3=$((${octets[2]} + $range - 1))
                end_ip="${octets[0]}.${octets[1]}.$last_octet3.254"
            else
                local range=$((2**(32-$cidr)))
                local last_octet4=$((${octets[3]} + $range - 2))
                end_ip="${octets[0]}.${octets[1]}.${octets[2]}.$last_octet4"
            fi
            ;;
    esac
    
    echo "$start_ip ~ $end_ip"
}

echo -e "${BLUE}${BOLD}══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}${BOLD}                                                                     Docker Network Full Report                                                                                                  ${NC}"
echo -e "${BLUE}${BOLD}══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════${NC}"
echo ""

# Docker 기본 브릿지 네트워크 정보
bridge_subnet=$(docker network inspect bridge --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null)
bridge_gateway=$(docker network inspect bridge --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null)
bridge_containers=$(docker network inspect bridge --format '{{len .Containers}}' 2>/dev/null)

if [ -n "$bridge_subnet" ]; then
    echo -e "${CYAN}Docker Default Bridge Network:${NC}"
    printf "${BOLD}bridge${NC}         : Default bridge network for containers\n"
    printf "    ├─ Subnet: ${GREEN}%-20s${NC} Gateway: ${GREEN}%-15s${NC} Containers: ${GREEN}%s${NC}\n" "$bridge_subnet" "$bridge_gateway" "$bridge_containers"
    printf "    └─ IP Range: ${CYAN}%s${NC}\n" "$(calculate_ip_range $bridge_subnet)"
    echo ""
fi

# 전체 요약
total_networks=$(docker network ls -q | wc -l)
total_containers=$(docker ps -aq | wc -l)
running_containers=$(docker ps -q | wc -l)
stopped_containers=$(docker ps -aq -f status=exited | wc -l)

echo -e "${CYAN}Summary:${NC}"
echo -e "  Total Networks: ${GREEN}$total_networks${NC}"
echo -e "  Total Containers: ${GREEN}$total_containers${NC} (Running: ${GREEN}$running_containers${NC} | Stopped: ${RED}$stopped_containers${NC})"
echo ""

# 네트워크 요약 표
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
printf "${BOLD}%-35s %-18s %-22s %-18s %-35s %-12s %-12s${NC}\n" \
    "NETWORK NAME" "ID" "SUBNET" "GATEWAY" "IP RANGE" "CONTAINERS" "DRIVER"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# 네트워크 정보 수집 및 표시
docker network ls --format '{{.ID}}' | while read net_id; do
    name=$(docker network inspect $net_id --format '{{.Name}}')
    driver=$(docker network inspect $net_id --format '{{.Driver}}')
    subnet=$(docker network inspect $net_id --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}')
    gateway=$(docker network inspect $net_id --format '{{range .IPAM.Config}}{{.Gateway}}{{end}}')
    container_count=$(docker network inspect $net_id --format '{{len .Containers}}')
    
    # 기본값 설정
    [ -z "$subnet" ] && subnet="-"
    [ -z "$gateway" ] && gateway="-"
    
    # IP 범위 계산
    ip_range=$(calculate_ip_range "$subnet")
    
    # 컨테이너 수에 따라 색상 적용
    if [ "$container_count" -gt 0 ]; then
        printf "${GREEN}%-35s${NC} %-18s %-22s %-18s ${CYAN}%-35s${NC} ${GREEN}%-12s${NC} %-12s\n" \
            "$name" "${net_id:0:12}" "$subnet" "$gateway" "$ip_range" "$container_count" "$driver"
    else
        printf "%-35s %-18s %-22s %-18s %-35s %-12s %-12s\n" \
            "$name" "${net_id:0:12}" "$subnet" "$gateway" "$ip_range" "$container_count" "$driver"
    fi
done

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 컨테이너 상세 정보 (상태 포함)
echo -e "${CYAN}${BOLD}Container Details with Status:${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
printf "${BOLD}%-35s %-35s %-15s %-22s %-10s %-15s${NC}\n" \
    "NETWORK" "CONTAINER" "STATUS" "IP ADDRESS" "PORTS" "UPTIME"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# 모든 컨테이너 (실행 중 + 정지)의 네트워크 정보 수집
docker ps -aq | while read container_id; do
    # 컨테이너 정보 가져오기
    container_name=$(docker inspect $container_id --format '{{.Name}}' | sed 's/^\/\///')
    container_state=$(docker inspect $container_id --format '{{.State.Status}}')
    container_uptime=$(docker inspect $container_id --format '{{.State.Status}}')
    
    # 컨테이너가 실행 중일 때만 uptime 표시
    if [ "$container_state" == "running" ]; then
        container_uptime=$(docker ps -f id=$container_id --format '{{.Status}}' | sed 's/Up //')
    else
        container_uptime="-"
    fi
    
    # 포트 매핑 정보
    ports=$(docker port $container_id 2>/dev/null | head -1 | cut -d' ' -f3 | cut -d':' -f2)
    [ -z "$ports" ] && ports="-"
    
    # 네트워크 정보
    docker inspect $container_id --format '{{range $net, $conf := .NetworkSettings.Networks}}{{$net}}|{{$conf.IPAddress}}|{{end}}' | \
    tr '|' '\n' | grep -v '^$' | \
    while IFS= read -r network && IFS= read -r ip; do
        [ -z "$ip" ] && ip="-"
        
        # 상태에 따른 색상 적용
        case "$container_state" in
            "running")
                status_color="${GREEN}"
                status_text="● Running"
                ;;
            "exited"|"stopped")
                status_color="${RED}"
                status_text="○ Stopped"
                ;;
            "paused")
                status_color="${YELLOW}"
                status_text="⏸ Paused"
                ;;
            "restarting")
                status_color="${MAGENTA}"
                status_text="↻ Restarting"
                ;;
            *)
                status_color="${NC}"
                status_text="? $container_state"
                ;;
        esac
        
        printf "%-35s %-35s ${status_color}%-15s${NC} %-22s %-10s %-15s\n" \
            "${network:0:35}" "${container_name:0:35}" "$status_text" "$ip" "$ports" "$container_uptime"
    done
done

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"