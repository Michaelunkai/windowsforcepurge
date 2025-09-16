#!/bin/bash

gitit() {
    # Initialize git repo if not already in one
    (git rev-parse --is-inside-work-tree >/dev/null 2>&1 || git init -b main)
    
    # Check commit count
    commit_count=$(git rev-list --count HEAD 2>/dev/null || echo "0")
    
    # Make initial commit if no commits exist
    if [ "$commit_count" -eq 0 ]; then
        git add -A && git commit --allow-empty -m "Initial commit"
    else
        # Add and commit any changes
        git add -A
        if ! git diff-index --quiet HEAD --; then
            git commit -m "Auto commit: $(date)"
        fi
    fi
    
    # Try to create GitHub repo
    if ! gh repo create --source=. --public --remote=origin --push -y 2>/dev/null; then
        echo "Repository might already exist, setting up remote..."
        
        # Add remote if it doesn't exist
        if ! git remote get-url origin >/dev/null 2>&1; then
            git remote add origin "https://github.com/$(gh api user --jq .login)/$(basename $(pwd)).git"
        fi
        
        # Try to push, handle conflicts gracefully
        if ! git push -u origin main 2>/dev/null; then
            echo "Push failed, attempting to resolve conflicts..."
            
            # Fetch remote changes
            git fetch origin main 2>/dev/null || {
                echo "Could not fetch from remote. Repository might not exist or have different structure."
                return 1
            }
            
            # Check if we can fast-forward
            if git merge-base --is-ancestor HEAD origin/main 2>/dev/null; then
                # Local is behind, can safely pull
                echo "Local repository is behind remote. Pulling changes..."
                git pull origin main --no-edit
                git push origin main
            elif git merge-base --is-ancestor origin/main HEAD 2>/dev/null; then
                # Remote is behind, force push
                echo "Remote repository is behind local. Force pushing..."
                git push --force-with-lease origin main
            else
                # Divergent histories - need to merge or rebase
                echo "Repositories have divergent histories. Attempting merge..."
                if git pull origin main --no-edit --allow-unrelated-histories; then
                    git push origin main
                else
                    echo "Merge failed. You may need to resolve conflicts manually."
                    echo "Run: git status, resolve conflicts, then git commit and git push"
                    return 1
                fi
            fi
        fi
    fi
    
    # Optional: Clean up git directories (commented out by default for safety)
    # rmgit
    
    # Open GitHub repositories page
    github
}

# Set up the alias
alias gitit='gitit'
