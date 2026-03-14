###########################################################################################
####                          PowerShell Profile 配置文件                               ####
####                          Owner: DantaKing                                          ####
###########################################################################################

# 记录配置文件加载开始时间，用于性能分析
$Global:ProfileStartTime = [datetime]::Now
# 关闭 PowerShell 版本更新提示
$env:POWERSHELL_UPDATECHECK = 'Off'

###########################################################################################
####                                 [全局个性化偏好设置]                               ####
###########################################################################################

# 1. eza 列表默认排序方式: "name"(名称), "size"(大小), "ext"(扩展名), "newest"(修改时间)
$Global:DefaultSortBy = "name" 
# 2. 是否默认将文件夹显示在文件前面 (推荐 $true)
$Global:GroupDirsFirst = $true

###########################################################################################
####                                   基础功能与环境                                   ####
###########################################################################################

# 强制终端输入输出编码为 UTF-8，防止中文乱码
[Console]::OutputEncoding =[System.Text.Encoding]::UTF8
[Console]::InputEncoding =[System.Text.Encoding]::UTF8

# 安全加载 Scoop 补全功能
$scoopCompletion = "$env:USERPROFILE\scoop\modules\scoop-completion"
if (Test-Path $scoopCompletion) { Import-Module $scoopCompletion -ErrorAction SilentlyContinue }

# Jabba Java环境管理自动加载 (动态路径)
$jabbaPath = "$env:USERPROFILE\.jabba\jabba.ps1"
if (Test-Path $jabbaPath) { . $jabbaPath }

###########################################################################################
####                                 智能导航 (Zoxide & Fzf)                            ####
###########################################################################################

# 1. 智能目录跳转 (Zoxide) -> 接管 cd，使用 z 跳转
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& {zoxide init powershell | Out-String})
}

# 2. 模糊查找文件 (Fzf) -> 输入 f 唤起交互式搜索
function f {
    if (Get-Command fzf -ErrorAction SilentlyContinue) {
        $selected = fzf --preview 'bat --color=always --style=numbers {}' --height 80%
        if ($selected) {
            Write-Host "✅ 已选中文件: " -NoNewline; Write-Host $selected -ForegroundColor Green
            # 自动将选中路径复制到剪贴板
            Set-Clipboard -Value $selected
        }
    } else { Write-Warning "请先安装 fzf: scoop install fzf" }
}

###########################################################################################
####                                   功能拓展 (模块)                                  ####
###########################################################################################

# 批量且安全地加载模块
$ModulesToLoad = @("posh-git", "DirColors", "PSReadLine", "PSWriteColor", "git-aliases", "Log")
foreach ($module in $ModulesToLoad) {
    Import-Module $module -ErrorAction SilentlyContinue -DisableNameChecking
}

# ==================== PSReadLine 设置 (自动补全与快捷键) ====================
if (Get-Module -Name PSReadLine) {
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin
    Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadlineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadlineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadlineKeyHandler -Key Ctrl+d -Function DeleteCharOrExit
}

###########################################################################################
####                              核心拦截与包装 (eza / bat / tree)                     ####
###########################################################################################

# [增强] bat 语法高亮接管原生的 cat
if (Get-Command bat -ErrorAction SilentlyContinue) {
    Remove-Item Alias:cat -Force -ErrorAction SilentlyContinue
    function cat { bat --paging=never @args }
}

# [增强] eza 增强列表体验，支持快捷排序
if (Get-Command eza -ErrorAction SilentlyContinue) {
    Remove-Item Alias:ls -Force -ErrorAction SilentlyContinue
    Remove-Item Alias:la -Force -ErrorAction SilentlyContinue
    Remove-Item Alias:ll -Force -ErrorAction SilentlyContinue

    function Invoke-EzaWrapper {
        param([string]$Type,[array]$InputArgs)
        $ezaArgs = @("--icons")
        if ($Global:GroupDirsFirst) { $ezaArgs += "--group-directories-first" }
        if (![string]::IsNullOrEmpty($Global:DefaultSortBy)) { $ezaArgs += "--sort=$Global:DefaultSortBy" }
        switch ($Type) {
            "ls" { }
            "ll" { $ezaArgs += @("-l", "-g", "--time-style=long-iso") }
            "la" { $ezaArgs += @("-la", "-g", "--time-style=long-iso") }
            "lt" { $ezaArgs += @("--tree", "--level=2") }
        }
        $passArgs = @()
        foreach ($a in $InputArgs) {
            if     ($a -match "^-size$") { $ezaArgs += "--sort=size" }
            elseif ($a -match "^-time$") { $ezaArgs += "--sort=newest" }
            elseif ($a -match "^-ext$")  { $ezaArgs += "--sort=ext" }
            elseif ($a -match "^-name$") { $ezaArgs += "--sort=name" }
            elseif ($a -match "^-rev$")  { $ezaArgs += "--reverse" }
            else { $passArgs += $a }
        }
        eza @ezaArgs @passArgs
    }
    function ls { Invoke-EzaWrapper "ls" $args }
    function ll { Invoke-EzaWrapper "ll" $args }
    function la { Invoke-EzaWrapper "la" $args }
    function lt { Invoke-EzaWrapper "lt" $args }
} else {
    function ListForce { Get-ChildItem -Force }
    Set-Alias la ListForce; Set-Alias ll Get-ChildItem
}

# 动态获取 scoop curl 与 tree
$scoopCurl = "$env:USERPROFILE\scoop\apps\curl\current\bin\curl.exe"
if (Test-Path $scoopCurl) { 
    if (Get-Alias curl -ErrorAction SilentlyContinue) { Remove-Item Alias:curl -Force }
    Set-Alias curl $scoopCurl 
}
function tree {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $scoopTree = "$env:USERPROFILE\scoop\apps\tree\current\bin\tree.exe"
    if (Test-Path $scoopTree) { & $scoopTree -N @args } else { & tree.com @args }
}

###########################################################################################
####                                 开发者超级辅助工具                                 ####
###########################################################################################

#[新增] 1. 端口查杀：查询占用某端口的进程并提供提示
function Get-PortOccupation ($Port) {
    if (!$Port) { Write-Warning "请输入端口号, 例如: ports 8080"; return }
    Write-Host "`n🔍 正在扫描占用端口 $Port 的进程..." -ForegroundColor Cyan
    $active = netstat -ano | Select-String ":$Port\s"
    if ($active) {
        $active | ForEach-Object {
            $parts = $_.Line.Split(' ',[StringSplitOptions]::RemoveEmptyEntries)
            $pidNum = $parts[-1]
            $proc = Get-Process -Id $pidNum -ErrorAction SilentlyContinue
            $procName = if ($proc) { $proc.ProcessName } else { "未知进程/系统保留" }
            Write-Host " 🔴 PID: $pidNum `t| 进程: $procName `t| 状态: $($parts[3])" -ForegroundColor Yellow
        }
        Write-Host "`n💡 提示: 可使用 'kill <PID>' 强制结束进程`n" -ForegroundColor DarkGray
    } else { Write-Host "✅ 端口 $Port 目前空闲。`n" -ForegroundColor Green }
}
Set-Alias ports Get-PortOccupation

# [新增] 2. 快速提权 (sudo)：以管理员身份新开窗口执行命令
if (!(Get-Command sudo -ErrorAction SilentlyContinue)) {
    function sudo {
        param([Parameter(ValueFromRemainingArguments=$true)][String[]]$Command)
        $cmd = $Command -join ' '
        Write-Host "🛡️ 正在请求管理员权限执行: $cmd" -ForegroundColor Yellow
        Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -NoExit -Command $cmd"
    }
}

# [新增] 3. 万能解压 (ex)：调用内置 tar 或 7z智能解压所有常见压缩包
function ex {
param([string]$File)
if (!(Test-Path $File)) { Write-Warning "找不到文件: $File"; return }
$dest = (Get-Item $File).BaseName
if (!(Test-Path $dest)) { New-Item -ItemType Directory -Path $dest | Out-Null }
Write-Host "📦 正在解压 $File 到 $dest ..." -ForegroundColor Cyan
try {
    $ext = [System.IO.Path]::GetExtension($File).ToLower()
    if (($ext -eq ".7z" -or $ext -eq ".rar") -and (Get-Command 7z -ErrorAction SilentlyContinue)) {
        & 7z x "$File" "-o$dest" -y | Out-Null
    } else {
        tar -xf "$File" -C "$dest"
    }
    if ($LASTEXITCODE -eq 0) { Write-Host "✅ 解压完成!" -ForegroundColor Green }
    else { throw }
}
catch { Write-Error "❌ 解压失败，请检查文件格式或是否安装了 7zip" }
}

# [新增] 4. 查看公网IP (myip)
function myip {
    Write-Host "🌍 正在获取公网 IP 信息..." -ForegroundColor Cyan
    try {
        $info = Invoke-RestMethod -Uri "https://ipinfo.io/json" -TimeoutSec 5
        Write-Host " 🌐 IP地址 : $($info.ip)" -ForegroundColor Green
        Write-Host " 📍 归属地 : $($info.city), $($info.region), $($info.country)" -ForegroundColor Green
        Write-Host " 🏢 运营商 : $($info.org)" -ForegroundColor Green
    } catch { Write-Host "❌ 网络请求失败" -ForegroundColor Red }
}

# [新增] 5. 终端 AI 程序员求助器 (howto)：极速查询命令与代码片段
function howto {
    if ($args.Count -eq 0) {
        Write-Warning "请输入要查询的命令或问题。"
        Write-Host "用法 1 (查命令): howto tar" -ForegroundColor DarkGray
        Write-Host "用法 2 (查场景): howto `"convert mp4 to mp3`"" -ForegroundColor DarkGray
        Write-Host "用法 3 (查代码): howto python `"read json file`"" -ForegroundColor DarkGray
        return
    }

    Write-Host "`n🤖 正在召唤终端 AI 程序员为您解答...`n" -ForegroundColor Cyan

    # 智能解析参数并拼接 URL
    if ($args.Count -eq 1) {
        # 单参数：可能是基础命令 (tar) 或一句话问题 (convert mp4 to mp3)
        $query = $args[0].Replace(' ', '+')
        $url = "https://cht.sh/$query"
    } else {
        # 多参数：第一个参数为语言 (python)，后面的参数为具体问题
        $lang = $args[0]
        $query = ($args[1..($args.Count-1)] -join '+').Replace(' ', '+')
        $url = "https://cht.sh/$lang/$query"
    }

    try {
        # 必须使用 curl.exe (-s 静默模式去除进度条)，以完美获取远端渲染的 ANSI 语法高亮
        curl.exe -s $url
        
        Write-Host "======================================================" -ForegroundColor DarkGray
        Write-Host "💡 提示: 直接用鼠标选中上方代码即可复制执行！`n" -ForegroundColor Green
    } catch {
        Write-Error "❌ 哎呀，请求失败了。请检查网络或稍后再试。"
    }
}


###########################################################################################
####                                快捷指令与别名系统                                  ####
###########################################################################################

# 1. 基础跳转与复制
function .. { Set-Location .. }
function ... { Set-Location ../.. }      
function .... { Set-Location ../../.. }  
# [新增] 建目录并进入
function mkcd { param([string]$Name); New-Item -ItemType Directory -Force -Path $Name | Out-Null; Set-Location $Name }
# [新增] 复制当前路径到剪贴板
function ccpp { (Get-Location).Path | Set-Clipboard; Write-Host "📋 当前路径已复制: $((Get-Location).Path)" -ForegroundColor Green }

# 2. 系统别名
function RecycleBinFolder { explorer.exe shell:RecycleBinFolder }
function SortScoopStatus { scoop update; scoop status | Sort-Object -Property info } 

Set-Alias -Name gh -Value Get-Help
Set-Alias -Name vi -Value vim -ErrorAction SilentlyContinue
Set-Alias -Name get-trash -Value RecycleBinFolder  
Set-Alias -Name ff -Value fastfetch -ErrorAction SilentlyContinue
Set-Alias -Name fs -Value Format-FileSize
Set-Alias -Name ss -Value scoop-search -ErrorAction SilentlyContinue
Set-Alias -Name guid -Value New-PartialGuid
Set-Alias -Name pip -Value pip3
Set-Alias -Name sss -Value SortScoopStatus
Set-Alias -Name source -Value Set-PoshGitStatus
Set-Alias -Name kill -Value Stop-Process -ErrorAction SilentlyContinue
Set-Alias -Name note -Value notepad4

###########################################################################################
####                                 高级配置管理                                       ####
###########################################################################################

function Reload-Profile { & $PROFILE; Write-Host "配置已重载！" -ForegroundColor Green }
Set-Alias rlp Reload-Profile

function Edit-Profile {
    if (Get-Command code -ErrorAction SilentlyContinue) { code $PROFILE }
    elseif (Get-Command nvim -ErrorAction SilentlyContinue) { nvim $PROFILE }
    else { notepad $PROFILE }
}
Set-Alias ep Edit-Profile


###########################################################################################
####                                 其他自定义函数                                     ####
###########################################################################################

function net-info {
    Write-Host "`n=== 网络适配器状态 ===" -ForegroundColor Cyan
    Get-NetAdapter | Where-Object Status -eq 'Up' | Format-Table Name, Status, LinkSpeed
    Write-Host "=== IP配置 ===" -ForegroundColor Cyan  
    Get-NetIPConfiguration | Format-Table InterfaceAlias, IPv4Address, IPv4DefaultGateway
}

function rss {
    $scriptDir = "D:\Documents\04_Scripts\Scripts\script_launcher"
    $venvPython = Join-Path $scriptDir ".venv\Scripts\python.exe"
    $scriptPath = Join-Path $scriptDir "main.py"
    if (Test-Path $venvPython) { Write-Host "使用虚拟环境运行..." -ForegroundColor Cyan; & $venvPython $scriptPath } 
    elseif (Test-Path $scriptPath) { Write-Host "使用全局 Python 运行..." -ForegroundColor Yellow; python $scriptPath } 
    else { Write-Host "错误: 找不到脚本 ($scriptPath) 或虚拟环境。" -ForegroundColor Red }
}

function lsd {
    param ([string]$Path = (Get-Location))
    try {
        $directories = Get-ChildItem -Directory -Path $Path
        if ($directories.Count -eq 0) {
            if (Get-Command Write-Color -ErrorAction SilentlyContinue) { Write-Color "目录 $Path 中没有子目录。" -Color Yellow } 
            else { Write-Host "目录 $Path 中没有子目录。" -ForegroundColor Yellow }
        } else {
            foreach ($dir in $directories) {
                if (Get-Command Write-Color -ErrorAction SilentlyContinue) { Write-Color "子目录: $($dir.Name)" -Color Green }
                else { Write-Host "子目录: $($dir.Name)" -ForegroundColor Green }
            }
        }
    } catch {
        Write-Host "错误: 路径 $Path 不存在或无法访问。" -ForegroundColor Red
    }
}

function Remove-EmptyFolders {[CmdletBinding(SupportsShouldProcess=$true)]
    param([Parameter(ValueFromPipeline=$true)][string]$Path = ".")
    process {
        Get-ChildItem -Path $Path -Directory -Recurse | Where-Object { 
            (Get-ChildItem $_.FullName -Force) -eq $null 
        } | ForEach-Object { 
            if ($PSCmdlet.ShouldProcess($_.FullName, "删除空文件夹")) { Remove-Item -Force -Recurse $_.FullName }
        }
    }
}

function touch {
    param ([Parameter(Mandatory = $true, ValueFromPipeline = $true)][string[]]$Paths)
    process {
        foreach ($Path in $Paths) {
            if (Test-Path -Path $Path) { (Get-Item $Path).LastWriteTime = Get-Date } 
            else { New-Item -ItemType File -Path $Path -Force | Out-Null }
        }
    }
}
 
function Set-PoshGitStatus {
    $global:GitStatus = Get-GitStatus
    $env:POSH_GIT_STRING = Write-GitStatus -Status $global:GitStatus
}
Set-Alias -Name 'Set-PoshContext' -Value 'Set-PoshGitStatus' -Force

function which ($command) { Get-Command -Name $command -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue }

function trash {[CmdletBinding()]
    param ([Parameter(Mandatory=$true, ValueFromPipeline=$true)][string[]]$FilePaths, [switch]$Filter, [string]$FilterPattern)
    process {
        $shell = New-Object -ComObject Shell.Application
        $recycleBin = $shell.Namespace(0xA)
        foreach ($Path in $FilePaths) {
            $files = @()
            if ($Filter) { $files = Get-ChildItem -Path $Path -File -Recurse | Where-Object { $_.Name -match $FilterPattern } } 
            else { if (Test-Path $Path) { $files += Get-Item $Path } }
            foreach ($file in $files) {
                try { $recycleBin.MoveHere($file.FullName) } 
                catch { Write-Error "删除失败: $($file.FullName) - $($_.Exception.Message)" }
            }
        }[System.Runtime.Interopservices.Marshal]::ReleaseComObject($shell) | Out-Null
    }
}
 
function Format-FileSize {
    param([Parameter(Mandatory, ValueFromPipeline)][long]$Size,[ValidateSet('B', 'KB', 'MB', 'GB', 'TB')][string]$Unit,[int]$Decimal = 2, [switch]$SI)
    process {
        $base = if ($SI) { 1000 } else { 1024 }
        $units = @('B', 'KB', 'MB', 'GB', 'TB')
        if ($Unit) {
            $index = $units.IndexOf($Unit)
            $result = $Size / [Math]::Pow($base, $index)
            return "{0:N$Decimal} $Unit" -f $result
        }
        $order = 0; $calcSize = $Size
        while ($calcSize -ge $base -and $order -lt $units.Count - 1) { $calcSize /= $base; $order++ }
        return "{0:N$Decimal} {1}" -f $calcSize, $units[$order]
    }
}

function New-PartialGuid {
    [CmdletBinding()]
    Param([int]$Length = 32)
    Process {
        if ($Length -le 0 -or $Length -gt 128) { Write-Error "指定的长度必须在 1 到 128 之间。"; return }
        if ($Length -le 32) { Write-Output ([guid]::NewGuid().ToString("N").Substring(0, $Length)) } 
        else { 
            $concatenatedGuids = ""; $requiredGuids =[math]::Ceiling($Length / 32.0)
            for ($i = 0; $i -lt $requiredGuids; $i++) { $concatenatedGuids += [guid]::NewGuid().ToString("N") }
            Write-Output ($concatenatedGuids.Substring(0, $Length))
        }
    }
}


###########################################################################################
####                                 系统清理与 Git 增强                                ####
###########################################################################################

# [新增] 1. 一键大扫除 (sys-clean)：强迫症福音，全方位释放 C 盘空间
function sys-clean {
    Write-Host "`n🧹 开始系统深度清理 (请耐心等待)..." -ForegroundColor Cyan
    
    # 1. 清理 Windows 临时文件夹
    Write-Host " ⏳[1/5] 正在清理 Windows 临时文件..." -ForegroundColor Yellow
    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    
    # 2. 清空回收站
    Write-Host " ⏳ [2/5] 正在静默清空回收站..." -ForegroundColor Yellow
    Clear-RecycleBin -Force -Confirm:$false -ErrorAction SilentlyContinue
    
    # 3. 清理 Scoop 历史旧版本
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-Host " ⏳ [3/5] 正在卸载 Scoop 软件的过期老版本..." -ForegroundColor Yellow
        scoop cleanup * | Out-Null
        
        Write-Host " ⏳ [4/5] 正在清除 Scoop 下载缓存..." -ForegroundColor Yellow
        scoop cache rm * | Out-Null
    }

    # 4. 清理 Pip 缓存
    if (Get-Command pip -ErrorAction SilentlyContinue) {
        Write-Host " ⏳ [5/5] 正在清理 Python Pip 缓存包..." -ForegroundColor Yellow
        pip cache purge | Out-Null
    }

    Write-Host "✨ 清理完成！你的系统现在已轻装上阵。`n" -ForegroundColor Green
}

# [新增] 2. Git 后悔药 (gundo)：一键撤销上一次 commit
function gundo {
    if (!(Test-Path .git)) { Write-Warning "当前目录不是 Git 仓库！"; return }
    Write-Host "⏪ 正在撤销最近一次 Commit..." -ForegroundColor Cyan
    try {
        # 使用 mixed 模式：撤销 commit 和暂存区，但保留你在文件里写的代码
        git reset HEAD~1
        Write-Host "`n✅ 已成功撤销！" -ForegroundColor Green
        Write-Host "💡 提示: 你的代码更改已全部保留在工作区，可以重新修改或添加后再提交。" -ForegroundColor DarkGray
    } catch {
        Write-Error "❌ 撤销失败，可能是当前分支没有任何历史 Commit 可以撤销。"
    }
}



###########################################################################################
####                                 自定义帮助面板                                     ####
###########################################################################################

function Show-MyHelp {
    Write-Host ""
    Write-Host " ========================================================================= " -ForegroundColor Cyan
    Write-Host "                          DantaKing's 终端终极快捷手册                      " -ForegroundColor Yellow
    Write-Host " ========================================================================= " -ForegroundColor Cyan
    
    Write-Host "`n [极速导航与文件搜索]" -ForegroundColor Magenta
    Write-Host "   z <目录名> : 智能模糊跳转目录 (代替 cd)"
    Write-Host "   f          : 交互式全局模糊搜索文件，并自动复制路径"
    Write-Host "   mkcd <名>  : 一键创建目录并进入"
    Write-Host "   ccpp        : 一键复制当前绝对路径到剪贴板"
    Write-Host "   .. / ...   : 向上返回 1 级 / 2 级 / 3 级 (....)"

    Write-Host "`n [万能文件处理与查看]" -ForegroundColor Magenta
    Write-Host "   ls/ll/la/lt: eza 增强列表 (附加 -Size, -Time, -Ext, -Rev 快捷排序)"
    Write-Host "   lsd        : 仅列出当前目录下的子文件夹"
    Write-Host "   tree       : 树状图显示目录结构 (完美支持中文输出，不乱码)"
    Write-Host "   cat <文件> : 自动使用 bat 带语法高亮读取文本"
    Write-Host "   touch      : 创建新文件或更新文件最后修改时间"
    Write-Host "   ex <压缩包>: 万能解压工具 (自动解压 zip, tar.gz 等)"

    Write-Host "`n [安全删除与清理]" -ForegroundColor Magenta
    Write-Host "   trash      : 安全删除文件至回收站 (支持正则: trash . -Filter '*.log')"
    Write-Host "   get-trash  : 快速在系统资源管理器中打开回收站"
    Write-Host "   Remove-EmptyFolders : 清理当前目录下所有空文件夹 (支持 -WhatIf 预览)"
    
    Write-Host "`n [开发者超级辅助]" -ForegroundColor Magenta
    Write-Host "   ports <号> : 查看指定端口被哪个程序占用 (例: ports 8080)"
    Write-Host "   kill <PID> : 强制杀掉对应进程"
    Write-Host "   sudo <令>  : 新开管理员权限窗口执行命令 (例: sudo notepad)"
    Write-Host "   myip       : 快速查看当前真实公网 IP 和地理归属地"
    Write-Host "   net-info   : 快速查看本地网络适配器、IP配置与 DNS 状态"
    Write-Host "   rss        : 启动自定义 Python 脚本管理器 (script_launcher)"
    Write-Host "   which <令> : 查找命令或程序的绝对路径 (例: which python)"
    Write-Host "   guid / fs  : 生成特定长度 GUID (guid -Length 16) / 转换字节为 MB/GB"
    Write-Host "   vi / pip   : 终端编辑器 vim 的简写 / pip3 的简写"
    Write-Host "   howto      : 终端 AI 求助 (例: howto python `"read json`" / howto tar)"

    Write-Host "`n [系统环境与包管理]" -ForegroundColor Magenta
    Write-Host "   ep / rlp   : 编辑配置文件 (Edit-Profile) / 重新加载配置 (Reload-Profile)"
    Write-Host "   ss / sss   : Scoop 搜索软件包 / Scoop 更新并按 info 状态排序展示"
    Write-Host "   source     : 手动刷新 Git 状态 (Set-PoshGitStatus)"
    Write-Host "   ff         : 重新展示系统美化信息 (Fastfetch)"
    Write-Host "   gh         : 调用原生系统帮助 (Get-Help)"
    
    Write-Host "`n [系统清理与 Git 增强]" -ForegroundColor Magenta
    Write-Host "   sys-clean  : 一键清理系统垃圾 (Scoop缓存/老版本/Temp/回收站/Pip)"
    Write-Host "   gundo      : 一键撤销 Git 上一次 Commit (保留代码修改)"

    Write-Host " ========================================================================= " -ForegroundColor Cyan
    Write-Host ""
}

function help {
    if ($args.Count -eq 0) { Show-MyHelp } 
    else { Get-Help @args | Out-Host -Paging }
}

###########################################################################################
####                                 启动问候与时间统计                                 ####
###########################################################################################

$LoadTime = ([datetime]::Now - $Global:ProfileStartTime).TotalMilliseconds

# 如果安装了 fastfetch，每次打开终端自动展示系统美化信息
if (Get-Command fastfetch -ErrorAction SilentlyContinue) {
    # fastfetch
    Write-Host "`n⚡ DantaKing, PowerShell环境已加载完毕 (耗时: ${LoadTime}ms)`n" -ForegroundColor DarkGray
} else {
    Write-Host "`n⚡ Welcome to PowerShell, DantaKing! (耗时: ${LoadTime}ms)`n" -ForegroundColor Cyan
}