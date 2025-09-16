// TodoNotes - Main JavaScript functionality

class TodoNotesApp {
    constructor() {
        this.init();
    }

    init() {
        this.setupGlobalSearch();
        this.setupNotifications();
        this.setupKeyboardShortcuts();
        this.setupAnimations();
        this.setupTheme();
    }

    // Global Search Functionality
    setupGlobalSearch() {
        const searchInput = document.getElementById('global-search');
        const searchResults = document.getElementById('search-results');
        
        if (!searchInput || !searchResults) return;

        let searchTimeout;
        
        searchInput.addEventListener('input', (e) => {
            const query = e.target.value.trim();
            
            clearTimeout(searchTimeout);
            
            if (query.length < 2) {
                searchResults.style.display = 'none';
                return;
            }
            
            searchTimeout = setTimeout(() => {
                this.performSearch(query, searchResults);
            }, 300);
        });

        // Hide search results when clicking outside
        document.addEventListener('click', (e) => {
            if (!searchInput.contains(e.target) && !searchResults.contains(e.target)) {
                searchResults.style.display = 'none';
            }
        });

        // Handle search result clicks
        searchResults.addEventListener('click', (e) => {
            const resultItem = e.target.closest('.search-result-item');
            if (resultItem) {
                const type = resultItem.dataset.type;
                const id = resultItem.dataset.id;
                
                if (type === 'task') {
                    window.location.href = '/tasks';
                } else if (type === 'note') {
                    window.location.href = `/notes/${id}/edit`;
                }
            }
        });
    }

    async performSearch(query, resultsContainer) {
        try {
            const response = await fetch(`/search?q=${encodeURIComponent(query)}`);
            const data = await response.json();
            
            this.displaySearchResults(data, resultsContainer);
        } catch (error) {
            console.error('Search error:', error);
            resultsContainer.style.display = 'none';
        }
    }

    displaySearchResults(data, container) {
        const { tasks, notes } = data;
        
        if (tasks.length === 0 && notes.length === 0) {
            container.innerHTML = '<div class="search-no-results">No results found</div>';
            container.style.display = 'block';
            return;
        }

        let html = '';
        
        if (tasks.length > 0) {
            html += '<div class="search-category">Tasks</div>';
            tasks.forEach(task => {
                html += `
                    <div class="search-result-item" data-type="task" data-id="${task.id}">
                        <i class="fas fa-check-circle search-result-icon"></i>
                        <span class="search-result-title">${this.escapeHtml(task.title)}</span>
                        <span class="search-result-type">Task</span>
                    </div>
                `;
            });
        }
        
        if (notes.length > 0) {
            html += '<div class="search-category">Notes</div>';
            notes.forEach(note => {
                html += `
                    <div class="search-result-item" data-type="note" data-id="${note.id}">
                        <i class="fas fa-sticky-note search-result-icon"></i>
                        <span class="search-result-title">${this.escapeHtml(note.title)}</span>
                        <span class="search-result-type">Note</span>
                    </div>
                `;
            });
        }
        
        container.innerHTML = html;
        container.style.display = 'block';
    }

    // Notification System
    setupNotifications() {
        this.notificationContainer = this.createNotificationContainer();
    }

    createNotificationContainer() {
        const container = document.createElement('div');
        container.className = 'notification-container';
        container.innerHTML = '';
        document.body.appendChild(container);
        return container;
    }

    showNotification(message, type = 'info', duration = 3000) {
        const notification = document.createElement('div');
        notification.className = `notification notification-${type}`;
        
        const icon = this.getNotificationIcon(type);
        notification.innerHTML = `
            <div class="notification-content">
                <i class="${icon}"></i>
                <span>${this.escapeHtml(message)}</span>
            </div>
            <button class="notification-close" onclick="this.parentElement.remove()">
                <i class="fas fa-times"></i>
            </button>
        `;
        
        this.notificationContainer.appendChild(notification);
        
        // Animate in
        setTimeout(() => notification.classList.add('show'), 100);
        
        // Auto remove
        if (duration > 0) {
            setTimeout(() => {
                notification.classList.remove('show');
                setTimeout(() => notification.remove(), 300);
            }, duration);
        }
    }

    getNotificationIcon(type) {
        const icons = {
            success: 'fas fa-check-circle',
            error: 'fas fa-exclamation-circle',
            warning: 'fas fa-exclamation-triangle',
            info: 'fas fa-info-circle'
        };
        return icons[type] || icons.info;
    }

    // Keyboard Shortcuts
    setupKeyboardShortcuts() {
        document.addEventListener('keydown', (e) => {
            // Global shortcuts
            if (e.ctrlKey || e.metaKey) {
                switch (e.key) {
                    case 'k':
                        e.preventDefault();
                        this.focusSearch();
                        break;
                    case 'n':
                        e.preventDefault();
                        if (window.location.pathname.includes('/tasks')) {
                            this.showTaskModal();
                        } else if (window.location.pathname.includes('/notes')) {
                            window.location.href = '/notes/create';
                        }
                        break;
                    case '/':
                        e.preventDefault();
                        this.focusSearch();
                        break;
                }
            }
            
            // Escape key
            if (e.key === 'Escape') {
                this.closeAllModals();
                this.clearSearch();
            }
        });
    }

    focusSearch() {
        const searchInput = document.getElementById('global-search');
        if (searchInput) {
            searchInput.focus();
            searchInput.select();
        }
    }

    showTaskModal() {
        const modal = document.getElementById('taskModal');
        if (modal && typeof showTaskModal === 'function') {
            showTaskModal();
        }
    }

    closeAllModals() {
        const modals = document.querySelectorAll('.modal');
        modals.forEach(modal => {
            modal.style.display = 'none';
        });
    }

    clearSearch() {
        const searchInput = document.getElementById('global-search');
        const searchResults = document.getElementById('search-results');
        
        if (searchInput) searchInput.value = '';
        if (searchResults) searchResults.style.display = 'none';
    }

    // Animations
    setupAnimations() {
        // Intersection Observer for animations
        const observerOptions = {
            threshold: 0.1,
            rootMargin: '0px 0px -50px 0px'
        };

        const observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    entry.target.classList.add('fade-in');
                }
            });
        }, observerOptions);

        // Observe all cards and main content sections
        const elementsToAnimate = document.querySelectorAll(`
            .stat-card, .dashboard-card, .task-card, .note-card, 
            .project-card, .action-btn, .page-header
        `);
        
        elementsToAnimate.forEach(el => observer.observe(el));
    }

    // Theme Management
    setupTheme() {
        // Auto theme based on time of day
        const hour = new Date().getHours();
        const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
        
        // Add theme class to body for future dark mode support
        if (prefersDark && (hour < 7 || hour > 19)) {
            document.body.classList.add('theme-dark');
        }
    }

    // Utility Functions
    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    formatDate(date) {
        if (!date) return '';
        
        const now = new Date();
        const inputDate = new Date(date);
        const diffTime = Math.abs(now - inputDate);
        const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
        
        if (diffDays === 0) {
            return 'Today';
        } else if (diffDays === 1) {
            return 'Yesterday';
        } else if (diffDays < 7) {
            return `${diffDays} days ago`;
        } else {
            return inputDate.toLocaleDateString();
        }
    }

    // API Helpers
    async apiRequest(url, options = {}) {
        try {
            const response = await fetch(url, {
                headers: {
                    'Content-Type': 'application/json',
                    ...options.headers
                },
                ...options
            });
            
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            
            return await response.json();
        } catch (error) {
            console.error('API request failed:', error);
            this.showNotification('Request failed. Please try again.', 'error');
            throw error;
        }
    }

    // Task Management
    async toggleTask(taskId) {
        try {
            await this.apiRequest(`/tasks/${taskId}/toggle`, {
                method: 'POST'
            });
            
            this.showNotification('Task updated successfully!', 'success');
            
            // Update UI without full reload if possible
            const checkbox = document.querySelector(`#task-${taskId}`);
            if (checkbox) {
                const taskCard = checkbox.closest('.task-card');
                if (taskCard) {
                    taskCard.classList.toggle('completed');
                }
            }
        } catch (error) {
            console.error('Error toggling task:', error);
        }
    }

    async deleteTask(taskId) {
        if (!confirm('Are you sure you want to delete this task?')) {
            return;
        }
        
        try {
            await this.apiRequest(`/tasks/${taskId}`, {
                method: 'DELETE'
            });
            
            this.showNotification('Task deleted successfully!', 'success');
            
            // Remove from UI
            const taskCard = document.querySelector(`#task-${taskId}`)?.closest('.task-card');
            if (taskCard) {
                taskCard.style.animation = 'slideOut 0.3s ease';
                setTimeout(() => taskCard.remove(), 300);
            }
        } catch (error) {
            console.error('Error deleting task:', error);
        }
    }

    async deleteNote(noteId) {
        if (!confirm('Are you sure you want to delete this note?')) {
            return;
        }
        
        try {
            await this.apiRequest(`/notes/${noteId}`, {
                method: 'DELETE'
            });
            
            this.showNotification('Note deleted successfully!', 'success');
            
            // Remove from UI
            const noteCard = document.querySelector(`[data-note-id="${noteId}"]`);
            if (noteCard) {
                noteCard.style.animation = 'slideOut 0.3s ease';
                setTimeout(() => noteCard.remove(), 300);
            }
        } catch (error) {
            console.error('Error deleting note:', error);
        }
    }

    // Local Storage Management
    saveToStorage(key, data) {
        try {
            localStorage.setItem(key, JSON.stringify(data));
        } catch (error) {
            console.warn('Could not save to localStorage:', error);
        }
    }

    loadFromStorage(key, defaultValue = null) {
        try {
            const item = localStorage.getItem(key);
            return item ? JSON.parse(item) : defaultValue;
        } catch (error) {
            console.warn('Could not load from localStorage:', error);
            return defaultValue;
        }
    }

    // Progressive Web App Features
    setupPWA() {
        // Service Worker registration
        if ('serviceWorker' in navigator) {
            window.addEventListener('load', () => {
                navigator.serviceWorker.register('/sw.js')
                    .then(registration => {
                        console.log('SW registered: ', registration);
                    })
                    .catch(registrationError => {
                        console.log('SW registration failed: ', registrationError);
                    });
            });
        }

        // Install prompt
        let deferredPrompt;
        window.addEventListener('beforeinstallprompt', (e) => {
            e.preventDefault();
            deferredPrompt = e;
            
            // Show install button
            const installBtn = document.getElementById('install-app');
            if (installBtn) {
                installBtn.style.display = 'block';
                installBtn.addEventListener('click', () => {
                    deferredPrompt.prompt();
                    deferredPrompt.userChoice.then((choiceResult) => {
                        if (choiceResult.outcome === 'accepted') {
                            console.log('User accepted the install prompt');
                        }
                        deferredPrompt = null;
                    });
                });
            }
        });
    }
}

// Notification Styles
const notificationStyles = `
.notification-container {
    position: fixed;
    top: 80px;
    right: 20px;
    z-index: 1000;
    display: flex;
    flex-direction: column;
    gap: 10px;
}

.notification {
    background: white;
    border-radius: 8px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 12px 16px;
    min-width: 300px;
    transform: translateX(100%);
    opacity: 0;
    transition: all 0.3s ease;
}

.notification.show {
    transform: translateX(0);
    opacity: 1;
}

.notification-content {
    display: flex;
    align-items: center;
    gap: 8px;
}

.notification-success { border-left: 4px solid #10b981; }
.notification-error { border-left: 4px solid #ef4444; }
.notification-warning { border-left: 4px solid #f59e0b; }
.notification-info { border-left: 4px solid #3b82f6; }

.notification-success .notification-content i { color: #10b981; }
.notification-error .notification-content i { color: #ef4444; }
.notification-warning .notification-content i { color: #f59e0b; }
.notification-info .notification-content i { color: #3b82f6; }

.notification-close {
    background: none;
    border: none;
    color: #6b7280;
    cursor: pointer;
    padding: 4px;
    border-radius: 4px;
}

.notification-close:hover {
    background: #f3f4f6;
}

.search-no-results {
    padding: 12px 16px;
    color: #6b7280;
    font-size: 14px;
}

.search-category {
    padding: 8px 16px;
    background: #f3f4f6;
    font-weight: 600;
    font-size: 12px;
    color: #374151;
    text-transform: uppercase;
    letter-spacing: 0.5px;
}

.search-result-item {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 12px 16px;
    cursor: pointer;
    transition: background 0.15s ease;
}

.search-result-item:hover {
    background: #f3f4f6;
}

.search-result-icon {
    color: #6b7280;
    width: 16px;
}

.search-result-title {
    flex: 1;
    font-weight: 500;
}

.search-result-type {
    font-size: 12px;
    color: #9ca3af;
    text-transform: uppercase;
    letter-spacing: 0.5px;
}

@keyframes slideOut {
    to {
        transform: translateX(100%);
        opacity: 0;
    }
}
`;

// Add notification styles to document
const styleSheet = document.createElement('style');
styleSheet.textContent = notificationStyles;
document.head.appendChild(styleSheet);

// Initialize the app when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.todoNotesApp = new TodoNotesApp();
});

// Global functions for backwards compatibility
function toggleTask(taskId) {
    return window.todoNotesApp.toggleTask(taskId);
}

function deleteTask(taskId) {
    return window.todoNotesApp.deleteTask(taskId);
}

function deleteNote(noteId) {
    return window.todoNotesApp.deleteNote(noteId);
}

// Export for module usage
if (typeof module !== 'undefined' && module.exports) {
    module.exports = TodoNotesApp;
}