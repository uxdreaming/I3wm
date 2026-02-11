#!/bin/bash
# i3wm-config backup script (copy-based, no deletions)

REPO_DIR="$HOME/claude/auto-backups/i3wm-config"
LOG_FILE="$REPO_DIR/backup.log"

# Timestamp
echo "=== Backup $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$LOG_FILE"

# Create dirs if needed
mkdir -p "$REPO_DIR/nitrogen" "$REPO_DIR/wallpapers" "$REPO_DIR/autotiling" \
         "$REPO_DIR/polybar" "$REPO_DIR/gtk-3.0" "$REPO_DIR/gtksourceview-4/styles"

# Copy configs (overwrites existing, keeps deleted files in repo)
cp -r ~/.config/i3/* "$REPO_DIR/i3/" 2>/dev/null
cp -r ~/.config/alacritty/* "$REPO_DIR/alacritty/" 2>/dev/null
cp -r ~/.config/picom/* "$REPO_DIR/picom/" 2>/dev/null
cp -r ~/.config/dunst/* "$REPO_DIR/dunst/" 2>/dev/null
cp -r ~/.config/rofi/* "$REPO_DIR/rofi/" 2>/dev/null
cp -r ~/.config/nitrogen/* "$REPO_DIR/nitrogen/" 2>/dev/null
cp -r ~/.config/polybar/* "$REPO_DIR/polybar/" 2>/dev/null
cp -r ~/.config/autotiling/autotiling/* "$REPO_DIR/autotiling/" 2>/dev/null
cp -r ~/.config/gtk-3.0/* "$REPO_DIR/gtk-3.0/" 2>/dev/null
cp -r ~/.local/share/gtksourceview-4/styles/* "$REPO_DIR/gtksourceview-4/styles/" 2>/dev/null
cp -r ~/downloads/walls/* "$REPO_DIR/wallpapers/" 2>/dev/null
cp ~/.bashrc "$REPO_DIR/.bashrc" 2>/dev/null
cp ~/.gtkrc-2.0 "$REPO_DIR/.gtkrc-2.0" 2>/dev/null
cp ~/.profile "$REPO_DIR/.profile" 2>/dev/null

cd "$REPO_DIR"

# Check for changes
if [[ -n $(git status --porcelain) ]]; then
    git add -A
    git commit -m "Auto backup $(date '+%Y-%m-%d %H:%M')

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
    git push origin master
    echo "Backup completed with changes" >> "$LOG_FILE"
else
    echo "No changes detected" >> "$LOG_FILE"
fi
