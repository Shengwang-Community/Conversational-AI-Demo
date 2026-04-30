---
name: jira-confluence
description: |
  Manage Agora Jira issues and Confluence documentation. Trigger this skill when:
  - User mentions: Jira, Confluence, ticket, issue, task, bug, story, epic, subtask, sprint, board, kanban, backlog, JQL, wiki, docs, page
  - User wants to: search/create/update issues, check task status, add comments, transition workflow, create documentation, search wiki pages
  - User asks about: my tasks, assigned issues, project backlog, team documentation
  Even without explicit keywords, trigger when the context involves project management, task tracking, issue tracking, or team documentation.
---

## Pre-flight Check (Execute First)

Before any Jira/Confluence operation, verify the MCP server is available.

## Hard Rules

- If the user asks for Jira or Confluence content, always use Atlassian MCP tools first.
- Do not use `curl`, generic web access, browser scraping, or raw HTML fetching before Atlassian MCP has been attempted.
- If the user provides a Confluence URL, prefer resolving it into `page_id` or `space_key` + `title` and call `confluence_get_page(...)` directly.
- If Atlassian MCP is unavailable, stop the content-retrieval flow and enter setup guidance. Do not substitute web scraping for MCP-backed reads.
- For Jira/Confluence requests, this skill takes priority over generic web-fetch behavior.

### Step 1: Check MCP Tools

Check whether Atlassian MCP tools are available in the current session.

- **Tools found** (for example `mcp__mcp_atlassian__confluence_get_page`, `mcp__mcp_atlassian__confluence_search`, `mcp__mcp_atlassian__jira_search`) → Proceed to operations
- **No tools found** → Go to Step 2

### Step 2: Setup Required

Tell the user:

> "The Jira/Confluence MCP server is not configured. Would you like me to help you set it up? It takes about 2 minutes."

If user agrees, read `references/setup.md` and guide them through:
1. Install uv/uvx (if needed)
2. Configure MCP settings with Agora OAuth credentials
3. Restart AI tool - browser will open for OAuth SSO login
4. Verify connection

### Step 3: Verify Connection

After setup, test with a simple query:
```
jira_search(jql="assignee = currentUser() AND statusCategory != Done ORDER BY updated DESC", limit=1)
```
- Success → Ready to use
- Error → Check `references/setup.md` troubleshooting section

---

## Jira Operations

### Search Issues

Use `jira_search` with JQL. Common patterns:

```
# My open issues (use statusCategory for i18n support)
assignee = currentUser() AND statusCategory != Done ORDER BY updated DESC

# Project backlog
project = PROJ AND statusCategory = "To Do" ORDER BY priority DESC

# Recent bugs
project = PROJ AND type = Bug AND created >= -7d

# Issues in current sprint
sprint in openSprints() AND assignee = currentUser()

# High priority unresolved
assignee = currentUser() AND statusCategory != Done AND priority in (High, Highest)
```

**Tips:**
- Use `statusCategory` instead of `status` for better i18n support (works with Chinese/localized status names)
- Quote multi-word values: `status = "In Progress"`
- Use `currentUser()` for the logged-in user
- Add `ORDER BY` for sorting: `ORDER BY updated DESC`
- See `references/jql-cql-reference.md` for more advanced JQL/CQL patterns

### Get Issue Details

Use `jira_get_issue(issue_key="PROJ-123")` to fetch full details including description, comments, and status.

### Create Issues

Use `jira_create_issue` with required fields:
- `project_key`: Project key (e.g., "PROJ") - always ask user if unknown
- `summary`: Issue title
- `issue_type`: Type name (Task, Bug, Story, Epic, etc.)

Optional fields:
- `description`: Markdown content
- `assignee`: Email or display name
- `components`: Comma-separated names
- `additional_fields`: JSON for priority, labels, parent, epic link

**Creating subtasks:** (see `references/jira-create-subtasks.md` for details)
```python
jira_create_issue(
    project_key="PROJ",
    summary="Subtask title",
    issue_type="Subtask",  # or "子任务" in Chinese instances
    additional_fields='{"parent": "PROJ-123"}'
)
```

### Update Issues

Use `jira_update_issue(issue_key="PROJ-123", ...)` to modify:
- `summary`, `description`, `assignee`, `priority`, `labels`, etc.

### Transition Status

1. Get available transitions: `jira_get_transitions(issue_key="PROJ-123")`
2. Execute transition: `jira_transition_issue(issue_key="PROJ-123", transition="Done")`

### Add Comments

```python
jira_add_comment(issue_key="PROJ-123", body="Comment in **Markdown**")
```

---

## Confluence Operations

### If User Provides a Confluence URL

Handle Confluence URLs directly through MCP, not through web fetching.

Preferred order:
1. If the URL contains `pageId=...`, call `confluence_get_page(page_id="...")`
2. If the URL is in `/display/SPACE/TITLE` form, extract `space_key` and title, then call `confluence_get_page(title="...", space_key="...")`
3. If title parsing is ambiguous, use `confluence_search` first, then fetch the matching page

Examples:
- `https://confluence.agoralab.co/pages/viewpage.action?pageId=123456789`
  - `confluence_get_page(page_id="123456789")`
- `https://confluence.agoralab.co/display/DPE/Demo+2.2.0+HLD`
  - `confluence_get_page(title="Demo 2.2.0 HLD", space_key="DPE")`

### Search Pages

Use `confluence_search` with text or CQL:

```
# Simple text search
confluence_search(query="project documentation")

# CQL: pages in specific space
confluence_search(query="type=page AND space=TEAM")

# CQL: recently modified
confluence_search(query="lastModified > startOfWeek()")
```

### Get Page Content

```python
# By page ID
confluence_get_page(page_id="123456789")

# By title and space
confluence_get_page(title="Meeting Notes", space_key="TEAM")
```

### Handling Jira Macros in Pages

Agora Confluence pages often embed Jira issue links via macros. These cause two problems:

**Reading:** Markdown conversion produces garbage like `JIRA2cd8ad8e-4449-3a5a-9d76-fd5a49868868EEP-1484`. The actual issue key is the suffix after the UUID — in this case `EEP-1484`. When presenting to the user, extract and show only the issue key.

**Editing:** Pages with Jira macros must be edited in `storage` format to preserve the macros. Using `markdown` format will destroy all Jira links and user mentions.

To edit a page with macros:
1. Read the page in raw HTML: `confluence_get_page(page_id="...", convert_to_markdown=false)`
2. Modify only the parts you need in the storage XML
3. Write back using storage format: `confluence_update_page(..., content_format="storage")`

To insert a new Jira issue link, use this storage XML template:
```xml
<ac:structured-macro ac:name="jira" ac:schema-version="1">
  <ac:parameter ac:name="server">JIRA</ac:parameter>
  <ac:parameter ac:name="serverId">2cd8ad8e-4449-3a5a-9d76-fd5a49868868</ac:parameter>
  <ac:parameter ac:name="key">PROJ-123</ac:parameter>
</ac:structured-macro>
```

The `serverId` `2cd8ad8e-4449-3a5a-9d76-fd5a49868868` is the Agora Jira application link ID — use it as-is for all Jira macros.

### Create Pages

```python
confluence_create_page(
    space_key="TEAM",
    title="New Page Title",
    content="# Heading\n\nMarkdown content here",
    parent_id="123456"  # optional
)
```

### Update Pages

```python
# Simple pages (no macros) — use markdown
confluence_update_page(
    page_id="123456789",
    title="Updated Title",
    content="# New Content\n\nUpdated markdown"
)

# Pages with Jira macros — use storage format
confluence_update_page(
    page_id="123456789",
    title="Updated Title",
    content="<p>Updated content with <ac:structured-macro ...>...</ac:structured-macro></p>",
    content_format="storage"
)
```

---

## Quick Reference

| Task | Tool | Key Parameters |
|------|------|----------------|
| Search Jira | `jira_search` | `jql`, `limit` |
| Get issue | `jira_get_issue` | `issue_key` |
| Create issue | `jira_create_issue` | `project_key`, `summary`, `issue_type` |
| Update issue | `jira_update_issue` | `issue_key`, fields to update |
| Add comment | `jira_add_comment` | `issue_key`, `body` |
| Change status | `jira_transition_issue` | `issue_key`, `transition` |
| Search Confluence | `confluence_search` | `query`, `limit` |
| Get page | `confluence_get_page` | `page_id` or `title`+`space_key` |
| Create page | `confluence_create_page` | `space_key`, `title`, `content` |
| Update page | `confluence_update_page` | `page_id`, `title`, `content` |

---

## Common Issues

| Problem | Solution |
|---------|----------|
| JQL syntax error | Quote multi-word values: `"In Progress"` |
| Status filter not working | Use `statusCategory` instead of `status` for i18n support |
| Issue type not found | Check exact name; Chinese instances use localized names (e.g., `子任务`, `缺陷`, `新功能`) |
| Permission denied | Verify your Agora account has project access |
| MCP tools not found | Run setup from `references/setup.md` |
| Too many results | Add filters like `project = X` or `created >= -30d` to narrow scope |
| Jira macros show as garbage | Extract issue key from suffix (e.g., `JIRA2cd8...EEP-1484` → `EEP-1484`) |
| Macros lost after page edit | Use `content_format="storage"` and raw HTML; never use markdown for macro pages |
| OAuth SSO timeout | Restart AI tool, complete browser login within 5 minutes |
| OAuth token expired | Token auto-refreshes; if issues persist, restart AI tool to re-authenticate |
