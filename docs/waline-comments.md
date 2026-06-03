# Waline Comments

This site is wired for Waline comments through a local Stack theme override.

## What Was Added

- Global comment provider switched from `disqus` to `waline`
- Stable post slugs added so comment threads do not drift when titles change
- Non-blog pages keep comments disabled
- GitHub Pages build reads `HUGO_WALINE_SERVER_URL` from repository variables

## TODO

1. Deploy a Waline server.
2. Set the GitHub repository variable `HUGO_WALINE_SERVER_URL` to that deployed URL.
3. Redeploy the site so the URL is baked into the generated pages.
4. Open `https://<your-waline-server>/ui/register` once to create the first admin account.
5. Tighten anti-spam settings on the Waline server if you expose anonymous comments publicly.

## Local Preview

Preview with a live Waline server URL:

```bash
env HUGO_WALINE_SERVER_URL=https://your-waline-server.example.com \
  ~/.local/bin/hugo server --bind 127.0.0.1 --baseURL http://127.0.0.1:1313/ --port 1313 --disableFastRender
```
