#!/bin/bash
# Includes
SRC_DIR=`dirname "$0"`
. $SRC_DIR/backup.config
#
echo -e "\nThis is an backup archive restore list creator, use this program from the directory you restore to from '$DEST_SERVER'."
echo "To restore from the remote backup, use the list with the restore shell script."
echo "Like: $SRC_DIR/restore.sh ./restore.lst"
echo -e "Usage: $SRC_DIR/list.sh -keep - With -keep argument a previously created restore.lst will not be deleted.\n" 
[[ "$1" == '-?' || "$1" == '-h' ]] && exit;

echo "Please enter $THIS_MACHINE's sudo password ->"
sudo sshfs $USER@$DEST_SERVER:backups /mnt/$DEST_SERVER -o allow_other > /dev/null 2>&1
sel=$(xzcat /mnt/$DEST_SERVER/$THIS_MACHINE-*.$EXT_LST | sort -f -i -u | fzf --multi)
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
"\n During restore can potentialy overwite existing files or leave put does not found in backup."

exit
# This file originated from https://github.com/wbudic/B_L_R_via_sshfs