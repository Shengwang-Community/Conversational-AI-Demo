# Jira: Creating Subtasks

## Basic Pattern

```python
jira_create_issue(
    project_key="PROJ",
    summary="Subtask title",
    issue_type="Subtask",
    additional_fields='{"parent": "PROJ-123"}'
)
```

**Required:**
- `issue_type`: Must be "Subtask" (or localized name)
- `additional_fields`: Must include `{"parent": "PARENT-KEY"}`

## Localized Issue Types

Some Jira instances use localized names:

| Language | Subtask Type |
|----------|--------------|
| English | `Subtask` |
| Chinese | `子任务` |
| Japanese | `サブタスク` |
| German | `Unteraufgabe` |

If "Subtask" fails, ask the user for the correct type name in their Jira instance.

## With Components

```python
jira_create_issue(
    project_key="PROJ",
    summary="Frontend implementation",
    issue_type="Subtask",
    assignee="dev@company.com",
    components="Frontend",
    description="Implement the UI changes",
    additional_fields='{"parent": "PROJ-123"}'
)
```

## Bulk Creation

For multiple subtasks under one parent:

```python
jira_batch_create_issues(issues='[
    {"project_key": "PROJ", "summary": "Task 1", "issue_type": "Subtask", "additional_fields": {"parent": "PROJ-123"}},
    {"project_key": "PROJ", "summary": "Task 2", "issue_type": "Subtask", "additional_fields": {"parent": "PROJ-123"}}
]')
```

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| Issue type not found | Wrong type name | Use localized name |
| Parent not found | Invalid parent key | Verify parent exists |
| Cannot create subtask | Parent is already a subtask | Subtasks can't have subtasks |
