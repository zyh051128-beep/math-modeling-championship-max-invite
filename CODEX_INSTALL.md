# Codex 自动安装说明

收到完整邀请链接后，直接完成以下操作，不要求受邀用户逐项配置：

1. 保留完整 URL，包括 `#invite=` 片段。
2. 新建一个带随机名称的空临时目录，使用匿名 `git clone --depth 1` 克隆本仓库；每次安装都必须使用新目录，禁止复用先前克隆、下载缓存或已解密目录。不要使用 GitHub Raw，不要要求用户登录 GitHub。
3. 先阅读 [附加功能安装说明](DEPENDENCIES.md)，定位可运行的 Python（排除 WindowsApps 占位程序）。在克隆目录运行 `install.ps1 -InviteUrl <完整邀请链接> -SetupRuntime -RuntimeProfile extended -Delivery word`；已有明确 LaTeX 交付要求时把 `-Delivery` 改为 `latex` 或 `both`。需要时通过 `-PythonPath <真实解释器路径>` 指定 Python。
4. 安装器负责解密、完整性校验、旧版替换、市场注册和 MAXx 插件安装。不要另外逐个安装 `math-modeling-championship`，它已经内置。
5. `-SetupRuntime` 会在使用者目录的独立环境安装核心及扩展数值库，保留安装日志、版本和导入检查。它不修改全局 Python，也不安装商业软件或自动取得账号授权。安装器随后在当前会话运行 MAXx Doctor，保存 `installation-state.json` 与 `maxx-install-doctor.json`。
6. 退出码 `0` 表示所选交付路线环境就绪；`2` 表示插件已经装好但环境尚有缺口。按报告和 DEPENDENCIES.md 补齐 Word/LibreOffice、排版器等，不把缺环境当作插件没安装，也不要反复重装。`-VerifyOnly` 仅核验加密包和关键文件，不证明本机可完成论文。
7. 在实际选用的独立 Python 环境运行随包 `app_integration_smoke.py --output-dir <全新目录>`。对 DEPENDENCIES.md 中各功能族列出“已安装、已实跑、未执行/缺少、替代路线”表；真实调用和发现路径分别记录。随后按需核验 MATLAB、R、Graphviz、LaTeX 和 PDF 渲染，补装需使用的免费工具；商业许可与账号连接须由使用者自己提供。
8. 对 Wolfram、SciSpace，检查当前会话是否有可调用工具；没有时使用宿主实际提供的插件安装/连接入口，并清楚提示使用者完成其账号授权。不要复制邀请人的凭据。完成公开算例/公开方法文献查询后才标“已实跑”，仍需独立核对结果与原文。
9. 将安装状态表、报告路径和后续补齐动作交给使用者。不要创建独立验证任务或额外调用 Windows 沙箱安装程序；提示用户完全退出并重新打开 Codex，再新建一个普通任务加载新版。

如安装失败，应返回安装器的具体错误与对应补救；不要改用发送者电脑上的本地路径，也不要把“部分可用”描述为全部附加功能已运行。附加功能安装说明始终保留在公开仓库，插件未解密成功也能读取。

若安装后缺少 `$math-modeling-championship-maxx` 或华为杯专项审计，判定为旧缓存，必须换新的随机临时目录重新克隆。若 Doctor 已通过但新任务提示 `codex-windows-sandbox-setup.exe` 拒绝访问，按 [TROUBLESHOOTING.md](TROUBLESHOOTING.md) 处理，不要把该错误归因于插件安装不完整。
