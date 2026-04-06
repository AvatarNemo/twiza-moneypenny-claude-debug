# TOOLS.md - Local Notes

Skills define _how_ tools work. This file is for _your_ specifics — the stuff that's unique to your setup.

## What Goes Here

Things like:

- Camera names and locations
- SSH hosts and aliases
- Preferred voices for TTS
- Speaker/room names
- Device nicknames
- Anything environment-specific

## Examples

```markdown
### Cameras

- living-room → Main area, 180° wide angle
- front-door → Entrance, motion-triggered

### SSH

- home-server → 192.168.1.100, user: admin

### TTS

- Preferred voice: "Nova" (warm, slightly British)
- Default speaker: Kitchen HomePod
```

## Why Separate?

Skills are shared. Your setup is yours. Keeping them apart means you can update skills without losing your notes, and share skills without leaking your infrastructure.

### ElevenLabs TTS

- **Christian** (voce clonata): ID `2kZeWws77Pfc4574R4a0`
- **Moneypenny** (la mia voce): ID `oVJbgLwL0s5pk9e2U6QH` — accento milanese marcato, velocità +15%
- Model: `eleven_multilingual_v2`
- API via curl (sag non installato su WSL)
- Default: quando parlo io uso la MIA voce. La voce di Christian solo se esplicitamente richiesto.

### GitHub

- **User**: AvatarNemo
- **Token**: stored in `~/.config/github/token` + `~/.git-credentials`
- **Credential helper**: `git config --global credential.helper store`
- **TWIZA repo**: `https://github.com/AvatarNemo/twiza-moneypenny`

---

Add whatever helps you do your job. This is your cheat sheet.
