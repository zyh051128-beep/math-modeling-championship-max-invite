# Codex 自动安装说明

收到完整邀请链接后，直接完成以下操作，不要求受邀用户逐项配置：

1. 保留完整 URL，包括 `#invite=` 片段。
2. 使用匿名 `git clone --depth 1` 克隆本仓库；不要使用 GitHub Raw，不要要求用户登录 GitHub。
3. 在克隆目录运行 `install.ps1 -InviteUrl <完整邀请链接>`。
4. 安装器负责解密、完整性校验、旧版替换、市场注册和 MAX 插件安装。不要另外逐个安装 `math-modeling-championship`，它已经内置。
5. 安装完成后运行 MAX Doctor，确认 `ready: true`、`base_suite.available: true`、`blocking_failures: []`，然后提示用户新建 Codex 任务加载新版。

如安装失败，应返回安装器的具体错误；不要改用发送者电脑上的本地路径，也不要把“部分可用”描述为完整安装。
