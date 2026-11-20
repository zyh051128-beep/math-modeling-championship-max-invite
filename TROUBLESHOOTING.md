# 受邀安装故障处理

## Mac 上的 LibreOffice 下载返回 404

先用 `uname -m` 确认处理器。从 LibreOffice 官网选择对应架构的安装包，Apple Silicon 选 aarch64，Intel 选 x86-64。若 Homebrew 使用已下架的下载地址，可从官方归档安装与本次发布测试相同的 26.2.5.2。下载后用 `shasum -a 256` 对照下载详情页的 SHA-256，打开 DMG，将 LibreOffice 拖入“应用程序”。使用 `/Applications/LibreOffice.app/Contents/MacOS/soffice --version` 验证，再运行论文导出。[Apple Silicon 下载详情](https://downloadarchive.documentfoundation.org/libreoffice/old/26.2.5.2/mac/aarch64/LibreOffice_26.2.5.2_MacOS_aarch64.dmg.mirrorlist) · [Intel 下载详情](https://downloadarchive.documentfoundation.org/libreoffice/old/26.2.5.2/mac/x86_64/LibreOffice_26.2.5.2_MacOS_x86-64.dmg.mirrorlist)

## 仍显示旧版本或旧提交

如果界面仍只显示“MAX”、找不到 `$math-modeling-championship-maxx`，或新建英文赛项目使用了旧规则，先检查安装回执的版本。2.6 默认使用 `apmcm2025`。用原邀请更新至 2.7 或更新版本并重启 Codex 后，在新目录启动项目，检查 `format_profile` 为 `apmcm2026`，并核对当届竞赛规则 PDF、报名通知 PDF 和 AI 规定摘要。已有项目沿用记录的年度和赛项。

原因：安装过程复用了旧克隆、旧下载缓存或旧解密目录。

处理：为本次安装创建新的随机临时目录，重新匿名克隆邀请仓库。Windows把完整邀请URL传给`install.ps1 -InviteUrl`；macOS/Linux传给`install.sh --invite-url`。若当前消息没有URL或`#invite=`被截断，使用发送者同条消息里的单独邀请码：Windows用`-InviteCode`，macOS/Linux用`--invite-code`。不要在旧目录直接重复运行。

## 当前消息或附件里没有邀请链接

症状：Codex明确报告当前消息、任务记录和附件中均没有URL。

原因：转发时只复制了安装说明，完整裸URL没有进入同一段可复制文本，或聊天软件截断了`#invite=`片段。

处理：请发送者在同一条纯文本消息中同时放入完整裸URL、公开仓库URL、单独邀请码和安装指令。收到方优先使用公共仓库URL配合单独邀请码，不依赖聊天软件保留URL片段。

## macOS提示不能运行Windows安装器

症状：设备为Apple Silicon或Intel macOS，无法执行`install.ps1`。

处理：从全新目录克隆仓库，执行`install.sh --invite-code '<邀请码>' --setup-runtime --runtime-profile extended --delivery both`。安装报告若列出LibreOffice、XeLaTeX、Pandoc、MATLAB或在线账号缺口，按`DEPENDENCIES.md`补齐后重新运行Doctor；插件文件安装成功与外部应用就绪分别记录。

## Selected model is at capacity

这是模型服务容量提示，不是插件压缩包或安装器程序。不要通过反复创建验证任务、切换安装器、降低文件校验或重复安装解决。当前主任务仍能工作时，停止重试失败子代理，直接运行本机工具链。新版随包 `capacity_fallback.py --output <插件目录外的新报告.json>` 可在不调用语言模型的情况下实跑全部仓库回归，结果与源码哈希绑定。

仓库回归不等于具体论文通过复审。题目的求解、摘要、逐页视觉复核及材料包审计仍按插件执行。若当前整个会话也不能工作，保留已完成阶段，使用宿主提供的其他可用模型继续；插件和本地脚本不能解除服务端容量限制。

## Windows 沙箱程序拒绝访问

症状：插件结果已经显示 `ready: true`、`blocking_failures: []`，但新建的验证任务报告 `codex-windows-sandbox-setup.exe` 被拒绝访问。

判断：这表示插件 MAXx Doctor 已通过，故障发生在 Codex 的 Windows 沙箱启动层，不代表插件缺失或安装失败。

处理顺序：

1. 保存当前工作并完全退出所有 Codex 窗口。
2. 重新打开 Codex，在普通新任务中调用 MAXx；不要创建额外的独立验证任务。
3. 若仍失败，检查 Windows 安全中心是否隔离或阻止了由官方 Codex 安装的沙箱组件，并使用 Codex 自带的更新、修复或重新安装入口恢复程序文件。
4. 不要关闭杀毒软件、不要关闭系统安全功能，也不要从非官方来源下载同名可执行文件。
5. 如果普通任务也无法启动，记录完整错误、Codex 版本和 Windows 安全中心事件后联系 Codex 支持；此时属于宿主环境故障，重复安装 MAXx 无法修复。
