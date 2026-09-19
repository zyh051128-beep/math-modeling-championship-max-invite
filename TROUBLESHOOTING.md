# 受邀安装故障处理

## 仍显示旧版本或旧提交

症状：界面仍只显示“MAX”，缺少 `$math-modeling-championship-maxx`、华为杯专项审计或内置基础套件。

原因：安装过程复用了旧克隆、旧下载缓存或旧解密目录。

处理：为本次安装创建新的随机临时目录，重新匿名克隆邀请仓库。Windows把完整邀请URL传给`install.ps1 -InviteUrl`；macOS/Linux传给`install.sh --invite-url`。若当前消息没有URL或`#invite=`被截断，使用发送者同条消息里的单独邀请码：Windows用`-InviteCode`，macOS/Linux用`--invite-code`。不要在旧目录直接重复运行。

## 当前消息或附件里没有邀请链接

症状：Codex明确报告当前消息、任务记录和附件中均没有URL。

原因：转发时只复制了安装说明，完整裸URL没有进入同一段可复制文本，或聊天软件截断了`#invite=`片段。

处理：请发送者在同一条纯文本消息中同时放入完整裸URL、公开仓库URL、单独邀请码和安装指令。收到方优先使用公共仓库URL配合单独邀请码，不依赖聊天软件保留URL片段。

## macOS提示不能运行Windows安装器

症状：设备为Apple Silicon或Intel macOS，无法执行`install.ps1`。

处理：从全新目录克隆仓库，执行`install.sh --invite-code '<邀请码>' --setup-runtime --runtime-profile extended --delivery both`。安装报告若列出LibreOffice、XeLaTeX、Pandoc、MATLAB或在线账号缺口，按`DEPENDENCIES.md`补齐后重新运行Doctor；插件文件安装成功与外部应用就绪分别记录。

## Windows 沙箱程序拒绝访问

症状：插件结果已经显示 `ready: true`、`blocking_failures: []`，但新建的验证任务报告 `codex-windows-sandbox-setup.exe` 被拒绝访问。

判断：这表示插件 MAXx Doctor 已通过，故障发生在 Codex 的 Windows 沙箱启动层，不代表插件缺失或安装失败。

处理顺序：

1. 保存当前工作并完全退出所有 Codex 窗口。
2. 重新打开 Codex，在普通新任务中调用 MAXx；不要创建额外的独立验证任务。
3. 若仍失败，检查 Windows 安全中心是否隔离或阻止了由官方 Codex 安装的沙箱组件，并使用 Codex 自带的更新、修复或重新安装入口恢复程序文件。
4. 不要关闭杀毒软件、不要关闭系统安全功能，也不要从非官方来源下载同名可执行文件。
5. 如果普通任务也无法启动，记录完整错误、Codex 版本和 Windows 安全中心事件后联系 Codex 支持；此时属于宿主环境故障，重复安装 MAXx 无法修复。
