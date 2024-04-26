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

# Process each gist
while IFS=$'\t' read -r id description is_public; do
  # Convert public status to human-readable form
  privacy_status=$(if [[ "$is_public" == "true" ]]; then echo "Public"; else echo "Private"; fi)

  echo "| [$id](https://gist.github.com/$id) | $privacy_status | $description |" >> "./README.md"
  
  # Define the submodule path
  submodule_path="$gist_dir/$id"
  
  # Check if the submodule already exists
  if git config --file .gitmodules --get-regexp "path" | grep -q "$id"; then
    # Submodule exists, update it
    echo "Updating gist submodule: $description ($privacy_status)"
    git -C "$submodule_path" pull origin main
  else
    # Submodule does not exist, add it
    echo "Adding new gist submodule: $description ($privacy_status)"
    git submodule add "git@gist.github.com:$id.git" "$submodule_path"
    git submodule update --init --recursive
  fi
done <<< "$gists"

# Add all changes including submodules
git add .
git commit -m "Updated gists submodules and README"
git push

echo "All gists have been processed and the main repository is updated."
