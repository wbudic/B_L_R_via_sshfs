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
# LST_ARG=restore.lst and individual files to restore as arguments follow.
LST_ARG=$1;

while [ ! -z "$1" ];do
if [[ $1 =~ ^--target= ]]
then
  TARGET=$(echo $1 | awk -F= '{print $2}')
  echo -e "Target directory set as: $TARGET"
  shift; continue
fi
if [[ $1 =~ ^--gpg-pass= ]]
then
  GPG_PASS=$(echo $1 | awk -F= '{print $2}')
  echo -e "Using gpg-pass: $GPG_PASS"
  shift; continue; 
fi
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
      shift
      echo -e "Target directory set as: $TARGET"          
      continue
      ;;
    *)
        if [[ $1 =~ ^-- ]]; then
          echo -e "Err: Unknow option $1 ignoring it. Try -h|--help?"
          shift;
          continue
        fi

        LST_ARG=$1;
        shift 
    ;;        
esac
done

function showHelp () {
echo -e "--------------------------------------------------------------------------------------------------------------"
echo -e "Backup restore Utility\n\t This utility restores latest backup found in an target directory."
echo -e "The default settings or arguments are set in the backup.config file.\n And the list utility can be used for fast individual file slections. Before calling restore."
echo -e "Other availabe command line options:"
echo -e "-h|--help - For this help."
echo -e "--target {full_path_to_dir} - To select alterneative backup target location."
echo -e "                              Note - BACKUP_DIRECTORY and TARGET config settings will be also ignored."
echo -e "--gpg-pass {the_other_gpg_pass} - To overwrite the pgp_pass setting, found in backup.config."
echo -e "--------------------------------------------------------------------------------------------------------------"
}

[[ ! -d "$TARGET" ]] && "$TARGET=$BACKUP_DIRECTORY/$TARGET" && echo -e "Reseting to: $TARGET"
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
      IS_LOCAL=1
      DEST_SERVER=$THIS_MACHINE
      LA1=$2;LA2=$3;LA3=$4;LA4=$5;
  fi  


#echo -e "Last Argument:[$1]"
if [ -z $IS_LOCAL ]
then
echo -e "\nYour are about to restore from '$USER@$DEST_SERVER:$BACKUP_DIRECTORY'" "Please enter $THIS_MACHINE's sudo password ->"
sudo sshfs "$USER@$DEST_SERVER:$BACKUP_DIRECTORY" $TARGET -o allow_other 
[[ $? -ne 1 ]] && echo -e "Exiting..." && exit 1
fi

BACKUP_FILE=$(ls $TARGET/$THIS_MACHINE-*.$EXT_ENC|tail -n 1)
if [[ -f $BACKUP_FILE ]] 
then
echo -e "\nLocated backup file is -> $BACKUP_FILE"
echo -e "Restore location or target will be -> $PWD\n"
	else
echo "No backup file has been found!"
exit;
fi

if [[ "." = "$SRC_DIR" ]]
then
	echo "Error, you are in the backup source directory: $PWD!"
	exit 1;
fi


function start (){  
  RESTORE_START=`date +%F%t%T`;
  FC=$(awk 'END{print NR}' $LST_ARG);
  echo "Restoring files from [$LST_ARG] ($FC) ..."
  gpg --decrypt --batch --passphrase $GPG_PASS $BACKUP_FILE | pv -N "Status" | tar -Jxv --files-from $LST_ARG
  i#[[ $? != 0 ]] && echo "FATAL ERROR, EXITING RESTORE OF $BACKUP_FILE!\nFatal erros, check if your PGP_PASS is right?" && exit $?;
}

function end (){
  RESTORE_END=`date +%F%t%T`;
  RESTORE_TIME=`dateutils.ddiff -f "%H hours and %M minutes %S seconds" "$RESTORE_START" "$RESTORE_END" \
  | awk '{gsub(/^0 hours and/,"");}1' | awk '{gsub(/^\s*0 minutes\s*/,"");}1'`
  echo -e "\nRestore started : $RESTORE_START"
  echo -e "Restore ended   : $RESTORE_END"
  echo -e "Restore took    : $RESTORE_TIME"
  echo -e "Done with restore from: $BACKUP_FILE\nHave a nice day!"
}

##

#echo -e "LST_ARG=$LST_ARG"

if [[ -z $LST_ARG || ! -f $LST_ARG ]]
then
	echo -e "No valid list of files has been provided as argument,\nShould next the whole backup be restored into the '$PWD' directory."
	read -p "Are you sure you want to proceed? (Answer Yes/No): " rep; 
	if [[ $rep =~ ^Y|^y ]]
	then
          RESTORE_START=`date +%F%t%T`;
          echo "Restoring whole archive!"
          gpg --decrypt --batch --passphrase $GPG_PASS $BACKUP_FILE | pv -N "Status" | tar -Jxv $LA1 $LA2 $LA3 $LA4 $LA5; 
          [[ $? != 0 ]] && echo -e "\nFatal erros, check if your --gpg-pass is right?" && exit $?;
          end
	else
	     echo "Restore has been skipped."
	     exit 1;
	fi
else 
  start
  end
fi



# This file originated from https://github.com/wbudic/B_L_R_via_sshfs
