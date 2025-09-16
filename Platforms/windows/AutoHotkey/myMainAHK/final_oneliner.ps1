$REPO_NAME = (Split-Path -Leaf $PWD).Replace(' ', ''); try { if (Get-Command rmgit -ErrorAction SilentlyContinue) { rmgit } } catch {}; git config --global --add safe.directory $PWD; git init; "Last updated: $(Get-Date)" | Out-File -FilePath .last_update -Encoding UTF8; @"
*.json
*.pickle
*credentials*
*secret*
*token*
*.key
*.pem
*.p12
*.pfx
.env
.env.*
"@ | Out-File -FilePath .gitignore -Encoding UTF8; Get-ChildItem -Recurse -Filter "*.py" | ForEach-Object { $content = Get-Content $_.FullName -Raw; if ($content) { $content = $content -replace '(client_id\s*=\s*["\047])[^"]*(["\047])', '$1YOUR_CLIENT_ID_HERE$2' -replace '(client_secret\s*=\s*["\047])[^"]*(["\047])', '$1YOUR_CLIENT_SECRET_HERE$2' -replace '(api_key\s*=\s*["\047])[^"]*(["\047])', '$1YOUR_API_KEY_HERE$2' -replace '([0-9]{12}-[a-zA-Z0-9_]{32}\.apps\.googleusercontent\.com)', 'YOUR_CLIENT_ID_HERE' -replace '([A-Za-z0-9_-]{24})', 'YOUR_CLIENT_SECRET_HERE'; $content | Set-Content $_.FullName -NoNewline } }; $filesToRemove = @("apps/youtube/Playlists/deleteVideosFromOldestPublished/client_secret.json", "apps/youtube/Playlists/Add2playlist/*/client_secret.json", "apps/youtube/Playlists/Add2playlist/*/token.pickle", "apps/youtube_credentials.json"); foreach ($file in $filesToRemove) { try { Remove-Item -Path $file -Force -ErrorAction SilentlyContinue } catch {} }; git add -A; git commit -m "auto update $(Get-Date)"; try { git remote remove origin 2>$null } catch {}; git remote add origin "https://github.com/Michaelunkai/$REPO_NAME.git"; git branch -M main; try { git push -u origin main; Write-Output "Successfully pushed to GitHub!" } catch { $ghStatus = gh auth status 2>$null; if ($LASTEXITCODE -eq 0) { try { gh repo delete "Michaelunkai/$REPO_NAME" --yes 2>$null } catch {}; gh repo create $REPO_NAME --public --source=. --remote=origin --push; Write-Output "Created and pushed repository using GitHub CLI!" } else { git push -u origin main --force --no-verify; Write-Output "Force pushed to repository!" } }; try { if (Get-Command rmgit -ErrorAction SilentlyContinue) { rmgit } } catch {}; Write-Output "Repository name used: $REPO_NAME"