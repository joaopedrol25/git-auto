#!/bin/bash

check_git_repository() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: This directory is not a git repository."
    exit 1
  fi
}

check_api_key() {
  if [ -z "${API_KEY_AI:-}" ]; then
    echo "API_KEY_AI environment variable is not set."
    echo "Export it first: export API_KEY_AI=\"your-key-here\""
    exit 1
  fi
}

get_current_branch() {
  CURRENT_BRANCH=$(git branch --show-current 2>/dev/null)
  if [ -z "$CURRENT_BRANCH" ]; then
    CURRENT_BRANCH=$(git config --get init.defaultBranch 2>/dev/null || echo "main")
  fi
}

get_current_remote() {
  REMOTE=$(git config --get branch."$CURRENT_BRANCH".remote 2>/dev/null || true)
  [ -z "$REMOTE" ] && REMOTE="origin"
}

check_staged_changes() {
  DIFF_CONTENT=$(git diff --cached | head -n 300)

  if [ -z "$DIFF_CONTENT" ]; then
    echo "No staged changes found."
    echo ""
    read -rp "  Do you want to try a push? [Y/n]: " push_choice
    push_choice="${push_choice:-y}"
    case "${push_choice,,}" in
    y | yes)
      push_to_remote
      ;;
    n | no)
      echo "Exiting. Nothing to do."
      exit 0
      ;;
    *)
      echo "Invalid choice. Exiting."
      exit 1
      ;;
    esac
  else
    echo "Staged changes detected."
    get_ai_message
  fi
}

get_ai_message() {
  local API_KEY="$API_KEY_AI"
  local URL="https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent"

  echo "Asking AI for a commit message..."

  export DIFF_CONTENT

  local HEADER
  local JSON_PAYLOAD
  JSON_PAYLOAD=$(jq -n --arg prompt "Write a short, professional git commit message for these changes. Use English. Return ONLY the raw commit message text in one line using a prefix that categorizes the nature of changes, like feat, fix, docs, style, refactor, perf, test, chore, build, ci, or revert, followed by a colon and the message itself. Example: feat: add user authentication module" \
    '{
      contents: [
        {
          parts: [
            {
              text: ($prompt + "\n\n" + env.DIFF_CONTENT)
            }
          ]
        }
      ]
    }')

  local RESPONSE
  RESPONSE=$(curl -s -w "\n%{http_code}" "$URL" \
    -H "x-goog-api-key: $API_KEY" \
    -H "Content-Type: application/json" \
    -X POST \
    -d "$JSON_PAYLOAD")

  local HTTP_CODE
  HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
  RESPONSE=$(echo "$RESPONSE" | sed '$d')

  if [ "$HTTP_CODE" -ne 200 ]; then
    echo "API request failed (HTTP $HTTP_CODE)."
    echo "$RESPONSE" | jq -r '.error.message // .' 2>/dev/null || echo "$RESPONSE"
    exit 1
  fi

  COMMIT_MESSAGE=$(echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].text // empty' 2>/dev/null)
  COMMIT_MESSAGE=$(echo "$COMMIT_MESSAGE" | tr -d '\"' | tr -d '`' | sed '/^$/d' | head -n 1)

  if [ -z "$COMMIT_MESSAGE" ] || [ "$COMMIT_MESSAGE" == "null" ]; then
    echo "AI returned an empty or invalid response."
    echo "Raw response:"
    echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
    exit 1
  fi

  do_commit
}

do_commit() {
  echo "--------------------------------------------------------------"
  echo -e "Proposed commit message:"
  echo "[ ${COMMIT_MESSAGE} ]"
  echo "--------------------------------------------------------------"
  echo ""
  read -rp "  Accept? [Y/n/e(dit)/r(etry)]: " choice
  choice="${choice:-y}"

  case "${choice,,}" in
  n | no)
    echo "Commit aborted."
    exit 0
    ;;
  e | edit)
    read -rp "  Enter your commit message: " COMMIT_MESSAGE
    if [ -z "$COMMIT_MESSAGE" ]; then
      echo "Empty message. Aborting."
      exit 1
    fi
    ;;
  *)
    echo ""
    ;;
  esac

  git commit -m "$COMMIT_MESSAGE"
  echo "Committed successfully!"
  push_to_remote
}

push_to_remote() {
  get_current_branch
  get_current_remote

  if git remote | grep -q "^${REMOTE}$"; then
    echo ""
    read -rp "Push to ${REMOTE}/${CURRENT_BRANCH}? [Y/n]: " push_choice
    echo ""
    case "${push_choice,,}" in
    n | no)
      echo "Push skipped. Your commit is saved locally."
      exit 0
      ;;
    *)
      echo "Pushing to ${REMOTE}/${CURRENT_BRANCH}..."
      if git push "$REMOTE" "$CURRENT_BRANCH"; then
        echo "Push complete."
        exit 0
      else
        echo "Push failed. You can retry with:"
        echo "  git push $REMOTE $CURRENT_BRANCH"
        echo "  git push $REMOTE $CURRENT_BRANCH --force  (if you know what you are doing)"
        exit 1
      fi
      ;;
    esac
  else
    echo ""
    echo "Remote '$REMOTE' not configured. Skipping push."
    echo "Commit saved locally. To push later, link your repo:"
    echo "  git remote add origin <url>"
    echo "  git push -u origin $CURRENT_BRANCH"
    exit 1
  fi
}

undo_last_commit() {
  check_git_repository
  get_current_branch
  get_current_remote

  if ! git rev-parse HEAD >/dev/null 2>&1; then
    echo "No commits found in this branch to undo."
    exit 0
  fi

  echo "Analyzing your last commit..."

  local LAST_COMMIT_HASH LAST_COMMIT_SUBJECT LAST_COMMIT_AUTHOR LAST_COMMIT_DATE
  LAST_COMMIT_HASH=$(git rev-parse HEAD)
  LAST_COMMIT_SUBJECT=$(git log -1 --format="%s")
  LAST_COMMIT_AUTHOR=$(git log -1 --format="%an")
  LAST_COMMIT_DATE=$(git log -1 --format="%cr")

  echo "--------------------------------------------------------------"
  echo "  Last commit found:"
  echo "  Hash    : ${LAST_COMMIT_HASH:0:7}"
  echo "  Message : ${LAST_COMMIT_SUBJECT}"
  echo "  Author  : ${LAST_COMMIT_AUTHOR}"
  echo "  When    : ${LAST_COMMIT_DATE}"
  echo "--------------------------------------------------------------"

  local IS_PUSHED
  IS_PUSHED=$(git branch -r --contains "$LAST_COMMIT_HASH" 2>/dev/null \
    | grep -q "${REMOTE}/${CURRENT_BRANCH}" && echo "yes" || echo "no")

  if [ "$IS_PUSHED" = "no" ]; then
    echo "This commit is strictly LOCAL (not pushed yet)."
    read -rp "Undo this commit and keep changes staged? [Y/n]: " undo_choice
    undo_choice="${undo_choice:-y}"

    if [[ "${undo_choice,,}" =~ ^(y|yes)$ ]]; then
      git reset --soft HEAD~1
      echo "Success! Commit undone. Your changes are back in the staging area."
    else
      echo "Operation canceled."
    fi

  else
    echo "WARNING: This commit has ALREADY been pushed to ${REMOTE}/${CURRENT_BRANCH}."
    echo "Undoing it locally and force-pushing can break things for other contributors."
    echo ""
    echo "Options:"
    echo "  1) Revert  — Create a new commit that rolls back the changes (Safest)"
    echo "  2) Force   — Delete locally and force-push (Dangerous — use only if working alone)"
    echo "  3) Cancel"
    read -rp "Choose an option [1-3]: " remote_choice

    case "$remote_choice" in
    1)
      echo "Reverting commit..."
      git revert --no-edit "$LAST_COMMIT_HASH" && git push "$REMOTE" "$CURRENT_BRANCH"
      echo "Revert pushed successfully."
      ;;
    2)
      echo "This will rewrite the remote history of ${REMOTE}/${CURRENT_BRANCH}."
      read -rp "  Are you absolutely sure? [y/N]: " confirm_force
      if [[ "${confirm_force,,}" =~ ^(y|yes)$ ]]; then
        git reset --soft HEAD~1
        git push "$REMOTE" "$CURRENT_BRANCH" --force
        echo "History rewritten successfully."
      else
        echo "Operation canceled."
      fi
      ;;
    *)
      echo "Operation canceled."
      exit 0
      ;;
    esac
  fi
}

case "${1:-}" in
-u | --undo)
  undo_last_commit
  ;;
-a | --stage-all)
  echo "Staging all changes..."
  git add -A
  check_git_repository
  check_api_key
  check_staged_changes
  ;;
-h | --help)
  echo "gitauto — AI-Powered Git Assistant"
  echo ""
  echo "Usage:"
  echo "  gitauto [options]"
  echo ""
  echo "Options:"
  echo "  gitauto              Run standard flow (Stage check → AI Commit → Push)"
  echo "  gitauto -a, --stage-all   Stage all changes, then run standard flow"
  echo "  gitauto -u, --undo        Undo or revert the very last commit safely"
  echo "  gitauto -h, --help        Show this help menu"
  exit 0
  ;;
"")

  check_git_repository
  check_api_key
  check_staged_changes
  ;;
*)
  echo "Unknown option: $1"
  echo "Use 'gitauto --help' for usage."
  exit 1
  ;;
esac
