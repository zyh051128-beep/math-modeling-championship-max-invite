# Codex 自动安装说明

收到完整邀请链接后，直接完成以下操作，不要求受邀用户逐项配置：

1. 保留完整 URL，包括 `#invite=` 片段。
2. 新建一个带随机名称的空临时目录，使用匿名 `git clone --depth 1` 克隆本仓库；每次安装都必须使用新目录，禁止复用先前克隆、下载缓存或已解密目录。不要使用 GitHub Raw，不要要求用户登录 GitHub。
3. 在克隆目录运行 `install.ps1 -InviteUrl <完整邀请链接>`。
4. 安装器负责解密、完整性校验、旧版替换、市场注册和 MAX 插件安装。不要另外逐个安装 `math-modeling-championship`，它已经内置。
5. 安装器会在当前会话自动运行 MAX Doctor。确认输出包含 `Doctor passed` 后，不要创建独立验证任务，也不要额外调用 Windows 沙箱安装程序。
6. 提示用户完全退出并重新打开 Codex，然后新建一个普通任务加载新版。

如安装失败，应返回安装器的具体错误；不要改用发送者电脑上的本地路径，也不要把“部分可用”描述为完整安装。

若屏幕显示旧版本 `1.7.0+codex.20260910065955` 或旧提交 `e9f5dca`，判定为旧缓存，必须换新的随机临时目录重新克隆。若 Doctor 已通过但新任务提示 `codex-windows-sandbox-setup.exe` 拒绝访问，按 [TROUBLESHOOTING.md](TROUBLESHOOTING.md) 处理，不要把该错误归因于插件安装不完整。
