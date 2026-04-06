# UI Patches — Da riapplicare dopo ogni aggiornamento OpenClaw

Tutte le modifiche custom alla webchat di OpenClaw.
**Directory target:** `/home/chris/.nvm/versions/node/v24.13.1/lib/node_modules/openclaw/dist/control-ui/`

## 1. Titolo pagina
In `index.html`, cambiare `<title>` da default a:
```html
<title>MONEYPENNY</title>
```

## 2. Favicon (logo Twiza)
I file favicon originali sono backuppati con estensione `.bak`.
Sovrascrivere con i nostri:
- `favicon.svg` → logo Twiza
- `favicon-32.png` → logo Twiza 32x32
- `favicon.ico` → logo Twiza

**Sorgenti backup:** `ui-patches/favicon/`

## 3. Avatar utente (Christian DreamWorks)
Copiare l'immagine DreamWorks di Christian come avatar:
```
cp media/christian/05-dreamworks-avatar.jpg → assets/user-avatar.jpg
```
E in `index.html` aggiungere nel `<style>`:
```css
.chat-avatar.user {
  background-image: url('./assets/user-avatar.jpg') !important;
  background-size: cover !important;
  background-position: center !important;
  color: transparent !important;
}
```

## 4. Font size +15%
In `index.html` aggiungere nel `<style>`:
```css
.message-content, .message-content p, .message-content li, .message-content code {
  font-size: 1.265rem !important;
  line-height: 1.6 !important;
}
```

## 5. Config (non sovrascritta da update)
Queste sono nel config OpenClaw e sopravvivono agli aggiornamenti:
- `ui.assistant.name: "Moneypenny"`
- `ui.assistant.avatar: "🦾"`
