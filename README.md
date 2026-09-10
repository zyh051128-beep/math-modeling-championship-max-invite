# 数学建模竞赛超级套件 MAX｜邀请安装与更新入口

本仓库只保存加密后的插件分发包，不包含可直接读取的插件源码。完整邀请链接末尾带有 `#invite=...`，邀请口令位于 URL 片段中，不会发送给 GitHub 服务器。

当前邀请包同时包含 `math-modeling-championship-max` 总控技能和完整的 `math-modeling-championship` 基础套件。安装器会在解密后检查两个技能入口、基础 Doctor 和状态管理程序，缺少任一关键文件都会停止安装。

## 最简单的使用方式

受邀者只需把**完整邀请链接**发送给 Codex，并说：

> 请从这个完整邀请链接自动安装或更新“数学建模竞赛超级套件 MAX”，完成后运行内置 Doctor 验证，并提示我新建任务。不要逐个安装相关技能。

其余步骤由 Codex 完成。受邀者不需要登录 GitHub，不需要添加私人仓库权限，不需要单独安装基础套件，也不需要手工配置插件市场。每次安装或更新必须克隆到新的临时目录，禁止复用旧克隆或旧下载缓存。

## 交给 Codex 安装

收到邀请链接后，把**完整链接**发送给 Codex，并说：

> 请按照此邀请链接安装“数学建模竞赛超级套件 MAX”，安装完成后新建任务验证插件。

Codex 应执行以下流程（不要使用 `raw.githubusercontent.com`，不要逐个安装关联技能）：

1. 从用户发送的完整 URL 中读取 `#invite=` 后的邀请口令。
2. 使用 `git clone --depth 1` 克隆本公开分发仓库。
3. 从克隆目录执行 `install.ps1 -InviteUrl <完整邀请链接>`。安装器会自动读取邀请码，并识别和替换同一邀请市场的旧版本。
4. 安装器会在当前会话自动运行 Doctor；不要再创建独立验证任务。
5. 安装成功后完全退出并重新打开 Codex，再新建一个普通任务加载新版插件。

已经安装过旧版的用户，重新把同一个完整邀请链接发给 Codex并执行上述流程，即可升级到邀请包中的最新版，无需邀请人再次审批。

人工安装命令：

```powershell
$folder = Join-Path $env:TEMP ('math-modeling-max-invite-' + [guid]::NewGuid().ToString('N'))
git clone --depth 1 https://github.com/zyh051128-beep/math-modeling-championship-max-invite.git $folder
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $folder 'install.ps1') -InviteUrl '<粘贴完整邀请链接>'
```

若 `git clone` 失败，应先检查能否打开本 GitHub 页面或更换网络；不要改用发送者电脑上的 `marketplacePath`。

如果结果仍显示版本 `1.7.0+codex.20260910065955` 或提交 `e9f5dca`，说明复用了旧缓存，并未取得当前邀请包。请删除本次临时克隆或直接换一个新的随机临时目录后重新克隆。

若出现 `codex-windows-sandbox-setup.exe` 拒绝访问，但同时显示 `ready: true` 和 `blocking_failures: []`，这是 Codex 新任务的 Windows 沙箱启动故障，不是插件缺失。不要反复安装插件或降低系统安全设置；先完全退出 Codex 后重新打开，再新建普通任务。进一步处理见 [TROUBLESHOOTING.md](TROUBLESHOOTING.md)。

每次构建时，`build_invite.ps1` 必须接收所有者当前插件目录并先运行 `parity_gate.ps1`，逐文件确认受邀版与所有者版的有效功能文件完全一致；Python 缓存等运行残留不会计入功能。每次发布后还必须运行 `release_gate.ps1`：它会从 GitHub 公开地址匿名克隆一个全新副本，核对加密包摘要，验证正确口令可以解密、错误口令必然被拒绝，并检查说明中未依赖 GitHub Raw 或发送者本机路径。任一门禁未通过时不得发送邀请链接。

## 权限说明

- 只有持有完整邀请链接的人能够解密并安装。
- 使用插件产生的模型和 Token 消耗归使用者自己的 Codex/ChatGPT 账户。
- 邀请人可发布新密钥和新加密包，使旧邀请链接不能安装后续版本。
- 已经下载、安装或复制的旧版本无法远程收回。
