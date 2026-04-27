# Android 项目 AI 协作规范

> 适用于使用 AI Agent 参与 Android 项目开发的仓库。默认技术栈为 Android + Kotlin + Gradle；当前仓库主路径为传统 View + ViewBinding，局部实现以目标模块为准。所有约定以目标仓库实现为准，若与外部规范冲突以本文件优先。

## 偏好

- 语言：中文
- 时间：Asia/Shanghai，YYYY-MM-DD，24h

## 当前项目画像

> 详细模块关系、主链路和配置注入请看 `ARCHITECTURE.md`，这里仅保留 AI 协作需要的最小项目画像。

- 项目定位：`Shengwang Convo AI Demo for Android`，用于演示对话式 AI、音视频、字幕、数字人和 IoT 接入；默认按 Demo 工程思考，不直接等同生产环境
- 模块骨架：`app` 是入口壳层，`common` 是共享基座，`scenes:convoai` 是主业务，`scenes:convoai:iot` / `scenes:convoai:bleManager` 是外设链路
- 配置与构建：主要配置来自 `gradle.properties`；`app` 当前只有 `china` flavor；`app/common/scenes:convoai` 使用 Java 17，`iot/bleManager` 使用 Java 11
- UI 现状：当前仓库以 `Activity` / `Fragment` / `ViewBinding` 为主；无明确需求时，不要把方案默认成 Compose-first
- 高风险区域：构建脚本、`gradle.properties`、Manifest，以及 `scenes/convoai/.../convoaiApi/subRender` 字幕链路
- AI 工程化资产：`AGENTS.md`、`ARCHITECTURE.md`、`.agents/skills/`、`.agents/state/INDEX.md`、`.agents/state/tasks/`、`docs/*.md`

## 对话模式

| Mode | 识别特征 | 响应策略 |
|------|---------|---------|
| **workflow** | 明确要求改文件、执行构建/测试/adb/提交流水线验证，或明确要求进入 workflow | **启动工作流（强制状态管理）** |
| **continue** | 用户明确输入"继续 / 接着做 / 继续 <TASK_TITLE> / 继续 <task-id>"，且 `.agents/state/tasks/` 中存在 `active` 或 `blocked` 任务 | 按「未完成任务分流」规则解析候选并恢复，进入 workflow |
| **analysis** | 仓库分析、读代码、看 diff、看日志、排查根因，但尚未进入改动执行 | 允许只读命令，不创建或更新任务状态 |
| **general** | 技术咨询、概念解释、一般问题 | 直接回答，不启动 workflow |

## Review 子类型触发

当用户请求包含 `review` 时，先按**精确短语**识别子类型（详细边界见 `docs/REVIEW_TEMPLATES.md`）：

- `开发态联调 review`：默认按开发中假设评审，优先把未证实问题定性为 `Gaps` / `assumption` / `open question`
- `问题修复 review`：默认按发布态/回归风险评审，重点检查是否真正修复、是否引入新回归
- 未命中以上短语：按默认 code review 模式处理

精确短语仅对原文字符串生效，不做模糊扩展。两短语同时出现时必须先要求用户澄清。

## 模式切换规则

### general / analysis → workflow

当 **general 或 analysis 模式**下的回答即将涉及文件修改、写操作命令（`./gradlew`、构建、`adb` 等）或任务状态变化时，必须切换到 workflow 模式。

**纯展示文案豁免**：仅修改展示文案、不改代码逻辑/资源 key/布局/样式/配置/埋点，且不涉及 `AGENTS.md`、`.agents/skills/`、`docs/*.md`、不需要构建验证时，可直接执行不进入 workflow。若执行中发现超出边界，必须立即升级。

若用户请求本身已明确要求"修复/实现/重构/跑检查/进入 workflow"，直接进入，不二次确认。只有提问/分析中需要升级成执行时才提示切换。

### analysis 模式限制

允许：`rg`、`git status`、`git diff`、`git log`、`sed`、`cat`、`nl`、`ls` 等只读命令。  
禁止：修改文件、运行构建/测试/`adb`、更新 `.agents/state/` 下的状态文件。

### 未完成任务分流（continue 唯一入口）

当 `.agents/state/tasks/` 中存在 `active` 或 `blocked` 任务，但用户未明确表达"继续"时：

- 不得仅因任务文件存在而自动进入 continue；`completed` 永不触发 continue
- 若用户输入"继续 XXX"，优先精确匹配 `TASK_TITLE` 或 `task-id`；未命中时允许做子串/关键词候选匹配，候选唯一则先确认再绑定，候选多个则列出让用户选择
- 若当前请求是新任务，按新任务进入 workflow
- 若当前请求可能与旧任务相关但无法确定，必须先提示用户选择"继续旧任务"或"启动新任务"
- `blocked` 表示"可恢复"，不表示"必须恢复"

## workflow 模式（强制状态机）

### 启动门禁（Hard Gate）

> **只要进入 workflow 模式，必须先通过 `ac-workflow` 完成编排与状态就绪检查，否则不得执行任何开发动作。**

`ac-workflow` 流程：读取 `INDEX.md` 与未完成任务摘要 → 判定新任务/continue（continue 按上方分流规则解析目标）→ 目标明确后调用 `ac-memory` 校验/创建状态文件 → 路由到 `single` / `single + reviewer` / `planner -> executor -> reviewer`。

建议回显：`[STATE] <task-id> | <role> | <status> | 已检查/已更新`

### 多角色路由（风险评分制）

默认 `single`。评分维度（每项 0-2 分）：

1. 复杂度：跨模块、页面、构建配置或数据层
2. 影响面：公共组件、共享导航、网络层、数据库、权限
3. 不确定性：需求模糊、方案需比较、信息不足
4. 变更风险：迁移、兼容性、回滚难度、数据一致性
5. 验证成本：单测、设备验证、手工回归、variant 验证

| 总分 | 路由 |
|------|------|
| 0-3 | `single` |
| 4-6 | `single + reviewer` |
| ≥7 | `planner -> executor -> reviewer` |

典型参考：
- 单文件 README/SKILL.md 微调 → `0-2` → `single`
- 同步 AGENTS.md + skills + docs 术语 → `5` → `single + reviewer`
- 修改 common 公共能力 → `7` → 完整三角色
- 修改 convoaiApi/subRender 字幕链路 → `9` → 完整三角色

路由语义：
- `single`：由 `ac-workflow` 折叠执行 `ac-plan → ac-execute → summary closeout`，收尾写 `CURRENT_ROLE: single`、`WORKFLOW_STATUS: completed`
- `single + reviewer`：同上完成后强制进入 `ac-review`，通过后统一回交 `ac-workflow` 做 `📝 总结`
- `planner -> executor -> reviewer`：显式多角色顺序交接

### 轻量 workflow（仅非 copy-edit 小任务）

满足以下条件时按轻量处理：目标为 docs/skill/template/注释/路径修正/术语同步等，修改范围为单文件或少量联动文件（允许跨 `AGENTS.md`、`.agents/skills/`、`docs/`），不涉及构建配置、高风险代码路径、`./gradlew`/`adb`/设备验证。

轻量 workflow 中（亦称 micro-task），评分决定路由而非资格：0-3 保持 `single`，4-6 升级 `single + reviewer`，≥7 退出轻量走完整三角色。涉及 workflow 路由语义、Execution Contract/review 规则或 AGENTS.md 核心约束时，默认至少带 `reviewer`。

处理约定：仍进入 workflow 经 `ac-workflow`，仍由 `ac-memory` 维护状态、`ac-plan` 冻结 Contract（允许简版），允许把同一轮（Contract 冻结后到本次回复前）连续小改动聚合成一次状态写回。聚合上限 `3` 步或 `50` 行净变更，超出回到标准节奏。接近上限时在 Evidence/Gaps 留校准观察（阈值可接受/偏紧/偏松）。

### 执行冻结与角色纪律

- `ac-memory`：状态文件与索引的创建、校验、同步
- `ac-workflow`：入口编排、阶段推进、`single` 折叠路由、continue 恢复、强制收尾编排
- `ac-plan`：产出并冻结 Execution Contract（`PLAN_FROZEN=true`）
- `ac-execute`：仅按 Contract 执行，不得新增设计
- `ac-review`：按 Contract 验收 Evidence/Gaps，必要时解冻回退
- `self-improving-agent`：`ac-review` 后可选复盘，只写自身 `memory/`

执行中出现新增设计、范围扩大或关键约束变化，必须回 `ac-plan` 解冻重规划，再次冻结后继续。

## AI 行为规范

### 任务状态文件维护（硬约束）

**核心原则**：workflow 状态源由 `.agents/state/INDEX.md` 与 `.agents/state/tasks/<task-id>.md` 组成；`ac-memory` 托管维护，`ac-workflow` 承接编排。

#### 强制更新节点

以下节点必须更新任务状态文件与 INDEX.md：

- 创建/更新 todo、完成 todo item
- 提交 commit 后、阶段切换时
- 遇到阻塞/决策点、新增/更新证据或识别到未验证风险时
- 收到或关闭 review finding 时
- **即使是轻量 workflow 任务**

> ⚠️ **禁止以"任务太小"为由跳过状态更新。**

轻量任务允许同一轮聚合写回（上限 `3` 步 / `50` 行），但不得跨 turn 延迟、不得省略 Contract/Evidence/最终收尾。仅在出现真实范围/路由/一致性取舍时追加关键决策日志。

#### 必备字段与区块

头部字段：`TASK_ID`、`TASK_TITLE`、`TASK_TYPE`、`PLAN_FROZEN`、`CURRENT_ROLE`、`WORKFLOW_STATUS`、`STARTED_AT`、`LAST_UPDATED_AT`。

状态语义：`active`（可推进）、`blocked`（已收尾等待继续）、`completed`（已收尾，永不自动触发 continue）。

必备区块（模板见 `docs/TASK_STATE_TEMPLATE.md`）：目标、Top 3、阻塞项、关键决策索引（最近 3 条）、关键决策日志（全量追加）、Evidence、Gaps、Review Findings（闭环）、提交计划、Execution Contract。

INDEX.md 维护：`CURRENT_TASK`、`## Active`、`## Blocked`、`## Completed`，列表格式 `<task-id> | <TASK_TITLE> | <task-type> | <role> | <status>`（模板见 `docs/STATE_INDEX_TEMPLATE.md`）。

### Commit Policy

- 允许 `git commit` 仅当用户明确要求；默认不提交
- 严格禁止 `git push`，除非用户明确要求且单独确认
- Commit message 英语，附 `Co-Authored-By: <llm-model>`
- `.agents/state/` 默认不提交，仅在跨环境同步或用户明确要求时提交

### 质量审查

- 每完成一个 todo item 后主动检查是否需要 review
- Review 维度：代码（逻辑/类型/边界/生命周期/线程）、配置链路（BuildConfig/flavor/权限/RTC/RTM/字幕/IoT/BLE）、文档（准确性/路径/命令可执行性/skill 触发条件）
- 开发态联调/debugging 任务发起 review 前，必须显式说明本地缓存策略、后端契约前提、明确非目标和可疑项归类（Gaps/assumption/open question）
- 收到 review finding 后必须写入 `Review Findings（闭环）`，用 `fixed` / `rejected with evidence` / `accepted as gap` / `requires re-plan` 收尾
- **发现问题立即修复，不得累积**

### 完成判定与验证新鲜度

- "已完成/已修复/已验证通过"必须基于本轮 fresh Evidence；历史 Evidence 只能作为背景
- 仅完成代码/文档修改但未完成声明中的验证 → 写入 Gaps
- `review pass` 表示实现与 Contract 一致可按本轮收尾，不自动等于所有运行时风险已消除
- docs-only 任务同样需要本轮一致性检查证据

### 对话评审与上下文管理

进度回显格式与阶段切换提示见 `docs/REVIEW_TEMPLATES.md`。

出现以下情况时强制收尾（`WORKFLOW_STATUS → blocked`），刷新状态文件后提示：

- 对话超过 10 轮、大量变更、用户提示上下文不足、Agent 感知上下文风险

输出格式：

```text
⚠️ 建议切换新对话

已完成：[已完成任务列表]
待继续：[未完成任务列表]
下一步：开启新对话，输入「继续 <TASK_TITLE>」或「继续 <task-id>」
```

review 通过收尾时，`WORKFLOW_STATUS → completed`。

## Android 开发约束

以下为项目特有约束，模块详情与主链路见 `ARCHITECTURE.md`。

- **模块边界**：`app` 只承载壳层（flavor/Manifest/签名/入口），业务不回灌；`common` 是高影响底座，改动需说明对上层模块的影响；`scenes/convoai` 主业务；`iot → bleManager` 外设链路
- **高风险路径**：`convoaiApi/subRender` 字幕链路、`settings.gradle`、`build.gradle(.kts)`、`gradle/libs.versions.toml`、`AndroidManifest.xml`
- **配置**：`gradle.properties` 是配置入口，涉及 `AG_APP_ID`/`BASIC_AUTH_*`/`LLM_*`/`TTS_*`/`AVATAR_*`/`TOOLBOX_SERVER_HOST` 时说明影响范围；禁止扩散密钥，优先占位值
- **构建**：仅 `china` flavor，Java 17 (`app/common/convoai`) 与 Java 11 (`iot/bleManager`) 混用
- **UI**：默认 ViewBinding + Activity/Fragment，无需求不引入 Compose
- **权限/外设**：涉及 `CAMERA`/`RECORD_AUDIO`/蓝牙/定位/Wi-Fi 时说明申请时机与拒绝路径；IoT/BLE 需要真机验证
- **文档/Skill**：修改 `AGENTS.md`/`.agents/skills/`/`docs/*.md` 时必须检查三者同步；skill 的 `description` 需含"做什么"和"触发词"；优先修改原 skill 而非新增近义 skill
## 工具链与检查

代码任务默认：

```bash
./gradlew lint
./gradlew test
./gradlew :app:assembleChinaDebug
```

纯文档/skill/template 任务改为一致性检查（具体 `rg` 命令见 `docs/WORKFLOW_TEMPLATES.md`），不得伪造构建结论。

## 文档导航

详见 `ARCHITECTURE.md` §8 推荐阅读顺序。核心入口：

- `ARCHITECTURE.md` — 模块关系、主链路、高风险区域
- `docs/TASK_STATE_TEMPLATE.md` / `docs/STATE_INDEX_TEMPLATE.md` — 状态文件模板
- `docs/WORKFLOW_TEMPLATES.md` — 按任务类型的 workflow 模板
- `docs/REVIEW_TEMPLATES.md` — 评审标准与输出格式
- `docs/PR_CHECKLIST.md` — PR 审查清单
- `docs/DEBUG_WORKFLOW.md` — 联调/调试任务规则
- `.agents/skills/ac-workflow/SKILL.md` 等 — 各 skill 的详细执行边界
