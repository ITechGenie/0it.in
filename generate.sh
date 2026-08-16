#!/usr/bin/env bash
# =============================================================
# generate.sh — 0it.in product page generator
# Requires: bash, python3 (no jq needed)
#
# Usage:
#   ./generate.sh --all
#   ./generate.sh --product <slug>
#   ./generate.sh --new --slug <s> --name <n> [options]
#
# Options for --new:
#   --category  "CATEGORY LABEL"
#   --tagline   "Short tagline"
#   --accent    "#hexcolor"
#   --cta       "Button Text"
#   --logo      "../assets/Logo.png"
#   --url       "https://product.com"
#   --shorturl  "https://links.0it.in/slug/"
# =============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRODUCTS_JSON="$SCRIPT_DIR/products.json"
TPL_DIR="$SCRIPT_DIR/tpl"
BACKUP_DIR="$SCRIPT_DIR/backup"

# ---------- Python JSON helper ----------
# Usage: py_json <json_file> <python_expression>
# The expression receives `data` as the parsed JSON object.
py_json() {
  python3 -c "
import json, sys
with open('$1', 'r', encoding='utf-8') as f:
    data = json.load(f)
print($2)
"
}

# Get a value from products.json at the site level
site_val() {
  py_json "$PRODUCTS_JSON" "data['site']['$1']"
}

# Get a value from a specific product by slug
product_val() {
  local slug="$1" key="$2"
  py_json "$PRODUCTS_JSON" "next(p for p in data['products'] if p['slug']=='$slug')['$key']"
}

# Get number of links for a product
product_link_count() {
  py_json "$PRODUCTS_JSON" "len(next(p for p in data['products'] if p['slug']=='$1')['links'])"
}

# Get a link field for a product at index i
product_link_field() {
  local slug="$1" idx="$2" field="$3"
  py_json "$PRODUCTS_JSON" "next(p for p in data['products'] if p['slug']=='$slug')['links'][$idx]['$field']"
}

# Get all slugs
all_slugs() {
  py_json "$PRODUCTS_JSON" "'\n'.join(p['slug'] for p in data['products'])"
}

# Check if a slug exists
slug_exists() {
  py_json "$PRODUCTS_JSON" "str(any(p['slug']=='$1' for p in data['products'])).lower()"
}

# ---------- Timestamp ----------
timestamp() { date +"%Y%m%d_%H%M%S"; }

# ---------- Backup a product folder ----------
backup_product() {
  local slug="$1"
  local src="$SCRIPT_DIR/$slug"
  if [[ -d "$src" ]]; then
    local ts; ts=$(timestamp)
    local dest="$BACKUP_DIR/${slug}_${ts}"
    mkdir -p "$dest"
    cp -r "$src/." "$dest/"
    echo "  [backup] $slug/ → backup/${slug}_${ts}/"
  fi
}

# ---------- Read a template file ----------
read_tpl() { cat "$TPL_DIR/$1"; }

# ---------- Replace all instances of a placeholder ----------
# Using python3 for reliable multi-line / special-char replacement
replace_placeholder() {
  local content="$1" key="$2" value="$3"
  python3 -c "
import sys
content = sys.stdin.read()
sys.stdout.write(content.replace('{{$key}}', sys.argv[1]))
" "$value" <<< "$content"
}

# ---------- Build <head> partial ----------
build_head() {
  local title="$1" description="$2" favicon="$3" css_path="$4" amp_key="$5"
  local tpl; tpl=$(read_tpl "partials/head.tpl")
  tpl=$(replace_placeholder "$tpl" "TITLE"         "$title")
  tpl=$(replace_placeholder "$tpl" "DESCRIPTION"   "$description")
  tpl=$(replace_placeholder "$tpl" "FAVICON_URL"   "$favicon")
  tpl=$(replace_placeholder "$tpl" "CSS_PATH"      "$css_path")
  tpl=$(replace_placeholder "$tpl" "AMPLITUDE_KEY" "$amp_key")
  echo "$tpl"
}

# ---------- Build footer partial ----------
build_footer() {
  local owner="$1" owner_url="$2"
  local tpl; tpl=$(read_tpl "partials/footer.tpl")
  tpl=$(replace_placeholder "$tpl" "OWNER"     "$owner")
  tpl=$(replace_placeholder "$tpl" "OWNER_URL" "$owner_url")
  echo "$tpl"
}

# ---------- Build one link button ----------
build_link_btn() {
  local icon="$1" label="$2" url="$3" icon_base="$4"
  local tpl; tpl=$(read_tpl "partials/link-btn.tpl")
  tpl=$(replace_placeholder "$tpl" "LINK_URL"   "$url")
  tpl=$(replace_placeholder "$tpl" "LINK_LABEL" "$label")
  tpl=$(replace_placeholder "$tpl" "ICON_PATH"  "${icon_base}${icon}.svg")
  echo "$tpl"
}

# ---------- Generate a single product page ----------
generate_product() {
  local slug="$1"
  echo "→ Generating: $slug"

  # Verify slug exists
  local exists; exists=$(slug_exists "$slug")
  if [[ "$exists" != "true" ]]; then
    echo "  ERROR: Product '$slug' not found in products.json" >&2
    return 1
  fi

  # Read all fields
  local name;        name=$(product_val "$slug" "name")
  local category;    category=$(product_val "$slug" "category")
  local tagline;     tagline=$(product_val "$slug" "tagline")
  local description; description=$(product_val "$slug" "description")
  local accent;      accent=$(product_val "$slug" "accentColor")
  local logo;        logo=$(product_val "$slug" "logo")
  local favicon;     favicon=$(site_val "favicon")
  local amp_key;     amp_key=$(py_json "$PRODUCTS_JSON" "data['site']['analytics']['amplitude']")
  local owner;       owner=$(site_val "owner")
  local owner_url;   owner_url=$(site_val "ownerUrl")

  # Backup existing output folder
  backup_product "$slug"

  # Ensure product folder exists
  mkdir -p "$SCRIPT_DIR/$slug"

  # Build all link buttons
  local links_html=""
  local count; count=$(product_link_count "$slug")
  for (( i=0; i<count; i++ )); do
    local icon label url
    icon=$(product_link_field  "$slug" "$i" "icon")
    label=$(product_link_field "$slug" "$i" "label")
    url=$(product_link_field   "$slug" "$i" "url")
    links_html+=$(build_link_btn "$icon" "$label" "$url" "../assets/")
    links_html+=$'\n'
  done

  # Build partials
  local head_html; head_html=$(build_head \
    "$name — 0it.in" "$description" "$favicon" "../assets/style.css" "$amp_key")
  local footer_html; footer_html=$(build_footer "$owner" "$owner_url")

  # Render main template
  local page; page=$(read_tpl "subproduct.tpl")
  page=$(replace_placeholder "$page" "HEAD"         "$head_html")
  page=$(replace_placeholder "$page" "ACCENT_COLOR" "$accent")
  page=$(replace_placeholder "$page" "PRODUCT_NAME" "$name")
  page=$(replace_placeholder "$page" "CATEGORY"     "$category")
  page=$(replace_placeholder "$page" "TAGLINE"      "$tagline")
  page=$(replace_placeholder "$page" "LOGO_PATH"    "$logo")
  page=$(replace_placeholder "$page" "LINKS"        "$links_html")
  page=$(replace_placeholder "$page" "FOOTER"       "$footer_html")

  printf '%s\n' "$page" > "$SCRIPT_DIR/$slug/index.html"
  echo "  ✓ Written → $slug/index.html"
}

# ---------- Add a new product entry to products.json ----------
add_new_product() {
  local slug="$1" name="$2" category="$3" tagline="$4"
  local accent="$5" cta="$6" logo="$7" url="$8" shorturl="$9"

  local exists; exists=$(slug_exists "$slug")
  if [[ "$exists" == "true" ]]; then
    echo "  ERROR: Product '$slug' already exists in products.json." >&2
    return 1
  fi

  # Backup products.json first
  mkdir -p "$BACKUP_DIR"
  local ts; ts=$(timestamp)
  cp "$PRODUCTS_JSON" "$BACKUP_DIR/products.json_${ts}"
  echo "  [backup] products.json → backup/products.json_${ts}"

  # Append new product via python3
  python3 -c "
import json, sys

with open('$PRODUCTS_JSON', 'r', encoding='utf-8') as f:
    data = json.load(f)

data['products'].append({
    'slug':        '$slug',
    'name':        '$name',
    'category':    '$category',
    'tagline':     '$tagline',
    'description': '$tagline',
    'accentColor': '$accent',
    'ctaText':     '$cta',
    'logo':        '$logo',
    'url':         '$url',
    'shortUrl':    '$shorturl',
    'links':       []
})

with open('$PRODUCTS_JSON', 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
print('  ✓ Added to products.json')
"
}

# ---------- Parse arguments ----------
MODE=""
TARGET_SLUG=""
NEW_SLUG="" NEW_NAME="" NEW_CAT="PRODUCT" NEW_TAGLINE=""
NEW_ACCENT="#6366f1" NEW_CTA="Visit" NEW_LOGO="../assets/Profile.jpeg"
NEW_URL="#" NEW_SHORTURL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)       MODE="all" ;;
    --product)   MODE="one";  TARGET_SLUG="${2:-}"; shift ;;
    --new)       MODE="new" ;;
    --slug)      NEW_SLUG="${2:-}";     shift ;;
    --name)      NEW_NAME="${2:-}";     shift ;;
    --category)  NEW_CAT="${2:-}";      shift ;;
    --tagline)   NEW_TAGLINE="${2:-}";  shift ;;
    --accent)    NEW_ACCENT="${2:-}";   shift ;;
    --cta)       NEW_CTA="${2:-}";      shift ;;
    --logo)      NEW_LOGO="${2:-}";     shift ;;
    --url)       NEW_URL="${2:-}";      shift ;;
    --shorturl)  NEW_SHORTURL="${2:-}"; shift ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
  shift
done

# ---------- Ensure backup root exists ----------
mkdir -p "$BACKUP_DIR"

# ---------- Run ----------
case "$MODE" in
  all)
    echo "Generating all products..."
    while IFS= read -r s; do
      [[ -n "$s" ]] && generate_product "$s"
    done <<< "$(all_slugs)"
    echo "Done."
    ;;

  one)
    [[ -z "$TARGET_SLUG" ]] && { echo "ERROR: --product requires a slug." >&2; exit 1; }
    generate_product "$TARGET_SLUG"
    echo "Done."
    ;;

  new)
    [[ -z "$NEW_SLUG" || -z "$NEW_NAME" ]] && {
      echo "ERROR: --new requires at least --slug and --name." >&2; exit 1
    }
    [[ -z "$NEW_SHORTURL" ]] && NEW_SHORTURL="https://links.0it.in/$NEW_SLUG/"
    echo "Adding new product: $NEW_SLUG..."
    add_new_product "$NEW_SLUG" "$NEW_NAME" "$NEW_CAT" "$NEW_TAGLINE" \
                    "$NEW_ACCENT" "$NEW_CTA" "$NEW_LOGO" "$NEW_URL" "$NEW_SHORTURL"
    generate_product "$NEW_SLUG"
    echo ""
    echo "Done. Edit products.json to add social links for '$NEW_SLUG', then run:"
    echo "  ./generate.sh --product $NEW_SLUG"
    ;;

  *)
    echo ""
    echo "Usage:"
    echo "  ./generate.sh --all"
    echo "  ./generate.sh --product <slug>"
    echo "  ./generate.sh --new --slug <slug> --name \"Name\" [options]"
    echo ""
    echo "Options for --new:"
    echo "  --category  \"CATEGORY LABEL\""
    echo "  --tagline   \"Short tagline\""
    echo "  --accent    \"#hexcolor\""
    echo "  --cta       \"Button Text\""
    echo "  --logo      \"../assets/Logo.png\""
    echo "  --url       \"https://product.com\""
    echo "  --shorturl  \"https://links.0it.in/slug/\""
    echo ""
    echo "Requires: bash, python3 (no jq needed)"
    exit 0
    ;;
esac
