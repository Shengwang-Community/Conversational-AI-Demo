# Android 与 AI 工程化工作流模板

开始任务前，先识别 mode 与任务类型；若当前只是读代码、看 diff、定位根因，可先停留在 `analysis`。一旦进入执行，再由 workflow 绑定到当前任务状态文件。

**仓库范围提示**

- 业务模块：`app`、`common`、`scenes/convoai`、`scenes/convoai:iot`、`scenes/convoai:bleManager`
- AI 工程化资产：`AGENTS.md`、`.agents/skills/`、`.agents/state/INDEX.md`、`.agents/state/tasks/`、`docs/*.md`
- UI 现状：默认按当前 `Activity` / `Fragment` / `ViewBinding` 体系思考，除非需求明确要求 Compose

**通用约束**

- workflow 任务每次阶段结束必须更新当前任务状态文件，并同步 `.agents/state/INDEX.md`
- analysis 模式允许只读命令，不写任务状态
- 纯文档 / skill / template 任务也属于 workflow，不按 general 模式处理
- 存在未完成任务不等于自动 continue；只有用户明确说“继续 / 接着做 / 继续 <TASK_TITLE> / 继续 <task-id>”时，才按 continue 恢复
- continue 进入前，先由 `ac-workflow` 从索引和未完成任务摘要中解析目标任务，再交给 `ac-memory` 绑定状态文件
- 若存在多个未完成任务，先要求用户指定 `TASK_TITLE` 或 `task-id`
- 带 reviewer 的路线在 `✅ 校验` 通过后，统一回交 `ac-workflow` 执行最终 `📝 总结`
- 代码任务优先跑 `gradlew` 检查；docs-only 任务优先做路径、术语、模板一致性检查
- 触及 `scenes/convoai/src/main/java/io/agora/scene/convoai/convoaiApi/` 或 `subRender/` 字幕组件时，默认按高风险处理，扩大验证范围

---

## feat（新功能 / 新页面 / 新模块）

### 入口分流

1. 是否新增 `Activity` / `Fragment` / 自定义 View / 对话页面？
2. 是否新增模块、导航入口、权限、接口、配置项或资源文件？
3. 是否影响 `common` 公共能力或 `scenes/convoai` 主场景？

### 最小问题集

- 目标功能是什么，入口在哪个模块？
- 期望行为、失败行为、验收标准是什么？
- 是否涉及 RTC / RTM / RESTful / IoT / 权限 / 生命周期？

### 动作清单

- [ ] 确认模块与目录归属
- [ ] 明确 Loading / Empty / Error / Success 态
- [ ] 明确导航、返回栈、权限、生命周期影响
- [ ] 补充必要的数据层、接口、类型和测试
- [ ] 运行 `./gradlew lint`
- [ ] 运行 `./gradlew test`

### 完成标准

- 功能可用且符合验收标准
- 关键状态、错误态、返回路径可用
- Evidence 与 Gaps 记录完整

---

## fix（问题修复）

### 入口分流

1. 是否可稳定复现？
2. 是否与系统版本、机型、网络、权限、音视频链路或设备连接相关？
3. 是否与最近一次改动或某个模块边界有关？

### 最小问题集

- 复现步骤、期望行为、实际表现分别是什么？
- 涉及页面、模块、日志、崩溃栈或接口是什么？
- 是否影响登录、入会、对话、录音、IoT 配网等关键路径？
- 是否涉及 `convoaiApi` / `subRender` 字幕组件、RTM 消息解析、字幕回调或包名结构？

### 动作清单

- [ ] 定位触发路径与责任边界
- [ ] 做最小修复，避免顺手重构
- [ ] 若涉及字幕组件，检查包名结构、消息解析、字幕渲染与回调链路
- [ ] 回归相邻路径（返回、重试、旋转屏、前后台切换、权限再次申请）
- [ ] 保留必要日志、截图或手工路径作为 Evidence

### 完成标准

- 缺陷不再复现
- 无明显行为回归
- 必要检查通过或已在 Gaps 中说明未验证原因

---

## refactor（重构）

### 入口分流

1. 是否改变外部行为、数据结构或对外接口？
2. 是否跨 `common`、`scenes/convoai`、`scenes/convoai:iot`、`scenes/convoai:bleManager` 等边界？
3. 是否需要分阶段推进、保留兼容层或拆成多次提交？

### 最小问题集

- 重构目标和范围是什么？
- 哪些行为必须保持不变？
- 是否涉及公共基类、导航、Repository、并发、缓存、权限流程，或 `convoaiApi` 字幕组件链路？

### 动作清单

- [ ] 定义边界与不变量
- [ ] 小步替换并验证
- [ ] 记录兼容性风险与回滚方式
- [ ] 更新相关文档与模板

### 完成标准

- 外部行为保持一致
- 关键测试与人工验证通过
- 回滚路径清晰

---

## chore（工程化 / 依赖 / 配置）

### 入口分流

1. 是否涉及 `settings.gradle`、任一 `build.gradle(.kts)`、`gradle/libs.versions.toml`？
2. 是否影响构建、CI、签名、混淆、版本管理或产物？
3. 是否会影响多个模块或三方 SDK 兼容性？

### 最小问题集

- 目标依赖或配置是什么？
- 变更动机与风险是什么？
- 是否有官方迁移说明、版本兼容性要求或回滚方案？

### 动作清单

- [ ] 更新依赖或配置
- [ ] 运行 `./gradlew lint` / `./gradlew test`
- [ ] 运行必要的 `assemble` 或 instrumentation
- [ ] 记录兼容性变化与潜在回滚方案

### 完成标准

- 变更生效
- 关键脚本通过
- 风险已记录

---

## docs（文档 / skills / templates / workflow 规范）

适用范围：`AGENTS.md`、`.agents/skills/*.md`、`docs/*.md`、模块 README 等文档资产。

### 入口分流

1. 是否修改 workflow 规则、Execution Contract、review 标准或模板？
2. 是否修改 `.agents/skills` 的 `description`、交接边界或使用场景？
3. 是否需要同步 `AGENTS.md`、模板文档与 skill 文档，避免规则漂移？

### 最小问题集

- 要解决的是触发不清、规则冲突、路径不准，还是模板不可执行？
- 涉及哪些文档必须联动更新？
- 这次改动会不会改变 docs-only 任务、continue 流程或 reviewer 结论？

### 动作清单

- [ ] 对照仓库实际结构，校准模块名、路径和命令示例
- [ ] 检查 `AGENTS.md`、`.agents/skills`、`docs/*.md` 的术语与阶段定义是否一致
- [ ] 为 `SKILL.md` 补足清晰的 `description`、交接边界和禁止项
- [ ] 在 Evidence 中记录本次一致性检查结果，在 Gaps 中记录未演练场景

### 完成标准

- 文档内容与当前仓库结构一致
- workflow、template、skill 之间无明显冲突
- docs-only 检查方式清晰，不伪造代码构建结论

---

## 通用检查清单

在任何工作流结束前，确保：

- [ ] 当前任务状态文件与 `.agents/state/INDEX.md` 已更新
- [ ] Evidence 与 Gaps 已补充
- [ ] 如用户要求提交，提交策略已明确
- [ ] 代码任务：相关 `gradlew` 检查通过或已说明未运行原因
- [ ] docs-only 任务：路径、术语、模板、skill 描述一致性已核对
