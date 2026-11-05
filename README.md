# beebrew 🐝

一个美观、易用的macOS Homebrew包管理客户端，为普通用户提供图形化界面管理Homebrew包。

## 功能特性

- 🎯 **直观的界面** - 现代化设计，亲和易用
- 🔍 **包搜索与浏览** - 轻松查找Homebrew包
- 📦 **一键安装/卸载** - 简化包管理操作
- 🌐 **多语言支持** - 中文/英文界面
- 🎨 **科技感设计** - 现代化UI，流畅动画
- 📊 **系统状态查看** - 实时监控Homebrew状态

## 技术栈

- **语言**: Swift
- **UI框架**: SwiftUI
- **架构**: MVVM
- **平台**: macOS 12+

## 项目结构

```
beebrew/
├── App/                    # 应用入口
├── Models/                 # 数据模型
├── ViewModels/             # 视图模型
├── Views/                  # 视图组件
├── Services/               # 服务层
├── Utils/                  # 工具类
└── Resources/              # 资源文件
```

## 快速开始

### 环境要求

- macOS 12+
- Xcode 14+
- Homebrew (自动检测)

### 构建与运行

```bash
# 克隆项目
git clone <repository-url>
cd beebrew

# 构建项目
swift build

# 运行应用
swift run beebrew
```

或者使用Xcode打开项目：

```bash
open Package.swift
```

## 开发计划

### MVP版本 (v1.0)
- [x] 项目基础结构
- [ ] 包数据模型
- [ ] Homebrew服务层
- [ ] 主界面框架
- [ ] 包搜索功能
- [ ] 包安装/卸载
- [ ] 多语言支持

### 未来版本
- 批量操作
- 包更新管理
- 分类浏览
- 深色/浅色主题
- 高级搜索筛选

## 设计理念

beebrew旨在为普通macOS用户提供友好的Homebrew管理体验，将复杂的命令行操作转化为直观的图形界面操作。采用现代化设计语言，平衡科技感与亲和力，让包管理变得简单而愉悦。

## 贡献

欢迎提交Issue和Pull Request！

## 许可证

MIT License