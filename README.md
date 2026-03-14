# PowerShell 配置与脚本集合

[toc]

这是一个面向 Windows 11 + PowerShell 7 的个人终端配置仓库，包含两个 Profile 脚本以及若干高频命令增强与实用函数。主目标是提升交互效率、命令可读性和开发者日常操作体验。

## 目录结构

- `Microsoft.PowerShell_profile.ps1`：常规终端的主 Profile
- `Microsoft.VSCode_profile.ps1`：VS Code 集成终端的 Profile

## 快速使用

1. 将仓库放在用户 PowerShell 配置目录（通常为 `Documents\PowerShell`）。
2. 重新打开 PowerShell 或执行 `rlp` 重新加载配置。
3. 在 VS Code 集成终端中，`Microsoft.VSCode_profile.ps1` 会自动生效。

## 管理脚本

`manage.ps1` 用于安装、卸载、导出和配置 Profile 文件，支持按需指定目录并自动备份。

常用命令：

- `.\manage.ps1 install`：安装/更新两个 Profile，已有文件会备份
- `.\manage.ps1 uninstall`：卸载并尽量还原备份；若文件被修改则跳过（可加 `-Force` 强制）
- `.\manage.ps1 export`：导出当前 Profile 到 `ExportDir\yyyyMMdd-HHmmss`
- `.\manage.ps1 config show`：查看当前配置
- `.\manage.ps1 config set ProfileDir <dir>`：设置配置项（`ProfileDir` / `BackupDir` / `ExportDir`）
- `.\manage.ps1 config reset`：重置配置

配置与默认值：

- `ProfileDir` 默认指向当前用户 Profile 目录（`$PROFILE.CurrentUserAllHosts` 的父目录）
- `BackupDir` 默认在 `ProfileDir\.backup`
- `ExportDir` 默认在仓库根目录下的 `exports`
- 配置文件为 `profile-manager.json`，位于仓库根目录

示例：

```powershell
.\manage.ps1 install
.\manage.ps1 config set ProfileDir D:\Documents\PowerShell
.\manage.ps1 export
.\manage.ps1 uninstall -Force
```

## 功能概览

常用增强与函数概况（以 `Microsoft.PowerShell_profile.ps1` 为主）：

- 终端基础：UTF-8 输入输出、PSReadLine 预测与快捷键增强、posh-git 状态显示
- 列表与查看：`ls/ll/la/lt` 由 `eza` 增强，`cat` 自动切换为 `bat`，`tree` 兼容中文输出
- 智能导航：`z`（zoxide 目录跳转）、`f`（fzf 模糊查找并预览）
- 高效工具：
  - 端口占用查询：`ports 8080`
  - 提权执行：`sudo <command>`
  - 万能解压：`ex <file>`
  - 公网 IP：`myip`
  - 终端 AI 查询：`howto <query>`
  - 系统清理：`sys-clean`
  - 撤销上次提交：`gundo`
- 便捷别名与函数：`mkcd`、`ccpp`、`trash`、`Remove-EmptyFolders`、`touch`、`which`、`Format-FileSize`
- 自定义帮助面板：`help`（无参数时显示自定义手册）

## 依赖与可选工具

核心环境：

- PowerShell 7
- Windows 11

已在 Profile 中使用的模块：

- `posh-git`
- `DirColors`
- `PSReadLine`
- `PSWriteColor`
- `git-aliases`
- `Log`
- `Terminal-Icons`（主要在 VS Code Profile 中使用）

建议安装的外部工具（未安装时会自动降级或提示）：

- `eza`、`bat`、`fzf`、`zoxide`
- `oh-my-posh`（VS Code Profile 使用自定义主题）
- `scoop`（用于模块与工具管理）
- `fastfetch`
- `7z`、`curl.exe`、`tree`
- `git`、`python`（`rss` 依赖外部脚本与 Python 环境）

## 注意事项

- `gundo` 会执行 `git reset HEAD~1`，仅用于当前仓库且会影响提交历史。
- `sys-clean` 会清理系统缓存与回收站，执行前请确保无重要数据。
- `myip` 与 `howto` 依赖外网访问服务（`ipinfo.io` 与 `cht.sh`）。
- `rss` 默认指向 `D:\Documents\04_Scripts\Scripts\script_launcher`，路径需按实际环境调整。
- VS Code Profile 中的 oh-my-posh 主题路径为 `C:\Users\Administrator\.config\posh\powerlevel10k_modify.omp.json`，如未使用该路径请替换。
