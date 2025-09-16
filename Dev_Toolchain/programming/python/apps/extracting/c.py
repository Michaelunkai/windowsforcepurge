#!/usr/bin/env python3
"""
Auto-extractor for archives that land in F:\Downloads.

• Watches the folder for .zip and .rar files.
• Extracts each archive into a sub-folder named after the archive.
• Tries the default password “123” if the archive is protected.
• Deletes the archive after successful extraction.
• Shuts down automatically after 10 s of inactivity.

Required pip packages:
    pip install watchdog rarfile
You also need the “unrar” utility in your PATH (for RAR support).
"""
import os
import time
import zipfile
import rarfile
import logging
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

# YOUR_CLIENT_SECRET_HERE_CLIENT_SECRET_HEREE—
# Configuration
# YOUR_CLIENT_SECRET_HERE_CLIENT_SECRET_HEREE—
DOWNLOADS_DIR = r'F:\Downloads'          # <--- hard-coded destination
DEFAULT_PASSWORD = '123'
SUPPORTED_EXTENSIONS = ['.zip', '.rar']
INACTIVITY_TIMEOUT = 10                  # seconds to wait before auto-exit

# Ensure the target folder exists
os.makedirs(DOWNLOADS_DIR, exist_ok=True)

# YOUR_CLIENT_SECRET_HERE_CLIENT_SECRET_HEREE—
# Logging setup
# YOUR_CLIENT_SECRET_HERE_CLIENT_SECRET_HEREE—
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

# YOUR_CLIENT_SECRET_HERE_CLIENT_SECRET_HEREE—
# Watchdog event handler
# YOUR_CLIENT_SECRET_HERE_CLIENT_SECRET_HEREE—
class ArchiveHandler(FileSystemEventHandler):
    def __init__(self):
        self.processed = set()
        self.last_activity_time = time.time()

    # Triggered when a new file appears
    def on_created(self, event):
        if event.is_directory:
            return

        filepath = event.src_path
        ext = os.path.splitext(filepath)[1].lower()

        if ext in SUPPORTED_EXTENSIONS and filepath not in self.processed:
            self.processed.add(filepath)
            self.last_activity_time = time.time()
            logger.info(f"New archive detected: {filepath}")
            time.sleep(2)                       # give the OS a moment to finish copying
            self.extract_and_cleanup(filepath)

    # Unpack and delete the archive
    def extract_and_cleanup(self, archive_path):
        try:
            filename   = os.path.basename(archive_path)
            base_name  = os.path.splitext(filename)[0]
            extract_to = os.path.join(DOWNLOADS_DIR, base_name)
            os.makedirs(extract_to, exist_ok=True)

            ext = os.path.splitext(archive_path)[1].lower()
            if ext == '.zip':
                self._extract_zip(archive_path, extract_to, filename)
            elif ext == '.rar':
                self._extract_rar(archive_path, extract_to, filename)

            if os.path.exists(archive_path):
                os.remove(archive_path)
                logger.info(f"Deleted archive: {archive_path}")

        except Exception as e:
            logger.error(f"Extraction failed for {archive_path}: {e}")

    # Handle ZIP archives
    def _extract_zip(self, path, out_dir, name):
        try:
            with zipfile.ZipFile(path, 'r') as z:
                try:
                    z.extractall(out_dir)
                    logger.info(f"Extracted ZIP: {name}")
                except RuntimeError as e:
                    if "password" in str(e).lower():
                        logger.info(f"{name} is password-protected. Trying default password.")
                        with zipfile.ZipFile(path, 'r') as z2:
                            z2.extractall(out_dir, pwd=DEFAULT_PASSWORD.encode())
                            logger.info(f"Extracted protected ZIP: {name}")
                    else:
                        raise
        except Exception as e:
            raise RuntimeError(f"ZIP error: {e}")

    # Handle RAR archives
    def _extract_rar(self, path, out_dir, name):
        try:
            rarfile.UNRAR_TOOL = "unrar"       # assumes “unrar” is available
            with rarfile.RarFile(path, 'r') as r:
                if r.needs_password():
                    r.setpassword(DEFAULT_PASSWORD)
                    logger.info(f"{name} is password-protected.")
                r.extractall(out_dir)
                logger.info(f"Extracted RAR: {name}")
        except Exception as e:
            raise RuntimeError(f"RAR error: {e}")

# YOUR_CLIENT_SECRET_HERE_CLIENT_SECRET_HEREE—
# Helper to process any archives that were already present at start-up
# YOUR_CLIENT_SECRET_HERE_CLIENT_SECRET_HEREE—
def scan_existing_archives(handler):
    logger.info("Scanning for existing archives...")
    for file in os.listdir(DOWNLOADS_DIR):
        full_path = os.path.join(DOWNLOADS_DIR, file)
        if os.path.isfile(full_path) and os.path.splitext(full_path)[1].lower() in SUPPORTED_EXTENSIONS:
            logger.info(f"Found pre-existing archive: {full_path}")
            handler.extract_and_cleanup(full_path)
            handler.processed.add(full_path)

# YOUR_CLIENT_SECRET_HERE_CLIENT_SECRET_HEREE—
# Main loop
# YOUR_CLIENT_SECRET_HERE_CLIENT_SECRET_HEREE—
def main():
    logger.info(f"Monitoring folder: {DOWNLOADS_DIR}")
    handler = ArchiveHandler()
    scan_existing_archives(handler)

    observer = Observer()
    observer.schedule(handler, DOWNLOADS_DIR, recursive=False)
    observer.start()

    try:
        while True:
            time.sleep(1)
            if time.time() - handler.last_activity_time > INACTIVITY_TIMEOUT:
                logger.info(f"No new archives for {INACTIVITY_TIMEOUT} s — shutting down.")
                break
    except Exception as e:
        logger.error(f"Fatal error: {e}")
    finally:
        observer.stop()
        observer.join()

if __name__ == "__main__":
    main()
