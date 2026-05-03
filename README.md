# 智慧学习 - 全平台学习助手

一款功能全面的智慧学习应用，帮助用户高效管理知识、笔记和考试，提供智能化的学习体验。

## 功能列表

### 核心功能
- **知识库管理** - 分类管理各学科知识点，支持多级目录结构
- **智能笔记** - 支持富文本编辑、Markdown、图片插入、语音输入
- **OCR识别** - 拍照识别文字，快速录入笔记和题目
- **语音助手** - 语音输入笔记、语音朗读题目和知识点

### 学习工具
- **必记内容** - 收藏重要知识点，支持间隔重复复习
- **错题本** - 自动收录错题，支持分类筛选和重做
- **母题集** - 整理典型题目，举一反三
- **思维导图** - 可视化知识结构，支持拖拽编辑
- **考试中心** - 限时练习、随机练习、模拟考试等多种模式

### 数据分析
- **学习统计** - 学习时长、完成题目、正确率等多维度统计
- **科目分析** - 各科目掌握程度分析
- **趋势图表** - 学习进度趋势可视化
- **学习历史** - 完整的学习活动记录

### 其他功能
- **深色模式** - 支持亮色/暗色/跟随系统三种主题模式
- **数据备份** - 本地数据备份与恢复
- **PDF导出** - 笔记和知识导出为PDF
- **分享功能** - 分享笔记和知识给同学
- **响应式布局** - 适配手机和平板

## 技术栈

### 框架
- **Flutter 3.x** - 跨平台UI框架
- **Dart 3.x** - 开发语言

### 状态管理
- **Provider** - 轻量级状态管理方案

### 本地存储
- **sqflite** - SQLite本地数据库
- **shared_preferences** - 键值对偏好设置存储
- **path_provider** - 文件路径管理

### 多媒体
- **camera** - 相机调用
- **image_picker** - 图片选择
- **speech_to_text** - 语音识别
- **flutter_tts** - 文字转语音

### AI/ML
- **google_ml_kit** - OCR文字识别

### 文档与渲染
- **flutter_markdown** - Markdown渲染
- **flutter_html** - HTML渲染
- **pdf** - PDF生成
- **printing** - 打印功能

### 数据可视化
- **fl_chart** - 轻量级图表库
- **syncfusion_flutter_charts** - 专业级图表库
- **graphview** - 图/思维导图可视化

### 工具库
- **intl** - 国际化与日期格式化
- **uuid** - 唯一标识符生成
- **http** - 网络请求
- **file_picker** - 文件选择
- **share_plus** - 系统分享
- **photo_view** - 图片查看

## 项目结构

```
lib/
  main.dart                 # 应用入口
  app.dart                  # 主应用Widget（隐藏式导航栏）
  models/                   # 数据模型层
  services/                 # 服务层（数据库、网络等）
  providers/                # 状态管理（Provider）
    theme_provider.dart     # 主题状态管理
    navigation_provider.dart # 导航状态管理
  screens/                  # 页面层
    home/                   # 首页
    knowledge/              # 知识库
    notes/                  # 笔记
    must_remember/          # 必记内容
    wrong_questions/        # 错题本
    mother_questions/       # 母题集
    exam/                   # 考试中心
    history/                # 学习历史
    mind_map/               # 思维导图
    analysis/               # 学习分析
    web_knowledge/          # 网络知识
    search/                 # 搜索
    profile/                # 个人中心
    settings/               # 设置
  widgets/                  # 自定义组件
  utils/                    # 工具类
```

## 快速开始

### 环境要求
- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Android Studio / VS Code

### 安装步骤

1. 克隆项目
```bash
git clone <repository-url>
cd smart_learning_app
```

2. 安装依赖
```bash
flutter pub get
```

3. 运行项目
```bash
flutter run
```

## 版本信息

- **版本号**: 1.0.0+1
- **最低支持**: Android 5.0+ / iOS 12.0+
- **目标平台**: Android, iOS, Web, macOS, Windows, Linux

## 许可证

MIT License
