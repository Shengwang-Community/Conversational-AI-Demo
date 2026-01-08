## 变更类型
<!-- 选择一个 -->
- [ ] ✨ Feature - 新功能
- [ ] 🐛 Fix - Bug 修复
- [ ] ♻️ Refactor - 代码重构
- [ ] 📝 Docs - 文档更新
- [ ] ⚡ Perf - 性能优化
- [ ] 🧪 Test - 测试相关
- [ ] 🔧 Chore - 构建/工具链相关

## 变更说明
<!-- 简要描述改动内容，回答"做了什么"和"为什么这么做" -->





## 影响范围
<!-- 列出影响的模块、页面、API，帮助 Reviewer 快速理解影响面 -->

**影响的模块**:
- [ ] API Manager (api/)
- [ ] UI 组件 (ui/)
- [ ] Activity/Fragment (ui/)
- [ ] ViewModel (ui/)
- [ ] 工具函数 (util/)
- [ ] 资源文件 (res/)
- [ ] 配置 (build.gradle / gradle.properties)
- [ ] 文档

**具体影响**:
- Activity/Fragment:
- ViewModel:
- API Manager:
- 共享组件/工具类:

## 破坏性变更
<!-- 如果有破坏性变更，请详细说明 -->
- [ ] 无破坏性变更
- [ ] 包含破坏性变更（请在下方说明）

**Breaking Changes 说明**:
<!-- 如有，请详细说明变更内容和迁移方案 -->



## 测试说明
<!-- 如何验证这个 PR 的改动 -->

### 测试步骤
1.
2.
3.

### 测试环境
- [ ] 本地开发环境（Debug APK）
- [ ] Release 构建测试

### 测试设备
- [ ] Android 7.0+ (API 24+)
- [ ] 不同屏幕尺寸
- [ ] 深色模式（如涉及 UI）

## 提交前自检清单
<!-- 提交 PR 前请确保以下项目已完成 -->

### 必须完成（⚠️）
- [ ] ✅ 运行 `./gradlew lint` 通过（**必须**）
- [ ] ✅ 运行 `./gradlew test` 通过
- [ ] ✅ 运行 `./gradlew assembleDebug` 成功
- [ ] ✅ 已阅读 [Android/.cursorrules.md](./Android/.cursorrules.md)

### 代码质量
- [ ] 遵循 [Android/.cursorrules.md](./Android/.cursorrules.md) 开发规范
- [ ] 遵循 MVVM 架构（UI → ViewModel → API Manager）
- [ ] 使用 ViewBinding，无 `findViewById`
- [ ] 无 `Log.d/e` 残留（使用 `CovLogger`）
- [ ] 协程使用 `viewModelScope` 或 `lifecycleScope`
- [ ] LiveData 观察使用正确的 LifecycleOwner

### 架构规范
- [ ] ViewModel 继承 `ViewModel`，使用 `viewModelScope`
- [ ] 状态使用 `LiveData` 或 `StateFlow`
- [ ] 私有数据使用 `MutableLiveData`/`MutableStateFlow`，公开只读版本
- [ ] API Manager 使用 `object` 单例模式
- [ ] 错误处理统一使用 `ApiException`

### 资源管理
- [ ] 字符串资源定义在 `strings.xml`，使用 `R.string.cov_xxx`
- [ ] 图片使用 Glide 加载
- [ ] 资源命名遵循 `cov_` 前缀规范
- [ ] 支持深色模式（如涉及颜色资源）

### 用户体验
- [ ] 有 Loading 状态（使用 `AgentListState.Loading`）
- [ ] 有错误处理和 Toast 提示（使用 `ToastUtil`）
- [ ] 有空态提示（如列表为空，使用 `AgentListState.Empty`）
- [ ] 危险操作有二次确认
- [ ] 网络错误有友好提示

### 内存和性能
- [ ] Fragment 中 ViewBinding 在 `onDestroyView()` 中置为 null
- [ ] LiveData 观察使用 `viewLifecycleOwner`（Fragment）
- [ ] 图片使用 Glide 自动管理内存
- [ ] 无内存泄漏风险（检查协程和观察者）

### 测试和文档
- [ ] 新功能有测试覆盖（如有）
- [ ] 复杂逻辑有 KDoc 注释说明
- [ ] 如有 API 变更，文档已更新
- [ ] 关键方法有参数和返回值说明

## 截图/录屏（如有 UI 变更）
<!-- 添加截图或录屏，帮助 Reviewer 理解 UI 变更 -->



## 补充说明
<!-- 其他需要 Reviewer 注意的信息 -->



---

## Review 指引

**给 Reviewer 的建议**:
- 使用 AI 工具（VSCode Copilot / Cursor）辅助 review
- Prompt: `请按照 Android/.cursorrules.md 的标准 review 这个 PR`
- 重点关注：
  - ✅ MVVM 架构规范（UI → ViewModel → API Manager）
  - ✅ ViewBinding 使用（禁止 findViewById）
  - ✅ 协程和 LiveData 的正确使用
  - ✅ 内存泄漏预防（ViewBinding 清理、LifecycleOwner）
  - ✅ 资源前缀规范（`cov_`）
  - ✅ 日志使用 `CovLogger`（禁止 Log.d/e）
  - ✅ 错误处理和用户体验
