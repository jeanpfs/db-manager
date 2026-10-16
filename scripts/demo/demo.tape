# Records the real Claude Code session behind assets/demo.gif (https://github.com/charmbracelet/vhs).
#
# Setup (paths are examples; keep everything under /tmp):
#   1. Throwaway Postgres + data (trust auth, so the URLs below hold no password):
#        docker run -d --name demo-db-manager-pg -p 127.0.0.1:54329:5432 -e POSTGRES_USER=demo \
#          -e POSTGRES_HOST_AUTH_METHOD=trust postgres:16-alpine
#        for d in shop_dev shop_prod; do
#          psql postgresql://demo@127.0.0.1:54329/postgres -c "CREATE DATABASE $d"
#          psql postgresql://demo@127.0.0.1:54329/$d -f seed.sql; done
#   2. mkdir -p /tmp/dbdemo-proj && cd /tmp/dbdemo-proj
#        echo 'DATABASE_URL=postgresql://demo@127.0.0.1:54329/shop_dev'  > .env.development
#        echo 'DATABASE_URL=postgresql://demo@127.0.0.1:54329/shop_prod' > .env.production
#        npx skills@latest add jeanpfs/db-manager --all -a claude-code -y
#   3. A clean Claude Code config dir (no personal skills, hooks or status line) with credentials, pointed to by
#      CLAUDE_CONFIG_DIR. Allow Skill and Bash (the skill's inline session check is a compound shell command that
#      per-command rules do not match), and deny Read(**/.env*) so the agent goes through the skill instead of
#      opening the .env files.
#   4. Use a throwaway HOME so the skill's ~/.cache/db-manager session/audit files do not touch your real one,
#      with psql on PATH. Delete /tmp/dbdemo-home and the container afterwards.
# Record:  vhs demo.tape   (writes session.mp4 in the current directory)
# Then:    make-gif.sh
#
# The session is real and not deterministic: re-record until the agent loads the skill, asks for the environment (an interactive menu: Enter picks "development"),
# inspects the schema, prints the confirmation block and applies the UPDATE after CONFIRM. Reset order 1042 to
# 'pending' before every take, then set the T_* times in make-gif.sh from the new recording.

Output "session.mp4"
Set Shell "bash"
Set FontSize 18
Set Width 940
Set Height 720
Set Padding 16
Set Theme "Catppuccin Mocha"
Set TypingSpeed 38ms

Hide
Type "cd /tmp/dbdemo-proj && export HOME=/tmp/dbdemo-home CLAUDE_CONFIG_DIR=/tmp/dbdemo-cc PATH=/opt/homebrew/opt/libpq/bin:$PATH && PS1='$ ' && clear" Enter
Show
Type "claude" Enter
Wait+Screen@30s /Try|\? for shortcuts|esc to interrupt|❯/
Sleep 2s
Type "Which orders are still pending?" Sleep 500ms Enter
Wait+Screen@120s /Enter to select/
Sleep 2500ms
Enter
Wait+Screen@180s /Together|1051/
Sleep 2s
Type "Mark order 1042 as paid." Sleep 500ms Enter
Wait+Screen@180s /Type exactly/
Sleep 3s
Type "CONFIRM" Sleep 500ms Enter
Wait+Screen@180s /audit|now marked|is now/
Sleep 4s
