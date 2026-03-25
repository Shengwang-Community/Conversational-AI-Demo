# Android 与 AI 工程化 PR Review 检查清单

> 供 AI 工具和人工 Reviewer 使用的项目 PR 审查标准，覆盖代码、文档、workflow 与 skill 资产。

---

## 1. PR 基本信息分析

### 变更范围识别

- [ ] 变更类型：Feature / Fix / Refactor / Docs / Chore / AI-Workflow / Perf
- [ ] 影响模块：`app` / `common` / `scenes/convoai` / `scenes/convoai:iot` / `scenes/convoai:bleManager` / `docs` / `.agents/skills`
- [ ] 变更规模：文件数量、代码行数（+XXX / -XXX）
- [ ] 是否包含 Breaking Changes
- [ ] 是否修改依赖、Gradle 配置、版本目录、Manifest、数据库 Schema、workflow 规则

### 影响范围评估

- [ ] 影响的页面、导航路径或用户关键路径
- [ ] 影响的公共组件、基础模块、共享 skill 或模板
- [ ] 影响的数据层、缓存、Room Schema、DataStore、权限
- [ ] 影响的构建配置、variant、签名、混淆、CI、Agent workflow
- [ ] 若涉及 `convoaiApi` / `subRender`，已评估字幕组件、包名结构、RTM/RTC 与转录链路风险

---

## 2. 架构与模块边界

- [ ] 改动放在正确的模块与目录
- [ ] 无无意义的跨模块扩散
- [ ] 公共模块或共享文档变更已说明影响面
- [ ] 依赖方向合理，无循环依赖
- [ ] 未顺手混入无关重构

---

## 3. Kotlin 类型与协程安全

- [ ] 空安全处理合理
- [ ] 无无充分理由的 `!!`
- [ ] Result / sealed class / error path 设计清晰
- [ ] 协程作用域、线程切换、取消逻辑合理
- [ ] Flow / StateFlow / SharedFlow 的使用符合场景

---

## 4. UI、交互与可用性

- [ ] Loading / Empty / Error / Success 态完整
- [ ] 当前 ViewBinding / Fragment / Activity 状态驱动清晰
- [ ] 用户操作有成功/失败反馈
- [ ] 危险操作有二次确认
- [ ] 如有需要，已考虑无障碍、深色模式、平板和横竖屏

---

## 5. 生命周期与状态恢复

- [ ] 返回栈行为正确
- [ ] 旋转屏或配置变更后状态可恢复
- [ ] 前后台切换无明显异常
- [ ] 权限申请、重试、重新进入场景已考虑
- [ ] 无明显内存泄漏或观察者泄漏风险

---

## 6. 数据、网络与持久化

- [ ] API 请求有错误处理与超时策略
- [ ] 缓存、离线、重试策略合理
- [ ] Room / DataStore / 文件存储改动已说明兼容性
- [ ] 若涉及 migration，已提供验证方式
- [ ] 日志中无敏感信息泄露
- [ ] 若涉及字幕组件，消息解析、字幕回调、版本兼容性与包名结构要求已说明

---

## 7. 构建与质量检查

- [ ] 代码任务：`./gradlew lint` 通过
- [ ] 代码任务：`./gradlew test` 通过
- [ ] 必要的 `assemble` 或 instrumentation 已验证
- [ ] 文档任务：已完成路径 / 术语 / 模板 / skill 一致性检查
- [ ] 无明显编译告警、静态检查遗漏或文档虚假结论

---

## 8. 性能与稳定性

- [ ] 无明显主线程阻塞风险
- [ ] 列表、图片、动画或大对象加载无明显性能隐患
- [ ] View 刷新、observer 频率或音视频链路无明显稳定性问题
- [ ] 启动路径与关键交互未明显变慢

---

## 9. 文档与 AI 资产可维护性

- [ ] 复杂逻辑有必要说明
- [ ] Magic numbers 已提取或解释
- [ ] 公共接口、配置变更、迁移点已同步文档
- [ ] `AGENTS.md`、`.agents/skills`、`docs/*.md` 的 workflow 语义一致
- [ ] `SKILL.md` 的 `description`、边界、禁止项足够清晰
- [ ] `PROJECT_STATE.md` 中 Evidence / Gaps 已同步

---

## 10. Git 提交质量

- [ ] Commit message 清晰，符合目标仓库约定
- [ ] 一个 commit 只做一件事（原子性）
- [ ] 无 `wip`、`fix typo` 等低质量提交
- [ ] 分支与提交策略符合团队规范

---

## AI Review 输出模板

```markdown
# PR Review 总结

## 变更概览
- 类型：Feature / Fix / Refactor / Docs / Perf / Chore / AI-Workflow
- 影响模块：[列出具体模块]
- 代码行数：+XXX / -XXX
- 变更文件：XX 个
- 风险等级：低 / 中 / 高

## 检查通过项
- [x] 架构与模块边界
- [x] Kotlin 类型与协程安全
- [x] UI 与交互
- [x] 生命周期与状态恢复
- [x] 构建与质量检查
- [x] 文档与 AI 资产一致性

## 需要改进的问题
1. [模块/文件:行号] 问题描述
   - 风险：
   - 建议：
   - 参考：

## 整体评价
- 建议：可以合并 / 修复后再审 / 不建议合并
- 总结：1-2 句话概括主要优点与主要风险
```
