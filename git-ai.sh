#!/bin/bash

check_api_key() {
  if [ -z "${API_KEY_AI:-}" ]; then
    err "API_KEY_AI environment variable is not set."
    echo "Export it first: export API_KEY_AI=\"your-key-here\""
    exit 1
  fi
}

check_staged_changes() {
  DIFF_CONTENT=$(git diff --cached)

  if [ -z "$DIFF_CONTENT" ]; then
    echo "No staged changes found."
    echo ""
    read -rp "Do you wanna try a push?[Y/n]: " push_choice
    case "${push_choice,,}" in
      y) push_to_remote
        ;;
      n) exit 0
        ;;
      *) echo "Invalid choice. Exiting."; exit 1
        ;;
    esac
  else
   echo "Staged changes detected."
   get_ai_message
  fi
}

get_ai_message() {
  local API_KEY="$API_KEY_AI"
  local URL="https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent"

  echo "Asking AI for a commit message..."

  local JSON_PAYLOAD
  JSON_PAYLOAD=$(jq -n --arg diff "$DIFF_CONTENT" \
    --arg prompt "Write a short, professional git commit message for these changes. Use English. Return ONLY the raw commit message text in one line using a prefix that categorizes the nature of changes, like feat, fix, docs, style, refactor, perf, test, chore, build, ci, or revert, followed by a colon and the message itself. Example: feat: add user authentication module" \
    '{
      contents: [
        {
          parts: [
            {
              text: ($prompt + "\n\n" + $diff)
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
    err "API request failed (HTTP $HTTP_CODE)."
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
}

do_commit() {
  echo ""
  echo "Proposed commit message:"
  echo ${COMMIT_MESSAGE}
  echo ""
  git commit -m "$COMMIT_MESSAGE"
  echo "Committed successfully!"
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

push_to_remote() {
  get_current_branch
  get_current_remote

  if git remote | grep -q "^${REMOTE}$"; then

    read -rp "Push to ${REMOTE}/${CURRENT_BRANCH}? [Y/n]: " push_choice
    echo ""
    case "${push_choice,,}" in
      n)
        echo "Push skipped. Your commit is saved locally."
        ;;
      *)
        echo "Pushing to ${REMOTE}/${CURRENT_BRANCH}..."
        if git push "$REMOTE" "$CURRENT_BRANCH"; then
          exit 0
        else
          echo "Push failed. You can retry with:"
          echo "  git push $REMOTE $CURRENT_BRANCH"
          echo "  git push $REMOTE $CURRENT_BRANCH --force (if you know what you are doing)" 
          exit 1
        fi
        ;;
    esac
  else
    echo ""
    echo "Remote '$REMOTE' not configured. Skipping push."
    echo "Commit saved locally. To push later, link your repo:"
    echo "    git remote add origin <url>"
    echo "    git push -u origin $CURRENT_BRANCH"
    exit 1
  fi
}

check_api_key
check_staged_changes
do_commit
push_to_remote