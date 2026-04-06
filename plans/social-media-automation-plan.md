# Piano Operativo: Automazione Content Creation & Social Media

**Versione:** 1.0
**Data:** 2026-03-05
**Autore:** Moneypenny (AI Agent di Christian Contardi / SHAKAZAMBA)

---

## 1. ARCHITETTURA TECNICA

### 1.1 Pipeline Overview

```
┌─────────────┐    ┌──────────────┐    ┌───────────────┐    ┌─────────────┐    ┌────────────┐
│  PED (JSON)  │───▶│  Content Gen  │───▶│  Media Gen     │───▶│  Formatter   │───▶│  Publisher  │
│  piano edit. │    │  testo/copy   │    │  img/audio/vid │    │  per canale  │    │  API post   │
└─────────────┘    └──────────────┘    └───────────────┘    └─────────────┘    └────────────┘
       │                  │                    │                    │                   │
       ▼                  ▼                    ▼                    ▼                   ▼
   schedules/         content/              media/              output/             logs/
   ped.json          drafts/            generated/          ready-to-post/       publish.log
```

### 1.2 Struttura Directory

```
workspace/
├── social/
│   ├── ped.json                    # Piano Editoriale Digitale
│   ├── schedules/
│   │   └── weekly-schedule.json    # Schedule settimanale generato dal PED
│   ├── content/
│   │   └── drafts/                 # Testi generati, pre-review
│   ├── media/
│   │   ├── images/                 # Immagini generate (DALL-E, Canva)
│   │   ├── audio/                  # Audio TTS (ElevenLabs)
│   │   ├── video/                  # Video (Remotion + ffmpeg)
│   │   └── templates/              # Template Remotion
│   ├── output/
│   │   └── ready/                  # Pacchetti pronti per pubblicazione
│   ├── logs/
│   │   └── publish.log
│   └── scripts/
│       ├── generate-content.sh     # Script generazione contenuto
│       ├── generate-media.sh       # Script generazione media
│       ├── publish.sh              # Script pubblicazione
│       ├── publish-twitter.sh
│       ├── publish-linkedin.sh
│       ├── publish-facebook.sh
│       └── publish-instagram.sh
```

### 1.3 Tool Stack per Step

| Step | Tool | API/Servizio | Costo |
|------|------|-------------|-------|
| Testo | Claude/GPT (via OpenClaw) | Incluso nel piano OpenClaw | $0 extra |
| Immagini | OpenAI DALL-E 3 | `api.openai.com/v1/images/generations` | ~$0.04-0.08/img |
| Immagini template | Canva API | `api.canva.com` | Piano esistente |
| Audio TTS | ElevenLabs | `api.elevenlabs.io/v1/text-to-speech` | ~$0.30/1000 char |
| Video | Remotion + ffmpeg | Locale (Node.js) | $0 |
| Twitter | Twitter API v2 | `api.twitter.com/2/tweets` | Piano Free/Basic |
| LinkedIn | LinkedIn API | `api.linkedin.com/v2` | Gratuito |
| Facebook | Graph API | `graph.facebook.com/v19.0` | Gratuito |
| Instagram | Graph API | `graph.facebook.com/v19.0` | Gratuito |

### 1.4 Integrazione con OpenClaw Cron

OpenClaw supporta cron job nativi. La pipeline si aggancia così:

```bash
# Cron job giornaliero: genera contenuti per il giorno dopo
# openclaw cron add --schedule "0 8 * * *" --command "bash social/scripts/generate-content.sh"

# Cron job pubblicazione: controlla output/ready/ e pubblica
# openclaw cron add --schedule "*/30 9-21 * * *" --command "bash social/scripts/publish.sh"
```

Il flusso tramite heartbeat è più pratico per ora:
- Nel `HEARTBEAT.md` aggiungi check: "Controlla se ci sono post schedulati da pubblicare"
- Moneypenny legge `social/schedules/weekly-schedule.json`
- Se c'è un post per ora corrente → genera + pubblica

---

## 2. CONTENT CREATION

### 2.1 Generazione Testo

#### Formato per piattaforma

| Piattaforma | Max char | Stile | Hashtag | Link | CTA |
|-------------|----------|-------|---------|------|-----|
| Twitter/X | 280 | Diretto, punch | 2-3 max | Sì (shortlink) | Opzionale |
| LinkedIn | 3000 | Professionale, storytelling | 3-5 | Sì | Forte |
| Facebook | 63.206 | Conversazionale, medio | 2-3 | Sì | Medio |
| Instagram | 2.200 | Visual-first, emoji | 15-30 (commento) | No (solo bio) | Forte |

#### Template Prompt per Generazione Testo

File: `social/templates/prompts/`

**Twitter:**
```
Scrivi un tweet per @AvatarNemo (SHAKAZAMBA / Christian Contardi).
Tema: {tema}
Angolo: {angolo}
Tono: provocatorio ma intelligente, tech-savvy, italiano con spruzzate di inglese
Max 270 caratteri (lascia spazio per eventuali link).
Includi 1-2 hashtag pertinenti.
NO emoji eccessivi. Max 1-2 se naturali.
```

**LinkedIn:**
```
Scrivi un post LinkedIn per la pagina SHAKAZAMBA.
Tema: {tema}
Formato: hook (1 riga) + corpo (3-5 paragrafi) + CTA
Tono: professionale ma non corporate, thought leadership su AI/tech
Lunghezza: 800-1500 caratteri
Includi 3-5 hashtag alla fine.
Prima riga = gancio forte (la gente vede solo quella nel feed).
```

**Facebook:**
```
Scrivi un post Facebook per la pagina SHAKAZAMBA.
Tema: {tema}
Formato: conversazionale, come se parlassi a una community
Tono: accessibile, divulgativo, entusiasta
Lunghezza: 300-800 caratteri
Domanda finale per engagement.
```

**Instagram:**
```
Scrivi una caption Instagram per il profilo business SHAKAZAMBA.
Tema: {tema}
Formato: prima riga gancio + corpo + CTA + hashtag block
Tono: visual-oriented, inspirational/educational
Lunghezza caption: 500-1000 caratteri
Hashtag block separato: 15-25 hashtag mix (grandi + nicchia)
```

#### Script Generazione Testo

```bash
#!/bin/bash
# social/scripts/generate-text.sh
# Usa OpenClaw/Claude per generare testo

TEMA="$1"
ANGOLO="$2"
DATE="$3"

# Il testo viene generato direttamente da Moneypenny (Claude)
# durante l'esecuzione del cron/heartbeat, non serve script esterno.
# Moneypenny legge il PED, genera i testi, li salva in content/drafts/
```

In pratica: **Moneypenny genera il testo direttamente** come parte del flusso. Non serve un tool esterno per il copy.

### 2.2 Generazione Immagini

#### Tipi di immagine per canale

| Tipo | Uso | Dimensioni | Tool |
|------|-----|-----------|------|
| Quote card | Twitter, LinkedIn, FB | 1200x675 | Canva API o DALL-E |
| Hero image | LinkedIn, FB | 1200x628 | DALL-E |
| Instagram post | IG feed | 1080x1080 | DALL-E + ffmpeg resize |
| Instagram story | IG story | 1080x1920 | DALL-E + ffmpeg |
| Carousel slide | IG, LinkedIn | 1080x1080 | Canva API |
| Thumbnail | Video, Twitter | 1280x720 | DALL-E |
| Avatar/brand | Tutti | Varie | Canva API |

#### Generazione con DALL-E 3

```bash
# Esempio chiamata DALL-E 3
curl -s https://api.openai.com/v1/images/generations \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d '{
    "model": "dall-e-3",
    "prompt": "Futuristic AI assistant hologram, cyberpunk style, neon blue and purple, clean composition, no text, no humans, digital art style suitable for tech brand",
    "n": 1,
    "size": "1792x1024",
    "quality": "hd"
  }' | jq -r '.data[0].url'
```

Dimensioni DALL-E 3 disponibili: `1024x1024`, `1792x1024`, `1024x1792`

#### Post-processing con ffmpeg

```bash
# Resize per Instagram post (1080x1080) da DALL-E output
ffmpeg -i input.png -vf "scale=1080:1080:force_original_aspect_ratio=decrease,pad=1080:1080:(ow-iw)/2:(oh-ih)/2:color=black" output_ig.png

# Resize per Twitter/LinkedIn (1200x675)
ffmpeg -i input.png -vf "scale=1200:675:force_original_aspect_ratio=decrease,pad=1200:675:(ow-iw)/2:(oh-ih)/2:color=black" output_tw.png

# Resize per Story (1080x1920)
ffmpeg -i input.png -vf "scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2:color=black" output_story.png
```

#### Generazione con Canva API

```bash
# Canva API - Crea design da template
curl -s https://api.canva.com/rest/v1/designs \
  -H "Authorization: Bearer $CANVA_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "design_type": "InstagramPost",
    "title": "Post SHAKAZAMBA"
  }'

# Esporta design
curl -s https://api.canva.com/rest/v1/exports \
  -H "Authorization: Bearer $CANVA_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "design_id": "DESIGN_ID",
    "format": {"type": "png", "quality": "high", "size": "original"}
  }'
```

**Nota:** Canva API è in beta. Verificare stato accesso su https://www.canva.dev/

### 2.3 Generazione Audio

#### ElevenLabs TTS

Due voci disponibili:
- **Christian** (voce clonata): `2kZeWws77Pfc4574R4a0` — per contenuti "da Christian"
- **Moneypenny** (AI agent): `oVJbgLwL0s5pk9e2U6QH` — accento milanese, per contenuti "da Moneypenny"

```bash
# Genera audio con voce Moneypenny
curl -s https://api.elevenlabs.io/v1/text-to-speech/oVJbgLwL0s5pk9e2U6QH \
  -H "xi-api-key: $ELEVENLABS_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Testo da convertire in audio",
    "model_id": "eleven_multilingual_v2",
    "voice_settings": {
      "stability": 0.5,
      "similarity_boost": 0.75,
      "speed": 1.15
    }
  }' --output social/media/audio/output.mp3

# Genera audio con voce Christian
curl -s https://api.elevenlabs.io/v1/text-to-speech/2kZeWws77Pfc4574R4a0 \
  -H "xi-api-key: $ELEVENLABS_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Testo da convertire in audio",
    "model_id": "eleven_multilingual_v2",
    "voice_settings": {
      "stability": 0.5,
      "similarity_boost": 0.8
    }
  }' --output social/media/audio/output_christian.mp3
```

#### Usi audio
- **Voiceover per video**: narrazione su Reel/Short
- **Podcast snippet**: 30-60 sec clip audio per Twitter/LinkedIn
- **Audiogramma**: audio + waveform animata (ffmpeg)

```bash
# Audiogramma: audio + waveform
ffmpeg -i audio.mp3 -i background.png \
  -filter_complex "[0:a]showwaves=s=1080x200:mode=cline:colors=0x00BFFF:rate=30[waves];[1:v][waves]overlay=0:H-200[out]" \
  -map "[out]" -map 0:a -c:v libx264 -c:a aac -shortest -t 60 audiogram.mp4
```

### 2.4 Generazione Video

#### Pipeline Video

```
Testo script → TTS audio → Remotion template → Render → ffmpeg post-process → Output per canale
```

#### Formati video per canale

| Canale | Formato | Durata | Aspect | Risoluzione |
|--------|---------|--------|--------|-------------|
| Twitter | Video post | max 2:20 | 16:9 o 1:1 | 1920x1080 o 1080x1080 |
| LinkedIn | Video post | max 10 min | 16:9 o 1:1 | 1920x1080 |
| Facebook | Reel | 3-90 sec | 9:16 | 1080x1920 |
| Facebook | Video post | max 240 min | 16:9 | 1920x1080 |
| Instagram | Reel | 3-90 sec | 9:16 | 1080x1920 |
| Instagram | Story | max 60 sec | 9:16 | 1080x1920 |
| Instagram | Feed video | max 60 min | 1:1 o 4:5 | 1080x1080 |

#### Remotion Setup

```bash
# Installazione Remotion
cd social/media/templates
npx create-video@latest remotion-templates --template blank

# Struttura template
remotion-templates/
├── src/
│   ├── compositions/
│   │   ├── QuoteVideo.tsx      # Citazione animata con sfondo
│   │   ├── TipVideo.tsx        # Tip/consiglio con bullet points
│   │   ├── ProductDemo.tsx     # Demo TWIZA Moneypenny
│   │   ├── Audiogram.tsx       # Audio + waveform
│   │   └── TextReveal.tsx      # Testo che appare progressivamente
│   ├── components/
│   │   ├── Logo.tsx
│   │   ├── Background.tsx
│   │   └── TextBlock.tsx
│   └── Root.tsx
├── public/
│   ├── logo-shakazamba.png
│   ├── fonts/
│   └── audio/
└── package.json
```

#### Esempio Template Remotion (QuoteVideo)

```tsx
// src/compositions/QuoteVideo.tsx
import {AbsoluteFill, useCurrentFrame, interpolate, Audio, Img} from 'remotion';

export const QuoteVideo: React.FC<{
  quote: string;
  author: string;
  audioSrc: string;
  bgColor: string;
}> = ({quote, author, audioSrc, bgColor}) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(frame, [0, 30], [0, 1], {extrapolateRight: 'clamp'});
  const slideUp = interpolate(frame, [0, 30], [50, 0], {extrapolateRight: 'clamp'});

  return (
    <AbsoluteFill style={{backgroundColor: bgColor, padding: 80}}>
      <Audio src={audioSrc} />
      <div style={{
        opacity,
        transform: `translateY(${slideUp}px)`,
        color: 'white',
        fontSize: 48,
        fontFamily: 'Inter',
        textAlign: 'center',
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'center',
        height: '100%'
      }}>
        <p>"{quote}"</p>
        <p style={{fontSize: 24, marginTop: 40}}>— {author}</p>
      </div>
      <Img src="/logo-shakazamba.png"
        style={{position: 'absolute', bottom: 40, right: 40, width: 120}} />
    </AbsoluteFill>
  );
};
```

#### Render Remotion

```bash
# Render video 1080x1920 (Reel/Story)
npx remotion render src/index.ts QuoteVideo \
  --props='{"quote":"AI non sostituisce, amplifica","author":"Christian Contardi","audioSrc":"../../audio/quote1.mp3","bgColor":"#1a1a2e"}' \
  --width=1080 --height=1920 --fps=30 \
  output/reel_quote.mp4

# Render video 1080x1080 (Feed)
npx remotion render src/index.ts QuoteVideo \
  --props='...' \
  --width=1080 --height=1080 --fps=30 \
  output/feed_quote.mp4

# Render video 1920x1080 (Landscape)
npx remotion render src/index.ts QuoteVideo \
  --props='...' \
  --width=1920 --height=1080 --fps=30 \
  output/landscape_quote.mp4
```

#### Post-processing ffmpeg

```bash
# Aggiungi watermark
ffmpeg -i input.mp4 -i logo.png \
  -filter_complex "overlay=W-w-20:H-h-20" \
  -c:a copy output_watermarked.mp4

# Converti per Instagram (H.264, AAC, max 3500kbps)
ffmpeg -i input.mp4 -c:v libx264 -preset slow -crf 23 \
  -c:a aac -b:a 128k -movflags +faststart \
  -maxrate 3500k -bufsize 7000k output_ig.mp4

# Taglia a 60 secondi
ffmpeg -i input.mp4 -t 60 -c copy output_60s.mp4
```

#### Google Veo (Video AI)

**BLOCCATO per figure umane in EU.** Utilizzabile solo per:
- Sfondi astratti animati
- Transizioni
- B-roll senza persone

```bash
# Quando disponibile:
curl -X POST "https://generativelanguage.googleapis.com/v1beta/models/veo-2.0-generate-001:predictLongRunning" \
  -H "Authorization: Bearer $GOOGLE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "instances": [{"prompt": "Abstract neon particles flowing, tech background, no humans"}],
    "parameters": {"sampleCount": 1, "aspectRatio": "9:16", "durationSeconds": 6}
  }'
```

---

## 3. SETUP PER CANALE

### 3.1 Twitter/X (@AvatarNemo)

**Stato: ✅ ATTIVO E FUNZIONANTE**

#### API
- Endpoint: `https://api.twitter.com/2/tweets`
- Auth: OAuth 1.0a (già configurato in OpenClaw)
- Piano: Free tier (1.500 tweet/mese write, 50 read)

#### Formati supportati
| Tipo | Supportato | Note |
|------|-----------|------|
| Testo | ✅ | Max 280 char |
| Immagine | ✅ | Max 4 img, 5MB PNG/JPEG, 15MB GIF |
| Video | ✅ | Max 512MB, 2:20 durata, MP4 H.264 |
| Carousel | ❌ | Non disponibile via API |
| Thread | ✅ | reply_to_tweet_id per catena |
| Poll | ✅ | Max 4 opzioni, durata 5min-7gg |

#### Upload media
```bash
# Step 1: Upload media
MEDIA_ID=$(curl -s -X POST "https://upload.twitter.com/1.1/media/upload.json" \
  -H "Authorization: OAuth ..." \
  -F "media=@image.png" | jq -r '.media_id_string')

# Step 2: Tweet con media
curl -s -X POST "https://api.twitter.com/2/tweets" \
  -H "Authorization: Bearer $TWITTER_BEARER" \
  -H "Content-Type: application/json" \
  -d "{\"text\":\"Il tweet\",\"media\":{\"media_ids\":[\"$MEDIA_ID\"]}}"
```

#### Rate limits (Free tier)
- 1.500 tweet/mese (POST)
- 50 richieste/15min (GET app-level)
- Upload media: 615 richieste/15min

#### Cosa funziona già
- ✅ Autenticazione
- ✅ Posting testo
- ✅ OpenClaw message tool per Twitter

#### Cosa serve
- Niente, è operativo

---

### 3.2 LinkedIn (Pagina SHAKAZAMBA)

**Stato: 🟡 PARZIALMENTE CONFIGURATO**

#### API
- Endpoint: `https://api.linkedin.com/v2/`
- Auth: OAuth 2.0 (3-legged)
- Client ID: `77vgn2jxff38c9`
- Docs: https://learn.microsoft.com/en-us/linkedin/marketing/

#### Permessi richiesti
Per pubblicare come pagina serve:
- `w_member_social` — post come utente
- `w_organization_social` — post come pagina (SERVE QUESTO)
- `r_organization_social` — leggere post pagina
- `rw_organization_admin` — gestire pagina

**⚠️ IMPORTANTE:** Per `w_organization_social` serve il programma **LinkedIn Marketing Developer Platform**. Bisogna fare application:
- URL: https://www.linkedin.com/developers/apps/{app-id}/products
- Selezionare "Share on LinkedIn" e "Sign In with LinkedIn using OpenID Connect"
- Per posting come Organization serve anche "Community Management API"

#### Flusso Auth
```bash
# Step 1: Redirect utente per autorizzazione
# https://www.linkedin.com/oauth/v2/authorization?response_type=code&client_id=77vgn2jxff38c9&redirect_uri=YOUR_REDIRECT&scope=w_member_social%20w_organization_social%20r_organization_social

# Step 2: Scambia code per access token
curl -s -X POST "https://www.linkedin.com/oauth/v2/accessToken" \
  -d "grant_type=authorization_code" \
  -d "code=AUTH_CODE" \
  -d "client_id=77vgn2jxff38c9" \
  -d "client_secret=CLIENT_SECRET" \
  -d "redirect_uri=YOUR_REDIRECT"

# Token dura 60 giorni, refresh token 365 giorni
```

#### Formati supportati
| Tipo | Supportato | Note |
|------|-----------|------|
| Testo | ✅ | Max 3000 char |
| Immagine | ✅ | Max 1 img inline, JPEG/PNG, 10MB |
| Video | ✅ | Max 200MB, 10min, MP4 |
| Carousel (document) | ✅ | PDF upload (max 300 pagine, 100MB) |
| Article | ✅ | Con URL preview |
| Poll | ✅ | Max 4 opzioni |

#### Post come Organization
```bash
# Post testo come pagina
curl -s -X POST "https://api.linkedin.com/v2/ugcPosts" \
  -H "Authorization: Bearer $LINKEDIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "author": "urn:li:organization:ORGANIZATION_ID",
    "lifecycleState": "PUBLISHED",
    "specificContent": {
      "com.linkedin.ugc.ShareContent": {
        "shareCommentary": {"text": "Il testo del post"},
        "shareMediaCategory": "NONE"
      }
    },
    "visibility": {"com.linkedin.ugc.MemberNetworkVisibility": "PUBLIC"}
  }'
```

#### Rate limits
- 100 post/giorno per pagina
- API calls: 100.000/giorno (app level)

#### Cosa funziona già
- ✅ App registrata (client ID)
- ❓ Token di accesso (da verificare se ancora valido)

#### Cosa serve
- [ ] Verificare/rinnovare access token
- [ ] Verificare permessi `w_organization_social`
- [ ] Ottenere Organization ID della pagina SHAKAZAMBA
- [ ] Testare post come Organization
- [ ] Se Community Management API non approvato → richiedere a LinkedIn

---

### 3.3 Facebook (Pagina SHAKAZAMBA)

**Stato: ❌ DA CONFIGURARE**

#### API
- Endpoint: `https://graph.facebook.com/v19.0/`
- Auth: Page Access Token (long-lived)
- Docs: https://developers.facebook.com/docs/pages-api/

#### Setup richiesto

**Step 1: Creare Facebook Developer App**
1. Vai a https://developers.facebook.com/apps/
2. "Crea App" → Tipo: "Business"
3. Nome: "SHAKAZAMBA Social Publisher"
4. Associa al Business Manager SHAKAZAMBA

**Step 2: Permessi richiesti**
- `pages_manage_posts` — pubblicare post
- `pages_read_engagement` — leggere engagement
- `pages_show_list` — lista pagine
- `pages_manage_metadata` — gestire metadata
- `publish_video` — pubblicare video (richiede App Review!)

**Step 3: Ottenere Page Access Token**
```bash
# 1. Ottieni User Access Token (da Graph API Explorer)
#    https://developers.facebook.com/tools/explorer/
#    Seleziona permessi, genera token

# 2. Scambia per Long-Lived Token (60 giorni)
curl -s "https://graph.facebook.com/v19.0/oauth/access_token?\
grant_type=fb_exchange_token&\
client_id=APP_ID&\
client_secret=APP_SECRET&\
fb_exchange_token=SHORT_LIVED_TOKEN"

# 3. Ottieni Page Access Token (non scade!)
curl -s "https://graph.facebook.com/v19.0/me/accounts?\
access_token=LONG_LIVED_USER_TOKEN"
# → Prendi il token della pagina SHAKAZAMBA dalla risposta
```

#### Formati supportati
| Tipo | Supportato | Note |
|------|-----------|------|
| Testo | ✅ | Nessun limite pratico |
| Immagine | ✅ | JPEG/PNG, max 10MB |
| Video | ✅ | Max 10GB, 240min |
| Reel | ✅ | 3-90 sec, 9:16, via `/PAGE_ID/video_reels` |
| Carousel | ✅ | Multi-photo (non via API standard, serve workaround) |
| Link preview | ✅ | Automatico con URL |
| Story | ❌ | Non disponibile via API per pagine |

#### Pubblicazione
```bash
# Post testo + immagine
curl -s -X POST "https://graph.facebook.com/v19.0/PAGE_ID/photos" \
  -F "message=Testo del post" \
  -F "source=@image.jpg" \
  -F "access_token=PAGE_ACCESS_TOKEN"

# Post Reel
# Step 1: Initialize upload
curl -s -X POST "https://graph.facebook.com/v19.0/PAGE_ID/video_reels" \
  -d "upload_phase=start" \
  -d "access_token=PAGE_ACCESS_TOKEN"

# Step 2: Upload video
curl -s -X POST "https://rupload.facebook.com/video-upload/v19.0/VIDEO_ID" \
  -H "Authorization: OAuth PAGE_ACCESS_TOKEN" \
  -H "file_url=https://example.com/video.mp4"

# Step 3: Publish
curl -s -X POST "https://graph.facebook.com/v19.0/PAGE_ID/video_reels" \
  -d "upload_phase=finish" \
  -d "video_id=VIDEO_ID" \
  -d "description=Descrizione del reel" \
  -d "access_token=PAGE_ACCESS_TOKEN"
```

#### Rate limits
- 200 post/ora per pagina (molto generoso)
- API: 200 chiamate/utente/ora
- Video upload: rate limit separato

#### Cosa serve
- [ ] Creare Facebook Developer App
- [ ] Configurare permessi
- [ ] App Review per `publish_video` (richiede video demo, privacy policy)
- [ ] Ottenere Page Access Token long-lived
- [ ] Page ID della pagina SHAKAZAMBA
- [ ] Testare post

---

### 3.4 Instagram (Business Account SHAKAZAMBA)

**Stato: ❌ DA CONFIGURARE (dipende da Facebook)**

#### API
- Endpoint: `https://graph.facebook.com/v19.0/` (stessa di Facebook!)
- Auth: Page Access Token della pagina Facebook collegata
- Docs: https://developers.facebook.com/docs/instagram-api/

**⚠️ PREREQUISITO:** L'account Instagram deve essere:
1. Account Business o Creator
2. Collegato a una Pagina Facebook
3. La Facebook App deve avere i permessi Instagram

#### Permessi aggiuntivi richiesti
- `instagram_basic` — accesso profilo
- `instagram_content_publish` — pubblicare contenuti
- `instagram_manage_comments` — gestire commenti

#### Formati supportati
| Tipo | Supportato | Endpoint | Note |
|------|-----------|----------|------|
| Immagine singola | ✅ | `/media` | JPEG, max 8MB |
| Carousel | ✅ | `/media` (container) | 2-10 immagini/video |
| Reel | ✅ | `/media` | 3-90sec, 9:16, MP4, max 1GB |
| Story | ❌ | Non disponibile via Content Publishing API | |
| IGTV | Deprecato | — | — |

#### Pubblicazione Immagine
```bash
# Step 1: Crea container
CONTAINER_ID=$(curl -s -X POST \
  "https://graph.facebook.com/v19.0/IG_USER_ID/media" \
  -d "image_url=https://HOSTED_IMAGE_URL/image.jpg" \
  -d "caption=La caption con #hashtag" \
  -d "access_token=PAGE_ACCESS_TOKEN" | jq -r '.id')

# Step 2: Pubblica
curl -s -X POST \
  "https://graph.facebook.com/v19.0/IG_USER_ID/media_publish" \
  -d "creation_id=$CONTAINER_ID" \
  -d "access_token=PAGE_ACCESS_TOKEN"
```

**⚠️ NOTA CRITICA:** Instagram Content Publishing API richiede che le immagini siano accessibili via URL pubblico. Non puoi uploadare file direttamente. Opzioni:
1. Hostare su un server web (es. un bucket S3, Cloudflare R2, o il server stesso)
2. Usare un servizio come imgur (temporaneo)
3. GitHub raw content (per immagini statiche)

#### Pubblicazione Reel
```bash
# Step 1: Crea container video
CONTAINER_ID=$(curl -s -X POST \
  "https://graph.facebook.com/v19.0/IG_USER_ID/media" \
  -d "media_type=REELS" \
  -d "video_url=https://HOSTED_VIDEO_URL/reel.mp4" \
  -d "caption=Caption del reel" \
  -d "share_to_feed=true" \
  -d "access_token=PAGE_ACCESS_TOKEN" | jq -r '.id')

# Step 2: Check status (video processing)
# Aspetta che status sia "FINISHED"
curl -s "https://graph.facebook.com/v19.0/$CONTAINER_ID?fields=status_code&access_token=PAGE_ACCESS_TOKEN"

# Step 3: Pubblica
curl -s -X POST \
  "https://graph.facebook.com/v19.0/IG_USER_ID/media_publish" \
  -d "creation_id=$CONTAINER_ID" \
  -d "access_token=PAGE_ACCESS_TOKEN"
```

#### Pubblicazione Carousel
```bash
# Step 1: Crea container per ogni item
ITEM1=$(curl -s -X POST "https://graph.facebook.com/v19.0/IG_USER_ID/media" \
  -d "image_url=https://URL/slide1.jpg" \
  -d "is_carousel_item=true" \
  -d "access_token=TOKEN" | jq -r '.id')

ITEM2=$(curl -s -X POST "https://graph.facebook.com/v19.0/IG_USER_ID/media" \
  -d "image_url=https://URL/slide2.jpg" \
  -d "is_carousel_item=true" \
  -d "access_token=TOKEN" | jq -r '.id')

# Step 2: Crea carousel container
CAROUSEL=$(curl -s -X POST "https://graph.facebook.com/v19.0/IG_USER_ID/media" \
  -d "media_type=CAROUSEL" \
  -d "children=$ITEM1,$ITEM2" \
  -d "caption=Caption del carousel" \
  -d "access_token=TOKEN" | jq -r '.id')

# Step 3: Pubblica
curl -s -X POST "https://graph.facebook.com/v19.0/IG_USER_ID/media_publish" \
  -d "creation_id=$CAROUSEL" \
  -d "access_token=TOKEN"
```

#### Rate limits
- 25 post/24h per IG account (Content Publishing API)
- 50 API calls/utente/ora

#### Cosa serve
- [ ] Account IG Business collegato a pagina Facebook
- [ ] Stessa Facebook App (vedi sezione 3.3)
- [ ] Permessi `instagram_content_publish` (richiede App Review!)
- [ ] IG User ID (non è lo username, è l'ID numerico)
- [ ] Soluzione per hosting immagini/video (URL pubblici)
- [ ] Testare post immagine e reel

---

## 4. PED (Piano Editoriale Digitale)

### 4.1 Struttura del PED

File: `social/ped.json`

```json
{
  "version": "1.0",
  "brand": "SHAKAZAMBA",
  "themes": [
    {
      "id": "ai-personal",
      "name": "AI Personale",
      "description": "TWIZA Moneypenny, AI agent personale, automazione quotidiana",
      "hashtags": ["#AI", "#PersonalAI", "#Moneypenny", "#TWIZA"]
    },
    {
      "id": "tech-vision",
      "name": "Tech Vision",
      "description": "Futuro della tecnologia, trend AI, opinioni su industry",
      "hashtags": ["#TechVision", "#FutureOfAI", "#Innovation"]
    },
    {
      "id": "behind-scenes",
      "name": "Behind the Scenes",
      "description": "Come costruiamo SHAKAZAMBA, dev diary, problemi e soluzioni",
      "hashtags": ["#BuildInPublic", "#IndieHacker", "#DevDiary"]
    },
    {
      "id": "tips-tutorial",
      "name": "Tips & Tutorial",
      "description": "Come usare AI, prompt engineering, automazione",
      "hashtags": ["#AITips", "#PromptEngineering", "#Automation"]
    },
    {
      "id": "moneypenny-life",
      "name": "La Vita di Moneypenny",
      "description": "Contenuti dalla prospettiva di Moneypenny come entità AI",
      "hashtags": ["#AILife", "#Moneypenny", "#AIAgent"]
    },
    {
      "id": "community",
      "name": "Community & Engagement",
      "description": "Domande, sondaggi, interazione, repost, commenti",
      "hashtags": ["#Community", "#SHAKAZAMBA"]
    }
  ],
  "content_types": [
    {"id": "text-only", "name": "Solo testo", "platforms": ["twitter", "linkedin", "facebook"]},
    {"id": "image-post", "name": "Immagine + testo", "platforms": ["all"]},
    {"id": "carousel", "name": "Carousel/Slides", "platforms": ["instagram", "linkedin"]},
    {"id": "video-short", "name": "Video breve (Reel/Short)", "platforms": ["instagram", "facebook"]},
    {"id": "video-long", "name": "Video lungo", "platforms": ["linkedin", "facebook"]},
    {"id": "audio-clip", "name": "Audio clip", "platforms": ["twitter"]},
    {"id": "thread", "name": "Thread", "platforms": ["twitter"]},
    {"id": "poll", "name": "Sondaggio", "platforms": ["twitter", "linkedin"]},
    {"id": "quote-card", "name": "Quote card", "platforms": ["all"]},
    {"id": "link-share", "name": "Condivisione link", "platforms": ["twitter", "linkedin", "facebook"]}
  ],
  "weekly_schedule": [
    {
      "day": "monday",
      "slots": [
        {"time": "09:30", "theme": "tech-vision", "type": "text-only", "platforms": ["twitter", "linkedin"]},
        {"time": "12:00", "theme": "ai-personal", "type": "image-post", "platforms": ["instagram", "facebook"]}
      ]
    },
    {
      "day": "tuesday",
      "slots": [
        {"time": "10:00", "theme": "tips-tutorial", "type": "carousel", "platforms": ["instagram", "linkedin"]},
        {"time": "14:00", "theme": "tips-tutorial", "type": "thread", "platforms": ["twitter"]}
      ]
    },
    {
      "day": "wednesday",
      "slots": [
        {"time": "09:30", "theme": "behind-scenes", "type": "text-only", "platforms": ["twitter", "linkedin"]},
        {"time": "13:00", "theme": "moneypenny-life", "type": "video-short", "platforms": ["instagram", "facebook"]}
      ]
    },
    {
      "day": "thursday",
      "slots": [
        {"time": "10:00", "theme": "ai-personal", "type": "image-post", "platforms": ["all"]},
        {"time": "15:00", "theme": "community", "type": "poll", "platforms": ["twitter", "linkedin"]}
      ]
    },
    {
      "day": "friday",
      "slots": [
        {"time": "09:30", "theme": "tech-vision", "type": "quote-card", "platforms": ["all"]},
        {"time": "12:00", "theme": "behind-scenes", "type": "video-short", "platforms": ["instagram", "facebook"]}
      ]
    },
    {
      "day": "saturday",
      "slots": [
        {"time": "11:00", "theme": "moneypenny-life", "type": "text-only", "platforms": ["twitter"]}
      ]
    },
    {
      "day": "sunday",
      "slots": []
    }
  ]
}
```

### 4.2 Frequenza Pubblicazione

| Canale | Post/settimana | Tipo principale | Orari migliori |
|--------|---------------|----------------|----------------|
| Twitter/X | 7-10 | Testo, thread, quote | 9:30, 12:00, 18:00 |
| LinkedIn | 3-4 | Testo lungo, carousel, articoli | 9:00-10:00 (Mar-Gio) |
| Facebook | 3-4 | Immagine, video, link | 12:00-14:00 |
| Instagram | 4-5 | Immagine, carousel, reel | 12:00, 18:00 |

### 4.3 Rotazione Temi

Settimana tipo:
```
Lun: Tech Vision + AI Personale
Mar: Tips & Tutorial (educational day)
Mer: Behind the Scenes + Moneypenny Life
Gio: AI Personale + Community
Ven: Tech Vision + Behind the Scenes
Sab: Moneypenny Life (leggero)
Dom: Riposo (o contenuto spontaneo)
```

Ogni 4 settimane:
- Settimana 1: Focus su TWIZA Moneypenny (product)
- Settimana 2: Focus su AI/Tech (thought leadership)
- Settimana 3: Focus su Tutorial/How-to (educational)
- Settimana 4: Focus su Community (engagement, sondaggi, Q&A)

### 4.4 Come il PED Viene Consumato dall'Automazione

```
1. Cron/Heartbeat → Leggi ped.json
2. Trova slot per oggi/ora corrente
3. Per ogni slot:
   a. Genera testo con prompt template + tema
   b. Se serve media → genera immagine/video/audio
   c. Formatta per piattaforma target
   d. Salva in output/ready/ con metadata
   e. Pubblica via API
   f. Logga risultato in logs/publish.log
4. Se errore → retry dopo 30 min, max 3 tentativi
```

File output ready:
```json
{
  "id": "2026-03-05-0930-twitter",
  "scheduled_time": "2026-03-05T09:30:00+01:00",
  "platform": "twitter",
  "theme": "tech-vision",
  "content": {
    "text": "Il testo del tweet...",
    "media": ["social/media/images/2026-03-05-techvision.png"],
    "alt_text": "Descrizione immagine"
  },
  "status": "ready",
  "published_at": null,
  "post_id": null,
  "error": null,
  "retries": 0
}
```

---

## 5. AUTOMAZIONE E SCHEDULING

### 5.1 Pipeline End-to-End

```
[06:00] Cron: generate-daily-content
  ├── Leggi PED → slot di oggi
  ├── Per ogni slot:
  │   ├── Genera testo (Claude via OpenClaw)
  │   ├── Genera media se necessario (DALL-E / Canva / Remotion)
  │   ├── Formatta per piattaforma
  │   └── Salva in output/ready/
  └── Log: "Contenuti generati per oggi: N post"

[Ogni 30 min, 09:00-21:00] Cron: check-and-publish
  ├── Leggi output/ready/ → post con scheduled_time ≤ now AND status=ready
  ├── Per ogni post:
  │   ├── Upload media se presente
  │   ├── Pubblica via API
  │   ├── Se OK → status=published, salva post_id
  │   └── Se ERRORE → status=error, incrementa retries
  └── Se retries < 3 → riprogramma per prossimo check

[21:00] Cron: daily-report
  ├── Conta post pubblicati/falliti oggi
  ├── Salva report in logs/daily/
  └── Notifica Christian se ci sono errori
```

### 5.2 Cron Job Structure

```bash
# Generazione contenuti giornaliera (6:00 AM)
# openclaw cron add --name "social-generate" \
#   --schedule "0 6 * * 1-6" \
#   --command "Leggi social/ped.json, genera i contenuti per oggi, salvali in social/output/ready/"

# Publisher check (ogni 30 min, 9:00-21:00, lun-sab)
# openclaw cron add --name "social-publish" \
#   --schedule "*/30 9-21 * * 1-6" \
#   --command "Controlla social/output/ready/ per post da pubblicare ora. Pubblica quelli con scheduled_time passato e status=ready."

# Report giornaliero (21:30)
# openclaw cron add --name "social-report" \
#   --schedule "30 21 * * 1-6" \
#   --command "Genera report dei post social pubblicati oggi, salvalo in social/logs/daily/"

# Token refresh LinkedIn (ogni 50 giorni)
# openclaw cron add --name "linkedin-refresh" \
#   --schedule "0 8 */50 * *" \
#   --command "Rinnova il token LinkedIn usando il refresh token salvato"
```

**Alternativa via Heartbeat** (più semplice per iniziare):

Aggiungi a `HEARTBEAT.md`:
```markdown
## Social Media Check
- Se ora tra 9:00-21:00 e giorno lun-sab:
  - Controlla social/output/ready/ per post da pubblicare
  - Se ci sono post con scheduled_time ≤ now → pubblica
- Se ora = ~06:00 (prima check del giorno):
  - Genera contenuti per oggi da PED
```

### 5.3 Monitoring e Fallback

#### Logging
```bash
# Struttura log
social/logs/
├── publish.log          # Log continuo di tutte le pubblicazioni
├── errors.log           # Solo errori
└── daily/
    └── 2026-03-05.json  # Report giornaliero
```

#### Formato log entry
```json
{
  "timestamp": "2026-03-05T09:30:15+01:00",
  "action": "publish",
  "platform": "twitter",
  "post_id": "ready/2026-03-05-0930-twitter.json",
  "result": "success",
  "api_response_id": "1897234567890",
  "error": null
}
```

#### Fallback Strategy

| Errore | Azione |
|--------|--------|
| Rate limit (429) | Aspetta `retry-after` header, riprova |
| Auth expired (401) | Logga errore, notifica Christian per refresh token |
| Server error (5xx) | Riprova dopo 5 min, max 3 tentativi |
| Media upload fail | Riprova upload, se fallisce pubblica solo testo |
| API down | Salva post come "pending", riprova al prossimo check |
| Content generation fail | Usa contenuto backup (citazione generica + immagine stock) |

#### Alert a Christian
```bash
# Se errori critici → notifica via canale principale (webchat/telegram)
# "⚠️ Social publisher: 3 post falliti oggi. Twitter auth potrebbe essere scaduto."
```

### 5.4 Gestione Errori Specifica

```bash
# Retry wrapper
publish_with_retry() {
  local post_file="$1"
  local max_retries=3
  local retry=0

  while [ $retry -lt $max_retries ]; do
    result=$(publish_post "$post_file")
    if [ "$result" = "success" ]; then
      return 0
    fi
    retry=$((retry + 1))
    sleep $((60 * retry))  # Backoff: 60s, 120s, 180s
  done

  # Fallback: marca come failed
  jq '.status = "failed"' "$post_file" > tmp && mv tmp "$post_file"
  return 1
}
```

---

## 6. PREREQUISITI E AZIONI RICHIESTE

### 6.1 Cosa Serve da Christian

| # | Azione | Priorità | Tempo stimato | Note |
|---|--------|----------|---------------|------|
| 1 | **Facebook Developer App** — Creare app su developers.facebook.com | 🔴 Alta | 15 min | Serve account developer Facebook |
| 2 | **Facebook Page Access Token** — Autorizzare l'app sulla pagina | 🔴 Alta | 10 min | Dopo step 1, login OAuth |
| 3 | **Facebook App Review** — Submit per `publish_video` e `instagram_content_publish` | 🔴 Alta | 5-15 giorni | Serve privacy policy URL, video demo |
| 4 | **Instagram Business Account** — Verificare che sia collegato a FB Page | 🟡 Media | 5 min | In IG settings → Account → Switch to Business |
| 5 | **LinkedIn Token refresh** — Login per generare nuovo access token | 🟡 Media | 5 min | Se token scaduto |
| 6 | **LinkedIn Organization ID** — Fornire l'ID numerico della pagina | 🟡 Media | 2 min | Da admin page o API |
| 7 | **Hosting per media** — Decidere dove hostare immagini/video (per IG API) | 🟡 Media | 30 min | Opzioni: S3, R2, VPS |
| 8 | **Privacy Policy URL** — Per Facebook App Review | 🟡 Media | 1-2 ore | Pagina web con privacy policy |
| 9 | **OpenAI API Key** — Confermare che è attiva e ha credito per DALL-E | 🟢 Bassa | 2 min | Verificare su platform.openai.com |
| 10 | **ElevenLabs API Key** — Confermare credito disponibile | 🟢 Bassa | 2 min | Verificare su elevenlabs.io |
| 11 | **Brand assets** — Logo SHAKAZAMBA alta risoluzione, colori brand, font | 🟢 Bassa | 10 min | Per template Remotion e grafiche |
| 12 | **Approvazione PED** — Review e approvazione del piano editoriale proposto | 🟢 Bassa | 15 min | Sezione 4 di questo documento |

### 6.2 Cosa Configuro Io (Moneypenny)

| # | Azione | Dipende da | Tempo stimato |
|---|--------|-----------|---------------|
| 1 | Creare struttura directory `social/` | Niente | 5 min |
| 2 | Creare `social/ped.json` con piano editoriale | Approvazione PED (#12) | 30 min |
| 3 | Setup Remotion project con template base | Niente | 2 ore |
| 4 | Script pubblicazione Twitter (già funzionante) | Niente | 30 min |
| 5 | Script pubblicazione LinkedIn | Token LinkedIn (#5), Org ID (#6) | 1 ora |
| 6 | Script pubblicazione Facebook | FB App (#1), Page Token (#2) | 1 ora |
| 7 | Script pubblicazione Instagram | FB App Review (#3), Hosting (#7) | 2 ore |
| 8 | Pipeline generazione immagini (DALL-E + ffmpeg) | OpenAI key (#9) | 1 ora |
| 9 | Pipeline generazione audio (ElevenLabs) | ElevenLabs key (#10) | 30 min |
| 10 | Pipeline generazione video (Remotion + ffmpeg) | Step 3 | 2 ore |
| 11 | Cron job / heartbeat scheduling | Tutti gli step sopra | 1 ora |
| 12 | Testing end-to-end per canale | Tutto | 2 ore |
| 13 | Setup monitoring e alerting | Step 11 | 30 min |

### 6.3 Timeline Stimata

```
Settimana 1 (5-12 Mar):
├── ✅ Piano operativo (questo documento)
├── 🔲 Christian: Crea FB Developer App, verifica IG Business
├── 🔲 Moneypenny: Struttura directory, PED draft, template Remotion
├── 🔲 Moneypenny: Pipeline Twitter completa (già quasi pronta)

Settimana 2 (12-19 Mar):
├── 🔲 Christian: FB App Review submit, LinkedIn token, hosting media
├── 🔲 Moneypenny: Pipeline LinkedIn
├── 🔲 Moneypenny: Pipeline immagini + audio
├── 🔲 Moneypenny: Primi test Twitter automatici

Settimana 3 (19-26 Mar):
├── 🔲 Moneypenny: Pipeline Facebook (se token ottenuto)
├── 🔲 Moneypenny: Pipeline video (Remotion)
├── 🔲 Moneypenny: Testing cross-platform

Settimana 4 (26 Mar - 2 Apr):
├── 🔲 (attesa FB App Review se non ancora approvato)
├── 🔲 Moneypenny: Pipeline Instagram
├── 🔲 Moneypenny: Cron job finali
├── 🔲 GO LIVE: Pubblicazione automatica su tutti i canali
```

**MVP (Minimum Viable Pipeline):** Twitter + LinkedIn + immagini DALL-E → 2 settimane
**Full Pipeline:** Tutti i canali + video → 4 settimane

### 6.4 Costi Stimati Mensili

| Servizio | Uso stimato | Costo/mese |
|----------|------------|------------|
| OpenAI DALL-E 3 | ~60 immagini/mese (HD) | ~$4-5 |
| ElevenLabs TTS | ~30.000 char/mese | ~$5-10 (piano Starter) |
| Twitter API | Free tier | $0 |
| LinkedIn API | Gratuito | $0 |
| Facebook/IG API | Gratuito | $0 |
| Canva | Piano esistente | $0 extra |
| Media hosting (Cloudflare R2) | ~5GB/mese | ~$0.75 |
| **TOTALE STIMATO** | | **~$10-16/mese** |

**Nota:** Se il volume aumenta significativamente (es. video quotidiani con TTS), il costo ElevenLabs potrebbe salire a $22-99/mese.

---

## 7. LIMITAZIONI E RISCHI

### 7.1 Cosa NON Posso Fare

| Limitazione | Motivo | Workaround |
|-------------|--------|------------|
| **Stories Instagram** | API non supporta stories per pagine | Manuale o tool terzo (Later, Buffer) |
| **Stories Facebook** | Stessa limitazione | Manuale |
| **Direct Messages** | API non supporta DM automation su IG/FB | Manuale |
| **Video con figure umane (Veo)** | Bloccato in EU | Usare solo per sfondi/astratto |
| **Carousel Facebook** | Supporto API limitato | Multi-photo post come alternativa |
| **Instagram senza URL pubblici** | API richiede URL per media | Serve hosting (R2/S3) |
| **Engagement automatico** (like, commenti altrui) | Contro ToS di tutte le piattaforme | Solo pubblicazione, engagement manuale |
| **A/B testing nativo** | Non supportato dalle API | Tracking manuale con varianti |
| **Analytics cross-platform** | Ogni API ha i suoi endpoint | Dashboard custom (futuro) |

### 7.2 Rischi Tecnici

| Rischio | Probabilità | Impatto | Mitigazione |
|---------|------------|---------|-------------|
| **Facebook App Review rifiutato** | Media | Alto — blocca FB + IG | Preparare demo video perfetta, privacy policy completa |
| **Token scaduto** | Alta | Medio — blocca 1 canale | Alert automatico, refresh proattivo |
| **Rate limit Twitter Free** | Media | Basso — 1500/mese è sufficiente | Monitorare conteggio, non superare 10/giorno |
| **LinkedIn Community API negato** | Bassa | Alto — solo post come utente | Postare come Christian (profilo personale) come fallback |
| **Qualità contenuti AI** | Media | Medio — brand reputation | Review manuale prima settimana, poi sample random |
| **Costi ElevenLabs sforano** | Bassa | Basso — budget modesto | Monitorare character count, cache audio riutilizzabili |
| **Remotion render lento su WSL** | Media | Basso — solo ritardo | Pre-render di notte, cache template |
| **Cambio API (breaking changes)** | Bassa | Alto — pipeline rotta | Pinning versioni API, monitoring errori |
| **Shadow ban per posting troppo automatico** | Bassa | Alto | Variare orari ±15min, tono naturale, mix manuale/auto |
| **OpenClaw downtime** | Bassa | Alto — tutto fermo | Heartbeat fallback, retry built-in |

### 7.3 Dipendenze Critiche

```
CRITICA (bloccante):
├── Facebook Developer App + App Review → Blocca Facebook + Instagram
├── Hosting media pubblico → Blocca Instagram
└── LinkedIn Organization permissions → Blocca posting come pagina

IMPORTANTE (degradante):
├── OpenAI API key attiva → Fallback: solo testo, no immagini
├── ElevenLabs API key → Fallback: no audio/voiceover
└── Node.js + Remotion → Fallback: no video generati

NICE-TO-HAVE:
├── Google Veo → Solo per B-roll astratti
├── Canva API → Alternativa a DALL-E per template
└── Manus.im → Futuro, non ancora disponibile
```

---

## 8. QUICK START — Primi 3 Passi

### Passo 1: Crea la struttura (Moneypenny, oggi)
```bash
mkdir -p social/{schedules,content/drafts,media/{images,audio,video,templates},output/ready,logs/daily,scripts,templates/prompts}
```

### Passo 2: Inizia con Twitter (Moneypenny, questa settimana)
- Pipeline già funzionante
- Genera 1 post/giorno da PED
- Test per 1 settimana

### Passo 3: Christian, azione richiesta
1. Vai su https://developers.facebook.com/apps/ → Crea App
2. Vai su settings LinkedIn app → verifica token
3. Dimmi l'Organization ID LinkedIn
4. Approva il PED (sezione 4)

---

*Piano generato da Moneypenny il 2026-03-05. Aggiornamento: ad ogni milestone completata.*
