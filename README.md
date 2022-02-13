# git-moonwalk #

A simple tool for moonwalking through commits. 

### Use case ###

I noticed during PR reviews I would either have to squash, add a new commit or do some soft reset magic to ammend the target commit. This got clunky and I wanted a way to access a certain commit, ammend some changes and re-apply my previous commits. This tool moon walks through a specified number of commits preserving them. When you have made the desired changes to the desired commit you can then restore the stashed commits.
