# STATE_INDEX（Android 任务索引模板）

用途：用于维护 workflow 当前任务指针和任务摘要列表；由 `ac-memory` 负责创建与同步。

约束：

- `CURRENT_TASK` 只指向当前正在推进的任务；没有进行中的任务时写 `none`
- 同一个任务在任一时刻只能出现在 `Active`、`Blocked`、`Completed` 其中一个列表中

CURRENT_TASK: none

## Active

- none

## Blocked

- none

## Completed

- none
