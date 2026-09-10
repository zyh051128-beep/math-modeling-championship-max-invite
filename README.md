# 数学建模竞赛超级套件 MAX｜邀请安装入口

本仓库只保存加密后的插件分发包，不包含可直接读取的插件源码。完整邀请链接末尾带有 `#invite=...`，邀请口令位于 URL 片段中，不会发送给 GitHub 服务器。

## 交给 Codex 安装

收到邀请链接后，把**完整链接**发送给 Codex，并说：

> 请按照此邀请链接安装“数学建模竞赛超级套件 MAX”，安装完成后新建任务验证插件。

Codex 应执行以下流程：

1. 从用户发送的完整 URL 中读取 `#invite=` 后的邀请口令。
2. 下载本仓库的 `install.ps1`。
3. 执行 `install.ps1 -InviteCode <邀请口令>`。
4. 安装成功后新建 Codex 任务，以便加载新版插件。

人工安装命令：

```powershell
$script = Join-Path $env:TEMP 'install-math-modeling-max.ps1'
Invoke-WebRequest 'https://raw.githubusercontent.com/zyh051128-beep/math-modeling-championship-max-invite/main/install.ps1' -OutFile $script
powershell -NoProfile -ExecutionPolicy Bypass -File $script -InviteCode '<填写邀请口令>'
```

## 权限说明

- 只有持有完整邀请链接的人能够解密并安装。
- 使用插件产生的模型和 Token 消耗归使用者自己的 Codex/ChatGPT 账户。
- 邀请人可发布新密钥和新加密包，使旧邀请链接不能安装后续版本。
- 已经下载、安装或复制的旧版本无法远程收回。

