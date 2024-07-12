#!/bin/bash

# A script to manage GitHub Gist submodules and update the README file

# Usage:
#   bash backup.sh              # Updates all submodules and the README
#   bash backup.sh readme-only  # Only updates the README without fetching the latest version of the submodules

# Description:
# This script automates the process of managing GitHub Gist submodules in this repository.

# It performs the following tasks:
# - Fetches the list of gists from GitHub, including their privacy status.
# - Updates the README file with an overview of the gists.
# - Adds new gists as submodules and pulls updates for existing submodules.
# - Commits and pushes changes to the main repository.
# - Removes submodules for gists that no longer exist.

# abort on error
set -e

# Define the directory where gists will be stored
gist_dir="./data"

# Function to fetch and process gists
fetch_gists() {
  # Fetch the list of gists, including their privacy status
  gists=$(gh api gists | jq -r '.[] | [.id, .description, .public] | @tsv')

  echo "Found the following gists:"
  echo "$gists"

  # Prepare the README file
  echo "Gists Overview" > "./README.md"
  echo "=============" >> "./README.md"
  echo "" >> "./README.md"
  echo "This repository contains the following gists:" >> "./README.md"
  echo "" >> "./README.md"
  echo "| ID | Privacy | Description |" >> "./README.md"
  echo "| --- | --- | --- |" >> "./README.md"

  # Maintain a list of active gist IDs
  active_gists=()

  # Process each gist
  while IFS=$'\t' read -r id description is_public; do
    active_gists+=("$id")
    privacy_status=$(if [[ "$is_public" == "true" ]]; then echo "Public"; else echo "Private"; fi)

    echo "| [$id](https://gist.github.com/$id) | $privacy_status | $description |" >> "./README.md"
  done <<< "$gists"
}

# Function to update submodules
update_submodules() {
  # Process each gist
  while IFS=$'\t' read -r id description is_public; do
    # Define the submodule path
    submodule_path="$gist_dir/$id"

    # Check if the submodule already exists
    if git config --file .gitmodules --get-regexp "path" | grep -q "$id"; then
      default_branch=$(git -C "$submodule_path" remote show origin | grep 'HEAD branch' | cut -d' ' -f5)

      # Check for uncommitted changes
      if [[ -n $(git -C "$submodule_path" status --porcelain) ]]; then
        echo "Committing changes in $description ($privacy_status)"
        git -C "$submodule_path" add .
        git -C "$submodule_path" commit -m "Auto-commit changes"
      fi

      # Submodule exists, pull updates
      echo "Updating gist submodule: $description ($privacy_status)"
      git -C "$submodule_path" pull origin "$default_branch"
    else
      # Submodule does not exist, add it
      echo "Adding new gist submodule: $description ($privacy_status)"
      git submodule add "git@gist.github.com:$id.git" "$submodule_path"
      git submodule update --init --recursive
    fi
  done <<< "$gists"

  # Ensure all submodules are initialized and updated
  git submodule update --init --recursive

  # Check and remove any submodules for gists that no longer exist
  for submodule in $(git config --file .gitmodules --get-regexp "path" | awk '{ print $2 }'); do
    if [[ ! " ${active_gists[@]} " =~ " ${submodule##*/} " ]]; then
      echo "Removing deleted gist submodule: ${submodule##*/}"
      git submodule deinit -f "$submodule"
      git rm -f "$submodule"
      rm -rf ".git/modules/$submodule"
    fi
  done
}

# Main logic
if [[ "$1" == "readme-only" ]]; then
  fetch_gists
  echo "All gists have been processed and the README has been updated."
else
  fetch_gists
  update_submodules
  echo "All gists have been processed and the README and submodules have been updated."
fi

# Add all changes including submodules
# git add .
# git commit -m "Updated gists submodules and README"
# git push

