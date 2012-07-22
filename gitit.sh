#!/usr/bin/env bash

set -e

usage() {
cat <<EOF
  usage: $0 opts

  This script updates all the git repos to keep my machines synced up.

  By default, it runs 'git pull' in each repository in addition
  to any extra commands you give it. 

  Note that "-S" overrides the update so you ONLY get the status.

  OPTIONS:
    -h    Show this message
    -p    Push in addition to pulling
    -s    Check the status of each repository
    -S    Check ONLY the status -- don't do anything else! 
    -b    Base path that git repos are located (default: $basepath)
EOF
}

basepath="$HOME/local"
push=false
stat=false
onlyStat=false

while getopts "b:psSh" opt; do
	case $opt in
    b) basepath=$OPTARG ;;
    p) push=true ;;
    s) stat=true ;;
    S) onlyStat=true ; stat=true ;;
    h) usage; exit 0 ;;
    \?) echo "incorrect usage"; usage; echo; exit 0;;
	esac
done

gitit(){
    cd $1
    printf '\033[1m\033[34m>>> \033[1m\033[37m%s\033[0m\n' $1

    if ! $onlyStat ; then
        printf '\033[1m\033[34m... \033[1m\033[37mUpdating\033[0m\n'
        git pull
    fi

    if $stat ; then
        printf '\033[1m\033[34m... \033[1m\033[37mGetting Status\033[0m\n'
        git st
    fi

    if $push && ! $onlyStat ; then
        printf '\033[1m\033[34m... \033[1m\033[37mPushing Changes\033[0m\n'
        git push
    fi

    echo
    cd ..
}

cd $basepath

gitit class-code
gitit config
gitit pyutils
gitit research
gitit scripts
gitit side-projects
gitit website

