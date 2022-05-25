#!/bin/bash
# Includes
SRC_DIR=`dirname "$0"`
if [[ -f ~/.config/backup.config ]]; then
CONFIG_FILE="$HOME/.config/backup.config"
else
CONFIG_FILE="$SRC_DIR/backup.config"
fi 
. $CONFIG_FILE
#
echo -e "\n--------------------------------------------------------------------------------------------------------------"
echo -e "This is an backup archive restore list creator, use this program from the directory you restore to locally."
echo -e "Backup location is DEST_SERVER='$DEST_SERVER'"
echo -e "Restore location is PWD='`pwd`'"
echo -e "--------------------------------------------------------------------------------------------------------------"
echo -e "Syntax: $0 {-target=/some/path} {-keep} {restore.lst}\n"
echo "After listing, to restore from the backup, use the list with the restore shell script."
echo "Like: $SRC_DIR/restore.sh ./restore.lst"
echo "To restore from a local drive or mount:"
echo "$SRC_DIR/restore.sh --target=/mnt/$user/samsung  ./restore.lst"
echo -e "Usage: $0 -keep - With -keep option so an previously created default named restore.lst will not be deleted.\n" 
[[ "$1" == '-?' || "$1" == '-h' ]] && exit;

echo -e "Processing from config: $CONFIG_FILE"
if [[ ! -z "$1" && $1 =~ ^--target ]] 
then
    TARGET=$(echo $1 | awk -v bd="$BACKUP_DIRECTORY" -F= '{print $2"/"bd}')
    echo -e "[[[$TARGET]]]\n"
    if [[ ! -d "$TARGET" ]] 
    then
        echo -e "\nTarget location doesn't exits: $TARGET"
        echo -e "Available Media:"
        find /media/$USER -maxdepth 2 -type d -print         
        echo -e "\nAvailable Mounts:"
        find /mnt/ -maxdepth 2 -type d -not -path '*/\.*' -print
        exit 1
    else
        IS_LOCAL=1
        DEST_SERVER=$THIS_MACHINE
    fi    
fi
if [[ -z $IS_LOCAL ]];
then
[[ ! -d "$TARGET" ]] && echo "Exiting mount point not setup!" && exit 1
echo -e "Accessing  -> $USER@$DEST_SERVER:$BACKUP_DIRECTORY"
sudo sshfs "$USER@$DEST_SERVER:$BACKUP_DIRECTORY" $TARGET -o allow_other > /dev/null 2>&1
fi

INDEX=$(sudo ls -lh $TARGET/$THIS_MACHINE-*.$EXT_LST);
if [[ -z $INDEX ]]
then
echo -e "FAILED to access target backup directory!\n"
exit 0
fi
sel=$(xzcat $TARGET/$THIS_MACHINE-*.$EXT_LST | sort -f -i -u | fzf --multi --header "Listing: $INDEX Config: $CONFIG_FILE")
[[ -z $sel ]] &&  exit;
#Delete previous restore.lst unless we have arguments.
[[ -z $1   ]] && rm restore.lst > /dev/null;


for n in $sel
do
  echo $n >> restore.lst
done
echo -e "Restore list contents check:"

# Following is an good example why uvars are needed, bash can only forward $variables to spawn shells global variables.
# This is what we are doing with the following statment. Or we could write this whole and other scripts in perl? :)
cat restore.lst | sort -u | while read n
do 
      #Display exisiting directory if selected.
      if [[ -d ~/$n ]]
      then
            echo -e "-------------------------------"            
            echo -e "Warning found local dir in path, selected as: $n"
            ls -laht ~/$n
            echo -e "-------------------------------"
            ~/uvar.sh -s /var/tmp -n BCK_LST_CHK -v 1
      else
            echo -e "$n"
      fi
done

if [[ $(~/uvar.sh -s /var/tmp -r "BCK_LST_CHK") -eq 1 ]]
then 
echo -e "Warning - existing directories that have been found and listed above." \
"\n During an restore are not synched, this will overwite existing local files or leave unneeded files."
~/uvar.sh -d "BCK_LST_CHK" > /dev/null
fi

exit
# This script originated from https://github.com/wbudic/B_L_R_via_sshfs
# Required uvar.sh be installed in home directory, located at: https://github.com/wbudic/wb-shell-scripts