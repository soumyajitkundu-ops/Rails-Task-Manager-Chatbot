# dbstore — Todo app with AI chat, memory, and web-grounded answers

A Rails API with JWT-authenticated todos, plus an AI chat assistant that:

- keeps a rolling conversation memory (in-process, with a MySQL-backed durable snapshot)
- knows the user's own todos as live context
- falls back to a web search (Google SERP + Google AI Mode, via Scrape.do) when it doesn't know an answer, without ever leaking personal data into the search query
- logs the full chat transcript to the database for the frontend to render

## Stack

- Ruby on Rails 8.1 (API-only), MySQL
- JWT auth in a signed, httponly cookie
- [Groq](https://groq.com) (`openai/gpt-oss-120b`) for the chat model
- [Scrape.do](https://scrape.do) for web search (Google SERP + Google AI Mode)
- In-process `Concurrent::Map` for live chat sessions, with debounced DB snapshotting

## Setup

```bash
bundle install
bin/rails credentials:edit
bin/rails db:create db:migrate
bin/rails s
```

### Credentials

Add these under `bin/rails credentials:edit`:

```yaml
jwt_secret: <a long random string>

groq:
  api_key: <your Groq API key>

scrape_do:
  token: <your Scrape.do token>
```

### Cache

`SearchClient` caches results for an hour to avoid re-billing Scrape.do credits on repeated questions. In development, caching is off by default — run this once:

```bash
bin/rails dev:cache
```

## Architecture

```
Client
  │
  ├─ Auth (SessionsController)        — register, login, logout, JWT cookie
  ├─ Todos (TodosController)          — create/update tasks; refreshes chat memory's core data
  └─ AI chat (AiController)           — chat, chat history, clear memory
        │
        ▼
  AiChatService                       — orchestrates one chat turn
        │
        ├─ ChatMemory                 — working conversation state (map + DB snapshot)
        ├─ ChatMemoryJobs             — debounced snapshot + 2-minute idle eviction (in-process timers)
        ├─ GroqClient                 — talks to the Groq chat completions API
        └─ SearchClient               — talks to Scrape.do (Google SERP + Google AI Mode)
              │
              ▼
        MySQL (users, todos, chat_memory_snapshots, chat_messages)
```

See the two diagrams shared in chat for the visual version of this (component architecture, and the step-by-step `/ai/chat` request flow).

## API

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/register` | — | Create a user |
| POST | `/login` | — | Log in, sets JWT cookie |
| DELETE | `/logout` | ✓ | Revoke the JWT (blacklisted by `jti`) |
| GET | `/me` | ✓ | Current user + their todos (all todos, if admin) |
| POST | `/todos` | ✓ | Create todos |
| PATCH | `/todos/:id` | ✓ | Update a todo |
| POST | `/ai/chat` | ✓ | Send a chat message, get an answer |
| GET | `/ai/chats` | ✓ | Fetch this user's chat transcript, oldest first (`?user_id=` for admins) |
| DELETE | `/ai/clear_memory` | ✓ | Wipe this user's working chat memory (not the transcript) |

## How a chat message is answered

1. **Load session.** `ChatMemory.fetch_or_load` checks the in-process map first, then the
   `chat_memory_snapshots` table, then starts fresh. `ChatMemoryJobs.schedule` resets a
   debounced snapshot job (writes to the DB a minute after the last request) and a
   2-minute idle-eviction job (writes to the DB, then drops the session from memory).
2. **Call 1 (full context).** The model sees the user's core data (name, age, role, todos),
   long-term facts, the priority queue, the rolling summary, and recent turns. It either
   answers directly, or — only for non-personal, public questions it isn't confident about —
   returns a `search_query` with an empty answer.
3. **Search, if needed.** `SearchClient` fetches both Google's SERP snippets and the first ~50
   words of Google's AI Mode answer via Scrape.do (20 credits total; cached for an hour).
4. **Call 2 (minimal).** A separate, much smaller prompt — just the search evidence and the
   user's question, no core data, no history — writes the final answer in plain language.
   It's explicitly told not to include links, URLs, or citations.
5. **Persist.** The turn updates `ChatMemory` (summary, learned facts, recent/priority queues)
   and is appended to `chat_messages` — a permanent, ordered transcript separate from the
   AI's own working memory, used only for the frontend history view.

### Why two Groq calls per search

Call 1 already has everything needed to decide *whether* to search and to keep the
conversation summary current. Call 2 only needs to turn search evidence into words, so it
skips the user's personal data, memory, and history entirely — smaller prompt, smaller
completion, less exposure of personal data to search-derived content.

## Known limitations

- **Single-process memory.** The in-process map isn't shared across multiple Puma workers or
  server instances. The DB snapshot gives durability across restarts, not agreement between
  workers — that would need sticky routing by user or a shared store (Redis) as the source of
  truth.
- **"Answer box" queries** (live weather, currency conversion, stock prices, in-progress
  scores) aren't reliably answered by web search, since those are computed and rendered by
  Google directly rather than crawled and indexed text. They'd need a dedicated API per
  category (e.g. a weather API) rather than falling through to search.
- **Groq's free/on-demand tier** has an 8,000 tokens-per-minute cap; heavy use of the search
  path can hit it. `AiChatService` logs Groq error responses distinctly from parse failures,
  but does not currently retry automatically.
- **Scrape.do costs credits per search** (10 for SERP, 10 for AI Mode). Results are cached for
  an hour to reduce repeat cost, but there's no budget/quota guard beyond that.