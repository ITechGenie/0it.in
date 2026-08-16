# 0it.in — Portfolio Site

A static HTML/CSS/JS portfolio hub hosted at [0it.in](https://0it.in).

## Structure

```
0it.in/
├── assets/           Shared CSS, images, and SVG icons
├── tpl/              HTML templates (edit here, never in generated files)
│   ├── partials/     head.tpl, footer.tpl, link-btn.tpl
│   └── subproduct.tpl
├── backup/           Auto-created backups before any regeneration
├── products.json     Single source of truth for all product metadata
├── generate.sh       Generator script (requires bash + jq)
├── index.html        Home page (do not generate — edit directly)
├── adayastory/       Generated sub-product page
├── itechgenie/       Generated sub-product page
└── myculinarygalaxy/ Generated sub-product page
```

## Adding a new sub-product

```bash
./generate.sh --new \
  --slug   "dodl" \
  --name   "Dodl" \
  --category "CREATIVE TOOLS" \
  --tagline  "Quick sketches and visual ideas." \
  --accent   "#f97316" \
  --cta      "Launch Dodl" \
  --url      "https://dodl.in" \
  --shorturl "https://links.0it.in/dodl/"
```

Then edit `products.json` to add social links for `dodl`, and regenerate:

```bash
./generate.sh --product dodl
```

## Regenerating all products

```bash
./generate.sh --all
```

## Regenerating one product

```bash
./generate.sh --product itechgenie
```

> Existing files are automatically backed up to `backup/<slug>_<timestamp>/` before any write.

## Dependencies for generate.sh

- **bash** — via WSL (Windows Subsystem for Linux)
- **python3** — ships with WSL, no extra install needed. No `jq` required.

## Running on Windows

Use `generate.bat` — just double-click it or run from any terminal:

```bat
generate.bat --all
generate.bat --product itechgenie
generate.bat --new --slug dodl --name "Dodl" --accent "#f97316" --cta "Launch Dodl"
```

The `.bat` auto-converts the Windows path to a WSL mount path and delegates to `generate.sh`. Requires WSL to be installed.

## Running on Mac / Linux

```bash
bash generate.sh --all
bash generate.sh --product itechgenie
bash generate.sh --new --slug dodl --name "Dodl" --accent "#f97316" --cta "Launch Dodl"
```

## Design system

All products share `assets/style.css`. Per-product accent color is set via CSS custom property `--accent`
on the `<body>` element (e.g. `<body style="--accent: #a855f7;">`).

To update the design, edit `assets/style.css` and `tpl/subproduct.tpl`, then regenerate all products.
