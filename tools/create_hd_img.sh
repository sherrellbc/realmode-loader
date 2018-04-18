#!/bin/bash

NAME=$1
DISK_SIZE=1024*1024*50
SECTOR_SIZE=512
START_SECTOR=2048
END_SECTOR=$(($DISK_SIZE/$SECTOR_SIZE - 1))

# Create the formatted disk
dd if=/dev/zero of=$NAME bs=1M count=50
echo -e "o\nn\np\n1\n$START_SECTOR\n$END_SECTOR\nt\n7\na\n1\nw\n" | fdisk -b$SECTOR_SIZE -H255 -S63 $NAME

# Add our MBR, Stage1 and Stage2 payloads
# We have 512 bytes total less:
#   6 byte disk signature (offset 0x1b8)
#   4 partition entries, 16 byets each (0offset 0x1be)
#   2 byte boot signature (offset 0x1fe)
dd if=rml_mbr.bin of=$NAME conv=notrunc bs=1 count=$((512 - 6 - 4*16 - 2 ))
dd if=rml_s1.bin  of=$NAME conv=notrunc bs=1 seek=$(($START_SECTOR*512)) count=512
dd if=rml_s2.bin  of=$NAME conv=notrunc bs=1 seek=$((($START_SECTOR + 1)*512)) count=$((512*16)) ## TODO: Fix 16 sector hardcode here (need size on disk)
