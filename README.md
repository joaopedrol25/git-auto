# gitauto

> **AI-powered Git commits — stage, commit, and push with a single command.**

`gitauto` is a Bash script that reads your staged Git changes, sends them to an AI model, and proposes a professional, conventional commit message. You review it, accept, edit, retry, or reject — then it commits and pushes for you.

---

## Features

- **AI-generated commit messages** built from your staged diff as context
- **Conventional Commits** format (`feat:`, `fix:`, `docs:`, `refactor:`, `chore:`, etc.)
- **Interactive review** — accept, edit, retry with a new AI suggestion, or abort
- **Safe undo** — undo or revert the last commit with built-in safety checks
- **Stage-all shortcut** — stage everything and commit in one command
- **Smart push** — detects the current branch and remote automatically
- **API key validation** before any network call is made

---

## Requirements

| Tool | Purpose |
|------|---------|
| `bash` (v4+) | Runtime |
| `git` | Version control |
| `curl` | API requests |
| `jq` | JSON parsing |
| An AI API key | Commit message generation |

Install missing tools on Debian/Ubuntu:

```bash
sudo apt install git curl jq
```

---

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/joaopedrol25/git-auto.git
cd git-auto
```

### 2. Make the script executable

```bash
chmod +x git-ai.sh
```

### 3. Install globally

```bash
sudo cp git-ai.sh /usr/local/bin/gitauto
```

Now you can call `gitauto` from any Git repository on your system.

---

## API Key Setup

The script requires an AI API key exported as `API_KEY_AI`. It ships pre-configured for **Google Gemini**.

### Getting a Gemini API key

1. Go to [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Sign in with your Google account
3. Click **"Create API key"**
4. Copy the generated key

### Exporting the key

```bash
export API_KEY_AI="your-gemini-api-key-here"
```

To make this permanent, add it to your shell config:

```bash
# ~/.bashrc or ~/.zshrc
export API_KEY_AI="your-gemini-api-key-here"
```

Then reload:

```bash
source ~/.bashrc   # or source ~/.zshrc
```

---

## Usage

```
gitauto              Run standard flow (Stage check → AI Commit → Push)
gitauto -a           Stage all changes, then run standard flow
gitauto -u           Undo or revert the very last commit safely
gitauto -h           Show the help menu
```

### Standard workflow

```bash
# Stage your changes as usual
git add .

# Let AI do the rest
gitauto
```

### Stage everything in one shot

```bash
gitauto -a   # or gitauto --stage-all
# Equivalent to: git add -A && gitauto
```

---

## Interactive Prompts

### Commit message review

```
--------------------------------------------------------------
Proposed commit message:
[ feat: add user authentication module ]
--------------------------------------------------------------

  Accept? [Y/n/e(dit)/r(etry)]:
```

| Input | Behaviour |
|-------|-----------|
| `Y` or Enter | Commit with the proposed message |
| `n` | Abort — nothing is committed |
| `e` | Type your own message, then commit |
| `r` | Ask the AI for a new suggestion |

### Push prompt

```
  Push to origin/main? [Y/n]:
```

| Input | Behaviour |
|-------|-----------|
| `Y` or Enter | Push to the detected remote and branch |
| `n` | Skip push — commit is saved locally |

### No staged changes

If nothing is staged, `gitauto` skips the AI and asks if you want to push directly:

```
No staged changes found.

  Do you want to try a push? [Y/n]:
```

---

## Undo Last Commit (`-u`)

```bash
gitauto --undo
```

`gitauto` inspects your last commit and handles it differently based on whether it has been pushed:

### Local-only commit

```
Last commit found:
  Hash   : a1b2c3d
  Message: feat: add login page
  Author : Unknown Author
  When   : 2 minutes ago

This commit is strictly LOCAL (not pushed yet).
Undo this commit and keep changes staged? [Y/n]:
```

A `git reset --soft HEAD~1` is run — your changes go back to the staging area.

### Already-pushed commit

```
 WARNING: This commit has ALREADY been pushed to origin/main.

Options:
  1) Revert — Create a new commit that rolls back the changes (Safest)
  2) Force  — Delete locally and force-push (Dangerous — solo repos only)
  3) Cancel
```

| Option | What it does |
|--------|-------------|
| `1` | `git revert` + push — safe for shared repos |
| `2` | `git reset --soft` + `git push --force` — rewrites history |
| `3` | Do nothing |

---

## How It Works

```
git diff --cached
       │
       ▼
  AI API (Gemini)
       │
       ▼
  Proposed commit message
       │
       ▼
  User reviews  ──→  retry / edit / abort
       │
       ▼
  git commit -m "..."
       │
       ▼
  git push origin <branch>
```

| Function | Responsibility |
|----------|---------------|
| `check_git_repository` | Validates you're inside a Git repo |
| `check_api_key` | Ensures `API_KEY_AI` is set |
| `get_current_branch` | Detects the active branch |
| `get_current_remote` | Detects the configured remote |
| `check_staged_changes` | Reads the diff; routes to AI or push-only |
| `get_ai_message` | Builds the JSON payload, calls the API, parses the response |
| `do_commit` | Shows the message and handles accept / edit / retry / abort |
| `push_to_remote` | Optionally pushes after a successful commit |
| `undo_last_commit` | Safely undoes or reverts the last commit |

---

## Switching to Another AI Provider

You can adapt `gitauto` to any REST-based AI API. The only function you need to modify is `get_ai_message()` inside `git-ai.sh`.

### Example: OpenAI (ChatGPT)

```bash
get_ai_message() {
  local API_KEY="$API_KEY_AI"
  local URL="https://api.openai.com/v1/chat/completions"

  local JSON_PAYLOAD
  JSON_PAYLOAD=$(jq -n --arg diff "$DIFF_CONTENT" \
    --arg prompt "Write a short, professional git commit message..." \
    '{
      model: "gpt-4o-mini",
      messages: [{ role: "user", content: ($prompt + "\n\n" + $diff) }]
    }')

  RESPONSE=$(curl -s "$URL" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -X POST \
    -d "$JSON_PAYLOAD")

  COMMIT_MESSAGE=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // empty')
  COMMIT_MESSAGE=$(echo "$COMMIT_MESSAGE" | tr -d '"' | tr -d '`' | sed '/^$/d' | head -n 1)
}
```

---

## Security Notes

- Your API key is **never** logged, committed, or stored by the script — it lives only in your shell environment.
- The staged diff is sent to the AI provider's servers. Avoid using `gitauto` on diffs that contain secrets or sensitive credentials.

---

## License

MIT — do whatever you want with it.

---

## Contributing

PRs and issues are welcome. If you add support for a new AI provider or a new flag, feel free to open a PR with the relevant changes and a snippet in this README.
