#!/usr/bin/env bash
# .github/hooks/guard-kubectl-apply.sh
#
# PreToolUse hook — intercepts run_in_terminal calls that contain
# "kubectl apply" and blocks any that are NOT the bootstrap flow.
#
# Bootstrap-allowed patterns (never blocked):
#   kubectl apply -k infrastructure/argocd/...
#   kubectl apply -f <file-containing-__REPO_URL__-or-__TARGET_REVISION__>
#   kubectl apply -f - (piped sed substitution from Makefile bootstrap target)
#
# Everything else emits a warning and sets permissionDecision=ask.
#
# Input:  JSON on stdin  { "toolName": "...", "toolInput": { "command": "..." } }
# Output: JSON on stdout (permissionDecision + reason)

set -euo pipefail

input=$(cat)

tool_name=$(echo "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('toolName',''))" 2>/dev/null || true)

# Only act on run_in_terminal / terminal tool calls
if [[ "$tool_name" != "run_in_terminal" && "$tool_name" != "terminal" ]]; then
  exit 0
fi

command=$(echo "$input" | python3 -c "
import sys, json
d = json.load(sys.stdin)
inp = d.get('toolInput', {})
print(inp.get('command', inp.get('cmd', '')))
" 2>/dev/null || true)

# Not a kubectl apply — allow
if ! echo "$command" | grep -qE 'kubectl[[:space:]]+apply'; then
  exit 0
fi

# ── Allowed bootstrap patterns ──────────────────────────────────────────────
# 1. kustomize overlay for argocd install
if echo "$command" | grep -qE 'kubectl apply -k infrastructure/argocd'; then
  exit 0
fi
# 2. Piped sed substitution (bootstrap renders root-application.yaml)
if echo "$command" | grep -qE 'sed .* kubectl apply -f -'; then
  exit 0
fi
# 3. Explicit root-application.yaml (rendered file, contains no placeholders)
if echo "$command" | grep -qE 'kubectl apply -f .*root-application\.yaml'; then
  exit 0
fi
# ────────────────────────────────────────────────────────────────────────────

# Everything else: warn and ask for confirmation
cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "Direct 'kubectl apply' detected outside the bootstrap flow. This cluster is GitOps-managed by Argo CD — imperative applies may be overwritten by the next sync.\n\nPreferred workflow:\n  1. Commit and push your manifest changes to Git\n  2. Run: make apps-install\n     (triggers a hard refresh on root-app; Argo CD syncs everything)\n\nOnly continue if you are intentionally making a one-off imperative change (e.g. a ConfigMap patch during debugging)."
  }
}
EOF
