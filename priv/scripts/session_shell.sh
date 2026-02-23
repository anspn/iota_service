#!/bin/bash
# =============================================================================
# IOTA Service — TTY Session Recording Shell
# =============================================================================
#
# Entrypoint for the ttyd container. Spawns an interactive bash shell with
# automatic command-history capture.
#
# Flow:
#   1. Check /data/sessions/pending/ for a pending session created by the
#      Elixir app (contains session_id and DID).
#   2. Create a session directory under /data/sessions/<session_id>/.
#   3. Configure bash to flush every command to the session history file.
#   4. On exit (trap), write a completion marker so the Elixir app can
#      detect that the session has ended and trigger notarization.
# =============================================================================

SESSIONS_DIR="${SESSIONS_DIR:-/data/sessions}"
PENDING_DIR="${SESSIONS_DIR}/pending"

# Ensure directories are writable by all containers on the shared Docker volume.
# The ttyd container runs as root; the Elixir app container runs as non-root "iota".
mkdir -p "$PENDING_DIR"
chmod 777 "$SESSIONS_DIR" "$PENDING_DIR" 2>/dev/null || true

# --- Consume pending session ------------------------------------------------
SESSION_ID=""
DID=""

# Look for the newest pending session file
if [ -d "$PENDING_DIR" ]; then
  PENDING_FILE=$(ls -t "$PENDING_DIR"/*.session 2>/dev/null | head -1)

  if [ -n "$PENDING_FILE" ] && [ -f "$PENDING_FILE" ]; then
    # File format: line 1 = session_id, line 2 = DID
    SESSION_ID=$(sed -n '1p' "$PENDING_FILE")
    DID=$(sed -n '2p' "$PENDING_FILE")
    rm -f "$PENDING_FILE"
  fi
fi

# Fallback: generate a UUID if no pending session was claimed
if [ -z "$SESSION_ID" ]; then
  SESSION_ID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "s_$(date +%s%N)")
fi

SESSION_DIR="${SESSIONS_DIR}/${SESSION_ID}"
mkdir -p "$SESSION_DIR"
chmod 755 "$SESSION_DIR"

# Pre-create the history file with world-readable permissions.
# Bash normally creates HISTFILE with mode 600 (owner-only), which would
# prevent the Elixir app (non-root) from reading it.
touch "$SESSION_DIR/history"
chmod 666 "$SESSION_DIR/history"

# --- Write session metadata -------------------------------------------------
cat > "$SESSION_DIR/meta.json" << METAEOF
{
  "session_id": "${SESSION_ID}",
  "did": "${DID}",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "pid": $$
}
METAEOF

# Write a pointer so the app can quickly find the current session
echo "$SESSION_ID" > "${SESSIONS_DIR}/current"
chmod 644 "${SESSIONS_DIR}/current" 2>/dev/null

# --- Diagnostic logging (helps debug pending‑file handoff) -------------------
LOG="$SESSION_DIR/shell.log"
{
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] session_shell.sh started"
  echo "  Session ID  : $SESSION_ID"
  echo "  DID         : ${DID:-<none>}"
  echo "  Pending file: ${PENDING_FILE:-<not found>}"
  echo "  Session dir : $SESSION_DIR"
  echo "  History file: $SESSION_DIR/history"
  echo "  Shell PID   : $$"
  echo "  UID/GID     : $(id)"
  echo "--- directory listing ---"
  ls -la "$SESSION_DIR/" 2>/dev/null
  echo "--- pending dir ---"
  ls -la "$PENDING_DIR/" 2>/dev/null || echo "  (not accessible)"
} >> "$LOG" 2>&1
chmod 644 "$LOG" 2>/dev/null

# --- Build a bashrc for the interactive shell --------------------------------
cat > "$SESSION_DIR/bashrc" << 'RCEOF'
# Flush every command to the session history file immediately
export HISTCONTROL=ignoredups:ignorespace
export HISTTIMEFORMAT="%Y-%m-%dT%H:%M:%S "
shopt -s histappend
# After each command: flush history to disk AND ensure the file stays
# world-readable (bash may reset permissions on write)
PROMPT_COMMAND='history -a; chmod 644 "$HISTFILE" 2>/dev/null'
RCEOF

# Inject the dynamic HISTFILE path
echo "export HISTFILE=\"${SESSION_DIR}/history\"" >> "$SESSION_DIR/bashrc"

# On exit: write an ended marker with timestamp
cat >> "$SESSION_DIR/bashrc" << RCEOF2
_iota_session_cleanup() {
  history -a 2>/dev/null
  chmod 644 "$HISTFILE" 2>/dev/null
  echo "{\"ended_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" > "${SESSION_DIR}/ended.json"
}
trap _iota_session_cleanup EXIT
RCEOF2

# Add welcome banner
cat >> "$SESSION_DIR/bashrc" << BANNEREOF

echo ""
echo "  ╔══════════════════════════════════════╗"
echo "  ║  🔷  IOTA Service Terminal           ║"
echo "  ╚══════════════════════════════════════╝"
echo ""
echo "  Session : ${SESSION_ID}"
BANNEREOF

if [ -n "$DID" ]; then
  echo "echo \"  DID     : ${DID}\"" >> "$SESSION_DIR/bashrc"
fi

cat >> "$SESSION_DIR/bashrc" << 'TAILEOF'
echo ""
echo "  Commands are recorded and will be notarized on the IOTA Tangle."
echo ""
TAILEOF

# --- Launch the interactive shell -------------------------------------------
exec bash --rcfile "$SESSION_DIR/bashrc" -i
