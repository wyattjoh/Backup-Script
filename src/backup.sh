#     Copyright 2011 Wyatt Johnson
#     All Rights Reserved.
#
#     This program is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 3 of the License, or
#     (at your option) any later version.
# 
#     This program is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
# 
#     You should have received a copy of the GNU General Public License
#     along with this program.  If not, see <http://www.gnu.org/licenses/>.
#!/bin/bash

#	Wyatt's Handy Local Backup Script
#	Version 1.20

echoerror() { echo "$@" 1>&2; }

print_error() {
  DATESTAMP="< $(date "+"%B" "%e", "%Y", "%r) > ERROR: "
#  COLOR_RED_BOLD="$(tty -s && tput bold)""$(tty -s && tput setaf 1)"
#  COLOR_RESET="$(tty -s && tput sgr0)"
#  printf $COLOR_RED_BOLD"$DATESTAMP""$*"$COLOR_RESET" \n"
  printf "$DATESTAMP""$*""\n" 1>&2
}
print_warning() {
  DATESTAMP="< $(date "+"%B" "%e", "%Y", "%r) > Warning: "
 # COLOR_YELLOW_BOLD="$(tty -s && tput bold)""$(tty -s && tput setaf 3)"
 # COLOR_RESET="$(tty -s && tput sgr0)"
 # printf $COLOR_YELLOW_BOLD"$DATESTAMP""$*"$COLOR_RESET" \n"
  printf "$DATESTAMP""$*""\n"
}
print_blue() {
  DATESTAMP="[ $(date "+"%B" "%e", "%Y", "%r) ] "
#  COLOR_BLUE="$(tty -s && tput setaf 4)"
#  COLOR_RESET="$(tty -s && tput sgr0)"
#  printf $COLOR_BLUE"$DATESTAMP""$*"$COLOR_RESET" \n"
  printf "$DATESTAMP""$*""\n"
}

#Checks to see if there is at least 1 command line argument, if there is not, then exit and print $USAGE
USAGE='\nUsage.. backup.sh [Location] [Name] [Days Old]\n
Location:\tLocation of the local backup source\n
Name:\t\tName of the backup source (basename location default)\n
Days Old:\tAmount of days before old backups are deleted (10 default)'
[[ $# -lt 1 ]] && print_error $USAGE && exit

### Parse Options ###

#What to backup?
LOCATION=${1}

NAME=${2-$(basename $LOCATION)}

Days_old=${3:-10}
###	###	###

#	Location of the TAR File and Log
HOME_DIR="$HOME"
BACKUP_DIRECTORY="$HOME_DIR""/.backups"
LOG_GLOBAL="$BACKUP_DIRECTORY""/""Backup_Log.txt"
BACKUP_DIRECTORY_NAME="$BACKUP_DIRECTORY""/""$NAME"
LOG_LOCAL="$BACKUP_DIRECTORY_NAME""/""$NAME""_Backup_Log.txt"
BACKUP_DIRECTORY_NAME_DATE="$BACKUP_DIRECTORY_NAME""/""$(date +%d%m%Y)"
BACKUP_TAR_NAME="$NAME""_""$(date +%d%m%Y)""_Backup.tar.bz2"
BACKUP_TAR_FILE="$BACKUP_DIRECTORY_NAME_DATE""/""$BACKUP_TAR_NAME"
INVENTORY="$BACKUP_DIRECTORY_NAME_DATE/File Listing.txt"


#	The Untar Bash Script preparations
UNTAR_SCRIPT_FILE="$BACKUP_DIRECTORY_NAME_DATE""/Restore_Backup.sh"

lock_ini() {
##################################################
### Locking and Initialization  ##################
##################################################

# lock dirs/files
LOCK=`basename $0`
LOCK=${LOCK%.*}
LOCKDIR="/tmp/${LOCK}-lock"
PIDFILE="${LOCKDIR}/PID"

# exit codes and text for them - additional features nobody needs :-)
ENO_SUCCESS=0; ETXT[0]="SUCCESS"
ENO_GENERAL=1; ETXT[1]="GENERAL"
ENO_LOCKFAIL=2; ETXT[2]="LOCKFAIL"
ENO_RECVSIG=3; ETXT[3]="RECVSIG"

###
### start locking attempt
###

trap 'ECODE=$?; echo "[lockgen] Exit: ${ETXT[ECODE]}($ECODE)" >&2' 0
echo -n "[lockgen] Locking: "

if mkdir "${LOCKDIR}" &>/dev/null; then

# lock succeeded, install signal handlers before storing the PID just in case 
# storing the PID fails
trap 'ECODE=$?;
echo "[lockgen] Removing lock. Exit: ${ETXT[ECODE]}($ECODE)"
rm -rf "${LOCKDIR}"' 0
echo "$$" >"${PIDFILE}" 
# the following handler will exit the script on receiving these signals
# the trap on "0" (EXIT) from above will be triggered by this trap's "exit" command!
trap 'echo "[lockgen] Killed by a signal." >&2
exit ${ENO_RECVSIG}' 1 2 3 15
echo "success, installed signal handlers [$LOCKDIR]"

# sucessfull locking completed

#   Execute based on options


else

# lock failed, now check if the other PID is alive
OTHERPID="$(cat "${PIDFILE}")"

# if cat wasn't able to read the file anymore, another instance probably is
# about to remove the lock -- exit, we're *still* locked
if [ $? != 0 ]; then
echo "lock failed, PID ${OTHERPID} is active" >&2
exit ${ENO_LOCKFAIL}
fi

if ! kill -0 $OTHERPID &>/dev/null; then
# lock is stale, remove it and restart
echo "removing stale lock of nonexistant PID ${OTHERPID}" >&2
rm -rf "${LOCKDIR}"
echo "[lockgen] restarting myself" >&2
exec "$0" "$@"
else
# lock is valid and OTHERPID is active - exit, we're locked!
echo "lock failed, PID ${OTHERPID} is active" >&2
exit ${ENO_LOCKFAIL}
fi

fi
}

#	Start function declerations
clean_files() {
  for files in $*;
  do
    [[ ! -e "$files" ]] && continue
    rm $files
    gen_files $files
  done
}
verify() {	#	Added to verity the path to the $* directory before proceeding
  [[ ! -e "$*" ]] && print_error "Folder $* does not exist" &&print_error $USAGE && exit
}
gen_folder() {
go() {
[[ ! -e "$1" ]] && mkdir -p "$1" && verify $1
}
  for folder in $*;
  do
    go $folder &
  done

  wait
}
gen_files() {
go() {
[[ ! -e "$1" ]] && touch "$1" && verify "$1"
}
  for files in $*;
  do
    go $files &
  done

  wait
}
restore_script() {

cat > $UNTAR_SCRIPT_FILE <<EOF
    #!/bin/bash 
    CURRENTDIR=\$(pwd)
    COLOR_RED_BOLD="\$(tty -s && tput bold)""\$(tty -s && tput setaf 1)"
    COLOR_RESET="\$(tty -s && tput sgr0)"
    [[ ! -e "$BACKUP_TAR_FILE" ]] && printf "\$COLOR_RED_BOLD ERROR: The Following TAR File that you are trying to restore does not exist! \n\t$BACKUP_TAR_FILE\nMake sure that the backup TAR is located in the following directory:\n\t$LOCATION\n\$COLOR_RESET" && exit
    echo "ATTENTION! The file $BACKUP_TAR_NAME will override files in the following directory"
    echo "$LOCATION"
    read -p "Continue? [y/n]"
    [ "\$REPLY" == y* ] || exit 
    tar -xzvf "\$CURRENTDIR/$BACKUP_TAR_NAME" -C /
EOF

  chmod u=x $UNTAR_SCRIPT_FILE
}
gen_prereq() {
  verify $HOME_DIR
  gen_folder $BACKUP_DIRECTORY_NAME_DATE
  gen_files $LOG_GLOBAL $LOG_LOCAL
  clean_files $INVENTORY $UNTAR_SCRIPT_FILE
  [[ ! -e "$UNTAR_SCRIPT_FILE" ]] && restore_script
}
start_logging() {
  (print_blue "$NAME Backup: backup has started on $(date "+"%B" "%e", "%Y", "%r)" 2>&1) | tee -a "$LOG_GLOBAL" | tee -a "$LOG_LOCAL"
}
end_log() {
  (print_blue "$NAME Backup: $NAME backup has finished on $(date "+"%B" "%e", "%Y", "%r)" 2>&1) | tee -a "$LOG_GLOBAL" | tee -a "$LOG_LOCAL"
}
cleanup_logs() {
  for l in $*
  do
    TEMPFILE="/tmp/backup-"$$

    trap 'rm $TEMPFILE; exit;' INT TERM

    COUNTER=$(wc -l < "$l" )
    if [[ $COUNTER -gt "300" ]]; then
      tail --lines=250 "$l" > TEMPFILE
      mv TEMPFILE "$l"
      (print_warning "$LOGNAME $l Logfile Cleaned" 2>&1) | tee -a "$LOG_GLOBAL" | tee -a "$LOG_LOCAL"
      else
	[[ -e "$TEMPFILE" ]] && rm $TEMPFILE
    fi
	[[ -e "$TEMPFILE" ]] && rm $TEMPFILE && trap - INT TERM
  done
}
check_backup_and_warn() {
  DATESTAMP=$(date "+"%B" "%e", "%Y", "%r)
  DATESTAMPS=$(date "+"%B" "%e)
  old_IFS=$IFS
  IFS=$'\n'

  for files in "$@"
  do
  if [[ -e "$files" ]]; then
    LOG_LINES=`cat $LOG_LOCAL`
    FOUND=(`echo "${LOG_LINES[*]}" | grep "$DATESTAMPS"`)

    if [[ "${#FOUND[*]}" -gt 0 ]]; then
      (print_warning "$(basename $files) already exists, will override." && rm "$files" 2>&1) | tee -a "$LOG_GLOBAL" | tee -a "$LOG_LOCAL"
    else
      echo "$(basename $files) already exists and no logs were created... will stop for today." && exit
    fi
  fi
  done
  
  IFS=$old_IFS
}
func_log() {
  DATESTAMP=$(date "+"%B" "%e", "%Y", "%r)
  for log in "$@"
  do
    (print_blue "$log" 2>&1) | tee -a "$LOG_GLOBAL" | tee -a "$LOG_LOCAL"
  done
}
inventory() {
 DATESTAMP=$(date "+"%B" "%e", "%Y", "%r)
 IFS=$'\n'
 printf "File Listing of Backup Directory as of $DATESTAMP\n\n" > "$INVENTORY"
 for files in $(find $* -maxdepth 0); do
	[[ -d "${files}" ]] && echo -e "$files/" >> "$INVENTORY" && continue
	echo -e "${files}" >> "$INVENTORY"
 done
}
backup() {
  gen_prereq	# Generate the backups prerequisites
  check_backup_and_warn $BACKUP_TAR_FILE

  start_logging &
  inventory "$LOCATION*" &
  wait

  TAR_LOG=`tar -cjhf "$BACKUP_TAR_FILE" "$LOCATION"  2>&1`
  func_log "$TAR_LOG"
  end_log
  chown -R $USER "$BACKUP_DIRECTORY" &
  wait
}
clean_old_backups()	{
find "$BACKUP_DIRECTORY_NAME" -depth -mtime +$Days_old -exec rm -R {} \;
}

#   Lock and ini
lock_ini

#	And...... Backup!
backup &
clean_old_backups &
cleanup_logs $LOG_LOCAL $LOG_GLOBAL &

wait    #   wait until all tasks are completed

exit 0	#	And Quit :)
