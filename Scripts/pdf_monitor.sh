#!/bin/bash
#
# PandyDoc PDF Monitor
# Watches the incoming directory for new PDFs and notifies the app
#

INCOMING_DIR="$HOME/Library/Application Support/PandyDoc/Incoming"
PROCESSED_DIR="$HOME/Library/Application Support/PandyDoc/Processed"

mkdir -p "$INCOMING_DIR" "$PROCESSED_DIR"

echo "Monitoring $INCOMING_DIR for new PDFs..."
echo "Press Ctrl+C to stop"

while true; do
    for file in "$INCOMING_DIR"/*.pdf; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            echo "Found new PDF: $filename"
            
            # Move to processed directory
            mv "$file" "$PROCESSED_DIR/"
            
            # Notify PandyDoc if running
            if pgrep -x "PandyDoc" > /dev/null; then
                osascript -e '
                    tell application "PandyDoc"
                        activate
                    end tell
                ' 2>/dev/null
            fi
            
            echo "Processed: $filename"
        fi
    done
    
    sleep 2
done
