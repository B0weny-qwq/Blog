# Hugo Post Compatibility Fixer

This repo expects each post to use Hugo page bundle layout:

```text
content/post/my-post/
  index.md
  cover.jpg
  demo.png
```

## What breaks Hugo

These patterns are the common sources of bad archive links, empty pages, or missing images:

- the article body is named `something.md` instead of `index.md`
- images are stored in `photo/` instead of next to `index.md`
- front matter is missing `title`, `date`, or `draft`

## One-command fix

Run this from the repo root:

```bash
bash scripts/fix-hugo-posts.sh
```

Preview only:

```bash
bash scripts/fix-hugo-posts.sh --check
```

## What the script does

For each folder under `content/post/`, the script will:

1. rename a single top-level markdown file to `index.md`
2. move files out of `photo/` into the post root
3. delete the empty `photo/` directory
4. add missing `title`, `date`, and `draft: false` front matter

## Limits

The script stays conservative.

- If a post folder contains multiple markdown files, it will warn and skip that folder.
- If a moved image would overwrite an existing file, it will warn and skip that file.
- If the folder name is not a date like `26.4.23` or `2026-04-23`, the script falls back to today's date.

## Recommended publish flow

```bash
bash scripts/fix-hugo-posts.sh
/home/boweny/.local/bin/hugo --gc --minify --baseURL https://b0weny-qwq.github.io/Blog/
git status
git add .
git commit -m "Update blog"
git push
```
