#!/bin/bash

# Colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Default values
crop_panel=false
screen_height=2160
panel_height=44

show_usage() {
  echo -e "\n${BOLD}Usage:${NC}"
  echo -e "  ./screenrec [${YELLOW}filename${NC}] [options]"
  echo -e "\n${BOLD}Options:${NC}"
  echo -e "  --crop    Crop out the bottom panel (${panel_height}px)"
  echo -e "\nIf no filename is provided, datetime will be used"
  exit 1
}

# Parse arguments
if [ $# -eq 0 ]; then
  filename="recording_$(date '+%Y%m%d_%H%M%S')"
else
  # Check if first arg is an option
  if [[ $1 == --* ]]; then
    filename="recording_$(date '+%Y%m%d_%H%M%S')"
  else
    filename="$1"
    shift
  fi
fi

# Parse remaining options
while [[ $# -gt 0 ]]; do
  case $1 in
  --crop)
    crop_panel=true
    shift
    ;;
  --help | -h)
    show_usage
    ;;
  *)
    echo -e "${RED}Unknown option: $1${NC}"
    show_usage
    ;;
  esac
done

# Add .mp4 extension if not provided
if [[ ! $filename =~ \.mp4$ ]]; then
  filename="${filename}.mp4"
fi

# Calculate crop if needed
if [ "$crop_panel" = true ]; then
  new_height=$((screen_height - panel_height))
  crop_filter="crop=3840:${new_height}:0:0,scale=1920:1080"
  resolution_text="3840x${screen_height} → 1920x1080 (bottom ${panel_height}px cropped)"
else
  crop_filter="scale=1920:1080"
  resolution_text="3840x${screen_height} → 1920x1080"
fi

# Clear screen
clear

# Show banner
echo -e "${BLUE}╔════════════════════════════════╗${NC}"
echo -e "${BLUE}║      ${GREEN}Screen Recorder${BLUE}           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════╝${NC}"

# Print recording info
echo -e "\n${BOLD}Recording Details:${NC}"
echo -e "📁 Output file: ${GREEN}$filename${NC}"
echo -e "🎥 Resolution: ${GREEN}$resolution_text${NC}"
echo -e "🎤 Audio: ${GREEN}Default microphone (mono)${NC}"
echo -e "⚙️  Quality: ${GREEN}Medium preset, CRF 23${NC}"

# Countdown with cleaner output
echo -e "\n${YELLOW}Starting recording in:${NC}"
for i in {3..1}; do
  echo -e "${YELLOW}$i...${NC}"
  sleep 1
done

echo -e "\n${GREEN}🔴 Recording started! Press ${BOLD}Ctrl+C${NC}${GREEN} to stop...${NC}"

# Start recording with suppressed output
ffmpeg -f x11grab -framerate 30 -video_size 3840x2160 -i :0.0 \
  -f pulse -i default \
  -vf "${crop_filter}" \
  -c:v libx264 -preset medium -crf 23 \
  -c:a aac -b:a 64k -ac 1 \
  -pix_fmt yuv420p "$filename" 2>/dev/null &

pid=$!

# Wait for ffmpeg to finish or be interrupted
wait $pid

# Final message
echo -e "\n${GREEN}✅ Recording saved to: ${BOLD}$filename${NC}"
