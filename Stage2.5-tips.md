# 🛠️ Stage 2.5 - Quick Fix Tips & Tmux Guide

## 🚀 Quick Fix Solution

Simply go into tmux and rerun Yin's script that'll fix the issue.

```bash
wget -O setup.sh https://gist.githubusercontent.com/0xCRASHOUT/6656b9418018c3657e612c34ae1546fd/raw/setup.sh
sudo bash setup.sh
```

Press `Ctrl+B` then `D` to exit tmux.

Check your node:
```bash
docker ps
```

### ✅ How to Verify Node is Running Correctly

When you run `docker ps`, look for these **COMMAND** entries:
- `moongate-server`
- `/app/spn-node prove...`

  ![image](https://github.com/user-attachments/assets/a6d03877-2a52-4014-b999-7322502065bc)


If you see these commands, **your node is running correctly!** You can safely exit tmux.

**Note: Don't press Ctrl+C to stop the running log.**

---

## 📘 Tmux Complete Usage Guide

### What is Tmux?
Tmux (Terminal Multiplexer) allows you to run multiple terminal sessions within a single window, and keep processes running even when you disconnect from the server.

### 🔧 Basic Tmux Commands

#### Installing Tmux
```bash
# Ubuntu/Debian
sudo apt update && sudo apt install tmux

# CentOS/RHEL
sudo yum install tmux
```

#### Starting & Managing Sessions
```bash
# Start a new tmux session
tmux

# Start a new session with a name
tmux new-session -s prover

# List all sessions
tmux list-sessions
# or
tmux ls

# Attach to a session
tmux attach-session -t prover
# or
tmux a -t prover

# Kill a session
tmux kill-session -t prover
```

### ⌨️ Essential Tmux Keyboard Shortcuts

**Default Prefix Key: `Ctrl+B`**

| Action | Shortcut | Description |
|--------|----------|-------------|
| **Session Management** |
| Detach from session | `Ctrl+B` → `D` | Exit tmux but keep session running |
| List sessions | `Ctrl+B` → `S` | Show all sessions |
| Rename session | `Ctrl+B` → `$` | Give session a custom name |
| **Window Management** |
| Create new window | `Ctrl+B` → `C` | Open new window in session |
| Switch to next window | `Ctrl+B` → `N` | Move to next window |
| Switch to previous window | `Ctrl+B` → `P` | Move to previous window |
| List all windows | `Ctrl+B` → `W` | Show window picker |
| Close current window | `Ctrl+B` → `&` | Close current window |
| **Pane Management** |
| Split horizontally | `Ctrl+B` → `%` | Split pane left/right |
| Split vertically | `Ctrl+B` → `"` | Split pane top/bottom |
| Switch between panes | `Ctrl+B` → Arrow Keys | Navigate panes |
| Close current pane | `Ctrl+B` → `X` | Close active pane |
| **Useful Commands** |
| Show time | `Ctrl+B` → `T` | Display clock |
| Help | `Ctrl+B` → `?` | Show all shortcuts |

### 🎯 Succinct Prover Workflow with Tmux

#### Step 1: Create Named Session
```bash
# Create a session specifically for prover
tmux new-session -s succinct-prover
```

#### Step 2: Run Setup Script
```bash
# Inside tmux session
wget -O setup.sh https://gist.githubusercontent.com/0xCRASHOUT/6656b9418018c3657e612c34ae1546fd/raw/setup.sh
sudo bash setup.sh
```

#### Step 3: Detach Safely
```bash
# Press Ctrl+B then D (not Ctrl+C!)
# This keeps the prover running in background
```

#### Step 4: Monitor from Outside
```bash
# Check if container is running
docker ps

# Look for these COMMAND entries to confirm success:
# - moongate-server
# - /app/spn-node prove...

# View container logs
docker logs <container-name>

# Reattach to see live logs
tmux attach-session -t succinct-prover
```

### 🔍 Advanced Tmux Tips

#### Custom Configuration (~/.tmux.conf)
```bash
# Create config file
nano ~/.tmux.conf

# Add these useful settings:
# Enable mouse support
set -g mouse on

# Change prefix key to Ctrl+A (easier to reach)
unbind C-b
set -g prefix C-a
bind C-a send-prefix

# Start window numbering at 1
set -g base-index 1

# Reload config
bind r source-file ~/.tmux.conf \; display-message "Config reloaded!"
```

#### Useful Session Management
```bash
# Create multiple windows for monitoring
tmux new-session -d -s monitoring
tmux new-window -n 'docker-logs' 'docker logs -f container-name'
tmux new-window -n 'system-monitor' 'htop'
tmux new-window -n 'gpu-monitor' 'watch -n 1 nvidia-smi'
```

### 🚨 Common Tmux Mistakes & Solutions

#### ❌ Wrong: Pressing Ctrl+C
```bash
# This will STOP your prover process!
# DON'T DO THIS when you want to exit
```

#### ✅ Correct: Detaching with Ctrl+B → D
```bash
# This keeps your prover running safely
# You can reconnect anytime
```

#### ❌ Wrong: Closing Terminal Window
```bash
# This might kill your session
# Always detach properly first
```

#### ✅ Correct: Proper Exit Sequence
```bash
# 1. Detach from tmux: Ctrl+B → D
# 2. Check session still exists: tmux ls
# 3. Then close terminal window
```

### 📊 Monitoring Your Prover in Tmux

#### Window Setup for Complete Monitoring
```bash
# Start main session
tmux new-session -d -s prover-monitor

# Window 1: Prover logs
tmux rename-window 'prover'
# Run your prover script here

# Window 2: Docker monitoring  
tmux new-window -n 'docker'
tmux send-keys 'watch -n 5 docker ps' Enter

# Window 3: System resources
tmux new-window -n 'system'
tmux send-keys 'htop' Enter

# Window 4: GPU monitoring
tmux new-window -n 'gpu'
tmux send-keys 'watch -n 2 nvidia-smi' Enter

# Window 5: Network monitoring
tmux new-window -n 'network'
tmux send-keys 'nethogs' Enter
```

### 🎬 Quick Reference Card

```
┌─ TMUX QUICK REFERENCE ─────────────────────────┐
│                                                │
│ START:     tmux new -s prover                  │
│ DETACH:    Ctrl+B → D                          │
│ ATTACH:    tmux a -t prover                    │
│ LIST:      tmux ls                             │
│                                                │
│ NEW WINDOW:    Ctrl+B → C                      │
│ NEXT WINDOW:   Ctrl+B → N                      │
│ SPLIT HORIZ:   Ctrl+B → %                      │
│ SPLIT VERT:    Ctrl+B → "                      │
│                                                │
│ ⚠️  NEVER use Ctrl+C to exit tmux!            │
│ ✅  Always use Ctrl+B → D to detach           │
│                                                │
└────────────────────────────────────────────────┘
```

### 🛡️ Prover Safety Checklist

- [ ] ✅ Started tmux session with descriptive name
- [ ] ✅ Prover script running successfully  
- [ ] ✅ Detached using `Ctrl+B → D` (not Ctrl+C)
- [ ] ✅ Verified session exists with `tmux ls`
- [ ] ✅ Container running with `docker ps`
- [ ] ✅ **Confirmed correct COMMAND**: `moongate-server` and `/app/spn-node prove...`
- [ ] ✅ Can reattach anytime with `tmux a -t session-name`

---

**💡 Pro Tip**: Keep your prover running 24/7 by always using tmux. This ensures maximum uptime and earnings potential!

**🔗 Need Help?** 
- Tmux official docs: https://github.com/tmux/tmux/wiki
- Quick tmux tutorial: https://www.hamvocke.com/blog/a-quick-and-easy-guide-to-tmux/
