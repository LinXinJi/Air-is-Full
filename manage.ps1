<#
.SYNOPSIS
    博客项目管理脚本
.DESCRIPTION
    用于管理博客项目的PowerShell脚本，支持单独启动和管理每个站点的开发服务器
.EXAMPLE
    .\manage.ps1 start cultivation-between-realms
    启动主站点的开发服务器
.EXAMPLE
    .\manage.ps1 start code-on-farm
    启动 Code on Farm 站点的开发服务器
.EXAMPLE
    .\manage.ps1 list
    列出所有可用的站点及其端口
.EXAMPLE
    .\manage.ps1 start
    默认启动主站点 air-is-full
#>

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('start', 'list')]
    [string]$Command,
    
    [Parameter(Position = 1)]
    # 核心修改1：给Site参数设置默认值为主站点 air-is-full
    [string]$Site = "air-is-full"
)

# 定义站点列表（包含端口号）
$sites = @(
    @{ Name = "air-is-full"; Description = "主站点"; Port = 8000 },
    @{ Name = "cultivation-between-realms"; Description = "Cultivation Between Realms 站点"; Port = 8001 },
    @{ Name = "code-on-farm"; Description = "Code on Farm 站点"; Port = 8002 },
    @{ Name = "fly-in-air"; Description = "Fly in Air 站点"; Port = 8003 },
    @{ Name = "walk-to-heart"; Description = "Walk to Heart 站点"; Port = 8004 }
)

# 保存当前目录
$originalLocation = Get-Location

# 激活虚拟环境
function Activate-VirtualEnvironment {
    if (Test-Path ".venv\Scripts\Activate.ps1") {
        Write-Host "激活虚拟环境..."
        .venv\Scripts\activate
        return $true
    }
    else {
        Write-Warning "未找到虚拟环境，将使用系统Python"
        return $false
    }
}

# 启动站点的开发服务器
function Start-SiteServer {
    param(
        [string]$SiteName = "air-is-full",
        [string]$Description,
        [int]$Port
    )
    
    Write-Host "`n启动 $Description ($SiteName)..."
    Write-Host "----------------------------------------"
    Write-Host "站点: $SiteName"
    Write-Host "描述: $Description"
    Write-Host "端口: $Port"
    Write-Host "访问地址: http://localhost:$Port"
    Write-Host "----------------------------------------"
    
    # 切换到站点目录
    Set-Location $SiteName
    
    try {
        # 启动开发服务器，指定端口
        Write-Host "启动开发服务器..." -ForegroundColor Green
        Write-Host "按 Ctrl+C 停止服务"
        mkdocs serve --dev-addr=localhost:$Port
    }
    catch {
        Write-Error "启动 $SiteName 失败: $_" -ForegroundColor Red
    }
    finally {
        # 返回到原始目录
        Set-Location $originalLocation
    }
}

# 列出所有可用的站点
function List-Sites {
    Write-Host "`n可用的站点列表"
    Write-Host "======================================="
    foreach ($site in $sites) {
        Write-Host "站点: $($site.Name)"
        Write-Host "描述: $($site.Description)"
        Write-Host "端口: $($site.Port)"
        Write-Host "访问地址: http://localhost:$($site.Port)"
        Write-Host "命令: .\manage.ps1 start $($site.Name)"
        Write-Host "----------------------------------------"
    }
}

# 主函数
function Main {
    # 激活虚拟环境
    Activate-VirtualEnvironment
    
    # 执行命令
    switch ($Command) {
        "start" {
            # 核心修改2：移除空值判断（因为参数已有默认值，不会为空）
            # 直接查找目标站点（默认就是 air-is-full）
            $targetSite = $sites | Where-Object { $_.Name -eq $Site }
            if ($targetSite) {
                Start-SiteServer -SiteName $targetSite.Name -Description $targetSite.Description -Port $targetSite.Port
            }
            else {
                Write-Error "未找到指定的站点: $Site" -ForegroundColor Red
                Write-Host "可用的站点: $($sites.Name -join ', ')`n" -ForegroundColor Yellow
                Write-Host "使用 .\manage.ps1 list 查看所有可用的站点"
            }
        }
        "list" {
            List-Sites
        }
    }
}

# 调用主函数
Main

# 返回到原始目录
Set-Location $originalLocation