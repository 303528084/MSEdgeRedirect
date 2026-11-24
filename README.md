# MSEdgeRedirect 简体中文版

> 本仓库是 [MSEdgeRedirect](https://github.com/rcmaehl/MSEdgeRedirect) 的**非官方简体中文分支**：只汉化界面，功能逻辑与上游完全一致。构建产物基于上游正式 release 版本，**不含上游未发布的代码**。

把 Windows 里那些"只能交给 Edge"的入口——任务栏搜索、新闻与兴趣、小组件、天气、开始菜单推荐——重新交回你的默认浏览器。

## 下载

到 [Releases](https://github.com/303528084/MSEdgeRedirect/releases) 取 `zh-<上游版本>` 的包：

| 发布标签 | 对应上游版本 | 说明 |
|---|---|---|
| `zh-0.8.0.0` | 0.8.0.0 | 当前中文版 |

- `MSEdgeRedirect.exe` —— 64 位 Windows
- `MSEdgeRedirect_x86.exe` —— 32 位系统
- `checksums.sha256` —— 校验和，可用 `certutil -hashfile MSEdgeRedirect.exe SHA256` 核对
- `0804.lang` —— 语言包本体，一般无需单独下载（已嵌入 exe）
- `MSEdgeRedirect_zh-CN.zip` —— 上述文件的打包版

exe 的文件版本号与上游保持一致，中文版只体现在发布标签和标题上。

## 使用前提

1. 系统里已安装另一个浏览器，并把它设为**默认浏览器**。Edge 自己就是默认浏览器时重定向没有意义，程序会提示后直接退出。
2. 仅支持 Windows 8 / 8.1 / 10 / 11。

## 安装

下载后直接运行，向导里选一个模式：

- **主动模式（推荐）**：替代 Edge 启动，不常驻后台，性能最好，可自定义
- **服务模式**：无需管理员权限，单用户安装，后台常驻，检测到 Edge 调用就重定向
- **欧洲模式**：用 Windows 原生功能把系统区域设为欧盟，需要重启，不安装程序

最后一页可勾选"立即启动服务模式""创建开始菜单快捷方式"。

便携使用：`MSEdgeRedirect.exe /portable`，配置写在程序目录而不是 `%LocalAppData%`。

## 命令行

参数名保持英文，汉化只改说明文字：

| 参数 | 作用 |
|---|---|
| `/change` | 重新运行安装向导、修改设置 |
| `/settings` | 直接打开设置窗口 |
| `/portable` | 便携模式 |
| `/hide` | 隐藏托盘图标 |
| `/si` | 静默安装 |
| `/repair` | 修复 IFEO 目录联接 |
| `/admin` | 以管理员权限运行 |
| `/force` | 跳过安全检查 |
| `/kill` | 结束其它 MSEdgeRedirect 进程 |

完整列表见 `MSEdgeRedirect.exe /?`。

## 汉化范围

已汉化：安装向导各页、托盘菜单、设置窗口、全部提示弹窗、`/help` 说明。

刻意保留英文（改了会坏功能或没意义）：日志文本、命令行参数名、下拉框的实际值（`Default` / `Custom` / `Google` 等）、Edge 频道名、`IFEO`。日志保持英文是为了能和上游 issue 对齐。

## 跟上上游

仓库结构：`main` 只用于跟随上游，不做任何改动；汉化全部在 `zh-CN` 分支。

上游每发一次正式版，本仓库会在 24 小时内跟进同名的 `zh-<版本>` 发布：

1. 把本地化改动 rebase 到上游那个 **release tag**（不是 main，避免把上游未发布的提交带进来）
2. 用 AutoIt3Wrapper 重新编译 x64 / x86
3. 跑 `Tools\check-lang.ps1` 检查语言包一致性
4. 发布，校验和一并附上

上游新增文案时，那几句可能短暂显示英文；补齐语言包后重新发版即可，不影响使用。

## 自己构建

需要 AutoIt3 3.3.18 与 SciTE4AutoIt3（含 AutoIt3Wrapper、Au3Stripper）：

```powershell
& "C:\Program Files (x86)\AutoIt3\AutoIt3.exe" `
  "C:\Program Files (x86)\AutoIt3\SciTE\AutoIt3Wrapper\AutoIt3Wrapper.au3" `
  /NoStatus /prod /in MSEdgeRedirect.au3
```

- 源码 `.au3` 必须是 **UTF-8 with BOM**，语言包 `Assets\Langs\0804.lang` 必须是 **UTF-16 LE with BOM**。编码错了会表现为整界面乱码或干脆全英文。
- 语言包一致性检查：`pwsh -NoProfile -File Tools\check-lang.ps1`，输出"缺失翻译""失效翻译"两份清单。
- 改了界面文案或上游新增字符串，记得在语言包补上对应 key。

## 语言包与翻译

译文全部集中在 `Assets\Langs\0804.lang`（INI 的 `[Strings]` 段，`key = 英文原文`，`value = 中文`）。修一句翻译不用碰任何代码，改完跑一次校验脚本即可。发现漏译、错译，欢迎直接向本仓库的 `zh-CN` 分支提 PR。

## 常见问题

**重定向没生效？** 先确认默认浏览器不是 Edge，再用 `/settings` 确认模式已正确安装。

**杀软报毒？** 程序会写入 IFEO 注册表项并改变 Edge 的启动路径，这类工具常被误报；可以只下载源码自行编译。

**装完 Edge 打不开？** 用 `/repair` 修复联接，或 `/change` 重装。

## 许可证与致谢

沿用上游 [LGPL-3.0](LICENSE)。原作者 [Robert Maehl](https://github.com/rcmaehl)，上游仓库见 https://github.com/rcmaehl/MSEdgeRedirect 。

本仓库只做界面本地化，不含任何上游未发布的代码。功能层面的问题请用英文反馈给上游；本分支维护者能力有限，不承诺修复功能缺陷。
