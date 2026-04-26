# Lume Brand System

## Name

**Lume.** Lowercase only — `lume`. Never "LUME". Never "LumeApp" in copy.

## Positioning

Serious tooling, not a candy app. Lume sits next to System Settings,
not next to a kids' game. The brand reads quiet, technical, deliberate.

## Voice

- Calm, precise, light-touch.
- Product, not utility — write copy as if introducing a thing, not
  explaining a feature.
- Examples:
  - **Yes:** "A clipboard, lit."
  - **Yes:** "Everything you've copied, on every Mac you own."
  - **No:** "The best clipboard manager for Mac." (generic)
  - **No:** "Clipboard manager with iCloud support." (utility framing)

## Logo

| File | Usage |
|---|---|
| `assets/logo-mark.svg` | Square icon, app icon source, favicon, social avatar. |
| `assets/logo.svg` | Full wordmark — mark + "lume" type. README, site, About. |
| `assets/menubar-template.svg` | Monochrome menu-bar glyph. macOS auto-tints (Template image). |
| `assets/social-card.svg` | 1200×630 OG/Twitter card. |

### Concept

A capital **L** set inside a soft, near-black tile. The L stands for
*Lume* and reads as a pane catching light. A single restrained spark
sits at the foot of the L. **No rainbow gradients.** The brand is
monochrome with one tasteful accent.

### Construction (mark, 256-grid)

- Tile: vertical gradient from `#1A1C26` → `#0E0F14`. Corner radius 58.
- Inner rim: 1 px white at **8 %** alpha (subtle, not shiny).
- L: solid `#F4F1FF`, two rounded rectangles, optically centred. Vertical
  bar 24 × 132 px at (78, 60); horizontal bar 108 × 24 px at (78, 168).
- Spark: a single radial-gradient bloom at (186, 180), radius 22. Inner
  alpha 0.85 → outer 0. No coloured stops.

### Wordmark alignment rules

Wordmark canvas is 760 × 200. Mark sits at `translate(20, 20) scale(0.625)`,
160 px tall, vertically centred at `y = 100`. Type baseline anchored
with `dominant-baseline="central"` so the cap-block centres on the same
mid-line as the mark. Letter-spacing −3 at display sizes; flatten to
−2 at body sizes.

### Don't

- Don't reintroduce cyan/rose/lavender gradients — that was the old
  candy palette.
- Don't add a drop shadow. The dark tile is the depth.
- Don't outline the wordmark.
- Don't recolour the L. It's `#F4F1FF`. Not white. Not lavender.

## Color

| Token | Hex | Use |
|---|---|---|
| `lume.indigo` | `#6E63FF` | The single accent. Selection, primary buttons, active state. Use sparingly. |
| `lume.slate`  | `#1A1C26` | Tile top, surface gradient start. |
| `lume.ink`    | `#0E0F14` | Tile bottom, dark surface base, marketing background. |
| `lume.bone`   | `#F4F1FF` | Type on dark. The L itself. |
| `lume.mist`   | `#9690B8` | Secondary type on dark. |

The app itself defers to the system's Liquid Glass tinting. The accent
is exposed as a single user-tunable token (`indigo` is the default);
everything else (light/dark, contrast, vibrancy) is the system's.

## Type

- **App UI**: SF Pro (system), all sizes.
- **Marketing site / docs**: Inter or SF Pro Rounded with Inter
  fallback.
- **Wordmark**: SF Pro Rounded, semibold, letter-spacing −3 at the
  display size.

## Voice patterns

- "A clipboard, lit." — primary tagline.
- "Everything you've copied, on every Mac you own." — sync-focused variant.
- "Faster than you copied it." — perf-focused variant.
