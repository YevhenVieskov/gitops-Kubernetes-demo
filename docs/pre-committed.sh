#!/bin/bash

# directories containing potential secrets
DIRS="env/bel1/c1/helm_vars env/bel1/c2/helm_vars env/dev/helm_vars"

bold=$(tput bold)
normal=$(tput sgr0)

# allow to read user input, assigns stdin to keyboard
exec < /dev/tty

for d in $DIRS; do
    # find files containing secrets that should be encrypted
    for f in $(find "${d}" -type f -regex ".*secrets.yaml"); do
        if ! $(grep -q "^sops:" $f); then
            printf '\xF0\x9F\x92\xA5 '
            echo "File $f has non encrypted secrets!"
            HAS_NON_ENCRYPTED=1
        fi
    done
done

# still allow to commit with confirmation is non encrypted secrets were found
if [ ! -z $HAS_NON_ENCRYPTED ]; then
    echo
    printf '\xF0\x9F\xA4\x94 '
    read -p "${bold}Do you still want to commit?${normal} (y|Y to commit) " -n 1 -r REPLY
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "aborted"
        exit 1
    fi
fi