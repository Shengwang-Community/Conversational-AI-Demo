# Android 与 AI 工程化评审标准（Agent 自检用）

Agent 在每个阶段结束时自动按此标准评审并输出结论。用户无需参与，除非主动要求交互式评审。

---

## 使用方式

- 默认模式：Agent 自动评审，输出进度、Evidence、Gaps 和风险
- 交互模式：用户说“详细评审”或“逐项检查”时，逐条展示

### 显式 Trigger

- `开发态联调 review`：进入开发联调评审模式
- `问题修复 review`：进入问题修复评审模式
- 未命中以上短语：按默认 code review 模式处理

补充约定：

- 仅对精确短语生效，不做模糊匹配
- 精确短语可来自用户请求，或已被写入 `Execution Contract`
- 若两个 trigger 同时出现，先澄清，再评审

---

## 阶段标识

### 完整进度条（阶段切换时显示）

```text
[🔍 澄清] → [📐 设计] → [⚡ 执行] → [✅ 校验] → [📝 总结]
              ▲ 当前
```

### 阶段说明

| 图标 | 阶段 | 含义 | 允许行为 |
|---|---|---|---|
| 🔍 | 澄清 | 理解需求、复现问题、识别影响范围 | 询问、拆解、识别边界 |
| 📐 | 设计 | 方案规划、划定 Contract、评估风险 | 结构化推理、给有限选项 |
| ⚡ | 执行 | 改代码、写文档、改 skill、运行声明范围内检查 | 直接 action，禁止新增设计 |
| ✅ | 校验 | 检查结果、记录 Evidence/Gaps | 对照检查、指出风险 |
| 📝 | 总结 | 沉淀产出、给出后续建议 | 结构化总结 |

补充约定：

- 带 reviewer 的路线中，`✅ 校验` 通过后统一回交 `ac-workflow` 执行 `📝 总结`；`ac-review` 不直接承担最终总结收尾

---

## 对话评审（Agent 自检）

每次输出前自检：

1. 阶段是否正确，是否跨阶段操作
2. 输出是否收敛，是否给出有限选项
3. 是否重复了用户已确认内容
4. 缺少信息时是否停止假设并写入 Gaps
5. 是否更新了当前任务状态文件与 `.agents/state/INDEX.md` 中需要同步的状态

---

## Review 发起与反馈闭环

### 何时应主动发起 review

- 完成 major feature、复杂 bugfix 或跨模块重构后
- docs / skills / workflow 规则任务完成主要修改后
- 准备进入 merge / 提交前，且希望确认当前实现或文档是否满足 Contract
- 执行中遇到高不确定性问题，希望获得一次 fresh review 视角时

### 发起 review 前的最小材料

发起 review 前，至少准备以下材料：

- 本轮实现或修改摘要
- 对应的 plan / requirements / Execution Contract
- 本轮实际改动的文件或模块
- 已运行的 checks 与结果
- 当前 `Evidence`
- 当前 `Gaps`
- 尚未关闭的假设、非目标或联调前提

docs-only / skills-only 任务还应补充：

- 联动同步的文档或 skill 文件清单
- 本轮一致性检查方式与结果

### 收到 review 后的标准动作

收到 review feedback 时，先完成以下动作，再决定是否实现：

1. 先完整读完反馈，不立刻承诺实现
2. 若有不清楚的条目，先澄清再继续
3. 对照当前代码、文档、Contract、Evidence 与仓库实际进行验证
4. 对每条 finding 仅给出一个结果：
   - `fixed`
   - `rejected with evidence`
   - `accepted as gap`
   - `requires re-plan`
5. 先将对应结论写入当前任务状态文件的 `Review Findings（闭环）`，并同步任务索引，再进入后续实现或收尾

### 何时必须回到 `ac-plan`

若 review finding 导致以下任一变化，必须回到 `ac-plan`：

- Scope 变化
- Files to change 变化
- Checks 变化
- 关键假设、联调前提或 rollback 策略变化
- 原 Contract 已不足以覆盖当前修复范围

---

## Android 变更评审（提交前自检）

### 范围与边界

- [ ] 只做了声明范围内的改动
- [ ] 未意外改动无关模块
- [ ] 公共 API、导航、权限、数据库、构建配置的影响已说明
- [ ] 若改动 `convoaiApi` / `subRender`，已说明对字幕组件、包名结构和转录链路的影响

### Kotlin 与并发

- [ ] 类型安全与空安全合理
- [ ] 协程、线程切换、取消逻辑无明显问题
- [ ] Flow / LiveData / State 的来源与消费路径清晰

### 生命周期与状态

- [ ] 不存在明显生命周期泄漏风险
- [ ] 返回栈、旋转屏、前后台恢复行为已考虑
- [ ] 权限申请、异常态、重试态处理合理

### UI 与体验

- [ ] Loading / Empty / Error / Success 态完整
- [ ] ViewBinding / Fragment / Activity 更新逻辑无明显异常
- [ ] 如有需要，已考虑无障碍、深色模式、平板和横竖屏

### 质量与验证

- [ ] 已运行声明中的检查（代码任务为 `gradlew`，文档任务为一致性检查）
- [ ] Evidence 已记录具体命令、结果或人工验证
- [ ] Gaps 已记录尚未验证的风险与原因
- [ ] 若涉及字幕组件，已核对 RTM/RTC、消息解析、字幕回调或渲染路径的验证情况

### 开发态联调边界（命中 `开发态联调 review` 时）

- [ ] 若本轮属于开发态联调 / debugging，`Execution Contract` 已明确写出本地缓存 / 调试数据策略
- [ ] 若本轮依赖后端契约、联调约定或服务端默认前提，Evidence / Gaps 已明确写出这些假设
- [ ] 明确非目标已写出，review 未把这些非目标直接当成发布态回退
- [ ] 尚未证实的问题已优先定性为 `Gaps` / `assumption` / `open question`，而不是在缺证据时直接升格为 blocker

### 问题修复关注点（命中 `问题修复 review` 时）

- [ ] 问题现象、期望结果与修复范围已在 Contract / Evidence 中写清楚
- [ ] review 已优先检查“是否真的修好”，而不是只看代码风格或重构质量
- [ ] review 已检查是否引入回归、边界条件缺口或兼容性问题
- [ ] 若缺少必要验证，问题应被标记为未完成闭环，而不是被误判为“只要看起来合理就算修复”

---

## 文档与 Skill 变更评审

适用于 `AGENTS.md`、`.agents/skills/*.md`、`docs/*.md`、README 等文档资产。

### 一致性

- [ ] `AGENTS.md`、`.agents/skills`、`docs/*.md` 的 workflow 术语一致
- [ ] 任务阶段、角色路由、`PLAN_FROZEN` / `CURRENT_ROLE` 语义一致
- [ ] 模块名、路径示例、命令示例与当前仓库一致

### Skill 质量

- [ ] `SKILL.md` 的 `description` 同时说明“做什么”和“什么时候用”
- [ ] skill 的输入、输出、交接边界和禁止项清晰
- [ ] 无把 docs-only 任务误写成必须跑 `gradlew` 的情况

### 模板可执行性

- [ ] workflow 模板覆盖代码任务与 docs-only 任务
- [ ] `TASK_STATE_TEMPLATE.md` 能承载 Evidence / Gaps / Contract
- [ ] 评审模板与 PR checklist 能覆盖本次改动类型

### 证据与风险

- [ ] 已记录文档一致性检查结果
- [ ] 尚未实际演练的 skill / continue 场景已写入 Gaps
- [ ] 未运行的命令、未验证的流程没有被包装成“已完成”
- [ ] review request 已携带最小材料，未以“改完了”替代 Contract / Evidence / Gaps
- [ ] review findings 已写回 `Review Findings（闭环）` 并显式闭环，未出现未归类的反馈项

---

## 输出格式

### 简化版（每次输出末尾）

```text
进度：📐设计 → ⚡执行 | 轮次 5 | 结构已冻结
```

### 需确认时

```text
⚠️ 需确认 | 📐设计 | 变更超出声明范围，是否继续？
```

### 开发态联调评审提示

```text
⚠️ 开发态联调边界 | ✅校验 | 以下行为按已声明假设评审：本地缓存策略、后端契约前提、明确非目标；未证实部分先记入 Gaps / assumption / open question
```

### 问题修复评审提示

```text
⚠️ 问题修复评审 | ✅校验 | 当前按问题修复模式评审：优先确认问题是否真正修复、是否引入回归、验证与验收是否闭环
```

### 阻塞时

```text
❌ 阻塞 | 🔍澄清 | 缺少必要信息，请补充 XXX
```

---

## 交互式评审（仅按需）

用户说以下关键词时进入交互模式：

- 详细评审
- 逐项检查
- 展开评审

交互模式下逐条展示检查项和结果。
