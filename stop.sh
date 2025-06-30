#!/usr/bin/env bash
# File: docker-stop-helper.sh
# Usage: sudo ./docker-stop-helper.sh
# Description: Lists running Docker containers (and any bound to TCP/4444),
#              then interactively stops the selected container.

set -euo pipefail
IFS=$'\n\t'

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check for required commands
for cmd in docker lsof; do
  if ! command -v "$cmd" &>/dev/null; then
    echo -e "${RED}Error:${NC} '$cmd' is not installed or not in your PATH."
    exit 1
  fi
done

# Get container listening on port 4444, if any
PORT=4444
echo -e "${YELLOW}Checking for process on port ${PORT}...${NC}"
lsof -iTCP:${PORT} -sTCP:LISTEN -Pn || true

container_on_4444=$(docker ps \
  --filter "publish=${PORT}" \
  --format '{{.ID}}\t{{.Names}}\t{{.Ports}}')

echo
if [[ -n "$container_on_4444" ]]; then
  read -r cid cname cports <<<"$(echo -e "$container_on_4444" | head -n1 | tr '\t' ' ')"
  echo -e "${GREEN}Found container on port ${PORT}:${NC}"
  echo "  ID:    $cid"
  echo "  Name:  $cname"
  echo "  Ports: $cports"
  echo
  read -p "Stop this container? [y/N] " yn
  case "$yn" in
    [Yy]* )
      echo -e "${YELLOW}Stopping $cid ($cname)...${NC}"
      docker stop "$cid"
      echo -e "${GREEN}Stopped.${NC}"
      exit 0
      ;;
    * )
      echo "Okay, you can select a different container below."
      ;;
  esac
else
  echo -e "${YELLOW}No container is publishing port ${PORT}.${NC}"
fi

# List all running containers
echo
echo -e "${YELLOW}Listing all running containers:${NC}"
mapfile -t lines < <(docker ps --format '{{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Ports}}')
if (( ${#lines[@]} == 0 )); then
  echo "  No running containers found."
  exit 0
fi

# Display nicely
printf "%-4s %-12s %-20s %-20s %s\n" "No." "CONTAINER ID" "NAME" "IMAGE" "PORTS"
echo "----------------------------------------------------------------------"
for i in "${!lines[@]}"; do
  IFS=$'\t' read -r id name image ports <<<"${lines[i]}"
  printf "%-4s %-12s %-20s %-20s %s\n" "$((i+1))" "$id" "$name" "$image" "$ports"
done

# Prompt user to choose one
echo
while true; do
  read -p "Enter the number of the container you want to stop (or 'q' to quit): " sel
  [[ "$sel" =~ ^[Qq]$ ]] && echo "Aborted." && exit 0
  if [[ "$sel" =~ ^[0-9]+$ ]] && (( sel >= 1 && sel <= ${#lines[@]} )); then
    idx=$((sel-1))
    IFS=$'\t' read -r cid name _ <<<"${lines[idx]}"
    echo -e "${YELLOW}Stopping $cid ($name)...${NC}"
    docker stop "$cid"
    echo -e "${GREEN}Stopped.${NC}"
    exit 0
  else
    echo -e "${RED}Invalid selection.${NC} Please enter a number between 1 and ${#lines[@]}, or 'q' to quit."
  fi
done
