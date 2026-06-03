import { createCipheriv, pbkdf2Sync, randomBytes } from "node:crypto";
import { promises as fs } from "node:fs";
import path from "node:path";

const publicDir = process.argv[2] || "public";
const password = process.env.BLOG_PASSWORD;
const encryptedPaths = parseEncryptedPaths(process.env.BLOG_ENCRYPT_PATHS);
const iterations = 210000;

if (!password) {
  console.error("BLOG_PASSWORD is required.");
  process.exit(1);
}

if (encryptedPaths.length === 0) {
  console.error("BLOG_ENCRYPT_PATHS must list generated HTML files to encrypt.");
  process.exit(1);
}

function parseEncryptedPaths(value) {
  return (value || "")
    .split(/[\n,]/)
    .map((item) => item.trim())
    .filter(Boolean);
}

function base64Url(buffer) {
  return Buffer.from(buffer).toString("base64url");
}

function encryptHtml(source) {
  const salt = randomBytes(16);
  const iv = randomBytes(12);
  const key = pbkdf2Sync(password, salt, iterations, 32, "sha256");
  const cipher = createCipheriv("aes-256-gcm", key, iv);
  const encrypted = Buffer.concat([cipher.update(source, "utf8"), cipher.final()]);
  const tag = cipher.getAuthTag();

  return renderUnlockPage({
    salt: base64Url(salt),
    iv: base64Url(iv),
    data: base64Url(encrypted),
    tag: base64Url(tag),
  });
}

function renderUnlockPage(payload) {
  const serializedPayload = JSON.stringify({ ...payload, iterations });

  return `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="robots" content="noindex, nofollow">
  <meta http-equiv="Cache-Control" content="no-store, no-cache, must-revalidate">
  <meta http-equiv="Pragma" content="no-cache">
  <meta http-equiv="Expires" content="0">
  <title>请输入密码</title>
  <style>
    :root {
      color-scheme: light dark;
      font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: #f4f1ea;
      color: #1f2933;
    }
    * {
      box-sizing: border-box;
    }
    body {
      min-height: 100vh;
      margin: 0;
      display: grid;
      place-items: center;
      padding: 24px;
    }
    main {
      width: min(100%, 360px);
    }
    h1 {
      margin: 0 0 18px;
      font-size: 24px;
      font-weight: 650;
      letter-spacing: 0;
    }
    form {
      display: grid;
      gap: 12px;
    }
    input,
    button {
      width: 100%;
      height: 44px;
      border-radius: 8px;
      font: inherit;
    }
    input {
      border: 1px solid #b7c0c9;
      padding: 0 12px;
      background: #ffffff;
      color: #111827;
    }
    button {
      border: 0;
      background: #243b53;
      color: #ffffff;
      cursor: pointer;
      font-weight: 600;
    }
    p {
      min-height: 20px;
      margin: 4px 0 0;
      color: #b42318;
      font-size: 14px;
    }
    @media (prefers-color-scheme: dark) {
      :root {
        background: #15191f;
        color: #eef2f6;
      }
      input {
        border-color: #52606d;
        background: #1f2933;
        color: #eef2f6;
      }
      button {
        background: #4f8cc9;
      }
    }
  </style>
</head>
<body>
  <main>
    <h1>请输入密码</h1>
    <form id="unlock-form">
      <input id="password" name="password" type="password" autocomplete="off" autofocus required>
      <button type="submit">打开</button>
      <p id="message" role="alert"></p>
    </form>
  </main>
  <script>
    const payload = ${serializedPayload};
    const form = document.getElementById("unlock-form");
    const input = document.getElementById("password");
    const message = document.getElementById("message");
    let unlockedFrame = null;

    window.addEventListener("pageshow", (event) => {
      if (event.persisted) {
        window.location.reload();
      }
    });

    window.addEventListener("pagehide", () => {
      if (unlockedFrame) {
        unlockedFrame.remove();
        unlockedFrame = null;
      }
      input.value = "";
    });

    function decodeBase64Url(value) {
      const base64 = value.replace(/-/g, "+").replace(/_/g, "/");
      const padded = base64 + "=".repeat((4 - base64.length % 4) % 4);
      const binary = atob(padded);
      const bytes = new Uint8Array(binary.length);
      for (let i = 0; i < binary.length; i += 1) {
        bytes[i] = binary.charCodeAt(i);
      }
      return bytes;
    }

    async function deriveKey(password) {
      const sourceKey = await crypto.subtle.importKey(
        "raw",
        new TextEncoder().encode(password),
        "PBKDF2",
        false,
        ["deriveKey"]
      );

      return crypto.subtle.deriveKey(
        {
          name: "PBKDF2",
          salt: decodeBase64Url(payload.salt),
          iterations: payload.iterations,
          hash: "SHA-256",
        },
        sourceKey,
        { name: "AES-GCM", length: 256 },
        false,
        ["decrypt"]
      );
    }

    async function unlock(password) {
      const key = await deriveKey(password);
      const encrypted = decodeBase64Url(payload.data);
      const tag = decodeBase64Url(payload.tag);
      const combined = new Uint8Array(encrypted.length + tag.length);
      combined.set(encrypted);
      combined.set(tag, encrypted.length);

      const decrypted = await crypto.subtle.decrypt(
        { name: "AES-GCM", iv: decodeBase64Url(payload.iv), tagLength: 128 },
        key,
        combined
      );

      return new TextDecoder().decode(decrypted);
    }

    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      message.textContent = "";

      try {
        const html = await unlock(input.value);
        input.value = "";
        document.body.replaceChildren();

        unlockedFrame = document.createElement("iframe");
        unlockedFrame.setAttribute("title", "protected content");
        unlockedFrame.style.position = "fixed";
        unlockedFrame.style.inset = "0";
        unlockedFrame.style.width = "100%";
        unlockedFrame.style.height = "100%";
        unlockedFrame.style.border = "0";
        unlockedFrame.srcdoc = html;
        document.body.appendChild(unlockedFrame);
      } catch {
        input.value = "";
        message.textContent = "密码错误";
      }
    });
  </script>
</body>
</html>
`;
}

async function walk(dir) {
  const entries = await fs.readdir(dir, { withFileTypes: true });
  const files = [];

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...await walk(fullPath));
    } else {
      files.push(fullPath);
    }
  }

  return files;
}

async function removeIfExists(file) {
  await fs.rm(file, { force: true });
}

const files = await walk(publicDir);
const htmlFiles = encryptedPaths.map((target) => path.join(publicDir, target));

for (const file of htmlFiles) {
  const original = await fs.readFile(file, "utf8");
  await fs.writeFile(file, encryptHtml(original), "utf8");
}

await Promise.all(
  files
    .filter((file) => file.endsWith(".xml") || file.endsWith(".json"))
    .map(removeIfExists)
);

console.log(`Encrypted ${htmlFiles.length} selected HTML file(s).`);
console.log("Removed generated XML/JSON indexes that could expose protected content.");
