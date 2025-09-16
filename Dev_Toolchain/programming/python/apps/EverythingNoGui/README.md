# Everything CLI

Terminal-based file search utility similar to Windows "Everything" app. Provides blazing-fast file and folder search capabilities directly from your command line.

## Features

- **Lightning Fast Search**: Instant search results using SQLite indexing
- **Cross-Platform**: Works on Windows, macOS, and Linux
- **Interactive Mode**: Real-time search as you type
- **Advanced Filtering**: Filter by file type, size, date, and more
- **Colorized Output**: Easy-to-read colored terminal output
- **Comprehensive CLI**: Full command-line interface with many options

## Installation

1. Ensure you have Python 3.6+ installed
2. Download or clone the `everything_cli.py` file
3. Make it executable (Unix/Linux/macOS):
   ```bash
   chmod +x everything_cli.py
   ```

## Quick Start

**Just run the script for Everything app experience:**
```bash
python everything_cli.py
```
This automatically shows all files ranked by size (largest first), just like Windows Everything app!

**Other options:**
1. **Interactive search mode** (recommended):
   ```bash
   python everything_cli.py --interactive
   ```

2. **Search for specific files**:
   ```bash
   python everything_cli.py --search "filename"
   ```

3. **Manual indexing** (optional - happens automatically):
   ```bash
   python everything_cli.py --index-c-drive
   ```

## Usage Examples

### Basic Operations

```bash
# DEFAULT: Show all files by size (Everything app style)
python everything_cli.py

# Interactive search mode (best experience)
python everything_cli.py --interactive

# Search for files containing "config"
python everything_cli.py --search "config"

# Index additional directories (C drive indexed automatically)
python everything_cli.py --index /path/to/directory
```

### Advanced Filtering

```bash
# Search for Python files only
python everything_cli.py --search "script" --ext .py

# Find large files (over 100MB)
python everything_cli.py --search "*" --min-size 100MB

# Find files modified in the last week
python everything_cli.py --search "*" --modified-after 1w

# Show only directories
python everything_cli.py --search "project" --dirs-only

# Show detailed information
python everything_cli.py --search "important" --details

# Limit results to 50 items
python everything_cli.py --search "*" --limit 50
```

### Size Filters
Supported size formats: `B`, `KB`, `MB`, `GB`, `TB`
```bash
--min-size 1MB      # Minimum 1 megabyte
--max-size 500KB    # Maximum 500 kilobytes
--min-size 2GB      # Minimum 2 gigabytes
```

### Time Filters
Supported time formats: `d` (days), `w` (weeks), `m` (months), `y` (years)
```bash
--modified-after 7d     # Modified in last 7 days
--modified-before 2w    # Modified before 2 weeks ago
--modified-after 1m     # Modified in last month
```

## Interactive Mode

The interactive mode provides the best user experience:

```bash
python everything_cli.py --interactive
```

In interactive mode, you can:
- Type search queries directly
- Use special commands starting with `:`
- Get instant results as you search

### Interactive Commands

- `:stats` - Show database statistics
- `:clear` - Clear the database
- `:index <path>` - Index a new directory
- `:help` - Show help
- `quit`, `exit`, or `q` - Exit the program

### Interactive Mode Example
```
Everything CLI - Interactive Search Mode
Type your search query (or 'quit' to exit):
Commands: :stats, :clear, :index <path>, :help

Search> config
📄 config.json - /home/user/projects/myapp/config.json
📄 config.py - /home/user/scripts/config.py
📁 config - /home/user/.config

Search> :stats
Database Statistics:
Files: 45,231
Directories: 8,942
Total entries: 54,173
Total size: 12.4 GB

Search> *.py --ext .py
📄 main.py - /home/user/projects/app/main.py
📄 utils.py - /home/user/projects/app/utils.py
...

Search> quit
```

## Command Line Options

| Option | Short | Description |
|--------|-------|-------------|
| `--index PATH` | `-i` | Index files in the specified directory |
| `--search QUERY` | `-s` | Search for files matching the query |
| `--interactive` | `-I` | Start interactive search mode |
| `--ext EXTENSION` | | Filter by file extension (e.g., .txt, .py) |
| `--min-size SIZE` | | Minimum file size (e.g., 1MB, 500KB) |
| `--max-size SIZE` | | Maximum file size (e.g., 1GB, 100MB) |
| `--dirs-only` | | Show only directories |
| `--files-only` | | Show only files |
| `--modified-after TIME` | | Modified after (e.g., 1d, 2w, 3m) |
| `--modified-before TIME` | | Modified before (e.g., 1d, 2w, 3m) |
| `--limit NUMBER` | `-l` | Maximum number of results (default: 100) |
| `--details` | `-d` | Show detailed information |
| `--stats` | | Show database statistics |
| `--clear` | | Clear the database |

## Search Patterns

- **Wildcard matching**: Use `*` and `?` in search queries
- **Partial matching**: Search queries match anywhere in the filename
- **Case insensitive**: All searches are case insensitive
- **Extension filtering**: Use `--ext` for specific file types

## Database

- Uses SQLite for fast indexing and searching
- Database file: `everything_cli.db` (created automatically)
- Includes file metadata: size, modification time, path, etc.
- Supports incremental updates

## Performance

- **Indexing**: ~10,000-50,000 files per second (depending on storage)
- **Searching**: Sub-millisecond search times after indexing
- **Memory**: Low memory footprint using SQLite
- **Storage**: Minimal database size (typically <1% of indexed data)

## Tips & Tricks

1. **Index frequently**: Re-index directories when files change significantly
2. **Use specific queries**: More specific searches return faster results
3. **Interactive mode**: Best for exploratory searching
4. **Combine filters**: Use multiple filters for precise results
5. **Regular indexing**: Set up periodic indexing for active directories

## Troubleshooting

### Permission Errors
```bash
# Some directories may require elevated permissions
sudo python everything_cli.py --index /system/directory
```

### Large Directories
```bash
# For very large directories, indexing may take time
# Use Ctrl+C to interrupt if needed
python everything_cli.py --index /large/directory
```

### Database Issues
```bash
# Clear and rebuild database if corrupted
python everything_cli.py --clear
python everything_cli.py --index /path/to/directory
```

## Comparison with Windows "Everything"

| Feature | Everything CLI | Windows Everything |
|---------|---------------|-------------------|
| Platform | Cross-platform | Windows only |
| Interface | Terminal/CLI | GUI |
| Search Speed | Very Fast | Very Fast |
| Indexing | Manual/Scripted | Real-time |
| Filtering | Advanced CLI options | GUI filters |
| Scripting | Perfect for scripts | Limited |
| Resource Usage | Very Low | Low |

## License

This project is released under the MIT License. Feel free to use, modify, and distribute.

## Contributing

Contributions are welcome! Areas for improvement:
- Real-time file system monitoring
- Configuration file support
- Additional search operators
- Export functionality
- Integration with other tools