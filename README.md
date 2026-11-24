# 3x-ui 中文安装脚本（最新版）

自动拉取官方 3x-ui 安装脚本，**只汉化交互提示、菜单和关键流程文案，核心逻辑一行不改**。
装完的面板是官方原版，内置简体中文，登录后把语言切成「简体中文」即可。

## 一键安装

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/18110512616/3x-ui-cn-latest/main/install-cn.sh)
```

## 其他用法

```bash
# 跟随官方最新版（master 分支脚本）
bash install-cn.sh -v latest

# 指定版本
bash install-cn.sh -v v3.11.0

# 只生成汉化后的脚本，不执行安装
CN_ONLY=1 bash install-cn.sh    # 输出 ./install-cn-localized.sh

# 非交互安装（云端/脚本化），透传官方环境变量
XUI_NONINTERACTIVE=1 XUI_PANEL_PORT=2053 XUI_DB_TYPE=sqlite bash install-cn.sh
```

## 工作原理

| 步骤 | 说明 |
|---|---|
| 1 | 按版本从 `raw.githubusercontent.com/mhsanaei/3x-ui/<版本>/install.sh` 下载官方脚本 |
| 2 | 用内置词表逐条做**精确字符串替换**（按长度降序，避免短句先命中把长句拆坏） |
| 3 | 替换完 `bash -n` 语法检查，不通过就退出，绝不在坏脚本上继续 |
| 4 | 通过才执行，实时打印替换命中数 |

- 汉化覆盖率：v3.11.0 的 `install.sh` 共命中 **232 条**，未命中 0 条
- 官方改版后如有新增英文提示，会出现在「未命中」清单里，不影响安装
- 依赖安装、下载、sha256 校验、systemd/OpenRC 服务写入等逻辑保持官方原样

## 环境要求

- Linux（Debian/Ubuntu/Armbian、RHEL/CentOS/Rocky/Alma、Fedora、Arch/Manjaro、openSUSE、Alpine）
- root 权限
- 服务器能访问 GitHub（汉化只改提示语，安装包、`x-ui.sh`、服务文件仍从官方仓库下载）

## 装完之后

- 面板本身支持简体中文：登录页右下角切换语言，或 面板设置 → 常规 → 语言 → 简体中文
- v3.11.0 起新库不再使用默认 `admin/admin`，首个面板账号密码是随机的，会打印在服务器日志里
- 命令行管理仍用 `x-ui`（该菜单为官方英文版，未汉化）

## 与 V2RaySSR 中文固定版的区别

| 项目 | 本仓库 | V2RaySSR/3x-ui-cn-installer |
|---|---|---|
| 面板版本 | 跟随官方最新稳定版（默认 v3.11.0） | 固定 2.9.3 |
| 汉化范围 | 交互提示 / 菜单 / 关键流程文案 | 交互提示（2.9.3 时期） |
| 面板界面中文 | 官方内置 zh-CN 语言包 | 官方内置 zh-CN 语言包 |
| 资源来源 | 官方 Release | 该仓库自己的 Release |

## 免责声明

仅供个人学习与通信使用，请遵守所在地区法律法规，勿用于非法用途。
