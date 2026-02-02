# 激活虚拟环境
.venv\Scripts\activate.ps1

# 构建 cultivation-between-realms 站点
Set-Location cultivation-between-realms
mkdocs build

# 构建 fly-in-air 站点
Set-Location ..\fly-in-air
mkdocs build

# 构建 walk-to-heart 站点
Set-Location ..\walk-to-heart
mkdocs build

# 构建 code-on-farm 站点
Set-Location ..\code-on-farm
mkdocs build

# 清空 site 目录（如果存在）
Set-Location ..
if (Test-Path site) {
    Remove-Item -Path site -Recurse -Force
}

# 将 .\cultivation-between-realms\site 目录复制到项目根目录
Copy-Item -Path .\cultivation-between-realms\site -Destination . -Recurse -Container

# 将 .\fly-in-air\fly-in-air 目录复制到 ..\site 目录
Copy-Item -Path .\fly-in-air\fly-in-air -Destination site -Recurse -Container

# 将 .\walk-to-heart\walk-to-heart 目录复制到 ..\site 目录
Copy-Item -Path .\walk-to-heart\walk-to-heart -Destination site -Recurse -Container

# 将 .\code-on-farm\code-on-farm 目录复制到 ..\site 目录
Copy-Item -Path .\code-on-farm\code-on-farm -Destination site -Recurse -Container