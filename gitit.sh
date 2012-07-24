#!/usr/bin/env bash

#set -e
set -u

usage() {
cat <<EOF
  usage: $0 opts

  This script updates all the git repos to keep my machines synced up.

  In the absence of any flags, it runs 'git pull' in each repository. 
  If other flags are given, you must explicitly provide the '-u' option.

  Note that '-C' includes '-c' (though they are not mutually exclusive)

  OPTIONS:
    -h    Show this message
    -a    Shortcut for -Cups

    -u    Pull from all repos (this is the default action in absense of any flags)
    -p    Push in addition to pulling

    -s    Check the status of each repository

    -c    Commit STAGED changes (for EVERY repo)
    -C    Commit (selectively) ALL changes using 'git add -p', then commit (for EVERY repo)

    -x    Pause after acting on each repo (press Enter to contnue, or ^C to stop)
EOF
}

push=false
stat=false
commit=false
add=false
pause=false
pull=false

while getopts "b:aupscChx" opt; do
	case $opt in
    a) pull=true ; push=true ; stat=true ; add=true ; commit=true ;;
    u) pull=true ;;
    p) push=true ;;
    s) stat=true ;;
    c) commit=true ;;
    C) add=true ; commit=true ;;
    x) pause=true ;;
    h) usage; exit 0 ;;
    \?) echo "incorrect usage"; usage; echo; exit 1;;
	esac
done

# if any command flags were given, then we 
# don't want to just *assume* that we're updating 
if  ! ($push || $stat || $commit) ; then
    pull=true
fi

progress(){
    printf '\033[1m\033[34m... \033[1m\033[37m%s\033[0m\n' "$1"
}

gitit(){
    cd $1 || exit 1

    printf '\033[1m\033[34m>>> \033[1m\033[37m%s\033[0m\n' "$1"

    if $pull ; then
        progress "Updating"
        git pull
    fi

    if $stat ; then
        progress "Getting Status"
        git status
    fi

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

    echo
    if $pause ; then read foobar; fi
}

basepath=$HOME/local

gitit $basepath/class-code
gitit $basepath/config
gitit $basepath/pyutils
gitit $basepath/research
gitit $basepath/scripts
gitit $basepath/side-projects
gitit $basepath/website

