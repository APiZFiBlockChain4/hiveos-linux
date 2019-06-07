#!/usr/bin/env bash

#######################
# Functions
#######################

get_cards_hashes(){ 
#                                      5                  9                  13
# [I 20:24:28] SushiMiner: Hashrate: 207.3 kH/s | GPU0: 107.0 kH/s | GPU1: 100.3 kH/s
  local hs_line=$(cat $log_name | tail -n 50 | grep "GPU" | tail -n 1)

  khs=$(echo $hs_line | cut -d " " -f 5)

  hs=
  for (( i=0; i < ${GPU_COUNT}; i++ )); do
    hs+=$(echo $hs_line | cut -d " " -f $(expr 9 + 4 \* $i))" "
  done
}

get_miner_uptime(){
  ps -o etimes= -C $MINER_NAME | awk '{print $1}'
}

get_log_time_diff(){
  local a=0
  let a=$(date +%s)-$(stat --format='%Y' $log_name)
  echo $a
}


#######################
# MAIN script body
#######################

stats=""
khs=0

local log_name="/var/log/miner/sushi-miner-opencl/sushi-miner-opencl.log"

if [[ -f $log_name ]]; then

  # Calculate log freshness
  local diffTime=$(get_log_time_diff)
  local maxDelay=60

  # If log is fresh the calc miner stats or set to null if not
  if [ "$diffTime" -lt "$maxDelay" ]; then

    local temp=
    local fan=
    local ac=0
    local rj=0
    local ver=$(miner_ver)

    [[ -z $GPU_COUNT_NVIDIA ]] &&
      GPU_COUNT_NVIDIA=$(gpu-detect NVIDIA)
    [[ -z $GPU_COUNT_AMD ]] &&
      GPU_COUNT_AMD=$(gpu-detect AMD)
    GPU_COUNT=$(expr $GPU_COUNT_NVIDIA + $GPU_COUNT_AMD)

        # Per-card hashes array
        get_cards_hashes
        # Hashes units
        local hs_units='khs'
        # Get temp and fan of GPUs from $gpu_stats
        local temp=$(jq -c "[.temp$nvidia_indexes_array]" <<< $gpu_stats)
        local fan=$(jq -c "[.fan$nvidia_indexes_array]" <<< $gpu_stats)
        # Miner uptime
        local uptime=$(get_miner_uptime)
        # Mining algorithm
        local algo="argon2d-nim"

        # Amount of A/R shares (by pool)
        local ac=$(cat $log_name | grep -c "Found share")
        local rj=$(cat $log_name | grep -c "invalid share")

        # create JSON
        stats=$(jq -nc \
                   --argjson hs "`echo ${hs[@]} | tr " " "\n" | jq -cs '.'`" \
                   --arg hs_units "$hs_units" \
                   --argjson temp "$temp" \
                   --argjson fan "$fan" \
                   --arg uptime "$uptime" \
                   --arg ac "$ac" \
                   --arg rj "$rj" \
                   --arg algo "$algo" \
                   --arg ver "$ver" \
                   '{$hs, $hs_units, $temp, $fan, $uptime, ar: [$ac, $rj], $algo, $ver}')
  fi
fi

