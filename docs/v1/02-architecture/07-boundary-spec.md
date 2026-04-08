# 边界条件规约文档

## 文档信息

- **项目名称**: PDF-Ve
- **版本**: v1.0
- **对应PRD**: docs/v1/01-prd.md
- **更新日期**: 2026-04-01

---

## 边界条件清单

| 编号 | 边界条件名称 | 类型 | 对应PRD | 对应接口 |
|-----|------------|------|---------|---------|
| BOUND-001 | 文件打开边界 | 输入验证 | AC-001-04, AC-001-05 | API-001 |
| BOUND-002 | 最近文件数量边界 | 业务规则 | Rule-004, AC-015-01 | API-003 |
| BOUND-003 | 最近文件路径失效边界 | 业务规则 | Rule-003, AC-015-05 | API-004 |
| BOUND-010 | 页码跳转边界 | 输入验证 | AC-002-04 | API-010 |
| BOUND-011 | 缩放范围边界 | 输入验证 | AC-003-06 | API-011 |
| BOUND-020 | 文本标注选区边界 | 输入验证 | AC-006 异常 | API-040 |
| BOUND-021 | 便签注释位置边界 | 数据约束 | AC-009-04 | API-041, API-042 |
| BOUND-022 | 自由绘制边界 | 输入验证 | AC-010-04, AC-010-06 | API-044, API-045 |
| BOUND-030 | 持久化写入边界 | 系统边界 | 性能需求 3.1 | API-050 |
| BOUND-031 | 标注导出边界 | 业务规则 | AC-016-04 异常 | API-053 |
| BOUND-040 | 标注列表空状态边界 | 展示边界 | AC-011 异常 | API-060 |
| BOUND-041 | 书签重复边界 | 业务规则 | AC-012-01 | API-063 |
| BOUND-042 | 缩略图按需加载边界 | 性能边界 | AC-013-05 | API-067 |
| BOUND-050 | 搜索关键词边界 | 输入验证 | AC-005 输入边界 | API-030 |
| BOUND-051 | 无可搜索文本边界 | 系统边界 | AC-005 异常 | API-030 |

---

## 边界条件详细定义

### BOUND-001: 文件打开边界

**对应PRD**: AC-001-04, AC-001-05
**所属接口**: API-001 `openDocument(at:)`

**输入边界**：

| 参数 | 类型 | 约束 | 来源 |
|-----|------|------|------|
| url | URL | 非空，路径存在，扩展名为.pdf | 用户选择 |

**验证规则**：

```swift
// 1. 扩展名检查
guard url.pathExtension.lowercased() == "pdf" else {
    throw FileError.invalidPDF
}

// 2. 文件存在检查
guard FileManager.default.fileExists(atPath: url.path) else {
    throw FileError.notFound
}

// 3. PDF 有效性检查（通过 PDFDocument 初始化）
guard PDFDocument(url: url) != nil else {
    throw FileError.invalidPDF
}
```

**错误处理**：

| 错误码 | 场景 | 用户提示 |
|-------|------|---------|
| `FileError.notFound` | 文件路径不存在 | 「无法打开文件：文件不存在」（AC-001-05） |
| `FileError.invalidPDF` | 非 PDF 或损坏 | 「无法打开文件：这不是有效的 PDF 文档」（AC-001-05） |

---

### BOUND-002: 最近文件数量边界

**对应PRD**: Rule-004, AC-015-01
**所属接口**: API-003 `recentDocuments()`，触发于 `DocumentRepository.recordOpen()`

**业务边界**：

| 条件 | 处理方式 |
|-----|---------|
| 记录数量 <= 20 | 正常插入 |
| 记录数量 > 20（插入新记录后） | 删除 `lastOpenedAt` 最小的记录，保持总数 = 20 |
| 同一文件重复打开 | 更新已有记录的 `lastOpenedAt`，不新增，不触发数量限制 |

```swift
// DocumentRepository.recordOpen()
func recordOpen(url: URL, pageCount: Int) {
    if let existing = fetchRecord(for: url.path) {
        existing.lastOpenedAt = Date()
        existing.pageCount = pageCount
    } else {
        let record = DocumentRecord(filePath: url.path, fileName: url.lastPathComponent, pageCount: pageCount)
        modelContext.insert(record)
        // 检查数量限制
        let all = fetchAllSorted()
        if all.count > 20 {
            modelContext.delete(all.last!)  // 删除最旧的
        }
    }
    try? modelContext.save()
}
```

---

### BOUND-003: 最近文件路径失效边界

**对应PRD**: Rule-003, AC-015-05
**所属接口**: API-004 `openRecentDocument(_:)`

**业务边界**：

| 条件 | 处理方式 |
|-----|---------|
| 文件路径存在 | 正常打开（走 API-001 逻辑） |
| 文件路径不存在（文件被删除/移动） | 从最近文件列表删除该记录 → 抛 `FileError.notFoundRemoved` |

**用户提示**：「文件"XXX"已不存在或已被移动，已从最近文件列表中移除」（AC-015-05）

---

### BOUND-010: 页码跳转边界

**对应PRD**: AC-002-04
**所属接口**: API-010 `goToPage(_:)`

| 输入 | 处理方式 |
|-----|---------|
| `pageNumber < 1` | 跳转到第 1 页（clamp） |
| `pageNumber > totalPages` | 跳转到最后一页（clamp） |
| 非数字输入（工具栏页码输入框） | 忽略，恢复显示当前页码数字 |
| 空字符串输入 | 忽略，恢复显示当前页码 |

---

### BOUND-011: 缩放范围边界

**对应PRD**: AC-003-06
**所属接口**: API-011

| 输入 | 处理方式 |
|-----|---------|
| `setZoom(level)` 其中 `level < 0.1` | 设置为 0.1（clamp），不抛错 |
| `setZoom(level)` 其中 `level > 5.0` | 设置为 5.0（clamp），不抛错 |
| `zoomIn()` 时已达 5.0 | 静默不操作，工具栏缩放+按钮变灰 |
| `zoomOut()` 时已达 0.1 | 静默不操作，工具栏缩放-按钮变灰 |
| 触控板捏合超出范围 | clamp 到边界值，手势继续响应但不再改变缩放 |

---

### BOUND-020: 文本标注选区边界

**对应PRD**: AC-006 异常，AC-007/008 异常
**所属接口**: API-040 `createTextAnnotation()`

| 条件 | 处理方式 |
|-----|---------|
| 选中区域为纯图片（无文本） | `PDFSelection.string == nil`，工具栏标注按钮保持禁用，不调用 API-040 |
| 选中区域为扫描件（图像 PDF） | 同上 |
| 选中文本跨越多页 | 仅处理第一页的选区，创建单条标注记录 |
| `selectedText` 超过 10000 字符 | 截断保存前 10000 字符，标注仍然创建 |

---

### BOUND-021: 便签注释位置边界

**对应PRD**: AC-009-04（便签可拖动）
**所属接口**: API-041, API-042

| 条件 | 处理方式 |
|-----|---------|
| 便签拖动到页面边界外 | `bounds.origin` 限制在页面可视范围内（clamp to page bounds） |
| 便签创建位置与已有便签重叠 | 创建新便签（允许重叠），每个便签独立 |
| `content` 为空字符串 | 允许保存空内容便签 |

---

### BOUND-022: 自由绘制边界

**对应PRD**: AC-010-04, AC-010-06
**所属接口**: API-044, API-045

| 条件 | 处理方式 |
|-----|---------|
| 路径点数量 < 2 | 不创建绘制记录（不构成可见线条） |
| Cmd+Z 无 drawing 类型标注 | 静默无操作 |
| 橡皮擦点击空白区域（非绘制内容） | 静默无操作 |
| 橡皮擦命中多个重叠绘制标注 | 删除 z-order 最上层（createdAt 最新）的标注 |

---

### BOUND-030: 持久化写入边界

**对应PRD**: 性能需求 3.1（< 100ms），Rule-001
**所属接口**: API-050 `AnnotationRepository.save()`

| 条件 | 处理方式 |
|-----|---------|
| SwiftData `save()` 失败（磁盘满） | 捕获错误，通过 AnnotationViewModel 发布错误状态，UI 层显示 Toast 提示 |
| 并发写入（用户快速操作） | SwiftData MainActor 序列化保证，不存在并发问题（单用户应用） |
| 数据库文件不存在 | PersistenceController 初始化时自动创建，运行时不会出现此情况 |
| 写入超过 100ms | 日志记录，但不阻塞 UI（SwiftData 使用同步 save，应用场景数据量小，100ms 完全可达） |

---

### BOUND-031: 标注导出边界

**对应PRD**: AC-016-04 异常
**所属接口**: API-053 `exportAnnotationsAsText()`

| 条件 | 处理方式 |
|-----|---------|
| 当前文档无标注 | 返回空字符串，调用方（AnnotationViewModel）检测并弹出提示「当前文档无标注内容」（AC-016-04） |
| 保存路径无写权限 | 抛 `ExportError.permissionDenied`，UI 层提示 |
| 保存路径磁盘空间不足 | 系统写入错误，捕获并提示 |

---

### BOUND-040: 标注列表空状态边界

**对应PRD**: AC-011 异常
**所属接口**: API-060 annotations

| 条件 | 处理方式 |
|-----|---------|
| 文档无任何标注 | AnnotationListView 显示空状态视图：图标 + 「暂无标注」文字 |
| 按类型筛选后无结果 | 显示「该类型暂无标注」 |

---

### BOUND-041: 书签重复边界

**对应PRD**: AC-012-01（Cmd+B 切换语义）
**所属接口**: API-063 `toggleBookmark()`

| 条件 | 处理方式 |
|-----|---------|
| 当前页已有书签 → Cmd+B | 删除已有书签（切换语义） |
| 当前页无书签 → Cmd+B | 创建新书签，默认名称「第X页」 |
| 重命名时输入空字符串或纯空格 | 忽略，保持原书签名不变 |
| 重命名时名称超过 50 字符 | 截断到 50 字符 |

---

### BOUND-042: 缩略图按需加载边界

**对应PRD**: AC-013-05
**所属接口**: API-067 `thumbnail(for:size:)`

| 条件 | 处理方式 |
|-----|---------|
| 缩略图在视口外 | LazyVGrid 不触发 `task {}` 加载，不调用 API-067 |
| 缩略图生成失败（页面损坏） | 显示灰色占位矩形 + 页码 |
| 文档 > 1000 页 | 全部通过 LazyVGrid 按需渲染，不预生成所有缩略图 |

---

### BOUND-050: 搜索关键词边界

**对应PRD**: AC-005 输入边界
**所属接口**: API-030

| 条件 | 处理方式 |
|-----|---------|
| 空字符串搜索 | 清空结果，不调用 PDFKit 搜索，回到 `empty` 状态 |
| 关键词长度 > 100 字符 | 截断到前 100 字符后执行搜索 |
| 特殊字符（正则符号等） | 作为字面量字符串处理（PDFKit findString 不使用正则） |

---

### BOUND-051: 无可搜索文本边界

**对应PRD**: AC-005 异常（PDF 无可搜索文本）
**所属接口**: API-030

| 条件 | 判断方式 | 处理方式 |
|-----|---------|---------|
| 扫描件 PDF（纯图片，无文本层） | `document.findString("a", withOptions: [])` 返回空数组，且 `document.string == nil` | SearchViewModel 设置 `isUnsearchable = true`，SearchBarView 显示「此文档不包含可搜索文本」 |
| 正常 PDF 但关键词不存在 | `findString` 返回空数组，`document.string != nil` | 正常显示「未找到」（noResults 状态） |
