import sys
import os
import json
import subprocess
import tempfile
from PyQt5.QtWidgets import (
    QApplication, QWidget, QLabel, QPushButton, QVBoxLayout, QHBoxLayout, QGridLayout, QScrollArea, QLineEdit, QComboBox, QFileDialog, QMessageBox, QDialog, QInputDialog, QMainWindow, QSplitter, QListWidget, QListWidgetItem, QTextEdit, QMenuBar, QAction, QFrame, QMenu
)
from PyQt5.QtGui import QPixmap, QFont, QMouseEvent, QIcon
from PyQt5.QtCore import Qt, QThread, pyqtSignal

# --- Data loading helpers ---
def load_tags():
    tags_file = 'tags_cache.json'
    tag_settings_file = 'tag_settings.json'
    tags, tag_settings = [], {}
    if os.path.exists(tags_file):
        with open(tags_file, 'r', encoding='utf-8') as f:
            cache = json.load(f)
            tags = cache.get('tags', [])
    if os.path.exists(tag_settings_file):
        with open(tag_settings_file, 'r', encoding='utf-8') as f:
            tag_settings = json.load(f)
    # Merge alias/category from tag_settings
    for tag in tags:
        name = tag.get('name', '').lower()
        settings = tag_settings.get(name, {})
        if 'alias' in settings:
            tag['alias'] = settings['alias']
        else:
            tag['alias'] = tag.get('name', '')
        tag['category'] = settings.get('category', 'all')
    return tags

def load_tabs():
    tabs_file = 'tabs_config.json'
    if os.path.exists(tabs_file):
        with open(tabs_file, 'r', encoding='utf-8') as f:
            return json.load(f)
    return []

def load_user_preferences():
    prefs_file = 'user_preferences.json'
    if os.path.exists(prefs_file):
        with open(prefs_file, 'r', encoding='utf-8') as f:
            return json.load(f)
    return {}

def save_user_preferences(prefs):
    with open('user_preferences.json', 'w', encoding='utf-8') as f:
        json.dump(prefs, f, indent=2)

def get_image_path(tag_name):
    filename = tag_name.lower().replace(' ', '').replace(':', '').replace('/', '').replace('\\', '') + '.png'
    path = os.path.join('images', filename)
    if os.path.exists(path):
        return path
    return None

def parse_time_file():
    import re
    time_map = {}
    if not os.path.exists('time.txt'):
        return time_map
    with open('time.txt', 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line or '–' not in line:
                continue
            name, time = line.split('–', 1)
            # Normalize: lowercase, remove spaces and special chars
            norm_name = re.sub(r'[^a-z0-9]', '', name.lower())
            time_map[norm_name] = time.strip()
    return time_map

# --- Sync Thread ---
class SyncThread(QThread):
    output = pyqtSignal(str)
    finished = pyqtSignal(int)
    def __init__(self, tags, sync_path):
        super().__init__()
        self.tags = tags
        self.sync_path = sync_path
    def run(self):
        import sys
        import os
        for tag in self.tags:
            tag_name = tag.get('name', tag.get('docker_name', ''))
            docker_command = (
                f'docker run --pull=always --rm '
                f'-v "{self.sync_path}:/games" '
                f'--name {tag_name} '
                f'michadockermisha/backup:{tag_name} '
                f'sh -c "mkdir -p /games/{tag_name} && rsync -aP --compress-level=1 --compress --numeric-ids --inplace --delete-during --info=progress2 --no-i-r /home /games/{tag_name}"'
            )
            print(f"SYNC COMMAND: {docker_command}", flush=True)
            self.output.emit(f"\n>>> Syncing {tag_name}\n{docker_command}\n")
            # Write the command to a temporary .bat file
            with tempfile.NamedTemporaryFile(delete=False, suffix='.bat', mode='w', encoding='utf-8') as batfile:
                batfile.write(docker_command)
                bat_path = batfile.name
            # Launch a new PowerShell window to run the .bat file
            subprocess.Popen(
                ["start", "powershell", "-NoExit", "-Command", bat_path],
                shell=True
            )
        self.finished.emit(0)

# --- Tag Card Widget ---
class TagCard(QWidget):
    def __init__(self, tag, select_callback=None, selected=False, parent=None, time_map=None, move_tag_callback=None):
        super().__init__(parent)
        self.tag = tag
        self.select_callback = select_callback
        self.selected = selected
        self.time_map = time_map or {}
        self.move_tag_callback = move_tag_callback
        self.init_ui()
    def init_ui(self):
        layout = QVBoxLayout()
        name_label = QLabel(self.tag.get('alias', self.tag.get('name', 'Unknown')))
        name_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        name_label.setFont(QFont('Arial', 12, QFont.Bold))
        layout.addWidget(name_label)
        image_path = get_image_path(self.tag.get('name', self.tag.get('docker_name', '')))
        if image_path:
            pixmap = QPixmap(image_path)
            pixmap = pixmap.scaled(240, 240, Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation)
            img_label = QLabel()
            img_label.setPixmap(pixmap)
            img_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
            layout.addWidget(img_label)
        else:
            img_label = QLabel('(No Image)')
            img_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
            layout.addWidget(img_label)
        size = self.tag.get('full_size', 0)
        size_gb = size / (1024**3) if size > 0 else 0
        size_str = f"{size_gb:.1f} GB" if size_gb > 0 else "N/A"
        # --- TIME LOOKUP ---
        import re
        tag_name = self.tag.get('name', self.tag.get('docker_name', ''))
        norm_tag = re.sub(r'[^a-z0-9]', '', tag_name.lower())
        time_str = self.time_map.get(norm_tag, 'N/A')
        info_label = QLabel(f"Size: {size_str}\nTime: {time_str}")
        info_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(info_label)
        if self.selected:
            self.setStyleSheet('background: #3399ff; border: 2px solid #0055cc; border-radius: 8px; color: white;')
        else:
            self.setStyleSheet('')
        self.setLayout(layout)
        self.setFixedWidth(280)
        self.setFixedHeight(340)
    def mousePressEvent(self, event: QMouseEvent):
        if event.button() == Qt.MouseButton.RightButton and self.move_tag_callback:
            self.show_context_menu(event.pos())
        elif self.select_callback:
            self.select_callback(self.tag)
    def show_context_menu(self, pos):
        menu = QMenu(self)
        move_action = menu.addAction('Move to another tab')
        global_pos = self.mapToGlobal(pos)
        def handle_action(action):
            if action == move_action and self.move_tag_callback is not None:
                self.move_tag_callback(self.tag)
        menu.triggered.connect(handle_action)
        menu.exec_(global_pos)

# --- Main Window ---
class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.tags = load_tags()
        self.tabs = load_tabs()
        self.prefs = load_user_preferences()
        self.selected_tags = set()
        self.current_tab = 'All'
        self.time_map = parse_time_file()
        self.init_ui()
    def init_ui(self):
        self.setWindowTitle('Games Docker Menu - PyQt5 GUI')
        self.resize(1400, 900)
        # --- Main Content Area (must be initialized first!) ---
        self.content_widget = QWidget()
        self.content_layout = QVBoxLayout()
        self.content_widget.setLayout(self.content_layout)
        # --- Menu Bar ---
        menubar = QMenuBar(self)
        self.setMenuBar(menubar)
        # Main Menus
        edit_action = QAction('Edit', self)
        edit_action.triggered.connect(self.show_edit)
        search_action = QAction('Search', self)
        search_action.triggered.connect(self.show_search)
        sort_action = QAction('Sort', self)
        sort_action.triggered.connect(self.show_sort)
        time_action = QAction('Time Menu', self)
        time_action.triggered.connect(self.show_time_menu)
        sync_action = QAction('Sync', self)
        sync_action.triggered.connect(self.sync_selected)
        path_action = QAction('Change Sync Path', self)
        path_action.triggered.connect(self.change_sync_path)
        menubar.addAction(edit_action)
        menubar.addAction(search_action)
        menubar.addAction(sort_action)
        menubar.addAction(time_action)
        menubar.addAction(sync_action)
        menubar.addAction(path_action)
        # --- Sidebar for Tabs ---
        sidebar = QListWidget()
        sidebar.setMaximumWidth(200)
        # Always add 'All' tab first
        sidebar.addItem('All')
        exclude_tabs = {'my backup', 'meh', 'localcoop', 'finished', 'operationsystems'}
        for tab in self.tabs:
            name = tab.get('name', 'Unknown')
            if name.strip().lower() not in exclude_tabs and name.strip().lower() != 'all':
                sidebar.addItem(name)
        sidebar.currentTextChanged.connect(self.change_tab)
        sidebar.setCurrentRow(0)
        self.sidebar = sidebar
        # --- Splitter Layout ---
        splitter = QSplitter()
        splitter.addWidget(sidebar)
        splitter.addWidget(self.content_widget)
        self.setCentralWidget(splitter)
        self.show_browse()
    def change_tab(self, tab_name):
        self.current_tab = tab_name
        self.show_browse()
    def show_browse(self):
        self.clear_content()
        # Exclude tags from 'All' tab if their category matches any excluded tab name or id
        exclude_tab_names = {'my backup', 'meh', 'localcoop', 'finished', 'operationsystems'}
        exclude_tab_ids = {'mybackup', 'meh', 'localcoop', 'finished', 'operationsystems', 'not_for_me', 'oporationsystems'}
        if self.current_tab == 'All':
            filtered = [
                t for t in self.tags
                if str(t.get('category', 'all')).strip().lower() not in exclude_tab_names
                and str(t.get('category', 'all')).strip().lower() not in exclude_tab_ids
            ]
        else:
            tab_id = None
            for tab in self.tabs:
                if tab.get('name', '') == self.current_tab:
                    tab_id = tab.get('id', '').lower()
            filtered = [t for t in self.tags if t.get('category', 'all').lower() == (tab_id or '').lower()]
        # Grid of TagCards
        grid = QGridLayout()
        cols = 6
        for idx, tag in enumerate(filtered):
            card = TagCard(
                tag,
                select_callback=self.toggle_select,
                selected=tag.get('name', tag.get('docker_name', '')) in self.selected_tags,
                time_map=self.time_map,
                move_tag_callback=self.move_tag_permanently
            )
            row, col = divmod(idx, cols)
            grid.addWidget(card, row, col)
        grid_frame = QFrame()
        grid_frame.setLayout(grid)
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setWidget(grid_frame)
        self.content_layout.addWidget(scroll)
        sync_btn = QPushButton('Sync Selected')
        sync_btn.clicked.connect(self.sync_selected)
        self.content_layout.addWidget(sync_btn)
    def show_search(self):
        self.clear_content()
        search_box = QLineEdit()
        search_box.setPlaceholderText('Search games...')
        result_area = QScrollArea()
        result_area.setWidgetResizable(True)
        result_widget = QWidget()
        result_layout = QGridLayout()
        result_widget.setLayout(result_layout)
        result_area.setWidget(result_widget)
        def do_search():
            term = search_box.text().lower()
            matches = [t for t in self.tags if term in t.get('alias', '').lower() or term in t.get('name', '').lower()]
            for i in reversed(range(result_layout.count())):
                item = result_layout.itemAt(i)
                if item is not None:
                    w = item.widget()
                    if w:
                        w.setParent(None)
            for idx, tag in enumerate(matches):
                card = TagCard(tag, select_callback=self.toggle_select, selected=tag.get('name', tag.get('docker_name', '')) in self.selected_tags, time_map=self.time_map)
                row, col = divmod(idx, 6)
                result_layout.addWidget(card, row, col)
        search_box.textChanged.connect(do_search)
        self.content_layout.addWidget(search_box)
        self.content_layout.addWidget(result_area)
    def show_edit(self):
        self.clear_content()
        layout = QVBoxLayout()
        # Tabs List
        tabs_list = QListWidget()
        for tab in self.tabs:
            tabs_list.addItem(tab.get('name', 'Unknown'))
        layout.addWidget(QLabel('Tabs:'))
        layout.addWidget(tabs_list)
        # Add/Remove/Edit Tab Buttons
        btn_layout = QHBoxLayout()
        add_btn = QPushButton('Add Tab')
        remove_btn = QPushButton('Remove Tab')
        edit_btn = QPushButton('Edit Tab Name')
        btn_layout.addWidget(add_btn)
        btn_layout.addWidget(remove_btn)
        btn_layout.addWidget(edit_btn)
        layout.addLayout(btn_layout)
        # Move Tag to Tab
        move_layout = QHBoxLayout()
        move_tag_btn = QPushButton('Move Tag to Tab')
        move_layout.addWidget(move_tag_btn)
        layout.addLayout(move_layout)
        # Widget to hold everything
        edit_widget = QWidget()
        edit_widget.setLayout(layout)
        self.content_layout.addWidget(edit_widget)
        # --- Button Logic ---
        def save_tabs():
            with open('tabs_config.json', 'w', encoding='utf-8') as f:
                json.dump(self.tabs, f, indent=2)
        def refresh_tabs():
            tabs_list.clear()
            for tab in self.tabs:
                tabs_list.addItem(tab.get('name', 'Unknown'))
        def add_tab():
            name, ok = QInputDialog.getText(self, 'Add Tab', 'Tab name:')
            if ok and name.strip():
                tab_id = name.strip().lower().replace(' ', '_')
                self.tabs.append({'name': name.strip(), 'id': tab_id})
                save_tabs()
                refresh_tabs()
                self.sidebar.addItem(name.strip())
        def remove_tab():
            row = tabs_list.currentRow()
            if row >= 0 and row < len(self.tabs):
                del self.tabs[row]
                save_tabs()
                refresh_tabs()
                self.sidebar.takeItem(row+1)  # +1 to skip 'All'
        def edit_tab():
            row = tabs_list.currentRow()
            if row >= 0 and row < len(self.tabs):
                old_name = self.tabs[row]['name']
                new_name, ok = QInputDialog.getText(self, 'Edit Tab', 'New tab name:', text=old_name)
                if ok and new_name.strip():
                    self.tabs[row]['name'] = new_name.strip()
                    save_tabs()
                    refresh_tabs()
                    sidebar_item = self.sidebar.item(row+1)
                    if sidebar_item is not None:
                        sidebar_item.setText(new_name.strip())
        def move_tag():
            tag_names = [t.get('name', t.get('docker_name', '')) for t in self.tags]
            tag, ok1 = QInputDialog.getItem(self, 'Move Tag', 'Select tag:', tag_names, editable=False)
            if not ok1:
                return
            tab_names = [tab.get('name', 'Unknown') for tab in self.tabs]
            tab_name, ok2 = QInputDialog.getItem(self, 'Move Tag', 'Select tab:', tab_names, editable=False)
            if not ok2:
                return
            # Update tag_settings.json
            tag_settings = {}
            if os.path.exists('tag_settings.json'):
                with open('tag_settings.json', 'r', encoding='utf-8') as f:
                    tag_settings = json.load(f)
            tag_key = tag.lower()
            if tag_key not in tag_settings:
                tag_settings[tag_key] = {}
            # Find tab id
            tab_id = None
            for tab in self.tabs:
                if tab.get('name', '') == tab_name:
                    tab_id = tab.get('id', '').lower()
            tag_settings[tag_key]['category'] = tab_id or 'all'
            with open('tag_settings.json', 'w', encoding='utf-8') as f:
                json.dump(tag_settings, f, indent=2)
        add_btn.clicked.connect(add_tab)
        remove_btn.clicked.connect(remove_tab)
        edit_btn.clicked.connect(edit_tab)
        move_tag_btn.clicked.connect(move_tag)
    def show_sort(self):
        self.clear_content()
        sort_options = [
            'Size (Largest)', 'Size (Smallest)', 'Name (A-Z)', 'Name (Z-A)',
            'Time (Shortest)', 'Time (Longest)',
            'Latest Added', 'Oldest Added'
        ]
        for opt in sort_options:
            btn = QPushButton(opt)
            btn.clicked.connect(lambda _, o=opt: self.sort_and_show(o))
            self.content_layout.addWidget(btn)
    def sort_and_show(self, option):
        if option == 'Size (Largest)':
            self.tags.sort(key=lambda x: x.get('full_size', 0), reverse=True)
        elif option == 'Size (Smallest)':
            self.tags.sort(key=lambda x: x.get('full_size', 0))
        elif option == 'Name (A-Z)':
            self.tags.sort(key=lambda x: x.get('alias', '').lower())
        elif option == 'Name (Z-A)':
            self.tags.sort(key=lambda x: x.get('alias', '').lower(), reverse=True)
        elif option == 'Time (Shortest)':
            import re
            def get_time(tag):
                tag_name = tag.get('name', tag.get('docker_name', ''))
                norm_tag = re.sub(r'[^a-z0-9]', '', tag_name.lower())
                t = self.time_map.get(norm_tag, None)
                if not t:
                    return float('inf')
                m = re.search(r'([\d.]+)', t)
                return float(m.group(1)) if m else float('inf')
            self.tags.sort(key=get_time)
        elif option == 'Time (Longest)':
            import re
            def get_time(tag):
                tag_name = tag.get('name', tag.get('docker_name', ''))
                norm_tag = re.sub(r'[^a-z0-9]', '', tag_name.lower())
                t = self.time_map.get(norm_tag, None)
                if not t:
                    return -float('inf')
                m = re.search(r'([\d.]+)', t)
                return float(m.group(1)) if m else -float('inf')
            self.tags.sort(key=get_time, reverse=True)
        elif option == 'Latest Added':
            self.tags = list(reversed(self.tags))
        elif option == 'Oldest Added':
            self.tags = sorted(self.tags, key=lambda x: 0)  # preserve original order
        self.show_browse()
    def show_time_menu(self):
        self.clear_content()
        # Just a placeholder for now
        self.content_layout.addWidget(QLabel('Time Menu: (implement stats, debug, refresh, etc.)'))
    def toggle_select(self, tag):
        name = tag.get('name', tag.get('docker_name', ''))
        if name in self.selected_tags:
            self.selected_tags.remove(name)
        else:
            self.selected_tags.add(name)
        self.show_browse()
    def sync_selected(self):
        if not self.selected_tags:
            QMessageBox.information(self, 'Sync', 'No games selected!')
            return
        sync_path = self.prefs.get('sync_destination', 'F:\\Games')
        tags_to_sync = [t for t in self.tags if t.get('name', t.get('docker_name', '')) in self.selected_tags]
        dlg = QDialog(self)
        dlg.setWindowTitle('Sync Progress')
        dlg.resize(700, 400)
        layout = QVBoxLayout()
        output_box = QTextEdit()
        output_box.setReadOnly(True)
        layout.addWidget(output_box)
        dlg.setLayout(layout)
        thread = SyncThread(tags_to_sync, sync_path)
        thread.output.connect(lambda text: output_box.append(text))
        def show_sync_complete():
            QMessageBox.information(self, 'Sync', 'Sync complete!')
        thread.finished.connect(lambda _: show_sync_complete())
        thread.finished.connect(dlg.accept)
        thread.start()
        dlg.exec_()
    def change_sync_path(self):
        dlg = QFileDialog(self)
        dlg.setFileMode(QFileDialog.Directory)
        dlg.setOption(QFileDialog.ShowDirsOnly, True)
        if dlg.exec_():
            path = dlg.selectedFiles()[0]
            self.prefs['sync_destination'] = path
            save_user_preferences(self.prefs)
            QMessageBox.information(self, 'Sync Path', f'Sync path set to: {path}')
    def clear_content(self):
        if not hasattr(self, 'content_layout') or self.content_layout is None:
            return
        for i in reversed(range(self.content_layout.count())):
            item = self.content_layout.itemAt(i)
            if item is not None:
                w = item.widget()
                if w:
                    w.setParent(None)
    def move_tag_permanently(self, tag):
        tab_names = [tab.get('name', 'Unknown') for tab in self.tabs]
        tab_name, ok = QInputDialog.getItem(self, 'Move Tag', 'Select tab:', tab_names, editable=False)
        if not ok:
            return
        tag_settings = {}
        if os.path.exists('tag_settings.json'):
            with open('tag_settings.json', 'r', encoding='utf-8') as f:
                tag_settings = json.load(f)
        tag_key = tag.get('name', tag.get('docker_name', '')).lower()
        if tag_key not in tag_settings:
            tag_settings[tag_key] = {}
        tab_id = None
        for tab in self.tabs:
            if tab.get('name', '') == tab_name:
                tab_id = tab.get('id', '').lower()
        tag_settings[tag_key]['category'] = tab_id or 'all'
        with open('tag_settings.json', 'w', encoding='utf-8') as f:
            json.dump(tag_settings, f, indent=2)
        # Reload tags from disk to ensure UI reflects latest categories
        self.tags = load_tags()
        # If moved to an excluded tab, refresh to remove from 'All' view
        exclude_tabs = {'my backup', 'meh', 'localcoop', 'finished', 'operationsystems'}
        self.show_browse()

if __name__ == '__main__':
    app = QApplication(sys.argv)
    # --- GLOBAL STYLESHEET FOR DARK THEME AND RED, BOLD, LARGE TEXT ---
    app.setStyleSheet('''
        QWidget {
            background-color: #181818;
            color: #ff2222;
            font-family: Arial, Helvetica, sans-serif;
            font-size: 18px;
            font-weight: bold;
        }
        QLabel, QPushButton, QListWidget, QMenuBar, QLineEdit, QTextEdit, QComboBox, QFrame {
            color: #ff2222;
            font-size: 18px;
            font-weight: bold;
        }
        QPushButton {
            background-color: #232323;
            border: 2px solid #ff2222;
            border-radius: 8px;
            padding: 8px 16px;
        }
        QPushButton:hover {
            background-color: #333333;
        }
        QListWidget {
            background-color: #232323;
            border: none;
        }
        QListWidget::item:selected {
            background: #ff2222;
            color: #181818;
        }
        QMenuBar {
            background-color: #232323;
        }
        QMenuBar::item {
            background: transparent;
            color: #ff2222;
        }
        QMenuBar::item:selected {
            background: #ff2222;
            color: #181818;
        }
        QScrollArea {
            background: #181818;
        }
        QLineEdit, QTextEdit {
            background: #232323;
            border: 1px solid #ff2222;
            color: #ff2222;
        }
    ''')
    win = MainWindow()
    win.show()
    sys.exit(app.exec_()) 