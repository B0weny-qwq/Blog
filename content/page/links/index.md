---
title: 友链
links:
  - title: GitHub
    description: GitHub is the world's largest software development platform.
    website: https://github.com
    image: https://github.githubassets.com/images/modules/logos_page/GitHub-Mark.png
menu:
    main: 
        weight: 4
        params:
            icon: link

comments: false
---

在 front matter 里配置 `links` 列表即可添加友链。

This page's frontmatter:

```yaml
links:
  - title: GitHub
    description: GitHub is the world's largest software development platform.
    website: https://github.com
    image: https://github.githubassets.com/images/modules/logos_page/GitHub-Mark.png
  - title: TypeScript
    description: TypeScript is a typed superset of JavaScript that compiles to plain JavaScript.
    website: https://www.typescriptlang.org
    image: ts-logo-128.jpg
```

`image` field accepts both local and external images.