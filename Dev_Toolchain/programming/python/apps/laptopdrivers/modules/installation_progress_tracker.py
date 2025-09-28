"""
Enhanced Installation Progress Tracker
Provides detailed progress tracking, ETA calculations, and comprehensive
status updates throughout the driver installation process.
"""

import asyncio
import logging
import time
from typing import Dict, List, Optional, Callable, Any
from datetime import datetime, timedelta
from dataclasses import dataclass, field
from enum import Enum
import threading
import json

class TaskStatus(Enum):
    PENDING = "pending"
    RUNNING = "running" 
    COMPLETED = "completed"
    FAILED = "failed"
    SKIPPED = "skipped"

@dataclass
class ProgressTask:
    """Represents a single task in the installation process."""
    id: str
    name: str
    description: str
    estimated_duration: float = 30.0  # seconds
    status: TaskStatus = TaskStatus.PENDING
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    progress_percent: float = 0.0
    current_step: str = ""
    error_message: str = ""
    subtasks: List['ProgressTask'] = field(default_factory=list)
    metadata: Dict[str, Any] = field(default_factory=dict)

class InstallationProgressTracker:
    """Advanced progress tracking system for driver installations."""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        self.tasks: Dict[str, ProgressTask] = {}
        self.task_order: List[str] = []
        self.current_task_id: Optional[str] = None
        self.overall_progress: float = 0.0
        self.start_time: Optional[datetime] = None
        self.estimated_completion_time: Optional[datetime] = None
        
        # Progress callbacks
        self.progress_callbacks: List[Callable] = []
        self.status_callbacks: List[Callable] = []
        
        # Statistics
        self.stats = {
            'total_tasks': 0,
            'completed_tasks': 0,
            'failed_tasks': 0,
            'skipped_tasks': 0,
            'total_estimated_time': 0.0,
            'actual_elapsed_time': 0.0,
            'average_task_accuracy': 0.0
        }
        
        # Thread safety
        self._lock = threading.Lock()
    
    def add_progress_callback(self, callback: Callable[[str, float, str], None]):
        """Add a callback for progress updates."""
        self.progress_callbacks.append(callback)
    
    def add_status_callback(self, callback: Callable[[Dict], None]):
        """Add a callback for status updates."""
        self.status_callbacks.append(callback)
    
    def initialize_installation(self, tasks: List[Dict]):
        """Initialize the installation process with a list of tasks."""
        with self._lock:
            self.tasks.clear()
            self.task_order.clear()
            self.current_task_id = None
            self.overall_progress = 0.0
            self.start_time = datetime.now()
            
            total_estimated_time = 0.0
            
            for task_info in tasks:
                task = ProgressTask(
                    id=task_info['id'],
                    name=task_info['name'],
                    description=task_info.get('description', ''),
                    estimated_duration=task_info.get('estimated_duration', 30.0),
                    metadata=task_info.get('metadata', {})
                )
                
                # Add subtasks if provided
                if 'subtasks' in task_info:
                    for subtask_info in task_info['subtasks']:
                        subtask = ProgressTask(
                            id=subtask_info['id'],
                            name=subtask_info['name'],
                            description=subtask_info.get('description', ''),
                            estimated_duration=subtask_info.get('estimated_duration', 10.0),
                            metadata=subtask_info.get('metadata', {})
                        )
                        task.subtasks.append(subtask)
                        total_estimated_time += subtask.estimated_duration
                
                self.tasks[task.id] = task
                self.task_order.append(task.id)
                total_estimated_time += task.estimated_duration
            
            self.stats['total_tasks'] = len(self.tasks)
            self.stats['total_estimated_time'] = total_estimated_time
            
            # Calculate initial ETA
            self.estimated_completion_time = self.start_time + timedelta(seconds=total_estimated_time)
            
            self.logger.info(f"Initialized installation tracker with {len(self.tasks)} tasks, "
                           f"estimated completion: {self.estimated_completion_time}")
            
            self._notify_status_callbacks()
    
    def start_task(self, task_id: str, step_description: str = ""):
        """Start a specific task."""
        with self._lock:
            if task_id not in self.tasks:
                self.logger.error(f"Task {task_id} not found")
                return False
            
            task = self.tasks[task_id]
            task.status = TaskStatus.RUNNING
            task.start_time = datetime.now()
            task.current_step = step_description
            task.progress_percent = 0.0
            
            self.current_task_id = task_id
            
            self.logger.info(f"Started task: {task.name}")
            self._update_overall_progress()
            self._notify_progress_callbacks(task.name, task.progress_percent, step_description)
            self._notify_status_callbacks()
            
            return True
    
    def update_task_progress(self, task_id: str, progress_percent: float, step_description: str = ""):
        """Update progress for a specific task."""
        with self._lock:
            if task_id not in self.tasks:
                self.logger.error(f"Task {task_id} not found")
                return False
            
            task = self.tasks[task_id]
            if task.status != TaskStatus.RUNNING:
                self.logger.warning(f"Trying to update progress for non-running task: {task_id}")
                return False
            
            task.progress_percent = min(100.0, max(0.0, progress_percent))
            if step_description:
                task.current_step = step_description
            
            self._update_overall_progress()
            self._update_eta()
            
            self._notify_progress_callbacks(task.name, task.progress_percent, task.current_step)
            self._notify_status_callbacks()
            
            return True
    
    def complete_task(self, task_id: str, success: bool = True, error_message: str = ""):
        """Mark a task as completed or failed."""
        with self._lock:
            if task_id not in self.tasks:
                self.logger.error(f"Task {task_id} not found")
                return False
            
            task = self.tasks[task_id]
            task.end_time = datetime.now()
            task.progress_percent = 100.0 if success else task.progress_percent
            
            if success:
                task.status = TaskStatus.COMPLETED
                self.stats['completed_tasks'] += 1
                self.logger.info(f"Completed task: {task.name}")
            else:
                task.status = TaskStatus.FAILED
                task.error_message = error_message
                self.stats['failed_tasks'] += 1
                self.logger.error(f"Failed task: {task.name} - {error_message}")
            
            # Update task duration accuracy
            if task.start_time:
                actual_duration = (task.end_time - task.start_time).total_seconds()
                accuracy = min(task.estimated_duration, actual_duration) / max(task.estimated_duration, actual_duration)
                task.metadata['duration_accuracy'] = accuracy
            
            self._update_overall_progress()
            self._update_eta()
            
            # Move to next task if this was the current task
            if self.current_task_id == task_id:
                self._advance_to_next_task()
            
            self._notify_progress_callbacks(
                task.name, 
                100.0 if success else task.progress_percent,
                "Completed" if success else f"Failed: {error_message}"
            )
            self._notify_status_callbacks()
            
            return True
    
    def skip_task(self, task_id: str, reason: str = ""):
        """Skip a task."""
        with self._lock:
            if task_id not in self.tasks:
                self.logger.error(f"Task {task_id} not found")
                return False
            
            task = self.tasks[task_id]
            task.status = TaskStatus.SKIPPED
            task.end_time = datetime.now()
            task.error_message = reason
            task.progress_percent = 0.0
            
            self.stats['skipped_tasks'] += 1
            self.logger.info(f"Skipped task: {task.name} - {reason}")
            
            self._update_overall_progress()
            self._update_eta()
            
            if self.current_task_id == task_id:
                self._advance_to_next_task()
            
            self._notify_progress_callbacks(task.name, 0.0, f"Skipped: {reason}")
            self._notify_status_callbacks()
            
            return True
    
    def _advance_to_next_task(self):
        """Advance to the next pending task."""
        if not self.current_task_id:
            return
        
        current_index = self.task_order.index(self.current_task_id)
        
        # Find next pending task
        for i in range(current_index + 1, len(self.task_order)):
            next_task_id = self.task_order[i]
            if self.tasks[next_task_id].status == TaskStatus.PENDING:
                self.current_task_id = next_task_id
                return
        
        # No more pending tasks
        self.current_task_id = None
    
    def _update_overall_progress(self):
        """Update overall installation progress."""
        if not self.tasks:
            self.overall_progress = 0.0
            return
        
        total_weight = sum(task.estimated_duration for task in self.tasks.values())
        if total_weight == 0:
            self.overall_progress = 0.0
            return
        
        weighted_progress = 0.0
        for task in self.tasks.values():
            task_weight = task.estimated_duration / total_weight
            if task.status == TaskStatus.COMPLETED:
                weighted_progress += task_weight * 100.0
            elif task.status == TaskStatus.RUNNING:
                weighted_progress += task_weight * task.progress_percent
            # Pending, failed, and skipped tasks contribute 0
        
        self.overall_progress = min(100.0, weighted_progress)
    
    def _update_eta(self):
        """Update estimated time of completion."""
        if not self.start_time or not self.tasks:
            return
        
        now = datetime.now()
        elapsed_time = (now - self.start_time).total_seconds()
        
        # Calculate progress-based ETA
        if self.overall_progress > 0:
            estimated_total_time = elapsed_time * (100.0 / self.overall_progress)
            remaining_time = estimated_total_time - elapsed_time
            self.estimated_completion_time = now + timedelta(seconds=max(0, remaining_time))
        
        # Also calculate task-based ETA for comparison
        remaining_estimated_time = 0.0
        for task in self.tasks.values():
            if task.status == TaskStatus.PENDING:
                remaining_estimated_time += task.estimated_duration
            elif task.status == TaskStatus.RUNNING:
                remaining_progress = (100.0 - task.progress_percent) / 100.0
                remaining_estimated_time += task.estimated_duration * remaining_progress
        
        task_based_eta = now + timedelta(seconds=remaining_estimated_time)
        
        # Use the more conservative (later) estimate
        if task_based_eta > self.estimated_completion_time:
            self.estimated_completion_time = task_based_eta
    
    def _notify_progress_callbacks(self, task_name: str, progress: float, step: str):
        """Notify all progress callbacks."""
        for callback in self.progress_callbacks:
            try:
                callback(task_name, progress, step)
            except Exception as e:
                self.logger.error(f"Error in progress callback: {e}")
    
    def _notify_status_callbacks(self):
        """Notify all status callbacks."""
        status = self.get_status()
        for callback in self.status_callbacks:
            try:
                callback(status)
            except Exception as e:
                self.logger.error(f"Error in status callback: {e}")
    
    def get_status(self) -> Dict:
        """Get current installation status."""
        with self._lock:
            now = datetime.now()
            elapsed_time = (now - self.start_time).total_seconds() if self.start_time else 0
            
            # Calculate remaining time
            remaining_time = 0
            if self.estimated_completion_time and now < self.estimated_completion_time:
                remaining_time = (self.estimated_completion_time - now).total_seconds()
            
            # Get current task info
            current_task_info = None
            if self.current_task_id and self.current_task_id in self.tasks:
                current_task = self.tasks[self.current_task_id]
                current_task_info = {
                    'id': current_task.id,
                    'name': current_task.name,
                    'description': current_task.description,
                    'progress': current_task.progress_percent,
                    'current_step': current_task.current_step,
                    'status': current_task.status.value
                }
            
            # Get task summaries
            task_summaries = []
            for task_id in self.task_order:
                task = self.tasks[task_id]
                summary = {
                    'id': task.id,
                    'name': task.name,
                    'status': task.status.value,
                    'progress': task.progress_percent,
                    'error': task.error_message if task.error_message else None
                }
                task_summaries.append(summary)
            
            return {
                'overall_progress': self.overall_progress,
                'elapsed_time_seconds': elapsed_time,
                'remaining_time_seconds': remaining_time,
                'estimated_completion': self.estimated_completion_time.isoformat() if self.estimated_completion_time else None,
                'current_task': current_task_info,
                'tasks': task_summaries,
                'statistics': self.stats.copy(),
                'is_complete': self.is_installation_complete(),
                'has_errors': self.stats['failed_tasks'] > 0
            }
    
    def is_installation_complete(self) -> bool:
        """Check if the installation is complete."""
        with self._lock:
            if not self.tasks:
                return False
            
            for task in self.tasks.values():
                if task.status in [TaskStatus.PENDING, TaskStatus.RUNNING]:
                    return False
            
            return True
    
    def get_detailed_report(self) -> str:
        """Generate a detailed installation report."""
        with self._lock:
            report_lines = []
            
            report_lines.append("=== DRIVER INSTALLATION REPORT ===")
            report_lines.append(f"Start Time: {self.start_time.strftime('%Y-%m-%d %H:%M:%S') if self.start_time else 'Unknown'}")
            
            if self.is_installation_complete():
                total_time = max(task.end_time for task in self.tasks.values() if task.end_time) - self.start_time
                report_lines.append(f"Completion Time: {total_time}")
            else:
                report_lines.append(f"Current Progress: {self.overall_progress:.1f}%")
                if self.estimated_completion_time:
                    report_lines.append(f"Estimated Completion: {self.estimated_completion_time.strftime('%Y-%m-%d %H:%M:%S')}")
            
            report_lines.append("")
            
            # Statistics
            report_lines.append("📊 STATISTICS:")
            report_lines.append(f"  Total Tasks: {self.stats['total_tasks']}")
            report_lines.append(f"  Completed: {self.stats['completed_tasks']} ✅")
            report_lines.append(f"  Failed: {self.stats['failed_tasks']} ❌")
            report_lines.append(f"  Skipped: {self.stats['skipped_tasks']} ⏭️")
            
            success_rate = (self.stats['completed_tasks'] / max(1, self.stats['total_tasks'])) * 100
            report_lines.append(f"  Success Rate: {success_rate:.1f}%")
            report_lines.append("")
            
            # Task details
            report_lines.append("📋 TASK DETAILS:")
            for task_id in self.task_order:
                task = self.tasks[task_id]
                
                status_icon = {
                    TaskStatus.COMPLETED: "✅",
                    TaskStatus.FAILED: "❌",
                    TaskStatus.RUNNING: "🔄",
                    TaskStatus.PENDING: "⏳",
                    TaskStatus.SKIPPED: "⏭️"
                }.get(task.status, "❓")
                
                report_lines.append(f"  {status_icon} {task.name}")
                
                if task.status == TaskStatus.RUNNING:
                    report_lines.append(f"    Progress: {task.progress_percent:.1f}%")
                    if task.current_step:
                        report_lines.append(f"    Current Step: {task.current_step}")
                
                if task.status == TaskStatus.FAILED and task.error_message:
                    report_lines.append(f"    Error: {task.error_message}")
                
                if task.status == TaskStatus.SKIPPED and task.error_message:
                    report_lines.append(f"    Reason: {task.error_message}")
                
                if task.start_time and task.end_time:
                    duration = (task.end_time - task.start_time).total_seconds()
                    report_lines.append(f"    Duration: {duration:.1f}s (estimated: {task.estimated_duration:.1f}s)")
                
                # Subtasks
                if task.subtasks:
                    for subtask in task.subtasks:
                        subtask_icon = {
                            TaskStatus.COMPLETED: "  ✅",
                            TaskStatus.FAILED: "  ❌",
                            TaskStatus.RUNNING: "  🔄",
                            TaskStatus.PENDING: "  ⏳",
                            TaskStatus.SKIPPED: "  ⏭️"
                        }.get(subtask.status, "  ❓")
                        report_lines.append(f"    {subtask_icon} {subtask.name}")
                
                report_lines.append("")
            
            report_lines.append("=== END OF REPORT ===")
            
            return "\n".join(report_lines)
    
    def export_status_json(self) -> str:
        """Export current status as JSON."""
        status = self.get_status()
        return json.dumps(status, indent=2, default=str)
    
    def abort_installation(self, reason: str = "User requested"):
        """Abort the installation process."""
        with self._lock:
            self.logger.warning(f"Installation aborted: {reason}")
            
            # Mark running task as failed
            if self.current_task_id and self.current_task_id in self.tasks:
                current_task = self.tasks[self.current_task_id]
                if current_task.status == TaskStatus.RUNNING:
                    current_task.status = TaskStatus.FAILED
                    current_task.error_message = f"Aborted: {reason}"
                    current_task.end_time = datetime.now()
                    self.stats['failed_tasks'] += 1
            
            # Mark all pending tasks as skipped
            for task in self.tasks.values():
                if task.status == TaskStatus.PENDING:
                    task.status = TaskStatus.SKIPPED
                    task.error_message = reason
                    task.end_time = datetime.now()
                    self.stats['skipped_tasks'] += 1
            
            self.current_task_id = None
            self._notify_status_callbacks()
    
    def retry_failed_tasks(self) -> List[str]:
        """Reset failed tasks to pending status for retry."""
        with self._lock:
            retried_tasks = []
            
            for task in self.tasks.values():
                if task.status == TaskStatus.FAILED:
                    task.status = TaskStatus.PENDING
                    task.progress_percent = 0.0
                    task.current_step = ""
                    task.error_message = ""
                    task.start_time = None
                    task.end_time = None
                    
                    retried_tasks.append(task.id)
                    self.stats['failed_tasks'] -= 1
            
            self.logger.info(f"Reset {len(retried_tasks)} failed tasks for retry")
            self._notify_status_callbacks()
            
            return retried_tasks
