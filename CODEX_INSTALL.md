# 在受邀者电脑上部署数模-MAXx

从受邀者在本次对话中提供的完整邀请 URL 或单独邀请码安装。将邀请仅用于本次安装，避免写入项目文件、安装报告和公开日志。每次安装或更新都克隆到新的临时目录，使用其中的安装器、加密包和校验文件。

## Windows

用受邀者提供的实际值替换占位符，执行 PowerShell 命令。

```powershell
$maxxClone = Join-Path ([IO.Path]::GetTempPath()) ('maxx-' + [guid]::NewGuid().ToString('N'))
git -c credential.helper= -c core.autocrlf=false clone --depth 1 https://github.com/zyh051128-beep/math-modeling-championship-max-invite.git $maxxClone
if ($LASTEXITCODE -ne 0) { throw '邀请仓库下载失败' }
& (Join-Path $maxxClone 'install.ps1') -InviteUrl '<完整邀请链接>' -SetupRuntime -RuntimeProfile extended -Delivery word
```

只有单独邀请码时，用 `-InviteCode '<邀请码>'` 替换 `-InviteUrl '<完整邀请链接>'`。可通过 `-PythonPath` 指定可运行的 CPython 3.11 或更新版本。若 Windows 提示当前脚本执行策略限制，使用单次进程运行 `powershell -NoProfile -ExecutionPolicy Bypass -File` 加安装脚本绝对路径及同一组参数。

## macOS 或 Linux

```sh
maxx_clone="$(mktemp -d)"
git -c credential.helper= -c core.autocrlf=false clone --depth 1 https://github.com/zyh051128-beep/math-modeling-championship-max-invite.git "$maxx_clone" &&
sh "$maxx_clone/install.sh" --invite-url '<完整邀请链接>' --setup-runtime --runtime-profile extended --delivery word
```

只有单独邀请码时改用 `--invite-code '<邀请码>'`。若系统找不到 CPython 3.11 或更新版本，可用该解释器的绝对路径运行克隆目录中的 `install.py` 和同一组参数。Apple Silicon 与 Intel Mac 共用此入口。macOS 和 Linux 自动导出 PDF 使用 LibreOffice。

## 验收并开始使用

1. 安装器核验加密包、邀请、插件文件及 APMCM 原件，再向 Codex 注册市场和插件。使用同一邀请市场时可更新旧安装。检查安装回执 `installation-state.json` 的 `plugin_installed`、版本及环境状态，并查看 Doctor 报告。单独执行 `--verify-only` 或 `-VerifyOnly` 只核验包。安装之后退出码 2 表示所选运行环境尚待补齐；shell 启动器找不到 Python 时也可能返回 2，须结合回执判断。
2. 按附加功能安装说明准备 Git、Codex CLI、CPython 和选用的 Office 后端。需要 LaTeX 时补齐 TeX 依赖并改用 `both` 验收。按题目需要实测绘图、外部程序或文献服务，记录已运行项目和缺失的授权。[附加功能安装说明](DEPENDENCIES.md)
3. 安装 2.7 或更新版本后，重新打开 Codex 并新建对话，调用 `$math-modeling-championship-maxx`。新建英文赛演练应使用 `apmcm2026`，历史项目可使用已记录的 `apmcm2025` 或华为杯档案。
4. 在空项目中用英文合成材料运行随包 `publication_pipeline.py`，省略 `format_profile`。检查回执中的 `format_profile` 为 `apmcm2026`，打开实际导出的 PDF，核对首页英文摘要、演练版第二页目录、每页页眉的完整队号和对应页码。输出还包括可编辑 Word 和单独的演练核对清单。正式承诺书随当届赛题发布。交付材料时运行 `apmcm_submission.py`，逐项填写人工复核结果。[2026 英文赛规则](https://www.apmcm.org/detail/2513)

安装或导出遇到故障时，保留报错分类、插件版本和使用的 Office 后端，在当前对话继续修复。模型容量不足时可使用本机脚本完成确定性检查。[常见问题](TROUBLESHOOTING.md)
