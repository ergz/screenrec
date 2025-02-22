#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'
BOLD='\033[1m'

# Default values (fallback if config fails)
config_file="screenrec.conf"
profile="default"

# Function to read config
read_config() {
  local profile_name=$1
  local found=false
  output_dir=""
  filename_prefix=""
  crop_panel=""
  screen_height=""
  panel_height=""

  while IFS= read -r line; do
    # Trim whitespace
    line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # Skip empty lines and comments
    [[ -z "$line" || "$line" == \#* ]] && continue

    # Check for profile section
    if [[ "$line" == "[$profile_name]" ]]; then
      found=true
      continue
    elif [[ "$line" == \[*] ]]; then
      found=false
      continue
    fi

    # Read properties if in correct profile
    if [ "$found" = true ]; then
      if [[ "$line" =~ ^output_dir[[:space:]]*=[[:space:]]*(.*)$ ]]; then
        output_dir="${BASH_REMATCH[1]}"
      elif [[ "$line" =~ ^filename_prefix[[:space:]]*=[[:space:]]*(.*)$ ]]; then
        filename_prefix="${BASH_REMATCH[1]}"
      elif [[ "$line" =~ ^crop[[:space:]]*=[[:space:]]*(.*)$ ]]; then
        crop_panel="${BASH_REMATCH[1]}"
      elif [[ "$line" =~ ^screen_height[[:space:]]*=[[:space:]]*(.*)$ ]]; then
        screen_height="${BASH_REMATCH[1]}"
      elif [[ "$line" =~ ^panel_height[[:space:]]*=[[:space:]]*(.*)$ ]]; then
        panel_height="${BASH_REMATCH[1]}"
      fi
    fi
  done <"$config_file"

  # Verify we found the profile and all required settings
  if [ -z "$output_dir" ] || [ -z "$filename_prefix" ] ||
    [ -z "$crop_panel" ] || [ -z "$screen_height" ] || [ -z "$panel_height" ]; then
    echo -e "${RED}Error: Profile '$profile_name' not found or incomplete in $config_file${NC}"
    exit 1
  fi
}

show_usage() {
  echo -e "\n${BOLD}Usage:${NC}"
  echo -e "  ./screenrec [${YELLOW}filename${NC}] [options]"
  echo -e "\n${BOLD}Options:${NC}"
  echo -e "  --profile  Use specific profile from config (default: 'default')"
  echo -e "\nIf no filename is provided, datetime will be used"
  exit 1
}

# Parse arguments (simplified since --crop is now in config)
while [[ $# -gt 0 ]]; do
  case $1 in
  --profile)
    profile="$2"
    shift 2
    ;;
  --help | -h)
    show_usage
    ;;
  *)
    if [ -z "$custom_filename" ]; then
      custom_filename="$1"
      shift
    else
      echo -e "${RED}Unknown option: $1${NC}"
      show_usage
    fi
    ;;
  esac
done

# Read configuration
read_config "$profile"

# Generate filename
datetime=$(date '+%Y%m%d_%H%M%S')
if [ -n "$custom_filename" ]; then
  filename="${custom_filename}_${datetime}"
else
  filename="${filename_prefix}_${datetime}"
fi

# Add .mp4 extension if not provided
if [[ ! $filename =~ \.mp4$ ]]; then
  filename="${filename}.mp4"
fi

# Ensure output directory exists
mkdir -p "$output_dir"
full_path="${output_dir}/${filename}"

# Calculate crop based on config settings
if [ "$crop_panel" = "true" ]; then
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
echo -e "📁 Profile: ${GREEN}$profile${NC}"
echo -e "📁 Output file: ${GREEN}$full_path${NC}"
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
  -c:v libx264 -preset superfast -crf 23 \
  -c:a aac -b:a 64k -ac 1 \
  -pix_fmt yuv420p "$full_path" 2>/dev/null &

pid=$!

# Wait for ffmpeg to finish or be interrupted
wait $pid

# Final message
echo -e "\n${GREEN}✅ Recording saved to: ${BOLD}$full_path${NC}"
