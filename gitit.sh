#!/usr/bin/env bash

#set -e
set -u

usage() {
cat <<EOF
  usage: $0 opts

  This script updates all the git repos to keep my machines synced up.

  By default, it runs 'git pull' in each repository in addition
  to any extra commands you give it. 

  Note that 
    "-S" overrides the update so you ONLY get the status.
    '-C' includes '-c' (though they are not mutually exclusive)

  OPTIONS:
    -h    Show this message
    -p    Push in addition to pulling

    -s    Check the status of each repository
    -S    Check ONLY the status -- don't do anything else! 

    -c    Commit STAGED changes (for EVERY repo)
    -C    Commit (selectively) ALL changes using 'git add -p', then commit (for EVERY repo)

    -b    Base path that git repos are located (default: $basepath)
    -a    Pause after acting on each repo (press Enter to contnue, or ^C to stop)
EOF
}

basepath="$HOME/local"
push=false
stat=false
onlyStat=false
commit=false
add=false
pause=false

while getopts "b:psScCha" opt; do
	case $opt in
    b) basepath=$OPTARG ;;
    p) push=true ;;
    s) stat=true ;;
    S) onlyStat=true ; stat=true ;;
    c) commit=true ;;
    C) add=true ; commit=true ;;
    a) pause=true ;;
    h) usage; exit 0 ;;
    \?) echo "incorrect usage"; usage; echo; exit 1;;
	esac
done

# make sure basepath is an absolute path
basepath="`$HOME/local/scripts/abs_path.sh $basepath`"

# before returning from gitit(), make sure you print
# out a blank line and offer the user a brief pause
beforeyougotit(){
    echo
    if $pause ; then
        read foobar
    fi
}

progress(){
    printf '\033[1m\033[34m... \033[1m\033[37m%s\033[0m\n' "$1"
}

gitit(){
    cd $basepath
    cd $1

    printf '\033[1m\033[34m>>> \033[1m\033[37m%s\033[0m\n' "$1"

    if ! $onlyStat ; then
        progress "Updating"
        git pull
    fi

    if $stat ; then
        progress "Getting Status"
        git status
    fi

    ## we're done here 
    if $onlyStat ; then beforeyougotit; return; fi

    if $add ; then
        progress "Interactive Add"
        git add -p
    fi

    if $commit ; then
        progress "Committing Staged Changes"
        git commit
    fi

    if $push ; then
        progress "Pushing Changes"
        git push
    fi

    beforeyougotit
}

gitit class-code
gitit config
gitit pyutils
gitit research
gitit scripts
gitit side-projects
gitit website

