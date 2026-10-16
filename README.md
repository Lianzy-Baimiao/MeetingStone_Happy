# MeetingStone_Happy · 集合石开心快乐版

面向魔兽世界正式服的组队工具，提供队伍查找、申请管理、条件筛选及界面优化。**推荐使用新 UI 版。**

> 当前为 `classic` 分支（经典 UI 版源码）。推荐的新 UI 版源码在 `master` 分支；两版发布包都在 Releases 中。

[版本选择](#版本选择) · [下载与安装](#下载与安装) · [功能介绍](#功能介绍) · [美化插件](#美化插件) · [常见问题](#常见问题) · [界面预览](#界面预览) · [更新日志](UpdateLog.md)

## 版本选择

**推荐使用新 UI 版。** 两个版本的组队功能基本相同，区别在界面风格和大秘境筛选方式：

| | 新 UI 版（推荐） | 经典 UI 版 |
| --- | --- | --- |
| 界面风格 | 沿用 11.0 以后暴雪原生过滤器的风格 | 保留 11.0 以前的风格 |
| 大秘境筛选 | 暴雪原生高级筛选，条件随搜索一起提交 | 集合石自带的搜索面板 |
| 源码分支 | `master`（主分支） | `classic` |

两个版本的 `MeetingStone` 与 `MeetingStoneEX` 不能混用。这里的“经典 UI”指界面样式，不代表魔兽世界怀旧服版本。

## 下载与安装

- **发布包**：[GitHub Releases](https://github.com/Lianzy-Baimiao/MeetingStone_Happy/releases) · [Gitee 发行版](https://gitee.com/xmmmmm/meeting-stone_-happy/releases)。分新 UI 版、经典 UI 版两个压缩包，**推荐下载新 UI 版**。
- **蓝奏云**：[下载页](https://wwi.lanzout.com/b04jz05cb)，密码：`gaxi`。
- **交流群**：[集合石插件_开心快乐](https://jq.qq.com/?_wv=1027&k=R04aQLlV)，QQ群号：`723978808`。

1. 完全退出游戏。若已安装其他版本，请先备份并移除旧的 `MeetingStone`、`MeetingStoneEX` 文件夹，不要混合覆盖不同版本。
2. 解压所选版本，将 `MeetingStone` 与 `MeetingStoneEX` 文件夹放入正式服的 `Interface/AddOns/` 目录。
3. 确认目录结构如下，然后启动游戏并启用插件。不要删除 `WTF` 目录或已有角色配置。更新插件后同样要完全退出再启动游戏，只 `/reload` 时新增的文件不会加载。

```text
World of Warcraft/
  _retail_/
    Interface/
      AddOns/
        MeetingStone/
          MeetingStone.toc
        MeetingStoneEX/
          MeetingStoneEX.toc
```

![安装目录示例](Image/%E6%96%87%E4%BB%B6%E8%B7%AF%E5%BE%84.png)

## 功能介绍

- 1～2 倍 UI 缩放，以及设置页面和其他界面优化。
- 屏蔽队长、举报队伍。
- 双击进组、自动进组和自动邀请。
- 地下城自动申请：按当前专精的职责逐个申请，可设置申请备注和最长等待时间。
- 申请列表、队伍列表的显示优化。
- 创建队伍时设置最低申请分数。
- 跨阵营组队、职业图标、队伍专精和申请人职业信息显示。
- 用于快速筛选和创建队伍的大秘境信息。

具体可用功能以所选版本及游戏接口限制为准。

## 美化插件

使用 [EllesmereUI](https://www.curseforge.com/wow/addons/ellesmereui)（EUI）的玩家，可以搭配 **MeetingStoneEllesmereUI**（可选）：它为集合石开心快乐版提供 EUI 风格的精细皮肤和操作优化，新 UI 版、经典 UI 版都支持，不修改集合石本身的文件。

- 深色面板、直角按钮、统一字体，首页、管理活动、最近玩友和设置页风格一致。
- 普通过滤与高级过滤合并为一个「筛选」窗口；新 UI 版首页底部提供职责快捷筛选。
- 「界面美化」页可调整窗口、字体、列表和选中配色。
- 1.4.21 起：美化自动申请按钮和备注弹窗；可选屏蔽说明栏带语音图标的队伍（默认关闭）。

下载：[CurseForge](https://www.curseforge.com/wow/addons/meetingstoneellesmereui) · 源码与截图：[GitHub](https://github.com/Lianzy-Baimiao/MeetingStoneEllesmereUI)

> 美化插件依赖 EllesmereUI；不安装它，集合石照常使用。

## 常见问题

### 不显示地下城搜索面板或地下城清单

打开“活动类型”下拉框，选择大秘境。

### 隐藏悬浮窗后无法打开插件

在聊天框输入 `/ms` 或 `/meetingstone` 打开。

### 打开后显示几秒「搜寻中」

窗口打开时才会发出搜索，这几秒主要是暴雪服务器返回结果的时间；重载后刚登录时还要先等游戏发来活动列表。输入 `/ms diag` 可查看每一段各用了多久。

### 内存占用时高时低

大部分是搜索、刷新列表时生成后丢弃的临时数据，游戏会自动回收。输入 `/ms mem` 可查看常驻与可回收的部分以及存档大小；若提示存档中有本插件不读取的旧数据（多为其他集合石版本留下），可输入 `/ms clean` 确认后删除。

### 等级或分数显示不完整

检查 ElvUI 等插件的整体缩放比例；若字体过大，调整字体或字号。

### 更习惯旧版筛选界面

可以改用经典 UI 版发布包，但仍推荐新 UI 版。两版文件不要混用。

## 界面预览

截图仅展示界面示例，具体布局以所安装的版本为准。

### 首页

![首页](Image/%E9%A6%96%E9%A1%B5.jpg)

### 申请列表

![申请列表](Image/%E7%94%B3%E8%AF%B7%E5%88%97%E8%A1%A8.jpg)

### 设置

![设置](Image/%E8%AE%BE%E7%BD%AE.jpg)

### 筛选

![筛选功能使用](Image/%E7%AD%9B%E9%80%89%E5%8A%9F%E8%83%BD%E4%BD%BF%E7%94%A8.png)

## 项目说明

开心和快乐是最重要的，让每次组队都成为一段充满欢笑的美好回忆！每一把都当作最后一把，也不要怕输。

开心快乐版集合石在本仓库及交流群内发布。

> 原作者声明：请以收费订阅为目的的插件整合包作者及为插件收费站台者，不要使用此修改版插件。

更新历史请查看仓库内的 [UpdateLog.md](UpdateLog.md)。

本项目采用 [MIT 许可证](LICENSE)；`MeetingStone/Libs/` 下的第三方库保留各自的许可与署名。
