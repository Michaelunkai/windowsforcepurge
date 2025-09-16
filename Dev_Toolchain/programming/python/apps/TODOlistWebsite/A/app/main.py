from fastapi import FastAPI, Depends, HTTPException, Request, Form, File, UploadFile, Query
from fastapi.responses import HTMLResponse, RedirectResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_
from datetime import datetime, timedelta
import os
import shutil
import uuid
from typing import List, Optional
import uvicorn

from .database import get_db, init_db, SessionLocal, User, Project, Task, Note, Folder, Label, TaskLabel, Attachment

# Initialize FastAPI app
app = FastAPI(title="TodoNotes", description="Beautiful Task and Note Management", version="1.0.0")

# Create directories
os.makedirs("app/static/css", exist_ok=True)
os.makedirs("app/static/js", exist_ok=True)
os.makedirs("app/static/uploads", exist_ok=True)
os.makedirs("app/templates", exist_ok=True)

# Mount static files
app.mount("/static", StaticFiles(directory="app/static"), name="static")

# Templates
templates = Jinja2Templates(directory="app/templates")

# Initialize database
init_db()

# Create default user and sample data
def create_sample_data():
    db = SessionLocal()
    try:
        # Check if user exists
        user = db.query(User).filter(User.username == "demo").first()
        if not user:
            user = User(username="demo", email="demo@example.com", hashed_password="demo123")
            db.add(user)
            db.commit()
            db.refresh(user)
            
            # Create sample projects
            work_project = Project(name="Work", description="Work related tasks", color="#e74c3c", owner_id=user.id)
            personal_project = Project(name="Personal", description="Personal tasks", color="#2ecc71", owner_id=user.id)
            db.add(work_project)
            db.add(personal_project)
            db.commit()
            
            # Create sample tasks
            tasks = [
                Task(title="Complete project proposal", description="Finish the Q4 project proposal", priority=3, owner_id=user.id, project_id=work_project.id),
                Task(title="Review team presentations", description="Review and provide feedback", priority=2, owner_id=user.id, project_id=work_project.id),
                Task(title="Plan weekend trip", description="Research destinations and book hotels", priority=1, owner_id=user.id, project_id=personal_project.id),
                Task(title="Buy groceries", description="Weekly grocery shopping", priority=2, owner_id=user.id, project_id=personal_project.id),
            ]
            db.add_all(tasks)
            db.commit()
            
            # Create sample folders and notes
            work_folder = Folder(name="Work Notes", color="#3498db", owner_id=user.id)
            personal_folder = Folder(name="Personal Notes", color="#9b59b6", owner_id=user.id)
            db.add(work_folder)
            db.add(personal_folder)
            db.commit()
            
            notes = [
                Note(title="Meeting Notes - Q4 Planning", content="<h2>Q4 Planning Meeting</h2><p>Key points discussed:</p><ul><li>Budget allocation</li><li>Team assignments</li><li>Timeline review</li></ul>", owner_id=user.id, folder_id=work_folder.id),
                Note(title="Project Ideas", content="<h2>New Project Ideas</h2><p>Some innovative ideas for next quarter:</p><ol><li>Mobile app development</li><li>AI integration</li><li>User experience improvements</li></ol>", owner_id=user.id, folder_id=work_folder.id),
                Note(title="Recipe Collection", content="<h2>Favorite Recipes</h2><p><strong>Pasta Carbonara:</strong></p><p>Ingredients: pasta, eggs, cheese, bacon...</p>", owner_id=user.id, folder_id=personal_folder.id),
            ]
            db.add_all(notes)
            db.commit()
            
    finally:
        db.close()

create_sample_data()

# Routes
@app.get("/", response_class=HTMLResponse)
async def dashboard(request: Request, db: Session = Depends(get_db)):
    # Get current user (demo user for now)
    user = db.query(User).filter(User.username == "demo").first()
    
    # Get recent tasks
    recent_tasks = db.query(Task).filter(Task.owner_id == user.id).order_by(Task.created_at.desc()).limit(5).all()
    
    # Get recent notes
    recent_notes = db.query(Note).filter(Note.owner_id == user.id).order_by(Note.updated_at.desc()).limit(5).all()
    
    # Get projects
    projects = db.query(Project).filter(Project.owner_id == user.id).all()
    
    # Get task statistics
    total_tasks = db.query(Task).filter(Task.owner_id == user.id).count()
    completed_tasks = db.query(Task).filter(Task.owner_id == user.id, Task.completed == True).count()
    
    return templates.TemplateResponse("dashboard.html", {
        "request": request,
        "user": user,
        "recent_tasks": recent_tasks,
        "recent_notes": recent_notes,
        "projects": projects,
        "total_tasks": total_tasks,
        "completed_tasks": completed_tasks
    })

@app.get("/tasks", response_class=HTMLResponse)
async def tasks_page(request: Request, project_id: Optional[int] = None, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == "demo").first()
    
    # Get tasks
    query = db.query(Task).filter(Task.owner_id == user.id)
    if project_id:
        query = query.filter(Task.project_id == project_id)
    
    tasks = query.order_by(Task.created_at.desc()).all()
    projects = db.query(Project).filter(Project.owner_id == user.id).all()
    
    return templates.TemplateResponse("tasks.html", {
        "request": request,
        "tasks": tasks,
        "projects": projects,
        "selected_project_id": project_id
    })

@app.post("/tasks/create")
async def create_task(
    title: str = Form(...),
    description: str = Form(""),
    priority: int = Form(1),
    project_id: Optional[int] = Form(None),
    due_date: Optional[str] = Form(None),
    db: Session = Depends(get_db)
):
    user = db.query(User).filter(User.username == "demo").first()
    
    # Parse due date if provided
    parsed_due_date = None
    if due_date:
        try:
            parsed_due_date = datetime.strptime(due_date, "%Y-%m-%d")
        except:
            pass
    
    new_task = Task(
        title=title,
        description=description,
        priority=priority,
        project_id=project_id,
        due_date=parsed_due_date,
        owner_id=user.id
    )
    
    db.add(new_task)
    db.commit()
    
    return RedirectResponse(url="/tasks", status_code=303)

@app.post("/tasks/{task_id}/toggle")
async def toggle_task(task_id: int, db: Session = Depends(get_db)):
    task = db.query(Task).filter(Task.id == task_id).first()
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    task.completed = not task.completed
    if task.completed:
        task.completed_at = datetime.utcnow()
    else:
        task.completed_at = None
    
    db.commit()
    return {"status": "success", "completed": task.completed}

@app.delete("/tasks/{task_id}")
async def delete_task(task_id: int, db: Session = Depends(get_db)):
    task = db.query(Task).filter(Task.id == task_id).first()
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    db.delete(task)
    db.commit()
    return {"status": "success"}

@app.get("/notes", response_class=HTMLResponse)
async def notes_page(request: Request, folder_id: Optional[int] = None, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == "demo").first()
    
    # Get notes
    query = db.query(Note).filter(Note.owner_id == user.id)
    if folder_id:
        query = query.filter(Note.folder_id == folder_id)
    
    notes = query.order_by(Note.updated_at.desc()).all()
    folders = db.query(Folder).filter(Folder.owner_id == user.id).all()
    
    return templates.TemplateResponse("notes.html", {
        "request": request,
        "notes": notes,
        "folders": folders,
        "selected_folder_id": folder_id
    })

@app.get("/notes/create", response_class=HTMLResponse)
async def create_note_page(request: Request, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == "demo").first()
    folders = db.query(Folder).filter(Folder.owner_id == user.id).all()
    
    return templates.TemplateResponse("note_editor.html", {
        "request": request,
        "folders": folders,
        "note": None
    })

@app.get("/notes/{note_id}/edit", response_class=HTMLResponse)
async def edit_note_page(request: Request, note_id: int, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == "demo").first()
    note = db.query(Note).filter(Note.id == note_id, Note.owner_id == user.id).first()
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    
    folders = db.query(Folder).filter(Folder.owner_id == user.id).all()
    
    return templates.TemplateResponse("note_editor.html", {
        "request": request,
        "folders": folders,
        "note": note
    })

@app.post("/notes/save")
async def save_note(
    title: str = Form(...),
    content: str = Form(...),
    folder_id: Optional[int] = Form(None),
    note_id: Optional[int] = Form(None),
    db: Session = Depends(get_db)
):
    user = db.query(User).filter(User.username == "demo").first()
    
    if note_id:
        # Update existing note
        note = db.query(Note).filter(Note.id == note_id, Note.owner_id == user.id).first()
        if not note:
            raise HTTPException(status_code=404, detail="Note not found")
        
        note.title = title
        note.content = content
        note.folder_id = folder_id
        note.updated_at = datetime.utcnow()
    else:
        # Create new note
        note = Note(
            title=title,
            content=content,
            folder_id=folder_id,
            owner_id=user.id
        )
        db.add(note)
    
    db.commit()
    return RedirectResponse(url="/notes", status_code=303)

@app.delete("/notes/{note_id}")
async def delete_note(note_id: int, db: Session = Depends(get_db)):
    note = db.query(Note).filter(Note.id == note_id).first()
    if not note:
        raise HTTPException(status_code=404, detail="Note not found")
    
    db.delete(note)
    db.commit()
    return {"status": "success"}

@app.post("/upload")
async def upload_file(file: UploadFile = File(...)):
    # Create unique filename
    file_extension = os.path.splitext(file.filename)[1]
    unique_filename = f"{uuid.uuid4()}{file_extension}"
    file_path = f"app/static/uploads/{unique_filename}"
    
    # Save file
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    
    return {"filename": unique_filename, "url": f"/static/uploads/{unique_filename}"}

@app.post("/folders/create")
async def create_folder(
    name: str = Form(...),
    color: str = Form("#9b59b6"),
    db: Session = Depends(get_db)
):
    user = db.query(User).filter(User.username == "demo").first()
    
    new_folder = Folder(
        name=name,
        color=color,
        owner_id=user.id
    )
    
    db.add(new_folder)
    db.commit()
    
    return RedirectResponse(url="/notes", status_code=303)

# Project Management Endpoints
@app.post("/projects/create")
async def create_project(
    name: str = Form(...),
    description: str = Form(""),
    color: str = Form("#3498db"),
    db: Session = Depends(get_db)
):
    user = db.query(User).filter(User.username == "demo").first()
    
    new_project = Project(
        name=name,
        description=description,
        color=color,
        owner_id=user.id
    )
    
    db.add(new_project)
    db.commit()
    
    return RedirectResponse(url="/", status_code=303)

@app.post("/projects/{project_id}/edit")
async def edit_project(
    project_id: int,
    name: str = Form(...),
    description: str = Form(""),
    color: str = Form("#3498db"),
    db: Session = Depends(get_db)
):
    user = db.query(User).filter(User.username == "demo").first()
    project = db.query(Project).filter(Project.id == project_id, Project.owner_id == user.id).first()
    
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    
    project.name = name
    project.description = description
    project.color = color
    
    db.commit()
    
    return RedirectResponse(url="/", status_code=303)

@app.delete("/projects/{project_id}")
async def delete_project(project_id: int, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == "demo").first()
    project = db.query(Project).filter(Project.id == project_id, Project.owner_id == user.id).first()
    
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    
    # Update tasks to remove project association
    db.query(Task).filter(Task.project_id == project_id).update({"project_id": None})
    
    db.delete(project)
    db.commit()
    
    return {"success": True}

@app.get("/projects/{project_id}")
async def get_project(project_id: int, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == "demo").first()
    project = db.query(Project).filter(Project.id == project_id, Project.owner_id == user.id).first()
    
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    
    return {
        "id": project.id,
        "name": project.name,
        "description": project.description,
        "color": project.color
    }

@app.get("/search")
async def search(q: str = Query(...), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == "demo").first()
    
    # Search tasks
    tasks = db.query(Task).filter(
        Task.owner_id == user.id,
        or_(
            Task.title.contains(q),
            Task.description.contains(q)
        )
    ).limit(10).all()
    
    # Search notes
    notes = db.query(Note).filter(
        Note.owner_id == user.id,
        or_(
            Note.title.contains(q),
            Note.content.contains(q)
        )
    ).limit(10).all()
    
    return {
        "tasks": [{"id": t.id, "title": t.title, "type": "task"} for t in tasks],
        "notes": [{"id": n.id, "title": n.title, "type": "note"} for n in notes]
    }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)