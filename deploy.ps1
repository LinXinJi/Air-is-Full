<#
.SYNOPSIS
自动化部署网站到GitHub Pages的gh-pages分支
.DESCRIPTION
步骤：1. 执行build.ps1构建网站 2. 清空远端gh-pages 3. 推送site目录到gh-pages 4. 切回main分支
#>

# -------------- 配置项（可根据实际情况修改）--------------
$repoUrl = "https://github.com/LinXinJi/Air-is-Full"
$buildScript = ".\build.ps1"
$siteDir = ".\site"
$targetBranch = "gh-pages"
$mainBranch = "main"
# ---------------------------------------------------------

# 辅助函数：执行Git命令并处理错误
function Invoke-GitCommand {
    param(
        [string[]]$GitArgs,
        [string]$SuccessMsg,
        [string]$ErrorMsg,
        [bool]$IgnoreError = $false
    )
    
    # 执行Git命令并捕获输出和退出码
    $output = & git $GitArgs 2>&1
    $exitCode = $LASTEXITCODE

    # 输出成功日志（如果指定）
    if ($exitCode -eq 0 -and $SuccessMsg) {
        Write-Host $SuccessMsg -ForegroundColor Green
    }

    # 处理错误（如果不忽略）
    if ($exitCode -ne 0 -and -not $IgnoreError) {
        Write-Error "$ErrorMsg`nGit输出：$($output -join "`n")"
        # 执行紧急回滚
        Invoke-EmergencyRollback
        exit 1
    }

    return $exitCode
}

# 辅助函数：紧急回滚（分支异常时恢复环境）
function Invoke-EmergencyRollback {
    Write-Host "`n⚠️  执行紧急回滚，恢复工作环境..." -ForegroundColor Yellow
    
    # 尝试切回主分支
    if (git rev-parse --verify $mainBranch 2>&1) {
        git checkout $mainBranch --quiet 2>&1 | Out-Null
    }

    # 删除临时分支和目标分支（如果存在）
    $tempBranchExists = git branch --list $tempBranch 2>&1
    if ($tempBranchExists) {
        git branch -D $tempBranch 2>&1 | Out-Null
    }
    
    $targetBranchExists = git branch --list $targetBranch 2>&1
    if ($targetBranchExists) {
        git branch -D $targetBranch 2>&1 | Out-Null
    }

    # 恢复暂存的工作区
    if ($script:hasStashedChanges) {
        git stash pop 2>&1 | Out-Null
    }
}

# 初始化变量
$script:hasStashedChanges = $false

# 1. 检查构建脚本是否存在
Write-Host "`n[步骤1/5] 检查构建环境..." -ForegroundColor Cyan
if (-not (Test-Path $buildScript)) {
    Write-Error "错误：找不到构建脚本 $buildScript，请确认文件路径正确"
    exit 1
}

# 2. 执行构建脚本
Write-Host "`n[步骤2/5] 执行网站构建..." -ForegroundColor Cyan
& $buildScript
if ($LASTEXITCODE -ne 0) {
    Write-Error "错误：构建脚本 $buildScript 执行失败"
    exit 1
}

# 检查构建产物是否存在
if (-not (Test-Path $siteDir)) {
    Write-Error "错误：构建失败，未生成 $siteDir 目录"
    exit 1
}
Write-Host "✅ 构建成功，site目录已生成" -ForegroundColor Green

# 3. 检查Git工作区状态
Write-Host "`n[步骤3/5] 检查Git工作区状态..." -ForegroundColor Cyan
$gitStatus = git status --porcelain
if ($gitStatus -and $gitStatus -ne "") {
    Write-Warning "发现未提交的修改，暂存当前工作区（后续可通过 git stash pop 恢复）"
    Invoke-GitCommand -GitArgs @("stash") -SuccessMsg "✅ 工作区已暂存" -ErrorMsg "错误：暂存工作区失败"
    $script:hasStashedChanges = $true
}
else {
    Write-Host "✅ Git工作区干净" -ForegroundColor Green
}

# 4. 处理gh-pages分支
Write-Host "`n[步骤4/5] 处理gh-pages分支..." -ForegroundColor Cyan
$tempBranch = "temp-gh-pages-deploy-$(Get-Date -Format 'yyyyMMddHHmmss')"

# 4.1 创建临时分支
Invoke-GitCommand -GitArgs @("checkout", "-b", $tempBranch) `
    -SuccessMsg "✅ 临时分支 $tempBranch 创建成功" `
    -ErrorMsg "错误：创建临时分支 $tempBranch 失败"

# 4.2 删除远端gh-pages分支（忽略不存在的错误）
Write-Host "🔄 清空远端gh-pages分支..." -ForegroundColor Cyan
Invoke-GitCommand -GitArgs @("push", "origin", "--delete", $targetBranch) `
    -SuccessMsg "✅ 远端 $targetBranch 分支已删除" `
    -ErrorMsg "警告：远端 $targetBranch 分支删除失败（首次部署可忽略）" `
    -IgnoreError $true

# 4.3 创建纯净的gh-pages孤儿分支
Invoke-GitCommand -GitArgs @("checkout", "--orphan", $targetBranch) `
    -SuccessMsg "✅ 本地孤儿分支 $targetBranch 创建成功" `
    -ErrorMsg "错误：创建本地 $targetBranch 分支失败"

# 4.4 清空分支所有文件
Invoke-GitCommand -GitArgs @("rm", "-rf", ".", "--quiet") `
    -SuccessMsg "✅ 本地 $targetBranch 分支已清空" `
    -ErrorMsg "错误：清空 $targetBranch 分支文件失败"

# 4.5 复制site目录内容到当前分支
Write-Host "🔄 复制site目录内容到 $targetBranch 分支..." -ForegroundColor Cyan
Copy-Item -Path "$siteDir\*" -Destination . -Recurse -Force -ErrorAction Stop

# 检查复制后是否有内容
$files = Get-ChildItem . -File -Recurse -ErrorAction SilentlyContinue
if (-not $files) {
    Write-Error "错误：site目录为空，无内容可推送"
    Invoke-EmergencyRollback
    exit 1
}
Write-Host "✅ site目录内容复制完成" -ForegroundColor Green

# 4.6 提交并推送gh-pages分支
Write-Host "🔄 提交 $targetBranch 分支内容..." -ForegroundColor Cyan
Invoke-GitCommand -GitArgs @("add", ".") `
    -SuccessMsg $null `
    -ErrorMsg "错误：添加文件到暂存区失败"

$commitMsg = "Deploy site: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Invoke-GitCommand -GitArgs @("commit", "-m", $commitMsg, "--quiet") `
    -SuccessMsg "✅ 提交成功：$commitMsg" `
    -ErrorMsg "错误：提交 $targetBranch 分支内容失败"

# 推送分支到远端
Write-Host "🔄 推送 $targetBranch 分支到远端..." -ForegroundColor Cyan
Invoke-GitCommand -GitArgs @("push", "-f", "origin", $targetBranch) `
    -SuccessMsg "✅ $targetBranch 分支推送成功" `
    -ErrorMsg "错误：推送 $targetBranch 分支到远端失败"

# 5. 恢复工作环境
Write-Host "`n[步骤5/5] 恢复工作环境..." -ForegroundColor Cyan

# 切回主分支
Invoke-GitCommand -GitArgs @("checkout", $mainBranch) `
    -SuccessMsg "✅ 已切回 $mainBranch 分支" `
    -ErrorMsg "错误：切回 $mainBranch 分支失败"

# 删除临时分支和本地gh-pages分支
$branchesToDelete = @($tempBranch, $targetBranch)
foreach ($branch in $branchesToDelete) {
    $branchExists = git branch --list $branch 2>&1
    if ($branchExists) {
        Invoke-GitCommand -GitArgs @("branch", "-D", $branch) `
            -SuccessMsg "✅ 已删除本地分支：$branch" `
            -ErrorMsg "警告：删除本地分支 $branch 失败（可手动删除）" `
            -IgnoreError $true
    }
}

# 恢复暂存的工作区修改
if ($script:hasStashedChanges) {
    Write-Host "🔄 恢复之前暂存的工作区修改..." -ForegroundColor Cyan
    Invoke-GitCommand -GitArgs @("stash", "pop") `
        -SuccessMsg "✅ 工作区已恢复" `
        -ErrorMsg "警告：恢复工作区失败（可手动执行 git stash pop）" `
        -IgnoreError $true
}

# 6. 完成提示
Write-Host "`n==================================================" -ForegroundColor Green
Write-Host "🎉 部署流程全部完成！" -ForegroundColor Green
Write-Host "✅ 网站已成功推送至 $targetBranch 分支" -ForegroundColor Green
Write-Host "✅ 当前已回到 $mainBranch 分支，可继续开发工作" -ForegroundColor Green
Write-Host "🌐 GitHub Pages访问地址：https://linxinji.github.io/Air-is-Full/" -ForegroundColor Green
Write-Host "==================================================`n" -ForegroundColor Green