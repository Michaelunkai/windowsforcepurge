import sys
import os
import json
import subprocess
import requests
import re
from datetime import datetime
from functools import partial

from PyQt5.QtWidgets import (
    QApplication, QWidget, QPushButton, QHBoxLayout, QVBoxLayout,
    QScrollArea, QLineEdit, QGridLayout, QLabel, QMenu, QDialog,
    QListWidget, QListWidgetItem, QMessageBox, QInputDialog,
    QTabWidget, QCheckBox
)
from PyQt5.QtGui import QFont, QDrag, QCursor, QPixmap, QImage, QIcon
from PyQt5.QtCore import Qt, QTimer, QRunnable, QThreadPool, QObject, pyqtSignal, pyqtSlot, QMimeData, QSize

from howlongtobeatpy import HowLongToBeat

# --- Optional word segmentation ---
try:
    import wordninja
except ImportError:
    wordninja = None

# YOUR_CLIENT_SECRET_HERE Persistence Functions YOUR_CLIENT_SECRET_HERE

SETTINGS_FILE = "tag_settings.json"
TABS_CONFIG_FILE = "tabs_config.json"

def load_settings():
    if os.path.exists(SETTINGS_FILE):
        try:
            with open(SETTINGS_FILE, "r") as f:
                return json.load(f)
        except Exception as e:
            print("Error loading settings file:", e)
    return {}

def save_settings(settings):
    try:
        with open(SETTINGS_FILE, "w") as f:
            json.dump(settings, f)
    except Exception as e:
        print("Error saving settings file:", e)

DEFAULT_TABS_CONFIG = [
    {"id": "all", "name": "All"},
    {"id": "finished", "name": "Finished"},
    {"id": "mybackup", "name": "MyBackup"},
    {"id": "not_for_me", "name": "Not for me right now"}
]

def load_tabs_config():
    if os.path.exists(TABS_CONFIG_FILE):
        try:
            with open(TABS_CONFIG_FILE, "r") as f:
                return json.load(f)
        except Exception as e:
            print("Error loading tabs config:", e)
    return DEFAULT_TABS_CONFIG

def save_tabs_config(config):
    try:
        with open(TABS_CONFIG_FILE, "w") as f:
            json.dump(config, f)
    except Exception as e:
        print("Error saving tabs config:", e)

persistent_settings = load_settings()
tabs_config = load_tabs_config()

# YOUR_CLIENT_SECRET_HERE Word Segmentation Helper YOUR_CLIENT_SECRET_HERE

def normalize_game_title(tag):
    """
    Insert spaces into a concatenated game title.
    If tag already contains spaces, return it.
    If tag is camel case, insert spaces before uppercase letters.
    Otherwise, if wordninja is available, use it; else use title().
    """
    if " " in tag:
        return tag
    if any(c.isupper() for c in tag[1:]):
        return re.sub(r'(?<!^)(?=[A-Z])', ' ', tag).strip()
    if wordninja is not None:
        return " ".join(wordninja.split(tag))
    return tag.title()

# YOUR_CLIENT_SECRET_HERE HTTP Session with Retries YOUR_CLIENT_SECRET_HERE

from requests.adapters import HTTPAdapter, Retry

session = requests.Session()
retries = Retry(total=3, backoff_factor=1, status_forcelist=[429, 500, 502, 503, 504])
adapter = HTTPAdapter(max_retries=retries)
session.mount("http://", adapter)
session.mount("https://", adapter)

# YOUR_CLIENT_SECRET_HERE Worker Classes YOUR_CLIENT_SECRET_HERE

class WorkerSignals(QObject):
    finished = pyqtSignal(object)

class Worker(QRunnable):
    def __init__(self, fn, *args, **kwargs):
        super().__init__()
        self.fn = fn
        self.args = args
        self.kwargs = kwargs
        self.signals = WorkerSignals()
    @pyqtSlot()
    def run(self):
        result = self.fn(*self.args, **self.kwargs)
        self.signals.finished.emit(result)

# YOUR_CLIENT_SECRET_HERE Helper Functions YOUR_CLIENT_SECRET_HERE

def fetch_game_time(alias):
    """
    Normalize alias then query HowLongToBeat.
    Returns (original alias, "<time> hours") or ("N/A").
    """
    normalized = normalize_game_title(alias)
    try:
        results = HowLongToBeat().search(normalized)
        if results:
            main_time = getattr(results[0], 'gameplay_main', None) or getattr(results[0], 'main_story', None)
            if main_time:
                return (alias, f"{main_time} hours")
            extra_time = getattr(results[0], 'gameplay_main_extra', None) or getattr(results[0], 'main_extra', None)
            if extra_time:
                return (alias, f"{extra_time} hours")
    except Exception as e:
        print(f"Error searching HowLongToBeat for '{normalized}': {e}")
    return (alias, "N/A")

def fetch_image(query):
    """
    Retrieve an image for the given query via DuckDuckGo.
    Uses the shared session with retries and a timeout of 15 seconds.
    """
    try:
        url = "https://duckduckgo.com/i.js"
        params = {"q": query, "o": "json", "iax": "images", "ia": "images"}
        headers = {"User-Agent": "Mozilla/5.0"}
        response = session.get(url, params=params, headers=headers, timeout=15)
        if response.status_code == 200:
            data = response.json()
            results = data.get("results", [])
            if results:
                image_url = results[0].get("image")
                if image_url:
                    img_response = session.get(image_url, stream=True, timeout=15)
                    if img_response.status_code == 200:
                        img = QImage()
                        img.loadFromData(img_response.content)
                        return (query, img)
    except Exception as e:
        print(f"Error fetching image for '{query}':", e)
    return (query, QImage())

def update_docker_tag_name(old_alias, new_alias):
    QMessageBox.information(None, "Info",
        "Renaming tags on Docker Hub is not supported by the API.\nOnly the local display name (alias) will be updated.")
    return True

def parse_date(date_str):
    try:
        return datetime.fromisoformat(date_str.replace("Z", ""))
    except Exception:
        return datetime.min

# YOUR_CLIENT_SECRET_HERE Custom Widgets YOUR_CLIENT_SECRET_HERE

class TagContainerWidget(QWidget):
    def __init__(self, type_name, parent=None):
        super().__init__(parent)
        self.type_name = type_name  
        self.setAcceptDrops(True)
        self.layout = QGridLayout(self)
        self.layout.setSpacing(10)
        self.setLayout(self.layout)
    def dragEnterEvent(self, event):
        if event.mimeData().hasText():
            event.acceptProposedAction()
    def dragMoveEvent(self, event):
        event.acceptProposedAction()
    def dropEvent(self, event):
        docker_name = event.mimeData().text()
        main_window = self.window()
        if main_window and hasattr(main_window, "update_tag_category"):
            main_window.update_tag_category(docker_name, self.type_name)
        event.acceptProposedAction()

class StyledButton(QPushButton):
    def __init__(self, text, color, parent=None):
        super().__init__(text, parent)
        self.setStyleSheet(f"""
            QPushButton {{
                background-color: {color};
                border: none;
                border-radius: 5px;
                padding: 10px;
                color: white;
                font-weight: bold;
                font-size: 14px;
            }}
            QPushButton:hover {{
                background-color: {color}99;
                border: 2px solid white;
            }}
            QPushButton:pressed {{
                background-color: {color}77;
            }}
        """)

class GameButton(QPushButton):
    dragThreshold = 10
    def __init__(self, text, parent=None):
        super().__init__(text, parent)
        self.setCheckable(True)
        self.setStyleSheet("""
            QPushButton {
                background-color: #2C3E50;
                border: none;
                border-radius: 8px;
                padding: 15px;
                color: white;
                font-size: 12px;
                min-height: 70px;
                text-align: center;
            }
            QPushButton:checked {
                background-color: #3498DB;
            }
            QPushButton:hover {
                background-color: #34495E;
                border: 2px solid #3498DB;
            }
            QPushButton:pressed {
                background-color: #2980B9;
            }
        """)
        self._drag_start_pos = None
    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton:
            self._drag_start_pos = event.pos()
        super().mousePressEvent(event)
    def mouseMoveEvent(self, event):
        if event.buttons() & Qt.LeftButton:
            if (event.pos() - self._drag_start_pos).manhattanLength() >= self.dragThreshold:
                mimeData = QMimeData()
                mimeData.setText(self.tag_info["docker_name"])
                drag = QDrag(self)
                drag.setMimeData(mimeData)
                drag.exec_(Qt.MoveAction)
                return
        super().mouseMoveEvent(event)
    def get_main_window(self):
        parent = self.parent()
        while parent:
            if hasattr(parent, "handle_tag_move"):
                return parent
            parent = parent.parent()
        return None
    def contextMenuEvent(self, event):
        menu = QMenu(self)
        change_action = menu.addAction("Change Tag Name")
        move_menu = menu.addMenu("Move To")
        for tab in tabs_config:
            move_menu.addAction(tab["name"])
        action = menu.exec_(event.globalPos())
        main_window = self.get_main_window()
        token = main_window.get_docker_token() if main_window else None
        if not token:
            return
        if action == change_action:
            new_alias, ok = QInputDialog.getText(self, "Change Tag Name",
                                                   "Enter new tag name:", QLineEdit.Normal, self.tag_info["alias"])
            if ok and new_alias:
                old_alias = self.tag_info["alias"]
                if update_docker_tag_name(old_alias, new_alias):
                    self.tag_info["alias"] = new_alias
                    persistent = persistent_settings.get(self.tag_info["docker_name"], {})
                    persistent["alias"] = new_alias
                    persistent_settings[self.tag_info["docker_name"]] = persistent
                    save_settings(persistent_settings)
                    lines = self.text().splitlines()
                    lines[0] = new_alias
                    self.setText("\n".join(lines))
                    if main_window and hasattr(main_window, "handle_tag_rename"):
                        main_window.handle_tag_rename(self.tag_info["docker_name"], new_alias)
                    worker = Worker(fetch_game_time, new_alias)
                    worker.signals.finished.connect(partial(main_window.handle_game_time_update, new_alias))
                    main_window.add_worker(worker)
                    QThreadPool.globalInstance().start(worker)
        elif action in menu.actions()[1].menu().actions():
            target_tab_name = action.text()
            target_tab_id = None
            for tab in tabs_config:
                if tab["name"] == target_tab_name:
                    target_tab_id = tab["id"]
                    break
            if target_tab_id and main_window and hasattr(main_window, "handle_tag_move"):
                main_window.handle_tag_move(self.tag_info["docker_name"], target_tab_id)

class ImageWorker(QRunnable):
    def __init__(self, query):
        super().__init__()
        self.query = query
        self.signals = WorkerSignals()
    @pyqtSlot()
    def run(self):
        result = fetch_image(self.query)
        self.signals.finished.emit(result)

# YOUR_CLIENT_SECRET_HERE Dialog for Deleting Tags YOUR_CLIENT_SECRET_HERE

class DeleteTagDialog(QDialog):
    def __init__(self, all_tags, parent=None):
        super().__init__(parent)
        self.all_tags = all_tags  
        self.setWindowTitle("Delete Tag")
        self.setMinimumSize(400, 400)
        self.init_ui()
    def format_size(self, size):
        for unit in ["B", "KB", "MB", "GB", "TB"]:
            if size < 1024:
                return f"{size:.1f}{unit}"
            size /= 1024
        return f"{size:.1f}PB"
    def init_ui(self):
        layout = QVBoxLayout(self)
        self.search_box = QLineEdit()
        self.search_box.setPlaceholderText("Search tag to delete...")
        layout.addWidget(self.search_box)
        self.dup_checkbox = QCheckBox("Show only duplicate tags")
        layout.addWidget(self.dup_checkbox)
        self.dup_checkbox.stateChanged.connect(self.populate_list)
        self.list_widget = QListWidget()
        self.list_widget.setSelectionMode(QListWidget.MultiSelection)
        layout.addWidget(self.list_widget)
        self.populate_list()
        self.search_box.textChanged.connect(self.filter_list)
        self.delete_button = QPushButton("Delete Selected")
        self.delete_button.setStyleSheet("""
            QPushButton {
                background-color: #C0392B;
                border: none;
                border-radius: 8px;
                padding: 12px;
                font-size: 14px;
            }
            QPushButton:hover {
                background-color: #E74C3C;
            }
            QPushButton:pressed {
                background-color: #A93226;
            }
        """)
        self.delete_button.clicked.connect(self.delete_selected)
        layout.addWidget(self.delete_button)
    def populate_list(self):
        self.list_widget.clear()
        only_duplicates = self.dup_checkbox.isChecked()
        alias_counts = {}
        for tag in self.all_tags:
            alias = tag["alias"]
            alias_counts[alias] = alias_counts.get(alias, 0) + 1
        for tag in self.all_tags:
            if only_duplicates and alias_counts[tag["alias"]] <= 1:
                continue
            display_text = f"{tag['alias']} ({self.format_size(tag['full_size'])})"
            item = QListWidgetItem(display_text)
            item.setData(Qt.UserRole, tag)
            self.list_widget.addItem(item)
    def filter_list(self, text):
        for i in range(self.list_widget.count()):
            item = self.list_widget.item(i)
            tag = item.data(Qt.UserRole)
            item.setHidden(text.lower() not in tag["alias"].lower())
    def delete_selected(self):
        selected_items = self.list_widget.selectedItems()
        if not selected_items:
            QMessageBox.information(self, "No Selection", "Please select at least one tag to delete.")
            return
        tags = [item.data(Qt.UserRole)["docker_name"] for item in selected_items]
        reply = QMessageBox.question(
            self, "Confirm Delete",
            "Are you sure you want to delete the following tags from Docker Hub?\n" + "\n".join(tags),
            QMessageBox.Yes | QMessageBox.No
        )
        if reply != QMessageBox.Yes:
            return
        token = self.parent().get_docker_token()
        if not token:
            return
        username = "michadockermisha"
        repo = "backup"
        headers = {"Authorization": f"JWT {token}"}
        successes = []
        failures = []
        for tag in tags:
            delete_url = f"https://hub.docker.com/v2/repositories/{username}/{repo}/tags/{tag}/"
            delete_response = requests.delete(delete_url, headers=headers)
            if delete_response.status_code == 204:
                successes.append(tag)
            else:
                failures.append((tag, delete_response.status_code, delete_response.text))
        message = ""
        if successes:
            message += "Successfully deleted:\n" + "\n".join(successes) + "\n\n"
            for tag in successes:
                items = self.list_widget.findItems(tag, Qt.MatchContains)
                for item in items:
                    row = self.list_widget.row(item)
                    self.list_widget.takeItem(row)
        if failures:
            message += "Failed to delete:\n" + "\n".join([f"{tag} (Status {status})" for tag, status, _ in failures])
            QMessageBox.warning(self, "Deletion Summary", message)
        else:
            QMessageBox.information(self, "Deletion Summary", message)
        if self.parent() and hasattr(self.parent(), "refresh_tags"):
            self.parent().refresh_tags()

# YOUR_CLIENT_SECRET_HERE Main Application Window YOUR_CLIENT_SECRET_HERE

class DockerApp(QWidget):
    def __init__(self):
        super().__init__()
        self.all_tags = self.fetch_tags()
        for tag in self.all_tags:
            tag["docker_name"] = tag["name"]
            tag["alias"] = persistent_settings.get(tag["docker_name"], {}).get("alias", tag["docker_name"])
            stored_cat = persistent_settings.get(tag["docker_name"], {}).get("category", "all")
            tag["category"] = stored_cat if any(tab["id"] == stored_cat for tab in tabs_config) else "all"
        self.setWindowTitle("michael fedro's backup&restore tool")
        self.run_processes = []
        self.game_times_cache = {}
        self.tag_buttons = {}
        self.image_cache = {}
        self.started_image_queries = set()
        self.mybackup_authorized = False
        self.previous_tab_index = 0
        self.tabs_config = load_tabs_config()
        self.tab_containers = {}
        self.docker_token = None
        self.active_workers = []
        self.init_ui()
        QThreadPool.globalInstance().setMaxThreadCount(10)
        QTimer.singleShot(0, self.start_game_time_queries)
    def add_worker(self, worker):
        self.active_workers.append(worker)
        worker.signals.finished.connect(lambda _: self.active_workers.remove(worker))
    def fetch_tags(self):
        url = "https://hub.docker.com/v2/repositories/michadockermisha/backup/tags?page_size=100"
        tag_list = []
        while url:
            try:
                response = requests.get(url)
                data = response.json()
                for item in data.get("results", []):
                    tag_list.append({
                        "name": item["name"],
                        "full_size": item.get("full_size", 0),
                        "last_updated": item.get("last_updated", "")
                    })
                url = data.get("next")
            except Exception as e:
                print("Error fetching tags:", e)
                break
        tag_list.sort(key=lambda x: x["name"].lower())
        return tag_list
    def format_size(self, size):
        for unit in ["B", "KB", "MB", "GB", "TB"]:
            if size < 1024:
                return f"{size:.1f}{unit}"
            size /= 1024
        return f"{size:.1f}PB"
    def init_ui(self):
        main_layout = QVBoxLayout(self)
        main_layout.setSpacing(20)
        main_layout.setContentsMargins(20, 20, 20, 20)
        title = QLabel("michael fedro's backup&restore tool")
        title.setStyleSheet("""
            QLabel {
                font-size: 24px;
                font-weight: bold;
                padding: 10px;
            }
        """)
        main_layout.addWidget(title, alignment=Qt.AlignCenter)
        # Control layout
        control_layout = QHBoxLayout()
        control_layout.setSpacing(10)
        self.search_box = QLineEdit()
        self.search_box.setPlaceholderText("Search tags...")
        self.search_box.setStyleSheet("""
            QLineEdit {
                padding: 12px;
                font-size: 16px;
                border: 2px solid #3E3E3E;
                border-radius: 8px;
            }
            QLineEdit:focus {
                border: 2px solid #3498DB;
            }
        """)
        self.search_box.textChanged.connect(self.filter_buttons)
        control_layout.addWidget(self.search_box)
        sort_button = QPushButton("Sort")
        sort_button.setStyleSheet("""
            QPushButton {
                border: none;
                border-radius: 8px;
                padding: 12px;
                font-size: 14px;
            }
            QPushButton:hover {
                background-color: #4E4E4E;
            }
            QPushButton:pressed {
                background-color: #2E2E2E;
            }
        """)
        sort_menu = QMenu(self)
        sort_menu.addAction("Heaviest to Lightest", lambda: self.sort_tags(descending=True))
        sort_menu.addAction("Lightest to Heaviest", lambda: self.sort_tags(descending=False))
        sort_menu.addAction("Sort by HowLong: Longest to Shortest", lambda: self.sort_tags_by_time(descending=True))
        sort_menu.addAction("Sort by HowLong: Shortest to Longest", lambda: self.sort_tags_by_time(descending=False))
        sort_menu.addAction("Sort by Date: Newest to Oldest", lambda: self.sort_tags_by_date(descending=True))
        sort_menu.addAction("Sort by Date: Oldest to Newest", lambda: self.sort_tags_by_date(descending=False))
        sort_button.setMenu(sort_menu)
        control_layout.addWidget(sort_button)
        run_selected = QPushButton("Run Selected")
        run_selected.setStyleSheet("""
            QPushButton {
                border: none;
                border-radius: 8px;
                padding: 12px;
                font-size: 14px;
            }
            QPushButton:hover {
                background-color: #2ECC71;
            }
            QPushButton:pressed {
                background-color: #1E8449;
            }
        """)
        run_selected.clicked.connect(self.run_selected_commands)
        control_layout.addWidget(run_selected)
        delete_tag_button = QPushButton("Delete Docker Tag")
        delete_tag_button.setStyleSheet("""
            QPushButton {
                border: none;
                border-radius: 8px;
                padding: 12px;
                font-size: 14px;
            }
            QPushButton:hover {
                background-color: #E74C3C;
            }
            QPushButton:pressed {
                background-color: #A93226;
            }
        """)
        delete_tag_button.clicked.connect(self.open_delete_dialog)
        control_layout.addWidget(delete_tag_button)
        # New "Save as .txt" button
        save_txt_button = QPushButton("Save as .txt")
        save_txt_button.setStyleSheet("""
            QPushButton {
                border: none;
                border-radius: 8px;
                padding: 12px;
                font-size: 14px;
                background-color: #8E44AD;
            }
            QPushButton:hover {
                background-color: #9B59B6;
            }
            QPushButton:pressed {
                background-color: #71368A;
            }
        """)
        save_txt_button.clicked.connect(self.save_as_txt)
        control_layout.addWidget(save_txt_button)
        main_layout.addLayout(control_layout)
        # Tab management buttons
        tab_mgmt_layout = QHBoxLayout()
        tab_mgmt_layout.setSpacing(10)
        add_tab_btn = QPushButton("Add Tab")
        add_tab_btn.clicked.connect(self.add_tab)
        tab_mgmt_layout.addWidget(add_tab_btn)
        rename_tab_btn = QPushButton("Rename Tab")
        rename_tab_btn.clicked.connect(self.rename_tab)
        tab_mgmt_layout.addWidget(rename_tab_btn)
        delete_tab_btn = QPushButton("Delete Tab")
        delete_tab_btn.clicked.connect(self.delete_tab)
        tab_mgmt_layout.addWidget(delete_tab_btn)
        main_layout.addLayout(tab_mgmt_layout)
        # Tabs
        self.tabs = QTabWidget()
        self.tab_containers = {}
        for tab in self.tabs_config:
            container = TagContainerWidget(tab["id"], parent=self)
            self.tab_containers[tab["id"]] = container
            scroll = QScrollArea()
            scroll.setWidgetResizable(True)
            scroll.setWidget(container)
            self.tabs.addTab(scroll, tab["name"])
        main_layout.addWidget(self.tabs)
        self.tabs.currentChanged.connect(self.on_tab_changed)
        self.previous_tab_index = 0
        self.create_tag_buttons()
    def save_as_txt(self):
        # Use the Downloads folder; if not available, use home.
        downloads = os.path.join(os.path.expanduser("~"), "Downloads")
        if not os.path.exists(downloads):
            downloads = os.path.expanduser("~")
        filepath = os.path.join(downloads, "tags.txt")
        output = []
        for tab in self.tabs_config:
            output.append(f"Tab: {tab['name']}")
            for tag in self.all_tags:
                if tag.get("category", "all") == tab["id"]:
                    output.append(tag["alias"])
            output.append("")  # blank line
        try:
            with open(filepath, "w") as f:
                f.write("\n".join(output))
            QMessageBox.information(self, "Save as .txt", f"Tags saved to {filepath}")
        except Exception as e:
            QMessageBox.warning(self, "Save as .txt", f"Error saving tags: {e}")
    def create_tag_buttons(self):
        for container in self.tab_containers.values():
            for i in reversed(range(container.layout.count())):
                widget = container.layout.itemAt(i).widget()
                if widget:
                    widget.setParent(None)
        self.buttons = []
        self.tag_buttons = {}
        pos = {tab_id: [0, 0] for tab_id in self.tab_containers}
        for tag in self.all_tags:
            time_line = (f"Approx Time: {self.game_times_cache[tag['alias']]}"
                         if tag["alias"] in self.game_times_cache and self.game_times_cache[tag["alias"]]
                         else "Approx Time: Loading...")
            text_lines = [tag["alias"], f"({self.format_size(tag['full_size'])})", time_line]
            display_text = "\n".join(text_lines)
            button = GameButton(display_text)
            button.tag_info = tag
            button.setIconSize(QSize(64, 64))
            self.tag_buttons.setdefault(tag["docker_name"], []).append(button)
            self.buttons.append(button)
            container = self.tab_containers.get(tag.get("category"), self.tab_containers.get("all"))
            row, col = pos[container.type_name]
            container.layout.addWidget(button, row, col)
            col += 1
            if col == 4:
                col = 0
                row += 1
            pos[container.type_name] = [row, col]
            alias = tag["alias"]
            if alias in self.image_cache:
                button.setIcon(QIcon(self.image_cache[alias]))
            elif alias not in getattr(self, "started_image_queries", set()):
                worker = Worker(fetch_image, alias)
                worker.signals.finished.connect(partial(self.handle_image_update, alias))
                self.add_worker(worker)
                QThreadPool.globalInstance().start(worker)
                if not hasattr(self, "started_image_queries"):
                    self.started_image_queries = set()
                self.started_image_queries.add(alias)
    def start_game_time_queries(self):
        for tag in self.all_tags:
            alias = tag["alias"]
            if alias not in self.game_times_cache:
                worker = Worker(fetch_game_time, alias)
                worker.signals.finished.connect(partial(self.handle_game_time_update, alias))
                self.add_worker(worker)
                QThreadPool.globalInstance().start(worker)
    def handle_game_time_update(self, alias, time_info):
        self.game_times_cache[alias] = time_info
        for docker_name, buttons in self.tag_buttons.items():
            for button in buttons:
                if button.tag_info["alias"] == alias:
                    lines = button.text().splitlines()
                    if len(lines) >= 3:
                        lines[2] = f"Approx Time: {time_info}" if time_info != "N/A" else "Approx Time: N/A"
                    else:
                        lines.append(f"Approx Time: {time_info}" if time_info != "N/A" else "Approx Time: N/A")
                    button.setText("\n".join(lines))
    def handle_image_update(self, alias, image):
        if not image.isNull():
            pixmap = QPixmap.fromImage(image)
            self.image_cache[alias] = pixmap
            for docker_name, buttons in self.tag_buttons.items():
                for button in buttons:
                    if button.tag_info["alias"] == alias:
                        button.setIcon(QIcon(pixmap))
        else:
            self.image_cache[alias] = QPixmap()
    def sort_tags(self, descending=True):
        self.all_tags.sort(key=lambda x: x["full_size"], reverse=descending)
        self.create_tag_buttons()
    def sort_tags_by_time(self, descending=True):
        def parse_time(time_str):
            try:
                return float(time_str.split()[0])
            except:
                return 0.0
        self.all_tags.sort(key=lambda x: parse_time(self.game_times_cache.get(x["alias"], "")), reverse=descending)
        self.create_tag_buttons()
    def sort_tags_by_date(self, descending=True):
        self.all_tags.sort(key=lambda x: parse_date(x.get("last_updated", "")), reverse=descending)
        self.create_tag_buttons()
    def filter_buttons(self, text):
        for button in self.buttons:
            if text.lower() in button.tag_info["alias"].lower():
                button.setVisible(True)
            else:
                button.setVisible(False)
    def run_selected_commands(self):
        selected_buttons = [btn for btn in self.buttons if btn.isChecked()]
        if not selected_buttons:
            QMessageBox.information(self, "No Selection", "Please select at least one tag to run.")
            return
        processes = []
        for btn in selected_buttons:
            tag = btn.tag_info["docker_name"]
            docker_command = (
                f'docker run '
                f'--rm '
                f'-v /mnt/c/games:/mnt/c/games '
                f'-e DISPLAY=$DISPLAY '
                f'-v /tmp/.X11-unix:/tmp/.X11-unix '
                f'--name "{tag}" '
                f'michadockermisha/backup:"{tag}" '
                f'sh -c "apk add rsync && mkdir -p /mnt/c/games/{tag} && rsync -aP /home/ /mnt/c/games/{tag}"'
            )
            proc = subprocess.Popen(docker_command, shell=True)
            processes.append((tag, proc))
        sender = self.sender()
        sender.setEnabled(False)
        self.run_processes = processes
        self.run_timer = QTimer()
        self.run_timer.timeout.connect(lambda: self.check_run_processes(sender))
        self.run_timer.start(500)
    def check_run_processes(self, run_button):
        still_running = []
        for tag, proc in self.run_processes:
            if proc.poll() is None:
                still_running.append((tag, proc))
        if not still_running:
            self.run_timer.stop()
            run_button.setEnabled(True)
            QMessageBox.information(self, "Run Complete", "All selected commands have finished.")
        self.run_processes = still_running
    def open_delete_dialog(self):
        dialog = DeleteTagDialog(self.all_tags, parent=self)
        dialog.exec_()
    def update_tag_category(self, docker_name, new_category):
        for tag in self.all_tags:
            if tag["docker_name"] == docker_name:
                tag["category"] = new_category
                persistent = persistent_settings.get(docker_name, {})
                persistent["category"] = new_category
                persistent_settings[docker_name] = persistent
                save_settings(persistent_settings)
        self.create_tag_buttons()
    def handle_tag_move(self, docker_name, new_category):
        self.update_tag_category(docker_name, new_category)
    def handle_tag_rename(self, docker_name, new_alias):
        for tag in self.all_tags:
            if tag["docker_name"] == docker_name:
                tag["alias"] = new_alias
                persistent = persistent_settings.get(docker_name, {})
                persistent["alias"] = new_alias
                persistent_settings[docker_name] = persistent
        self.create_tag_buttons()
    def refresh_tags(self):
        self.all_tags = self.fetch_tags()
        for tag in self.all_tags:
            tag["docker_name"] = tag["name"]
            stored_alias = persistent_settings.get(tag["docker_name"], {}).get("alias", tag["name"])
            stored_cat = persistent_settings.get(tag["docker_name"], {}).get("category", "all")
            tag["alias"] = stored_alias
            tag["category"] = stored_cat if any(tab["id"] == stored_cat for tab in self.tabs_config) else "all"
        self.create_tag_buttons()
    def on_tab_changed(self, index):
        current_tab_text = self.tabs.tabText(index)
        if current_tab_text == "MyBackup":
            token = self.get_docker_token()
            if token:
                self.mybackup_authorized = True
            else:
                QMessageBox.warning(self, "Access Denied", "Authentication failed.")
                self.tabs.setCurrentIndex(self.previous_tab_index)
                return
        self.previous_tab_index = index
    # --------------- Docker Hub Authentication ---------------
    def get_docker_token(self):
        if self.docker_token is not None:
            return self.docker_token
        password, ok = QInputDialog.getText(self, "Docker Hub Authentication",
                                            "Enter Docker Hub password:", QLineEdit.Password)
        if not (ok and password):
            return None
        username = "michadockermisha"
        login_url = "https://hub.docker.com/v2/users/login/"
        login_data = {"username": username, "password": password}
        login_response = requests.post(login_url, json=login_data)
        if login_response.status_code == 200 and login_response.json().get("token"):
            self.docker_token = login_response.json().get("token")
            return self.docker_token
        else:
            QMessageBox.warning(self, "Authentication Failed", "Incorrect Docker Hub password.")
            return None
    # ----------------- Tab Management Functions -----------------
    def add_tab(self):
        new_name, ok = QInputDialog.getText(self, "Add Tab", "Enter new tab name:")
        if not (ok and new_name):
            return
        new_id = new_name.lower().replace(" ", "_")
        if any(tab["id"] == new_id for tab in self.tabs_config):
            QMessageBox.warning(self, "Error", "A tab with that identifier already exists.")
            return
        token = self.get_docker_token()
        if not token:
            return
        new_tab = {"id": new_id, "name": new_name}
        self.tabs_config.append(new_tab)
        save_tabs_config(self.tabs_config)
        container = TagContainerWidget(new_id, parent=self)
        self.tab_containers[new_id] = container
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setWidget(container)
        self.tabs.addTab(scroll, new_name)
        self.create_tag_buttons()
    def rename_tab(self):
        current_index = self.tabs.currentIndex()
        if current_index < 0:
            return
        current_tab = self.tabs_config[current_index]
        new_name, ok = QInputDialog.getText(self, "Rename Tab", "Enter new tab name:", QLineEdit.Normal, current_tab["name"])
        if not (ok and new_name):
            return
        token = self.get_docker_token()
        if not token:
            return
        current_tab["name"] = new_name
        save_tabs_config(self.tabs_config)
        self.tabs.setTabText(current_index, new_name)
        self.create_tag_buttons()
    def delete_tab(self):
        current_index = self.tabs.currentIndex()
        if current_index < 0:
            return
        current_tab = self.tabs_config[current_index]
        if current_tab["id"] == "all":
            QMessageBox.warning(self, "Error", "You cannot delete the 'All' tab.")
            return
        token = self.get_docker_token()
        if not token:
            return
        reply = QMessageBox.question(self, "Confirm Deletion", f"Are you sure you want to delete the tab '{current_tab['name']}'?",
                                     QMessageBox.Yes | QMessageBox.No)
        if reply != QMessageBox.Yes:
            return
        for tag in self.all_tags:
            if tag.get("category") == current_tab["id"]:
                tag["category"] = "all"
                persistent = persistent_settings.get(tag["docker_name"], {})
                persistent["category"] = "all"
                persistent_settings[tag["docker_name"]] = persistent
        save_settings(persistent_settings)
        del self.tabs_config[current_index]
        save_tabs_config(self.tabs_config)
        self.tabs.removeTab(current_index)
        if current_tab["id"] in self.tab_containers:
            del self.tab_containers[current_tab["id"]]
        self.create_tag_buttons()

if __name__ == '__main__':
    app = QApplication(sys.argv)
    # Running as non-root is recommended to avoid QStandardPaths warnings.
    font = QFont("Segoe UI", 12, QFont.Bold)
    app.setFont(font)
    app.setStyleSheet("""
        QWidget {
            background-color: black;
            color: white;
        }
        QMenu, QInputDialog, QMessageBox {
            background-color: black;
            color: white;
        }
    """)
    QThreadPool.globalInstance().setMaxThreadCount(10)
    docker_app = DockerApp()
    docker_app.show()
    sys.exit(app.exec_())
