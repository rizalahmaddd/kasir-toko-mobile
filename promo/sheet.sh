#!/bin/bash
# sheet.sh out.png t1 t2 t3 t4 → contact sheet of preview shots
out=$1; shift
args=(); f=""; i=0
for t in "$@"; do args+=(-i "shots/t_$(printf %.2f $t).png"); f+="[$i]"; i=$((i+1)); done
ffmpeg -loglevel error -y "${args[@]}" -filter_complex "${f}hstack=$i,scale=$((i*400)):-1" "shots/$out"
