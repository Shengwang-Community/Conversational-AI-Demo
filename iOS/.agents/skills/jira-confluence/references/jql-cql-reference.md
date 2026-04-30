# JQL & CQL Reference

## JQL Patterns (Jira)

### By Assignment
```
assignee = currentUser()                    # My issues
assignee = "user@company.com"               # Specific user
assignee is EMPTY                           # Unassigned
assignee was currentUser()                  # Previously assigned to me
```

### By Status
```
statusCategory != Done                      # Not done (i18n-safe, recommended)
statusCategory = "In Progress"              # In progress category
status = "In Progress"                      # Exact status (locale-specific)
status in ("To Do", "In Progress")          # Multiple statuses
status changed to "Done" after -7d          # Recently completed
```

**Note:** Use `statusCategory` for better internationalization support. It works across all locales while `status` requires exact locale-specific names.

### By Date
```
created >= -7d                              # Last 7 days
updated >= startOfWeek()                    # This week
duedate < now()                             # Overdue
resolved >= startOfMonth()                  # Resolved this month
```

### By Sprint
```
sprint in openSprints()                     # Current sprint
sprint in futureSprints()                   # Future sprints
sprint = "Sprint 23"                        # Specific sprint
```

### By Type & Priority
```
type = Bug AND priority = High
type in (Bug, Task) AND priority in (High, Highest)
type = Epic AND "Epic Status" = "In Progress"
```

### By Text
```
summary ~ "login"                           # Title contains
description ~ "error message"               # Description contains
text ~ "authentication"                     # Any text field
```

### Combining Conditions
```
project = PROJ AND assignee = currentUser() AND statusCategory != Done ORDER BY priority DESC, updated DESC
```

---

## CQL Patterns (Confluence)

### By Space
```
space = TEAM                                # Specific space
space in (TEAM, DEV, DOCS)                  # Multiple spaces
space = "~username"                         # Personal space (quote required)
```

### By Type
```
type = page                                 # Pages only
type = blogpost                             # Blog posts
type in (page, blogpost)                    # Both
```

### By Date
```
created >= "2024-01-01"                     # After date
lastModified > startOfWeek()                # Modified this week
lastModified > startOfMonth("-1M")          # Modified last month
```

### By User
```
creator = currentUser()                     # Pages I created
contributor = currentUser()                 # Pages I edited
watcher = "user@company.com"                # Pages user watches
```

### By Content
```
title ~ "Meeting"                           # Title contains
text ~ "project plan"                       # Content contains
siteSearch ~ "quarterly report"             # Full site search
label = documentation                       # Has label
```

### Combining
```
type = page AND space = TEAM AND lastModified > startOfWeek() AND creator = currentUser()
```

---

## Tips

- **Quotes**: Required for multi-word values and special characters
- **Case**: Field names are case-insensitive, values may be case-sensitive
- **Dates**: Use relative (`-7d`, `startOfWeek()`) over absolute dates
- **Performance**: Add `project =` or `space =` to narrow scope
- **Limit**: Always set reasonable limits for large result sets
