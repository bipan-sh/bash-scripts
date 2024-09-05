#!/bin/bash

# Check if the word to search is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <word_to_search>"
  exit 1
fi

# Word to search
SEARCH_WORD=$1

# Get all branches (local and remote) excluding detached HEAD or symbolic references
branches=$(git branch -r | grep -v '\->')

# Loop through each branch and search for the word
for branch in $branches; do
  # Remove 'origin/' from remote branches if present
  clean_branch=$(echo $branch | sed 's/origin\///')
  
  # Checkout the branch
  git checkout $clean_branch -q >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Failed to checkout branch: $clean_branch"
    continue
  fi

  echo "Searching in branch: $clean_branch"

  # Search for the word in the branch
  grep -r "$SEARCH_WORD" . 2>/dev/null

  echo "-----------------------------------"
done

# Optionally, return to the original branch
git checkout -q - >/dev/null 2>&1