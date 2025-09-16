import os
import re

BASE_DIR = os.getcwd()
ENTRY_POINT = 'main.py'
OUTPUT_FILE = 'app.py'

visited = set()
code_blocks = []

def read_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()

def process_file(rel_path):
    abs_path = os.path.join(BASE_DIR, rel_path)
    if abs_path in visited:
        return
    visited.add(abs_path)

    code = read_file(abs_path)

    # Extract imports from same folder
    local_imports = re.findall(r'^\s*import (\w+)', code, re.MULTILINE) + \
                    [m[0] for m in re.findall(r'^\s*from (\w+) import', code, re.MULTILINE)]

    # Prioritize local files
    for module in local_imports:
        local_path = os.path.join(BASE_DIR, f'{module}.py')
        if os.path.isfile(local_path):
            process_file(f'{module}.py')

    # After dependencies
    code_blocks.append(f"# --- File: {rel_path} ---\n{code}\n")

def combine():
    if not os.path.exists(ENTRY_POINT):
        print(f"{ENTRY_POINT} not found.")
        return

    process_file(ENTRY_POINT)

    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        for block in code_blocks:
            f.write(block)
            f.write('\n')

    print(f"✅ Combined into {OUTPUT_FILE}")

if __name__ == "__main__":
    combine()
