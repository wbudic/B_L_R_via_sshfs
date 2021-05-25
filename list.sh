#!/bin/bash
# Includes
SRC_DIR=`dirname "$0"`
. $SRC_DIR/backup.config
#
echo -e "\nThis is an backup archive restore list creator, use this program from the directory you restore to from '$DEST_SERVER'."
echo "To restore from the remote backup, use the list with the restore shell script."
echo "Like: $SRC_DIR/restore.sh ./restore.lst"
echo -e "Usage: $SRC_DIR/list.sh -keep - With -keep argument a previously created restore.lst will not be deleted.\n" 
[[ "$1" == '-?' ]] && exit;

echo "Please enter $THIS_MACHINE's sudo password ->"
sudo sshfs $USER@$DEST_SERVER:backups /mnt/$DEST_SERVER -o allow_other > /dev/null 2>&1

sel=$(ls -lah /mnt/$DEST_SERVER/$THIS_MACHINE-*.lst| awk -F " " '{printf $9}' | xargs cat |sort -f -i -u | fzf --multi)
[[ -z $sel ]] &&  exit;
[[ -z $1   ]] && rm restore.lst > /dev/null;
for f in $sel
do
      echo $f >> restore.lst
done
echo "Restore list contents:"
cat restore.lst | sort -u
#
exit
