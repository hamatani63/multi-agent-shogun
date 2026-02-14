#!/bin/bash
# inbox_write.sh — メールボックスへのメッセージ書き込み（排他ロック付き）
# Usage: bash scripts/inbox_write.sh <target_agent> <content> [type] [from]
# Example: bash scripts/inbox_write.sh karo "足軽5号、任務完了" report_received ashigaru5

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="$1"
CONTENT="$2"
TYPE="${3:-wake_up}"
FROM="${4:-unknown}"

INBOX="$SCRIPT_DIR/queue/inbox/${TARGET}.yaml"
LOCKFILE="${INBOX}.lock"

# Validate arguments
if [ -z "$TARGET" ] || [ -z "$CONTENT" ]; then
    echo "Usage: inbox_write.sh <target_agent> <content> [type] [from]" >&2
    exit 1
fi

# Initialize inbox if not exists
if [ ! -f "$INBOX" ]; then
    mkdir -p "$(dirname "$INBOX")"
    echo "messages: []" > "$INBOX"
fi

# Generate unique message ID (timestamp-based)
MSG_ID="msg_$(date +%Y%m%d_%H%M%S)_$(head -c 4 /dev/urandom | xxd -p)"
TIMESTAMP=$(date "+%Y-%m-%dT%H:%M:%S")

# Atomic write (3 retries handled inside python or via shell loop)
attempt=0
max_attempts=3

while [ $attempt -lt $max_attempts ]; do
    if python3 -c "
import json, sys, fcntl, os, tempfile

INBOX = '$INBOX'
LOCKFILE = '$LOCKFILE'

def write_msg():
    try:
        # Acquire lock
        lock_fd = open(LOCKFILE, 'w')
        try:
            fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except (BlockingIOError, IOError):
            sys.exit(75) # EX_TEMPFAIL

        # Read existing content
        lines = []
        if os.path.exists(INBOX):
            with open(INBOX, 'r') as f:
                lines = f.readlines()
        
        # Simple parser/appender
        if not lines or not any(l.strip().startswith('messages:') for l in lines):
            lines = ['messages:\n']
        
        # Prepare new message as JSON (valid YAML)
        new_msg_data = {
            'id': '$MSG_ID',
            'from': '$FROM',
            'timestamp': '$TIMESTAMP',
            'type': '$TYPE',
            'content': '''$CONTENT''',
            'read': False
        }
        # Indent and add as YAML list item
        new_msg_json = json.dumps(new_msg_data, ensure_ascii=False)
        lines.append(f'  - {new_msg_json}\n')

        # Overflow protection: keep max 50 messages
        # (Simplified: just keep last 50 lines if it gets too big, 
        # but let's just append for now as it's safer than a buggy parser)
        
        # Atomic write: tmp file + rename
        tmp_fd, tmp_path = tempfile.mkstemp(dir=os.path.dirname(INBOX), suffix='.tmp')
        try:
            with os.fdopen(tmp_fd, 'w') as f:
                f.writelines(lines)
            os.replace(tmp_path, INBOX)
        except:
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)
            raise
        finally:
            fcntl.flock(lock_fd, fcntl.LOCK_UN)
            lock_fd.close()

    except Exception as e:
        print(f'ERROR: {e}', file=sys.stderr)
        sys.exit(1)

write_msg()
"; then
        # Success
        exit 0
    else
        EXIT_CODE=$?
        if [ $EXIT_CODE -eq 75 ]; then
            # Lock timeout
            attempt=$((attempt + 1))
            if [ $attempt -lt $max_attempts ]; then
                echo "[inbox_write] Lock busy for $INBOX (attempt $attempt/$max_attempts), retrying..." >&2
                sleep 1
            else
                echo "[inbox_write] Failed to acquire lock after $max_attempts attempts for $INBOX" >&2
                exit 1
            fi
        else
            # Other error
            exit 1
        fi
    fi
done
