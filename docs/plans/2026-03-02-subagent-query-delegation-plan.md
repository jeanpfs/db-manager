# Subagent Query Delegation — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Modify db-manager SKILL.md to delegate all database queries to subagents, keeping the main context clean.

**Architecture:** The skill instructs Claude to spawn a `general-purpose` subagent for every database operation. Session setup stays in the main context. Destructive operations are prepared by the subagent but confirmed in the main context.

**Tech Stack:** Claude Code Agent tool, bash (psql/db helper)

**Design doc:** `docs/plans/2026-03-02-subagent-query-delegation-design.md`

---

### Task 1: Add Subagent Protocol section to SKILL.md

**Files:**
- Modify: `SKILL.md:132-151` (replace "Query Protocol" section)

**Step 1: Replace the "Query Protocol" section with "Subagent Query Protocol"**

Replace lines 133-151 (the current `## Query Protocol — MANDATORY before writing any SQL` section) with:

```markdown
## Subagent Query Protocol — MANDATORY for all database operations

**Every database query MUST be delegated to a subagent.** This keeps the main conversation context clean and avoids token accumulation from schema inspection and query results.

### How to delegate

Use the **Agent tool** with the following parameters:

- `subagent_type`: `"general-purpose"`
- `description`: Short description of the query (e.g., "Query active users")
- `prompt`: Use the template below, filling in the placeholders

### Subagent prompt template

```
You are a PostgreSQL database assistant. Execute queries autonomously.

## Connection
- Helper script: ~/.claude/scripts/db
- Session file: SESSION_FILE_PATH
- Available tables: TABLE_LIST

## Task
USER_QUESTION

## Mandatory protocol
1. For each table referenced, run: ~/.claude/scripts/db -c "\d tablename"
2. Use ONLY real columns returned by \d — never guess column names
3. Build and execute SQL via: ~/.claude/scripts/db -c "<sql>"
4. If results exceed 20 rows, summarize: totals, patterns, sample rows

## Destructive operations (DELETE, UPDATE, DROP, TRUNCATE, ALTER)
If the task requires a destructive query:
- Do NOT execute it
- Return: the proposed SQL, estimated rows affected (via SELECT COUNT with same WHERE), and rationale
- The main agent will handle user confirmation

## Response format
Return ONLY:
- The SQL executed (or proposed, if destructive)
- The result (summarized if large)
- Relevant observations (if any)
Do NOT include long explanations of your process.
```

### Filling the template

Before spawning the subagent, the main agent MUST:
1. Ensure session setup is complete (session file exists in `/tmp`)
2. Read the cached table list from `/tmp/.db_tables_*`
3. Replace placeholders:
   - `SESSION_FILE_PATH` → actual path (e.g., `/tmp/.db_session_a1b2c3d4`)
   - `TABLE_LIST` → contents of `/tmp/.db_tables_*` file
   - `USER_QUESTION` → the user's request in natural language

### After the subagent returns

- Present the result to the user concisely
- If the subagent returned a destructive operation proposal, follow the confirmation protocol below
- If the subagent failed or returned incoherent results, fall back to direct execution (run `\d` and queries in the main context)
```

**Step 2: Verify the edit**

Read `SKILL.md` lines 132-200 to confirm the new section is correctly placed.

**Step 3: Commit**

```bash
git add SKILL.md
git commit -m "feat: add subagent query protocol section"
```

---

### Task 2: Update destructive operations flow for subagent handoff

**Files:**
- Modify: `SKILL.md:257-275` (add subagent handoff flow before the confirmation block)

**Step 1: Add subagent handoff flow**

Insert the following **before** the existing `### Mandatory confirmation protocol` (before line 276), as a new subsection:

```markdown
### Subagent handoff for destructive operations

When the subagent returns a destructive operation proposal, it will contain:
- **SQL**: the exact query to execute
- **Rows affected**: estimated count
- **Rationale**: why this query was built

The main agent MUST then:
1. Display the confirmation block below (using the SQL and row count from the subagent)
2. Wait for user confirmation (`CONFIRM` or `CONFIRM PRODUCTION`)
3. If confirmed, execute the query directly: `~/.claude/scripts/db -c "<sql>"`
4. Log to audit file as usual
```

**Step 2: Verify the edit**

Read `SKILL.md` lines 257-300 to confirm the new subsection fits correctly.

**Step 3: Commit**

```bash
git add SKILL.md
git commit -m "feat: add destructive operation handoff flow for subagent"
```

---

### Task 3: Update checklists for subagent workflow

**Files:**
- Modify: `SKILL.md:392-397` (per-query checklist)

**Step 1: Replace per-query checklist**

Replace the current per-query checklist:

```markdown
## Per-query checklist

- [ ] Identified tables involved in the query
- [ ] Ran `\d tablename` for each table (or reused from earlier in conversation)
- [ ] Query uses ONLY real column names from `\d` output
```

With:

```markdown
## Per-query checklist

- [ ] Session file exists in `/tmp` (setup completed)
- [ ] Table list cache exists in `/tmp/.db_tables_*`
- [ ] Spawned subagent with correct prompt template (all placeholders filled)
- [ ] Reviewed subagent result before presenting to user
- [ ] If destructive: followed confirmation protocol in main context
```

**Step 2: Verify the edit**

Read `SKILL.md` lines 390-400 to confirm.

**Step 3: Commit**

```bash
git add SKILL.md
git commit -m "feat: update per-query checklist for subagent workflow"
```

---

### Task 4: Update token strategy table

**Files:**
- Modify: `SKILL.md:400-407` (token strategy section)

**Step 1: Replace token strategy**

Replace the current token strategy section with:

```markdown
## Token strategy

| Approach                        | Tokens in main context           |
|---------------------------------|----------------------------------|
| MCP postgres                    | ~2,000–5,000 (schema always injected) |
| `db -c` direct (old approach)  | ~500–5,000 (schema + result)     |
| Subagent delegation (current)   | ~50–200 (only summarized result) |
| `docs/schema.sql`              | Read on demand only              |

The subagent absorbs all schema inspection and query execution tokens. The main context only receives the final summarized result.
```

**Step 2: Verify the edit**

Read `SKILL.md` lines 398-end to confirm.

**Step 3: Commit**

```bash
git add SKILL.md
git commit -m "feat: update token strategy for subagent approach"
```

---

### Task 5: Add error handling / fallback section

**Files:**
- Modify: `SKILL.md` (add new section after the subagent protocol, before the helper script section ~line 153)

**Step 1: Add fallback section**

Insert after the Subagent Query Protocol section and before `## ~/.claude/scripts/db helper script`:

```markdown
## Subagent fallback

If the subagent fails (timeout, connection error, incoherent result), fall back to direct execution:

1. Run `\d tablename` for relevant tables in the main context
2. Build and execute the SQL directly via `~/.claude/scripts/db -c "<sql>"`
3. This is the pre-subagent behavior — it works, just uses more tokens

This fallback ensures database access is never blocked by subagent issues.

---
```

**Step 2: Verify the edit**

Read the area around the insertion to confirm proper placement.

**Step 3: Commit**

```bash
git add SKILL.md
git commit -m "feat: add subagent fallback section"
```

---

### Task 6: Final review and verification

**Step 1: Read entire SKILL.md**

Read the full file to verify:
- Subagent Protocol section is complete and well-placed
- Destructive handoff flow integrates with existing confirmation blocks
- Checklists are updated
- Token strategy is updated
- Fallback section exists
- No duplicate or orphaned sections

**Step 2: Verify section ordering is logical**

Expected order:
1. Core principles
2. Dependencies
3. Central map
4. Session Setup (Steps 1-6)
5. **Subagent Query Protocol** (NEW)
6. **Subagent fallback** (NEW)
7. Helper script
8. Register project
9. Generate schema
10. Update CLAUDE.md
11. Security rules (with **subagent handoff** subsection)
12. Security model summary
13. Installation
14. Checklists (updated)
15. Token strategy (updated)

**Step 3: Final commit if any fixes needed**

```bash
git add SKILL.md
git commit -m "fix: final adjustments to subagent integration"
```
