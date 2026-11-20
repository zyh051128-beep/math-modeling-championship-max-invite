"use strict";

const main = document.querySelector("main");
const button = document.querySelector("#download");
const statusLine = document.querySelector("#status");

function statusText(text, error = false) {
  statusLine.textContent = text;
  statusLine.toggleAttribute("data-error", error);
}

function getKeyBytes() {
  const encoded = new URLSearchParams(location.hash.slice(1)).get("k") || "";
  if (!/^[A-Za-z0-9_-]{43}$/.test(encoded)) return null;
  const raw = atob(encoded.replace(/-/g, "+").replace(/_/g, "/") + "=");
  return Uint8Array.from(raw, char => char.charCodeAt(0));
}

function checkLink() {
  button.disabled = true;
  if (!window.isSecureContext || !window.crypto?.subtle) {
    statusText("请在支持 Web Crypto 的浏览器中，通过 HTTPS 打开完整分享链接。", true);
  } else if (!getKeyBytes()) {
    statusText("链接不完整。请从原消息复制整条链接，包括 #k= 后的字符。", true);
  } else {
    statusText("直接下载即可，无需输入邀请码。");
    button.disabled = false;
  }
}

window.addEventListener("hashchange", checkLink);
checkLink();

button.addEventListener("click", async () => {
  const keyBytes = getKeyBytes();
  if (!keyBytes) return checkLink();
  button.disabled = true;
  try {
    statusText("正在下载安装文件…");
    const reply = await fetch("./archive.bin", {credentials: "omit", referrerPolicy: "no-referrer"});
    if (!reply.ok) throw new Error("下载未完成，请检查网络后重试。");
    const encrypted = new Uint8Array(await reply.arrayBuffer());
    if (encrypted.length !== Number(main.dataset.size) + 28) {
      throw new Error("安装文件大小与发布记录不符，请重新打开分享链接。");
    }
    statusText("正在校验安装包…");
    const key = await crypto.subtle.importKey("raw", keyBytes, "AES-GCM", false, ["decrypt"]);
    const zip = await crypto.subtle.decrypt({name: "AES-GCM", iv: encrypted.slice(0, 12)},
                                            key, encrypted.subarray(12));
    const digest = Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256", zip)),
                              byte => byte.toString(16).padStart(2, "0")).join("");
    if (digest !== main.dataset.sha) throw new Error("安装包校验失败，请联系分享者。");
    const objectUrl = URL.createObjectURL(new Blob([zip], {type: "application/zip"}));
    const link = document.createElement("a");
    link.href = objectUrl;
    link.download = "MAXx-" + main.dataset.version + "-no-invite.zip";
    document.body.append(link);
    link.click();
    link.remove();
    setTimeout(() => URL.revokeObjectURL(objectUrl), 60_000);
    statusText("校验通过，已发起 ZIP 下载。打开下载目录后按下方步骤安装。");
  } catch (error) {
    statusText(error.name === "OperationError"
      ? "链接与安装文件不匹配，或文件已损坏。请重新复制完整分享链接。"
      : error.message || "下载失败，请重试。", true);
  } finally {
    button.disabled = !getKeyBytes();
  }
});
