#!/bin/bash
# SPDX-License-Identifier: BSD-3-Clause
#
# Script to create a desktop shortcut for Cursor with workaround flags
# This creates a .desktop file in ~/.local/share/applications/

# Create applications directory if it doesn't exist
mkdir -p ~/.local/share/applications

# Desktop file path
DESKTOP_FILE="$HOME/.local/share/applications/cursor-workaround.desktop"

# Check if the shortcut already exists and remove it
echo "Checking for existing 'Start Cursor' shortcut..."

FOUND_EXISTING=false

# Check for the specific desktop file
if [ -f "$DESKTOP_FILE" ]; then
    echo "  Found existing desktop file: $DESKTOP_FILE"
    FOUND_EXISTING=true
fi

# Also check for any other desktop files with "Start Cursor" name
for desktop_file in ~/.local/share/applications/*.desktop; do
    if [ -f "$desktop_file" ] && grep -q "^Name=Start Cursor" "$desktop_file" 2>/dev/null; then
        if [ "$desktop_file" != "$DESKTOP_FILE" ]; then
            echo "  Found existing 'Start Cursor' shortcut: $desktop_file"
            rm -f "$desktop_file"
            FOUND_EXISTING=true
        fi
    fi
done

# Remove the main desktop file if it exists
if [ -f "$DESKTOP_FILE" ]; then
    echo "  Removing existing desktop shortcut: $DESKTOP_FILE"
    rm -f "$DESKTOP_FILE"
    FOUND_EXISTING=true
fi

# Update desktop database after removal if we found and removed anything
if [ "$FOUND_EXISTING" = true ]; then
    echo "  Existing shortcut(s) removed."
    if command -v update-desktop-database >/dev/null 2>&1; then
        echo "  Updating desktop database..."
        update-desktop-database ~/.local/share/applications 2>/dev/null || true
    fi
    echo ""
else
    echo "  No existing shortcut found."
    echo ""
fi

# Find cursor binary
CURSOR_BIN=""
if [ -f "/usr/share/cursor/bin/cursor" ]; then
    CURSOR_BIN="/usr/share/cursor/bin/cursor"
elif command -v cursor >/dev/null 2>&1; then
    CURSOR_BIN="$(command -v cursor)"
else
    echo "Error: Cursor binary not found."
    echo "Checked: /usr/share/cursor/bin/cursor"
    echo "Checked: cursor command in PATH"
    echo "Please ensure Cursor is installed."
    exit 1
fi

echo "Found Cursor at: $CURSOR_BIN"

# Create the desktop file
cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Start Cursor
Name[en_US]=Start Cursor
Comment=Code editor with workaround flags
Comment[en_US]=Code editor with workaround flags
Exec=env DONT_PROMPT_WSL_INSTALL=1 $CURSOR_BIN --no-sandbox --disable-gpu --disable-dev-shm-usage --ozone-platform=x11 %F
Icon=co.anysphere.cursor
Terminal=false
Categories=Development;TextEditor;
MimeType=text/plain;inode/directory;
StartupNotify=true
StartupWMClass=cursor
EOF

# Desktop files don't need to be executable, but ensure proper permissions
chmod 644 "$DESKTOP_FILE"

# Validate desktop file (if desktop-file-validate is available)
if command -v desktop-file-validate >/dev/null 2>&1; then
    echo "Validating desktop file..."
    if desktop-file-validate "$DESKTOP_FILE" >/dev/null 2>&1; then
        echo "Desktop file validation: OK"
    else
        echo "Warning: Desktop file validation found issues:"
        desktop-file-validate "$DESKTOP_FILE" 2>&1 || true
        echo "Continuing anyway..."
    fi
else
    echo "Note: desktop-file-validate not found. Desktop file created but not validated."
fi

# Update desktop database (if available)
if command -v update-desktop-database >/dev/null 2>&1; then
    echo "Updating desktop database..."
    update-desktop-database ~/.local/share/applications 2>/dev/null || true
else
    echo "Note: update-desktop-database not found. Installing desktop-file-utils may help."
    echo "You can install it with: sudo apt-get install desktop-file-utils"
fi

# Verify the file was created
if [ ! -f "$DESKTOP_FILE" ]; then
    echo "Error: Desktop file was not created!"
    exit 1
fi

# Verify the Exec line contains the expected command
if ! grep -q "DONT_PROMPT_WSL_INSTALL=1" "$DESKTOP_FILE"; then
    echo "Warning: DONT_PROMPT_WSL_INSTALL environment variable not found in desktop file!"
fi

if ! grep -q "Start Cursor" "$DESKTOP_FILE"; then
    echo "Warning: Name 'Start Cursor' not found in desktop file!"
fi

echo ""
echo "Desktop shortcut created successfully at: $DESKTOP_FILE"
echo ""
echo "File permissions: $(ls -l "$DESKTOP_FILE" | awk '{print $1, $3, $4}')"
echo ""
echo "Contents of desktop file:"
echo "---"
cat "$DESKTOP_FILE"
echo "---"
echo ""
echo "The shortcut should appear in your XFCE4 application menu."
echo ""
echo "To refresh the menu, try one of these methods:"
echo ""
echo "Method 1: The menu should refresh automatically when you open it"
echo ""
echo "Method 2: Log out and log back in to your desktop session"
echo ""
echo "Method 3: Restart panel manually (if needed):"
echo "  xfce4-panel -r"
echo "  (If that fails with D-Bus error, use: killall xfce4-panel && xfce4-panel &)"
echo ""
echo "Note: The script does NOT automatically restart the panel to avoid"
echo "      accidentally removing it. Use the methods above if needed."
echo ""
echo "To test the shortcut manually, you can run:"
echo "  $CURSOR_BIN --no-sandbox --disable-gpu --disable-dev-shm-usage --ozone-platform=x11"
