# 数模-MAXx｜邀请安装与更新入口

本仓库只保存加密后的插件分发包，不包含可直接读取的插件源码。完整邀请链接末尾带有 `#invite=...`，邀请口令位于 URL 片段中，不会发送给 GitHub 服务器。

当前邀请包保留稳定插件标识 `math-modeling-championship-max`，首选总控技能为 `math-modeling-championship-maxx`，并保留旧名称兼容入口；同时内置完整的基础套件及经许可审计、固定版本的图表、附件、引文、MATLAB 代码和结果一致性技能。安装器会检查 MAXx、华为杯审计、兼容入口、基础运行时和受邀版与所有者版的功能文件一致性，缺少关键文件都会停止安装。

## 最简单的使用方式

受邀者只需把**完整邀请链接**发送给 Codex，并说：

> 请从这个完整邀请链接自动安装或更新“数模-MAXx”，完成后运行内置 Doctor 验证，并提示我新建任务。不要逐个安装相关技能。

其余步骤由 Codex 完成。受邀者不需要登录 GitHub，不需要添加私人仓库权限，不需要逐个安装随包技能，也不需要手工配置插件市场。每次安装或更新必须克隆到新的临时目录，禁止复用旧克隆或旧下载缓存。外部应用如 MATLAB、Word、R 或 LaTeX 及 Python 第三方库是否可用，仍取决于受邀者本机环境与许可；插件会检测并标明 `NOT_RUN` 或替代路线，不虚报零配置、已执行或国奖质量。

## 交给 Codex 安装

收到邀请链接后，把**完整链接**发送给 Codex，并说：

> 请按照此邀请链接安装“数模-MAXx”，安装完成后新建任务验证插件。

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

如果安装后仍只看到“MAX”而没有 `$math-modeling-championship-maxx`、华为杯专项审计和 MAXx Doctor，说明复用了旧缓存，并未取得当前邀请包。请删除本次临时克隆或直接换一个新的随机临时目录后重新克隆。

数模-MAXx 默认用于华为杯赛前演练：题目与附件直达可复算的解答论文、代码绘图、格式与代码审查、完整材料包，官方 AI 使用规定不阻断演练。2026 开赛公告与四份附件链接已发布；附件 DOCX 正文尚未逐项核验，不声称演练稿可直接提交。只有用户明确要求正式参赛辅助时才单独锁定当届规则。

完整演练材料包会逐文件计算哈希，并生成非程序 AI 内容的 JSON 台账、CSV 索引和可读标注表，逐节、逐图、逐表、逐公式/分析记录 AI 起源、采纳范围、人工修改和核验；程序 AI 参与另在使用台账中记录。正式论文图片须从真实数据通过源程序绘制，并保留运行证据；自动核验与人工二次复核分开报告。

若出现 `codex-windows-sandbox-setup.exe` 拒绝访问，但同时显示 `ready: true` 和 `blocking_failures: []`，这是 Codex 新任务的 Windows 沙箱启动故障，不是插件缺失。不要反复安装插件或降低系统安全设置；先完全退出 Codex 后重新打开，再新建普通任务。进一步处理见 [TROUBLESHOOTING.md](TROUBLESHOOTING.md)。

每次构建时，`build_invite.ps1` 必须接收所有者当前插件目录；它会丢弃旧的忽略构建缓存，从该目录重新生成邀请市场，再运行 `parity_gate.ps1`，逐文件确认受邀版与所有者版的有效功能文件完全一致；Python 缓存等运行残留不会进入包。每次发布后还必须运行 `release_gate.ps1`：它会从 GitHub 公开地址匿名克隆一个全新副本，核对加密包摘要，验证正确口令可以解密、错误口令必然被拒绝，并检查说明中未依赖 GitHub Raw 或发送者本机路径。任一门禁未通过时不得发送邀请链接。

## 权限说明

- 只有持有完整邀请链接的人能够解密并安装。
- 使用插件产生的模型和 Token 消耗归使用者自己的 Codex/ChatGPT 账户。
- 邀请人可发布新密钥和新加密包，使旧邀请链接不能安装后续版本。
- 已经下载、安装或复制的旧版本无法远程收回。
