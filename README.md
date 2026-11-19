# 数模-MAXx 邀请安装与更新

数模-MAXx 2.6 起，新建项目默认采用 2025 APMCM 论文提交规范、英文论文模板和参赛规则。安装包包含原始提交规范、Word Summary Sheet、Control Sheet 和配套 LaTeX 模板。安装时逐文件核对模板摘要值。

## 接受邀请

将下面两行一起复制到自己的 Codex 私人对话中，把第二行替换为邀请人发来的完整链接。使用纯文本保留 `#invite=` 后的全部字符。若聊天软件截断链接，可在同一条私人消息中附上邀请人提供的单独邀请码。

```text
请用以下邀请安装或更新数模-MAXx。读取邀请仓库的 CODEX_INSTALL.md 和 DEPENDENCIES.md，按本机系统从最新版安装，建立 extended 运行环境，验证 Word/PDF 路线和 APMCM 模板，告诉我插件版本及实际验证结果。
<邀请人提供的完整 URL，含 #invite= 和完整邀请码>
```

Windows 和 MacBook 都从同一个邀请入口获取版本。已安装的受邀者可以用原邀请重新执行安装命令以获取新版本，前提是邀请人保留该邀请码。安装程序在受邀者的电脑上注册插件并创建独立 Python 环境。使用者自行提供 Codex 登录、可选在线服务授权和商业软件许可。请仅私下转发邀请，任何取得完整链接的人都可以解密该版本。

## 新建论文

安装后重新打开 Codex，在新对话中调用 `$math-modeling-championship-maxx`，提供题目和附件。定稿需要所选题号及完整队号。英文摘要优先安排在一页，目录从第二页开始。正文以 22–24 页作为写作目标，规范上限为 25 页，附录单列。参考文献和源程序按附件要求处理，支持材料按题目要求提供。承诺书须由参赛者签署。插件另外保存可编辑 Word、自查记录及本地材料包。

使用历史项目时按其已记录的竞赛档案继续；新建 APMCM 项目按本次规则执行。

## 安装与检查

Windows 使用 PowerShell 安装器，macOS/Linux 使用 shell 和 Python 安装器。自动导出 PDF 支持 Windows Word 或 LibreOffice；macOS/Linux 使用 LibreOffice。按当前发布提交查看各平台安装和文档导出结果。[安装步骤](CODEX_INSTALL.md) · [附加功能和依赖](DEPENDENCIES.md) · [常见问题](TROUBLESHOOTING.md) · [跨平台测试记录](https://github.com/zyh051128-beep/math-modeling-championship-max-invite/actions/workflows/portable-release.yml)
