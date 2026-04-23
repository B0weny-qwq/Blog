# Blog

这是我的个人博客，使用 [Hugo](https://gohugo.io/) + [Stack 主题](https://github.com/CaiJimmy/hugo-theme-stack) 搭建，托管在 GitHub Pages。

访问地址：<https://b0weny-qwq.github.io/Blog/>

## 我应该怎么用

日常只需要记住这几个动作：

1. 写文章：在 `content/post/` 下面新建一个文件夹和 `index.md`
2. 放图片：文章图片放在文章自己的文件夹里，头像放在 `assets/img/`
3. 本地预览：运行 `hugo server`
4. 没问题后提交：`git add . && git commit -m "..."`
5. 推送到 GitHub：`git push`
6. GitHub Actions 会自动发布到 GitHub Pages

## 本地预览

进入项目目录：

```bash
cd ~/Blog
```

启动本地服务：

```bash
hugo server --bind 127.0.0.1 --baseURL http://127.0.0.1:1313/ --port 1313 --disableFastRender
```

然后打开：

<http://127.0.0.1:1313/>

如果提示 Hugo 版本太旧，使用本机安装的新版本：

```bash
~/.local/bin/hugo server --bind 127.0.0.1 --baseURL http://127.0.0.1:1313/ --port 1313 --disableFastRender
```

## 写一篇新文章

推荐每篇文章单独一个文件夹，文章正文叫 `index.md`，图片也放在同一个文件夹里。

例如写一篇 `my-first-post`：

```bash
mkdir -p content/post/my-first-post
cat > content/post/my-first-post/index.md <<'POST'
---
title: 我的第一篇文章
date: 2026-04-23
draft: false
categories:
  - 日常
tags:
  - Hugo
  - 博客
---

这里开始写正文。

可以直接写 Markdown。
POST
```

文章文件位置：

```text
content/post/my-first-post/index.md
```

写完后本地预览：

```bash
hugo server
```

## 文章开头的配置

每篇文章顶部 `---` 中间的内容叫 front matter。

常用字段：

```yaml
title: 文章标题
date: 2026-04-23
draft: false
categories:
  - 分类名
tags:
  - 标签1
  - 标签2
image: cover.jpg
```

说明：

- `title`：文章标题
- `date`：发布日期
- `draft: true`：草稿，本地能看，正式构建默认不发布
- `draft: false`：正式发布
- `categories`：分类
- `tags`：标签
- `image`：文章封面图，图片文件放在文章同目录

## 文章里放图片

把图片放到文章同目录，例如：

```text
content/post/my-first-post/index.md
content/post/my-first-post/cover.jpg
content/post/my-first-post/demo.png
```

正文里这样引用：

```markdown
![图片说明](demo.png)
```

如果想设置封面，在文章开头加：

```yaml
image: cover.jpg
```

## 换头像和 favicon

当前头像配置在 `config/_default/params.toml`：

```toml
[sidebar]
    avatar = "img/avatar.png"
```

当前头像文件是：

```text
assets/img/avatar.png
```

换头像最简单的方法：直接用你的图片覆盖这个文件。

```bash
cp /你的/图片/路径/avatar.png assets/img/avatar.png
```

要求：

- 文件名保持 `avatar.png` 最省事
- 建议用正方形图片，比如 `512x512` 或 `300x300`
- 图片太大也能用，但页面加载会慢，建议压到 1MB 以下

如果你的头像是 JPG，可以这样做：

```bash
cp /你的/图片/路径/avatar.jpg assets/img/avatar.jpg
```

然后改 `config/_default/params.toml`：

```toml
[sidebar]
    avatar = "img/avatar.jpg"
```

favicon 同理：

```text
assets/img/favicon.png
```

配置在 `config/_default/params.toml`：

```toml
favicon = "img/favicon.png"
```

## 修改博客信息

常改的配置文件都在 `config/_default/`。

| 想改什么 | 文件 |
| --- | --- |
| 网站标题、网址、语言 | `config/_default/config.toml` |
| 侧边栏头像、简介、页脚 | `config/_default/params.toml` |
| 菜单和社交链接 | `config/_default/menu.toml` 和 `content/page/` |
| 多语言标题 | `config/_default/languages.toml` |
| 文章链接格式 | `config/_default/permalinks.toml` |
| Hugo 模块主题 | `config/_default/module.toml` |

当前 GitHub Pages 地址配置在：

```toml
baseurl = "https://b0weny-qwq.github.io/Blog/"
```

不要随便改这个，除非仓库名或域名变了。

## 发布到 GitHub Pages

确认本地能构建：

```bash
hugo --gc --minify --baseURL https://b0weny-qwq.github.io/Blog/
```

提交修改：

```bash
git status
git add .
git commit -m "Update blog"
git push
```

推送后，GitHub Actions 会自动部署。

Actions 页面：

<https://github.com/B0weny-qwq/Blog/actions>

部署成功后访问：

<https://b0weny-qwq.github.io/Blog/>

## 常用命令速查

```bash
# 进入项目
cd ~/Blog

# 拉取 GitHub 最新内容
git pull

# 本地预览
hugo server

# 正式构建测试
hugo --gc --minify --baseURL https://b0weny-qwq.github.io/Blog/

# 查看改了什么
git status

# 提交并推送
git add .
git commit -m "Update blog"
git push
```

## 目录结构

```text
content/post/        # 文章
content/page/        # 固定页面，比如归档、搜索、友链
assets/img/          # 头像、favicon 等资源
assets/scss/         # 自定义样式
config/_default/     # Hugo 和主题配置
.github/workflows/   # GitHub Actions 自动部署
public/              # 本地构建产物，不需要手动编辑
```

## 注意事项

- 不要手动改 `public/` 里的文件，它是 Hugo 自动生成的。
- 写文章主要改 `content/post/`。
- 改头像、简介、页脚主要看 `config/_default/params.toml`。
- 改菜单主要看 `content/_index.md` 和 `content/page/`。
- 如果 GitHub Pages 没更新，先去 Actions 页面看是否部署成功。
- 如果 `hugo server` 报版本问题，使用 `~/.local/bin/hugo`。

## 主题更新

这个博客通过 Hugo Module 使用 Stack 主题。一般不用手动更新。

如果以后想更新主题：

```bash
hugo mod get -u github.com/CaiJimmy/hugo-theme-stack/v4
hugo mod tidy
```

更新后先本地构建确认没问题，再提交推送。
