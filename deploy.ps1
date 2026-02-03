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

# 1. 检查build.ps1是否存在
if (-not (Test-Path $buildScript)) {
    Write-Error "错误：找不到构建脚本 $buildScript，请确认文件路径正确"
    exit 1
}

# 2. 执行构建脚本，生成site目录
Write-Host "`n[步骤1/5] 执行构建脚本 $buildScript ..." -ForegroundColor Cyan
& $buildScript

# 检查构建是否成功（判断site目录是否存在）
if (-not (Test-Path $siteDir)) {
    Write-Error "错误：构建失败，未生成 $siteDir 目录"
    exit 1
}
Write-Host "构建成功，site目录已生成" -ForegroundColor Green

# 3. 检查Git工作区是否干净（避免未提交修改影响分支切换）
Write-Host "`n[步骤2/5] 检查Git工作区状态..." -ForegroundColor Cyan
$gitStatus = git status --porcelain
if ($gitStatus -ne $null -and $gitStatus -ne "") {
    Write-Warning "发现未提交的修改，先暂存当前工作区（后续可通过 git stash pop 恢复）"
    git stash
}

# 4. 清空并推送gh-pages分支
Write-Host "`n[步骤3/5] 处理gh-pages分支..." -ForegroundColor Cyan
# 4.1 创建临时分支（避免污染main分支）
$tempBranch = "temp-gh-pages-deploy-$(Get-Date -Format 'yyyyMMddHHmmss')"
git checkout -b $tempBranch | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "错误：创建临时分支失败"
    exit 1
}

# 4.2 彻底清空远端gh-pages分支（先删除远端，再本地重建空分支）
Write-Host "清空远端gh-pages分支..."
git push origin --delete $targetBranch 2>&1 | Out-Null
# 忽略分支不存在的错误（首次推送时远端无gh-pages，该命令会失败，不影响后续流程）

# 4.3 本地创建纯净的gh-pages分支（无任何历史提交）
git checkout --orphan $targetBranch | Out-Null
git rm -rf . --quiet  # 删除当前分支下所有文件
Write-Host "本地gh-pages分支已清空，准备复制site目录内容..." -ForegroundColor Green

# 4.4 复制site目录下的所有内容到当前分支根目录
Copy-Item -Path "$siteDir\*" -Destination . -Recurse -Force
if (-not (Get-ChildItem . -ErrorAction SilentlyContinue)) {
    Write-Error "错误：site目录为空，无内容可推送"
    # 回滚分支，避免残留
    git checkout $mainBranch | Out-Null
    git branch -D $tempBranch $targetBranch | Out-Null
    exit 1
}

# 4.5 提交并推送gh-pages分支
Write-Host "提交site目录内容到gh-pages分支..."
git add .
git commit -m "Deploy site: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" --quiet
if ($LASTEXITCODE -ne 0) {
    Write-Error "错误：提交gh-pages分支内容失败"
    exit 1
}

Write-Host "推送gh-pages分支到远端..."
git push origin $targetBranch
if ($LASTEXITCODE -eq 0) {
    Write-Host "gh-pages分支推送成功" -ForegroundColor Green
}
else {
    Write-Error "错误：推送gh-pages分支到远端失败"
    exit 1
}

# 5. 切回main分支，清理临时文件
Write-Host "`n[步骤4/5] 恢复工作环境..." -ForegroundColor Cyan
# 5.1 切回main分支
git checkout $mainBranch | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "错误：切回main分支失败"
    exit 1
}

# 5.2 删除临时分支和本地gh-pages分支（清理冗余）
git branch -D $tempBranch $targetBranch | Out-Null

# 5.3 恢复之前暂存的工作区修改
if ($gitStatus -ne $null -and $gitStatus -ne "") {
    Write-Warning "恢复之前暂存的工作区修改..."
    git stash pop 2>&1 | Out-Null
}

# 6. 完成提示
Write-Host "`n[步骤5/5] 部署流程全部完成！" -ForegroundColor Green
Write-Host "✅ 网站已推送至gh-pages分支，当前已回到main分支继续工作"
Write-Host "✅ GitHub Pages访问地址：https://linxinji.github.io/Air-is-Full/"