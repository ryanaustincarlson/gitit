#!/usr/bin/env bash

#set -e
set -u

default_config=$HOME/.gititrc

usage() {
cat <<EOF
  usage: $0 opts

  This script updates all git repos specified in a configuration file 
  (default: $default_config).

  In the absence of any flags, it runs 'git pull' and 'git status' in each
  repository.  If other flags are given, you must explicitly provide the '-u'
  or '-s' options.

  By default, the script checks if the operations you've requested actually
  need to be done (by checking git status). For example, if there's nothing to
  be pushed in repoA but something in repoB, the '-p' option will be ignored
  in repoA but will be used in repoB. To turn off this behavior, use the '-j'
  option. To do every operation, use '-ja'.

  Note that '-C' includes '-c' (though they are not mutually exclusive).

  OPTIONS:
    -h    Show this message
    -a    Shortcut for -Cups
    -j    Don't check if an operation *needs* to happen, just do it.

    -u    Pull from all repositories
    -p    Push to all repositories

    -s    Check the status of each repository

    -c    Commit STAGED changes (for EVERY repo)
    -C    Commit (selectively) ALL changes using 'git add -p', then commit (for EVERY repo)

    -g [path]
          Specify a configuration file location
EOF
}

push=false
stat=false
commit=false
add=false
pull=false
justdoit=false
config=$default_config

while getopts "g:aupscChj" opt; do
    case $opt in
        a) pull=true ; push=true ; stat=true ; add=true ; commit=true ;;
        u) pull=true ;;
        p) push=true ;;
        s) stat=true ;;
        c) commit=true ;;
        C) add=true ; commit=true ;;
        j) justdoit=true ;;
        g) config=$OPTARG ;;
        h) usage; exit 0 ;;
        \?) echo "incorrect usage"; usage; echo; exit 1;;
	esac
done

# get full path
if [[ $config != $default_config ]]; then

    if [ -z $config ]; then
        echo -e "Config file must be non-empty!\nRun \`$0 -h\` for more details. Exiting." 
        exit 1
    fi

    failed=false
    new_config=`readlink -f $config 2>/dev/null` || failed=true

    # os x readlink is a little weird, so let's see if they've installed greadlink (gnu version)
    if $failed; then
        failed=false
        new_config=`greadlink -f $config 2>/dev/null` || failed=true
    fi

    # if we're still failing, revert to perl
    if $failed; then
        new_config=`perl -e 'use Cwd "abs_path"; print abs_path(shift)' $config 2>/dev/null`
    fi

    if [ ! -z $new_config ]; then
        config=$new_config
    fi
fi

# we've done our best to find the full path. Let's see if you gave us a real path. 
if [[ ! -f $config ]]; then
    echo -e "Can't find config file at $config\nRun \`$0 -h\` for more details. Exiting."
    exit 1
fi

# defines the default behavior
#
# if any command flags were given, then we 
# don't want to just *assume* that we're updating 
if  ! ($push || $stat || $commit || $pull) ; then
    pull=true
    stat=true
fi

# helper functions to pretty-print some text
header(){
    printf '\033[1m\033[34m>>> \033[1m\033[37m%s\033[0m\n' "$1"
}

progress(){
    printf '\033[1m\033[34m... \033[1m\033[37m%s\033[0m\n' "$1"
    something_happened=true # if we're printing some progress, then at least one operation fired 
}

# helper functions to decide whether or not certain 
# git operations (status, push, add, commit) need to be run
should_i_stat(){
    mystatus="$1"
    # also show status if everything's been committed but hasn't yet been pushed
    if `should_i_push "$mystatus"` ; then
        echo true
    elif [[ `echo $mystatus | egrep -ic "nothing to commit.*working directory clean.*"` == 0 ]]; then
        echo true
    else
        echo false
    fi
}

should_i_push(){
    mystatus="$1"
    if [[ `echo $mystatus | egrep -ic "your branch is .* by .* commit"` != 0 ]]; then 
        echo true
    else 
        echo false
    fi
}

should_i_add(){
    mystatus="$1"
    if [[ `echo $mystatus | grep -ic "changes not staged for commit"` != 0 ]]; then
        echo true
    else 
        echo false
    fi
}

should_i_commit(){
    mystatus="$1"
    if [[ `echo $mystatus | grep -ic "changes to be committed"` != 0 ]]; then
        echo true
    else
        echo false
    fi
}

# main function that actually operates on a specified git repository
gitit(){
    repo=$1
    cd $repo || exit 1

    # determine which operations we're actually going to do / show to the user
    if $justdoit ; then
        should_stat=true
        should_push=true
        should_add=true
        should_commit=true
    else
        mystatus=`git status`
        should_stat=`should_i_stat "$mystatus"`
        should_push=`should_i_push "$mystatus"`
        should_add=`should_i_add "$mystatus"`
        should_commit=`should_i_commit "$mystatus"`
    fi

    # if we don't need to do anything, then jump out of the function here!
    if ! ( ($stat && $should_stat) \
        || ($push && $should_push) \
        || ($add && $should_add) \
        || ($commit && $should_commit) \
        || $pull) ; then
        return
    fi

    header "$repo" # pretty-print the repo's name

    if $pull ; then
        progress "Updating"
        git pull
    fi

    if $stat && $should_stat ; then
        progress "Getting Status"
        git status
    fi

    if $add && $should_add ; then
        progress "Interactive Add"
        git add -p 

        # need to get status again, because add could have changed the state of things
        if ! $justdoit ; then
            mystatus=`git status`
            should_commit=`should_i_commit "$mystatus"`
        fi
    fi

    if $commit && $should_commit ; then
        progress "Committing Staged Changes"
        git commit

        # need to get status again, because commit could have changed the state of things
        if ! $justdoit ; then
            mystatus=`git status`
            should_push=`should_i_push "$mystatus"`
        fi
    fi

    if $push && $should_push ; then
        progress "Pushing Changes"
        git push
    fi

    echo
}

something_happened=false # this can be changed in the progress() function

# there should be either comments or exactly two space-separated items in each
# line. Check for that before doing anything else
count=1
while read line; do
    if [[ $line = \#* ]]; then
        continue
    fi

    first=`echo $line | awk '{print $1}'`
    second=`echo $line | awk '{print $2}'`
    third=`echo $line | awk '{print $3}'`

    if [[ -z $first || -z $second || ! -z $third ]]; then
        echo "Looks like your config file ($config) is malformed at line $count. Exiting."
        exit 1
    fi

    count=$((count+1))
done < $config

# clone repos as necessary
count=0
while read line; do 
    if [[ $line = \#* ]]; then
        continue
    fi

    directory=`echo $line | awk '{print $1}' | sed "s:~:$HOME:"`

    # if directory doesn't exist, make it
    mkdir -p $directory 

    # if .git doesn't exist, check out the repo
    if [ ! -d "$directory/.git" ]; then
        repo=`echo $line | awk '{print $2}'`
        header "Cloning $repo"
        git clone $repo $directory
    fi

    DIRECTORIES[$count]=$directory
    count=$((count+1))
done < $config

# for some reason, interactive add (-C) gets into an infinite loop 
# when it's inside the `while read line` block, so I moved it here
for directory in "${DIRECTORIES[@]}"; do
    gitit $directory
done

# we want to have at least some output, so if nothing happens
# then print this friendly message
if ! $something_happened ; then
    header "All good! Nothing to do!"
fi

