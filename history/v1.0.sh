#!/bin/bash


if git diff --cached --quiet; then
    echo "No staged changes found. Use 'git add' first."
    exit 1
fi


DIFF_CONTENT=$(git diff --cached)


CURRENT_BRANCH=$(git branch --show-current 2>/dev/null)
if [ -z "$CURRENT_BRANCH" ]; then

    CURRENT_BRANCH=$(git config --get init.defaultBranch || echo "main")
fi

echo "Asking AI for a commit message..."

API_KEY=$API_KEY_AI
URL="https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent"


JSON_PAYLOAD=$(jq -n --arg diff "$DIFF_CONTENT" \
  --arg prompt "Write a short, professional git commit message for these changes. Use English. Return ONLY the raw commit message text in one line using categorizes the nature of changes, like feat, fix, docs, style, refactor, perf, test, chore, build, ci, or revert, in the beginning of the message, followed by the message itself:" \
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


RESPONSE=$(curl -s "$URL" \
    -H "x-goog-api-key: $API_KEY" \
    -H "Content-Type: application/json" \
    -X POST \
    -d "$JSON_PAYLOAD")


MESSAGE=$(echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].text // empty' 2>/dev/null)
MESSAGE=$(echo "$MESSAGE" | tr -d '"' | tr -d '`' | sed '/^$/d' | head -n 1)

if [ -z "$MESSAGE" ] || [ "$MESSAGE" == "null" ]; then
    echo "AI Error! Raw response from server:"
    echo "$RESPONSE"
    exit 1
fi


echo "Committing: $MESSAGE"
git commit -m "$MESSAGE"


if git remote | grep -q "^origin$"; then
    echo "Pushing to origin $CURRENT_BRANCH..."
    git push origin "$CURRENT_BRANCH"
else
    echo "--------------------------------------------------------"
    echo "Remote 'origin' not configured. Skipping push."
    echo "Commit saved locally! To push later, link your repo:"
    echo "   git remote add origin <url>"
    echo "   git push -u origin $CURRENT_BRANCH"
    echo "--------------------------------------------------------"
fi

echo "Done!"
