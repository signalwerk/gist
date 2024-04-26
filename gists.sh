#!/bin/bash

# Define the directory where gists will be stored
gist_dir="./data"

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
  
  # Define the submodule path
  submodule_path="$gist_dir/$id"
  
  # Check if the submodule already exists
  if git config --file .gitmodules --get-regexp "path" | grep -q "$id"; then
    default_branch=$(git -C "$submodule_path" remote show origin | grep 'HEAD branch' | cut -d' ' -f5)
    # Submodule exists, update it
    echo "Updating gist submodule: $description ($privacy_status)"
    git -C "$submodule_path" pull origin "$default_branch"
  else
    # Submodule does not exist, add it
    echo "Adding new gist submodule: $description ($privacy_status)"
    git submodule add "git@gist.github.com:$id.git" "$submodule_path"
    git submodule update --init --recursive
  fi
done <<< "$gists"

# Check and remove any submodules for gists that no longer exist
for submodule in $(git config --file .gitmodules --get-regexp "path" | awk '{ print $2 }'); do
  if [[ ! " ${active_gists[@]} " =~ " ${submodule##*/} " ]]; then
    echo "Removing deleted gist submodule: ${submodule##*/}"
    git submodule deinit -f "$submodule"
    git rm -f "$submodule"
    rm -rf ".git/modules/$submodule"
  fi
done

# Add all changes including submodules
git add .
git commit -m "Updated gists submodules and README"
git push

echo "All gists have been processed and the main repository is updated."
