# Codex 自动安装说明

2026-10-07 赛后修复：确认当前包含 `publication_pipeline.py`、`build_publication_fixture.py`，以及六类证据图的渲染/编辑入口。正文目标为60–70页（约65页）；该目标不用于短篇工具测试。先按下文安装，再实际验收原生Word、目录刷新、PDF导出、公式、三线表和绘图。不要把旧报告当作新版执行结果。

目录字体需检查字段刷新后的实际文字，最终PDF需逐页复核空白候选。可用 `build_publication_fixture.py --layout-stress` 创建全9级目录、长表和连续正文的合成压力样例；这是工具验收，不是比赛题解或质量认证。

收到完整邀请链接后，直接完成以下操作，不要求受邀用户逐项配置：

默认复制命令使用 `word` 交付配置打通主链（Python数值/绘图 + 可编辑Word + PDF导出），同时通过 `extended` 安装本插件定义的完整核心及扩展 Python 运行库。`word` 只选择本次交付环境检查范围，所有随包插件技能、程序及可选应用调用入口仍完整保留，不裁剪 LaTeX 功能。需要附加 LaTeX 时，先按 DEPENDENCIES.md 补齐并验证 TeX 等依赖，再把 `-Delivery word` / `--delivery word` 改为 `both`，重新检查两条交付路线；未安装可选 LaTeX 不应阻挡 Word/PDF 主链。在获得安装授权的当前任务内，Codex应代为定位或准备Git、官方Codex CLI、CPython3.11+、免费LibreOffice和合法中文字体；只有确需用户登录、管理员交互、许可或网络条件时才让用户接手。不能承诺这些外部条件随邀请码自动具备。

如果安装器指出原始ZIP路径含反斜杠，请不要修改安全校验或改用Windows绕过：从全新目录下载当前包，核对 `payload/SHA256.txt`，旧的失败载荷必须丢弃。每次安装保留仓库提交号、payload摘要、操作系统、插件版本与状态；这些信息可以安全反馈，邀请码不可出现在故障截图/日志中。

2.5 新增：默认完整演练稿正文目标约65页（60–70页，不采用比赛页数上限；摘要、目录、参考文献和附录不计入正文预算），默认目录覆盖实际使用的1–9级标题并用Word原生点引导线和页码。新增 `word_equations.py`、`equation_layout_audit.py`、`abstract_quality_audit.py`、`render_evidence_figures.py` 均随包安装，不需另装技能。目录字段先刷新回可编辑Word，再导出PDF；Windows自动PDF可用Word或LibreOffice，macOS/Linux自动PDF使用LibreOffice。

1. 确认当前消息正文里确实出现完整 URL，包括 `#invite=` 片段；不要只引用上一条消息或截图。发送者还会把同一邀请码单独列一行，链接片段在聊天软件中被截断时使用 `-InviteCode` 备用路线。
2. 每次安装都从默认分支新建浅克隆，确保拿到仓库当前最新版；禁止复用先前克隆、下载缓存或已解密目录。不要使用 GitHub Raw，也不要要求用户登录 GitHub。以下命令可直接复制（把尖括号占位内容替换成收到的完整值；邀请链接必须保留引号，避免 `#invite=` 被 shell 截断）。

   Windows PowerShell：

   ```powershell
   $maxxClone = Join-Path ([IO.Path]::GetTempPath()) ("maxx-invite-" + [guid]::NewGuid().ToString("N"))
   git -c credential.helper= -c core.autocrlf=false clone --depth 1 https://github.com/zyh051128-beep/math-modeling-championship-max-invite.git $maxxClone
   & (Join-Path $maxxClone "install.ps1") -InviteUrl '<完整邀请链接>' -SetupRuntime -RuntimeProfile extended -Delivery word
   ```

   macOS/Linux：

   ```sh
   maxx_clone="$(mktemp -d)/math-modeling-championship-max-invite"
   git -c credential.helper= -c core.autocrlf=false clone --depth 1 https://github.com/zyh051128-beep/math-modeling-championship-max-invite.git "$maxx_clone"
   "$maxx_clone/install.sh" --invite-url '<完整邀请链接>' --setup-runtime --runtime-profile extended --delivery word
   ```

3. 先阅读 [附加功能安装说明](DEPENDENCIES.md)，定位可运行的 CPython 3.11+（Windows排除 WindowsApps 商店占位程序）。上面的命令安装完整随包功能及 extended 运行库，并先验收 Word/PDF 主链，不代表所有可选外部应用已执行；若链接中的 `#invite=` 丢失，Windows把 `-InviteUrl '<完整邀请链接>'` 换成 `-InviteCode '<单独邀请码>'`，macOS/Linux把 `--invite-url '<完整邀请链接>'` 换成 `--invite-code '<单独邀请码>'`。Python不在PATH时，Windows可追加 `-PythonPath '<python.exe绝对路径>'`；macOS/Linux直接用真实解释器绝对路径替换 `<python>` 运行 `<python> "$maxx_clone/install.py" --invite-url '<完整邀请链接>' --setup-runtime --runtime-profile extended --delivery word`。Word仍为必交源稿；macOS/Linux的自动PDF导出使用LibreOffice路线，并分别实测Word/LibreOffice兼容性。
4. 安装器负责解密、完整性校验、旧版替换、市场注册和 MAXx 插件安装。不要另外逐个安装 `math-modeling-championship`，它已经内置。
5. `-SetupRuntime` 会在使用者目录的独立环境安装核心及扩展数值库，保留安装日志、版本和导入检查。它不修改全局 Python，也不安装商业软件或自动取得账号授权。安装器随后在当前会话运行 MAXx Doctor，保存 `installation-state.json` 与 `maxx-install-doctor.json`。
6. 只有实际安装回执 `installation-state.json` 中 `plugin_installed=true` 才证明插件已注册；不要只看退出码。安装器正常安装流程退出 `0` 表示所选交付路线环境就绪，退出 `2` 表示插件已装而环境未齐；但外层 `install.sh` 在启动前缺Python时也返回 `2`，此时尚未安装。按报告和 DEPENDENCIES.md 补齐，不反复重装。`-VerifyOnly` / `--verify-only` 只核验当前包，不执行安装或证明论文可交付。若Python不在PATH，可直接用真实解释器绝对路径运行 `install.py`。
7. 在实际选用的独立 Python 环境运行随包 `app_integration_smoke.py --output-dir <全新目录>`。对 DEPENDENCIES.md 中各功能族列出“已安装、已实跑、未执行/缺少、替代路线”表；真实调用和发现路径分别记录。随后按需核验 MATLAB、R、Graphviz、LaTeX 和 PDF 渲染，补装需使用的免费工具；商业许可与账号连接须由使用者自己提供。
8. 验证2.3图文专项：确认有 `render_flowcharts.py`、`presentation_audit.py` 和 `presentation-workflow.md`。按专项流程把渲染器和合成结构示例复制到全新测试项目，以 `--project-root` 生成总路线图及逐问步骤图的SVG/PDF/PNG并实际查看；中文缺字时按提示选用本机合法字体，不需要额外Graphviz。合成示例只验工具链，不当作实际赛题结论；真实论文仍须摘要证据映射和最终PDF专项审计。
9. 验证2.4新增链路：原生可编辑Word→真实排版器导出PDF→word_source_audit，中文命名总包，page_budget_audit，edit_figure_spec与algorithm_verification_audit。缺新增关键程序须重新安装；某个外部应用不可用时保留具体缺口。工具链五页示例不等于完整赛题论文，也不构成国奖篇幅标准。
10. 对 Wolfram、SciSpace，检查当前会话是否有可调用工具；没有时使用宿主实际提供的插件安装/连接入口，并清楚提示使用者完成其账号授权。不要复制邀请人的凭据。完成公开算例/公开方法文献查询后才标“已实跑”，仍需独立核对结果与原文。
11. 将安装状态表、报告路径和后续补齐动作交给使用者。不要创建独立验证任务；Windows不要额外调用沙箱安装程序。提示用户完全退出并重新打开 Codex，再新建一个普通任务加载新版。

如安装失败，应返回安装器的具体错误与对应补救；不要改用发送者电脑上的本地路径，也不要把“部分可用”描述为全部附加功能已运行。邀请码只用于本次安装命令，不写入公开仓库、报告或工单。附加功能安装说明始终保留在公开仓库，插件未解密成功也能读取。

若看到 `Selected model is at capacity`，按故障说明走“主任务接手、本机脚本回归”的路线，不再反复建立失败子任务。确认新版含 `capacity_fallback.py` 和 `capacity_fallback_test.py`，它们是无模型的工具链测试入口，不是论文审批、模型服务解限或远程自动升级功能。

若安装后缺少 `$math-modeling-championship-maxx` 或华为杯专项审计，判定为旧缓存，必须换新的随机临时目录重新克隆。若 Doctor 已通过但新任务提示 `codex-windows-sandbox-setup.exe` 拒绝访问，按 [TROUBLESHOOTING.md](TROUBLESHOOTING.md) 处理，不要把该错误归因于插件安装不完整。
