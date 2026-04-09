# PROJECT_STATE.md（Android 项目状态记录模板）

用途：用于跨会话接力，不做会话打卡；适用于代码任务、文档任务、skill 任务与 workflow 规范任务。

说明：由 `ac-memory` 负责创建、结构校验与 `[STATE]` 状态锚点维护；由 `ac-workflow` 负责在 workflow 入口、continue 与收尾时编排状态流转。

PLAN_FROZEN: false
CURRENT_ROLE: single
WORKFLOW_STATUS: active

仓库范围提示：

- 业务模块：`app`、`common`、`scenes/convoai`、`scenes/convoai:iot`、`scenes/convoai:bleManager`
- AI 工程化资产：`AGENTS.md`、`.agents/skills/`、`docs/*.md`、`PROJECT_STATE.md`

## 目标

- <本次要完成的目标；可为代码、文档、skill 或 workflow 规范任务>

## 下一步 Top 3

- [ ] <最优先动作 1>
- [ ] <最优先动作 2>
- [ ] <最优先动作 3>

## 阻塞项

- <阻塞项；无则写“无”>

## 关键决策索引（最近 3 条）

- <YYYY-MM-DD 决策摘要 1>
- <YYYY-MM-DD 决策摘要 2>
- <YYYY-MM-DD 决策摘要 3>

## 关键决策日志（全量追加，不覆盖历史）

- <YYYY-MM-DD：决策内容 | 原因 | 影响>

## 验收证据（Evidence）

- <命令输出：例如 `./gradlew lint` / `./gradlew test` / `./gradlew assembleDebug`>
- <文档任务检查：例如路径、模块名、术语、模板联动、一致性搜索结果>
- <截图 / 录屏 / Logcat / 模拟器或真机验证结果>
- <手工回归路径：启动、返回、旋转屏、后台恢复、权限弹窗等>

## 未验证清单（Gaps）

- <尚未验证的风险与原因，例如低版本设备、平板、深色模式、不同 variant、docs workflow 未做端到端演练>

## 提交计划

- <commit 1：范围 + 目的>
- <commit 2：范围 + 目的>

## Execution Contract

- Scope: <本轮允许执行的范围，例如“仅修复登录失败提示错误”或“仅同步 AGENTS.md / skills / templates 的 workflow 规则”>
- Files to change: <允许修改的文件/目录或模块，例如 `app/`, `common/`, `scenes/convoai/`, `docs/`, `.agents/skills/`>
- Forbidden: <明确禁止的行为或改动，例如“不升级 AGP/Kotlin；不修改无关模块；不调整无关 workflow 规范”>
- Steps: <执行步骤（有序）>
- Checks: <代码任务写 `lint / test / assemble`；docs-only 任务写路径 / 术语 / 模板一致性检查>
- Commit plan: <提交策略或“本轮不提交”>
- Rollback note: <回滚方式或注意事项>
