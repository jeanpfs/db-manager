# Session Setup — Step by Step

Run these steps at the start of every session.

## Step 1 — Identify current project

```bash
PROJECT=$(basename "$PWD" | tr -cd 'a-zA-Z0-9._-')
SESSION_FILE="/tmp/.db_session_$(echo "$PWD" | md5 -q 2>/dev/null || echo "$PWD" | md5sum | cut -c1-8)"
```

## Step 2 — Find available connections

**A) Entries in db-map.json for this project:**

```bash
MAP_FILE="$HOME/.claude/db-map.json"
if [ -f "$MAP_FILE" ]; then
  jq -r --arg proj "$PROJECT" '
    to_entries[] |
    select(.key | test($proj; "i")) |
    .key as $pname |
    .value | to_entries[] |
    "\($pname)/\(.key): \(.value)"
  ' "$MAP_FILE" 2>/dev/null | while IFS= read -r line; do
    envpath=$(echo "$line" | sed 's/.*: //')
    status="NOT FOUND"; [ -f "$envpath" ] && status="found"
    echo "$line [$status]"
  done
else
  echo "MAP_EMPTY"
fi
```

**B) Fallback — detect .env files in current project (works for monorepos):**

```bash
find . \( -name ".env" -o -name ".env.local" -o -name ".env.development" -o -name ".env.dev" \
  -o -name ".env.staging" -o -name ".env.production" \) \
  -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | while read -r f; do
  match=$(grep -E "^(DATABASE_URL|DB_URL|POSTGRES_URL)" "$f" 2>/dev/null | head -1)
  [ -n "$match" ] && echo "$f"
done
```

## Step 3 — Present options and ask

Show all discovered connections numbered, plus a manual entry option.
Ask: **"Which connection should be used for this session?"**

## Step 4 — Load credentials and save session to /tmp

```bash
ENV_PATH="<selected .env path>"
DB_URL=$(grep -E "^(DATABASE_URL|DB_URL|POSTGRES_URL)" "$ENV_PATH" | head -1 | cut -d= -f2- | sed 's/^["'\'']\|["'\''"]$//g')

(umask 077; cat > "$SESSION_FILE" << EOF
DATABASE_URL=${DB_URL}
DB_LABEL=${PROJECT}/<selected-label>
DB_SOURCE=${ENV_PATH}
EOF
)
```

## Step 5 — Lock session file and test connection

```bash
chmod 600 "$SESSION_FILE"
source "$SESSION_FILE"
psql "$DATABASE_URL" -c "SELECT 1" > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "Connection verified: ${DB_LABEL} (source: ${DB_SOURCE})"
else
  echo "Connection FAILED. Check credentials in ${DB_SOURCE}"
  rm -f "$SESSION_FILE"
  exit 1
fi
```

## Step 6 — Cache table list (automatic)

```bash
source "$SESSION_FILE"
SCHEMA_CACHE="/tmp/.db_tables_$(echo "$PWD" | md5 -q 2>/dev/null || echo "$PWD" | md5sum | cut -c1-8)"
psql "$DATABASE_URL" -t -A -c "SELECT schemaname || '.' || tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename" > "$SCHEMA_CACHE" 2>/dev/null
echo "Cached $(wc -l < "$SCHEMA_CACHE" | tr -d ' ') tables in $SCHEMA_CACHE"
```

## Register project in db-map.json

After detecting the project's .env files, offer to register them:

```bash
MAP_FILE="$HOME/.claude/db-map.json"
[ ! -f "$MAP_FILE" ] && echo '{}' > "$MAP_FILE"

jq --arg proj "$PROJECT" \
   --arg local "$LOCAL_ENV_PATH" \
   --arg staging "$STAGING_ENV_PATH" \
   '.[$proj] = {local: $local, staging: $staging}' \
   "$MAP_FILE" > "${MAP_FILE}.tmp" && mv "${MAP_FILE}.tmp" "$MAP_FILE"
```

Always ask the user before saving. Only include environments that actually exist.
