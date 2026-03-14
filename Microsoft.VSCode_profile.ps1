###########################################################################################
####                                  外观                                             ####
###########################################################################################

# $Prompt = "Welcome to PowerShell, KiyonoRin. "
# Write-Host $Prompt

## 去除默认的PowerShell提示(settings文件中修改)
#"commandline": "%SystemRoot%\\System32\\WindowsPowerShell\\v1.0\\powershell.exe -Nologo",

## 自定义输出界面(建议去除，提升性能)
# $startWork = "                    _          _ _
#  _ __   _____      _____ _ __ ___| |__   ___| | |
# | '_ \ / _ \ \ /\ / / _ \ '__/ __| '_ \ / _ \ | |
# | |_) | (_) \ V  V /  __/ |  \__ \ | | |  __/ | |
# | .__/ \___/ \_/\_/ \___|_|  |___/_| |_|\___|_|_|
# |_|
# "
# Write-Host $startWork
# Write-Host "自定义脚本启动器： rss"

## 设置Posh主题
# oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH/powerlevel10k_lean.omp.json" | Invoke-Expression 
oh-my-posh init pwsh --config "C:\Users\Administrator\.config\posh\powerlevel10k_modify.omp.json" | Invoke-Expression 

# 设置路径显示规则
# $Env:POSH_GIT_STRING = $(if ($PWD.Path.Split('\').Count -gt 5) { '...' + $PWD.Path.Split('\')[-2..-1] -join '\' } else { $PWD.Path })

# enable completion in current shell
Import-Module "$($(Get-Item $(Get-Command scoop.ps1).Path).Directory.Parent.FullName)\modules\scoop-completion"

###########################################################################################
####                                   基础功能                                         ####
###########################################################################################

# 修复因为默认安装路径修改导致的变量定义不生效
# $env:SCOOP = 'C:\UserScoop'
# $env:SCOOP_GLOBAL = 'C:\ProgramData\scoop'
# [Environment]::SetEnvironmentVariable('SCOOP', $env:SCOOP, 'Machine')
# 初始化 Starship
# Invoke-Expression (&starship init powershell)

# 设置输出文件编码为UTF-8
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

###########################################################################################
####                                   功能拓展                                         ####
###########################################################################################

## 导入模块

Import-Module posh-git # 引入 posh-git
# Import-Module oh-my-posh # 引入 oh-my-posh 


# Import-Module ZLocation
Import-Module PSReadLine
Import-Module Terminal-Icons
Import-Module PSWriteColor
Import-Module Log

# 自动建议
Set-PSReadLineOption -PredictionSource HistoryAndPlugin

# 命令补全
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineOption -PredictionSource History
Set-PSReadlineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadlineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadlineKeyHandler -Key Ctrl+d -Function DeleteCharOrExit


###########################################################################################
####                                 自定义功能                                          ####
###########################################################################################

## 别名函数
function ListForce {
    Get-ChildItem -Force
}
# function DiskSystemInformation {
# & neofetch ; & duf ;
# }
function RecycleBinFolder {
    explorer.exe shell:RecycleBinFolder
}
function .. {
    Set-location ../
}

function SortScoopStatus {
    scoop update
    scoop status | sort -Property info
} 



# 定义别名
Set-Alias la ListForce
Set-Alias gh Get-Help
Set-Alias vi neovim
Set-Alias vi nvim
Set-Alias ll ChildItem
Set-Alias get-trash RecycleBinFolder  
Set-Alias ff fastfetch
Set-Alias fs Format-FileSize
# 展示排序后的 scoop status 排序依据：info
Set-Alias sss SortScoopStatus
# 启动脚本管理器
Set-Alias rss Start-ScriptSelector

# 重定向curl路径
# Set-Alias curl 'C:\Users\Administrator\scoop\shims\curl.exe'


###########################################################################################
####                                 自定义函数                                          ####
###########################################################################################

function Start-ScriptSelector {
    $scriptPath = "C:\Users\Administrator\Documents\Scripts\src\runScriptSelector\runScriptSelector.ps1"
    
    if (Test-Path $scriptPath) {
        Write-Host "启动 Script Selector..." -ForegroundColor Green
        try {
            & $scriptPath
        } catch {
            Write-Host "运行时出错：" -ForegroundColor Red
            Write-Host $_.Exception.Message
        }
    } else {
        Write-Host "找不到脚本：$scriptPath" -ForegroundColor Red
    }
}

function lsd {
    param (
        [string]$Path = (Get-Location)  # 默认为当前目录
    )
    
    try {
        # 获取子目录并输出
        $directories = Get-ChildItem -Directory -Path $Path
        
        if ($directories.Count -eq 0) {
            Write-Color "目录 $Path 中没有子目录。" -Color Yellow
        } else {
            foreach ($dir in $directories) {
                # 使用 PSWriteColor 输出彩色目录名称
                Write-Color "子目录: $($dir.Name)" -Color Green
            }
        }
    } catch {
        # 处理路径不存在的情况
        Write-Color "错误: 路径 $Path 不存在或无法访问。" -Color Red
    }
}


# 函数描述： 删除
function Remove-EmptyFolders {
    param(
        [string]$Path = "."
    )
    
    # 获取所有空的子文件夹
    Get-ChildItem -Path $Path -Directory -Recurse | Where-Object { 
        (Get-ChildItem $_.FullName) -eq $null 
    } | ForEach-Object { 
        # 递归删除文件夹
        Remove-Item -Force -Recurse $_.FullName
    }
}



# 函数描述： 实现 linux 上的 touch 命令
function touch {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string[]]$Paths
    )
    process {
        foreach ($Path in $Paths) {
            if (Test-Path -Path $Path) {
                # 如果文件存在，更新文件的最后写入时间
                (Get-Item $Path).LastWriteTime = Get-Date
            } else {
                # 如果文件不存在，创建新文件
                New-Item -ItemType File -Path $Path -Force | Out-Null
            }
        }
    }
}


 
# 函数描述: 显示默认的 posh-git 输出
function Set-PoshGitStatus {
    $global:GitStatus = Get-GitStatus
    $env:POSH_GIT_STRING = Write-GitStatus -Status $global:GitStatus
}
New-Alias -Name 'Set-PoshContext' -Value 'Set-PoshGitStatus' 


# 函数描述: 实现 Linux 上的 which 命令 
function which ($command) {
    Get-command -name $command -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue
}


# 函数描述：用于删除文件至回收站，添加 Filter 参数。
function trash { 
    param (
        [string[]]$FilePaths, # 删除操作的文件路径数组
        [switch]$Filter, # 如果启用，将筛选出要删除的文件
        [string]$FilterPattern # 如果使用 -Filter, 可以指定用于筛选文件的正则表达式模式
    )

    $shell = New-Object -ComObject Shell.Application
    $recycleBin = $shell.Namespace(0xA)

    $allDeleted = $true  # 用于记录是否全部删除成功

    foreach ($Path in $FilePaths) {
        $files = @()
        if ($Filter) {
            $filteredFiles = Get-ChildItem -Path $Path -File -Recurse | Where-Object { $_.Name -match $FilterPattern }
            $files += $filteredFiles
        }
        else {
            $files += Get-Item $Path
        }

        foreach ($file in $files) {
            try {
                $recycleBin.MoveHere($file.FullName)
            }
            catch {
                $allDeleted = $false
                Write-Host "删除失败: $($file.FullName) - $($_.Exception.Message)"
            }
        }
    }

    if ($allDeleted) {  
    }
}
 

# 函数描述：将文件大小格式化为指定的单位
function Format-FileSize($Path, $Unit = "MB") { 
    $length = Get-Item $Path | Select-Object Length

    $length = [int]$length.Length
    # 进行错误检查
    if ($length -eq $null) {
        throw "无法获取文件大小。"
    }

    switch ($Unit) {
        "B" {
            $output = $length
        }
        "KB" {
            $output = $length / 1KB
        }
        "MB" {
            $output = $length / 1MB
        }
        "GB" {
            $output = $length / 1GB
        }
        "TB" {
            $output = $length / 1TB
        }
        default {
            return "未知单位"
        }
    }
    $output = $output.ToString("0.0000")
    Write-Host "$output $Unit"
} 




if (Test-Path "C:\Users\Administrator\.jabba\jabba.ps1") { . "C:\Users\Administrator\.jabba\jabba.ps1" }

