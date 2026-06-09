# 本地构建说明

这个仓库使用 Hugo + Stack 主题构建，主题通过 Hugo Modules 引入，所以本地构建需要同时有：

- Hugo extended
- Go

为了避免每台机器都手动配置环境，仓库里提供了一个 PowerShell 脚本：

```powershell
scripts\build-local.ps1
```

它会自动把固定版本的工具下载到仓库根目录的 `.tools/` 下：

- Go `1.22.12`
- Hugo extended `0.160.1`

`.tools/` 已经加入 `.gitignore`，不会被提交到仓库。

## 正式构建

在仓库根目录运行：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build-local.ps1
```

第一次运行会下载 Go 和 Hugo，时间会久一点。

后续运行会直接复用 `.tools/` 里的工具。

构建成功后会生成：

```text
public/
resources/
.hugo_build.lock
```

这些都是 Hugo 构建产物，已经被 `.gitignore` 忽略，不需要提交。

## 指定 baseURL

默认构建使用 GitHub Pages 地址：

```text
https://b0weny-qwq.github.io/Blog/
```

如果需要临时指定其他地址，可以把地址作为第一个参数传进去：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build-local.ps1 "http://127.0.0.1:1313/"
```

## 本地预览

当前脚本主要用于正式构建验证，不负责启动 `hugo server`。

如果已经通过脚本下载过工具，可以直接用 `.tools/` 里的 Hugo 启动本地预览：

```powershell
.\.tools\hugo-0.160.1\hugo.exe server --bind 127.0.0.1 --baseURL http://127.0.0.1:1313/ --port 1313 --disableFastRender
```

然后打开：

```text
http://127.0.0.1:1313/
```

## 常见情况

如果构建时报类似下面的错误：

```text
icon 'xxx.svg' is not found under 'assets/icons' folder
```

说明某个页面或菜单配置里使用了主题不存在的图标。

当前 Stack 主题可用的常见图标包括：

```text
home
archives
search
link
user
tag
categories
rss
```

如果出现远程头像资源 warning，例如：

```text
WARN Unable to get remote resource "https://github.com/xxx.png"
```

一般不影响构建，只是某个远程图片暂时拉取失败。

## 提交前检查

提交前建议至少跑一次：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build-local.ps1
git status --short --ignored
```

确认只提交源文件，比如：

```text
content/post/...
content/page/...
docs/...
scripts/...
config/...
```

不要提交构建产物：

```text
public/
resources/
.tools/
.hugo_build.lock
```
