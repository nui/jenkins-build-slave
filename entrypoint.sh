#!/bin/zsh
# fix jenkins permissions
pushd ~jenkins
for i in cache; do
    if [[ -d $i ]]; then
        chown jenkins:jenkins $i
    fi
done
popd

exec gosu jenkins jenkins-slave "$@"
