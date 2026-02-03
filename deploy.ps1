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

# 全局错误处理：遇到错误立即终止
$ErrorActionPreference = "Stop"

function Test-GitCommandSuccess {
    param([string]$command, [string]$errorMsg)
    # 执行Git命令并捕获输出和退出码
    $output = & git $command 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        # 排除"分支不存在"的预期错误（仅针对delete分支场景）
        if (-not ($command -match "push origin --delete" -and $output -match "remote: error: unable to delete.*not found")) {
            Write-Error "$errorMsg`nGit输出：$($output -join "`n")"
            exit 1
        }
    }
    return $exitCode
}

# 1. 检查build.ps1是否存在
if (-not (Test-Path $buildScript -PathType Leaf)) {
    Write-Error "错误：找不到构建脚本 $buildScript，请确认文件路径正确"
    exit 1
}

# 2. 执行构建脚本，生成site目录
Write-Host "`n[步骤1/5] 执行构建脚本 $buildScript ..." -ForegroundColor Cyan
& $buildScript
if ($LASTEXITCODE -ne 0) {
    Write-Error "错误：构建脚本 $buildScript 执行失败，退出码：$LASTEXITCODE"
    exit 1
}

# 检查构建是否成功（判断site目录是否存在且非空）
if (-not (Test-Path $siteDir -PathType Container) -or (-not (Get-ChildItem $siteDir -Recurse -File))) {
    Write-Error "错误：构建失败，$siteDir 目录不存在或为空"
    exit 1
}
Write-Host "构建成功，site目录已生成" -ForegroundColor Green

# 3. 检查Git工作区是否干净
Write-Host "`n[步骤2/5] 检查Git工作区状态..." -ForegroundColor Cyan
$gitStatus = git status --porcelain
$hasStash = $false
if ($gitStatus -and $gitStatus -ne "") {
    Write-Warning "发现未提交的修改，先暂存当前工作区（后续可通过 git stash pop 恢复）"
    Test-GitCommandSuccess -command "stash" -errorMsg "错误：暂存工作区修改失败"
    $hasStash = $true
}

# 4. 清空并推送gh-pages分支
Write-Host "`n[步骤3/5] 处理gh-pages分支..." -ForegroundColor Cyan
$tempBranch = "temp-gh-pages-deploy-$(Get-Date -Format 'yyyyMMddHHmmss')"

# 4.1 创建临时分支
Test-GitCommandSuccess -command "checkout -b $tempBranch" -errorMsg "错误：创建临时分支 $tempBranch 失败"

# 4.2 彻底清空远端gh-pages分支
Write-Host "清空远端gh-pages分支..."
Test-GitCommandSuccess -command "push origin --delete $targetBranch" -errorMsg "错误：删除远端 $targetBranch 分支失败"

# 4.3 本地创建纯净的gh-pages分支
Test-GitCommandSuccess -command "checkout --orphan $targetBranch" -errorMsg "错误：创建孤儿分支 $targetBranch 失败"
Test-GitCommandSuccess -command "rm -rf . --quiet" -errorMsg "错误：清空 $targetBranch 分支文件失败"
Write-Host "本地gh-pages分支已清空，准备复制site目录内容..." -ForegroundColor Green

# 4.4 复制site目录内容（排除.git目录）
Copy-Item -Path "$siteDir\*" -Destination . -Recurse -Force
# 校验：排除.git后是否有实际文件
$actualFiles = Get-ChildItem . -Recurse -File | Where-Object { $_.FullName -notmatch "\\.git\\" }
if (-not $actualFiles) {
    Write-Error "错误：site目录为空，无内容可推送"
    # 回滚分支
    git checkout $mainBranch 2>&1 | Out-Null
    git branch -D $tempBranch $targetBranch 2>&1 | Out-Null
    exit 1
}

# 4.5 提交并推送gh-pages分支
Write-Host "提交site目录内容到gh-pages分支..."
Test-GitCommandSuccess -command "add ." -errorMsg "错误：添加文件到暂存区失败"
Test-GitCommandSuccess -command "commit -m ""Deploy site: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"" --quiet" -errorMsg "错误：提交 $targetBranch 分支内容失败"

Write-Host "推送gh-pages分支到远端..."
Test-GitCommandSuccess -command "push origin $targetBranch" -errorMsg "错误：推送 $targetBranch 分支到远端失败"
Write-Host "$targetBranch 分支推送成功" -ForegroundColor Green

# 5. 恢复工作环境
Write-Host "`n[步骤4/5] 恢复工作环境..." -ForegroundColor Cyan
# 5.1 切回main分支
Test-GitCommandSuccess -command "checkout $mainBranch" -errorMsg "错误：切回 $mainBranch 分支失败"

# 5.2 清理临时分支（逐个删除，避免一个失败导致全部失败）
foreach ($branch in @($tempBranch, $targetBranch)) {
    $exitCode = Test-GitCommandSuccess -command "branch -D $branch" -errorMsg "错误：删除分支 $branch 失败"
    if ($exitCode -eq 0) {
        Write-Host "已删除本地分支：$branch" -ForegroundColor Gray
    }
}

# 5.3 恢复暂存的修改（处理冲突）
if ($hasStash) {
    Write-Warning "恢复之前暂存的工作区修改..."
    $stashOutput = git stash pop 2>&1
    $stashExitCode = $LASTEXITCODE
    if ($stashExitCode -ne 0) {
        Write-Warning "恢复暂存修改时发生冲突，请手动处理！`nGit输出：$($stashOutput -join "`n")"
    }
}

# 6. 完成提示
Write-Host "`n[步骤5/5] 部署流程全部完成！" -ForegroundColor Green
Write-Host "✅ 网站已推送至gh-pages分支，当前已回到$mainBranch分支继续工作"
Write-Host "✅ GitHub Pages访问地址：https://linxinji.github.io/Air-is-Full/"