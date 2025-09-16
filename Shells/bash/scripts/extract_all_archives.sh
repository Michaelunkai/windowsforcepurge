#!/bin/bash

PASSWORD="123"

find . -type f \( -name "*.zip" -o -name "*.tar" -o -name "*.tar.gz" -o -name "*.tgz" -o -name "*.rar" -o -name "*.7z" \) -exec sh -c '
for file; do
    echo "Processing: $file"
    
    # Get the base name without extension for folder creation
    case "$file" in
        *.tar.gz)
            folder_name="${file%.tar.gz}"
            ;;
        *.tgz)
            folder_name="${file%.tgz}"
            ;;
        *)
            folder_name="${file%.*}"
            ;;
    esac
    
    # Create the extraction folder
    mkdir -p "$folder_name"
    
    case "$file" in
        *.zip)
            echo "Extracting ZIP: $file -> $folder_name/"
            # Try without password first, then with password
            unzip "$file" -d "$folder_name" -o >/dev/null 2>&1 || \
            unzip -P "$PASSWORD" "$file" -d "$folder_name" -o >/dev/null 2>&1 || \
            7z x "$file" -o"$folder_name" -y >/dev/null 2>&1 || \
            7z x -p"$PASSWORD" "$file" -o"$folder_name" -y >/dev/null 2>&1 || \
            echo "Failed to extract: $file"
            ;;
        *.tar)
            echo "Extracting TAR: $file -> $folder_name/"
            tar -xf "$file" -C "$folder_name" || echo "Failed to extract: $file"
            ;;
        *.tar.gz|*.tgz)
            echo "Extracting TAR.GZ: $file -> $folder_name/"
            tar -xzf "$file" -C "$folder_name" || echo "Failed to extract: $file"
            ;;
        *.rar)
            echo "Extracting RAR: $file -> $folder_name/"
            # Try without password first, then with password
            unrar x "$file" "$folder_name/" -o+ >/dev/null 2>&1 || \
            unrar x -p"$PASSWORD" "$file" "$folder_name/" -o+ >/dev/null 2>&1 || \
            echo "Failed to extract: $file"
            ;;
        *.7z)
            echo "Extracting 7Z: $file -> $folder_name/"
            # Try without password first, then with password
            7z x "$file" -o"$folder_name" -y >/dev/null 2>&1 || \
            7z x -p"$PASSWORD" "$file" -o"$folder_name" -y >/dev/null 2>&1 || \
            echo "Failed to extract: $file"
            ;;
        *)
            echo "Unsupported file type: $file"
            ;;
    esac
    
    # Check if extraction was successful
    if [ -d "$folder_name" ] && [ "$(ls -A "$folder_name" 2>/dev/null)" ]; then
        echo "Successfully extracted: $file"
    else
        echo "Warning: Extraction may have failed or folder is empty: $file"
        # Remove empty folder if extraction failed
        rmdir "$folder_name" 2>/dev/null
    fi
    
    echo "---"
done' sh {} +

echo "Archive extraction complete!"
