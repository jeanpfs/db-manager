#!/usr/bin/env bash
# Builds demo.gif from the VHS recording (session.mp4) and two real psql dumps of the orders table.
# The terminal is on the left; a preview panel on the right is empty first, shows the orders table when the agent
# has read it, and flips order 1042 from pending to paid once the confirmed UPDATE has run. Waiting is sped up.
#
# Before recording, reset the row and dump it:
#   psql "$URL" -c "UPDATE orders SET status='pending' WHERE id=1042"
#   psql "$URL" -At -F'|' -c "SELECT id,status,total FROM orders ORDER BY id" > orders-before.txt
# After the take (the UPDATE has been applied by the agent):
#   psql "$URL" -At -F'|' -c "SELECT id,status,total FROM orders ORDER BY id" > orders-after.txt
# Run in a directory holding session.mp4, orders-before.txt and orders-after.txt.
# Needs ffmpeg, gifsicle and ImageMagick.
set -euo pipefail

T_SHOW=29.5   # second of session.mp4 where the agent shows the pending orders; the panel shows the table then
T_PAID=52.9   # second where the agent reports the UPDATE is done; the panel flips 1042 to paid
FONT="${FONT:-/System/Library/Fonts/Menlo.ttc}"
TITLE="${TITLE:-shop_dev  ·  orders}"

# Panel, 420x720: header + one row per line of the psql dump; pending = yellow, paid = green, refunded = grey.
panel() {  # panel <dump.txt> <out.png> <highlight-row-id> <footer>
  local args=(-size 420x720 xc:'#181825' -font "$FONT" -fill '#a6adc8' -pointsize 15 -annotate +24+40 "$TITLE"
    -stroke '#313244' -strokewidth 1 -draw "line 0,0 0,720" -stroke none
    -fill '#6c7086' -pointsize 14 -annotate +24+90 'id' -annotate +110+90 'status' -annotate +250+90 'total'
    -stroke '#313244' -draw "line 24,102 396,102" -stroke none)
  local y=128 id st tot col
  while IFS='|' read -r id st tot; do
    case "$st" in paid) col='#a6e3a1';; pending) col='#f9e2af';; *) col='#6c7086';; esac
    if [ "$id" = "$3" ]; then args+=(-fill '#313244' -draw "roundrectangle 16,$((y-18)) 404,$((y+8)) 6,6"); fi
    args+=(-fill '#cdd6f4' -pointsize 15 -annotate "+24+$y" "$id" -fill "$col" -annotate "+110+$y" "$st" \
           -fill '#cdd6f4' -annotate "+250+$y" "$tot")
    y=$((y+34))
  done < "$1"
  args+=(-fill '#6c7086' -pointsize 13 -annotate "+24+$((y+30))" "$4" -depth 8 "$2")
  magick "${args[@]}"
}
magick -size 420x720 xc:'#181825' -font "$FONT" -fill '#a6adc8' -pointsize 15 -annotate +24+40 "$TITLE" \
  -fill none -stroke '#45475a' -strokewidth 1.5 -draw "roundrectangle 24,250 396,481 10,10" \
  -stroke none -fill '#585b70' -pointsize 14 -annotate +150+372 'orders' \
  -stroke '#313244' -strokewidth 1 -draw "line 0,0 0,720" -depth 8 panel-empty.png
panel orders-before.txt panel-before.png 1042 'real psql output: order 1042 is pending'
panel orders-after.txt  panel-after.png  1042 'real psql output: UPDATE 1, order 1042 is paid'

# Speed ramp: typing at 1x, the agent's work at 1.5x-5x, the confirmation block at 1x, then hold the answer.
ffmpeg -v error -y -i session.mp4 -loop 1 -framerate 30 -i panel-empty.png -loop 1 -framerate 30 -i panel-before.png \
  -loop 1 -framerate 30 -i panel-after.png \
  -filter_complex "
[1:v]format=rgb24[pe];[2:v]format=rgb24[pb];[3:v]format=rgb24[pa];
[pe][pb]overlay=enable='gte(t,$T_SHOW)'[p1];[p1][pa]overlay=enable='gte(t,$T_PAID)'[panel];
[0:v]format=rgb24[term];
[term][panel]hstack=inputs=2:shortest=1,fps=30[full];
[full]split=10[a][b][c][d][e][f][g][h][i][j];
[a]trim=1.0:4.0,setpts=PTS-STARTPTS[s1];
[b]trim=4.0:14.5,setpts=(PTS-STARTPTS)/4[s2];
[c]trim=14.5:19.0,setpts=(PTS-STARTPTS)/1.5[s3];
[d]trim=19.0:29.0,setpts=(PTS-STARTPTS)/5[s4];
[e]trim=29.0:31.0,setpts=(PTS-STARTPTS)/1.3[s5];
[f]trim=31.0:33.5,setpts=PTS-STARTPTS[s6];
[g]trim=33.5:41.0,setpts=(PTS-STARTPTS)/4[s7];
[h]trim=41.0:46.5,setpts=PTS-STARTPTS[s8];
[i]trim=46.5:53.4,setpts=(PTS-STARTPTS)/3[s9];
[j]trim=53.3:53.4,setpts=PTS-STARTPTS,tpad=stop_mode=clone:stop_duration=3.5[s10];
[s1][s2][s3][s4][s5][s6][s7][s8][s9][s10]concat=n=10:v=1:a=0,fps=12,scale=960:-2:flags=lanczos,split[x][y];
[x]palettegen=max_colors=256:stats_mode=full[p];[y][p]paletteuse=dither=bayer:bayer_scale=3[out]" \
  -map "[out]" demo-raw.gif
gifsicle -O3 --lossy=25 demo-raw.gif -o demo.gif
echo "wrote $PWD/demo.gif"
