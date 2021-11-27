#!/bin/bash
# Includes
SRC_DIR=`dirname "$0"`
. $SRC_DIR/backup.config
#
TARGET="/mnt/$DEST_SERVER"
# LST_ARG=restore.lst and individual files to restore as arguments follow.
LST_ARG=$1;LA1=$2;LA2=$3;LA3=$4;LA4=$5;

function showHelp () {
echo -e "--------------------------------------------------------------------------------------------------------------"
echo -e "Backup restore Utility\n\t This utility restores latest backup found in the target directory."
echo -e "The default settings or arguments are set in the backup.config file.\n And the list utility can be used for fast individual file slections. Before calling restore."
echo -e "Other availabe command line options:"
echo -e "-h|--help - For this help."
echo -e "--target {path_to_dir} - To select alterneative backup target location."
echo -e "--gpg-pass {the_other_gpg_pass} - To overwrite the pgp_pass setting, found in backup.config."
echo -e "--------------------------------------------------------------------------------------------------------------"
}

while [ ! -z "$1" ];do
   case "$1" in
        -h|--help)
          showHelp; exit
          ;;
        --gpg-pass)
          shift
          GPG_PASS="$1"
          echo -e "Using gpg-pass: $GPG_PASS"
          ;;
        --target)
          shift
          TARGET="$1"
          echo -e "Target directory set as: $TARGET"
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
                LST_ARG=$2;LA1=$3;LA2=$4;LA3=$5;LA4=$6;
            fi 
            break
          ;;
        *)
        [[ $1 =~ ^-- ]] && echo -e "Unknow option $1" 
   esac
shift
done


if [ -z $IS_LOCAL_MOUNT ]
then
echo -e "\nYour are about to restore from '$DEST_SERVER'" "Please enter $THIS_MACHINE's sudo password ->"
sudo sshfs "$USER@$DEST_SERVER:backups" $TARGET -o allow_other 
fi

RESTORE_FILE=$(ls $TARGET/$THIS_MACHINE-*.$EXT_ENC|tail -n 1)
if [[ -f $RESTORE_FILE ]] 
then
echo "Located backup file is -> $RESTORE_FILE"
	else
echo "No backup file has been found!"
exit;
fi

if [[ "." = "$SRC_DIR" ]]
then
	echo "Error, you are in the backup source directory: $PWD!"
	exit 1;
fi

##
if [[ -z $LST_ARG ]]
then
	echo -e "No list of files has been provided, the whole backup will be restored into '$PWD' directory."
	read -p "Are you sure you want to proceed? (Answer Yes/No): " rep; 
	if [[ $rep =~ ^Y|^y ]]
	then
          gpg --decrypt --batch --passphrase $GPG_PASS $RESTORE_FILE | pv -N "Status" | tar -Jxv $LA1 $LA2 $LA3 $LA4 $LA5; 
	else
	     echo "Restore has been skipped.";
	     exit 1;
	fi
else 
echo "Restoring files from $LST_ARG..."
gpg --decrypt --batch --passphrase $GPG_PASS $RESTORE_FILE | pv -N "Status" | tar xvJ --files-from $LST_ARG $LA1 $LA2 $LA3 $LA4 $LA5; 
echo -e "done with restore from:\n $RESTORE_FILE\nOn:" `date` ", have a nice day!"
fi

# This file originated from https://github.com/wbudic/B_L_R_via_sshfs
