# AGENTS.md — How Your Agent Works

## Every Session

Your agent automatically:
1. Reads `SOUL.md` — its personality
2. Reads `USER.md` — info about you
3. Checks `memory/` — recent context

## Memory

Your agent remembers things between conversations:
- **Daily notes** → `memory/YYYY-MM-DD.md` (auto-created)
- **Long-term** → `MEMORY.md` (curated by your agent)

## Customization

- Edit `SOUL.md` to change your agent's personality
- Edit `USER.md` to tell it about yourself
- Edit `HEARTBEAT.md` to add periodic tasks (email checks, calendar, etc.)

## Safety

Your agent will:
- ✅ Read files, search the web, help with tasks
- ✅ Remember context between sessions
- ❌ Never send messages or emails without asking first
- ❌ Never delete files without confirmation
- ❌ Never share your private data

## Tips

- The more you fill in `USER.md`, the better your agent can help
- Use `HEARTBEAT.md` for recurring tasks (checking email, calendar reminders)
- Your agent gets better over time as it learns your preferences
