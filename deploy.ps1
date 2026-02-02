# 重新构建 Mkdocs 站点
Write-Host "重新构建 Mkdocs 站点" -ForegroundColor Cyan
.\build.ps1

# 部署 Mkdocs 站点
Write-Host "部署 Mkdocs 站点" -ForegroundColor Cyan
mkdocs gh-deploy --force