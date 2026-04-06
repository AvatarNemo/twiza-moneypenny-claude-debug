# TWIZA Moneypenny — Branding & Design Guidelines

*...more than an agent!*

---

## Logo

### TWIZA Wordmark
- **Font**: DK Jambo (bold, display weight)
- The word "TWIZA" is always set in DK Jambo
- Minimum clear space: height of the "T" character on all sides

### "Moneypenny" Identifier
- **Font**: Titillium Web (SemiBold or Bold)
- Displayed adjacent to or below the TWIZA wordmark
- Never in DK Jambo — always Titillium for numeric/technical elements

### Logo Variants
| File | Usage |
|------|-------|
| `twiza-white.png` / `twiza.svg` | Dark backgrounds (primary) |
| `twiza-black.png` | Light backgrounds |
| `twiza-icon.png` | Square icon, favicons, avatars |
| `twiza-logo-text.png` | Full logo with text |
| `twiza-logo-only.png` | Logomark without text |
| `twiza-fade.png` | Gradient/fade variant for overlays |

### SHAKAZAMBA Parent Brand
- `shakazamba-logo.png` — full color
- `shakazamba-logo-black.png` — monochrome
- `shakazamba-logo-gamma.png` — gamma-corrected variant
- Used in footer/credits: "TWIZA by SHAKAZAMBA"

---

## Color Palette

### Primary
| Name | Hex | Usage |
|------|-----|-------|
| **TWIZA Fuchsia** | `#D4006A` | Primary accent, CTAs, active states |
| **TWIZA Purple** | `#6600FF` | Secondary accent, links, hover |
| **SHAKAZAMBA Green** | `#5EC900` | Success states, confirmations |

### Backgrounds
| Name | Hex | Usage |
|------|-----|-------|
| **Deep Black** | `#010205` | Main background |
| **Dark Navy** | `#050913` | Card/panel backgrounds |
| **Dark Gray** | `#0D111A` | Secondary panels |
| **Medium Dark** | `#171420` | Elevated surfaces |
| **Card Gray** | `#2A2E36` | Input fields, cards |

### Text
| Name | Hex | Usage |
|------|-----|-------|
| **White** | `#FFFFFF` | Primary text |
| **Light Gray** | `#74727B` | Secondary text, labels |
| **Muted** | `#54595F` | Disabled, placeholder |

### Accent
| Name | Hex | Usage |
|------|-----|-------|
| **Orange Warm** | `#FFBC7D` | Warnings, badges |
| **Cyan/Teal** | `#6EC1E4` | Info, alt links |
| **Dark Purple** | `#370039` | Gradients |

### Gradients
- **Primary**: `linear-gradient(135deg, #D4006A, #6600FF)` — buttons, headers
- **Background**: `linear-gradient(180deg, #010205, #050913, #0D111A)` — page bg
- **Accent**: `linear-gradient(135deg, #440c2a, #370039)` — hover cards

---

## Typography

### Brand / Display
- **Font**: DK Jambo
- **Usage**: Logo, headings, splash screens, marketing
- **Weight**: Bold only
- **Never** use for body text or UI labels

### UI / Body
- **Font**: Titillium Web
- **Weights**: Regular (400), SemiBold (600), Bold (700)
- **Usage**: All UI text, navigation, buttons, form labels, body copy
- **Fallback**: Inter, system-ui, sans-serif

### Sizing
| Element | Size |
|---------|------|
| H1 | 2.5rem |
| H2 | 1.8rem |
| H3 | 1.3rem |
| Body | 1rem |
| Small / Caption | 0.85rem |

---

## Tone of Voice

Reference: [STYLE-GUIDE.md](../STYLE-GUIDE.md)

- **Professional but approachable** — never corporate-stiff, never too casual
- **Tech-forward** — confident about AI without hype
- **Privacy-first** — emphasize user control, local-first, no data harvesting
- **European identity** — Italian roots, EU compliance, GDPR-aware
- **Empowering** — the user is in control, TWIZA is their tool

### Payoff
> **...more than an agent!**

Always preceded by ellipsis. Used in:
- Splash screens, installer, about dialogs
- Marketing, landing pages, social
- Tray tooltip: "TWIZA Moneypenny — ...more than an agent!"

---

## Icon Guidelines

### App Icon (`icon.ico`, `icon.png`)
- Full-color TWIZA logomark on transparent background
- Sizes: 16×16, 24×24, 32×32, 48×48, 64×64, 128×128, 256×256, 512×512, 1024×1024
- ICO file bundles: 16, 32, 48, 256
- Located in `src-tauri/icons/`

### Tray Icon (`tray-icon.png`)
- Simplified monochrome or high-contrast version
- Must be legible at 16×16 and 24×24
- Light icon for dark system trays (Windows default)

### Installer Icon
- Uses `icon.ico` for NSIS/MSI
- Sidebar image (optional): 164×314 BMP for NSIS wizard

### Favicon
- 32×32 PNG or ICO from `twiza-icon.png`
- Used in all HTML pages served by the app

---

## Do's and Don'ts

### ✅ Do
- Use the fuchsia/purple gradient for primary actions
- Keep generous whitespace — the dark theme needs breathing room
- Use DK Jambo **only** for the brand name "TWIZA"
- Include the payoff "...more than an agent!" in key touchpoints
- Credit "TWIZA by SHAKAZAMBA" in about/footer
- Use high-contrast text on dark backgrounds
- Test all UI at 125% and 150% DPI scaling

### ❌ Don't
- Don't use DK Jambo for body text or UI elements
- Don't place the logo on busy/patterned backgrounds
- Don't stretch, rotate, or recolor the logo
- Don't use light backgrounds as primary — TWIZA is a dark-theme-first brand
- Don't abbreviate "TWIZA Moneypenny" to just "Moneypenny" in isolation
- Don't mix the fuchsia and green in the same gradient
- Don't use the SHAKAZAMBA logo without "TWIZA by" context
