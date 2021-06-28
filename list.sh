#!/bin/bash
# Includes
SRC_DIR=`dirname "$0"`
. $SRC_DIR/backup.config
#
TARGET="/mnt/$DEST_SERVER"

echo -e "\nThis is an backup archive restore list creator, use this program from the directory you restore to from '$DEST_SERVER'."
echo "To restore from the remote backup, use the list with the restore shell script."
echo "Like: $SRC_DIR/restore.sh ./restore.lst"
echo "To restore from a local drive or mount:"
echo "$SRC_DIR/restore.sh --target=/mnt/$user/samsung   ./restore.lst"
echo -e "Usage: $SRC_DIR/list.sh -keep - With -keep argument a previously created restore.lst will not be deleted.\n" 
[[ "$1" == '-?' || "$1" == '-h' ]] && exit;

if [[ ! -z "$1" && $1 =~ ^--target ]] 
then
    TARGET=$(echo $1 | awk -F= '{print $2}')
    echo -e "[[[$TARGET]]]\n"    
    if [[ ! -d "$TARGET" ]] 
    then
        echo -e "\nTarget doesn't exits: $TARGET"
        echo -e "Available Media:"
        find /media/$USER -maxdepth 2 -type d -print 
        #ls -lr "/media/$USER" |  awk '! /^total|\./ {print}';
        echo -e "\nAvailable Mounts:"
        #ls -lr "/mnt/"|  awk '! /^total|\./ {print}';
        find /mnt/ -maxdepth 2 -type d -print 
        exit 1;
    else
        IS_LOCAL_MOUNT=1
        DEST_SERVER=$THIS_MACHINE
    fi    
fi
if [ -z $IS_LOCAL_MOUNT ]
then
echo "Please enter $THIS_MACHINE's sudo password ->"
sudo sshfs $USER@$DEST_SERVER:backups /mnt/$DEST_SERVER -o allow_other > /dev/null 2>&1
fi
sel=$(xzcat $TARGET/$THIS_MACHINE-*.$EXT_LST | sort -f -i -u | fzf --multi)
[[ -z $sel ]] &&  exit;
[[ -z $1   ]] && rm restore.lst > /dev/null;


for n in $sel
do
      echo $n >> restore.lst
done
      echo -e "\nRestore list contents:"
      cat restore.lst | sort -u | while read n
do 
if [[ -d ~/$n ]]
then
      echo -e "-------------------------------"
      echo -e "Listing found existing dir, selected as: $n";
      ls -laht ~/$n;
      echo -e "-------------------------------"
else
      echo -e "$n"
fi
done

echo -e "Note - existing directories that have been found and listed above." \
"\n During restore can potentialy overwite existing files or leave put, files not found in backup."

exit
# This script originated from https://github.com/wbudic/B_L_R_via_sshfs