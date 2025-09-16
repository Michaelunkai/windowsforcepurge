#!/bin/sh

PROGRESS_CURR=0
PROGRESS_TOTAL=5250                        

# This file was autowritten by rmlint
# rmlint was executed from: /mnt/f/study/security/encryption/borgmatic/
# Your command line was: rmlint /mnt/wslg

RMLINT_BINARY="/usr/bin/rmlint"

# Only use sudo if we're not root yet:
# (See: https://github.com/sahib/rmlint/issues/27://github.com/sahib/rmlint/issues/271)
SUDO_COMMAND="sudo"
if [ "$(id -u)" -eq "0" ]
then
  SUDO_COMMAND=""
fi

USER='root'
GROUP='root'

STAMPFILE=$(mktemp 'rmlint.XXXXXXXX.stamp')

# Set to true on -n
DO_DRY_RUN=

# Set to true on -p
DO_PARANOID_CHECK=

# Set to true on -r
DO_CLONE_READONLY=

# Set to true on -q
DO_SHOW_PROGRESS=true

# Set to true on -c
DO_DELETE_EMPTY_DIRS=

# Set to true on -k
DO_KEEP_DIR_TIMESTAMPS=

##################################
# GENERAL LINT HANDLER FUNCTIONS #
##################################

COL_RED='[0;31m'
COL_BLUE='[1;34m'
COL_GREEN='[0;32m'
COL_YELLOW='[0;33m'
COL_RESET='[0m'

print_progress_prefix() {
    if [ -n "$DO_SHOW_PROGRESS" ]; then
        PROGRESS_PERC=0
        if [ $((PROGRESS_TOTAL)) -gt 0 ]; then
            PROGRESS_PERC=$((PROGRESS_CURR * 100 / PROGRESS_TOTAL))
        fi
        printf '%s[%3d%%]%s ' "${COL_BLUE}" "$PROGRESS_PERC" "${COL_RESET}"
        if [ $# -eq "1" ]; then
            PROGRESS_CURR=$((PROGRESS_CURR+$1))
        else
            PROGRESS_CURR=$((PROGRESS_CURR+1))
        fi
    fi
}

handle_emptyfile() {
    print_progress_prefix
    echo "${COL_GREEN}Deleting empty file:${COL_RESET} $1"
    if [ -z "$DO_DRY_RUN" ]; then
        rm -f "$1"
    fi
}

handle_emptydir() {
    print_progress_prefix
    echo "${COL_GREEN}Deleting empty directory: ${COL_RESET}$1"
    if [ -z "$DO_DRY_RUN" ]; then
        rmdir "$1"
    fi
}

handle_bad_symlink() {
    print_progress_prefix
    echo "${COL_GREEN} Deleting symlink pointing nowhere: ${COL_RESET}$1"
    if [ -z "$DO_DRY_RUN" ]; then
        rm -f "$1"
    fi
}

handle_unstripped_binary() {
    print_progress_prefix
    echo "${COL_GREEN} Stripping debug symbols of: ${COL_RESET}$1"
    if [ -z "$DO_DRY_RUN" ]; then
        strip -s "$1"
    fi
}

handle_bad_user_id() {
    print_progress_prefix
    echo "${COL_GREEN}chown ${USER}${COL_RESET} $1"
    if [ -z "$DO_DRY_RUN" ]; then
        chown "$USER" "$1"
    fi
}

handle_bad_group_id() {
    print_progress_prefix
    echo "${COL_GREEN}chgrp ${GROUP}${COL_RESET} $1"
    if [ -z "$DO_DRY_RUN" ]; then
        chgrp "$GROUP" "$1"
    fi
}

handle_bad_user_and_group_id() {
    print_progress_prefix
    echo "${COL_GREEN}chown ${USER}:${GROUP}${COL_RESET} $1"
    if [ -z "$DO_DRY_RUN" ]; then
        chown "$USER:$GROUP" "$1"
    fi
}

###############################
# DUPLICATE HANDLER FUNCTIONS #
###############################

check_for_equality() {
    if [ -f "$1" ]; then
        # Use the more lightweight builtin `cmp` for regular files:
        cmp -s "$1" "$2"
        echo $?
    else
        # Fallback to `rmlint --equal` for directories:
        "$RMLINT_BINARY" -p --equal  --no-followlinks "$1" "$2"
        echo $?
    fi
}

original_check() {
    if [ ! -e "$2" ]; then
        echo "${COL_RED}^^^^^^ Error: original has disappeared - cancelling.....${COL_RESET}"
        return 1
    fi

    if [ ! -e "$1" ]; then
        echo "${COL_RED}^^^^^^ Error: duplicate has disappeared - cancelling.....${COL_RESET}"
        return 1
    fi

    # Check they are not the exact same file (hardlinks allowed):
    if [ "$1" = "$2" ]; then
        echo "${COL_RED}^^^^^^ Error: original and duplicate point to the *same* path - cancelling.....${COL_RESET}"
        return 1
    fi

    # Do double-check if requested:
    if [ -z "$DO_PARANOID_CHECK" ]; then
        return 0
    else
        if [ "$(check_for_equality "$1" "$2")" -ne "0" ]; then
            echo "${COL_RED}^^^^^^ Error: files no longer identical - cancelling.....${COL_RESET}"
			return 1
        fi
    fi
}

cp_symlink() {
    print_progress_prefix
    echo "${COL_YELLOW}Symlinking to original: ${COL_RESET}$1"
    if original_check "$1" "$2"; then
        if [ -z "$DO_DRY_RUN" ]; then
            # replace duplicate with symlink
            rm -rf "$1"
            ln -s "$2" "$1"
            # make the symlink's mtime the same as the original
            touch -mr "$2" -h "$1"
        fi
    fi
}

cp_hardlink() {
    if [ -d "$1" ]; then
        # for duplicate dir's, can't hardlink so use symlink
        cp_symlink "$@"
        return $?
    fi
    print_progress_prefix
    echo "${COL_YELLOW}Hardlinking to original: ${COL_RESET}$1"
    if original_check "$1" "$2"; then
        if [ -z "$DO_DRY_RUN" ]; then
            # replace duplicate with hardlink
            rm -rf "$1"
            ln "$2" "$1"
        fi
    fi
}

cp_reflink() {
    if [ -d "$1" ]; then
        # for duplicate dir's, can't clone so use symlink
        cp_symlink "$@"
        return $?
    fi
    print_progress_prefix
    # reflink $1 to $2's data, preserving $1's  mtime
    echo "${COL_YELLOW}Reflinking to original: ${COL_RESET}$1"
    if original_check "$1" "$2"; then
        if [ -z "$DO_DRY_RUN" ]; then
            touch -mr "$1" "$0"
            if [ -d "$1" ]; then
                rm -rf "$1"
            fi
            cp --archive --reflink=always "$2" "$1"
            touch -mr "$0" "$1"
        fi
    fi
}

clone() {
    print_progress_prefix
    # clone $1 from $2's data
    # note: no original_check() call because rmlint --dedupe takes care of this
    echo "${COL_YELLOW}Cloning to: ${COL_RESET}$1"
    if [ -z "$DO_DRY_RUN" ]; then
        if [ -n "$DO_CLONE_READONLY" ]; then
            $SUDO_COMMAND $RMLINT_BINARY --dedupe  --dedupe-readonly "$2" "$1"
        else
            $RMLINT_BINARY --dedupe  "$2" "$1"
        fi
    fi
}

skip_hardlink() {
    print_progress_prefix
    echo "${COL_BLUE}Leaving as-is (already hardlinked to original): ${COL_RESET}$1"
}

skip_reflink() {
    print_progress_prefix
    echo "${COL_BLUE}Leaving as-is (already reflinked to original): ${COL_RESET}$1"
}

user_command() {
    print_progress_prefix

    echo "${COL_YELLOW}Executing user command: ${COL_RESET}$1"
    if [ -z "$DO_DRY_RUN" ]; then
        # You can define this function to do what you want:
        echo 'no user command defined.'
    fi
}

remove_cmd() {
    print_progress_prefix
    echo "${COL_YELLOW}Deleting: ${COL_RESET}$1"
    if original_check "$1" "$2"; then
        if [ -z "$DO_DRY_RUN" ]; then
            if [ ! -z "$DO_KEEP_DIR_TIMESTAMPS" ]; then
                touch -r "$(dirname $1)" "$STAMPFILE"
            fi

            rm -rf "$1"

            if [ ! -z "$DO_KEEP_DIR_TIMESTAMPS" ]; then
                # Swap back old directory timestamp:
                touch -r "$STAMPFILE" "$(dirname $1)"
                rm "$STAMPFILE"
            fi

            if [ ! -z "$DO_DELETE_EMPTY_DIRS" ]; then
                DIR=$(dirname "$1")
                while [ ! "$(ls -A "$DIR")" ]; do
                    print_progress_prefix 0
                    echo "${COL_GREEN}Deleting resulting empty dir: ${COL_RESET}$DIR"
                    rmdir "$DIR"
                    DIR=$(dirname "$DIR")
                done
            fi
        fi
    fi
}

original_cmd() {
    print_progress_prefix
    echo "${COL_GREEN}Keeping:  ${COL_RESET}$1"
}

##################
# OPTION PARSING #
##################

ask() {
    cat << EOF

This script will delete certain files rmlint found.
It is highly advisable to view the script first!

Rmlint was executed in the following way:

   $ rmlint /mnt/wslg

Execute this script with -d to disable this informational message.
Type any string to continue; CTRL-C, Enter or CTRL-D to abort immediately
EOF
    read -r eof_check
    if [ -z "$eof_check" ]
    then
        # Count Ctrl-D and Enter as aborted too.
        echo "${COL_RED}Aborted on behalf of the user.${COL_RESET}"
        exit 1;
    fi
}

usage() {
    cat << EOF
usage: $0 OPTIONS

OPTIONS:

  -h   Show this message.
  -d   Do not ask before running.
  -x   Keep rmlint.sh; do not autodelete it.
  -p   Recheck that files are still identical before removing duplicates.
  -r   Allow deduplication of files on read-only btrfs snapshots. (requires sudo)
  -n   Do not perform any modifications, just print what would be done. (implies -d and -x)
  -c   Clean up empty directories while deleting duplicates.
  -q   Do not show progress.
  -k   Keep the timestamp of directories when removing duplicates.
EOF
}

DO_REMOVE=
DO_ASK=

while getopts "dhxnrpqck" OPTION
do
  case $OPTION in
     h)
       usage
       exit 0
       ;;
     d)
       DO_ASK=false
       ;;
     x)
       DO_REMOVE=false
       ;;
     n)
       DO_DRY_RUN=true
       DO_REMOVE=false
       DO_ASK=false
       ;;
     r)
       DO_CLONE_READONLY=true
       ;;
     p)
       DO_PARANOID_CHECK=true
       ;;
     c)
       DO_DELETE_EMPTY_DIRS=true
       ;;
     q)
       DO_SHOW_PROGRESS=
       ;;
     k)
       DO_KEEP_DIR_TIMESTAMPS=true
       ;;
     *)
       usage
       exit 1
  esac
done

if [ -z $DO_REMOVE ]
then
    echo "#${COL_YELLOW} ///${COL_RESET}This script will be deleted after it runs${COL_YELLOW}///${COL_RESET}"
fi

if [ -z $DO_ASK ]
then
  usage
  ask
fi

if [ ! -z $DO_DRY_RUN  ]
then
    echo "#${COL_YELLOW} ////////////////////////////////////////////////////////////${COL_RESET}"
    echo "#${COL_YELLOW} /// ${COL_RESET} This is only a dry run; nothing will be modified! ${COL_YELLOW}///${COL_RESET}"
    echo "#${COL_YELLOW} ////////////////////////////////////////////////////////////${COL_RESET}"
fi

######### START OF AUTOGENERATED OUTPUT #########

handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/id' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/hostid' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/hexdump' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/usr/share/doc/gir1.2-pango-1.0/changelog.Debian.gz' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/head' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/hd' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/groups' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/fuser' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/free' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/fold' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/flock' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/find' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/fallocate' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/usr/share/doc/perl/Changes.gz' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/factor' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/expr' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/expand' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/env' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/eject' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/du' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/dos2unix' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/dirname' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/diff' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/deallocvt' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/dc' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/cut' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/cryptpw' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/crontab' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/usr/share/doc/gir1.2-polkit-1.0/changelog.Debian.gz' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/pstree' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/pscan' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/printf' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/pmap' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/zcat' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/pkill' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/watch' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/pgrep' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/usleep' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/usr/share/doc/libcap2-bin/changelog.Debian.gz' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/paste' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/passwd' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/openvt' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/od' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/nslookup' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/nsenter' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/nproc' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/nohup' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/nmeter' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/nl' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/nc' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/mkpasswd' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/mkfifo' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/microcom' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/mesg' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/md5sum' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/usr/share/doc/libxcb-present0/changelog.Debian.gz' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/lzopcat' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/lzma' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/lzcat' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/lsusb' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/sbin/killall5' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/lsof' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/sbin/fbset' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/logger' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/sbin/ether-wake' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/less' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/sbin/deluser' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/sbin/delgroup' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/usr/share/doc/gir1.2-harfbuzz-0.0/changelog.Debian.gz' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/last' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/sbin/crond' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/killall' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/sbin/chroot' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/slattach' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/sbin/chpasswd' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/etc/mtab' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/setconsole' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/sbin/brctl' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/route' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/sbin/arping' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/usr/share/doc/libxcb-glx0/changelog.Debian.gz' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/rmmod' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/sbin/adduser' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/reboot' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/usr/share/doc/python3-gi-cairo/changelog.Debian.gz' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/sbin/addgroup' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/raidautorun' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/sbin/add-shell' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/poweroff' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/more' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/pivot_root' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/mktemp' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/nologin' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/mknod' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/nameif' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/modprobe' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/mkdir' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/makemime' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/modinfo' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/lzop' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/mkswap' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/lsattr' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/mkfs.vfat' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/ls' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/mkdosfs' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/login' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/usr/share/doc/libxcb-xfixes0/changelog.Debian.gz' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/mdev' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/ln' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/lsmod' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/linux64' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/losetup' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/linux32' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/logread' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/link' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/loadkmap' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/usr/share/doc/gir1.2-gdkpixbuf-2.0/changelog.Debian.gz' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/kill' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/usr/share/doc/libpangoxft-1.0-0/changelog.Debian.gz' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/kbd_mode' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/klogd' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/ipcalc' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/iptunnel' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/iostat' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/iprule' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/ionice' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/usr/share/doc/libpam-cap/changelog.Debian.gz' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/iproute' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/hostname' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/ipneigh' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/gzip' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/iplink' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/gunzip' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/ipaddr' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/grep' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/usr/share/doc/libxcb-sync1/changelog.Debian.gz' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/ip' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/getopt' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/insmod' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/fsync' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/inotifyd' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/fgrep' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/init' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/fdflush' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/cpio' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/fatattr' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/comm' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/false' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/cmp' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/egrep' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/clear' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/echo' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/cksum' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/dumpkmap' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/chvt' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/dnsdomainname' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/cal' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/uname' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/bzip2' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/umount' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/bzcat' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/true' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/usr/share/doc/libxcb-randr0/changelog.Debian.gz' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/bunzip2' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/touch' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/blkdiscard' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/tar' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/beep' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/sbin/setlogcons' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/sync' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/bc' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/sbin/setfont' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/su' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/basename' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/sbin/sendmail' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/stty' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/awk' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/sbin/rfkill' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/stat' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/[[' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/sbin/remove-shell' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/sleep' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/[' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/sbin/readahead' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/sh' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/sbin/rdev' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/setserial' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/sbin/rdate' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/setpriv' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/sbin/partprobe' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/sed' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/sbin/ntpd' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/run-parts' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/sbin/nbd-client' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/rmdir' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/zcip' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/sbin/nandwrite' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/rm' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/watchdog' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/sbin/nanddump' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/rev' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/vconfig' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/sbin/loadfont' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/reformime' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/udhcpc' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/usr/share/doc/gir1.2-gtk-3.0/changelog.Debian.gz' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/traceroute6' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/pwd' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/tunctl' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/usr/share/doc/gir1.2-gtk-3.0/AUTHORS' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/traceroute' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/ps' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/syslogd' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/tr' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/printenv' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/sysctl' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/top' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/pipe_progress' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/switch_root' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/timeout' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/ping6' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/swapon' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/time' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/ping' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/swapoff' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/test' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/pidof' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/tee' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/nice' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/tail' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/netstat' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/tac' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/mv' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/sum' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/mpstat' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/strings' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/mountpoint' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/mount' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/split' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/sort' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/shuf' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/shred' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/showkey' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/sha512sum' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/usr/share/doc/gir1.2-freedesktop/changelog.Debian.gz' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/sha3sum' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/sha256sum' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/sha1sum' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/setsid' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/usr/share/doc/libxcb-dri3-0/changelog.Debian.gz' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/usr/share/doc/gir1.2-rsvg-2.0/changelog.Debian.gz' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/setkeycodes' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/etc/ssl1.1/cert.pem' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/seq' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/resize' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/reset' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/renice' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/realpath' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/readlink' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/pwdx' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/yes' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/xzcat' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/usr/share/doc/libxcb-dri2-0/changelog.Debian.gz' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/xxd' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/xargs' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/whois' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/ifup' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/whoami' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/ifenslave' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/who' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/ifdown' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/which' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/ifconfig' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/wget' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/hwclock' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/wc' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/halt' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/volname' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/getty' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/vlock' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/dmesg' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/fstrim' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/vi' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/df' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/fsck' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/uuencode' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/dd' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/findfs' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/uudecode' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/etc/mtab' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/date' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/usr/share/doc/libx11-xcb1/changelog.Debian.gz' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/fdisk' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/uptime' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/cp' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/fbsplash' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/unzip' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/chown' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/depmod' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/unxz' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/chmod' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/blockdev' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/unshare' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/chgrp' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/blkid' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/unlzop' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/chattr' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/arp' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/unlzma' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/cat' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/unlink' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/adjtimex' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/unix2dos' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/bbconfig' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sbin/acpid' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/uniq' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/base64' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/unexpand' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/ash' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/udhcpc6' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/bin/arch' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/ttysize' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/tty' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/truncate' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/usr/share/doc/gir1.2-atk-1.0/changelog.Debian.gz' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/tree' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/ipcs' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/ipcrm' # bad symlink pointing nowhere
handle_bad_symlink '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/bin/install' # bad symlink pointing nowhere
handle_emptydir '/mnt/wslg/run/user/0/dbus-1/service' # empty folder
handle_emptydir '/mnt/wslg/run/user/0/dbus-1' # empty folder
handle_emptydir '/mnt/wslg/distro/var/www/html/zina/zina/cache' # empty folder
handle_emptydir '/mnt/wslg/distro/var/tmp/systemd-private-3b3e39574ea64689913407dd5661fb9e-systemd-resolved.service-zTkQtD/tmp' # empty folder
handle_emptydir '/mnt/wslg/distro/var/tmp/systemd-private-3b3e39574ea64689913407dd5661fb9e-systemd-resolved.service-zTkQtD' # empty folder
handle_emptydir '/mnt/wslg/distro/var/tmp/systemd-private-3b3e39574ea64689913407dd5661fb9e-systemd-logind.service-AVxsXN/tmp' # empty folder
handle_emptydir '/mnt/wslg/distro/var/tmp/systemd-private-3b3e39574ea64689913407dd5661fb9e-systemd-logind.service-AVxsXN' # empty folder
handle_emptydir '/mnt/wslg/distro/var/tmp/systemd-private-3b3e39574ea64689913407dd5661fb9e-apache2.service-B0VSwU/tmp' # empty folder
handle_emptydir '/mnt/wslg/distro/var/tmp/systemd-private-3b3e39574ea64689913407dd5661fb9e-apache2.service-B0VSwU' # empty folder
handle_emptydir '/mnt/wslg/distro/var/tmp' # empty folder
handle_emptydir '/mnt/wslg/distro/var/opt' # empty folder
handle_emptydir '/mnt/wslg/distro/var/mail' # empty folder
handle_emptydir '/mnt/wslg/distro/var/log/private' # empty folder
handle_emptydir '/mnt/wslg/distro/var/log/installer/block' # empty folder
handle_emptydir '/mnt/wslg/distro/var/log/installer' # empty folder
handle_emptydir '/mnt/wslg/distro/var/local' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/update-manager' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/ubuntu-release-upgrader' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/systemd/pstore' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/systemd/linger' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/systemd/coredump' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/sudo/lectured' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/sudo' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/private' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/polkit-1/localauthority/90-mandatory.d' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/polkit-1/localauthority/50-local.d' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/polkit-1/localauthority/30-site.d' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/polkit-1/localauthority/20-org.d' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/php/sessions' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/misc' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/landscape' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/git' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/emacsen-common/state/flavor/installed' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/emacsen-common/state/flavor' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/dpkg/updates' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/dpkg/parts' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/volumes/act-toolcache/_data' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/volumes/act-toolcache' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/tmp' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/swarm' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/runtimes' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/plugins/tmp' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/plugins' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/fc79bf0921091fff551281c5c06c0a3ffa1112f17e72bc3bfa6746c3f84f494b/work' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/fc79bf0921091fff551281c5c06c0a3ffa1112f17e72bc3bfa6746c3f84f494b/diff/app' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/fc79bf0921091fff551281c5c06c0a3ffa1112f17e72bc3bfa6746c3f84f494b/diff' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/eb62213d5101cb801d7961f4b4b0c2032b533f87f8feba94c1e249dd90eb33a4/work' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/eb62213d5101cb801d7961f4b4b0c2032b533f87f8feba94c1e249dd90eb33a4/diff/lib/apk/exec' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/var/tmp' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/var/opt' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/var/mail' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/var/log' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/var/local' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/var/lib/misc' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/var/lib' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/var/empty' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/var/cache/misc' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/var/cache/apk' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/var/cache' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/share/misc' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/share/man' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/local/share' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/local/lib' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/local/bin' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/local' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/lib/modules-load.d' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/tmp' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/sys' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/srv' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/run/lock' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/run' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/root' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/proc' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/opt' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/mnt' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/media/usb' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/media/floppy' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/media/cdrom' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/media' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/lib/sysctl.d' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/lib/modules-load.d' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/lib/firmware' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/lib/apk/exec' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/home' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/etc/sysctl.d' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/etc/ssl/private' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/etc/periodic/weekly' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/etc/periodic/monthly' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/etc/periodic/hourly' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/etc/periodic/daily' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/etc/periodic/15min' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/etc/periodic' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/etc/opt' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/etc/network/if-pre-up.d' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/etc/network/if-pre-down.d' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/etc/network/if-post-up.d' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/etc/network/if-post-down.d' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/etc/network/if-down.d' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/etc/modules-load.d' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/etc/apk/protected_paths.d' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/dev' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/overlay2/c95f9cd902c37ef7e6d5de68ac18aafba154e456a6207b8800ed18b1f4d171db/work' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/image/overlay2/layerdb/tmp' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/image/overlay2/layerdb/mounts' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/image/overlay2/imagedb/metadata/sha256' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/image/overlay2/imagedb/metadata' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/containers' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/buildkit/net' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/docker/buildkit/content/ingest' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/containerd/tmpmounts' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/containerd/io.containerd.snapshotter.v1.native/snapshots' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/containerd/io.containerd.snapshotter.v1.native' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/containerd/io.containerd.snapshotter.v1.btrfs' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/containerd/io.containerd.snapshotter.v1.blockfile' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/containerd/io.containerd.runtime.v2.task/moby/9d1ea57abd5358abfcb0e8c10bc74e25631f4b808ee691b55c07e740cc0a791e' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/containerd/io.containerd.runtime.v2.task/moby' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/containerd/io.containerd.runtime.v2.task' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/containerd/io.containerd.runtime.v1.linux' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/containerd/io.containerd.content.v1.content/ingest' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/command-not-found' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/apt/mirrors/partial' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/apt/mirrors' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/apt/lists/auxfiles' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/apport/coredump' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/apport' # empty folder
handle_emptydir '/mnt/wslg/distro/var/lib/apache2/module/disabled_by_maint' # empty folder
handle_emptydir '/mnt/wslg/distro/var/crash' # empty folder
handle_emptydir '/mnt/wslg/distro/var/cache/private' # empty folder
handle_emptydir '/mnt/wslg/distro/var/cache/man' # empty folder
handle_emptydir '/mnt/wslg/distro/var/cache/apt/archives/partial' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/src' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/terminfo' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/zh_TW/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/zh_CN/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/vi/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/uk/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/tr/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/sv/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/sr/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/sl/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/sk/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/ru/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/ro/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/pt_BR/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/pt/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/pl/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/nl/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/nb/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/ms/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/lt/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/lg/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/lg' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/ko/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/kk/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/ja/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/it/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/id/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/ia/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/hu/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/hr/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/gl/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/ga/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/fr/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/fi/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/eu/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/et/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/es/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/eo/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/el/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/de/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/da/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/cs/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/ca/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/bg/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/be/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/locale/af/LC_TIME' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/stock/48' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/stock/32' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/stock/24' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/stock/16' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/stock/128' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/apps/48' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/stock/48' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/stock/32' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/stock/24' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/stock/16' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/stock/128' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/apps/48' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/symbolic/apps' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/symbolic' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/scalable/stock/text' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/scalable/stock/table' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/scalable/stock/object' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/scalable/stock/net' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/scalable/stock/navigation' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/scalable/stock/media' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/scalable/stock/io' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/scalable/stock/image' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/scalable/stock/form' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/scalable/stock/data' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/scalable/stock/code' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/scalable/stock/chart' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/scalable/stock' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/scalable/status' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/scalable/places' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/scalable/mimetypes' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/scalable/intl' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/scalable/filesystems' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/scalable/emotes' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/scalable/emblems' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/scalable/devices' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/scalable/categories' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/scalable/animations' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/scalable/actions' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/96x96/stock/text' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/96x96/stock/table' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/96x96/stock/object' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/96x96/stock/net' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/96x96/stock/navigation' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/96x96/stock/media' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/96x96/stock/io' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/96x96/stock/image' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/96x96/stock/form' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/96x96/stock/data' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/96x96/stock/code' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/96x96/stock/chart' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/96x96/stock' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/96x96/status' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/96x96/places' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/96x96/mimetypes' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/96x96/intl' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/96x96/filesystems' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/96x96/emotes' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/96x96/emblems' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/96x96/devices' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/96x96/categories' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/96x96/apps' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/96x96/animations' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/96x96/actions' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/96x96' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/72x72/stock/text' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/72x72/stock/table' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/72x72/stock/object' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/72x72/stock/net' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/72x72/stock/navigation' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/72x72/stock/media' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/72x72/stock/io' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/72x72/stock/image' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/72x72/stock/form' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/72x72/stock/data' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/72x72/stock/code' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/72x72/stock/chart' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/72x72/stock' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/72x72/status' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/72x72/places' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/72x72/mimetypes' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/72x72/intl' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/72x72/filesystems' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/72x72/emotes' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/72x72/emblems' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/72x72/devices' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/72x72/categories' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/72x72/apps' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/72x72/animations' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/72x72/actions' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/72x72' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/64x64/stock/text' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/64x64/stock/table' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/64x64/stock/object' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/64x64/stock/net' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/64x64/stock/navigation' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/64x64/stock/media' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/64x64/stock/io' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/64x64/stock/image' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/64x64/stock/form' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/64x64/stock/data' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/64x64/stock/code' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/64x64/stock/chart' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/64x64/stock' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/64x64/status' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/64x64/places' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/64x64/mimetypes' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/64x64/intl' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/64x64/filesystems' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/64x64/emotes' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/64x64/emblems' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/64x64/devices' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/64x64/categories' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/64x64/apps' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/64x64/animations' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/64x64/actions' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/64x64' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/512x512/stock/text' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/512x512/stock/table' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/512x512/stock/object' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/512x512/stock/net' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/512x512/stock/navigation' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/512x512/stock/media' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/512x512/stock/io' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/512x512/stock/image' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/512x512/stock/form' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/512x512/stock/data' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/512x512/stock/code' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/512x512/stock/chart' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/512x512/stock' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/512x512/status' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/512x512/places' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/512x512/mimetypes' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/512x512/intl' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/512x512/filesystems' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/512x512/emotes' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/512x512/emblems' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/512x512/devices' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/512x512/categories' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/512x512/apps' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/512x512/animations' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/512x512/actions' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/512x512' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/48x48/stock/text' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/48x48/stock/table' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/48x48/stock/object' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/48x48/stock/net' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/48x48/stock/navigation' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/48x48/stock/media' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/48x48/stock/io' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/48x48/stock/image' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/48x48/stock/form' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/48x48/stock/data' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/48x48/stock/code' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/48x48/stock/chart' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/48x48/stock' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/48x48/status' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/48x48/places' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/48x48/mimetypes' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/48x48/intl' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/48x48/filesystems' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/48x48/emotes' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/48x48/emblems' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/48x48/devices' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/48x48/categories' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/48x48/animations' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/48x48/actions' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/36x36/stock/text' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/36x36/stock/table' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/36x36/stock/object' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/36x36/stock/net' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/36x36/stock/navigation' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/36x36/stock/media' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/36x36/stock/io' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/36x36/stock/image' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/36x36/stock/form' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/36x36/stock/data' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/36x36/stock/code' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/36x36/stock/chart' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/36x36/stock' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/36x36/status' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/36x36/places' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/36x36/mimetypes' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/36x36/intl' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/36x36/filesystems' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/36x36/emotes' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/36x36/emblems' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/36x36/devices' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/36x36/categories' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/36x36/apps' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/36x36/animations' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/36x36/actions' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/36x36' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/32x32/stock/text' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/32x32/stock/table' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/32x32/stock/object' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/32x32/stock/net' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/32x32/stock/navigation' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/32x32/stock/media' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/32x32/stock/io' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/32x32/stock/image' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/32x32/stock/form' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/32x32/stock/data' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/32x32/stock/code' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/32x32/stock/chart' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/32x32/stock' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/32x32/status' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/32x32/places' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/32x32/mimetypes' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/32x32/intl' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/32x32/filesystems' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/32x32/emotes' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/32x32/emblems' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/32x32/devices' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/32x32/categories' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/32x32/apps' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/32x32/animations' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/32x32/actions' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/32x32' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/256x256/stock/text' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/256x256/stock/table' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/256x256/stock/object' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/256x256/stock/net' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/256x256/stock/navigation' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/256x256/stock/media' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/256x256/stock/io' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/256x256/stock/image' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/256x256/stock/form' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/256x256/stock/data' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/256x256/stock/code' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/256x256/stock/chart' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/256x256/stock' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/256x256/status' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/256x256/places' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/256x256/mimetypes' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/256x256/intl' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/256x256/filesystems' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/256x256/emotes' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/256x256/emblems' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/256x256/devices' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/256x256/categories' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/256x256/apps' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/256x256/animations' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/256x256/actions' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/256x256' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/24x24/stock/text' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/24x24/stock/table' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/24x24/stock/object' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/24x24/stock/net' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/24x24/stock/navigation' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/24x24/stock/media' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/24x24/stock/io' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/24x24/stock/image' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/24x24/stock/form' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/24x24/stock/data' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/24x24/stock/code' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/24x24/stock/chart' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/24x24/stock' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/24x24/status' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/24x24/places' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/24x24/mimetypes' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/24x24/intl' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/24x24/filesystems' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/24x24/emotes' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/24x24/emblems' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/24x24/devices' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/24x24/categories' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/24x24/apps' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/24x24/animations' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/24x24/actions' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/24x24' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/22x22/stock/text' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/22x22/stock/table' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/22x22/stock/object' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/22x22/stock/net' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/22x22/stock/navigation' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/22x22/stock/media' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/22x22/stock/io' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/22x22/stock/image' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/22x22/stock/form' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/22x22/stock/data' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/22x22/stock/code' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/22x22/stock/chart' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/22x22/stock' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/22x22/status' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/22x22/places' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/22x22/mimetypes' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/22x22/intl' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/22x22/filesystems' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/22x22/emotes' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/22x22/emblems' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/22x22/devices' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/22x22/categories' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/22x22/apps' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/22x22/animations' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/22x22/actions' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/22x22' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/192x192/stock/text' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/192x192/stock/table' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/192x192/stock/object' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/192x192/stock/net' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/192x192/stock/navigation' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/192x192/stock/media' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/192x192/stock/io' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/192x192/stock/image' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/192x192/stock/form' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/192x192/stock/data' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/192x192/stock/code' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/192x192/stock/chart' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/192x192/stock' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/192x192/status' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/192x192/places' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/192x192/mimetypes' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/192x192/intl' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/192x192/filesystems' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/192x192/emotes' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/192x192/emblems' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/192x192/devices' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/192x192/categories' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/192x192/apps' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/192x192/animations' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/192x192/actions' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/192x192' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/16x16/stock/text' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/16x16/stock/table' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/16x16/stock/object' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/16x16/stock/net' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/16x16/stock/navigation' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/16x16/stock/media' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/16x16/stock/io' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/16x16/stock/image' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/16x16/stock/form' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/16x16/stock/data' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/16x16/stock/code' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/16x16/stock/chart' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/16x16/stock' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/16x16/status' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/16x16/places' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/16x16/mimetypes' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/16x16/intl' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/16x16/filesystems' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/16x16/emotes' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/16x16/emblems' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/16x16/devices' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/16x16/categories' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/16x16/animations' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/16x16/actions' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/128x128/stock/text' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/128x128/stock/table' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/128x128/stock/object' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/128x128/stock/net' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/128x128/stock/navigation' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/128x128/stock/media' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/128x128/stock/io' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/128x128/stock/image' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/128x128/stock/form' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/128x128/stock/data' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/128x128/stock/code' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/128x128/stock/chart' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/128x128/stock' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/128x128/status' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/128x128/places' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/128x128/mimetypes' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/128x128/intl' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/128x128/filesystems' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/128x128/emotes' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/128x128/emblems' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/128x128/devices' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/128x128/categories' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/128x128/animations' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/hicolor/128x128/actions' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/places/32' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/actions/24' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/actions/22' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/git-core/templates/branches' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/file/magic' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/debianutils/shells.d' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/share/alsa/ucm2/conf.virt.d' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/local/src' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/local/share/man' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/local/share/ca-certificates' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/local/sbin' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/local/lib/python3.10/dist-packages' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/local/lib/python3.10' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/local/lib/docker/cli-plugins' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/local/lib/docker' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/local/lib' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/local/include' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/local/games' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/local/etc' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/libx32' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/lib32' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl/5.34.0/machine' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl/5.34.0/bits/linux' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/krb5/plugins/libkrb5' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/graphviz' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/lib/wsl/lib' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/lib/wsl/drivers' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/lib/wsl' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/lib/systemd/system/runlevel5.target.wants' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/lib/systemd/system/runlevel4.target.wants' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/lib/systemd/system/runlevel3.target.wants' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/lib/systemd/system/runlevel2.target.wants' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/lib/systemd/system/runlevel1.target.wants' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/lib/systemd/system/local-fs.target.wants' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/lib/systemd/system-sleep' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/lib/systemd/system-shutdown' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/lib/sasl2' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/lib/networkd-dispatcher/routable.d' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/lib/networkd-dispatcher/off.d' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/lib/networkd-dispatcher/no-carrier.d' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/lib/networkd-dispatcher/dormant.d' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/lib/networkd-dispatcher/degraded.d' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/lib/networkd-dispatcher/carrier.d' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/lib/networkd-dispatcher' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/lib/modules/5.15.167.4-microsoft-standard-WSL2' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/lib/modules/5.15.153.1-microsoft-standard-WSL2' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/lib/modules-load.d' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/lib/modules' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/lib/groff/site-tmac' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/lib/cgi-bin' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/lib/X11' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/include/X11' # empty folder
handle_emptydir '/mnt/wslg/distro/usr/games' # empty folder
handle_emptydir '/mnt/wslg/distro/tmp/systemd-private-3b3e39574ea64689913407dd5661fb9e-systemd-resolved.service-e1BtSK/tmp' # empty folder
handle_emptydir '/mnt/wslg/distro/tmp/systemd-private-3b3e39574ea64689913407dd5661fb9e-systemd-resolved.service-e1BtSK' # empty folder
handle_emptydir '/mnt/wslg/distro/tmp/systemd-private-3b3e39574ea64689913407dd5661fb9e-systemd-logind.service-yNCfaF/tmp' # empty folder
handle_emptydir '/mnt/wslg/distro/tmp/systemd-private-3b3e39574ea64689913407dd5661fb9e-systemd-logind.service-yNCfaF' # empty folder
handle_emptydir '/mnt/wslg/distro/tmp/systemd-private-3b3e39574ea64689913407dd5661fb9e-apache2.service-1VlWxc/tmp' # empty folder
handle_emptydir '/mnt/wslg/distro/tmp/systemd-private-3b3e39574ea64689913407dd5661fb9e-apache2.service-1VlWxc' # empty folder
handle_emptydir '/mnt/wslg/distro/sys' # empty folder
handle_emptydir '/mnt/wslg/distro/srv' # empty folder
handle_emptydir '/mnt/wslg/distro/run/user' # empty folder
handle_emptydir '/mnt/wslg/distro/run/systemd/users' # empty folder
handle_emptydir '/mnt/wslg/distro/run/systemd/shutdown' # empty folder
handle_emptydir '/mnt/wslg/distro/run/systemd/sessions' # empty folder
handle_emptydir '/mnt/wslg/distro/run/systemd/seats' # empty folder
handle_emptydir '/mnt/wslg/distro/run/systemd/netif/lldp' # empty folder
handle_emptydir '/mnt/wslg/distro/run/systemd/netif/links' # empty folder
handle_emptydir '/mnt/wslg/distro/run/systemd/netif/leases' # empty folder
handle_emptydir '/mnt/wslg/distro/run/systemd/netif' # empty folder
handle_emptydir '/mnt/wslg/distro/run/systemd/machines' # empty folder
handle_emptydir '/mnt/wslg/distro/run/systemd/ask-password' # empty folder
handle_emptydir '/mnt/wslg/distro/run/sudo' # empty folder
handle_emptydir '/mnt/wslg/distro/run/sendsigs.omit.d' # empty folder
handle_emptydir '/mnt/wslg/distro/run/screen' # empty folder
handle_emptydir '/mnt/wslg/distro/run/log' # empty folder
handle_emptydir '/mnt/wslg/distro/run/lock/subsys' # empty folder
handle_emptydir '/mnt/wslg/distro/run/lock' # empty folder
handle_emptydir '/mnt/wslg/distro/proc' # empty folder
handle_emptydir '/mnt/wslg/distro/opt/containerd/lib' # empty folder
handle_emptydir '/mnt/wslg/distro/opt/containerd/bin' # empty folder
handle_emptydir '/mnt/wslg/distro/opt/containerd' # empty folder
handle_emptydir '/mnt/wslg/distro/opt' # empty folder
handle_emptydir '/mnt/wslg/distro/mnt/wslg' # empty folder
handle_emptydir '/mnt/wslg/distro/mnt/wsl' # empty folder
handle_emptydir '/mnt/wslg/distro/mnt/f' # empty folder
handle_emptydir '/mnt/wslg/distro/mnt/e' # empty folder
handle_emptydir '/mnt/wslg/distro/mnt/c' # empty folder
handle_emptydir '/mnt/wslg/distro/mnt' # empty folder
handle_emptydir '/mnt/wslg/distro/media' # empty folder
handle_emptydir '/mnt/wslg/distro/lost+found' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/vulkan/implicit_layer.d' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/vulkan/icd.d' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/vulkan/explicit_layer.d' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/vulkan' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/ufw/applications.d/apache2' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/tmpfiles.d' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/systemd/user/pipewire.service.wants' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/systemd/user/default.target.wants' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/systemd/network' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/ssh/ssh_config.d' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/security/namespace.d' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/security/limits.d' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/pulse/client.conf.d' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/polkit-1/localauthority/90-mandatory.d' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/polkit-1/localauthority/50-local.d' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/polkit-1/localauthority/30-site.d' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/polkit-1/localauthority/20-org.d' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/polkit-1/localauthority/10-vendor.d' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/polkit-1/localauthority' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/opt' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/networkd-dispatcher/routable.d' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/networkd-dispatcher/off.d' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/networkd-dispatcher/no-carrier.d' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/networkd-dispatcher/dormant.d' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/networkd-dispatcher/degraded.d' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/networkd-dispatcher/carrier.d' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/networkd-dispatcher' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/mono/certstore/keypairs' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/lighttpd/conf-enabled' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/libpaper.d' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/kernel/postinst.d' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/kernel/install.d' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/kernel' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/gss/mech.d' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/gss' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/dpkg/dpkg.cfg.d' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/docker' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/dconf/db' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/dconf' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/dbus-1/session.d' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/binfmt.d' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/apt/preferences.d' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/apt/auth.conf.d' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/apparmor.d/force-complain' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/apparmor.d/disable' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/X11/xorg.conf.d' # empty folder
handle_emptydir '/mnt/wslg/distro/etc/X11/xkb' # empty folder
handle_emptydir '/mnt/wslg/distro/dev/shm' # empty folder
handle_emptydir '/mnt/wslg/distro/dev/pts' # empty folder
handle_emptydir '/mnt/wslg/distro/boot' # empty folder
handle_emptydir '/mnt/wslg/distro/Docker/host' # empty folder
handle_emptydir '/mnt/wslg/distro/Docker' # empty folder
handle_emptyfile '/mnt/wslg/distro/var/lib/apt/periodic/upgrade-stamp' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/man-db/auto-update' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/apt/periodic/update-stamp' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/apt/periodic/unattended-upgrades-stamp' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/urllib3/contrib/_securetransport/__init__.py' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/secretstorage/py.typed' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/apt/periodic/download-upgradeable-stamp' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/urllib3/contrib/__init__.py' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/borgmatic/config/__init__.py' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/dbus_python-1.2.18.egg-info/not-zip-safe' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/share/X11/locale/cs_CZ.UTF-8/XLC_LOCALE' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/pyrsistent/py.typed' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/borgmatic/commands/__init__.py' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/share/X11/locale/cs_CZ.UTF-8/XI18N_OBJS' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/trio/_core/tests/__init__.py' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/keyring/testing/__init__.py' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/jwt/py.typed' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/share/X11/locale/tatar-cyr/Compose' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-user-helper-enabled/sockets.target.wants/gpg-agent-ssh.socket' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-user-helper-enabled/sockets.target.wants/gpg-agent-extra.socket' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-user-helper-enabled/sockets.target.wants/gpg-agent.socket' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-user-helper-enabled/sockets.target.wants/pipewire.socket' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/dpkg/info/python3-venv.md5sums' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-user-helper-enabled/sockets.target.wants/gpg-agent-browser.socket' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-user-helper-enabled/sockets.target.wants/pk-debconf-helper.socket' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-user-helper-enabled/sockets.target.wants/dirmngr.socket' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-user-helper-enabled/graphical-session-pre.target.wants/session-migration.service' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-user-helper-enabled/graphical-session-pre.target.wants/xdg-desktop-portal-rewrite-launchers.service' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/jeepney/integrate/tests/__init__.py' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/idna/py.typed' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-user-helper-enabled/pipewire.service.wants/pipewire-media-session.service' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/docker/overlay2/c95f9cd902c37ef7e6d5de68ac18aafba154e456a6207b8800ed18b1f4d171db/committed' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/share/X11/locale/tscii-0/Compose' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-user-helper-enabled/default.target.wants/pipewire.service' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3.10/urllib/__init__.py' # empty file
handle_emptyfile '/mnt/wslg/distro/var/log/btmp' # empty file
handle_emptyfile '/mnt/wslg/distro/var/log/php8.1-fpm.log' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/importlib_metadata/py.typed' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/trio/tests/tools/__init__.py' # empty file
handle_emptyfile '/mnt/wslg/distro/etc/subuid-' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/share/X11/locale/th_TH/Compose' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/jeepney/io/tests/__init__.py' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/docker/overlay2/eb62213d5101cb801d7961f4b4b0c2032b533f87f8feba94c1e249dd90eb33a4/diff/lib/apk/db/lock' # empty file
handle_emptyfile '/mnt/wslg/distro/var/cache/debconf/config.dat' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/docker/overlay2/fc79bf0921091fff551281c5c06c0a3ffa1112f17e72bc3bfa6746c3f84f494b/committed' # empty file
handle_emptyfile '/mnt/wslg/distro/dev/zero' # empty file
handle_emptyfile '/mnt/wslg/distro/var/cache/debconf/passwords.dat' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/borgmatic-1.5.20.egg-info/requires.txt' # empty file
handle_emptyfile '/mnt/wslg/distro/var/cache/debconf/templates.dat' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/share/X11/locale/sr_RS.UTF-8/XLC_LOCALE' # empty file
handle_emptyfile '/mnt/wslg/distro/dev/null' # empty file
handle_emptyfile '/mnt/wslg/distro/var/cache/apt/archives/lock' # empty file
handle_emptyfile '/mnt/wslg/distro/dev/full' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/dpkg/triggers/Unincorp' # empty file
handle_emptyfile '/mnt/wslg/distro/dev/console' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/dpkg/triggers/Lock' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/apache2/enabled_by_maint/calendar' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/share/X11/locale/iso8859-11/Compose' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/apache2/enabled_by_maint/fileinfo' # empty file
handle_emptyfile '/mnt/wslg/distro/dev/tty' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/apache2/enabled_by_maint/readline' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_vendor/__init__.py' # empty file
handle_emptyfile '/mnt/wslg/distro/dev/urandom' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/apache2/enabled_by_maint/pdo' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/docker/buildkit/executor/runc-log.json' # empty file
handle_emptyfile '/mnt/wslg/distro/dev/random' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/apache2/enabled_by_maint/gettext' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/apache2/enabled_by_maint/sockets' # empty file
handle_emptyfile '/mnt/wslg/distro/dev/ptmx' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/urllib3/packages/backports/__init__.py' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/apache2/enabled_by_maint/sysvsem' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/apache2/enabled_by_maint/sysvmsg' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/apache2/enabled_by_maint/phar' # empty file
handle_emptyfile '/mnt/wslg/distro/etc/apparmor.d/local/usr.bin.man' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/apache2/enabled_by_maint/ffi' # empty file
handle_emptyfile '/mnt/wslg/distro/etc/apparmor.d/local/nvidia_modprobe' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/outcome-1.1.0.egg-info/requires.txt' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/apache2/enabled_by_maint/iconv' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/share/X11/locale/isiri-3342/Compose' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/borgmatic/hooks/__init__.py' # empty file
handle_emptyfile '/mnt/wslg/distro/etc/apparmor.d/local/lsb_release' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/apache2/enabled_by_maint/opcache' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/apache2/enabled_by_maint/ftp' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/apache2/enabled_by_maint/exif' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/apache2/enabled_by_maint/posix' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/launchpadlib/testing/tests/__init__.py' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/share/X11/locale/microsoft-cp1251/Compose' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/apache2/enabled_by_maint/shmop' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/apache2/enabled_by_maint/tokenizer' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/apache2/enabled_by_maint/ctype' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/apache2/enabled_by_maint/sysvshm' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/chardet/metadata/__init__.py' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/launchpadlib/testing/__init__.py' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/ruamel/yaml/py.typed' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/registry/calendar' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/registry/fileinfo' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/registry/readline' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/timers/stamp-borgmatic.timer' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/registry/pdo' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/registry/gettext' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-helper-enabled/timers.target.wants/borgmatic.timer' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/share/X11/locale/km_KH.UTF-8/XLC_LOCALE' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/registry/sockets' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/docker/overlay2/eb62213d5101cb801d7961f4b4b0c2032b533f87f8feba94c1e249dd90eb33a4/committed' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/registry/sysvsem' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/registry/sysvmsg' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/registry/ffi' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/cryptography/py.typed' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/registry/phar' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/pyfuse3-3.2.0.egg-info/requires.txt' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/share/X11/locale/microsoft-cp1256/Compose' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/pkg_resources/_vendor/__init__.py' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/docker-desktop/mounts.data' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/python/python3.10_installed' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/shells.state' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/borgmatic/borg/__init__.py' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/share/X11/locale/microsoft-cp1255/Compose' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/share/mime/icons' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/borgmatic/__init__.py' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib/tests/data/__init__.py' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-helper-enabled/sockets.target.wants/docker.socket' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/share/X11/locale/fi_FI.UTF-8/XLC_LOCALE' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-helper-enabled/sockets.target.wants/uuidd.socket' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/share/X11/locale/fi_FI.UTF-8/XI18N_OBJS' # empty file
handle_emptyfile '/mnt/wslg/distro/var/log/apache2/access.log' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-helper-enabled/multi-user.target.wants/containerd.service' # empty file
handle_emptyfile '/mnt/wslg/distro/var/log/apache2/other_vhosts_access.log' # empty file
handle_emptyfile '/mnt/wslg/distro/etc/dictionaries-common/ispell-default' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-helper-enabled/multi-user.target.wants/networkd-dispatcher.service' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-helper-enabled/multi-user.target.wants/docker.service' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-helper-enabled/multi-user.target.wants/apache2.service' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/share/X11/locale/nokhchi-1/Compose' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/sniffio/py.typed' # empty file
handle_emptyfile '/mnt/wslg/distro/etc/newt/palette.original' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-helper-enabled/multi-user.target.wants/binfmt-support.service' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/keyring/backends/__init__.py' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/packaging-21.3.egg-info/requires.txt' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/committed' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/apt/lists/lock' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-helper-enabled/multi-user.target.wants/e2scrub_reap.service' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-helper-enabled/sysinit.target.wants/systemd-timesyncd.service' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/sniffio/_tests/__init__.py' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-helper-enabled/sysinit.target.wants/apparmor.service' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-helper-enabled/timers.target.wants/apt-daily-upgrade.timer' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-helper-enabled/timers.target.wants/dpkg-db-backup.timer' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/apt/daily_lock' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-helper-enabled/timers.target.wants/motd-news.timer' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-helper-enabled/timers.target.wants/man-db.timer' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-helper-enabled/timers.target.wants/phpsessionclean.timer' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-helper-enabled/timers.target.wants/e2scrub_all.timer' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/packaging/py.typed' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-helper-enabled/timers.target.wants/apt-daily.timer' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-helper-enabled/timers.target.wants/fstrim.timer' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/docker/volumes/backingFsBlockDev' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-helper-enabled/dbus-org.freedesktop.timesync1.service' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/deborphan/keep' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/jeepney/tests/__init__.py' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/share/xml/iso-codes/iso_3166-3.xml' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/more_itertools/py.typed' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/share/X11/locale/iscii-dev/Compose' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/SecretStorage-3.3.1.egg-info/requires.txt' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3.10/email/mime/__init__.py' # empty file
handle_emptyfile '/mnt/wslg/distro/init' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/jeepney-0.7.1.dist-info/REQUESTED' # empty file
handle_emptyfile '/mnt/wslg/distro/run/mount/utab' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/trio/tests/__init__.py' # empty file
handle_emptyfile '/mnt/wslg/distro/run/mount/utab.lock' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/lib/apk/db/lock' # empty file
handle_emptyfile '/mnt/wslg/distro/run/systemd/resolve/stub-resolv.conf' # empty file
handle_emptyfile '/mnt/wslg/runtime-dir/pulse/native' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/attr/py.typed' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/php/8.1/sapi/cli' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/registry/ftp' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/php/8.1/sapi/apache2' # empty file
handle_emptyfile '/mnt/wslg/PulseAudioRDPSource' # empty file
handle_emptyfile '/mnt/wslg/PulseAudioRDPSink' # empty file
handle_emptyfile '/mnt/wslg/distro/var/log/unattended-upgrades/unattended-upgrades.log' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/share/X11/locale/am_ET.UTF-8/XLC_LOCALE' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/softwareproperties/dbus/__init__.py' # empty file
handle_emptyfile '/mnt/wslg/distro/var/log/unattended-upgrades/unattended-upgrades-shutdown.log' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/share/X11/locale/am_ET.UTF-8/XI18N_OBJS' # empty file
handle_emptyfile '/mnt/wslg/distro/var/log/unattended-upgrades/unattended-upgrades-dpkg.log' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/apt/py.typed' # empty file
handle_emptyfile '/mnt/wslg/runtime-dir/wayland-0.lock' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/borg/crypto/__init__.py' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/share/X11/locale/el_GR.UTF-8/XLC_LOCALE' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/registry/iconv' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/share/X11/locale/el_GR.UTF-8/XI18N_OBJS' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/registry/opcache' # empty file
handle_emptyfile '/mnt/wslg/distro/etc/security/opasswd' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/oauthlib/openid/connect/core/__init__.py' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/registry/exif' # empty file
handle_emptyfile '/mnt/wslg/runtime-dir/wayland-0' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/registry/posix' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/registry/shmop' # empty file
handle_emptyfile '/mnt/wslg/distro/var/log/fontconfig.log' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/apache2/site/enabled_by_admin/000-default' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/registry/tokenizer' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/oauthlib/openid/connect/__init__.py' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/registry/ctype' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/apache2/conf/disabled_by_maint/javascript-common' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/registry/sysvshm' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/trio/_tools/__init__.py' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/apache2/conf/enabled_by_maint/localized-error-pages' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/cli/enabled_by_maint/calendar' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/apache2/conf/enabled_by_maint/serve-cgi-bin' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/cli/enabled_by_maint/fileinfo' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/apache2/conf/enabled_by_maint/other-vhosts-access-log' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/cli/enabled_by_maint/readline' # empty file
handle_emptyfile '/mnt/wslg/distro/etc/odbc.ini' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/apache2/conf/enabled_by_maint/security' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/cli/enabled_by_maint/pdo' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/apache2/conf/enabled_by_maint/charset' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/cli/enabled_by_maint/gettext' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/jsonschema/tests/__init__.py' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/cli/enabled_by_maint/sockets' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/cli/enabled_by_maint/ftp' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/share/keyrings/ubuntu-cloudimage-removed-keys.gpg' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/colorlog/py.typed' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/cli/enabled_by_maint/sysvsem' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/apache2/module/enabled_by_admin/mpm_event' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/cli/enabled_by_maint/sysvmsg' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/apache2/module/enabled_by_maint/status' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/cli/enabled_by_maint/iconv' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/cli/enabled_by_maint/ffi' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/apache2/module/enabled_by_maint/auth_basic' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-user-helper-enabled/pipewire-session-manager.service' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/cli/enabled_by_maint/phar' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/apache2/module/enabled_by_maint/autoindex' # empty file
handle_emptyfile '/mnt/wslg/distro/etc/odbcinst.ini' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/apache2/module/enabled_by_maint/authz_core' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/cli/enabled_by_maint/opcache' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/apache2/module/enabled_by_maint/dir' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/share/X11/locale/C/Compose' # empty file
handle_emptyfile '/mnt/wslg/run/user/0/wine/server-820-21475/lock' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/apache2/module/enabled_by_maint/authn_core' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/cli/enabled_by_maint/exif' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/apache2/module/enabled_by_maint/negotiation' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/cli/enabled_by_maint/posix' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/apache2/module/enabled_by_maint/setenvif' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/cli/enabled_by_maint/shmop' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/async_generator/_tests/__init__.py' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/apache2/module/enabled_by_maint/authz_host' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/cli/enabled_by_maint/tokenizer' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/apache2/module/enabled_by_maint/access_compat' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/cli/enabled_by_maint/ctype' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/apache2/module/enabled_by_maint/env' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3.10/pydoc_data/__init__.py' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/php/modules/8.1/cli/enabled_by_maint/sysvshm' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/apache2/module/enabled_by_maint/deflate' # empty file
handle_emptyfile '/mnt/wslg/distro/etc/subgid-' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/apache2/module/enabled_by_maint/authn_file' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/timesync/clock' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-helper-masked/rtkit-daemon.service' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/apache2/module/enabled_by_maint/alias' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-helper-masked/sudo.service' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/apache2/module/enabled_by_maint/authz_user' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/lib/python3/dist-packages/cairo/py.typed' # empty file
handle_emptyfile '/mnt/wslg/PulseServer' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/apache2/module/enabled_by_maint/reqtimeout' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/timers/stamp-daily_task.timer' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/timers/stamp-apt-daily-upgrade.timer' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/apache2/module/enabled_by_maint/mime' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/apache2/module/enabled_by_maint/filter' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/timers/stamp-motd-news.timer' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/apache2/module/disabled_by_admin/php8.1' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/timers/stamp-apt-daily.timer' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/apache2/module/disabled_by_admin/mpm_prefork' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/timers/stamp-man-db.timer' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/timers/stamp-e2scrub_all.timer' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/dpkg/lock-frontend' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/timers/stamp-logrotate.timer' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/timers/stamp-phpsessionclean.timer' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/emacsen-common/state/package/installed/emacsen-common' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-user-helper-masked/pipewire-media-session.service' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/emacsen-common/state/package/installed/dictionaries-common' # empty file
handle_emptyfile '/mnt/wslg/distro/var/www/html/zina/zina/demo/zina_category' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-user-helper-masked/pipewire.socket' # empty file
handle_emptyfile '/mnt/wslg/distro/usr/share/dictionaries-common/elanguages' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/dpkg/lock' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-user-helper-masked/pipewire.service' # empty file
handle_emptyfile '/mnt/wslg/distro/var/lib/systemd/deb-systemd-user-helper-masked/xdg-desktop-portal-rewrite-launchers.service' # empty file
handle_bad_user_id '/mnt/wslg/distro/usr/local/bin/dua' # bad uid
original_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/dri/crocus_dri.so' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/dri/d3d12_dri.so' '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/dri/crocus_dri.so' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/dri/i915_dri.so' '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/dri/crocus_dri.so' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/dri/iris_dri.so' '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/dri/crocus_dri.so' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/dri/kms_swrast_dri.so' '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/dri/crocus_dri.so' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/dri/nouveau_dri.so' '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/dri/crocus_dri.so' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/dri/r300_dri.so' '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/dri/crocus_dri.so' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/dri/r600_dri.so' '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/dri/crocus_dri.so' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/dri/radeonsi_dri.so' '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/dri/crocus_dri.so' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/dri/swrast_dri.so' '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/dri/crocus_dri.so' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/dri/virtio_gpu_dri.so' '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/dri/crocus_dri.so' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/dri/vmwgfx_dri.so' '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/dri/crocus_dri.so' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/dri/zink_dri.so' '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/dri/crocus_dri.so' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/dri/i965_dri.so' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/dri/nouveau_vieux_dri.so' '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/dri/i965_dri.so' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/dri/r200_dri.so' '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/dri/i965_dri.so' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/dri/radeon_dri.so' '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/dri/i965_dri.so' # duplicate
original_cmd '/mnt/wslg/distro/usr/bin/perl' # original
remove_cmd '/mnt/wslg/distro/usr/bin/perl5.34.0' '/mnt/wslg/distro/usr/bin/perl' # duplicate
original_cmd '/mnt/wslg/distro/usr/bin/pigz' # original
remove_cmd '/mnt/wslg/distro/usr/bin/unpigz' '/mnt/wslg/distro/usr/bin/pigz' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/dist.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/dist.py' '/mnt/wslg/distro/usr/lib/python3.10/distutils/dist.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/ccompiler.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/ccompiler.py' '/mnt/wslg/distro/usr/lib/python3.10/distutils/ccompiler.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/bin/perlbug' # original
remove_cmd '/mnt/wslg/distro/usr/bin/perlthanks' '/mnt/wslg/distro/usr/bin/perlbug' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/command/install.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/command/install.py' '/mnt/wslg/distro/usr/lib/python3.10/distutils/command/install.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/pytree.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/pytree.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/pytree.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/refactor.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/refactor.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/refactor.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/pgen2/tokenize.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/pgen2/tokenize.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/pgen2/tokenize.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/util.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/util.py' '/mnt/wslg/distro/usr/lib/python3.10/distutils/util.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/_msvccompiler.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/_msvccompiler.py' '/mnt/wslg/distro/usr/lib/python3.10/distutils/_msvccompiler.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/command/build_py.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/command/build_py.py' '/mnt/wslg/distro/usr/lib/python3.10/distutils/command/build_py.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/cygwinccompiler.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/cygwinccompiler.py' '/mnt/wslg/distro/usr/lib/python3.10/distutils/cygwinccompiler.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/unixccompiler.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/unixccompiler.py' '/mnt/wslg/distro/usr/lib/python3.10/distutils/unixccompiler.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixer_util.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixer_util.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixer_util.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/pgen2/pgen.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/pgen2/pgen.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/pgen2/pgen.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/main.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/main.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/main.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/pgen2/conv.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/pgen2/conv.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/pgen2/conv.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/core.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/core.py' '/mnt/wslg/distro/usr/lib/python3.10/distutils/core.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/Grammar.txt' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/Grammar.txt' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/Grammar.txt' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/command/install_lib.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/command/install_lib.py' '/mnt/wslg/distro/usr/lib/python3.10/distutils/command/install_lib.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_urllib.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_urllib.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_urllib.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_metaclass.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_metaclass.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_metaclass.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixer_base.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixer_base.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixer_base.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/btm_matcher.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/btm_matcher.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/btm_matcher.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/command/build_scripts.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/command/build_scripts.py' '/mnt/wslg/distro/usr/lib/python3.10/distutils/command/build_scripts.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_imports.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_imports.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_imports.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_tuple_params.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_tuple_params.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_tuple_params.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/spawn.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/spawn.py' '/mnt/wslg/distro/usr/lib/python3.10/distutils/spawn.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_dict.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_dict.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_dict.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_has_key.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_has_key.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_has_key.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_itertools.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_itertools.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_itertools.py' # duplicate
original_cmd '/mnt/wslg/doc/ncurses/README' # original
remove_cmd '/mnt/wslg/doc/ncurses-libs/README' '/mnt/wslg/doc/ncurses/README' # duplicate
original_cmd '/mnt/wslg/doc/pcre-8.45/README' # original
remove_cmd '/mnt/wslg/doc/pcre-8.45/html/README.txt' '/mnt/wslg/doc/pcre-8.45/README' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl/5.34.0/POSIX.pm' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/POSIX.pm' '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl/5.34.0/POSIX.pm' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/command/build.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/command/build.py' '/mnt/wslg/distro/usr/lib/python3.10/distutils/command/build.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/command/upload.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/command/upload.py' '/mnt/wslg/distro/usr/lib/python3.10/distutils/command/upload.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_types.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_types.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_types.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/pgen2/driver.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/pgen2/driver.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/pgen2/driver.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/libtag1v5/copyright' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/libtag1v5-vanilla/copyright' '/mnt/wslg/distro/usr/share/doc/libtag1v5/copyright' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/libv4l-0/copyright' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/libv4lconvert0/copyright' '/mnt/wslg/distro/usr/share/doc/libv4l-0/copyright' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_unicode.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_unicode.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_unicode.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/command/check.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/command/check.py' '/mnt/wslg/distro/usr/lib/python3.10/distutils/command/check.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/git/copyright' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/git-man/copyright' '/mnt/wslg/distro/usr/share/doc/git/copyright' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/ucf/hashfile.2' # original
remove_cmd '/mnt/wslg/distro/var/lib/ucf/hashfile.0' '/mnt/wslg/distro/var/lib/ucf/hashfile.2' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/ucf/hashfile' '/mnt/wslg/distro/var/lib/ucf/hashfile.2' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/git/contrib/subtree/git-subtree.sh' # original
remove_cmd '/mnt/wslg/distro/usr/lib/git-core/git-subtree' '/mnt/wslg/distro/usr/share/doc/git/contrib/subtree/git-subtree.sh' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/git/contrib/subtree/git-subtree' '/mnt/wslg/distro/usr/share/doc/git/contrib/subtree/git-subtree.sh' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_idioms.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_idioms.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_idioms.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/glib-networking-services/copyright' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/glib-networking-common/copyright' '/mnt/wslg/distro/usr/share/doc/glib-networking-services/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/glib-networking/copyright' '/mnt/wslg/distro/usr/share/doc/glib-networking-services/copyright' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/libvorbisenc2/copyright' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/libvorbis0a/copyright' '/mnt/wslg/distro/usr/share/doc/libvorbisenc2/copyright' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/archive_util.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/archive_util.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/archive_util.py' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/archive_util.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/archive_util.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/bcppcompiler.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/bcppcompiler.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/bcppcompiler.py' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/bcppcompiler.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/bcppcompiler.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/cmd.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/cmd.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/cmd.py' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/cmd.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/cmd.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/command/bdist_dumb.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/command/bdist_dumb.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/command/bdist_dumb.py' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/command/bdist_dumb.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/command/bdist_dumb.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/command/bdist_rpm.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/command/bdist_rpm.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/command/bdist_rpm.py' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/command/bdist_rpm.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/command/bdist_rpm.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/command/build_clib.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/command/build_clib.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/command/build_clib.py' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/command/build_clib.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/command/build_clib.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/command/config.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/command/config.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/command/config.py' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/command/config.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/command/config.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/command/register.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/command/register.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/command/register.py' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/command/register.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/command/register.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/command/sdist.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/command/sdist.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/command/sdist.py' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/command/sdist.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/command/sdist.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/config.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/config.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/config.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/dep_util.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/dep_util.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/dep_util.py' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/dep_util.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/dep_util.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/fancy_getopt.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/fancy_getopt.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/fancy_getopt.py' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/fancy_getopt.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/fancy_getopt.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/file_util.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/file_util.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/file_util.py' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/file_util.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/file_util.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/msvc9compiler.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/msvc9compiler.py' '/mnt/wslg/distro/usr/lib/python3.10/distutils/msvc9compiler.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/text_file.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/text_file.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/text_file.py' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/text_file.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/text_file.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/packaging/_manylinux.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_vendor/packaging/_manylinux.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/packaging/_manylinux.py' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/pkg_resources/_vendor/packaging/_manylinux.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/packaging/_manylinux.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_vendor/packaging/_musllinux.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/pkg_resources/_vendor/packaging/_musllinux.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_vendor/packaging/_musllinux.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_vendor/packaging/tags.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/pkg_resources/_vendor/packaging/tags.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_vendor/packaging/tags.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_vendor/packaging/specifiers.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/pkg_resources/_vendor/packaging/specifiers.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_vendor/packaging/specifiers.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/packaging/utils.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_vendor/packaging/utils.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/packaging/utils.py' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/pkg_resources/_vendor/packaging/utils.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/packaging/utils.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/packaging/version.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_vendor/packaging/version.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/packaging/version.py' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/pkg_resources/_vendor/packaging/version.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/packaging/version.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/command/install_egg_info.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/command/install_egg_info.py' '/mnt/wslg/distro/usr/lib/python3.10/distutils/command/install_egg_info.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/rmlint-gui/copyright' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/rmlint/copyright' '/mnt/wslg/distro/usr/share/doc/rmlint-gui/copyright' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_exitfunc.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_exitfunc.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_exitfunc.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/lazr.restfulclient-0.14.4.egg-info/namespace_packages.txt' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/lazr.restfulclient-0.14.4.egg-info/top_level.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/lazr.restfulclient-0.14.4.egg-info/namespace_packages.txt' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/lazr.uri-1.0.6.egg-info/namespace_packages.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/lazr.restfulclient-0.14.4.egg-info/namespace_packages.txt' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/lazr.uri-1.0.6.egg-info/top_level.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/lazr.restfulclient-0.14.4.egg-info/namespace_packages.txt' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_numliterals.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_numliterals.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_numliterals.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/alsa/ucm2/MediaTek/mt8390-evk/HiFi.conf' # original
remove_cmd '/mnt/wslg/distro/usr/share/alsa/ucm2/MediaTek/mt8370-evk/HiFi.conf' '/mnt/wslg/distro/usr/share/alsa/ucm2/MediaTek/mt8390-evk/HiFi.conf' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/ucf/cache/:etc:papersize' # original
remove_cmd '/mnt/wslg/distro/etc/papersize' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:papersize' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/emacsen-common/packages/compat/emacsen-common' # original
remove_cmd '/mnt/wslg/distro/usr/lib/emacsen-common/packages/compat/dictionaries-common' '/mnt/wslg/distro/usr/lib/emacsen-common/packages/compat/emacsen-common' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/__main__.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/__main__.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/__main__.py' # duplicate
original_cmd '/mnt/wslg/distro/etc/subgid' # original
remove_cmd '/mnt/wslg/distro/etc/subuid' '/mnt/wslg/distro/etc/subgid' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/demo/Artist One Demo/Title One/01 - Song One.mp3' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/demo/Artist One Demo/Title One/02 - Song Two.mp3' '/mnt/wslg/distro/var/www/html/zina/zina/demo/Artist One Demo/Title One/01 - Song One.mp3' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/regen.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/regen_genres.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/regen.gif' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/images/missing_search.jpg' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/images/missing_sub.jpg' '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/images/missing_search.jpg' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/stars-3.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/zinamp/skins/WinampClassic/images/stars-3.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/stars-3.gif' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/forward.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/forward.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/forward.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/forward.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/forward.gif' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/rss.png' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/rss.png' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/rss.png' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/rss.png' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/rss.png' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/rss.png' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/rss.png' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/images/missing_playlist.jpg' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/images/missing_playlist.jpg' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/images/missing_playlist.jpg' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/images/missing_playlist.jpg' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/images/missing_playlist.jpg' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/images/missing_playlist.jpg' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/images/missing_playlist.jpg' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/images/missing_dir.jpg' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/images/missing_dir.jpg' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/images/missing_dir.jpg' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/images/missing_dir.jpg' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/images/missing_dir.jpg' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/images/missing_genre.jpg' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/images/missing_genre.jpg' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/images/missing_genre.jpg' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/images/missing_genre.jpg' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/images/missing_genre.jpg' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/images/missing_genre.jpg' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/images/missing_genre.jpg' # duplicate
original_cmd '/mnt/wslg/doc/FreeRDP/LICENSE' # original
remove_cmd '/mnt/wslg/distro/usr/share/common-licenses/Apache-2.0' '/mnt/wslg/doc/FreeRDP/LICENSE' # duplicate
original_cmd '/mnt/wslg/doc/systemd/LICENSE.LGPL2.1' # original
remove_cmd '/mnt/wslg/distro/usr/share/common-licenses/LGPL-2.1' '/mnt/wslg/doc/systemd/LICENSE.LGPL2.1' # duplicate
original_cmd '/mnt/wslg/doc/systemd/LICENSES/CC0-1.0.txt' # original
remove_cmd '/mnt/wslg/distro/usr/share/common-licenses/CC0-1.0' '/mnt/wslg/doc/systemd/LICENSES/CC0-1.0.txt' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_xrange.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_xrange.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_xrange.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/python3-pkg-resources/copyright' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/python3-setuptools/copyright' '/mnt/wslg/distro/usr/share/doc/python3-pkg-resources/copyright' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/rename.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/rename.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/rename.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/rename.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/rename.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/chardet/cli/__init__.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/sortedcontainers-2.1.0.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/jsonschema-3.2.0.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/pyparsing-2.4.7.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/certifi-2020.6.20.egg-info/not-zip-safe' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/certifi-2020.6.20.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/llfuse-1.3.8.egg-info/zip-safe' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/async_generator-1.10.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/colorama-0.4.4.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/chardet-4.0.0.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/SecretStorage-3.3.1.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/importlib_metadata-4.6.4.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/cryptography-3.4.8.egg-info/not-zip-safe' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/lazr.restfulclient-0.14.4.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/lazr.restfulclient-0.14.4.egg-info/not-zip-safe' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/ruamel.yaml-0.17.16.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/llfuse-1.3.8.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/borgmatic-1.5.20.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/more_itertools-8.10.0.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/outcome-1.1.0.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/sniffio-1.2.0.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/trio-0.19.0.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/httplib2-0.20.2.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/packaging-21.3.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/lazr.uri-1.0.6.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/lazr.uri-1.0.6.egg-info/not-zip-safe' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/attrs-21.2.0.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/attrs-21.2.0.egg-info/not-zip-safe' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/colorlog-6.6.0.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/keyring-23.5.0.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/launchpadlib-1.10.16.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/launchpadlib-1.10.16.egg-info/not-zip-safe' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/borgbackup-1.2.0.egg-info/not-zip-safe' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/borgbackup-1.2.0.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/pyfuse3-3.2.0.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/pyfuse3-3.2.0.egg-info/zip-safe' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/msgpack-1.0.3.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/ruamel.yaml.clib-0.2.6.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/dbus_python-1.2.18.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/pyrsistent-0.18.1.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/six-1.16.0.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/PyGObject-3.42.1.egg-info/not-zip-safe' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/PyGObject-3.42.1.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/PyJWT-2.3.0.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/PyJWT-2.3.0.egg-info/not-zip-safe' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/oauthlib-3.2.0.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/gcc/python/libstdcxx/__init__.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/requests-2.25.1.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/requests-2.25.1.egg-info/not-zip-safe' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/cryptography-3.4.8.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/idna-3.3.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/zipp-1.0.0.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/python_apt-2.4.0+ubuntu4.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools-59.6.0.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/urllib3-1.26.5.egg-info/dependency_links.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/wadllib-1.3.6.egg-info/not-zip-safe' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_vendor/packaging/_structures.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/pkg_resources/_vendor/packaging/_structures.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_vendor/packaging/_structures.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_funcattrs.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_funcattrs.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_funcattrs.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/pgen2/literals.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/pgen2/literals.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/pgen2/literals.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_set_literal.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_set_literal.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_set_literal.py' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/play_lofi.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/play_lofi_custom.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/play_lofi.gif' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/first.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/first.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/first.gif' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/first_un.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/first_un.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/first_un.gif' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/images/missing_search.jpg' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/images/missing_search.jpg' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/images/missing_search.jpg' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/images/missing_search.jpg' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/images/missing_search.jpg' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/images/missing_sub.jpg' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/images/missing_search.jpg' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/images/missing_sub.jpg' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/images/missing_search.jpg' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/images/missing_sub.jpg' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/images/missing_search.jpg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/libwine/NEWS.Debian.gz' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/fonts-wine/NEWS.Debian.gz' '/mnt/wslg/distro/usr/share/doc/libwine/NEWS.Debian.gz' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/last_un.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/last_un.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/last_un.gif' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/mm/mov.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/mm/mov.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/mm/mov.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/mm/mov.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/mm/mov.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/mm/qt.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/mm/mov.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/mm/qt.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/mm/mov.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/mm/qt.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/mm/mov.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/empathy-offline.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/tray-offline.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/empathy-offline.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/user-offline-panel.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/empathy-offline.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/applications-chat-panel.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/empathy-available.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/applications-chat-panel.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/tray-online.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/applications-chat-panel.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/user-available-panel.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/applications-chat-panel.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-charged.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/unity-gpm-battery-charged.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-charged.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/xfpm-primary-charged.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-charged.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/xfpm-ups-charged.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-charged.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/im-message-new.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/tray-message.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/im-message-new.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/tray-new-im.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/im-message-new.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-storm.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-storm.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-storm.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-020.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-ups-020.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-020.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/unity-gpm-battery-020.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-020.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/xfpm-primary-020.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-020.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/xfpm-ups-020.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-020.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/pygram.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/pygram.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/pygram.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/categories/24/preferences-desktop-peripherals-directory.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/categories/24/preferences-desktop-peripherals-directory.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/categories/24/preferences-desktop-peripherals-directory.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/empathy-offline.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/tray-offline.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/empathy-offline.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/user-offline-panel.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/empathy-offline.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/24/gnome-netstatus-75-100.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/24/nm-device-wireless.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/24/gnome-netstatus-75-100.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/24/nm-signal-100.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/24/gnome-netstatus-75-100.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gnome-netstatus-75-100.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/nm-device-wireless.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gnome-netstatus-75-100.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/nm-signal-100.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gnome-netstatus-75-100.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gtk-dialog-authentication-panel.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/krb-valid-ticket.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gtk-dialog-authentication-panel.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/24/gnome-netstatus-0-24.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/24/nm-signal-25.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/24/gnome-netstatus-0-24.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gnome-netstatus-0-24.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/nm-signal-25.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gnome-netstatus-0-24.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-mouse-100.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-mouse-100.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-mouse-100.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/24/gnome-netstatus-error.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/24/network-error.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/24/gnome-netstatus-error.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gnome-netstatus-error.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/network-error.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gnome-netstatus-error.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/empathy-busy.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/tray-busy.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/empathy-busy.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/user-busy-panel.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/empathy-busy.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/24/nm-signal-0.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/24/nm-signal-00.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/24/nm-signal-0.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/nm-signal-0.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/nm-signal-00.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/nm-signal-0.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-phone-000.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-phone-000.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-phone-000.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-phone-000.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-phone-000.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-phone-000.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/audio-volume-muted-blocking-panel.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/22/audio-volume-muted-blocking-panel.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/audio-volume-muted-blocking-panel.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/connect_no.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gnome-netstatus-disconn.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/connect_no.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/network-offline.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/connect_no.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/nm-no-connection.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/connect_no.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/stock_disconnect.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/connect_no.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gnome-netstatus-75-100.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/nm-signal-100.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gnome-netstatus-75-100.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gsm-3g-full.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/nm-device-wwan.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gsm-3g-full.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gnome-netstatus-rx.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/network-receive.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gnome-netstatus-rx.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gnome-netstatus-0-24.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/nm-signal-25.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gnome-netstatus-0-24.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-mouse-060.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-mouse-060.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-mouse-060.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gnome-netstatus-tx.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/network-transmit.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gnome-netstatus-tx.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gnome-netstatus-25-49.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/nm-signal-50.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gnome-netstatus-25-49.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-mouse-000.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-mouse-000.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-mouse-000.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-phone-060.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-phone-060.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-phone-060.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-phone-100.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-phone-100.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-phone-100.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-phone-060.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-phone-060.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-phone-060.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-phone-100.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-phone-100.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-phone-100.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/connect_no.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gnome-netstatus-disconn.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/connect_no.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/network-offline.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/connect_no.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/nm-no-connection.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/connect_no.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_disconnect.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/connect_no.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/connect_no.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gnome-netstatus-disconn.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/connect_no.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/network-offline.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/connect_no.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/nm-no-connection.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/connect_no.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_disconnect.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/connect_no.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-cloudy.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-overcast.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-cloudy.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/empathy-extended-away.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/tray-extended-away.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/empathy-extended-away.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/user-idle-panel.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/empathy-extended-away.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/im-message-new.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/tray-message.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/im-message-new.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/tray-new-im.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/im-message-new.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/nm-secure-lock.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/nm-vpn-active-lock.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/nm-secure-lock.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/nm-vpn-lock.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/nm-secure-lock.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/applications-chat-panel.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/empathy-available.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/applications-chat-panel.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/tray-online.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/applications-chat-panel.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/user-available-panel.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/applications-chat-panel.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-060.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-ups-060.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-060.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/unity-battery-060.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-060.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/unity-gpm-battery-060.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-060.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-primary-060.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-060.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-ups-060.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-060.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-100.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-ups-100.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-100.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/unity-battery-100.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-100.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/unity-battery_full.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-100.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/unity-gpm-battery-100.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-100.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-primary-100.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-100.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-ups-100.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-100.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-100.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-ups-100.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-100.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/unity-battery-100.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-100.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/unity-battery_full.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-100.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/unity-gpm-battery-100.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-100.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/xfpm-primary-100.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-100.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/xfpm-ups-100.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-100.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-060.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-ups-060.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-060.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/unity-battery-060.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-060.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/unity-gpm-battery-060.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-060.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-primary-060.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-060.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-ups-060.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-060.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-060.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-ups-060.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-060.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/unity-battery-060.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-060.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/unity-gpm-battery-060.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-060.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/xfpm-primary-060.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-060.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/xfpm-ups-060.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-060.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-080.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-ups-080.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-080.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/unity-battery-080.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-080.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/unity-gpm-battery-080.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-080.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-primary-080.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-080.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-ups-080.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-080.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-080.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-ups-080.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-080.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/unity-battery-080.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-080.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/unity-gpm-battery-080.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-080.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-primary-080.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-080.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-ups-080.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-080.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-100.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-ups-100.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-100.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/unity-battery-100.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-100.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/unity-battery_full.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-100.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/unity-gpm-battery-100.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-100.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-primary-100.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-100.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-ups-100.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-100.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-080.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-ups-080.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-080.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/unity-battery-080.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-080.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/unity-gpm-battery-080.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-080.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/xfpm-primary-080.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-080.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/xfpm-ups-080.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-080.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-000.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-ups-000.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-ups-missing.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/unity-battery-000.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/unity-battery_empty.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/unity-gpm-battery-000.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/unity-gpm-battery-empty.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/unity-gpm-battery-missing.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-primary-000.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-primary-missing.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-ups-000.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-ups-missing.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-000.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-000.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-ups-000.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-ups-missing.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/unity-battery-000.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/unity-battery_empty.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/unity-gpm-battery-000.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/unity-gpm-battery-empty.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/unity-gpm-battery-missing.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-primary-000.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-primary-missing.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-ups-000.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-ups-missing.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-000.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-000.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-ups-000.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-ups-missing.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/unity-battery-000.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/unity-battery_empty.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/unity-gpm-battery-000.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/unity-gpm-battery-empty.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/unity-gpm-battery-missing.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/xfpm-primary-000.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/xfpm-primary-missing.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/xfpm-ups-000.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/xfpm-ups-missing.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-000.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-fog.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-fog.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-fog.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-fog.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-fog.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-fog.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/animations/24/nm-stage01-connecting11.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/animations/24/nm-stage01-connecting11.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/animations/24/nm-stage01-connecting11.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/animations/22/nm-stage01-connecting02.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/animations/24/nm-stage01-connecting02.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/animations/22/nm-stage01-connecting02.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/animations/22/nm-stage01-connecting02.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/animations/22/nm-stage01-connecting02.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/animations/24/nm-stage01-connecting02.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/animations/22/nm-stage01-connecting02.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/animations/22/nm-stage01-connecting01.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/animations/24/nm-stage01-connecting01.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/animations/22/nm-stage01-connecting01.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/animations/22/nm-stage01-connecting01.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/animations/22/nm-stage01-connecting01.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/animations/24/nm-stage01-connecting01.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/animations/22/nm-stage01-connecting01.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/places/32/user-home.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/places/32/user-home.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/places/32/user-home.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/places/24/user-home.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/places/24/user-home.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/places/24/user-home.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/places/22/user-home.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/places/22/user-home.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/places/22/user-home.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/places/48/folder-home.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/places/48/folder-home.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/places/48/folder-home.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/places/16/user-home.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/places/16/user-home.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/places/16/user-home.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/actions/16/window-close-symbolic.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/actions/16/window-close-symbolic.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/actions/16/window-close-symbolic.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/LoginIcons/apps/22/go-home.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/LoginIcons/apps/22/session-properties.svg' '/mnt/wslg/distro/usr/share/icons/LoginIcons/apps/22/go-home.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/libjson-glib-1.0-0/copyright' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/libjson-glib-1.0-common/copyright' '/mnt/wslg/distro/usr/share/doc/libjson-glib-1.0-0/copyright' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/22x22/mimetypes/application-x-generic.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/22x22/mimetypes/text-x-preview.png' '/mnt/wslg/distro/usr/share/icons/Adwaita/22x22/mimetypes/application-x-generic.png' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/mm/mov.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/mm/qt.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/mm/mov.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_input.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_input.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_input.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/96x96/actions/edit-find-symbolic.symbolic.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/96x96/actions/system-search-symbolic.symbolic.png' '/mnt/wslg/distro/usr/share/icons/Adwaita/96x96/actions/edit-find-symbolic.symbolic.png' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/command/install_headers.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/command/install_headers.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/command/install_headers.py' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/command/install_headers.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/command/install_headers.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_ws_comma.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_ws_comma.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_ws_comma.py' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/last.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/last.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/last.gif' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/back.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/back_un.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/back.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-040.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-ups-040.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-040.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/unity-gpm-battery-040.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-040.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/xfpm-primary-040.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-040.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/xfpm-ups-040.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-040.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/unity-ac-adapter-symbolic.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/unity-battery_plugged.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/unity-ac-adapter-symbolic.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-ac-adapter.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/unity-ac-adapter-symbolic.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/unity-ac-adapter-symbolic.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/unity-battery_plugged.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/unity-ac-adapter-symbolic.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-ac-adapter.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/unity-ac-adapter-symbolic.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_sys_exc.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_sys_exc.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_sys_exc.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/applications-email-panel.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/indicator-messages.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/applications-email-panel.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/applications-email-panel.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/indicator-messages.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/applications-email-panel.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/applications-email-panel.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/indicator-messages.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/applications-email-panel.svg' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/last.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/last_un.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/last.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/sidebar-show-right-rtl-symbolic.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/sidebar-show-symbolic.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/sidebar-show-right-rtl-symbolic.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/empathy-away.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/tray-away.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/empathy-away.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/user-away-panel.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/empathy-away.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/application-exit-symbolic.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/system-log-out-symbolic.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/application-exit-symbolic.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/document-open-recent-symbolic.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/categories/emoji-recent-symbolic.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/document-open-recent-symbolic.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_vendor/packaging/__about__.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/pkg_resources/_vendor/packaging/__about__.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_vendor/packaging/__about__.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/empathy-busy.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/tray-busy.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/empathy-busy.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/user-busy-panel.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/empathy-busy.svg' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/mm/avi.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/mm/mpg.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/mm/avi.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/mm/wmv.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/mm/avi.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/mm/mpeg.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/mm/avi.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/mm/asf.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/mm/avi.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/actions/16/window-maximize-symbolic.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/actions/16/window-maximize-symbolic.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/actions/16/window-maximize-symbolic.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/command/__init__.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/command/__init__.py' '/mnt/wslg/distro/usr/lib/python3.10/distutils/command/__init__.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/emblems/emblem-favorite-symbolic.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/emotes/emote-love-symbolic.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/emblems/emblem-favorite-symbolic.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/stock/64/album_artwork.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/stock/64/album_artwork.png' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/stock/64/album_artwork.png' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/ucf/cache/:etc:profile.d:debuginfod.csh' # original
remove_cmd '/mnt/wslg/distro/etc/profile.d/debuginfod.csh' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:profile.d:debuginfod.csh' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/ui/pan-end-symbolic-rtl.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/ui/pan-start-symbolic.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/ui/pan-end-symbolic-rtl.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/ui/pan-end-symbolic.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/ui/pan-start-symbolic-rtl.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/ui/pan-end-symbolic.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/legacy/battery-empty-charging-symbolic.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/status/battery-level-0-charging-symbolic.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/legacy/battery-empty-charging-symbolic.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/aspell/british-ize-wo_accents.alias' # original
remove_cmd '/mnt/wslg/distro/usr/lib/aspell/en_GB-ize.multi' '/mnt/wslg/distro/usr/lib/aspell/british-ize-wo_accents.alias' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/aspell/british-ise-wo_accents.alias' # original
remove_cmd '/mnt/wslg/distro/usr/lib/aspell/en_GB-ise.multi' '/mnt/wslg/distro/usr/lib/aspell/british-ise-wo_accents.alias' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/aspell/en_GB-wo_accents.multi' '/mnt/wslg/distro/usr/lib/aspell/british-ise-wo_accents.alias' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/aspell/en_GB.multi' '/mnt/wslg/distro/usr/lib/aspell/british-ise-wo_accents.alias' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/16x16/actions/format-justify-fill-symbolic.symbolic.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/16x16/actions/open-menu-symbolic.symbolic.png' '/mnt/wslg/distro/usr/share/icons/Adwaita/16x16/actions/format-justify-fill-symbolic.symbolic.png' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/aspell/en.multi' # original
remove_cmd '/mnt/wslg/distro/usr/lib/aspell/english-wo_accents.alias' '/mnt/wslg/distro/usr/lib/aspell/en.multi' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/16x16/actions/edit-find-symbolic.symbolic.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/16x16/actions/system-search-symbolic.symbolic.png' '/mnt/wslg/distro/usr/share/icons/Adwaita/16x16/actions/edit-find-symbolic.symbolic.png' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_repr.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_repr.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_repr.py' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/play_video.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/play_video.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/play_video.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/play_video.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/play_video.gif' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/ucf/cache/:etc:profile.d:debuginfod.sh' # original
remove_cmd '/mnt/wslg/distro/etc/profile.d/debuginfod.sh' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:profile.d:debuginfod.sh' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_reduce.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_reduce.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_reduce.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/512x512/mimetypes/application-x-generic.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/512x512/mimetypes/text-x-preview.png' '/mnt/wslg/distro/usr/share/icons/Adwaita/512x512/mimetypes/application-x-generic.png' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/rss.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/rss.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/rss.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/rss.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/rss.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/rss.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/rss.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/go-first-symbolic-rtl.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/go-last-symbolic.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/go-first-symbolic-rtl.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_raw_input.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_raw_input.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_raw_input.py' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/back.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/back.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/back.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/back.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/back.gif' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/more.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/more.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/more.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/more.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/more.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/status/network-wireless-encrypted-symbolic.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/status/system-lock-screen-symbolic.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/status/network-wireless-encrypted-symbolic.svg' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/stars-5.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/zinamp/skins/WinampClassic/images/stars-5.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/stars-5.gif' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/stars-0.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/zinamp/skins/WinampClassic/images/stars-0.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/stars-0.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/go-next-symbolic-rtl.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/go-previous-symbolic.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/go-next-symbolic-rtl.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/packaging/__init__.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_vendor/packaging/__init__.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/packaging/__init__.py' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/pkg_resources/_vendor/packaging/__init__.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/packaging/__init__.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/cryptography/hazmat/bindings/openssl/__init__.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/cryptography/hazmat/bindings/__init__.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/cryptography/hazmat/bindings/openssl/__init__.py' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/cryptography/hazmat/primitives/__init__.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/cryptography/hazmat/bindings/openssl/__init__.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/ui/selection-end-symbolic-rtl.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/ui/selection-start-symbolic.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/ui/selection-end-symbolic-rtl.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/libdecor-0-0/copyright' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/libdecor-0-plugin-1-cairo/copyright' '/mnt/wslg/distro/usr/share/doc/libdecor-0-0/copyright' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/go-next-symbolic.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/go-previous-symbolic-rtl.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/go-next-symbolic.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/go-first-symbolic.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/go-last-symbolic-rtl.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/go-first-symbolic.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/16x16/mimetypes/application-x-generic.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/16x16/mimetypes/text-x-preview.png' '/mnt/wslg/distro/usr/share/icons/Adwaita/16x16/mimetypes/application-x-generic.png' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/48x48/actions/edit-find-symbolic.symbolic.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/48x48/actions/system-search-symbolic.symbolic.png' '/mnt/wslg/distro/usr/share/icons/Adwaita/48x48/actions/edit-find-symbolic.symbolic.png' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/48x48/mimetypes/application-x-generic.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/48x48/mimetypes/text-x-preview.png' '/mnt/wslg/distro/usr/share/icons/Adwaita/48x48/mimetypes/application-x-generic.png' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/delete_imgs_cache.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/delete_imgs_cache.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/delete_imgs_cache.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/delete_imgs_cache.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/delete_imgs_cache.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/delete_imgs_cache.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/delete_imgs_cache.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-snow.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-snow.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-snow.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gtk-dialog-authentication-panel.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/krb-valid-ticket.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gtk-dialog-authentication-panel.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-mouse-060.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-mouse-060.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-mouse-060.svg' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/stars-4.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/stars-4.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/stars-4.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/zinamp/skins/Silver/images/stars-4.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/stars-4.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/im-message-new.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/tray-message.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/im-message-new.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/tray-new-im.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/im-message-new.svg' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/en.php' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/en.php' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/en.php' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_basestring.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_basestring.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_basestring.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/COPYING' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/COPYING' '/mnt/wslg/distro/usr/share/icons/Humanity/COPYING' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/audio-volume-low.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/24/audio-volume-low.png' '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/audio-volume-low.png' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/audio-volume-high.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/24/audio-volume-high.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/audio-volume-high.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/audio-volume-medium.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/24/audio-volume-medium.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/audio-volume-medium.svg' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/sync_db.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/sync_db.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/sync_db.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/sync_db.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/sync_db.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/sync_db.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/sync_db.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_asserts.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_asserts.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_asserts.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/audio-volume-low.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/24/audio-volume-low.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/audio-volume-low.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-few-clouds.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-few-clouds.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/22/audio-volume-muted.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/22/audio-volume-muted.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/22/audio-volume-muted.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/22/audio-volume-low.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/22/audio-volume-low.png' '/mnt/wslg/distro/usr/share/icons/Humanity/status/22/audio-volume-low.png' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/22/indicator-messages-new.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/22/indicator-messages-new.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/22/indicator-messages-new.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/22/audio-volume-high.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/22/audio-volume-high.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/22/audio-volume-high.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_isinstance.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_isinstance.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_isinstance.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/22/audio-volume-medium.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/22/audio-volume-medium.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/22/audio-volume-medium.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/22/battery_two_thirds.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/22/gpm-battery-060.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/22/battery_two_thirds.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/22/battery_two_thirds.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/22/gpm-battery-060.svg' '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/22/battery_two_thirds.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/22/network-error.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/22/network-error.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/22/network-error.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/network-error.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/24/network-error.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/network-error.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/22/audio-volume-high.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/22/audio-volume-high.png' '/mnt/wslg/distro/usr/share/icons/Humanity/status/22/audio-volume-high.png' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/22/audio-volume-low.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/22/audio-volume-low.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/22/audio-volume-low.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/gpm-battery-charged.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/24/gpm-battery-charged.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/gpm-battery-charged.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/22/gpm-battery-charged.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/22/gpm-battery-charged.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/22/gpm-battery-charged.svg' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/play_lofi_custom.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/play_lofi_custom.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/play_lofi_custom.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/play_lofi_custom.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/play_lofi_custom.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/weather-clouds.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/48/weather-clouds.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/weather-clouds.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/weather-showers-scattered.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/48/weather-showers-scattered.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/weather-showers-scattered.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/battery_full.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/48/battery_full.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/battery_full.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/weather-severe-alert.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/48/weather-severe-alert.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/weather-severe-alert.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/weather-showers.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/48/weather-showers.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/weather-showers.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/weather-overcast.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/48/weather-overcast.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/weather-overcast.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/weather-snow.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/48/weather-snow.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/weather-snow.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/battery_charged.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/48/battery_charged.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/battery_charged.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/gpm-primary-100-charging.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/48/gpm-primary-100-charging.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/gpm-primary-100-charging.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/gpm-primary-060.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/48/gpm-primary-060.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/gpm-primary-060.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/gpm-primary-080.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/48/gpm-primary-080.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/gpm-primary-080.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/battery_empty.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/48/battery_empty.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/battery_empty.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/weather-storm.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/48/weather-storm.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/weather-storm.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/weather-clear.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/48/weather-clear.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/weather-clear.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/weather-fog.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/48/weather-fog.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/weather-fog.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/16/audio-volume-muted.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/16/audio-volume-muted.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/16/audio-volume-muted.svg' # duplicate
original_cmd '/mnt/wslg/distro/etc/profile' # original
remove_cmd '/mnt/wslg/distro/usr/share/base-files/profile' '/mnt/wslg/distro/etc/profile' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/16/audio-volume-high.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/16/audio-volume-high.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/16/audio-volume-high.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/16/audio-volume-medium.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/16/audio-volume-medium.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/16/audio-volume-medium.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/16/audio-volume-muted-blocked-panel.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/16/audio-volume-muted-blocked-panel.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/16/audio-volume-muted-blocked-panel.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-020-charging.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-ups-020-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-020-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/unity-battery-020-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-020-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/unity-gpm-battery-020-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-020-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-primary-020-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-020-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-ups-020-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-020-charging.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-020-charging.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-ups-020-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-020-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/unity-battery-020-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-020-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/unity-gpm-battery-020-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-020-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-primary-020-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-020-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-ups-020-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-020-charging.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/16/audio-volume-low.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/16/audio-volume-low.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/16/audio-volume-low.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/24x24/actions/edit-find-symbolic.symbolic.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/24x24/actions/system-search-symbolic.symbolic.png' '/mnt/wslg/distro/usr/share/icons/Adwaita/24x24/actions/edit-find-symbolic.symbolic.png' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/16/bluetooth-disabled.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/16/bluetooth-disabled.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/16/bluetooth-disabled.svg' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/ucf/registry' # original
remove_cmd '/mnt/wslg/distro/var/lib/ucf/registry.1' '/mnt/wslg/distro/var/lib/ucf/registry' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/16/gpm-battery-charged.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/16/gpm-battery-charged.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/16/gpm-battery-charged.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_operator.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_operator.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_operator.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-presentation.icon' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/32/emblem-presentation.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-presentation.icon' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-camera.icon' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/22/emblem-camera.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-camera.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/24/emblem-camera.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-camera.icon' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-money.icon' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/32/emblem-money.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-money.icon' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-photos.icon' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/32/emblem-photos.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-photos.icon' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-multimedia.icon' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/24/emblem-multimedia.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-multimedia.icon' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-draft.icon' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/32/emblem-draft.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-draft.icon' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-favorite.icon' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/24/emblem-favorite.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-favorite.icon' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-sales.icon' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/32/emblem-sales.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-sales.icon' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-marketing.icon' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/32/emblem-marketing.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-marketing.icon' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-ohno.icon' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-ohno.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-ohno.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/22/emblem-ohno.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-ohno.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/32/emblem-ohno.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-ohno.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/24/emblem-ohno.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-ohno.icon' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-new.icon' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-new.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-new.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/22/emblem-new.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-new.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/32/emblem-new.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-new.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/24/emblem-new.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-new.icon' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-art.icon' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-art.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-art.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/22/emblem-art.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-art.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/32/emblem-art.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-art.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/24/emblem-art.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-art.icon' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-desktop.icon' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-desktop.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-desktop.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/22/emblem-desktop.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-desktop.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/32/emblem-desktop.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-desktop.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/24/emblem-desktop.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-desktop.icon' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-development.icon' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-development.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-development.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/22/emblem-development.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-development.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/32/emblem-development.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-development.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/24/emblem-development.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-development.icon' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-cool.icon' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-cool.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-cool.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/22/emblem-cool.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-cool.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/32/emblem-cool.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-cool.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/24/emblem-cool.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-cool.icon' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-personal.icon' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-personal.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-personal.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/22/emblem-personal.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-personal.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/32/emblem-personal.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-personal.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/24/emblem-personal.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-personal.icon' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-OK.icon' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-OK.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-OK.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/22/emblem-OK.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-OK.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/32/emblem-OK.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-OK.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/24/emblem-OK.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-OK.icon' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-shared.icon' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/24/emblem-shared.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-shared.icon' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-videos.icon' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-videos.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-videos.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/22/emblem-videos.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-videos.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/32/emblem-videos.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-videos.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/24/emblem-videos.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-videos.icon' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-system.icon' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-system.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-system.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/22/emblem-system.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-system.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/32/emblem-system.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-system.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/24/emblem-system.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-system.icon' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/patcomp.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/patcomp.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/patcomp.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/audio-volume-muted.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/24/audio-volume-muted.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/audio-volume-muted.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/places/22/start-here.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/places/22/start-here.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/places/22/start-here.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/apps/22/distributor-logo.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/places/22/start-here.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/apps/22/distributor-logo.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/places/22/start-here.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/places/48/start-here.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/places/48/start-here.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/places/48/start-here.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/places/16/start-here.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/places/16/start-here.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/places/16/start-here.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/apps/16/distributor-logo.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/places/16/start-here.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/apps/16/distributor-logo.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/places/16/start-here.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/readline/inputrc' # original
remove_cmd '/mnt/wslg/distro/etc/inputrc' '/mnt/wslg/distro/usr/share/readline/inputrc' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/gpm-primary-040.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/48/gpm-primary-040.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/gpm-primary-040.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-100-charging.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-ups-100-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-100-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/unity-battery-100-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-100-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/unity-gpm-battery-100-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-100-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-primary-100-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-100-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-ups-100-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-100-charging.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/actions/24/mail-send.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/places/24/mail-sent.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/actions/24/mail-send.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-plan.icon' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/32/emblem-plan.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-plan.icon' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/actions/22/mail-send.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/places/22/mail-sent.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/actions/22/mail-send.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-keyboard-060.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-keyboard-060.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-keyboard-060.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gnome-netstatus-25-49.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/nm-signal-50.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gnome-netstatus-25-49.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/24/gnome-netstatus-25-49.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/24/nm-signal-50.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/24/gnome-netstatus-25-49.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/actions/16/mail-send.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/places/16/mail-sent.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/actions/16/mail-send.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/audio-volume-muted-panel.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfce4-mixer-muted.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/audio-volume-muted-panel.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfce4-mixer-volume-muted.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/audio-volume-muted-panel.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/actions/16/system-shutdown-restart-panel.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/actions/16/system-shutdown-restart-panel.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/actions/16/system-shutdown-restart-panel.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/applications-chat-panel.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/empathy-available.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/applications-chat-panel.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/tray-online.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/applications-chat-panel.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/user-available-panel.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/applications-chat-panel.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/nm-secure-lock.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/nm-vpn-active-lock.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/nm-secure-lock.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/nm-vpn-lock.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/nm-secure-lock.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/im-message-new.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/tray-message.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/im-message-new.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/tray-new-im.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/im-message-new.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/nm-secure-lock.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/nm-vpn-active-lock.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/nm-secure-lock.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/nm-vpn-lock.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/nm-secure-lock.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage01-connecting11.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/24/nm-stage01-connecting11.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage01-connecting11.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage02-connecting01.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/24/nm-stage02-connecting01.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage02-connecting01.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage02-connecting02.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/24/nm-stage02-connecting02.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage02-connecting02.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-vpn-connecting01.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/24/nm-vpn-connecting01.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-vpn-connecting01.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-vpn-connecting02.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/24/nm-vpn-connecting02.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-vpn-connecting02.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage01-connecting08.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/24/nm-stage01-connecting08.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage01-connecting08.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage01-connecting06.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/24/nm-stage01-connecting06.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage01-connecting06.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage01-connecting02.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/24/nm-stage01-connecting02.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage01-connecting02.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage03-connecting02.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/24/nm-stage03-connecting02.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage03-connecting02.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage03-connecting01.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/24/nm-stage03-connecting01.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage03-connecting01.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage02-connecting04.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/24/nm-stage02-connecting04.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage02-connecting04.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-vpn-connecting04.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/24/nm-vpn-connecting04.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-vpn-connecting04.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage02-connecting03.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/24/nm-stage02-connecting03.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage02-connecting03.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage01-connecting10.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/24/nm-stage01-connecting10.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage01-connecting10.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/pgen2/parse.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/pgen2/parse.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/pgen2/parse.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/gpm-primary-020-charging.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/48/gpm-primary-020-charging.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/gpm-primary-020-charging.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/gpm-primary-040-charging.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/48/gpm-primary-040-charging.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/gpm-primary-040-charging.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-vpn-connecting01.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/22/nm-vpn-connecting01.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-vpn-connecting01.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage01-connecting01.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/24/nm-stage01-connecting01.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage01-connecting01.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage01-connecting11.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/22/nm-stage01-connecting11.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage01-connecting11.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage02-connecting01.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/22/nm-stage02-connecting01.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage02-connecting01.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage02-connecting02.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/22/nm-stage02-connecting02.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage02-connecting02.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-vpn-connecting02.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/22/nm-vpn-connecting02.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-vpn-connecting02.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage02-connecting06.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/24/nm-stage02-connecting06.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage02-connecting06.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage02-connecting06.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/22/nm-stage02-connecting06.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage02-connecting06.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage01-connecting02.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/22/nm-stage01-connecting02.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage01-connecting02.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage01-connecting05.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/24/nm-stage01-connecting05.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage01-connecting05.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage01-connecting08.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/22/nm-stage01-connecting08.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage01-connecting08.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage01-connecting03.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/24/nm-stage01-connecting03.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage01-connecting03.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage01-connecting07.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/24/nm-stage01-connecting07.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage01-connecting07.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage01-connecting06.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/22/nm-stage01-connecting06.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage01-connecting06.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage03-connecting02.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/22/nm-stage03-connecting02.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage03-connecting02.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage03-connecting04.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/22/nm-stage03-connecting04.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage03-connecting04.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage03-connecting07.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/22/nm-stage03-connecting07.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage03-connecting07.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage03-connecting07.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/24/nm-stage03-connecting07.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage03-connecting07.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage03-connecting01.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/22/nm-stage03-connecting01.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage03-connecting01.svg' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/first.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/first_un.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/first.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage01-connecting09.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/22/nm-stage01-connecting09.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage01-connecting09.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage02-connecting04.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/22/nm-stage02-connecting04.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage02-connecting04.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage01-connecting04.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/22/nm-stage01-connecting04.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage01-connecting04.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage02-connecting11.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/22/nm-stage02-connecting11.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage02-connecting11.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage03-connecting09.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/24/nm-stage03-connecting09.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage03-connecting09.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage03-connecting09.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/22/nm-stage03-connecting09.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage03-connecting09.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage03-connecting11.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/22/nm-stage03-connecting11.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage03-connecting11.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage03-connecting11.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/24/nm-stage03-connecting11.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage03-connecting11.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage01-connecting05.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/22/nm-stage01-connecting05.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage01-connecting05.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage01-connecting03.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/22/nm-stage01-connecting03.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage01-connecting03.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage01-connecting07.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/22/nm-stage01-connecting07.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage01-connecting07.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/places/folder-saved-search-symbolic.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/apps/preferences-system-search-symbolic.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/places/folder-saved-search-symbolic.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage03-connecting08.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/22/nm-stage03-connecting08.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage03-connecting08.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage03-connecting10.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/24/nm-stage03-connecting10.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage03-connecting10.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage03-connecting08.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/24/nm-stage03-connecting08.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage03-connecting08.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage03-connecting10.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/22/nm-stage03-connecting10.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage03-connecting10.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/connect_creating.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/connect_established.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/connect_creating.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gnome-netstatus-idle.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/connect_creating.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gnome-netstatus-txrx.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/connect_creating.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/network-idle.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/connect_creating.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/network-transmit-receive.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/connect_creating.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/network-wired.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/connect_creating.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/nm-device-wired-autoip.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/connect_creating.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/nm-device-wired.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/connect_creating.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/connect_creating.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/connect_established.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/connect_creating.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gnome-netstatus-idle.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/connect_creating.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gnome-netstatus-txrx.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/connect_creating.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/network-idle.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/connect_creating.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/network-transmit-receive.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/connect_creating.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/network-wired.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/connect_creating.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/nm-device-wired-autoip.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/connect_creating.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/nm-device-wired.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/connect_creating.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/48/application-community.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/categories/48/application-community.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/48/application-community.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/48/gnome-display-properties.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/48/gsd-xrandr.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/48/gnome-display-properties.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/gpm-primary-020.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/48/gpm-primary-020.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/gpm-primary-020.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/16/application-community.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/categories/16/application-community.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/16/application-community.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/empathy-away.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/tray-away.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/empathy-away.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/user-away-panel.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/empathy-away.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/mimes/22/text-x-preview.icon' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/mimes/24/text-x-preview.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/mimes/22/text-x-preview.icon' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gnome-netstatus-50-74.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/nm-signal-75.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gnome-netstatus-50-74.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/32/application-community.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/categories/32/application-community.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/32/application-community.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/mimes/16/text-x-generic.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/mimes/16/x-office-document.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/mimes/16/text-x-generic.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/mimes/16/x-office-drawing.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/mimes/16/text-x-generic.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/mimes/16/x-office-spreadsheet.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/mimes/16/text-x-generic.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/nm-signal-0.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/nm-signal-00.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/nm-signal-0.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/devices/16/nm-device-wired.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/devices/16/nm-device-wired.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/devices/16/nm-device-wired.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/actions/16/window-minimize-symbolic.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/actions/16/window-minimize-symbolic.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/actions/16/window-minimize-symbolic.svg' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:readline.ini' # original
remove_cmd '/mnt/wslg/distro/usr/share/php8.1-readline/readline/readline.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:readline.ini' # duplicate
remove_cmd '/mnt/wslg/distro/etc/php/8.1/mods-available/readline.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:readline.ini' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/logout.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/logout.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/logout.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/logout.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/logout.gif' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/star-half.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/star-half.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/star-half.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-pictures.icon' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-pictures.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-pictures.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/22/emblem-pictures.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-pictures.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/32/emblem-pictures.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-pictures.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/24/emblem-pictures.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-pictures.icon' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/weather-few-clouds.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/48/weather-few-clouds.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/weather-few-clouds.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-mouse-000.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-mouse-000.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-mouse-000.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_zip.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_zip.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_zip.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/applications-email-panel.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/indicator-messages.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/applications-email-panel.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-060-charging.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-ups-060-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-060-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/unity-gpm-battery-060-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-060-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/xfpm-primary-060-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-060-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/xfpm-ups-060-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-060-charging.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-040-charging.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-ups-040-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-040-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/unity-gpm-battery-040-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-040-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/xfpm-primary-040-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-040-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/xfpm-ups-040-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-040-charging.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-080-charging.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-ups-080-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-080-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/unity-gpm-battery-080-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-080-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/xfpm-primary-080-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-080-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/xfpm-ups-080-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-080-charging.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/empathy-extended-away.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/tray-extended-away.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/empathy-extended-away.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/user-idle-panel.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/empathy-extended-away.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-020.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-ups-020.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-020.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/unity-battery-020.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-020.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/unity-battery-caution.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-020.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/unity-gpm-battery-020.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-020.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-primary-020.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-020.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-ups-020.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-020.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-020.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-ups-020.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-020.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/unity-battery-020.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-020.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/unity-battery-caution.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-020.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/unity-gpm-battery-020.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-020.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/xfpm-primary-020.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-020.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/xfpm-ups-020.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-020.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/libasound2/copyright' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/libasound2-data/copyright' '/mnt/wslg/distro/usr/share/doc/libasound2/copyright' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/log.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/log.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/log.py' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/log.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/log.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-charged.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/unity-battery-charged.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-charged.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/unity-battery_charged.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-charged.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/unity-gpm-battery-charged.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-charged.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-primary-charged.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-charged.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-ups-charged.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-charged.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-charged.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/unity-battery-charged.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-charged.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/unity-battery_charged.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-charged.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/unity-gpm-battery-charged.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-charged.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/xfpm-primary-charged.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-charged.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/xfpm-ups-charged.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-charged.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-charged.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/unity-battery-charged.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-charged.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/unity-battery_charged.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-charged.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/unity-gpm-battery-charged.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-charged.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-primary-charged.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-charged.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-ups-charged.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-charged.svg' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/stars-4.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/zinamp/skins/WinampClassic/images/stars-4.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/stars-4.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/groff/1.22.4/font/devascii/DESC' # original
remove_cmd '/mnt/wslg/distro/usr/share/groff/1.22.4/font/devlatin1/DESC' '/mnt/wslg/distro/usr/share/groff/1.22.4/font/devascii/DESC' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-few-clouds.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-few-clouds.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/extension.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/extension.py' '/mnt/wslg/distro/usr/lib/python3.10/distutils/extension.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_methodattrs.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_methodattrs.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_methodattrs.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/sidebar-show-right-symbolic.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/sidebar-show-rtl-symbolic.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/sidebar-show-right-symbolic.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/format-indent-less-symbolic.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/format-indent-more-symbolic-rtl.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/format-indent-less-symbolic.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/fuse/copyright' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/libfuse2/copyright' '/mnt/wslg/distro/usr/share/doc/fuse/copyright' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/bug/wine/control' # original
remove_cmd '/mnt/wslg/distro/usr/share/bug/wine64/control' '/mnt/wslg/distro/usr/share/bug/wine/control' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/bug/libwine/control' '/mnt/wslg/distro/usr/share/bug/wine/control' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/bug/fonts-wine/control' '/mnt/wslg/distro/usr/share/bug/wine/control' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/wine/copyright' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/wine64/copyright' '/mnt/wslg/distro/usr/share/doc/wine/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/libwine/copyright' '/mnt/wslg/distro/usr/share/doc/wine/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/fonts-wine/copyright' '/mnt/wslg/distro/usr/share/doc/wine/copyright' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/man/man1/wine-stable.1.gz' # original
remove_cmd '/mnt/wslg/distro/usr/share/man/man1/wine64-stable.1.gz' '/mnt/wslg/distro/usr/share/man/man1/wine-stable.1.gz' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_long.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_long.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_long.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/format-indent-less-symbolic-rtl.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/format-indent-more-symbolic.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/format-indent-less-symbolic-rtl.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/libgtksourceview-3.0-common/copyright' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/gir1.2-gtksource-3.0/copyright' '/mnt/wslg/distro/usr/share/doc/libgtksourceview-3.0-common/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/libgtksourceview-3.0-1/copyright' '/mnt/wslg/distro/usr/share/doc/libgtksourceview-3.0-common/copyright' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/aspell/british-ise-w_accents.alias' # original
remove_cmd '/mnt/wslg/distro/usr/lib/aspell/en_GB-w_accents.multi' '/mnt/wslg/distro/usr/lib/aspell/british-ise-w_accents.alias' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/delete_cache.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/delete_cache.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/delete_cache.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/delete_cache.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/delete_cache.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/delete_cache.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/delete_cache.gif' # duplicate
original_cmd '/mnt/wslg/distro/etc/networks' # original
remove_cmd '/mnt/wslg/distro/usr/share/base-files/networks' '/mnt/wslg/distro/etc/networks' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/16/battery_two_thirds.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/16/gpm-battery-060.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/16/battery_two_thirds.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_future.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_future.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_future.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/16/battery_two_thirds.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/16/gpm-battery-060.svg' '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/16/battery_two_thirds.svg' # duplicate
original_cmd '/mnt/wslg/distro/etc/services' # original
remove_cmd '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/etc/services' '/mnt/wslg/distro/etc/services' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/etc/ssl/openssl.cnf' # original
remove_cmd '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/etc/ssl/openssl.cnf.dist' '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/etc/ssl/openssl.cnf' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/lib/apk/db/triggers' # original
remove_cmd '/mnt/wslg/distro/var/lib/docker/overlay2/eb62213d5101cb801d7961f4b4b0c2032b533f87f8feba94c1e249dd90eb33a4/diff/lib/apk/db/triggers' '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/lib/apk/db/triggers' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/share/apk/keys/alpine-devel@lists.alpinelinux.org-6165ee59.rsa.pub' # original
remove_cmd '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/etc/apk/keys/alpine-devel@lists.alpinelinux.org-6165ee59.rsa.pub' '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/share/apk/keys/alpine-devel@lists.alpinelinux.org-6165ee59.rsa.pub' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/share/apk/keys/alpine-devel@lists.alpinelinux.org-61666e3f.rsa.pub' # original
remove_cmd '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/etc/apk/keys/alpine-devel@lists.alpinelinux.org-61666e3f.rsa.pub' '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/share/apk/keys/alpine-devel@lists.alpinelinux.org-61666e3f.rsa.pub' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/git-core/mergetools/gvimdiff' # original
remove_cmd '/mnt/wslg/distro/usr/lib/git-core/mergetools/nvimdiff' '/mnt/wslg/distro/usr/lib/git-core/mergetools/gvimdiff' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/libgsm1/README' # original
remove_cmd '/mnt/wslg/doc/gsm/README' '/mnt/wslg/distro/usr/share/doc/libgsm1/README' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/empathy-away.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/tray-away.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/empathy-away.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/user-away-panel.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/empathy-away.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/empathy-away.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/tray-away.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/empathy-away.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/user-away-panel.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/empathy-away.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/devices/input-keyboard-symbolic.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/apps/preferences-desktop-keyboard-symbolic.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/devices/input-keyboard-symbolic.svg' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/sort_asc.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/sort_asc.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/sort_asc.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/sort_asc.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/sort_asc.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/sort_asc.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/sort_asc.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/libopenal1/copyright' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/libopenal-data/copyright' '/mnt/wslg/distro/usr/share/doc/libopenal1/copyright' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/22/new-messages-red.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/22/new-messages-red.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/22/new-messages-red.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/libopenal1/examples/alsoftrc.sample' # original
remove_cmd '/mnt/wslg/distro/etc/openal/alsoft.conf' '/mnt/wslg/distro/usr/share/doc/libopenal1/examples/alsoftrc.sample' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/places/24/start-here.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/places/24/start-here.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/places/24/start-here.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/32x32/actions/format-justify-fill-symbolic.symbolic.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/32x32/actions/open-menu-symbolic.symbolic.png' '/mnt/wslg/distro/usr/share/icons/Adwaita/32x32/actions/format-justify-fill-symbolic.symbolic.png' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/blueman-tray.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/bluetooth-active.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/blueman-tray.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/libcap2-bin/copyright' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/libpam-cap/copyright' '/mnt/wslg/distro/usr/share/doc/libcap2-bin/copyright' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/categories/24/preferences-desktop-personal-directory.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/categories/24/preferences-desktop-personal-directory.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/categories/24/preferences-desktop-personal-directory.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/blueman-tray.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/bluetooth-active.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/blueman-tray.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/16/audio-volume-muted.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/16/audio-volume-muted.png' '/mnt/wslg/distro/usr/share/icons/Humanity/status/16/audio-volume-muted.png' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/pam/account' # original
remove_cmd '/mnt/wslg/distro/var/lib/pam/auth' '/mnt/wslg/distro/var/lib/pam/account' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/pam/password' '/mnt/wslg/distro/var/lib/pam/account' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/pam/session' '/mnt/wslg/distro/var/lib/pam/account' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/pam/session-noninteractive' '/mnt/wslg/distro/var/lib/pam/account' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/ucf/hashfile.7' # original
remove_cmd '/mnt/wslg/distro/var/lib/ucf/hashfile.6' '/mnt/wslg/distro/var/lib/ucf/hashfile.7' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/ucf/hashfile.5' '/mnt/wslg/distro/var/lib/ucf/hashfile.7' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/ucf/hashfile.4' '/mnt/wslg/distro/var/lib/ucf/hashfile.7' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/libdrm-radeon1/copyright' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/libdrm-nouveau2/copyright' '/mnt/wslg/distro/usr/share/doc/libdrm-radeon1/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/libdrm-intel1/copyright' '/mnt/wslg/distro/usr/share/doc/libdrm-radeon1/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/libdrm2/copyright' '/mnt/wslg/distro/usr/share/doc/libdrm-radeon1/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/libdrm-common/copyright' '/mnt/wslg/distro/usr/share/doc/libdrm-radeon1/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/libdrm-amdgpu1/copyright' '/mnt/wslg/distro/usr/share/doc/libdrm-radeon1/copyright' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/__init__.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/__init__.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/__init__.py' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3.10/test/__init__.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/__init__.py' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/zina.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/zina.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/zina.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/zina.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/zina.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/zina.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/zina.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage01-connecting09.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/24/nm-stage01-connecting09.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage01-connecting09.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-symbolic-link.icon' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/22/emblem-symbolic-link.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-symbolic-link.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/24/emblem-symbolic-link.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-symbolic-link.icon' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/sort_desc.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/sort_desc.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/sort_desc.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/sort_desc.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/sort_desc.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/sort_desc.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/sort_desc.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/libsensors5/copyright' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/libsensors-config/copyright' '/mnt/wslg/distro/usr/share/doc/libsensors5/copyright' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/config.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/config.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/config.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/config.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/config.gif' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libgl1-mesa-dri:amd64.postinst' # original
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libgl1-mesa-dri:amd64.postrm' '/mnt/wslg/distro/var/lib/dpkg/info/libgl1-mesa-dri:amd64.postinst' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libgl1-mesa-dri:amd64.preinst' '/mnt/wslg/distro/var/lib/dpkg/info/libgl1-mesa-dri:amd64.postinst' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libgl1-mesa-dri:amd64.prerm' '/mnt/wslg/distro/var/lib/dpkg/info/libgl1-mesa-dri:amd64.postinst' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/bug/libgl1-amber-dri/control' # original
remove_cmd '/mnt/wslg/distro/usr/share/bug/libglx-mesa0/control' '/mnt/wslg/distro/usr/share/bug/libgl1-amber-dri/control' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/bug/libgl1-mesa-dri/control' '/mnt/wslg/distro/usr/share/bug/libgl1-amber-dri/control' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/bug/libglapi-mesa/control' '/mnt/wslg/distro/usr/share/bug/libgl1-amber-dri/control' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/bug/libosmesa6/control' '/mnt/wslg/distro/usr/share/bug/libgl1-amber-dri/control' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/bug/mesa-vulkan-drivers/control' '/mnt/wslg/distro/usr/share/bug/libgl1-amber-dri/control' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/bug/libgbm1/control' '/mnt/wslg/distro/usr/share/bug/libgl1-amber-dri/control' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/libglx-mesa0/copyright' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/libgl1-mesa-dri/copyright' '/mnt/wslg/distro/usr/share/doc/libglx-mesa0/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/libglapi-mesa/copyright' '/mnt/wslg/distro/usr/share/doc/libglx-mesa0/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/libosmesa6/copyright' '/mnt/wslg/distro/usr/share/doc/libglx-mesa0/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/mesa-vulkan-drivers/copyright' '/mnt/wslg/distro/usr/share/doc/libglx-mesa0/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/libgbm1/copyright' '/mnt/wslg/distro/usr/share/doc/libglx-mesa0/copyright' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/xmlrpc/__init__.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.10/concurrent/__init__.py' '/mnt/wslg/distro/usr/lib/python3.10/xmlrpc/__init__.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/bug/libgl1/control' # original
remove_cmd '/mnt/wslg/distro/usr/share/bug/libglx0/control' '/mnt/wslg/distro/usr/share/bug/libgl1/control' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/bug/libglvnd0/control' '/mnt/wslg/distro/usr/share/bug/libgl1/control' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/libgl1/copyright' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/libglx0/copyright' '/mnt/wslg/distro/usr/share/doc/libgl1/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/libglvnd0/copyright' '/mnt/wslg/distro/usr/share/doc/libgl1/copyright' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # original
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libspeex1:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libsndio7.0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libgtksourceview-3.0-1:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libopenal1:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libvulkan1:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libaa1:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libcdparanoia0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libfuse2:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libfuse3-3:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libjson-glib-1.0-0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libavc1394-0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libasyncns0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libmp3lame0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libcaca0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libdv4:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libdecor-0-0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libexif12:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libgphoto2-6:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libgphoto2-port12:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libgudev-1.0-0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libice6:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libiec61883-0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libogg0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libraw1394-11:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libsamplerate0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libshout3:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libtheora0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libvisual-0.4-0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libvorbis0a:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libvorbisenc2:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libxss1:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libxv1:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libsm6:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libxcb-dri2-0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libxcb-dri3-0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libxcb-glx0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libxcb-present0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libxcb-randr0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libxcb-sync1:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libxcb-xfixes0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libxshmfence1:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libsigsegv2:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libxxf86vm1:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libmpfr6:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libopus0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libwxbase3.0-0v5:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libwxgtk3.0-gtk3-0v5:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libslang2:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libtwolame0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libv4l-0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libv4lconvert0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libwavpack1:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libproxy1v5:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libsensors5:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libxft2:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libnotify4:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libusb-1.0-0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libsdl2-2.0-0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libwayland-server0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libdrm-amdgpu1:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libdrm-intel1:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libdrm-nouveau2:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libdrm-radeon1:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libdrm2:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libpangoxft-1.0-0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libunwind8:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libllvm15:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libflac8:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libxpm4:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libpulse0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libodbc2:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libvpx7:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libpcap0.8:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/liborc-0.4-0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libgbm1:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libglapi-mesa:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libglx-mesa0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libosmesa6:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libseccomp2:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libmpg123-0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libgd3:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libcryptsetup12:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libdevmapper1.02.1:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libldap-2.5-0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libcurl3-gnutls:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libgstreamer-plugins-good1.0-0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libgstreamer1.0-0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libgstreamer-plugins-base1.0-0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libc6:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libssl3:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libtasn1-6:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libgnutls30:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libsndfile1:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libnss-systemd:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libsystemd0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libudev1:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libcap2:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libxml2:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libgssapi-krb5-2:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libk5crypto3:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libkrb5-3:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libkrb5support0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libfreetype6:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libdw1:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libelf1:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libxslt1.1:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libexpat1:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libperl5.34:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libsoup2.4-1:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libxmu6:amd64.triggers' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/libwxbase3.0-0v5/copyright' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/libwxgtk3.0-gtk3-0v5/copyright' '/mnt/wslg/distro/usr/share/doc/libwxbase3.0-0v5/copyright' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/X11/locale/sr_RS.UTF-8/XI18N_OBJS' # original
remove_cmd '/mnt/wslg/distro/usr/share/X11/locale/km_KH.UTF-8/XI18N_OBJS' '/mnt/wslg/distro/usr/share/X11/locale/sr_RS.UTF-8/XI18N_OBJS' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/versionpredicate.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/versionpredicate.py' '/mnt/wslg/distro/usr/lib/python3.10/distutils/versionpredicate.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/applications-chat-panel.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/empathy-available.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/applications-chat-panel.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/tray-online.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/applications-chat-panel.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/user-available-panel.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/applications-chat-panel.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_paren.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_paren.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_paren.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gnupg/help.be.txt' # original
remove_cmd '/mnt/wslg/distro/usr/share/gnupg/help.ca.txt' '/mnt/wslg/distro/usr/share/gnupg/help.be.txt' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/gnupg/help.cs.txt' '/mnt/wslg/distro/usr/share/gnupg/help.be.txt' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/gnupg/help.da.txt' '/mnt/wslg/distro/usr/share/gnupg/help.be.txt' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/gnupg/help.el.txt' '/mnt/wslg/distro/usr/share/gnupg/help.be.txt' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/gnupg/help.eo.txt' '/mnt/wslg/distro/usr/share/gnupg/help.be.txt' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/gnupg/help.et.txt' '/mnt/wslg/distro/usr/share/gnupg/help.be.txt' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/gnupg/help.gl.txt' '/mnt/wslg/distro/usr/share/gnupg/help.be.txt' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/gnupg/help.nb.txt' '/mnt/wslg/distro/usr/share/gnupg/help.be.txt' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/gnupg/help.sv.txt' '/mnt/wslg/distro/usr/share/gnupg/help.be.txt' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/julia.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/julia.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/julia.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/scilab.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/scilab.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/scilab.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/pascal.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/pascal.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/pascal.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/dtd.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/dtd.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/dtd.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/j.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/j.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/j.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/puppet.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/puppet.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/puppet.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/d.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/d.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/d.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/forth.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/forth.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/forth.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/lua.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/lua.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/lua.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/texinfo.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/texinfo.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/texinfo.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/prolog.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/prolog.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/prolog.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/lex.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/lex.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/lex.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/nemerle.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/nemerle.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/nemerle.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/scheme.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/scheme.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/scheme.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/gtkrc.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/gtkrc.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/gtkrc.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/opencl.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/opencl.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/opencl.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/desktop.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/desktop.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/desktop.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-showers.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-showers.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-showers.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/chdr.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/chdr.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/chdr.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/gdb-log.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/gdb-log.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/gdb-log.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/xslt.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/xslt.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/xslt.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/cobol.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/cobol.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/cobol.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/netrexx.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/netrexx.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/netrexx.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/bennugd.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/bennugd.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/bennugd.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/libtool.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/libtool.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/libtool.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/makefile.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/makefile.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/makefile.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/tera.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/tera.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/tera.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/abnf.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/abnf.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/abnf.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/tcl.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/tcl.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/tcl.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/eiffel.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/eiffel.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/eiffel.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/sml.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/sml.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/sml.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/docbook.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/docbook.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/docbook.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/erlang.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/erlang.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/erlang.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/diff.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/diff.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/diff.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/thrift.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/thrift.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/thrift.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/genie.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/genie.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/genie.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/automake.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/automake.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/automake.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/logtalk.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/logtalk.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/logtalk.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/systemverilog.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/systemverilog.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/systemverilog.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/ada.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/ada.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/ada.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/dtl.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/dtl.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/dtl.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/powershell.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/powershell.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/powershell.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/fsharp.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/fsharp.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/fsharp.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/haskell.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/haskell.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/haskell.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/ansforth94.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/ansforth94.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/ansforth94.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/po.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/po.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/po.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/boo.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/boo.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/boo.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/ooc.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/ooc.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/ooc.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/opal.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/opal.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/opal.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/vbnet.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/vbnet.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/vbnet.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/haxe.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/haxe.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/haxe.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/scala.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/scala.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/scala.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/cuda.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/cuda.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/cuda.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/cpphdr.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/cpphdr.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/cpphdr.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/ini.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/ini.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/ini.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/fcl.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/fcl.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/fcl.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/bibtex.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/bibtex.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/bibtex.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/pkgconfig.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/pkgconfig.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/pkgconfig.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/ocl.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/ocl.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/ocl.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/swift.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/swift.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/swift.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/pig.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/pig.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/pig.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/mxml.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/mxml.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/mxml.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/java.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/java.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/java.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/modelica.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/modelica.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/modelica.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/vhdl.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/vhdl.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/vhdl.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/idl.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/idl.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/idl.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/protobuf.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/protobuf.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/protobuf.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/yacc.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/yacc.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/yacc.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/ocaml.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/ocaml.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/ocaml.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/sparql.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/sparql.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/sparql.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/bluespec.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/bluespec.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/bluespec.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/toml.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/toml.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/toml.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/glsl.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/glsl.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/glsl.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/logcat.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/logcat.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/logcat.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/dosbatch.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/dosbatch.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/dosbatch.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/yaml.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/yaml.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/yaml.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/actionscript.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/actionscript.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/actionscript.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/verilog.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/verilog.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/verilog.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/nsis.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/nsis.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/nsis.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/rpmspec.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/rpmspec.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/rpmspec.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/imagej.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/imagej.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/imagej.lang' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:tokenizer.ini' # original
remove_cmd '/mnt/wslg/distro/usr/share/php8.1-common/common/tokenizer.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:tokenizer.ini' # duplicate
remove_cmd '/mnt/wslg/distro/etc/php/8.1/mods-available/tokenizer.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:tokenizer.ini' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:sysvshm.ini' # original
remove_cmd '/mnt/wslg/distro/usr/share/php8.1-common/common/sysvshm.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:sysvshm.ini' # duplicate
remove_cmd '/mnt/wslg/distro/etc/php/8.1/mods-available/sysvshm.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:sysvshm.ini' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:sysvsem.ini' # original
remove_cmd '/mnt/wslg/distro/usr/share/php8.1-common/common/sysvsem.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:sysvsem.ini' # duplicate
remove_cmd '/mnt/wslg/distro/etc/php/8.1/mods-available/sysvsem.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:sysvsem.ini' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:gettext.ini' # original
remove_cmd '/mnt/wslg/distro/usr/share/php8.1-common/common/gettext.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:gettext.ini' # duplicate
remove_cmd '/mnt/wslg/distro/etc/php/8.1/mods-available/gettext.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:gettext.ini' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:sockets.ini' # original
remove_cmd '/mnt/wslg/distro/usr/share/php8.1-common/common/sockets.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:sockets.ini' # duplicate
remove_cmd '/mnt/wslg/distro/etc/php/8.1/mods-available/sockets.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:sockets.ini' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:sysvmsg.ini' # original
remove_cmd '/mnt/wslg/distro/usr/share/php8.1-common/common/sysvmsg.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:sysvmsg.ini' # duplicate
remove_cmd '/mnt/wslg/distro/etc/php/8.1/mods-available/sysvmsg.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:sysvmsg.ini' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/alsa/ucm2/Librem_5/Librem_5.conf' # original
remove_cmd '/mnt/wslg/distro/usr/share/alsa/ucm2/PineTab/PineTab.conf' '/mnt/wslg/distro/usr/share/alsa/ucm2/Librem_5/Librem_5.conf' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:ffi.ini' # original
remove_cmd '/mnt/wslg/distro/usr/share/php8.1-common/common/ffi.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:ffi.ini' # duplicate
remove_cmd '/mnt/wslg/distro/etc/php/8.1/mods-available/ffi.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:ffi.ini' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:ftp.ini' # original
remove_cmd '/mnt/wslg/distro/usr/share/php8.1-common/common/ftp.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:ftp.ini' # duplicate
remove_cmd '/mnt/wslg/distro/etc/php/8.1/mods-available/ftp.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:ftp.ini' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:pdo.ini' # original
remove_cmd '/mnt/wslg/distro/usr/share/php8.1-common/common/pdo.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:pdo.ini' # duplicate
remove_cmd '/mnt/wslg/distro/etc/php/8.1/mods-available/pdo.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:pdo.ini' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:phar.ini' # original
remove_cmd '/mnt/wslg/distro/usr/share/php8.1-common/common/phar.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:phar.ini' # duplicate
remove_cmd '/mnt/wslg/distro/etc/php/8.1/mods-available/phar.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:phar.ini' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:exif.ini' # original
remove_cmd '/mnt/wslg/distro/usr/share/php8.1-common/common/exif.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:exif.ini' # duplicate
remove_cmd '/mnt/wslg/distro/etc/php/8.1/mods-available/exif.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:exif.ini' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/docker/image/overlay2/layerdb/sha256/f86a1fd3c76bcd04777a0dc26ed9b9fa260dd30e903fc08f01a4f17048bb34b7/diff' # original
remove_cmd '/mnt/wslg/distro/var/lib/docker/image/overlay2/distribution/diffid-by-digest/sha256/61a1db28084c43f4f983e92e7c86bd36811d3f0ab726630b072eb2cc0131ecae' '/mnt/wslg/distro/var/lib/docker/image/overlay2/layerdb/sha256/f86a1fd3c76bcd04777a0dc26ed9b9fa260dd30e903fc08f01a4f17048bb34b7/diff' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:ctype.ini' # original
remove_cmd '/mnt/wslg/distro/usr/share/php8.1-common/common/ctype.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:ctype.ini' # duplicate
remove_cmd '/mnt/wslg/distro/etc/php/8.1/mods-available/ctype.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:ctype.ini' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/docker/image/overlay2/layerdb/sha256/08000c18d16dadf9553d747a58cf44023423a9ab010aab96cf263d2216b8b350/diff' # original
remove_cmd '/mnt/wslg/distro/var/lib/docker/image/overlay2/layerdb/sha256/487fcea936a346ad462fdc8e962651b5fe7487d2fbcd046d2c7e637265d64455/parent' '/mnt/wslg/distro/var/lib/docker/image/overlay2/layerdb/sha256/08000c18d16dadf9553d747a58cf44023423a9ab010aab96cf263d2216b8b350/diff' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/docker/image/overlay2/distribution/diffid-by-digest/sha256/f18232174bc91741fdf3da96d85011092101a032a93a388b79e99e69c2d5c870' '/mnt/wslg/distro/var/lib/docker/image/overlay2/layerdb/sha256/08000c18d16dadf9553d747a58cf44023423a9ab010aab96cf263d2216b8b350/diff' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:shmop.ini' # original
remove_cmd '/mnt/wslg/distro/usr/share/php8.1-common/common/shmop.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:shmop.ini' # duplicate
remove_cmd '/mnt/wslg/distro/etc/php/8.1/mods-available/shmop.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:shmop.ini' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/docker/image/overlay2/layerdb/sha256/7c0b6b6c7743e12d10a884c054858551f0e3345159634dcc018c9bf4a02bab28/diff' # original
remove_cmd '/mnt/wslg/distro/var/lib/docker/image/overlay2/distribution/diffid-by-digest/sha256/eced5c8ca5e14f967ad29d9036503bea3a7d9d8300d162b5e4e97a830f3acf60' '/mnt/wslg/distro/var/lib/docker/image/overlay2/layerdb/sha256/7c0b6b6c7743e12d10a884c054858551f0e3345159634dcc018c9bf4a02bab28/diff' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/docker/image/overlay2/layerdb/sha256/487fcea936a346ad462fdc8e962651b5fe7487d2fbcd046d2c7e637265d64455/diff' # original
remove_cmd '/mnt/wslg/distro/var/lib/docker/image/overlay2/distribution/diffid-by-digest/sha256/b83444215e4851e96a72207b8d84506c205ed8d9c07bade066aa7df4cd6b8dda' '/mnt/wslg/distro/var/lib/docker/image/overlay2/layerdb/sha256/487fcea936a346ad462fdc8e962651b5fe7487d2fbcd046d2c7e637265d64455/diff' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:iconv.ini' # original
remove_cmd '/mnt/wslg/distro/usr/share/php8.1-common/common/iconv.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:iconv.ini' # duplicate
remove_cmd '/mnt/wslg/distro/etc/php/8.1/mods-available/iconv.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:iconv.ini' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:posix.ini' # original
remove_cmd '/mnt/wslg/distro/usr/share/php8.1-common/common/posix.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:posix.ini' # duplicate
remove_cmd '/mnt/wslg/distro/etc/php/8.1/mods-available/posix.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:posix.ini' # duplicate
original_cmd '/mnt/wslg/distro/etc/magic' # original
remove_cmd '/mnt/wslg/distro/etc/magic.mime' '/mnt/wslg/distro/etc/magic' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/LoginIcons/apps/24/go-home.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/LoginIcons/apps/24/session-properties.svg' '/mnt/wslg/distro/usr/share/icons/LoginIcons/apps/24/go-home.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-clear-night-000.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-clear-night-010.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-clear-night-020.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-clear-night-030.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-clear-night-040.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-clear-night-050.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-clear-night-060.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-clear-night-070.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-clear-night-080.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-clear-night-090.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-clear-night-100.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-clear-night-110.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-clear-night-120.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-clear-night-130.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-clear-night-140.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-clear-night-150.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-clear-night-160.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-clear-night-170.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-clear-night-180.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-clear-night-190.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-clear-night-200.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-clear-night-210.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-clear-night-220.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-clear-night-230.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-clear-night-240.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-clear-night-250.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-clear-night-260.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-clear-night-270.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-clear-night-280.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-clear-night-290.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-clear-night-300.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-clear-night-310.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-clear-night-320.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-clear-night-330.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-clear-night-340.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-clear-night-350.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-clear-night.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-clear.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/status/battery-level-30-symbolic.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/legacy/battery-low-symbolic.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/status/battery-level-30-symbolic.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/dir_util.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/dir_util.py' '/mnt/wslg/distro/usr/lib/python3.10/distutils/dir_util.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/filelist.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/filelist.py' '/mnt/wslg/distro/usr/lib/python3.10/distutils/filelist.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/importlib_metadata/_text.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.10/importlib/metadata/_text.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/importlib_metadata/_text.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/gpm-battery-000.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/24/gpm-battery-000.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/gpm-battery-000.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/libsoup2.4-1/copyright' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/libsoup2.4-common/copyright' '/mnt/wslg/distro/usr/share/doc/libsoup2.4-1/copyright' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_standarderror.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_standarderror.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_standarderror.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/22/gpm-battery-000.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/22/gpm-battery-000.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/22/gpm-battery-000.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/empathy-extended-away.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/tray-extended-away.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/empathy-extended-away.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/user-idle-panel.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/empathy-extended-away.svg' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/stars-0.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/stars-0.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/stars-0.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/zinamp/skins/Silver/images/stars-0.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/stars-0.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/man/man1/cpan.1.gz' # original
remove_cmd '/mnt/wslg/distro/usr/share/man/man1/cpan5.34-x86_64-linux-gnu.1.gz' '/mnt/wslg/distro/usr/share/man/man1/cpan.1.gz' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/stars-5.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/stars-5.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/stars-5.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/zinamp/skins/Silver/images/stars-5.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/stars-5.gif' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/stars-2.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/stars-2.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/stars-2.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/zinamp/skins/Silver/images/stars-2.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/stars-2.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/categories/applications-system-symbolic.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/categories/preferences-other-symbolic.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/categories/applications-system-symbolic.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/categories/preferences-system-symbolic.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/categories/applications-system-symbolic.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/audio-volume-muted-blocking-panel.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/24/audio-volume-muted-blocking-panel.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/audio-volume-muted-blocking-panel.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/dpatch.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/dpatch.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/dpatch.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/libnotify-bin/copyright' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/libnotify4/copyright' '/mnt/wslg/distro/usr/share/doc/libnotify-bin/copyright' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/zina.ico' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/zina.ico' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/zina.ico' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/zina.ico' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/zina.ico' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/zina.ico' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/zina.ico' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/etc/ssl/ct_log_list.cnf' # original
remove_cmd '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/etc/ssl/ct_log_list.cnf.dist' '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/etc/ssl/ct_log_list.cnf' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/24/nm-secure-lock.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/24/nm-vpn-active-lock.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/24/nm-secure-lock.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/24/nm-vpn-lock.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/24/nm-secure-lock.svg' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/stars-3.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/stars-3.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/stars-3.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/zinamp/skins/Silver/images/stars-3.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/stars-3.gif' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/dpkg/info/dirmngr.preinst' # original
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/dirmngr.prerm' '/mnt/wslg/distro/var/lib/dpkg/info/dirmngr.preinst' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/16/gpm-battery-000.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/16/gpm-battery-000.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/16/gpm-battery-000.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage02-connecting03.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/22/nm-stage02-connecting03.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage02-connecting03.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/man/man1/perl.1.gz' # original
remove_cmd '/mnt/wslg/distro/usr/share/man/man1/perl5.34-x86_64-linux-gnu.1.gz' '/mnt/wslg/distro/usr/share/man/man1/perl.1.gz' # duplicate
original_cmd '/mnt/wslg/distro/etc/gtk-3.0/im-multipress.conf' # original
remove_cmd '/mnt/wslg/distro/etc/gtk-2.0/im-multipress.conf' '/mnt/wslg/distro/etc/gtk-3.0/im-multipress.conf' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_imports2.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_imports2.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_imports2.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/24x24/mimetypes/application-x-generic.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/24x24/mimetypes/text-x-preview.png' '/mnt/wslg/distro/usr/share/icons/Adwaita/24x24/mimetypes/application-x-generic.png' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/status/content-loading-symbolic.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/status/image-loading-symbolic.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/status/content-loading-symbolic.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-package.icon' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/24/emblem-package.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-package.icon' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/nm-secure-lock.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/nm-vpn-active-lock.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/nm-secure-lock.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/nm-vpn-lock.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/nm-secure-lock.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/16/dialog-warning.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-important.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/16/dialog-warning.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/16/user-offline-panel.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/16/user-offline-panel.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/16/user-offline-panel.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/aspell/australian-wo_accents.alias' # original
remove_cmd '/mnt/wslg/distro/usr/lib/aspell/en_AU.multi' '/mnt/wslg/distro/usr/lib/aspell/australian-wo_accents.alias' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/aspell/canadian-wo_accents.alias' # original
remove_cmd '/mnt/wslg/distro/usr/lib/aspell/en_CA.multi' '/mnt/wslg/distro/usr/lib/aspell/canadian-wo_accents.alias' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/aspell/american-wo_accents.alias' # original
remove_cmd '/mnt/wslg/distro/usr/lib/aspell/en_US.multi' '/mnt/wslg/distro/usr/lib/aspell/american-wo_accents.alias' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-100-charging.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-ups-100-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-100-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/unity-battery-100-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-100-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/unity-gpm-battery-100-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-100-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-primary-100-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-100-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-ups-100-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-100-charging.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/bytes_heavy.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/bytes_heavy.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/bytes_heavy.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/objc.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/objc.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/objc.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/matlab.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/matlab.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/matlab.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_execfile.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_execfile.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_execfile.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/24/gnome-netstatus-50-74.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/24/nm-signal-75.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/24/gnome-netstatus-50-74.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gnome-netstatus-50-74.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/nm-signal-75.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gnome-netstatus-50-74.svg' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/share/apk/keys/alpine-devel@lists.alpinelinux.org-4a6a0840.rsa.pub' # original
remove_cmd '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/etc/apk/keys/alpine-devel@lists.alpinelinux.org-4a6a0840.rsa.pub' '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/share/apk/keys/alpine-devel@lists.alpinelinux.org-4a6a0840.rsa.pub' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/share/apk/keys/alpine-devel@lists.alpinelinux.org-5261cecb.rsa.pub' # original
remove_cmd '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/etc/apk/keys/alpine-devel@lists.alpinelinux.org-5261cecb.rsa.pub' '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/share/apk/keys/alpine-devel@lists.alpinelinux.org-5261cecb.rsa.pub' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/32x32/actions/edit-find-symbolic.symbolic.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/32x32/actions/system-search-symbolic.symbolic.png' '/mnt/wslg/distro/usr/share/icons/Adwaita/32x32/actions/edit-find-symbolic.symbolic.png' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_getcwdu.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_getcwdu.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_getcwdu.py' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/share/apk/keys/alpine-devel@lists.alpinelinux.org-5243ef4b.rsa.pub' # original
remove_cmd '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/etc/apk/keys/alpine-devel@lists.alpinelinux.org-5243ef4b.rsa.pub' '/mnt/wslg/distro/var/lib/docker/overlay2/d8fe5652277955bbf817895ece146ad0e9758731066bd815f321745bd8066249/diff/usr/share/apk/keys/alpine-devel@lists.alpinelinux.org-5243ef4b.rsa.pub' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_next.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_next.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_next.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/importlib_metadata/_adapters.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.10/importlib/metadata/_adapters.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/importlib_metadata/_adapters.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/actions/16/system-restart-panel.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/actions/16/system-restart-panel.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/actions/16/system-restart-panel.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/haskell-literate.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/haskell-literate.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/haskell-literate.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-clear-night-000.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-clear-night-010.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-clear-night-020.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-clear-night-030.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-clear-night-040.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-clear-night-050.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-clear-night-060.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-clear-night-070.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-clear-night-080.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-clear-night-090.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-clear-night-100.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-clear-night-110.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-clear-night-120.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-clear-night-130.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-clear-night-140.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-clear-night-150.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-clear-night-160.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-clear-night-170.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-clear-night-180.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-clear-night-190.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-clear-night-200.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-clear-night-210.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-clear-night-220.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-clear-night-230.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-clear-night-240.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-clear-night-250.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-clear-night-260.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-clear-night-270.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-clear-night-280.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-clear-night-290.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-clear-night-300.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-clear-night-310.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-clear-night-320.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-clear-night-330.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-clear-night-340.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-clear-night-350.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-clear-night.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-clear.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/libxcb-xfixes0/copyright' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/libxcb-sync1/copyright' '/mnt/wslg/distro/usr/share/doc/libxcb-xfixes0/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/libxcb-randr0/copyright' '/mnt/wslg/distro/usr/share/doc/libxcb-xfixes0/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/libxcb-present0/copyright' '/mnt/wslg/distro/usr/share/doc/libxcb-xfixes0/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/libxcb-glx0/copyright' '/mnt/wslg/distro/usr/share/doc/libxcb-xfixes0/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/libxcb-dri3-0/copyright' '/mnt/wslg/distro/usr/share/doc/libxcb-xfixes0/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/libxcb-dri2-0/copyright' '/mnt/wslg/distro/usr/share/doc/libxcb-xfixes0/copyright' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-040.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-ups-040.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-040.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/unity-battery-040.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-040.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/unity-battery-low.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-040.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/unity-gpm-battery-040.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-040.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-primary-040.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-040.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-ups-040.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-040.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-040.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-ups-040.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-040.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/unity-battery-040.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-040.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/unity-battery-low.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-040.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/unity-gpm-battery-040.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-040.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/xfpm-primary-040.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-040.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/xfpm-ups-040.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-040.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-040.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-ups-040.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-040.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/unity-battery-040.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-040.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/unity-battery-low.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-040.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/unity-gpm-battery-040.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-040.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-primary-040.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-040.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-ups-040.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-040.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/devices/media-optical-bd-symbolic.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/devices/media-optical-cd-audio-symbolic.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/devices/media-optical-bd-symbolic.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/devices/media-optical-dvd-symbolic.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/devices/media-optical-bd-symbolic.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl/5.34.0/Config_git.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/Config_git.pl' '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl/5.34.0/Config_git.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/64x64/actions/edit-find-symbolic.symbolic.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/64x64/actions/system-search-symbolic.symbolic.png' '/mnt/wslg/distro/usr/share/icons/Adwaita/64x64/actions/edit-find-symbolic.symbolic.png' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/forward_un.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/forward_un.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/forward_un.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/X11/locale/ja_JP.UTF-8/Compose' # original
remove_cmd '/mnt/wslg/distro/usr/share/X11/locale/zh_TW.UTF-8/Compose' '/mnt/wslg/distro/usr/share/X11/locale/ja_JP.UTF-8/Compose' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/X11/locale/th_TH.UTF-8/Compose' '/mnt/wslg/distro/usr/share/X11/locale/ja_JP.UTF-8/Compose' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/X11/locale/zh_HK.UTF-8/Compose' '/mnt/wslg/distro/usr/share/X11/locale/ja_JP.UTF-8/Compose' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/X11/locale/ko_KR.UTF-8/Compose' '/mnt/wslg/distro/usr/share/X11/locale/ja_JP.UTF-8/Compose' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/X11/locale/ru_RU.UTF-8/Compose' '/mnt/wslg/distro/usr/share/X11/locale/ja_JP.UTF-8/Compose' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/X11/locale/zh_CN.UTF-8/Compose' '/mnt/wslg/distro/usr/share/X11/locale/ja_JP.UTF-8/Compose' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/animations/24/nm-stage01-connecting05.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/animations/24/nm-stage01-connecting05.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/animations/24/nm-stage01-connecting05.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/animations/24/nm-stage01-connecting06.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/animations/24/nm-stage01-connecting06.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/animations/24/nm-stage01-connecting06.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/animations/24/nm-stage01-connecting09.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/animations/24/nm-stage01-connecting09.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/animations/24/nm-stage01-connecting09.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/animations/22/nm-stage01-connecting03.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/animations/24/nm-stage01-connecting03.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/animations/22/nm-stage01-connecting03.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/animations/22/nm-stage01-connecting03.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/animations/22/nm-stage01-connecting03.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/animations/24/nm-stage01-connecting03.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/animations/22/nm-stage01-connecting03.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/animations/24/nm-stage01-connecting08.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/animations/24/nm-stage01-connecting08.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/animations/24/nm-stage01-connecting08.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-000.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-ups-000.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-ups-missing.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/unity-gpm-battery-000.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/unity-gpm-battery-empty.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/unity-gpm-battery-missing.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/xfpm-primary-000.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/xfpm-primary-missing.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/xfpm-ups-000.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-000.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/xfpm-ups-missing.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-000.svg' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/home.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/home.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/home.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/home.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/home.gif' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/back_un.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/back_un.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/back_un.gif' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/download.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/download_custom.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/download.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/ruamel.yaml-0.17.16.egg-info/namespace_packages.txt' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/ruamel.yaml-0.17.16.egg-info/top_level.txt' '/mnt/wslg/distro/usr/lib/python3/dist-packages/ruamel.yaml-0.17.16.egg-info/namespace_packages.txt' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Hst.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/Hst.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Hst.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Ea.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/Ea.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Ea.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Upper.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/Upper.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Upper.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Jt.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/Jt.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Jt.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Isc.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/Isc.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Isc.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Bc.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/Bc.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Bc.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Lc.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/Lc.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Lc.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Title.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/Title.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Title.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/_PerlSCX.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/_PerlSCX.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/_PerlSCX.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/InPC.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/InPC.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/InPC.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Lb.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/Lb.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Lb.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Vo.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/Vo.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Vo.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/NFDQC.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/NFDQC.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/NFDQC.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Age.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/Age.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Age.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/NFKDQC.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/NFKDQC.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/NFKDQC.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-000-charging.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-ups-000-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-000-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/unity-battery-000-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-000-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/unity-gpm-battery-000-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-000-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-primary-000-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-000-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-ups-000-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-000-charging.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Bpt.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/Bpt.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Bpt.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-000-charging.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-ups-000-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-000-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/unity-battery-000-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-000-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/unity-gpm-battery-000-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-000-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-primary-000-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-000-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-ups-000-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-000-charging.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-000-charging.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-ups-000-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-000-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/unity-battery-000-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-000-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/unity-gpm-battery-000-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-000-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/xfpm-primary-000-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-000-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/xfpm-ups-000-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-000-charging.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Scx.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/Scx.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Scx.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Fold.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/Fold.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Fold.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/InSC.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/InSC.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/InSC.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Cf.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/Cf.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Cf.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/NameAlia.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/NameAlia.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/NameAlia.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Lower.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/Lower.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Lower.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/NFCQC.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/NFCQC.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/NFCQC.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Bmg.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/Bmg.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Bmg.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Uc.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/Uc.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Uc.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/PerlDeci.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/PerlDeci.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/PerlDeci.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-020.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-ups-020.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-020.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/unity-battery-020.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-020.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/unity-battery-caution.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-020.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/unity-gpm-battery-020.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-020.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-primary-020.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-020.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-ups-020.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-020.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Tc.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/Tc.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Tc.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/NFKCQC.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/NFKCQC.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/NFKCQC.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/WB.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/WB.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/WB.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/EqUIdeo.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/EqUIdeo.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/EqUIdeo.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/actions/24/object-rotate-right.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/actions/24/rotate.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/actions/24/object-rotate-right.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Sc.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/Sc.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Sc.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/GCB.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/GCB.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/GCB.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/_PerlLB.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/_PerlLB.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/_PerlLB.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Digit.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/Digit.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Digit.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Nt.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/Nt.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Nt.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Nv.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/Nv.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Nv.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/WB/XX.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/WB/XX.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/WB/XX.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/WB/KA.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/WB/KA.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/WB/KA.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/WB/LE.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/WB/LE.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/WB/LE.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/WB/Extend.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/WB/Extend.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/WB/Extend.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/actions/16/package-supported.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/actions/16/package-supported.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/actions/16/package-supported.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gnome-netstatus-error.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/network-error.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gnome-netstatus-error.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nt/Nu.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nt/Nu.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nt/Nu.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/20.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/20.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/20.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/7.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/7.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/7.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/100.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/100.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/100.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/status/bluetooth-active-symbolic.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/devices/bluetooth-symbolic.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/status/bluetooth-active-symbolic.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-060-charging.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-ups-060-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-060-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/unity-battery-060-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-060-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/unity-gpm-battery-060-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-060-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-primary-060-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-060-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-ups-060-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-060-charging.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-040-charging.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-ups-040-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-040-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/unity-battery-040-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-040-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/unity-gpm-battery-040-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-040-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-primary-040-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-040-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-ups-040-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-040-charging.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-080-charging.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-ups-080-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-080-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/unity-battery-080-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-080-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/unity-gpm-battery-080-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-080-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-primary-080-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-080-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-ups-080-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-primary-080-charging.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/1.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/1.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/1.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_itertools_imports.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_itertools_imports.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_itertools_imports.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-040-charging.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-ups-040-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-040-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/unity-battery-040-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-040-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/unity-gpm-battery-040-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-040-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-primary-040-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-040-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-ups-040-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-040-charging.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/0.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/0.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/0.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/1_16.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/1_16.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/1_16.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/3_16.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/3_16.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/3_16.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/audio-volume-high.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/24/audio-volume-high.png' '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/audio-volume-high.png' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/1000.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/1000.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/1000.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/30.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/30.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/30.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/8.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/8.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/8.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/10.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/10.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/10.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/90.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/90.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/90.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/1_4.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/1_4.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/1_4.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/80.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/80.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/80.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/4.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/4.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/4.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/5.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/5.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/5.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/_PerlIDS.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Perl/_PerlIDS.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/_PerlIDS.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/Title.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Perl/Title.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/Title.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/_PerlNch.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Perl/_PerlNch.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/_PerlNch.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/importlib_metadata/_collections.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.10/importlib/metadata/_collections.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/importlib_metadata/_collections.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/PerlWord.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Perl/PerlWord.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/PerlWord.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/PosixPun.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Perl/PosixPun.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/PosixPun.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/Print.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Perl/Print.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/Print.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/_PerlIsI.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Perl/_PerlIsI.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/_PerlIsI.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/Graph.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Perl/Graph.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/Graph.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/Word.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Perl/Word.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/Word.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/_PerlCha.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Perl/_PerlCha.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/_PerlCha.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/_PerlCh2.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Perl/_PerlCh2.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/_PerlCh2.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Ps.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Gc/Ps.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Ps.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Lo.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Gc/Lo.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Lo.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/N.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Gc/N.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/N.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Lu.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Gc/Lu.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Lu.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/C.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Gc/C.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/C.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Nd.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Gc/Nd.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Nd.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Ll.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Gc/Ll.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Ll.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/M.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Gc/M.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/M.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Sm.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Gc/Sm.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Sm.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/L.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Gc/L.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/L.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/gpm-primary-000-charging.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/48/gpm-primary-000-charging.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/gpm-primary-000-charging.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Po.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Gc/Po.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Po.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/XPosixPu.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Perl/XPosixPu.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/XPosixPu.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Cf.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Gc/Cf.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Cf.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/40.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/40.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/40.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Lm.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Gc/Lm.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Lm.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/So.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Gc/So.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/So.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Mn.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Gc/Mn.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Mn.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Pe.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Gc/Pe.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Pe.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/No.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Gc/No.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/No.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/P.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Gc/P.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/P.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds-night-000.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds-night-010.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds-night-020.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds-night-030.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds-night-040.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds-night-050.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds-night-060.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds-night-070.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds-night-080.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds-night-090.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds-night-100.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds-night-110.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds-night-120.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds-night-130.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds-night-140.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds-night-150.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds-night-160.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds-night-170.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds-night-180.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds-night-190.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds-night-200.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds-night-210.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds-night-220.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds-night-230.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds-night-240.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds-night-250.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds-night-260.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds-night-270.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds-night-280.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds-night-290.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds-night-300.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds-night-310.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds-night-320.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds-night-330.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds-night-340.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds-night-350.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-few-clouds-night.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-night-few-clouds.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Cn.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Gc/Cn.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Cn.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Mc.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Gc/Mc.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Mc.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Term/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Term/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Term/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Sk.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Gc/Sk.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Sk.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/NFCQC/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/NFCQC/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/NFCQC/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Math/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Math/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Math/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/CompEx/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/CompEx/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/CompEx/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jt/U.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Jt/U.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jt/U.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/dot.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/dot.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/dot.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jt/R.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Jt/R.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jt/R.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jt/T.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Jt/T.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jt/T.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/awk.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/awk.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/awk.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jt/D.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Jt/D.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jt/D.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/DI/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/DI/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/DI/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Bindu.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/InSC/Bindu.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Bindu.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Invisibl.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/InSC/Invisibl.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Invisibl.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/WB/WSegSpac.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/WB/WSegSpac.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/WB/WSegSpac.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/16/audio-volume-high.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/16/audio-volume-high.png' '/mnt/wslg/distro/usr/share/icons/Humanity/status/16/audio-volume-high.png' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Vowel.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/InSC/Vowel.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Vowel.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Syllable.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/InSC/Syllable.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Syllable.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Consonan.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/InSC/Consonan.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Consonan.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/PureKill.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/InSC/PureKill.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/PureKill.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Other.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/InSC/Other.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Other.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Nukta.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/InSC/Nukta.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Nukta.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/audio-volume-muted.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/24/audio-volume-muted.png' '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/audio-volume-muted.png' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Consona3.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/InSC/Consona3.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Consona3.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Virama.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/InSC/Virama.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Virama.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/PatternGrammar.txt' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/PatternGrammar.txt' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/PatternGrammar.txt' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/NFKDQC/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/NFKDQC/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/NFKDQC/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/NFKDQC/N.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/NFKDQC/N.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/NFKDQC/N.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/EPres/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/EPres/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/EPres/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/IdType/DefaultI.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/IdType/DefaultI.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/IdType/DefaultI.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/WB/FO.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/WB/FO.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/WB/FO.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/IdType/Obsolete.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/IdType/Obsolete.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/IdType/Obsolete.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/IdType/NotXID.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/IdType/NotXID.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/IdType/NotXID.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/IdType/Uncommon.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/IdType/Uncommon.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/IdType/Uncommon.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/IdType/LimitedU.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/IdType/LimitedU.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/IdType/LimitedU.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/IdType/NotChara.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/IdType/NotChara.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/IdType/NotChara.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/IdType/Recommen.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/IdType/Recommen.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/IdType/Recommen.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Ccc/VR.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Ccc/VR.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Ccc/VR.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Ccc/AR.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Ccc/AR.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Ccc/AR.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/edit-redo-symbolic-rtl.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/edit-undo-symbolic.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/edit-redo-symbolic-rtl.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Ccc/NR.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Ccc/NR.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Ccc/NR.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Ccc/B.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Ccc/B.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Ccc/B.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Ccc/DB.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Ccc/DB.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Ccc/DB.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/CWCM/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/CWCM/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/CWCM/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage01-connecting04.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/24/nm-stage01-connecting04.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage01-connecting04.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/PatSyn/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/PatSyn/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/PatSyn/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Bc/BN.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Bc/BN.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Bc/BN.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Visarga.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/InSC/Visarga.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Visarga.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Bc/R.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Bc/R.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Bc/R.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Bc/L.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Bc/L.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Bc/L.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Bc/AL.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Bc/AL.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Bc/AL.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Bc/NSM.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Bc/NSM.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Bc/NSM.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Ideo/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Ideo/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Ideo/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Upper/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Upper/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Upper/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/SB/XX.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/SB/XX.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/SB/XX.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/NFDQC/N.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/NFDQC/N.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/NFDQC/N.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/nm-mb-roam.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/nm-mb-roam.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/nm-mb-roam.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/nm-tech-3g.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/nm-mb-roam.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/nm-tech-3g.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/nm-mb-roam.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/nm-tech-cdma-1x.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/nm-mb-roam.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/nm-tech-cdma-1x.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/nm-mb-roam.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/nm-tech-edge.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/nm-mb-roam.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/nm-tech-edge.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/nm-mb-roam.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/nm-tech-evdo.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/nm-mb-roam.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/nm-tech-evdo.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/nm-mb-roam.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/nm-tech-gprs.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/nm-mb-roam.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/nm-tech-gprs.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/nm-mb-roam.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/nm-tech-hspa.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/nm-mb-roam.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/nm-tech-hspa.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/nm-mb-roam.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/nm-tech-umts.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/nm-mb-roam.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/nm-tech-umts.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/nm-mb-roam.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/nm-wwan-tower.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/nm-mb-roam.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/nm-wwan-tower.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/nm-mb-roam.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/nm-mb-roam.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/nm-tech-3g.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/nm-mb-roam.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/nm-tech-cdma-1x.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/nm-mb-roam.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/nm-tech-edge.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/nm-mb-roam.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/nm-tech-evdo.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/nm-mb-roam.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/nm-tech-gprs.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/nm-mb-roam.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/nm-tech-hspa.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/nm-mb-roam.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/nm-tech-umts.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/nm-mb-roam.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/nm-wwan-tower.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/nm-mb-roam.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/24/nm-wwan-tower.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/nm-mb-roam.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/SB/Sp.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/SB/Sp.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/SB/Sp.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/SB/FO.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/SB/FO.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/SB/FO.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/WB/NU.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/WB/NU.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/WB/NU.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/SB/EX.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/SB/EX.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/SB/EX.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/SB/NU.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/SB/NU.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/SB/NU.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/SB/CL.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/SB/CL.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/SB/CL.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/SB/SC.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/SB/SC.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/SB/SC.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/SB/LO.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/SB/LO.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/SB/LO.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/SB/LE.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/SB/LE.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/SB/LE.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/SB/ST.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/SB/ST.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/SB/ST.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/SB/UP.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/SB/UP.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/SB/UP.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Dia/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Dia/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Dia/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/BidiM/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/BidiM/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/BidiM/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Latn.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Sc/Latn.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Latn.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Grek.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Sc/Grek.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Grek.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Zinh.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Sc/Zinh.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Zinh.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/11.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/11.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/11.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/50000.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/50000.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/50000.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/12.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/12.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/12.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Cyrl.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Sc/Cyrl.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Cyrl.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/5_2.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/In/5_2.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/5_2.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/3_2.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/In/3_2.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/3_2.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/12_0.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/In/12_0.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/12_0.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/13_0.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/In/13_0.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/13_0.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/11_0.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/In/11_0.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/11_0.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/3_1.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/In/3_1.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/3_1.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/5_0.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/In/5_0.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/5_0.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/6_2.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/In/6_2.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/6_2.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Identifi.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/Identifi.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Identifi.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/6_1.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/In/6_1.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/6_1.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/6_3.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/In/6_3.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/6_3.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/9_0.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/In/9_0.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/9_0.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/6_0.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/In/6_0.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/6_0.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/8_0.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/In/8_0.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/8_0.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/4_0.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/In/4_0.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/4_0.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/10_0.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/In/10_0.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/10_0.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/12_1.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/In/12_1.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/12_1.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/Assigned.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Perl/Assigned.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/Assigned.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/4_1.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/In/4_1.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/4_1.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/3_0.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/In/3_0.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/3_0.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/IDS/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/IDS/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/IDS/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/ExtPict/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/ExtPict/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/ExtPict/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/XIDS/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/XIDS/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/XIDS/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/STerm/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/STerm/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/STerm/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/CWKCF/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/CWKCF/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/CWKCF/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/IdStatus/Restrict.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/IdStatus/Restrict.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/IdStatus/Restrict.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/IdStatus/Allowed.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/IdStatus/Allowed.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/IdStatus/Allowed.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/CWT/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/CWT/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/CWT/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/XX.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Lb/XX.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/XX.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/GL.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Lb/GL.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/GL.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Cantilla.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/InSC/Cantilla.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Cantilla.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Consona6.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/InSC/Consona6.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Consona6.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Bc/CS.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Bc/CS.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Bc/CS.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/NU.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Lb/NU.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/NU.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/AL.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Lb/AL.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/AL.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/IdType/Technica.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/IdType/Technica.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/IdType/Technica.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/OP.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Lb/OP.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/OP.pl' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/podcast.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/podcast.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/podcast.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/podcast.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/podcast.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/podcast.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/podcast.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/BB.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Lb/BB.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/BB.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/BA.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Lb/BA.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/BA.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/ID.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Lb/ID.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/ID.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/EX.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Lb/EX.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/EX.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/CL.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Lb/CL.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/CL.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Han.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Sc/Han.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Han.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/PO.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Lb/PO.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/PO.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/QU.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Lb/QU.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/QU.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Knda.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Sc/Knda.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Knda.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/CM.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Lb/CM.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/CM.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/AI.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Lb/AI.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/AI.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_throw.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_throw.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_throw.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Emoji/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Emoji/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Emoji/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/CI/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/CI/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/CI/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/CWCF/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/CWCF/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/CWCF/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V120.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Age/V120.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V120.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V30.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Age/V30.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V30.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V51.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Age/V51.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V51.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V110.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Age/V110.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V110.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V130.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Age/V130.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V130.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V100.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Age/V100.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V100.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V41.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Age/V41.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V41.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V40.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Age/V40.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V40.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Arab.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Sc/Arab.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Arab.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V80.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Age/V80.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V80.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/NA.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Age/NA.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/NA.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V32.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Age/V32.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V32.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V90.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Age/V90.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V90.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V11.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Age/V11.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V11.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V20.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Age/V20.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V20.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V61.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Age/V61.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V61.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V52.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Age/V52.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V52.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Blk/NB.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Blk/NB.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Blk/NB.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/CWL/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/CWL/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/CWL/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/edit-redo-symbolic.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/edit-undo-symbolic-rtl.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/edit-redo-symbolic.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Copt.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Copt.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Copt.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Me.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Gc/Me.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Me.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Tang.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Tang.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Tang.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/16/audio-volume-medium.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/16/audio-volume-medium.png' '/mnt/wslg/distro/usr/share/icons/Humanity/status/16/audio-volume-medium.png' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Latn.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Latn.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Latn.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Cprt.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Cprt.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Cprt.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Zyyy.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Zyyy.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Zyyy.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Hebr.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Hebr.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Hebr.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Kana.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Kana.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Kana.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Avagraha.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/InSC/Avagraha.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Avagraha.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Taml.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Sc/Taml.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Taml.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Grek.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Grek.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Grek.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/SA.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Lb/SA.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/SA.pl' # duplicate
original_cmd '/mnt/wslg/distro/etc/shadow' # original
remove_cmd '/mnt/wslg/distro/etc/shadow-' '/mnt/wslg/distro/etc/shadow' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/_PerlPr2.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Perl/_PerlPr2.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/_PerlPr2.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Kana.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Sc/Kana.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Kana.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/_PerlPro.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Perl/_PerlPro.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/_PerlPro.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Mlym.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Mlym.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Mlym.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Yi.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Yi.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Yi.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Linb.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Sc/Linb.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Linb.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Gonm.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Sc/Gonm.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Gonm.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Bopo.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Bopo.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Bopo.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Gujr.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Sc/Gujr.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Gujr.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Orya.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Sc/Orya.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Orya.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Beng.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Sc/Beng.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Beng.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/NS.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Lb/NS.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/NS.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Zinh.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Zinh.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Zinh.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Pd.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Gc/Pd.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Pd.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/UIdeo/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/UIdeo/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/UIdeo/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Guru.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Guru.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Guru.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/AUTHORS' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/AUTHORS' '/mnt/wslg/distro/usr/share/icons/Humanity/AUTHORS' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Cyrl.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Cyrl.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Cyrl.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/5000.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/5000.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/5000.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Nand.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Nand.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Nand.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Ethi.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Ethi.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Ethi.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Linb.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Linb.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Linb.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Telu.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Sc/Telu.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Telu.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Ccc/OV.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Ccc/OV.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Ccc/OV.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Pi.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Gc/Pi.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Pi.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/7000.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/7000.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/7000.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/30000.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/30000.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/30000.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/4000.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/4000.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/4000.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/6000.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/6000.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/6000.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Adlm.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Adlm.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Adlm.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/9000.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/9000.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/9000.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/60000.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/60000.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/60000.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/80000.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/80000.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/80000.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/3000.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/3000.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/3000.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/20000.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/20000.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/20000.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/70000.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/70000.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/70000.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/90000.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/90000.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/90000.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/8000.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/8000.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/8000.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/40000.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/40000.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/40000.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Tirh.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Tirh.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Tirh.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/2000.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/2000.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/2000.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Zs.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Gc/Zs.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Zs.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/15.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/15.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/15.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Hira.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Sc/Hira.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Hira.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/14.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/14.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/14.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/13.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/13.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/13.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Taml.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Taml.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Taml.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Beng.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Beng.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Beng.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Alpha/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Alpha/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Alpha/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Zzzz.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Zzzz.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Zzzz.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/command/command_template' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/command/command_template' '/mnt/wslg/distro/usr/lib/python3.10/distutils/command/command_template' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/WB/MN.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/WB/MN.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/WB/MN.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Sinh.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Sinh.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Sinh.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nt/Di.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nt/Di.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nt/Di.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Knda.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Knda.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Knda.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Gran.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Sc/Gran.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Gran.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Orya.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Orya.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Orya.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/ToneMark.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/InSC/ToneMark.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/ToneMark.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/10000.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/10000.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/10000.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/60.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/60.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/60.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Guru.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Sc/Guru.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Guru.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Telu.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Telu.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Telu.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/70.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/70.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/70.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/audio-volume-zero-panel.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/stock_volume-0.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/audio-volume-zero-panel.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Gujr.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Gujr.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Gujr.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Hang.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Hang.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Hang.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Bc/ET.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Bc/ET.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Bc/ET.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Hira.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Hira.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Hira.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_xreadlines.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_xreadlines.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_xreadlines.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/1_2.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/1_2.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/1_2.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Syrc.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Syrc.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Syrc.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Lao.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Lao.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Lao.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Pf.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Gc/Pf.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Pf.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Gran.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Gran.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Gran.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lower/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Lower/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lower/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jg/NoJoinin.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Jg/NoJoinin.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jg/NoJoinin.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/CJ.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Lb/CJ.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/CJ.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Tibt.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Tibt.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Tibt.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Mult.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Mult.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Mult.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jg/Seen.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Jg/Seen.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jg/Seen.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jg/Gaf.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Jg/Gaf.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jg/Gaf.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jg/Waw.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Jg/Waw.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jg/Waw.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Dupl.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Dupl.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Dupl.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Dupl.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Sc/Dupl.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Dupl.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Mlym.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Sc/Mlym.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Mlym.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/1_3.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/1_3.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/1_3.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/1_6.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/1_6.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/1_6.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Consona5.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/InSC/Consona5.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Consona5.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Cham.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Cham.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Cham.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jg/HanifiRo.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Jg/HanifiRo.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jg/HanifiRo.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Lina.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Lina.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Lina.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Xsux.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Xsux.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Xsux.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Bhks.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Bhks.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Bhks.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Lana.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Lana.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Lana.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jg/Lam.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Jg/Lam.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jg/Lam.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jg/Dal.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Jg/Dal.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jg/Dal.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Limb.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Sc/Limb.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Limb.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/400.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/400.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/400.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/600.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/600.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/600.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jg/Reh.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Jg/Reh.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jg/Reh.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Bc/ES.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Bc/ES.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Bc/ES.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/IS.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Lb/IS.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/IS.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Talu.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Talu.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Talu.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/_PerlPat.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Perl/_PerlPat.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/_PerlPat.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Tagb.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Tagb.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Tagb.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jg/Kaf.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Jg/Kaf.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jg/Kaf.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Khmr.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Khmr.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Khmr.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Syrc.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Sc/Syrc.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Syrc.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jg/Qaf.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Jg/Qaf.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jg/Qaf.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/SB/AT.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/SB/AT.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/SB/AT.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jt/C.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Jt/C.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jt/C.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jg/Sad.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Jg/Sad.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jg/Sad.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/BidiC/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/BidiC/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/BidiC/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jg/FarsiYeh.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Jg/FarsiYeh.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jg/FarsiYeh.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jg/Feh.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Jg/Feh.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jg/Feh.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Consona2.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/InSC/Consona2.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Consona2.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/EBase/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/EBase/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/EBase/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InPC/Left.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/InPC/Left.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InPC/Left.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/3_4.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/3_4.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/3_4.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_nonzero.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_nonzero.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_nonzero.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jg/Hah.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Jg/Hah.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jg/Hah.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Gonm.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Gonm.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Gonm.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Glag.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Sc/Glag.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Glag.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InPC/TopAndRi.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/InPC/TopAndRi.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InPC/TopAndRi.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Consona7.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/InSC/Consona7.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Consona7.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InPC/LeftAndR.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/InPC/LeftAndR.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InPC/LeftAndR.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InPC/Bottom.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/InPC/Bottom.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InPC/Bottom.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Shrd.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Shrd.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Shrd.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InPC/TopAndBo.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/InPC/TopAndBo.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InPC/TopAndBo.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/battery_two_thirds.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/gpm-battery-060.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/battery_two_thirds.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/24/battery_two_thirds.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/24/gpm-battery-060.svg' '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/24/battery_two_thirds.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Pc.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Gc/Pc.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Pc.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/WB/MB.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/WB/MB.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/WB/MB.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Mong.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Mong.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Mong.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/PCM/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/PCM/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/PCM/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Bc/WS.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Bc/WS.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Bc/WS.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InPC/Overstru.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/InPC/Overstru.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InPC/Overstru.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Consona8.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/InSC/Consona8.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Consona8.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InPC/TopAndLe.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/InPC/TopAndLe.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InPC/TopAndLe.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/100000.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/100000.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/100000.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Cakm.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Cakm.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Cakm.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/IN.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Lb/IN.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/IN.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/200.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/200.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/200.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Z.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Gc/Z.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Z.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/16.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/16.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/16.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/18.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/18.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/18.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/17.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/17.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/17.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/1_8.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/1_8.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/1_8.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InPC/VisualOr.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/InPC/VisualOr.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InPC/VisualOr.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InPC/Right.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/InPC/Right.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InPC/Right.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/700.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/700.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/700.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Yezi.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Yezi.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Yezi.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/800.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/800.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/800.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/19.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/19.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/19.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/CWU/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/CWU/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/CWU/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/GrExt/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/GrExt/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/GrExt/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Cased/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Cased/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Cased/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/GrBase/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/GrBase/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/GrBase/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/IDC/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/IDC/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/IDC/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/Alnum.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Perl/Alnum.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/Alnum.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/XIDC/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/XIDC/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/XIDC/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/_PerlIDC.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Perl/_PerlIDC.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/_PerlIDC.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Bpt/C.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Bpt/C.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Bpt/C.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Bpt/O.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Bpt/O.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Bpt/O.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Dt/NonCanon.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Dt/NonCanon.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Dt/NonCanon.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Khar.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Khar.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Khar.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Geor.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Geor.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Geor.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Diak.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Diak.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Diak.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Dt/Enc.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Dt/Enc.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Dt/Enc.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Dt/Iso.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Dt/Iso.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Dt/Iso.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jg/Ain.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Jg/Ain.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jg/Ain.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Hst/NA.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Hst/NA.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Hst/NA.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Mult.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Sc/Mult.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Mult.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Dt/Vert.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Dt/Vert.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Dt/Vert.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jg/Alef.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Jg/Alef.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jg/Alef.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Limb.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Limb.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Limb.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Hmng.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Hmng.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Hmng.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jt/L.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Jt/L.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jt/L.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Dt/Nb.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Dt/Nb.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Dt/Nb.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Dt/Fin.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Dt/Fin.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Dt/Fin.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Dt/Font.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Dt/Font.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Dt/Font.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Dt/Sup.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Dt/Sup.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Dt/Sup.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Dt/Com.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Dt/Com.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Dt/Com.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Ea/N.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Ea/N.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Ea/N.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Ea/A.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Ea/A.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Ea/A.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Ea/W.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Ea/W.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Ea/W.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Ea/Na.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Ea/Na.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Ea/Na.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Ext/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Ext/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Ext/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/EComp/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/EComp/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/EComp/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Geor.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Sc/Geor.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Geor.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Vo/U.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Vo/U.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Vo/U.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Vo/R.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Vo/R.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Vo/R.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/NFKCQC/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/NFKCQC/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/NFKCQC/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Vo/Tr.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Vo/Tr.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Vo/Tr.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Hang.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Sc/Hang.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Hang.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/NFKCQC/N.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/NFKCQC/N.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/NFKCQC/N.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/GCB/SM.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/GCB/SM.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/GCB/SM.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/GCB/XX.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/GCB/XX.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/GCB/XX.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/GCB/EX.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/GCB/EX.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/GCB/EX.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/GCB/LV.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/GCB/LV.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/GCB/LV.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/GCB/LVT.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/GCB/LVT.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/GCB/LVT.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Dash/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Dash/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Dash/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/SD/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/SD/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/SD/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-urgent.icon' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-urgent.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-urgent.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/24/emblem-urgent.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-urgent.icon' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/libpulse0/README' # original
remove_cmd '/mnt/wslg/doc/pulseaudio/README' '/mnt/wslg/distro/usr/share/doc/libpulse0/README' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Vo/Tu.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Vo/Tu.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Vo/Tu.pl' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/stats.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/stats.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/stats.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/stats.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/stats.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/NFCQC/M.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/NFCQC/M.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/NFCQC/M.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/5_1.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/In/5_1.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/5_1.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_intern.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_intern.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_intern.py' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/play.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/play_custom.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/play.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/play_selected.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/play.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/22/audio-volume-medium.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/22/audio-volume-medium.png' '/mnt/wslg/distro/usr/share/icons/Humanity/status/22/audio-volume-medium.png' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/nm-device-wired-autoip.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/categories/24/preferences-system-network.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/nm-device-wired-autoip.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/16/audio-volume-low.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/16/audio-volume-low.png' '/mnt/wslg/distro/usr/share/icons/Humanity/status/16/audio-volume-low.png' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/96x96/actions/format-justify-fill-symbolic.symbolic.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/96x96/actions/open-menu-symbolic.symbolic.png' '/mnt/wslg/distro/usr/share/icons/Adwaita/96x96/actions/format-justify-fill-symbolic.symbolic.png' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/SpacePer.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Perl/SpacePer.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/SpacePer.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/devices/multimedia-player-apple-ipod-touch-symbolic.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/devices/phone-apple-iphone-symbolic.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/devices/multimedia-player-apple-ipod-touch-symbolic.svg' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/stars-1.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/stars-1.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/stars-1.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/zinamp/skins/Silver/images/stars-1.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/stars-1.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/IdType/Inclusio.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/IdType/Inclusio.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/IdType/Inclusio.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Nl.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Gc/Nl.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Nl.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Bc/EN.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Bc/EN.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Bc/EN.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Glag.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Glag.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Glag.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/2_3.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/2_3.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/2_3.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Dep/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Dep/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Dep/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Ea/H.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Ea/H.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Ea/H.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Gong.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Gong.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Gong.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/32x32/mimetypes/application-x-generic.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/32x32/mimetypes/text-x-preview.png' '/mnt/wslg/distro/usr/share/icons/Adwaita/32x32/mimetypes/application-x-generic.png' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/add.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/add.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/add.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/add.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/add.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/libwine/NEWS.gz' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/fonts-wine/NEWS.gz' '/mnt/wslg/distro/usr/share/doc/libwine/NEWS.gz' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage03-connecting04.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/24/nm-stage03-connecting04.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage03-connecting04.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/devices/drive-harddisk-ieee1394-symbolic.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/devices/drive-harddisk-symbolic.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/devices/drive-harddisk-ieee1394-symbolic.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/devices/drive-harddisk-system-symbolic.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/devices/drive-harddisk-ieee1394-symbolic.svg' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/tab.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/tab.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/tab.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/tab.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/tab.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/tab.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/tab.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/7_0.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/In/7_0.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/7_0.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/_PerlQuo.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Perl/_PerlQuo.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/_PerlQuo.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Bc/B.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Bc/B.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Bc/B.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/aspell/aspell.compat' # original
remove_cmd '/mnt/wslg/distro/var/lib/aspell/en.compat' '/mnt/wslg/distro/usr/share/aspell/aspell.compat' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-vpn-connecting03.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/24/nm-vpn-connecting03.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-vpn-connecting03.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-vpn-connecting03.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/22/nm-vpn-connecting03.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-vpn-connecting03.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/pgen2/token.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/pgen2/token.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/pgen2/token.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/libelf1/copyright' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/libdw1/copyright' '/mnt/wslg/distro/usr/share/doc/libelf1/copyright' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/systemd/user/sound.target' # original
remove_cmd '/mnt/wslg/distro/usr/lib/systemd/system/sound.target' '/mnt/wslg/distro/usr/lib/systemd/user/sound.target' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/systemd/user/smartcard.target' # original
remove_cmd '/mnt/wslg/distro/usr/lib/systemd/system/smartcard.target' '/mnt/wslg/distro/usr/lib/systemd/user/smartcard.target' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/22/user-offline-panel.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/22/user-offline-panel.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/22/user-offline-panel.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/user-offline-panel.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/24/user-offline-panel.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/user-offline-panel.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/gnupg-utils/NEWS.Debian.gz' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/gnupg-l10n/NEWS.Debian.gz' '/mnt/wslg/distro/usr/share/doc/gnupg-utils/NEWS.Debian.gz' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/gpgv/NEWS.Debian.gz' '/mnt/wslg/distro/usr/share/doc/gnupg-utils/NEWS.Debian.gz' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/gpgconf/NEWS.Debian.gz' '/mnt/wslg/distro/usr/share/doc/gnupg-utils/NEWS.Debian.gz' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/bluetooth-disabled.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/24/bluetooth-disabled.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/bluetooth-disabled.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Hmnp.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Hmnp.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Hmnp.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Hex/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Hex/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Hex/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jg/Yeh.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Jg/Yeh.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jg/Yeh.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jg/Beh.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Jg/Beh.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Jg/Beh.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_ne.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_ne.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_ne.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/systemd/user/dirmngr.socket' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/gnupg/examples/systemd-user/dirmngr.socket' '/mnt/wslg/distro/usr/lib/systemd/user/dirmngr.socket' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/systemd/user/gpg-agent-browser.socket' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/gnupg/examples/systemd-user/gpg-agent-browser.socket' '/mnt/wslg/distro/usr/lib/systemd/user/gpg-agent-browser.socket' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/systemd/user/gpg-agent-extra.socket' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/gnupg/examples/systemd-user/gpg-agent-extra.socket' '/mnt/wslg/distro/usr/lib/systemd/user/gpg-agent-extra.socket' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/devices/camera-web-symbolic.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/emblems/emblem-videos-symbolic.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/devices/camera-web-symbolic.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/places/folder-videos-symbolic.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/devices/camera-web-symbolic.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/mimetypes/video-x-generic-symbolic.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/devices/camera-web-symbolic.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/gnupg/examples/systemd-user/dirmngr.service' # original
remove_cmd '/mnt/wslg/distro/usr/lib/systemd/user/dirmngr.service' '/mnt/wslg/distro/usr/share/doc/gnupg/examples/systemd-user/dirmngr.service' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Dt/Init.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Dt/Init.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Dt/Init.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/krb-expiring-ticket.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/24/krb-expiring-ticket.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/krb-expiring-ticket.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/legacy/battery-full-symbolic.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/status/battery-level-90-symbolic.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/legacy/battery-full-symbolic.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/CE/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/CE/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/CE/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/Unicode/Collate/Locale/mr.pl' # original
remove_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/Unicode/Collate/Locale/sa.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/Unicode/Collate/Locale/mr.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/places/64/start-here.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/places/64/start-here.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/places/64/start-here.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/dirmngr/copyright' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/gpg/copyright' '/mnt/wslg/distro/usr/share/doc/dirmngr/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/gnupg/copyright' '/mnt/wslg/distro/usr/share/doc/dirmngr/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/gpg-wks-client/copyright' '/mnt/wslg/distro/usr/share/doc/dirmngr/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/gnupg-utils/copyright' '/mnt/wslg/distro/usr/share/doc/dirmngr/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/gpg-agent/copyright' '/mnt/wslg/distro/usr/share/doc/dirmngr/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/gpg-wks-server/copyright' '/mnt/wslg/distro/usr/share/doc/dirmngr/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/gnupg-l10n/copyright' '/mnt/wslg/distro/usr/share/doc/dirmngr/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/gpgv/copyright' '/mnt/wslg/distro/usr/share/doc/dirmngr/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/gpgsm/copyright' '/mnt/wslg/distro/usr/share/doc/dirmngr/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/gpgconf/copyright' '/mnt/wslg/distro/usr/share/doc/dirmngr/copyright' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/libudev1/copyright' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/systemd/copyright' '/mnt/wslg/distro/usr/share/doc/libudev1/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/systemd-timesyncd/copyright' '/mnt/wslg/distro/usr/share/doc/libudev1/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/libnss-systemd/copyright' '/mnt/wslg/distro/usr/share/doc/libudev1/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/systemd-sysv/copyright' '/mnt/wslg/distro/usr/share/doc/libudev1/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/libpam-systemd/copyright' '/mnt/wslg/distro/usr/share/doc/libudev1/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/libsystemd0/copyright' '/mnt/wslg/distro/usr/share/doc/libudev1/copyright' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/bug/polkitd/control' # original
remove_cmd '/mnt/wslg/distro/usr/share/bug/pkexec/control' '/mnt/wslg/distro/usr/share/bug/polkitd/control' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/bug/libapache2-mod-php8.1/control' # original
remove_cmd '/mnt/wslg/distro/usr/share/bug/php8.1-cli/control' '/mnt/wslg/distro/usr/share/bug/libapache2-mod-php8.1/control' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Cprt.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Sc/Cprt.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Cprt.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Mong.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Sc/Mong.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Mong.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/22/audio-volume-muted-blocked-panel.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/22/audio-volume-muted-blocked-panel.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/22/audio-volume-muted-blocked-panel.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Dt/Nar.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Dt/Nar.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Dt/Nar.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/WB/EX.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/WB/EX.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/WB/EX.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Gong.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Sc/Gong.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Gong.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/audio-volume-muted-blocked-panel.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/24/audio-volume-muted-blocked-panel.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/audio-volume-muted-blocked-panel.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/aspell/en_US-variant_0.multi' # original
remove_cmd '/mnt/wslg/distro/usr/lib/aspell/english-variant_0.alias' '/mnt/wslg/distro/usr/lib/aspell/en_US-variant_0.multi' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/aspell/en_US-variant_1.multi' # original
remove_cmd '/mnt/wslg/distro/usr/lib/aspell/english-variant_1.alias' '/mnt/wslg/distro/usr/lib/aspell/en_US-variant_1.multi' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/dpkg/triggers/update-ca-certificates' # original
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/triggers/update-ca-certificates-fresh' '/mnt/wslg/distro/var/lib/dpkg/triggers/update-ca-certificates' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/bug/file/control' # original
remove_cmd '/mnt/wslg/distro/usr/share/bug/libmagic1/control' '/mnt/wslg/distro/usr/share/bug/file/control' # duplicate
original_cmd '/mnt/wslg/distro/etc/dotnet/install_location' # original
remove_cmd '/mnt/wslg/distro/etc/dotnet/install_location_x64' '/mnt/wslg/distro/etc/dotnet/install_location' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Hyphen/T.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Hyphen/T.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Hyphen/T.pl' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libgl1:amd64.triggers' # original
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libglvnd0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libgl1:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libglx0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libgl1:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libpciaccess0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libgl1:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libasound2:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libgl1:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libstb0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libgl1:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libjack-jackd2-0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libgl1:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libgsm1:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libgl1:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libfaudio0:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libgl1:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libtag1v5-vanilla:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libgl1:amd64.triggers' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libxt6:amd64.triggers' '/mnt/wslg/distro/var/lib/dpkg/info/libgl1:amd64.triggers' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:fileinfo.ini' # original
remove_cmd '/mnt/wslg/distro/usr/share/php8.1-common/common/fileinfo.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:fileinfo.ini' # duplicate
remove_cmd '/mnt/wslg/distro/etc/php/8.1/mods-available/fileinfo.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:fileinfo.ini' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:calendar.ini' # original
remove_cmd '/mnt/wslg/distro/usr/share/php8.1-common/common/calendar.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:calendar.ini' # duplicate
remove_cmd '/mnt/wslg/distro/etc/php/8.1/mods-available/calendar.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:calendar.ini' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/bug/libgl1-amber-dri/script' # original
remove_cmd '/mnt/wslg/distro/usr/share/bug/libglx-mesa0/script' '/mnt/wslg/distro/usr/share/bug/libgl1-amber-dri/script' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/bug/libgl1-mesa-dri/script' '/mnt/wslg/distro/usr/share/bug/libgl1-amber-dri/script' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/bug/libglapi-mesa/script' '/mnt/wslg/distro/usr/share/bug/libgl1-amber-dri/script' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/bug/libosmesa6/script' '/mnt/wslg/distro/usr/share/bug/libgl1-amber-dri/script' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/bug/mesa-vulkan-drivers/script' '/mnt/wslg/distro/usr/share/bug/libgl1-amber-dri/script' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/bug/libgbm1/script' '/mnt/wslg/distro/usr/share/bug/libgl1-amber-dri/script' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/libgsm1/MACHINES' # original
remove_cmd '/mnt/wslg/doc/gsm/MACHINES' '/mnt/wslg/distro/usr/share/doc/libgsm1/MACHINES' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Sinh.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Sc/Sinh.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Sinh.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/QMark/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/QMark/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/QMark/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/300.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/300.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/300.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/900.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/900.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/900.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/WB/ML.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/WB/ML.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/WB/ML.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/places/64/folder-home.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/places/64/folder-home.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/places/64/folder-home.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/empathy-busy.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/tray-busy.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/empathy-busy.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/user-busy-panel.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/empathy-busy.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/empathy-busy.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/tray-busy.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/empathy-busy.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/user-busy-panel.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/empathy-busy.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Sc.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Gc/Sc.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/Sc.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/VowelDep.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/InSC/VowelDep.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/VowelDep.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/500.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/500.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/500.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Takr.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Takr.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Takr.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Kthi.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Kthi.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Kthi.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InPC/BottomAn.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/InPC/BottomAn.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InPC/BottomAn.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Khoj.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Khoj.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Khoj.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Ccc/ATAR.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Ccc/ATAR.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Ccc/ATAR.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/edit-find-symbolic.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/system-search-symbolic.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/edit-find-symbolic.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Phlp.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Phlp.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Phlp.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Sind.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Sind.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Sind.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Mymr.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Mymr.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Mymr.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Ccc/NK.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Ccc/NK.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Ccc/NK.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/Carp/Heavy.pm' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/Carp/Heavy.pm' '/mnt/wslg/distro/usr/share/perl/5.34.0/Carp/Heavy.pm' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/_PerlFol.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Perl/_PerlFol.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/_PerlFol.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/X11/locale/C/XI18N_OBJS' # original
remove_cmd '/mnt/wslg/distro/usr/share/X11/locale/iso8859-1/XI18N_OBJS' '/mnt/wslg/distro/usr/share/X11/locale/C/XI18N_OBJS' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/actions/16/window-restore-symbolic.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/actions/16/window-restore-symbolic.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/actions/16/window-restore-symbolic.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/Blank.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Perl/Blank.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/Blank.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/VowelInd.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/InSC/VowelInd.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/VowelInd.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/50.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/50.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/50.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Bpt/N.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Bpt/N.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Bpt/N.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/GCB/PP.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/GCB/PP.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/GCB/PP.pl' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/systemd/deb-systemd-helper-enabled/uuidd.service.dsh-also' # original
remove_cmd '/mnt/wslg/distro/var/lib/systemd/deb-systemd-helper-enabled/uuidd.socket.dsh-also' '/mnt/wslg/distro/var/lib/systemd/deb-systemd-helper-enabled/uuidd.service.dsh-also' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_buffer.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_buffer.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_buffer.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V50.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Age/V50.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V50.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V60.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Age/V60.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V60.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/gpm-primary-060-charging.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/48/gpm-primary-060-charging.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/gpm-primary-060-charging.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/gpm-primary-080-charging.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/48/gpm-primary-080-charging.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/gpm-primary-080-charging.svg' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/play_rec_rand.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/play_rec_rand.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/play_rec_rand.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/play_rec_rand.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/play_rec_rand.gif' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/play.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/play.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/play.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/play.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/play.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/play_selected.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/play.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/play_selected.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/play.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/play_selected.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/play.gif' # duplicate
original_cmd '/mnt/wslg/doc/expat/AUTHORS' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/libexpat1/AUTHORS' '/mnt/wslg/doc/expat/AUTHORS' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/dpkg/info/perl.postrm' # original
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/perl.preinst' '/mnt/wslg/distro/var/lib/dpkg/info/perl.postrm' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/perl.prerm' '/mnt/wslg/distro/var/lib/dpkg/info/perl.postrm' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-wwan-tower.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/22/nm-wwan-tower.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-wwan-tower.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/nm-mb-roam.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-wwan-tower.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/nm-tech-3g.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-wwan-tower.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/nm-tech-cdma-1x.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-wwan-tower.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/nm-tech-edge.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-wwan-tower.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/nm-tech-evdo.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-wwan-tower.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/nm-tech-gprs.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-wwan-tower.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/nm-tech-hspa.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-wwan-tower.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/nm-tech-umts.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-wwan-tower.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/nm-wwan-tower.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-wwan-tower.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/22/nm-wwan-tower.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-wwan-tower.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/apache2/icons/odf6odp-20x22.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/apache2/icons/odf6odp.png' '/mnt/wslg/distro/usr/share/apache2/icons/odf6odp-20x22.png' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/apache2/icons/odf6odb-20x22.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/apache2/icons/odf6odb.png' '/mnt/wslg/distro/usr/share/apache2/icons/odf6odb-20x22.png' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/X11/locale/iso8859-9/XI18N_OBJS' # original
remove_cmd '/mnt/wslg/distro/usr/share/X11/locale/iso8859-2/XI18N_OBJS' '/mnt/wslg/distro/usr/share/X11/locale/iso8859-9/XI18N_OBJS' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/X11/locale/iso8859-7/XI18N_OBJS' '/mnt/wslg/distro/usr/share/X11/locale/iso8859-9/XI18N_OBJS' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/X11/locale/iso8859-5/XI18N_OBJS' '/mnt/wslg/distro/usr/share/X11/locale/iso8859-9/XI18N_OBJS' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/X11/locale/iso8859-13/XI18N_OBJS' '/mnt/wslg/distro/usr/share/X11/locale/iso8859-9/XI18N_OBJS' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/format-justify-fill-symbolic.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/open-menu-symbolic.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/format-justify-fill-symbolic.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/apache2/icons/odf6otc-20x22.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/apache2/icons/odf6otc.png' '/mnt/wslg/distro/usr/share/apache2/icons/odf6otc-20x22.png' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/apache2/icons/odf6odf-20x22.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/apache2/icons/odf6odf.png' '/mnt/wslg/distro/usr/share/apache2/icons/odf6odf-20x22.png' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/systemd/user/gpg-agent-ssh.socket' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/gnupg/examples/systemd-user/gpg-agent-ssh.socket' '/mnt/wslg/distro/usr/lib/systemd/user/gpg-agent-ssh.socket' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libpulse0:amd64.postinst' # original
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libpulse0:amd64.postrm' '/mnt/wslg/distro/var/lib/dpkg/info/libpulse0:amd64.postinst' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libpulse0:amd64.preinst' '/mnt/wslg/distro/var/lib/dpkg/info/libpulse0:amd64.postinst' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/libpulse0:amd64.prerm' '/mnt/wslg/distro/var/lib/dpkg/info/libpulse0:amd64.postinst' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/regen.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/regen.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/regen.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/regen.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/regen.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/regen_genres.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/regen.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/regen_genres.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/regen.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/regen_genres.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/regen.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/apache2/icons/odf6ots-20x22.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/apache2/icons/odf6ots.png' '/mnt/wslg/distro/usr/share/apache2/icons/odf6ots-20x22.png' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/edit.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/edit.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/edit.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/edit.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/edit.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/apache2/icons/odf6odg-20x22.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/apache2/icons/odf6odg.png' '/mnt/wslg/distro/usr/share/apache2/icons/odf6odg-20x22.png' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/lyr_edit.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/lyr_edit.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/lyr_edit.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/lyr_edit.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/lyr_edit.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/lyr_edit.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/lyr_edit.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/lyrics_edit.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/lyr_edit.gif' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/lyr.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/lyr.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/lyr.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/lyr.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/lyr.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/lyr.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/lyr.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/lyrics.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/lyr.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/apache2/icons/odf6odt-20x22.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/apache2/icons/odf6odt.png' '/mnt/wslg/distro/usr/share/apache2/icons/odf6odt-20x22.png' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Han.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Han.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Han.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/apache2/icons/uu.gif' # original
remove_cmd '/mnt/wslg/distro/usr/share/apache2/icons/uuencoded.gif' '/mnt/wslg/distro/usr/share/apache2/icons/uu.gif' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/mm/avi.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/mm/avi.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/mm/avi.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/mm/avi.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/mm/avi.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/pgen2/__init__.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/pgen2/__init__.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/pgen2/__init__.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/systemd/user/gpg-agent.service' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/gnupg/examples/systemd-user/gpg-agent.service' '/mnt/wslg/distro/usr/lib/systemd/user/gpg-agent.service' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/apache2/icons/odf6ott-20x22.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/apache2/icons/odf6ott.png' '/mnt/wslg/distro/usr/share/apache2/icons/odf6ott-20x22.png' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/apache2/icons/odf6odi-20x22.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/apache2/icons/odf6odi.png' '/mnt/wslg/distro/usr/share/apache2/icons/odf6odi-20x22.png' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gnome-netstatus-rx.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/network-receive.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gnome-netstatus-rx.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/emblems/emblem-ok-symbolic.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/actions/object-select-symbolic.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/emblems/emblem-ok-symbolic.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/apache2/icons/odf6ods-20x22.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/apache2/icons/odf6ods.png' '/mnt/wslg/distro/usr/share/apache2/icons/odf6ods-20x22.png' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/mm/pdf.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/mm/pdf.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/mm/pdf.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/mm/pdf.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/mm/pdf.gif' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/genres.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/genres.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/genres.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/genres.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/genres.gif' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/download.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/download.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/download.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/download.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/download.gif' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/star.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/star.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/star.gif' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/new.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/new.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/new.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/apache2/icons/dir.gif' # original
remove_cmd '/mnt/wslg/distro/usr/share/apache2/icons/folder.gif' '/mnt/wslg/distro/usr/share/apache2/icons/dir.gif' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/sgml-base/supercatalog.old' # original
remove_cmd '/mnt/wslg/distro/var/lib/sgml-base/supercatalog' '/mnt/wslg/distro/var/lib/sgml-base/supercatalog.old' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Number.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/InSC/Number.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Number.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V31.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Age/V31.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V31.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_exec.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_exec.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_exec.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/apache2/icons/odf6otp-20x22.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/apache2/icons/odf6otp.png' '/mnt/wslg/distro/usr/share/apache2/icons/odf6otp-20x22.png' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/README' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/README' '/mnt/wslg/distro/usr/lib/python3.10/distutils/README' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/apache2/icons/odf6otf-20x22.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/apache2/icons/odf6otf.png' '/mnt/wslg/distro/usr/share/apache2/icons/odf6otf-20x22.png' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/apache2/icons/odf6odc-20x22.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/apache2/icons/odf6odc.png' '/mnt/wslg/distro/usr/share/apache2/icons/odf6odc-20x22.png' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/apache2/icons/odf6odm-20x22.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/apache2/icons/odf6odm.png' '/mnt/wslg/distro/usr/share/apache2/icons/odf6odm-20x22.png' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/apache2/icons/odf6oti-20x22.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/apache2/icons/odf6oti.png' '/mnt/wslg/distro/usr/share/apache2/icons/odf6oti-20x22.png' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/apache2/icons/odf6otg-20x22.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/apache2/icons/odf6otg.png' '/mnt/wslg/distro/usr/share/apache2/icons/odf6otg-20x22.png' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/stars-1.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/zinamp/skins/WinampClassic/images/stars-1.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/stars-1.gif' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/stars-2.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/zinamp/skins/WinampClassic/images/stars-2.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/stars-2.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/apache2/icons/odf6oth-20x22.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/apache2/icons/odf6oth.png' '/mnt/wslg/distro/usr/share/apache2/icons/odf6oth-20x22.png' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/dpkg/info/perl-base.postinst' # original
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/perl-base.postrm' '/mnt/wslg/distro/var/lib/dpkg/info/perl-base.postinst' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/perl-base.preinst' '/mnt/wslg/distro/var/lib/dpkg/info/perl-base.postinst' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/perl-base.prerm' '/mnt/wslg/distro/var/lib/dpkg/info/perl-base.postinst' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/debug.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/debug.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/debug.py' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/debug.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/debug.py' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/check.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/check.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/check.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/check.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/check.gif' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/zinamp/skins/WinampClassic/style.css' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/zinamp/skins/Silver/style.css' '/mnt/wslg/distro/var/www/html/zina/zina/zinamp/skins/WinampClassic/style.css' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/48x48/actions/format-justify-fill-symbolic.symbolic.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/48x48/actions/open-menu-symbolic.symbolic.png' '/mnt/wslg/distro/usr/share/icons/Adwaita/48x48/actions/format-justify-fill-symbolic.symbolic.png' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/apache2/icons/dir.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/apache2/icons/folder.png' '/mnt/wslg/distro/usr/share/apache2/icons/dir.png' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/ui/selection-end-symbolic.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/ui/selection-start-symbolic-rtl.svg' '/mnt/wslg/distro/usr/share/icons/Adwaita/scalable/ui/selection-end-symbolic.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/bug/php8.1-common/control' # original
remove_cmd '/mnt/wslg/distro/usr/share/bug/php8.1-readline/control' '/mnt/wslg/distro/usr/share/bug/php8.1-common/control' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/bug/php8.1-opcache/control' '/mnt/wslg/distro/usr/share/bug/php8.1-common/control' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/dpkg/info/git.postinst' # original
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/git.postrm' '/mnt/wslg/distro/var/lib/dpkg/info/git.postinst' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/info/git.prerm' '/mnt/wslg/distro/var/lib/dpkg/info/git.postinst' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/tab_edit.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/tab_edit.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/tab_edit.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/tab_edit.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/tab_edit.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/tab_edit.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/tab_edit.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/docker-compose-plugin/changelog.Debian.gz' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/docker-ce-cli/changelog.Debian.gz' '/mnt/wslg/distro/usr/share/doc/docker-compose-plugin/changelog.Debian.gz' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/docker-ce-rootless-extras/changelog.Debian.gz' '/mnt/wslg/distro/usr/share/doc/docker-compose-plugin/changelog.Debian.gz' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/docker-ce/changelog.Debian.gz' '/mnt/wslg/distro/usr/share/doc/docker-compose-plugin/changelog.Debian.gz' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/docker-buildx-plugin/changelog.Debian.gz' '/mnt/wslg/distro/usr/share/doc/docker-compose-plugin/changelog.Debian.gz' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/download_custom.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/download_custom.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/download_custom.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/download_custom.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/download_custom.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/bug/wine/script' # original
remove_cmd '/mnt/wslg/distro/usr/share/bug/wine64/script' '/mnt/wslg/distro/usr/share/bug/wine/script' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/bug/libwine/script' '/mnt/wslg/distro/usr/share/bug/wine/script' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/bug/fonts-wine/script' '/mnt/wslg/distro/usr/share/bug/wine/script' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/delete.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/delete.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/delete.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/delete.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/delete.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/64x64/actions/format-justify-fill-symbolic.symbolic.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/64x64/actions/open-menu-symbolic.symbolic.png' '/mnt/wslg/distro/usr/share/icons/Adwaita/64x64/actions/format-justify-fill-symbolic.symbolic.png' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/playlist.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/playlist.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/playlist.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/playlist.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/playlist.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/apache2/icons/uu.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/apache2/icons/uuencoded.png' '/mnt/wslg/distro/usr/share/apache2/icons/uu.png' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/play_rec.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/play_rec.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/play_rec.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/play_rec.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/play_rec.gif' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/play_lofi.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/play_lofi.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/play_lofi.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/play_lofi.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/play_lofi.gif' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/mm/mpeg.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/mm/mpeg.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/mm/mpeg.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/mm/mpeg.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/mm/mpeg.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/mm/mpg.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/mm/mpeg.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/mm/mpg.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/mm/mpeg.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/mm/mpg.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/mm/mpeg.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/24x24/actions/format-justify-fill-symbolic.symbolic.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Adwaita/24x24/actions/open-menu-symbolic.symbolic.png' '/mnt/wslg/distro/usr/share/icons/Adwaita/24x24/actions/format-justify-fill-symbolic.symbolic.png' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/apache2/default-site/index.html' # original
remove_cmd '/mnt/wslg/distro/var/www/html/index.html' '/mnt/wslg/distro/usr/share/apache2/default-site/index.html' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Dt/Med.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Dt/Med.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Dt/Med.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-020-charging.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-ups-020-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-020-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/unity-gpm-battery-020-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-020-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/xfpm-primary-020-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-020-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/xfpm-ups-020-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-020-charging.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/mallard.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/mallard.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/mallard.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/2_0.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/In/2_0.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/2_0.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/2_1.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/In/2_1.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/In/2_1.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-100-charging.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-ups-100-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-100-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/unity-gpm-battery-100-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-100-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/xfpm-primary-100-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-100-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/xfpm-ups-100-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-100-charging.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Bpb.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/Bpb.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Bpb.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/NFDQC/Y.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/NFDQC/Y.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/NFDQC/Y.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Ccc/A.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Ccc/A.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Ccc/A.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/9.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/9.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/9.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/connect_no.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gnome-netstatus-disconn.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/connect_no.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/network-offline.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/connect_no.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/nm-no-connection.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/connect_no.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/stock_disconnect.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/connect_no.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/PR.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Lb/PR.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Lb/PR.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-keyboard-000.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-keyboard-000.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-keyboard-000.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-keyboard-000.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-keyboard-000.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-keyboard-000.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/IdType/Exclusio.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/IdType/Exclusio.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/IdType/Exclusio.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_print.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_print.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_print.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/errors.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/errors.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/errors.py' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/errors.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/errors.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/empathy-offline.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/tray-offline.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/empathy-offline.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/user-offline-panel.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/empathy-offline.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/empathy-offline.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/tray-offline.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/empathy-offline.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/user-offline-panel.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/empathy-offline.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-000-charging.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-ups-000-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-000-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/unity-gpm-battery-000-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-000-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/xfpm-primary-000-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-000-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/xfpm-ups-000-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-000-charging.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-important.icon' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-important.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-important.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/22/emblem-important.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-important.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/32/emblem-important.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-important.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/24/emblem-important.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-important.icon' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-package.icon' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/32/emblem-package.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-package.icon' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage01-connecting10.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/22/nm-stage01-connecting10.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage01-connecting10.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InPC/NA.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/InPC/NA.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InPC/NA.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-documents.icon' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-documents.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-documents.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/22/emblem-documents.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-documents.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/32/emblem-documents.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-documents.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/24/emblem-documents.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-documents.icon' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/2.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/2.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/2.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-storm.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-storm.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-storm.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gsm-3g-full.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/nm-device-wwan.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gsm-3g-full.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V70.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Age/V70.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Age/V70.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/S.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Gc/S.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/S.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/empathy-extended-away.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/tray-extended-away.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/empathy-extended-away.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/user-idle-panel.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/empathy-extended-away.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Zyyy.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Sc/Zyyy.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Zyyy.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds-night-000.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds-night-010.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds-night-020.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds-night-030.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds-night-040.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds-night-050.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds-night-060.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds-night-070.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds-night-080.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds-night-090.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds-night-100.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds-night-110.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds-night-120.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds-night-130.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds-night-140.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds-night-150.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds-night-160.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds-night-170.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds-night-180.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds-night-190.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds-night-200.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds-night-210.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds-night-220.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds-night-230.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds-night-240.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds-night-250.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds-night-260.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds-night-270.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds-night-280.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds-night-290.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds-night-300.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds-night-310.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds-night-320.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds-night-330.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds-night-340.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds-night-350.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-few-clouds-night.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-night-few-clouds.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-snow.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/weather-snow.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/stock_weather-snow.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/actions/22/package-supported.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/actions/22/package-supported.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/actions/22/package-supported.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/actions/24/package-supported.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/actions/24/package-supported.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/actions/24/package-supported.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_raise.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_raise.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_raise.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/command/install_data.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/command/install_data.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/command/install_data.py' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/command/install_data.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/command/install_data.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/keyrings/docker-archive-keyring.gpg' # original
remove_cmd '/mnt/wslg/distro/etc/apt/keyrings/docker.gpg' '/mnt/wslg/distro/usr/share/keyrings/docker-archive-keyring.gpg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/Unicode/Collate/Locale/nso.pl' # original
remove_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/Unicode/Collate/Locale/tn.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/Unicode/Collate/Locale/nso.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/IdType/NotNFKC.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/IdType/NotNFKC.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/IdType/NotNFKC.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Jg.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/Jg.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Jg.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/command/install_scripts.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/command/install_scripts.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/command/install_scripts.py' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/command/install_scripts.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/command/install_scripts.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/importlib_metadata/_itertools.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.10/importlib/metadata/_itertools.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/importlib_metadata/_itertools.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Dt/Sqr.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Dt/Sqr.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Dt/Sqr.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/WB/HL.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/WB/HL.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/WB/HL.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-keyboard-100.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-keyboard-100.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-keyboard-100.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-040-charging.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-ups-040-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-040-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/unity-battery-040-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-040-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/unity-gpm-battery-040-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-040-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/xfpm-primary-040-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-040-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/xfpm-ups-040-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-040-charging.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-060-charging.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-ups-060-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-060-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/unity-battery-060-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-060-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/unity-gpm-battery-060-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-060-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-primary-060-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-060-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-ups-060-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-060-charging.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-060-charging.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-ups-060-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-060-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/unity-battery-060-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-060-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/unity-gpm-battery-060-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-060-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/xfpm-primary-060-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-060-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/xfpm-ups-060-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-060-charging.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-080-charging.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-ups-080-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-080-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/unity-battery-080-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-080-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/unity-gpm-battery-080-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-080-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-primary-080-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-080-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-ups-080-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-primary-080-charging.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-080-charging.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-ups-080-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-080-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/unity-battery-080-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-080-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/unity-gpm-battery-080-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-080-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/xfpm-primary-080-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-080-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/xfpm-ups-080-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-080-charging.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-keyboard-060.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-keyboard-060.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-keyboard-060.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_renames.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_renames.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_renames.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/changelog.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/changelog.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/changelog.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/sweave.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/sweave.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/sweave.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-keyboard-100.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfpm-keyboard-100.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gpm-keyboard-100.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-sound.icon' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/32/emblem-sound.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-sound.icon' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/csv.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/csv.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/csv.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/6.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/6.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/6.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/_PerlAny.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Perl/_PerlAny.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Perl/_PerlAny.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_filter.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_filter.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_filter.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nt/None.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nt/None.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nt/None.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage02-connecting05.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/24/nm-stage02-connecting05.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage02-connecting05.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage02-connecting05.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/22/nm-stage02-connecting05.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage02-connecting05.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-danger.icon' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-danger.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-danger.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/22/emblem-danger.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-danger.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/32/emblem-danger.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-danger.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/24/emblem-danger.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-danger.icon' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/gpgconf/examples/gpgconf.conf' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/gnupg/examples/gpgconf.conf' '/mnt/wslg/distro/usr/share/doc/gpgconf/examples/gpgconf.conf' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage03-connecting06.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/22/nm-stage03-connecting06.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage03-connecting06.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage03-connecting05.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/22/nm-stage03-connecting05.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage03-connecting05.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage03-connecting06.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/24/nm-stage03-connecting06.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage03-connecting06.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage03-connecting05.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/24/nm-stage03-connecting05.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage03-connecting05.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_except.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_except.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_except.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/application-community.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/categories/24/application-community.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/application-community.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_map.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_map.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_map.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_import.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_import.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_import.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InPC/TopAndL2.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/InPC/TopAndL2.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InPC/TopAndL2.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Armn.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Armn.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Armn.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Deva.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Sc/Deva.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Sc/Deva.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Ccc/BR.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Ccc/BR.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Ccc/BR.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Ccc/AL.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Ccc/AL.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Ccc/AL.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Consona9.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/InSC/Consona9.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Consona9.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Dt/Sub.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Dt/Sub.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Dt/Sub.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-100.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-ups-100.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-100.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/unity-gpm-battery-100.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-100.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/xfpm-primary-100.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-100.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/xfpm-ups-100.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-100.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-080.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-ups-080.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-080.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/unity-gpm-battery-080.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-080.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/xfpm-primary-080.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-080.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/xfpm-ups-080.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-080.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-060.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-ups-060.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-060.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/unity-gpm-battery-060.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-060.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/xfpm-primary-060.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-060.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/xfpm-ups-060.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gpm-primary-060.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/22/krb-expiring-ticket.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/22/krb-expiring-ticket.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/status/22/krb-expiring-ticket.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/animations/24/nm-stage01-connecting04.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/animations/24/nm-stage01-connecting04.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/animations/24/nm-stage01-connecting04.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/animations/24/nm-stage01-connecting07.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/animations/24/nm-stage01-connecting07.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/animations/24/nm-stage01-connecting07.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/animations/24/nm-stage01-connecting10.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/animations/24/nm-stage01-connecting10.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/animations/24/nm-stage01-connecting10.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-100-charging.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-ups-100-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-100-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/unity-battery-100-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-100-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/unity-gpm-battery-100-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-100-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/xfpm-primary-100-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-100-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/xfpm-ups-100-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-100-charging.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gnome-netstatus-error.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/network-error.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gnome-netstatus-error.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gnome-netstatus-error.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/network-error.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/gnome-netstatus-error.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Bc/ON.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Bc/ON.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Bc/ON.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-020-charging.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-ups-020-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-020-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/unity-battery-020-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-020-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/unity-gpm-battery-020-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-020-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/xfpm-primary-020-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-020-charging.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/xfpm-ups-020-charging.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/16/gpm-primary-020-charging.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage02-connecting11.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/24/nm-stage02-connecting11.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage02-connecting11.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/application-community.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/categories/22/application-community.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/application-community.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/categories/24/preferences-system-directory.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/categories/24/preferences-system-directory.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/categories/24/preferences-system-directory.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-showers.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-showers.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-showers.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/GCB/CN.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/GCB/CN.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/GCB/CN.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage03-connecting03.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/24/nm-stage03-connecting03.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/24/nm-stage03-connecting03.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage03-connecting03.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/22/nm-stage03-connecting03.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage03-connecting03.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Arab.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Arab.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Arab.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InPC/Top.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/InPC/Top.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InPC/Top.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-cloudy.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/weather-overcast.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-dark/status/16/stock_weather-cloudy.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/adduser/adduser.conf' # original
remove_cmd '/mnt/wslg/distro/etc/adduser.conf' '/mnt/wslg/distro/usr/share/adduser/adduser.conf' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-people.icon' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/48/emblem-people.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-people.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/22/emblem-people.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-people.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/32/emblem-people.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-people.icon' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/24/emblem-people.icon' '/mnt/wslg/distro/usr/share/icons/Humanity/emblems/16/emblem-people.icon' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-mouse-100.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/xfpm-mouse-100.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/22/gpm-mouse-100.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/LC.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Gc/LC.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Gc/LC.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/audio-volume-medium.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/24/audio-volume-medium.png' '/mnt/wslg/distro/usr/share/icons/Humanity/status/24/audio-volume-medium.png' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/mm/asf.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/mm/asf.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/mm/asf.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/mm/asf.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/mm/asf.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/mm/wmv.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/mm/asf.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/mm/wmv.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/mm/asf.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/mm/wmv.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/mm/asf.gif' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/play_custom.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/play_custom.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/play_custom.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/play_custom.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/play_custom.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/systemd/user/gpg-agent.socket' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/gnupg/examples/systemd-user/gpg-agent.socket' '/mnt/wslg/distro/usr/lib/systemd/user/gpg-agent.socket' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/populate_db.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/populate_db.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/populate_db.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/sockCrystal/icons/populate_db.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/populate_db.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/populate_db.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/populate_db.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/command/clean.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.10/distutils/command/clean.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/command/clean.py' # duplicate
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/distutils/command/clean.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_distutils/command/clean.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/22/audio-volume-muted.png' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/22/audio-volume-muted.png' '/mnt/wslg/distro/usr/share/icons/Humanity/status/22/audio-volume-muted.png' # duplicate
original_cmd '/mnt/wslg/distro/usr/bin/kill' # original
remove_cmd '/mnt/wslg/distro/usr/bin/skill' '/mnt/wslg/distro/usr/bin/kill' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/3.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Nv/3.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Nv/3.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_reload.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_reload.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_reload.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage01-connecting01.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/22/nm-stage01-connecting01.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-stage01-connecting01.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gnome-netstatus-tx.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/network-transmit.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/gnome-netstatus-tx.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/bin/bunzip2' # original
remove_cmd '/mnt/wslg/distro/usr/bin/bzcat' '/mnt/wslg/distro/usr/bin/bunzip2' # duplicate
remove_cmd '/mnt/wslg/distro/usr/bin/bzip2' '/mnt/wslg/distro/usr/bin/bunzip2' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/audio-volume-muted-panel.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfce4-mixer-muted.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/audio-volume-muted-panel.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/xfce4-mixer-volume-muted.svg' '/mnt/wslg/distro/usr/share/icons/ubuntu-mono-light/status/24/audio-volume-muted-panel.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/Unicode/Collate/Locale/nb.pl' # original
remove_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/Unicode/Collate/Locale/nn.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/Unicode/Collate/Locale/nb.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Deva.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Deva.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Deva.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Thaa.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Thaa.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Thaa.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Bc/AN.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Bc/AN.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Bc/AN.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Rohg.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/Scx/Rohg.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/Scx/Rohg.pl' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/docker/overlay2/eb62213d5101cb801d7961f4b4b0c2032b533f87f8feba94c1e249dd90eb33a4/diff/usr/bin/rsync-ssl' # original
remove_cmd '/mnt/wslg/distro/usr/bin/rsync-ssl' '/mnt/wslg/distro/var/lib/docker/overlay2/eb62213d5101cb801d7961f4b4b0c2032b533f87f8feba94c1e249dd90eb33a4/diff/usr/bin/rsync-ssl' # duplicate
original_cmd '/mnt/wslg/distro/usr/bin/precat' # original
remove_cmd '/mnt/wslg/distro/usr/bin/preunzip' '/mnt/wslg/distro/usr/bin/precat' # duplicate
remove_cmd '/mnt/wslg/distro/usr/bin/prezip' '/mnt/wslg/distro/usr/bin/precat' # duplicate
original_cmd '/mnt/wslg/distro/usr/bin/pgrep' # original
remove_cmd '/mnt/wslg/distro/usr/bin/pidwait' '/mnt/wslg/distro/usr/bin/pgrep' # duplicate
original_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/login.gif' # original
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaDark/icons/login.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/login.gif' # duplicate
remove_cmd '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaEmbed/icons/login.gif' '/mnt/wslg/distro/var/www/html/zina/zina/themes/zinaGarland/icons/login.gif' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Consona4.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/lib/InSC/Consona4.pl' '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/lib/InSC/Consona4.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/bin/gunzip' # original
remove_cmd '/mnt/wslg/distro/usr/bin/uncompress' '/mnt/wslg/distro/usr/bin/gunzip' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_apply.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3.11/lib2to3/fixes/fix_apply.py' '/mnt/wslg/distro/usr/lib/python3.10/lib2to3/fixes/fix_apply.py' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:opcache.ini' # original
remove_cmd '/mnt/wslg/distro/usr/share/php8.1-opcache/opcache/opcache.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:opcache.ini' # duplicate
remove_cmd '/mnt/wslg/distro/etc/php/8.1/mods-available/opcache.ini' '/mnt/wslg/distro/var/lib/ucf/cache/:etc:php:8.1:mods-available:opcache.ini' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/dpkg/triggers/aspell-autobuildhash' # original
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/triggers/ispell-autobuildhash' '/mnt/wslg/distro/var/lib/dpkg/triggers/aspell-autobuildhash' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/triggers/update-default-ispell' '/mnt/wslg/distro/var/lib/dpkg/triggers/aspell-autobuildhash' # duplicate
remove_cmd '/mnt/wslg/distro/var/lib/dpkg/triggers/update-default-wordlist' '/mnt/wslg/distro/var/lib/dpkg/triggers/aspell-autobuildhash' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-vpn-connecting04.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/apps/22/nm-vpn-connecting04.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/apps/22/nm-vpn-connecting04.svg' # duplicate
original_cmd '/mnt/wslg/distro/etc/php/8.1/cli/php.ini' # original
remove_cmd '/mnt/wslg/distro/usr/lib/php/8.1/php.ini-production.cli' '/mnt/wslg/distro/etc/php/8.1/cli/php.ini' # duplicate
original_cmd '/mnt/wslg/distro/etc/php/8.1/apache2/php.ini' # original
remove_cmd '/mnt/wslg/distro/usr/lib/php/8.1/php.ini-production' '/mnt/wslg/distro/etc/php/8.1/apache2/php.ini' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/48/weather-clouds-night.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/weather-clouds-night.svg' '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/48/weather-clouds-night.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/maxima.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/maxima.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/maxima.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/R.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/R.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/R.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/perl-base/copyright' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/perl/copyright' '/mnt/wslg/distro/usr/share/doc/perl-base/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/libperl5.34/copyright' '/mnt/wslg/distro/usr/share/doc/perl-base/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/perl-modules-5.34/copyright' '/mnt/wslg/distro/usr/share/doc/perl-base/copyright' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/Config_heavy.pl' # original
remove_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl/5.34.0/Config_heavy.pl' '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/Config_heavy.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/Identif2.pl' # original
remove_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Identif2.pl' '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/Identif2.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/Gc.pl' # original
remove_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Gc.pl' '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/Gc.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/SB.pl' # original
remove_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/SB.pl' '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/SB.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/Na1.pl' # original
remove_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/Na1.pl' '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/Na1.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/libgstreamer-plugins-base1.0-0/copyright' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/gstreamer1.0-x/copyright' '/mnt/wslg/distro/usr/share/doc/libgstreamer-plugins-base1.0-0/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/gstreamer1.0-plugins-base/copyright' '/mnt/wslg/distro/usr/share/doc/libgstreamer-plugins-base1.0-0/copyright' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/gstreamer1.0-plugins-good/copyright' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/libgstreamer-plugins-good1.0-0/copyright' '/mnt/wslg/distro/usr/share/doc/gstreamer1.0-plugins-good/copyright' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/libgphoto2-port12/copyright' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/libgphoto2-l10n/copyright' '/mnt/wslg/distro/usr/share/doc/libgphoto2-port12/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/libgphoto2-6/copyright' '/mnt/wslg/distro/usr/share/doc/libgphoto2-port12/copyright' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/m4.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/m4.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/m4.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/octave.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/octave.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/octave.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/X11/xkb/rules/base.lst' # original
remove_cmd '/mnt/wslg/distro/usr/share/X11/xkb/rules/evdev.lst' '/mnt/wslg/distro/usr/share/X11/xkb/rules/base.lst' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/X11/xkb/rules/base.extras.xml' # original
remove_cmd '/mnt/wslg/distro/usr/share/X11/xkb/rules/evdev.extras.xml' '/mnt/wslg/distro/usr/share/X11/xkb/rules/base.extras.xml' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/categories/48/applications-astronomy.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/48/weather-clear-night.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/categories/48/applications-astronomy.svg' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/weather-clear-night.svg' '/mnt/wslg/distro/usr/share/icons/Humanity/categories/48/applications-astronomy.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/libpangoxft-1.0-0/copyright' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/gir1.2-pango-1.0/copyright' '/mnt/wslg/distro/usr/share/doc/libpangoxft-1.0-0/copyright' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/asp.lang' # original
remove_cmd '/mnt/wslg/distro/usr/share/gtksourceview-4/language-specs/asp.lang' '/mnt/wslg/distro/usr/share/gtksourceview-3.0/language-specs/asp.lang' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/48/weather-few-clouds-night.svg' # original
remove_cmd '/mnt/wslg/distro/usr/share/icons/Humanity/status/48/weather-few-clouds-night.svg' '/mnt/wslg/distro/usr/share/icons/Humanity-Dark/status/48/weather-few-clouds-night.svg' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/X11/xkb/rules/base.xml' # original
remove_cmd '/mnt/wslg/distro/usr/share/X11/xkb/rules/evdev.xml' '/mnt/wslg/distro/usr/share/X11/xkb/rules/base.xml' # duplicate
original_cmd '/mnt/wslg/distro/usr/share/doc/libkrb5-3/copyright' # original
remove_cmd '/mnt/wslg/distro/usr/share/doc/libkrb5support0/copyright' '/mnt/wslg/distro/usr/share/doc/libkrb5-3/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/libgssapi-krb5-2/copyright' '/mnt/wslg/distro/usr/share/doc/libkrb5-3/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/krb5-locales/copyright' '/mnt/wslg/distro/usr/share/doc/libkrb5-3/copyright' # duplicate
remove_cmd '/mnt/wslg/distro/usr/share/doc/libk5crypto3/copyright' '/mnt/wslg/distro/usr/share/doc/libkrb5-3/copyright' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/NFKCCF.pl' # original
remove_cmd '/mnt/wslg/distro/usr/share/perl/5.34.0/unicore/To/NFKCCF.pl' '/mnt/wslg/distro/usr/lib/x86_64-linux-gnu/perl-base/unicore/To/NFKCCF.pl' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_vendor/pyparsing.py' # original
remove_cmd '/mnt/wslg/distro/usr/lib/python3/dist-packages/pkg_resources/_vendor/pyparsing.py' '/mnt/wslg/distro/usr/lib/python3/dist-packages/setuptools/_vendor/pyparsing.py' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/git-core/git-shell' # original
remove_cmd '/mnt/wslg/distro/usr/bin/git-shell' '/mnt/wslg/distro/usr/lib/git-core/git-shell' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/docker/overlay2/c95f9cd902c37ef7e6d5de68ac18aafba154e456a6207b8800ed18b1f4d171db/diff/home/עכשיו ומיד by Michael Swissa.mp3.mp3' # original
remove_cmd '/mnt/wslg/distro/var/lib/docker/overlay2/c95f9cd902c37ef7e6d5de68ac18aafba154e456a6207b8800ed18b1f4d171db/diff/home/רטינה by Michael Swissa.mp3.mp3' '/mnt/wslg/distro/var/lib/docker/overlay2/c95f9cd902c37ef7e6d5de68ac18aafba154e456a6207b8800ed18b1f4d171db/diff/home/עכשיו ומיד by Michael Swissa.mp3.mp3' # duplicate
original_cmd '/mnt/wslg/distro/var/lib/docker/overlay2/c95f9cd902c37ef7e6d5de68ac18aafba154e456a6207b8800ed18b1f4d171db/diff/home/בואי by Cookie Levanna.mp3.mp3' # original
remove_cmd '/mnt/wslg/distro/var/lib/docker/overlay2/c95f9cd902c37ef7e6d5de68ac18aafba154e456a6207b8800ed18b1f4d171db/diff/home/בואי לרקוד by Cookie Levanna.mp3.mp3' '/mnt/wslg/distro/var/lib/docker/overlay2/c95f9cd902c37ef7e6d5de68ac18aafba154e456a6207b8800ed18b1f4d171db/diff/home/בואי by Cookie Levanna.mp3.mp3' # duplicate
original_cmd '/mnt/wslg/distro/usr/lib/git-core/git' # original
remove_cmd '/mnt/wslg/distro/usr/bin/git' '/mnt/wslg/distro/usr/lib/git-core/git' # duplicate
                                               
                                               
                                               
######### END OF AUTOGENERATED OUTPUT #########
                                               
if [ $PROGRESS_CURR -le $PROGRESS_TOTAL ]; then
    print_progress_prefix                      
    echo "${COL_BLUE}Done!${COL_RESET}"      
fi                                             
                                               
if [ -z $DO_REMOVE ] && [ -z $DO_DRY_RUN ]     
then                                           
  echo "Deleting script " "$0"             
  rm -f '/mnt/f/study/security/encryption/borgmatic/rmlint.sh';                                     
fi                                             
