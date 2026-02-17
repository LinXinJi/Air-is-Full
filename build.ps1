# 激活虚拟环境
.venv\Scripts\activate

# 清空 site 目录（如果存在）
if (Test-Path docs) {
    Write-Host "清空 docs 目录" -ForegroundColor Green
    Remove-Item -Path docs -Recurse -Force 
}

# 构建主页
Write-Host "构建主页" -ForegroundColor Green
Set-Location air-is-full
mkdocs build

# 构建 think-about-it 站点
Write-Host "构建 think-about-it 站点" -ForegroundColor Green
Set-Location ..\think-about-it
mkdocs build

# 构建 fly-in-air 站点
Write-Host "构建 fly-in-air 站点" -ForegroundColor Green
Set-Location ..\fly-in-air
mkdocs build

# 构建 walk-to-heart 站点
Write-Host "构建 walk-to-heart 站点" -ForegroundColor Green
Set-Location ..\walk-to-heart
mkdocs build

# 构建 code-on-farm 站点
Write-Host "构建 code-on-farm 站点" -ForegroundColor Green
Set-Location ..\code-on-farm
mkdocs build

Set-Location ..

# 将 .\air-is-full\air-is-full 目录复制到项目根目录的 docs 目录
Write-Host "将 .\air-is-full\air-is-full 目录复制到项目根的 docs 目录" -ForegroundColor Green
Copy-Item -Path .\air-is-full\air-is-full -Destination docs -Recurse -Container

# 将 .\cultivation-between-realms\cultivation-between-realms 目录复制到项目根目录
Write-Host "将 .\think-about-it\think-about-it 目录复制到项目根的 docs 目录" -ForegroundColor Green
Copy-Item -Path .\think-about-it\think-about-it -Destination docs -Recurse -Container

# 将 .\fly-in-air\fly-in-air 目录复制到 docs 目录
Write-Host "将 .\fly-in-air\fly-in-air 目录复制到 docs 目录" -ForegroundColor Green
Copy-Item -Path .\fly-in-air\fly-in-air -Destination docs -Recurse -Container

# 将 .\walk-to-heart\walk-to-heart 目录复制到 docs 目录
Write-Host "将 .\walk-to-heart\walk-to-heart 目录复制到 docs 目录" -ForegroundColor Green
Copy-Item -Path .\walk-to-heart\walk-to-heart -Destination docs -Recurse -Container

# 将 .\code-on-farm\code-on-farm 目录复制到 docs 目录
Write-Host "将 .\code-on-farm\code-on-farm 目录复制到 docs 目录" -ForegroundColor Green
Copy-Item -Path .\code-on-farm\code-on-farm -Destination docs -Recurse -Container
