# Android 项目 AI 协作规范（草案）

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

根据用户输入识别 Mode，采用不同响应策略：

| Mode | 识别特征 | 响应策略 |
|------|---------|---------|
| **workflow** | 明确要求改文件、执行构建/测试/adb/提交流水线验证，或明确要求进入 workflow | **启动工作流（强制状态管理）** |
| **continue** | 用户明确输入“继续 / 接着做 / 继续 <任务名>”，且 `.agents/state/tasks/` 中存在 `WORKFLOW_STATUS` 为 `active` 或 `blocked` 的任务 | 选择并恢复该任务，进入 workflow |
| **analysis** | 仓库分析、读代码、看 diff、看日志、排查根因，但尚未进入改动执行 | 允许只读命令，不创建或更新任务状态 |
| **general** | 技术咨询、概念解释、一般问题 | 直接回答，不启动 workflow |

## Review 子类型触发

当用户请求包含 `review` 时，先按以下**精确短语**识别 review 子类型：

- `开发态联调 review`：进入开发联调评审模式。默认按开发中假设评审，优先把未证实问题定性为 `Gaps` / `assumption` / `open question`，不把已声明的本地缓存策略、后端契约前提、明确非目标直接判成回退
- `问题修复 review`：进入问题修复评审模式。默认按发布态 / 回归风险评审，重点检查问题是否真正修复、是否引入新回归、边界条件与验收标准是否闭环
- 未命中以上短语：按默认 code review 模式处理

附加约定：

- 只对精确短语生效，不做模糊同义扩展
- 精确短语可来自用户请求，或由 `ac-plan` 明确写入 `Execution Contract`
- 若同一条请求同时出现两个短语，必须先要求用户澄清，不得自行猜测

## 模式切换规则

### general / analysis → workflow 回切

当 **general 或 analysis 模式** 下的回答即将涉及以下操作时，必须切换到 workflow 模式：

- 文件修改（创建、编辑、删除）
- 写操作命令（`./gradlew`、测试、构建、`adb`、提交前验证等）
- 任务状态变化（新增任务、更新 Contract、更新 Evidence / Gaps）

补充约定：

- 若用户请求本身已经明确要求“修复 / 实现 / 重构 / 跑检查 / 进入 workflow”，直接进入 workflow，不需要二次确认
- 只有在用户本来是在提问或分析，而当前回答需要升级成实际执行时，才提示切换

**提示格式**：

```text
⚠️ 检测到需要执行开发操作

当前操作需要：
- [具体操作列表]

建议切换到 workflow 模式以确保状态追踪。是否切换？
```

### analysis 模式限制

analysis 模式允许：

- `rg`、`git status`、`git diff`、`git log`、`sed`、`cat`、`nl`、`ls`
- 仅读取仓库上下文，不落盘任务状态

analysis 模式禁止：

- 修改文件
- 运行构建、测试、`adb`
- 更新 `.agents/state/INDEX.md` 或 `.agents/state/tasks/*.md`

### 未完成任务分流

当 `.agents/state/tasks/` 中存在 `WORKFLOW_STATUS: active` 或 `blocked` 的任务，但用户当前请求未明确表达“继续”时：

- 不得仅因任务文件存在而自动进入 continue
- 若当前请求是新任务，按新任务进入 workflow
- 若当前请求可能与旧任务相关，但无法确定是否续做，必须先提示用户选择“继续旧任务”或“启动新任务”
- 若存在多个未完成任务，必须要求用户指定任务名或 `task-id`
- `blocked` 表示“可恢复”，不表示“必须恢复”
- `completed` 永不触发 continue

## workflow 模式（强制状态机）

### workflow 启动门禁（Hard Gate）

> **只要进入 workflow 模式，必须先通过 `ac-workflow` 完成 workflow 编排与状态就绪检查，否则不得执行任何开发动作。**

1. **先进入 `ac-workflow`**
   - `ac-workflow` 会调用 `ac-memory`
   - `ac-memory` 负责检查/创建/校验 `.agents/state/INDEX.md` 与当前任务状态文件
   - 状态就绪后再路由到 `single` / `single + reviewer` 或 `planner / executor / reviewer`

2. **建议在本轮输出中回显当前任务状态（推荐）**：

```text
[STATE] <task-id> | <role> | <status> | 已检查 / 已更新
```

- 任务状态文件与 `.agents/state/INDEX.md` 才是 workflow 的真实状态源
- `[STATE]` 回显用于帮助用户感知当前任务，不再作为唯一门禁

### workflow 进度展示（标准输出）

```text
进入 workflow 模式

[🔍 澄清] → [📐 设计] → [⚡ 执行] → [✅ 校验] → [📝 总结]
  ▲ 当前
```

### 多角色路由（通用评分制）

**路由原则**：
- 默认 `single`
- 当任务风险或协调成本上升时，升级为 `planner / executor / reviewer`。

**风险评分维度（每项 0-2 分）**：
1. 复杂度：是否跨多个模块、页面、构建配置或数据层
2. 影响面：是否影响公共组件、共享导航、公共网络层、数据库、权限
3. 不确定性：需求是否模糊、方案是否需要比较、依赖信息是否不足
4. 变更风险：是否涉及迁移、兼容性、回滚难度、数据一致性
5. 验证成本：是否需要单测、设备验证、手工回归、不同 variant 验证

**触发阈值**：
- 总分 `0-3`：`single`
- 总分 `4-6`：`single + reviewer`
- 总分 `>=7`：完整多角色（`planner -> executor -> reviewer`）

**典型评分示例**：

- 单 README 文案或路径修正，且不改变 workflow 语义：复杂度 `0` + 影响面 `0` + 不确定性 `0` + 变更风险 `0` + 验证成本 `0` = `0`，走 `single`
- 单个 `SKILL.md` 的描述或触发词微调，不改变交接关系或 UI 展示语义：复杂度 `1` + 影响面 `1` + 不确定性 `0` + 变更风险 `0` + 验证成本 `0` = `2`，走 `single`
- 同步 `AGENTS.md`、`.agents/skills/`、`docs/*.md` 的 workflow 术语或模板语义：复杂度 `1` + 影响面 `1` + 不确定性 `1` + 变更风险 `1` + 验证成本 `1` = `5`，走 `single + reviewer`
- 修复 `scenes:convoai` 内单页面或单流程问题，未涉及共享字幕/构建/权限链路：复杂度 `1` + 影响面 `1` + 不确定性 `0` + 变更风险 `1` + 验证成本 `1` = `4`，走 `single + reviewer`
- 修改 `common` 公共能力或跨 `common` / `scenes:convoai` 的共享逻辑：复杂度 `2` + 影响面 `2` + 不确定性 `1` + 变更风险 `1` + 验证成本 `1` = `7`，走 `planner -> executor -> reviewer`
- 修改 `gradle.properties`、`build.gradle(.kts)`、`settings.gradle`、`AndroidManifest.xml` 等高风险配置：复杂度 `1` + 影响面 `2` + 不确定性 `1` + 变更风险 `2` + 验证成本 `1` = `7`，走 `planner -> executor -> reviewer`
- 修改 `convoaiApi` / `subRender` 字幕链路、RTM/RTC 消息解析或相关回调派发：复杂度 `2` + 影响面 `2` + 不确定性 `1` + 变更风险 `2` + 验证成本 `2` = `9`，走 `planner -> executor -> reviewer`
- 修改 IoT / BLE / 配网流程、设备权限或真机强依赖链路：复杂度 `2` + 影响面 `2` + 不确定性 `1` + 变更风险 `2` + 验证成本 `2` = `9`，走 `planner -> executor -> reviewer`

**路由语义（补充定义）**：
- `single`：不是独立 skill，而是由 `ac-workflow` 编排的折叠路由；同一 Agent 需先完成最小 `ac-plan` 职责，写出 `Execution Contract` 并设置 `PLAN_FROZEN=true`，再进入执行；执行后的收尾由 `ac-workflow` 负责完成最小自检，并在进入总结前写回 `CURRENT_ROLE: single`、`WORKFLOW_STATUS: completed`
- `single + reviewer`：先按 `single` 完成最小 planning + execution，再强制进入 `ac-review`
- `planner -> executor -> reviewer`：按显式多角色顺序交接；高风险任务默认使用该路线

附加约定：

- 涉及 `AGENTS.md`、`.agents/skills/`、`docs/*.md` 多文档联动时，复杂度和影响面通常不低于 `1`
- 涉及 workflow 路由、Execution Contract、评审模板、skill 触发描述调整时，默认至少带 `reviewer`

### 执行冻结与角色纪律

- `single`：由 `ac-workflow` 编排的折叠路由；同一 Agent 串行执行最小 `ac-plan -> ac-execute -> summary closeout`，但仍受冻结 Contract、范围控制与 Evidence / Gaps 约束
- `ac-memory`：负责 `.agents/state/INDEX.md` 与当前任务状态文件的本地记忆、结构校验与同步
- `ac-workflow`：负责 workflow 入口、阶段推进、`single` 折叠路由、continue 恢复与强制收尾编排
- `ac-plan`：在 `ac-memory` 校验通过后，产出并写入 `Execution Contract`，设置 `PLAN_FROZEN=true`
- `ac-execute`：在 `ac-memory` 校验通过且 `PLAN_FROZEN=true` 时，仅按 Contract 执行，不得新增设计
- `ac-review`：在 `ac-memory` 校验通过后，按 Contract 验收 Evidence/Gaps，必要时触发解冻回退
- `self-improving-agent`：在 `ac-review` 完成后按需提炼可复用经验，只写自身 `memory/`；若要采纳经验并修改仓库规则资产，必须重新进入 docs/skills workflow
- 执行中若出现新增设计、范围扩大、关键约束变化：必须回到 `ac-plan` 解冻重规划，再次冻结后继续


## AI 行为规范

### 任务状态文件维护（硬约束）

**核心原则**：
> **workflow 的状态源由 `.agents/state/INDEX.md` 与 `.agents/state/tasks/<task-id>.md` 组成；基础管理由 `ac-memory` 托管，workflow 编排由 `ac-workflow` 承接。**

#### 1. 维护入口

- 进入 workflow：先通过 `ac-workflow`
- `ac-workflow` 会调用 `ac-memory`
- `ac-memory` 负责：
  - 创建或校验 `.agents/state/INDEX.md`
  - 创建、选择或修复当前任务状态文件
  - 校验头字段（含 `TASK_ID` / `TASK_TYPE` / `WORKFLOW_STATUS`）与固定区块
  - 同步当前任务摘要

#### 2. 强制更新节点

- 创建 / 更新 todo
- 完成 todo item
- 提交 commit 后
- 阶段切换时
- 遇到阻塞 / 决策点时
- 新增或更新验证证据时
- 识别到未验证风险时
- **即使是轻量任务（单文件修改、同步、微调）**

> ⚠️ **禁止以"任务太小"为由跳过状态更新。**

#### 3.必备区块

当前任务状态文件头部必须包含：
- `TASK_ID: <yyyy-mm-dd-slug>`
- `TASK_TYPE: feat|fix|refactor|chore|docs`
- `PLAN_FROZEN: true|false`
- `CURRENT_ROLE: planner|executor|reviewer|single`
- `WORKFLOW_STATUS: active|blocked|completed`
- `STARTED_AT: YYYY-MM-DD`
- `LAST_UPDATED_AT: YYYY-MM-DD`

状态语义：
- `active`：任务正在推进，可继续执行或恢复
- `blocked`：已强制收尾，等待继续或补充信息
- `completed`：当前任务已收尾，不应仅因任务文件存在而自动触发 `continue`

当前任务状态文件必须包含并维护以下区块：
1. 目标
2. 下一步 Top 3
3. 阻塞项
4. 关键决策索引（最近 3 条）
5. 关键决策日志（全量追加）
6. 验收证据（Evidence）
7. 未验证清单（Gaps）
8. 提交计划
9. Execution Contract

`.agents/state/INDEX.md` 至少维护：

- `CURRENT_TASK`
- `## Active`
- `## Blocked`
- `## Completed`

#### 4. 模板
- 使用 `docs/TASK_STATE_TEMPLATE.md`
- 使用 `docs/STATE_INDEX_TEMPLATE.md`

### Commit Policy

- **允许执行 `git commit`**：仅当用户明确要求提交时
- **默认不提交**：未明确要求时，仅准备变更与提交建议
- **严格禁止 `git push`**：除非用户明确要求且单独确认
- Commit message 必须使用英语，并使用动态模型名协作者信息：
  - `Co-Authored-By: <llm-model>`（示例：`Co-Authored-By: GPT-5.3-Codex`）
- `.agents/state/INDEX.md` 与 `.agents/state/tasks/*.md` 默认不提交；仅在以下情况提交：
  - 跨环境/跨会话同步需要
  - 用户明确要求

### 质量审查

- **生成 ≠ 完成**
- 每完成一个 todo item 后，主动检查是否需要 review
- Review 内容：
  - 代码：逻辑正确性、Kotlin 类型安全、边界处理、生命周期与线程安全
  - 配置与链路：BuildConfig 注入、flavor、权限、RTC/RTM、字幕、IoT/BLE 影响是否说清楚
  - 文档：内容准确性、路径真实可达、命令可执行、模板可复用、skill 触发条件清晰
- 对开发态联调 / debugging 任务，发起 review 前必须显式说明以下边界，并同步写入 `Execution Contract` / `Evidence` / `Gaps`：
  - 本地缓存或调试数据是否会清空，是否要求兼容旧数据
  - 哪些后端契约或联调前提已被默认采用
  - 哪些行为是本轮明确非目标，不应按发布态默认要求直接判成回退
  - 哪些看起来有风险的行为目前只能记为 `Gaps` / `assumption` / `open question`
- 若 reviewer 发现的问题与上述边界不冲突，应优先定性为未验证风险或契约问题，而不是直接要求回退实现
- **发现问题立即修复，不得累积**

### 完成判定与验证新鲜度

- “已完成 / 已修复 / 已验证通过” 的表述，必须基于本轮新增的 fresh Evidence
- 历史 Evidence 只能作为背景，不得直接替代本轮验证结论
- 若本轮只完成了代码或文档修改，但未完成声明中的验证，必须明确写入 `Gaps`
- `review pass` 表示当前实现与 Contract 一致并可按本轮收尾，不自动等于所有运行时风险已消除
- docs-only / skills-only 任务同样需要本轮一致性检查证据，不得仅以“已同步”作为完成依据

### 对话评审（自动执行）

#### 常规轮次（简化）

```text
进度：📐设计 → ⚡执行 | 轮次 5 | +32 -10 行
```

#### 阶段切换（完整）

```text
进入 ⚡执行 阶段

[🔍 澄清] → [📐 设计] → [⚡ 执行] → [✅ 校验] → [📝 总结]
                          ▲ 当前
```

#### 任务完成（效率统计）

```text
📊 本次对话统计
轮次：12 | Tokens：~8.2k | 变更：+156 -23 ~45
🤖 15min | 🧑‍💻 3h | ⬇️ 2.75h
```

评审标准参考：`docs/REVIEW_TEMPLATES.md`

### 上下文管理（强制收尾）

当出现以下任一情况时，必须先刷新当前任务状态文件与 `.agents/state/INDEX.md` 再继续：

- 对话超过 10 轮
- 大量代码或文档变更
- 用户提示上下文不足
- Agent 感知上下文风险

- 强制收尾时，将 `WORKFLOW_STATUS` 更新为 `blocked`；review 通过并进入总结收尾时，将其更新为 `completed`。

输出格式：

```text
⚠️ 建议切换新对话

已完成：
- [已完成任务列表]

待继续：
- [未完成任务列表]

下一步：开启新对话，输入「继续 <任务名>」
```

## Android 开发约束

### 模块与边界

- 优先在声明范围内修改模块，不随意跨 `app/common/scenes/docs/.agents` 扩散
- `app` 只承载启动壳、flavor、Manifest、签名与入口逻辑，不要把业务细节回灌到 `app`
- `common` 是高影响公共底座，改动默认要说明对 Agora、网络、存储、BuildConfig 注入和所有上层模块的影响
- `scenes:convoai` 负责主业务；`scenes:convoai:iot -> scenes:convoai:bleManager` 是外设链路，相关改动需要说明依赖传播
- 涉及 `settings.gradle`、任一 `build.gradle(.kts)`、`gradle/libs.versions.toml` 时，视为高风险
- 涉及 `scenes/convoai/src/main/java/io/agora/scene/convoai/convoaiApi/` 或 `subRender/` 字幕组件时，按高风险处理，并明确说明对包名结构、字幕回调和 RTC/RTM 消息链路的影响

### 配置与构建

- `gradle.properties` 是项目主要配置入口；涉及 `AG_APP_ID`、`BASIC_AUTH_*`、`LLM_*`、`TTS_*`、`AVATAR_*`、`TOOLBOX_SERVER_HOST`、`IS_OPEN_SOURCE` 时，必须说明影响范围
- 不要在代码、文档或提交说明中随意扩散真实密钥、证书或厂商参数；示例优先使用占位值
- 当前 `app` 只有 `china` flavor；涉及 `applicationId`、`resValue(app_name)`、签名、APK 命名、BuildConfig 字段时，按高风险处理
- 当前存在 Java 17 与 Java 11 混用；跨 `app/common/scenes` 与 `iot/bleManager` 的构建或语言级别调整，必须列入验证清单

### UI 与状态

- 默认遵循项目现有 UI 方案；当前仓库以 ViewBinding + Activity/Fragment 为主，无需求时不要大规模引入 Compose
- 涉及生命周期、状态恢复、导航返回栈、权限申请时，必须列入验证清单
- 涉及无障碍、深色模式、横竖屏、平板适配时，必须说明是否已验证

### 权限、音视频与外设

- 涉及 `CAMERA`、`RECORD_AUDIO`、`POST_NOTIFICATIONS`、前台服务、Wi-Fi、蓝牙或媒体读取权限时，必须说明申请时机、拒绝路径和回归范围
- 涉及 RTC / RTM、toolbox server、agent 消息、字幕、数字人、录音或回调派发时，必须说明链路影响与失败处理
- 涉及 IoT / BLE / 配网流程时，必须列入设备权限、蓝牙状态、Wi-Fi、系统版本和真机验证要求

### 数据与并发

- 涉及 Room、Proto DataStore、网络缓存、离线状态时，必须显式写出迁移或兼容性风险
- 涉及协程、线程切换、取消逻辑、Flow/LiveData 状态传播时，优先做最小改动并补充验证

### 文档与 Skill

- 修改 `AGENTS.md`、`.agents/skills/*.md`、`docs/*.md` 时，必须检查三者是否需要同步，避免规则漂移
- `SKILL.md` 的 `description` 必须同时说明“做什么”和“什么时候用”，并包含能触发该 skill 的关键词
- 若外部 skill 编写方法论与本仓库规则不一致，以 `AGENTS.md` 的 repo-local 约定为准
- skill 应优先服务 repo 当前 workflow，不应无条件覆盖 `ac-*` 主骨架；需尽量写清输入、输出、交接边界和禁止项
- 修改 skill 时，除 `AGENTS.md`、`.agents/skills/*.md`、`docs/*.md` 外，还应评估是否同步同链路 skill 与 `agents/openai.yaml`
- 若只是补现有 skill 的边界、触发词或模板，优先修改原 skill，而不是新增近义 skill
- 模板中的模块名、路径示例必须使用当前仓库真实结构，例如 `common/`、`scenes/convoai/`、`.agents/skills/`
- 文档类任务不得伪造构建或测试结论；未运行的命令要明确写入 `Evidence` / `Gaps`
- 若文档 / skill 涉及 review 规则，应明确区分“已证实的回归”和“开发态联调下的未验证假设 / 契约前提 / 非目标”
- 若 skill 规则改变了交接关系、入口或 UI 展示语义，应评估是否同步对应的 `agents/openai.yaml`

## 工具链与检查

常见命令根据项目实际脚本调整，默认建议：

```bash
./gradlew lint
./gradlew test
./gradlew :app:assembleChinaDebug
```

如项目已集成，可额外运行：

```bash
./gradlew detekt
./gradlew ktlintCheck
./gradlew connectedDebugAndroidTest
```

纯文档 / skill / template 任务默认改用以下检查，除非改动触及代码或构建配置：

```bash
rg -n "PROJECT_STATE\\.md|旧术语|旧路径|过时模块名" AGENTS.md docs .agents/skills
rg -n "TASK_ID|TASK_TYPE|PLAN_FROZEN|CURRENT_ROLE|WORKFLOW_STATUS|Execution Contract" AGENTS.md docs .agents/skills
```

- 检查模块名、路径、命令示例是否与仓库一致
- 检查 `AGENTS.md`、`.agents/skills`、`docs/*.md` 的 workflow 术语是否一致
- 检查文档示例是否区分“代码任务校验”与“docs-only 校验”
- 若涉及 `gradle.properties`、Manifest、`convoaiApi`、IoT 或 BLE，还要补充链路与权限层面的影响说明

## 文档导航

- `ARCHITECTURE.md`：项目全局模块关系、主链路与高风险区域总览
- `docs/TASK_STATE_TEMPLATE.md`：任务状态模板
- `docs/STATE_INDEX_TEMPLATE.md`：任务索引模板
- `docs/WORKFLOW_TEMPLATES.md`：Android 开发任务模板
- `docs/REVIEW_TEMPLATES.md`：阶段自检与结果验收模板
- `docs/PR_CHECKLIST.md`：PR Review 标准
- `docs/DEBUG_WORKFLOW.md`：debugging / 联调任务的定位、证据与收尾规则
- `scenes/convoai/README.md`：Convo AI 场景总览与运行说明
- `scenes/convoai/src/main/java/io/agora/scene/convoai/convoaiApi/README.md`：字幕 / 消息 / API 组件说明
- `.agents/skills/ac-workflow/SKILL.md`：workflow 入口编排
- `.agents/skills/ac-memory/SKILL.md`：任务索引与状态文件校验 / 修复
- `.agents/skills/ac-plan/SKILL.md`：冻结 Contract
- `.agents/skills/ac-execute/SKILL.md`：按 Contract 执行
- `.agents/skills/ac-review/SKILL.md`：按 Evidence / Gaps 验收
- `.agents/skills/self-improving-agent/SKILL.md`：`ac-review` 后的可选复盘与 repo-local memory 提案
