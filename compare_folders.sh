#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

###############################################################################
# Konfigurasiyon - Source və Destination Folderlar
###############################################################################
SOURCE_FOLDERS=(
    "./folder1"
    "./folder2"
)

DESTINATION_FOLDER="./destination"
OUTPUT_LOG_PATH="compare_log.txt"
MIN_DEPTH=1
MAX_DEPTH=1

# Rənglər
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

error_exit() {
  echo -e "${RED}Error: $1${NC}" >&2
  exit 1
}

safe_du_size() {
  local path="$1"
  local total_size=0
  
  if [[ ! -e "$path" ]]; then
    echo 0
    return
  fi
  
  # stat ilə hər faylın ölçüsünü əldə edirik və cəmləyirik
  while IFS= read -r -d '' file; do
    local size
    # Linux üçün: stat -c %s
    # macOS üçün: stat -f%z
    if size=$(stat -c %s "$file" 2>/dev/null); then
      total_size=$((total_size + size))
    elif size=$(stat -f%z "$file" 2>/dev/null); then
      total_size=$((total_size + size))
    fi
  done < <(find "$path" -type f -print0 2>/dev/null)
  
  printf '%s' "$total_size"
}

# Gather top-level folder sizes under the given root.
# Returns lines of the form: "rel_path size"
gather_folder_sizes() {
  local root="$1"
  local root_abs
  root_abs=$(cd "$root" 2>/dev/null && pwd) || {
    echo "Warning: cannot access $root" >&2
    return
  }

  echo -e "${BLUE}Scanning folder: $root_abs${NC}" >&2

  while IFS= read -r -d '' dir; do
    local rel_path
    rel_path="${dir#$root_abs/}"
    local size
    size=$(safe_du_size "$dir")
    echo "$rel_path $size"
    echo "  scanned: $rel_path -> $size bytes" >&2
  done < <(find "$root_abs" -mindepth "$MIN_DEPTH" -maxdepth "$MAX_DEPTH" -type d -print0 2>/dev/null)
}

# Compare aggregated source sizes against destination sizes and produce log lines.
compare_aggregated_sizes() {
  local -n src_sizes_arrays_ref=$1
  local -n dst_sizes_ref=$2
  local -n src_names_ref=$3
  local entries=()
  declare -A stats=( [TOTAL]=0 [OK]=0 [FAIL]=0 [MISSING]=0 )
  declare -A combined_keys=()

  for idx in "${!src_sizes_arrays_ref[@]}"; do
    local -n sizes="${src_sizes_arrays_ref[$idx]}"
    for rel in "${!sizes[@]}"; do
      combined_keys["$rel"]=1
    done
  done

  for rel in "${!dst_sizes_ref[@]}"; do
    combined_keys["$rel"]=1
  done

  # Sort keys lexicographically
  mapfile -t sorted_keys < <(printf '%s\n' "${!combined_keys[@]}" | sort)

  echo -e "\n${BLUE}Aggregating sizes from all source folders and comparing with destination...${NC}\n" >&2

  for rel_path in "${sorted_keys[@]}"; do
    ((stats[TOTAL]++))
    local aggregated_size=0
    local source_present=false
    for idx in "${!src_sizes_arrays_ref[@]}"; do
      local -n sizes="${src_sizes_arrays_ref[$idx]}"
      if [[ -n ${sizes[$rel_path]+_} ]]; then
        source_present=true
      fi
      aggregated_size=$((aggregated_size + ${sizes[$rel_path]:-0}))
    done

    local dest_size=${dst_sizes_ref[$rel_path]:-}
    local dest_path_str
    if [[ -n ${dst_sizes_ref[$rel_path]+_} ]]; then
      dest_path_str="$rel_path"
    else
      dest_path_str="<missing>"
    fi

    local result
    if [[ -z ${dst_sizes_ref[$rel_path]+_} ]]; then
      result="MISSING_IN_DEST"
      ((stats[MISSING]++))
      dest_size=0
    else
      if [[ $source_present == false ]]; then
        result="MISSING_IN_SOURCE"
        ((stats[MISSING]++))
      elif [[ $aggregated_size -eq $dest_size ]]; then
        result="OK"
        ((stats[OK]++))
      else
        result="FAIL"
        ((stats[FAIL]++))
      fi
    fi

    entries+=("Folder: $rel_path")
    entries+=("Aggregated size from sources: $aggregated_size bytes")
    for idx in "${!src_sizes_arrays_ref[@]}"; do
      local -n sizes="${src_sizes_arrays_ref[$idx]}"
      local source_name=${src_names_ref[$idx]}
      if [[ -n ${sizes[$rel_path]+_} ]]; then
        entries+=("  $source_name: ${sizes[$rel_path]} bytes")
      else
        entries+=("  $source_name: <missing>")
      fi
    done
    entries+=("Destination path: $dest_path_str")
    entries+=("Destination size: $dest_size bytes")
    entries+=("Result: $result")
    entries+=("---")
  done

  printf '%s\n' "${entries[@]}"
  printf 'STATS:%s:%s:%s:%s:%s\n' "${stats[TOTAL]}" "${stats[OK]}" "${stats[FAIL]}" "${stats[MISSING]}" "${#sorted_keys[@]}"
}

write_log() {
  local output_path="$1"
  local start_time="$2"
  local end_time="$3"
  local duration_seconds="$4"
  local total="$5"
  local ok="$6"
  local fail="$7"
  local missing="$8"
  shift 8
  local lines=("$@")

  mkdir -p "$(dirname "$output_path")"
  {
    printf 'Start time: %s\n' "$start_time"
    printf 'End time: %s\n' "$end_time"
    printf 'Duration: %s seconds\n' "$duration_seconds"
    printf '\n'
    for line in "${lines[@]}"; do
      printf '%s\n' "$line"
    done
    printf '\n---\n'
    printf 'Total folders compared: %s\n' "$total"
    printf 'OK: %s\n' "$ok"
    printf 'FAIL: %s\n' "$fail"
    printf 'MISSING: %s\n' "$missing"
  } > "$output_path"

  echo -e "${GREEN}Log written to $output_path${NC}"
}

main() {
  echo -e "\n${BLUE}================================${NC}"
  echo -e "${BLUE}Folder Comparison Script${NC}"
  echo -e "${BLUE}================================${NC}\n"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --min-depth)
        MIN_DEPTH="$2"
        shift 2
        ;;
      --max-depth)
        MAX_DEPTH="$2"
        shift 2
        ;;
      --help|-h)
        echo "Usage: $0 [--min-depth N] [--max-depth N]"
        exit 0
        ;;
      *)
        error_exit "Unknown argument: $1"
        ;;
    esac
  done

  if [[ -z "$MIN_DEPTH" || "$MIN_DEPTH" -lt 1 ]]; then
    error_exit "--min-depth must be an integer >= 1"
  fi
  if [[ -z "$MAX_DEPTH" || "$MAX_DEPTH" -lt "$MIN_DEPTH" ]]; then
    error_exit "--max-depth must be an integer >= --min-depth"
  fi

  if [[ ${#SOURCE_FOLDERS[@]} -eq 0 ]]; then
    error_exit "No source folders configured."
  fi

  for folder in "${SOURCE_FOLDERS[@]}"; do
    if [[ ! -d "$folder" ]]; then
      error_exit "Source folder is not a valid directory: $folder"
    fi
  done

  if [[ ! -d "$DESTINATION_FOLDER" ]]; then
    error_exit "Destination folder is not a valid directory: $DESTINATION_FOLDER"
  fi

  local start_time
  start_time=$(date '+%Y-%m-%d %H:%M:%S')
  local start_epoch
  start_epoch=$(date +%s)
  echo -e "Started at: $start_time\n" >&2

  declare -a source_names=()
  declare -a source_size_vars=()

  for idx in "${!SOURCE_FOLDERS[@]}"; do
    local folder=${SOURCE_FOLDERS[$idx]}
    source_names+=("$(basename "$folder")")
    source_size_vars+=("source_sizes_$idx")
    declare -gA "source_sizes_$idx"
    local -n current_sizes="source_sizes_$idx"

    while IFS= read -r line; do
      local rel
      local size
      rel=${line%% *}
      size=${line#* }
      current_sizes["$rel"]=$size
    done < <(gather_folder_sizes "$folder")
  done

  declare -A dest_sizes=()
  while IFS= read -r line; do
    local rel
    local size
    rel=${line%% *}
    size=${line#* }
    dest_sizes["$rel"]=$size
  done < <(gather_folder_sizes "$DESTINATION_FOLDER")

  local result_lines
  result_lines=$(compare_aggregated_sizes source_size_vars dest_sizes source_names)

  local end_time
  end_time=$(date '+%Y-%m-%d %H:%M:%S')
  local end_epoch
  end_epoch=$(date +%s)
  local duration_seconds=$((end_epoch - start_epoch))

  # Split result_lines into array and remove trailing STATS marker from log lines.
  IFS=$'\n' read -r -d '' -a all_lines < <(printf '%s\0' "$result_lines") || true
  local stats_line="${all_lines[-1]}"
  unset 'all_lines[-1]'

  # Extract stats from STATS line
  # STATS format: STATS:total:ok:fail:missing:count
  local total ok fail missing
  IFS=':' read -r _ total ok fail missing _ <<< "$stats_line"

  write_log "$OUTPUT_LOG_PATH" "$start_time" "$end_time" "$duration_seconds" "$total" "$ok" "$fail" "$missing" "${all_lines[@]}"

  echo -e "${BLUE}================================${NC}"
  echo -e "Finished at: $end_time"
  echo -e "Total duration: $duration_seconds seconds"
  echo -e "Total folders compared: $total, OK: $ok, FAIL: $fail, MISSING: $missing"
  echo -e "${BLUE}================================${NC}\n"
}

main "$@"
