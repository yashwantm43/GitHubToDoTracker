# Git-Based To-Do Tracker

A simple shell-based to-do tracker that integrates seamlessly with GitHub.  
Built as part of the **Open Source Technologies** course project.

---

## Features
- Add, delete, and mark tasks as done ✅  
- Sort by **priority** or **status**  
- Search/filter tasks by keyword or priority  
- Auto-commit progress to GitHub  
- Colored terminal output  
- Daily summary of total / done / pending  
- Backup & CSV export support

---

## Usage
```bash
./todo.sh add "Finish assignment" high
./todo.sh list --sort priority
./todo.sh done 1
./todo.sh search report
./todo.sh list --done
./todo.sh backup
./todo.sh export csv
```
---

## Project Structure
```
todo.sh           → main script  
tasks.txt         → task data  
logs/             → activity logs  
backups/          → automatic backups
```

## Author
Yashwant M.
B. Tech Mechanical
23070125043


