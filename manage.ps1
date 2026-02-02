<#
.SYNOPSIS
    博客项目管理脚本
.DESCRIPTION
    用于管理博客项目的PowerShell脚本，支持启动各个站点的开发服务器
.EXAMPLE
    .\manage.ps1 serve
    启动所有站点的开发服务器
.EXAMPLE
    .\manage.ps1 serve -site cultivation-between-realms
    只启动指定站点的开发服务器
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [ValidateSet('serve')]
    [string]$Command,
    
    [Parameter(Position=1)]
    [string]$Site = "all"
)

# 定义站点列表
$sites = @(
    @{ Name = "cultivation-between-realms"; Description = "主站点" },
    @{ Name = "code-on-farm"; Description = "Code on Farm 站点" },
    @{ Name = "fly-in-air"; Description = "Fly in Air 站点" },
    @{ Name = "walk-to-heart"; Description = "Walk to Heart 站点" }
)

# 保存当前目录
$originalLocation = Get-Location

# 激活虚拟环境
function Activate-VirtualEnvironment {
    if (Test-Path ".venv\Scripts\Activate.ps1") {
        Write-Host "激活虚拟环境..."
        .venv\Scripts\activate
        return $true
    } else {
        Write-Warning "未找到虚拟环境，将使用系统Python"
        return $false
    }
}

# 启动站点的开发服务器
function Start-SiteServer {
    param(
        [string]$SiteName,
        [string]$Description
    )
    
    Write-Host "`n启动 $Description ($SiteName)..."
    Write-Host "----------------------------------------"
    
    # 切换到站点目录
    Set-Location $SiteName
    
    try {
        # 启动开发服务器
        mkdocs serve
    } catch {
        Write-Error "启动 $SiteName 失败: $_"
    } finally {
        # 返回到原始目录
        Set-Location $originalLocation
    }
}

# 主函数
function Main {
    # 激活虚拟环境
    Activate-VirtualEnvironment
    
    # 执行命令
    switch ($Command) {
        "serve" {
            if ($Site -eq "all") {
                Write-Host "准备启动所有站点的开发服务器..."
                Write-Host "注意：每个站点将在单独的终端窗口中启动"
                Write-Host "按任意键开始..."
                $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                
                # 为每个站点启动一个新的终端窗口
                foreach ($site in $sites) {
                    $siteName = $site.Name
                    $description = $site.Description
                    
                    # 在新的终端窗口中启动站点
                    Start-Process pwsh.exe -ArgumentList "-NoExit", "-Command", ".\manage.ps1 serve $siteName"
                    
                    # 等待1秒，避免同时启动多个进程导致的问题
                    Start-Sleep -Seconds 1
                }
                
                Write-Host "`n所有站点的开发服务器已在单独的终端窗口中启动"
                Write-Host "使用 Ctrl+C 停止各个终端窗口中的服务"
            } else {
                # 查找指定的站点
                $targetSite = $sites | Where-Object { $_.Name -eq $Site }
                if ($targetSite) {
                    Start-SiteServer -SiteName $targetSite.Name -Description $targetSite.Description
                } else {
                    Write-Error "未找到指定的站点: $Site"
                    Write-Host "可用的站点: $($sites.Name -join ', ')`n"
                }
            }
        }
    }
}

# 调用主函数
Main

# 返回到原始目录
Set-Location $originalLocation
