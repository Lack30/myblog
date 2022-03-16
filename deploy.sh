#!/bin/sh

# If a command fails then the deploy stops
set -e

printf "\033[0;32mDeploying updates to GitHub...\033[0m\n"

# Build the project.
hugo -t LoveIt

# upload algolia file
atomic-algolia

# Go To Public folder
cd public

# pull code from github
git pull 

# Add changes to git.
git add .

# Commit changes.
msg="rebuilding site $(date)"
if [ -n "$*" ]; then
	msg="$*"
fi
git commit -m "$msg"

# Push source and build repos.
git push -u origin main

cd ..

git pull
git add .
git commit -m "$msg"
git push -u origin gh-pages