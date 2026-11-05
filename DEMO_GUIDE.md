# beebrew Demo 使用指南

## 🎉 项目概述

beebrew 是一个为普通macOS用户设计的Homebrew图形化客户端，提供了友好、直观的包管理体验。这个demo版本展示了核心功能，包括包搜索、安装、卸载、多语言支持和现代化界面设计。

## 📦 已完成功能

### 核心功能
- ✅ **包搜索与浏览** - 实时搜索Homebrew包
- ✅ **包安装/卸载** - 一键安装和卸载包
- ✅ **已安装包管理** - 查看和管理已安装包
- ✅ **包更新检查** - 检查可更新的包
- ✅ **系统状态查看** - 显示Homebrew信息

### 用户体验
- ✅ **现代化界面** - 采用SwiftUI构建的现代化设计
- ✅ **多语言支持** - 中文/英文界面切换
- ✅ **主题系统** - 深色/浅色主题支持
- ✅ **响应式设计** - 适配不同窗口大小
- ✅ **流畅动画** - 平滑的过渡和加载动画

### 技术架构
- ✅ **MVVM架构** - 清晰的代码分离
- ✅ **模块化设计** - 易于扩展和维护
- ✅ **命令行集成** - 通过Process API调用Homebrew
- ✅ **本地化系统** - 完整的国际化支持
- ✅ **设置管理** - 用户偏好持久化

## 🚀 快速开始

### 环境要求
- macOS 12.0+
- Xcode 14.0+ (或Swift 5.9+)
- Homebrew (可选，可在应用内安装)

### 运行方式

#### 方式1: 使用启动脚本 (推荐)
```bash
# 调试模式运行
./run.sh

# 发布模式运行
./run.sh release

# 清理构建
./run.sh clean

# 运行测试
./run.sh test
```

#### 方式2: 直接使用Swift命令
```bash
# 构建项目
swift build

# 运行应用
swift run beebrew

# 清理构建
swift package clean
```

#### 方式3: 使用Xcode
```bash
# 生成Xcode项目
swift package generate-xcodeproj

# 打开Xcode
open beebrew.xcodeproj
```

## 📁 项目结构

```
beebrew/
├── App/                    # 应用入口
│   └── beebrewApp.swift   # 主应用文件
├── Models/                # 数据模型
│   └── BrewPackage.swift  # 包数据模型
├── ViewModels/            # 视图模型
│   ├── PackageViewModel.swift     # 包管理逻辑
│   └── SettingsViewModel.swift    # 设置管理逻辑
├── Views/                 # 视图组件
│   ├── Content/          # 主界面
│   ├── Packages/         # 包相关视图
│   └── Settings/         # 设置视图
├── Services/             # 服务层
│   └── BrewService.swift # Homebrew服务
├── Utils/                # 工具类
│   ├── Colors.swift      # 颜色系统
│   ├── CommandExecutor.swift # 命令行工具
│   ├── Icons.swift       # 图标系统
│   ├── Localization.swift # 本地化管理
│   ├── ThemeManager.swift # 主题管理
│   └── Typography.swift  # 字体系统
├── Resources/            # 资源文件
│   └── Localization/     # 本地化文件
└── Preview Content/      # SwiftUI预览资源
```

## 🎨 设计特色

### 色彩系统
- **主色调**: 科技蓝 (#0A84FF)
- **背景色**: 深色主题为主
- **功能色**: 成功(绿)、警告(橙)、错误(红)
- **渐变效果**: 微妙的渐变和阴影

### 界面布局
- **侧边栏导航**: 清晰的模块划分
- **卡片式设计**: 现代化信息展示
- **响应式布局**: 适配不同屏幕尺寸
- **交互动画**: 平滑的状态转换

### 交互设计
- **实时搜索**: 输入时实时过滤
- **批量操作**: 支持多选操作
- **状态反馈**: 清晰的加载和完成提示
- **错误处理**: 友好的错误信息

## 🌐 多语言支持

### 支持的语言
- **英语** (en) - 默认语言
- **简体中文** (zh-Hans) - 完整翻译

### 切换方式
1. 点击右上角设置图标 ⚙️
2. 选择"设置" → "通用"
3. 在"应用语言"中选择偏好语言
4. 应用将立即切换语言

### 本地化特性
- ✅ 完整界面文本翻译
- ✅ 动态语言切换
- ✅ 系统语言跟随
- ✅ RTL语言支持就绪

## ⚙️ 技术实现

### Homebrew集成
```swift
// 使用Process API调用Homebrew命令
let process = Process()
process.executableURL = URL(fileURLWithPath: "/bin/bash")
process.arguments = ["-c", "brew search \(query)"]
```

### 异步处理
```swift
// 使用async/await处理耗时操作
func searchPackages(query: String) async -> [BrewPackage] {
    let result = await commandExecutor.executeBrewCommandAsync("search", arguments: [query])
    // 解析和处理结果
}
```

### 状态管理
```swift
// 使用Combine发布状态变化
@Published var packages: [BrewPackage] = []
@Published var isLoading: Bool = false
@Published var errorMessage: String?
```

## 🔧 设置选项

### 外观设置
- **主题**: 深色/浅色/自动
- **强调色**: 自定义主色调
- **字体大小**: 可调整的文本大小

### Homebrew设置
- **路径设置**: 自定义Homebrew安装路径
- **连接测试**: 验证Homebrew可用性
- **自动检测**: 自动发现Homebrew

### 更新设置
- **自动检查**: 定期检查更新
- **检查频率**: 每小时/每天/每周
- **通知设置**: 更新提示开关

### 缓存管理
- **缓存大小**: 显示当前缓存使用
- **自动清理**: 设置缓存上限
- **手动清理**: 立即清理缓存

## 🧪 测试数据

### 示例包
应用包含以下示例包用于演示：

1. **python** - Python编程语言 (已安装)
2. **node** - Node.js JavaScript运行时 (可更新)
3. **visual-studio-code** - 微软代码编辑器 (未安装)
4. **git** - 分布式版本控制系统 (已安装)
5. **docker** - 容器化平台 (未安装)
6. **google-chrome** - 谷歌浏览器 (已安装)

### 演示操作
1. **搜索包**: 在搜索框中输入"python"
2. **安装包**: 点击"安装"按钮安装visual-studio-code
3. **卸载包**: 点击"卸载"按钮卸载python
4. **更新包**: 点击"更新"按钮更新node
5. **查看详情**: 点击包卡片查看详细信息

## 🐛 已知限制

### Demo版本限制
- ⚠️ **模拟数据**: 部分功能使用示例数据
- ⚠️ **实际Homebrew调用**: 需要真实Homebrew环境
- ⚠️ **包详情信息**: 部分信息为示例数据
- ⚠️ **安装过程**: 模拟安装过程，非真实安装

### 环境要求
- ⚠️ **macOS限制**: 仅支持macOS系统
- ⚠️ **权限需求**: 需要终端权限执行命令
- ⚠️ **网络连接**: 部分功能需要网络连接

## 🔮 未来扩展

### 计划功能
- 📅 **批量操作**: 批量安装/卸载/更新
- 📅 **包分类**: 按类别浏览包
- 📅 **高级搜索**: 更强大的搜索过滤器
- 📅 **自动化**: 定时任务和脚本
- 📅 **插件系统**: 扩展功能支持
- 📅 **云同步**: 设置和偏好同步

### 技术改进
- 📅 **性能优化**: 更高效的包列表加载
- 📅 **错误恢复**: 更好的网络错误处理
- 📅 **离线模式**: 本地缓存和离线使用
- 📅 **可访问性**: 更好的辅助功能支持

## 🤝 贡献指南

### 开发流程
1. Fork项目仓库
2. 创建功能分支
3. 提交更改
4. 创建Pull Request

### 代码规范
- 使用SwiftFormat保持代码风格一致
- 遵循MVVM架构模式
- 添加必要的注释和文档
- 编写单元测试

### 问题反馈
- 使用GitHub Issues报告问题
- 提供详细的重现步骤
- 包括系统环境和版本信息

## 📄 许可证

本项目基于MIT许可证开源。详情请查看LICENSE文件。

## 🙏 致谢

感谢以下开源项目的启发和帮助：
- [Homebrew](https://brew.sh/) - macOS包管理器
- [SwiftUI](https://developer.apple.com/xcode/swiftui/) - 声明式UI框架
- [Combine](https://developer.apple.com/documentation/combine) - 响应式编程框架

---

**beebrew - 让Homebrew管理变得简单愉快！** 🐝