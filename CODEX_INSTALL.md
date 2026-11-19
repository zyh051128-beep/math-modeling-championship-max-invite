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
3. 重新打开 Codex 并新建对话，调用 `$math-modeling-championship-maxx`。新项目档案应为 `apmcm2025`，从随包规范和 Summary Sheet 开始。已有项目可根据其原有竞赛档案继续。
4. 需要核验本机文档后端时，在空项目使用英文合成材料执行随包 `publication_pipeline.py`，检查首页 Summary Sheet、第二页目录、各页队号和页码、单独的待签承诺书以及实际导出的 PDF。部署回执与实际论文审查分别记录。赛题交付时运行 `apmcm_submission.py`，填写必要的人工复核项目。

安装或导出遇到故障时，保留报错分类、插件版本和使用的 Office 后端，在当前对话继续修复。模型容量不足时可使用本机脚本完成确定性检查。[常见问题](TROUBLESHOOTING.md)
