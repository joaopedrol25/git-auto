# git-auto

> **AI-powered Git commit messages — generated automatically from your staged diff.**

`git-auto` is a Bash script that reads your staged Git changes, sends them to an AI model, and proposes a professional, conventional commit message. You review it, accept, edit, or reject — then it commits and pushes for you.

---

##  Features

- **AI-generated commit messages** using your staged diff as context
- **Conventional Commits** format (`feat:`, `fix:`, `docs:`, `refactor:`, etc.)
- **Interactive review** — accept, reject, or manually edit the proposed message
- **Optional push** after committing, targeting the correct remote and branch automatically
- **API key validation** before any network call

---

## Requirements

- `bash` (v4+)
- `git`
- `curl`
- `jq`
- An AI API key (see [Choosing an AI Provider](#-choosing-an-ai-provider))

Install missing tools on Debian/Ubuntu:

```bash
sudo apt install git curl jq
```

---

## Choosing an AI Provider

The script requires an AI API key exported as the `API_KEY_AI` environment variable. **You can use any provider** — just swap the API endpoint and authentication header inside `get_ai_message()` in `git-ai.sh`.

The script currently ships pre-configured for **Google Gemini**.

---

## Using Google Gemini (default)

### 1. Get your Gemini API key

1. Go to [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Sign in with your Google account
3. Click **"Create API key"**
4. Copy the generated key

### 2. Export the key in your shell

```bash
export API_KEY_AI="your-gemini-api-key-here"
```

To make this permanent, add it to your shell config file:

```bash
# ~/.bashrc or ~/.zshrc
export API_KEY_AI="your-gemini-api-key-here"
```

Then reload it:

```bash
source ~/.bashrc   # or source ~/.zshrc
```

### 3. How the script calls Gemini

The script hits the Gemini **`generateContent`** REST endpoint:

```
POST https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent
```

Authentication is done via the `x-goog-api-key` HTTP header (not a Bearer token):

```bash
curl -s "$URL" \
  -H "x-goog-api-key: $API_KEY" \
  -H "Content-Type: application/json" \
  -X POST \
  -d "$JSON_PAYLOAD"
```

The model in use is configurable inside `git-ai.sh` — look for the `URL` variable inside `get_ai_message()`:

```bash
local URL="https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview:generateContent"
```

To switch to a different Gemini model (e.g. `gemini-1.5-pro`), just replace the model slug in that URL.

> **Available Gemini models:** [Google AI — Models overview](https://ai.google.dev/gemini-api/docs/models/gemini)

---

## Switching to Another AI Provider

You can adapt the script to any OpenAI-compatible or custom REST API. The only function you need to modify is `get_ai_message()`.

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

## Installation

### 1. Clone or download the script

```bash
git clone https://github.com/joaopedrol25/git-auto.git
cd git-auto
```

### 2. Make the script executable

```bash
chmod +x git-ai.sh
```

### 3. Install globally (optional but recommended)

```bash
sudo cp git-ai.sh /usr/local/bin/git-auto
```

Now you can call `git-auto` from any Git repository.

---

## Usage

### Basic workflow

```bash
# 1. Stage your changes as usual
git add .

# 2. Run git-auto
git-auto
```

### What happens next

```
Staged changes detected.
Asking AI for a commit message...
--------------------------------------------
Proposed commit message:
[feat: add user authentication module]
--------------------------------------------

Accept this message? [Y/n/e(dit)]:
```

| Input | Behaviour |
|-------|-----------|
| `Y` (or Enter) | Commit with the proposed message |
| `n` | Abort — nothing is committed |
| `e` | Prompt you to type your own message, then commit |

After committing:

```
Committed successfully!

Push to origin/main? [Y/n]:
```

| Input | Behaviour |
|-------|-----------|
| `Y` (or Enter) | Push to the detected remote and branch |
| `n` | Skip push — commit is saved locally |

### No staged changes

If you run `git-auto` with nothing staged, it skips AI and asks if you want to push directly:

```
No staged changes found.

Do you wanna try a push?[Y/n]:
```

---

## How It Works

```
git diff --cached
       │
       ▼
  AI API (Gemini / OpenAI / other)
       │
       ▼
  Proposed commit message
       │
       ▼
  User reviews (accept / edit / reject)
       │
       ▼
  git commit -m "..."
       │
       ▼
  git push origin <branch>
```

1. **`check_api_key`** — ensures `API_KEY_AI` is set before doing anything.
2. **`check_staged_changes`** — runs `git diff --cached`; if empty, jumps to push.
3. **`get_ai_message`** — builds a JSON payload with the diff + prompt, calls the API, and parses the response.
4. **`do_commit`** — shows the proposed message and lets you accept, edit, or abort.
5. **`push_to_remote`** — detects the current branch and remote, then optionally pushes.

---

## Security Notes

- Your API key is **never** logged or committed — it lives only in your shell environment.
- The staged diff is sent to the AI provider's servers. Avoid running this on diffs containing secrets or sensitive credentials.

---

## License

MIT — do whatever you want with it.

---

## Contributing

PRs and issues are welcome. If you add support for a new AI provider, feel free to open a PR with an example snippet in this README.
