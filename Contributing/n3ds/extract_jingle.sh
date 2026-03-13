#!/bin/bash

shopt -s nullglob
for ROM in *.3ds *.cci; do
    echo "Processing $ROM..."
    OUTPUT="${ROM%.*}.wav"

    3dstool -xvtf cci "$ROM" -0 partition0.cxi --header /dev/null > /dev/null
    3dstool -xvtf cxi partition0.cxi --exefs exefs.bin --exefs-auto-key > /dev/null
    3dstool -xvtfu exefs exefs.bin --exefs-dir exefs_dir/ > /dev/null

    mv exefs_dir/banner.bnr banner.bin

    3dstool -xvtf banner banner.bin --banner-dir banner_dir/ > /dev/null

    # Trim bcwav to the size declared in its header
    python3 -c "
import struct
with open('banner_dir/banner.bcwav','rb') as f:
    data = f.read()
size = struct.unpack('<I', data[12:16])[0]
with open('banner_dir/banner.bcwav','wb') as f:
    f.write(data[:size])
"

    vgmstream-cli banner_dir/banner.bcwav -o "$OUTPUT" > /dev/null

    rm -r partition0.cxi exefs.bin exefs_dir/ banner.bin banner_dir/

   FINAL=$(printf '%s\n' "$OUTPUT" \
    | iconv -f utf-8 -t ascii//TRANSLIT \
    | awk '
   {
    s=$0
    gsub(/\047/, "", s)                 # remove apostrophes
    gsub(/\([^)]*\)/, "", s)            # remove parentheses
    gsub(/ *- */, "-", s)               # normalize dash spacing
    gsub(/ /, "-", s)                   # spaces to dashes
    if (match(s, /\.[^.]+$/)) {         # protect extension
        ext=substr(s,RSTART)
        s=substr(s,1,RSTART-1)
    } else ext=""
    gsub(/\./, "", s)                   # remove other dots
    gsub(/[^A-Za-z0-9-]+/, "", s)       # strip remaining junk
    gsub(/-+/, "-", s)                  # collapse dashes
    gsub(/^-|-$/, "", s)                # trim leading/trailing dashes
    print tolower(s) ext
   }')

[ "$FINAL" != "$OUTPUT" ] && mv -- "$OUTPUT" "$FINAL"

    echo "Saved: $FINAL"
done
