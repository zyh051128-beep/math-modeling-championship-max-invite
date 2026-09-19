# 数模-MAXx｜邀请安装与更新入口

路径兼容修复：2026-09-19 已重建加密包，ZIP 原始条目名统一为 `/`。安装器检查 `orig_filename`，避免 Windows 自动转换路径掩盖 macOS/Linux 错误。如果此前收到“unsafe member path”或要求发布者重新打包，请从全新临时目录重新克隆，不复用旧下载；以 `payload/SHA256.txt` 区分载荷。公开 [跨平台测试记录](https://github.com/zyh051128-beep/math-modeling-championship-max-invite/actions/workflows/portable-release.yml) 会测试同一份加密包；仅绿色完成的运行可作为对应版本证据，不能把排队中或失败的测试称为通过。测试不公开解密产物。

本仓库只保存加密后的插件分发包，不包含可直接读取的插件源码。完整邀请链接末尾带有 `#invite=...`，邀请口令位于 URL 片段中，不会发送给 GitHub 服务器。为防聊天软件或任务转发丢失 URL 片段，发送者还会在同一条私信中单独列出同一邀请码；安装器支持 `-InviteCode` 备用输入，邀请码不进入本公开仓库。

当前邀请包保留稳定插件标识 `math-modeling-championship-max`，首选总控技能为 `math-modeling-championship-maxx`，并保留旧名称兼容入口；同时内置完整的基础套件及经许可审计、固定版本的图表、附件、引文、MATLAB 代码和结果一致性技能。构建时逐文件核验受邀版与所有者版的功能一致性；安装器验证加密载荷完整性，并检查 MAXx、华为杯审计、兼容入口和基础运行时等关键文件，缺失即停止安装。

## 最简单的使用方式

2.5深度更新：完整演练论文默认约60页（55–65页），加强论证、摘要两轮改写、代码证据组合图和Word→PDF公式检查。保留中文完整材料包、可编辑Word和全部源程序。不公开插件源码，不共享邀请人的账号与许可证。

2.4 强化中文命名完整材料包、原生可编辑 Word 与同源 PDF、实际范文页数预算、代码图表可编辑重绘，以及算法结果/基线/约束/重复运行验证。页数不是质量认证；未核实的范文获奖身份不会自动写成国奖。安装后需按说明实际验证 Word 导出，不能只发现应用就宣称全部就绪。

当前2.3版新增必需的全篇技术路线图、每问求解步骤图、摘要证据映射和PDF逐页呈现检查。图由随包代码生成，并提供可编辑结构、源码、SVG/PDF/高清PNG及运行回执；新门禁与既有数据、代码、图表和AI标注门禁共同执行。该功能使用已配置的核心Python依赖，不额外要求Graphviz或在线绘图账号。

受邀者把**完整邀请链接和单独邀请码以纯文本放在同一条消息中**发送给 Codex，并说：

> 请按仓库 CODEX_INSTALL.md 和 DEPENDENCIES.md 安装或更新“数模-MAXx”。先确认当前消息正文中确有完整 URL；若链接或 `#invite=` 缺失，使用同条消息中的单独邀请码。建立 extended 独立运行环境，以 both 路线检查 Word 与 LaTeX，补齐需要的绘图、排版、PDF 和文献功能，检查 Wolfram/SciSpace 等账号连接，运行 Doctor 与真实功能检查。逐项列出已实跑能力和待我完成的账号/许可证步骤，保存安装报告，最后提示我新建普通任务使用。不要逐个重复安装随包技能。

其余步骤由 Codex 完成。受邀者不需要登录 GitHub，不需要添加私人仓库权限，不需要逐个安装随包技能，也不需要手工配置插件市场。Windows使用`install.ps1`；macOS/Linux使用`install.sh`（调用标准Python安装器`install.py`）。每次安装或更新必须克隆到新的临时目录，禁止复用旧克隆或旧下载缓存。外部应用如 MATLAB、Word、R、LaTeX、Wolfram、SciSpace 及 Python 第三方库是否可用，仍取决于受邀者本机环境、账号连接与许可。Wolfram 用于公开/脱敏公式的可选交叉核验，SciSpace 用于可选文献发现与回源核验；其流程与离线整理程序随包提供，外部账号不会自动连接。插件会检测并标明 `NOT_RUN` 或替代路线，不虚报零配置、已执行或国奖质量。

## 交给 Codex 安装

完整附加功能清单、官方安装入口和验证方法见 [DEPENDENCIES.md](DEPENDENCIES.md)。插件运行环境可自动建立；外部应用与账号按这份清单补齐，逐项报告实际状态。

收到邀请链接后，把**完整链接**发送给 Codex，并说：

> 请按照此邀请链接安装或更新“数模-MAXx”，在当前任务运行内置 Doctor，完成后提示我新建普通任务使用新版。

Codex 应执行以下流程（不要使用 `raw.githubusercontent.com`，不要逐个安装关联技能）：

1. 从当前消息中的完整 URL 读取 `#invite=` 后的邀请码；若任务记录未包含 URL 或片段被截断，使用用户在同条消息中单独提供的邀请码。
2. 使用 `git clone --depth 1` 克隆本公开分发仓库。
3. 识别操作系统：Windows运行 `install.ps1 -InviteCode <邀请码> -SetupRuntime -RuntimeProfile extended -Delivery word`；macOS/Linux运行 `sh ./install.sh --invite-code '<邀请码>' --setup-runtime --runtime-profile extended --delivery word`。也可改用完整链接参数；只执行所选系统的一种路线，勿顺序执行所有备用命令。需要附加LaTeX时改为 `both`。安装器会识别和替换同一邀请市场的旧版本。
4. 安装器会建立隔离 Python 环境并运行 Doctor，保存安装与环境报告。以回执 `plugin_installed=true` 确认已安装；不能只看退出码 `2`，因为Mac启动脚本缺Python也用此码且尚未安装。按 DEPENDENCIES.md 补齐环境，不要反复重装或虚报全部就绪；不要再创建独立验证任务。
5. 安装成功后完全退出并重新打开 Codex，再新建一个普通任务加载新版插件。

已经安装过旧版的用户，使用发送者当前提供的完整邀请链接或单独邀请码执行上述流程，即可升级到邀请包中的最新版。邀请口令轮换后，旧链接不能解密新载荷。

人工安装命令：

```powershell
$folder = Join-Path $env:TEMP ('math-modeling-max-invite-' + [guid]::NewGuid().ToString('N'))
git clone --depth 1 https://github.com/zyh051128-beep/math-modeling-championship-max-invite.git $folder
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $folder 'install.ps1') -InviteUrl '<粘贴完整邀请链接>' -SetupRuntime -RuntimeProfile extended -Delivery both
# 若链接中的 #invite= 被聊天软件截断：
powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $folder 'install.ps1') -InviteCode '<粘贴单独邀请码>' -SetupRuntime -RuntimeProfile extended -Delivery both
```

macOS/Linux（Apple Silicon与Intel使用同一入口）：

```bash
folder="$(mktemp -d "${TMPDIR:-/tmp}/shumo-maxx-invite.XXXXXX")"
git clone --depth 1 https://github.com/zyh051128-beep/math-modeling-championship-max-invite.git "$folder"
"$folder/install.sh" --invite-code '<粘贴单独邀请码>' --setup-runtime --runtime-profile extended --delivery both
```

跨平台安装器只建立插件和隔离Python环境。macOS的DOCX自动导出需安装并实测LibreOffice；Microsoft Word for Mac可人工编辑和审阅DOCX，但当前自动导出器不调用Mac版Word。LaTeX、MATLAB及在线账号按`DEPENDENCIES.md`逐项准备和验证。

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
