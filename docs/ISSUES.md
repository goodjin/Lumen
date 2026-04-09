# Good First Issues

以下是为 pdf-ve 项目精选的 "good first issue" 列表，供手动创建 GitHub Issues 时使用。

---

## Issue 1: 添加深色模式支持

**标题**: [good first issue] 添加深色模式支持

**描述**:

**Problem（问题）**:
当前应用仅支持浅色模式。在 macOS 系统启用深色模式时，应用界面仍然是浅色，与系统主题不一致，影响用户体验。

**Solution（解决方案）**:
实现自动跟随系统主题的深色/浅色模式切换。应用界面应根据 macOS 系统偏好设置自动调整颜色方案。

**Acceptance Criteria（验收标准）**:
- [ ] 应用在浅色模式下显示浅色主题界面
- [ ] 应用在深色模式下显示深色主题界面
- [ ] 当系统主题切换时，应用界面自动响应变化
- [ ] 所有 UI 组件（工具栏、侧栏、注释等）均正确响应主题切换
- [ ] 标注颜色在不同主题下保持良好可读性

**Labels**: good first issue

---

## Issue 2: 导出标注为 PDF

**标题**: [good first issue] 导出标注为 PDF

**描述**:

**Problem（问题）**:
当前版本仅支持将标注导出为纯文本格式（.txt），无法保留标注在原始 PDF 页面上的位置和样式。用户希望导出的 PDF 能保留高亮、下划线、注释等视觉标注。

**Solution（解决方案）**:
扩展导出功能，支持将标注以 PDF 格式导出，保留原始 PDF 页面布局及所有视觉标注。

**Acceptance Criteria（验收标准）**:
- [ ] 菜单「文件 > 导出标注」新增「导出为 PDF」选项
- [ ] 导出的 PDF 包含原始 PDF 的所有页面
- [ ] 高亮标注以对应颜色半透明背景呈现
- [ ] 下划线/删除线以对应颜色线条呈现
- [ ] 文字注释以便签样式呈现在对应位置
- [ ] 导出进度显示（适用于大型文档）

**Labels**: good first issue

---

## Issue 3: 键盘快捷键自定义

**标题**: [good first issue] 键盘快捷键自定义

**描述**:

**Problem（问题）**:
当前应用的键盘快捷键是固定不变的，用户无法根据自己的习惯自定义快捷键。对于从其他 PDF 阅读器迁移过来的用户，可能希望使用熟悉的快捷键配置。

**Solution（解决方案）**:
在应用设置中添加键盘快捷键自定义功能，允许用户查看、修改快捷键配置，并支持重置为默认设置。

**Acceptance Criteria（验收标准）**:
- [ ] 设置页面显示所有可自定义的快捷键列表
- [ ] 用户点击快捷键后可录制新按键组合
- [ ] 同一快捷键被多个功能使用时显示冲突警告
- [ ] 支持将快捷键配置重置为默认值
- [ ] 自定义快捷键配置在应用重启后保持生效

**Labels**: good first issue

---

## Issue 4: i18n 本地化（中文/英文）

**标题**: [good first issue] i18n 本地化（中文/英文）

**描述**:

**Problem（问题）**:
当前应用界面仅包含英文文本。对于中文用户群体，缺乏本地化支持会影响使用体验和应用的可访问性。

**Solution（解决方案）**:
引入国际化（i18n）框架，实现中英文双语支持。界面文本应根据系统语言设置自动切换，用户也可在设置中手动选择语言。

**Acceptance Criteria（验收标准）**:
- [ ] 应用支持简体中文和英文两种语言
- [ ] 界面文本根据系统语言自动切换（系统为中文时显示中文，为英文时显示英文）
- [ ] 设置页面提供语言手动选择功能（覆盖系统设置）
- [ ] 所有 UI 文本（菜单、按钮、提示信息等）均已翻译
- [ ] 语言切换后界面立即响应，无需重启应用

**Labels**: good first issue

---

## 手动创建指南

使用以下命令在 GitHub 上创建这些 issues：

```bash
# Issue 1: 深色模式
gh issue create --title "[good first issue] 添加深色模式支持" --body "$(cat <<'EOF'
**Problem**: 当前应用仅支持浅色模式，与系统深色模式不一致

**Solution**: 实现自动跟随系统主题的深色/浅色模式切换

**Acceptance Criteria**:
- [ ] 浅色模式下显示浅色主题
- [ ] 深色模式下显示深色主题
- [ ] 系统主题切换时自动响应
- [ ] 所有 UI 组件正确响应主题切换
- [ ] 标注颜色在不同主题下保持可读性

Labels: good first issue
EOF
)"

# Issue 2: 导出标注为 PDF
gh issue create --title "[good first issue] 导出标注为 PDF" --body "$(cat <<'EOF'
**Problem**: 当前仅支持导出为纯文本，无法保留标注视觉样式

**Solution**: 扩展导出功能，支持将标注以 PDF 格式导出

**Acceptance Criteria**:
- [ ] 新增「导出为 PDF」选项
- [ ] 导出 PDF 包含原始页面
- [ ] 高亮以颜色背景呈现
- [ ] 下划线/删除线以颜色线条呈现
- [ ] 文字注释以便签样式呈现

Labels: good first issue
EOF
)"

# Issue 3: 键盘快捷键自定义
gh issue create --title "[good first issue] 键盘快捷键自定义" --body "$(cat <<'EOF'
**Problem**: 快捷键固定，无法自定义

**Solution**: 添加键盘快捷键自定义功能

**Acceptance Criteria**:
- [ ] 显示可自定义快捷键列表
- [ ] 支持录制新按键组合
- [ ] 快捷键冲突检测
- [ ] 支持重置为默认值
- [ ] 配置持久化

Labels: good first issue
EOF
)"

# Issue 4: i18n 本地化
gh issue create --title "[good first issue] i18n 本地化（中文/英文）" --body "$(cat <<'EOF'
**Problem**: 界面仅英文，缺少中文本地化

**Solution**: 引入 i18n 框架，实现中英文双语支持

**Acceptance Criteria**:
- [ ] 支持简体中文和英文
- [ ] 自动跟随系统语言
- [ ] 手动语言选择功能
- [ ] 所有 UI 文本已翻译
- [ ] 语言切换立即生效

Labels: good first issue
EOF
)"
```
