# 数模-MAXx 邀请安装与更新

数模-MAXx 2.8 新建项目默认使用 2026 年第十六届 APMCM 英文赛规则。安装包收录当届规则、报名通知、AI 工具规定摘要和往届论文的逐页研读索引。写作和复审可按题目选择范例，回到 PDF 核对队号、证据、图表和出处。2025 英文赛模板继续供历史项目使用。[2026 竞赛规则](https://www.apmcm.org/detail/2513) · [2026 AI 工具规定](https://m.saikr.com/contest/notice_detail/50212)

## 接受邀请

将下面两行一起复制到自己的 Codex 私人对话中，把第二行替换为邀请人发来的完整链接。使用纯文本保留 `#invite=` 后的全部字符。若聊天软件截断链接，可在同一条私人消息中附上邀请人提供的单独邀请码。

```text
请用以下邀请安装或更新数模-MAXx。读取邀请仓库的 CODEX_INSTALL.md 和 DEPENDENCIES.md，按本机系统安装最新版并建立 extended 运行环境。验证 Word 转 PDF 和 2026 APMCM 英文赛演练格式，告诉我插件版本和实际验证结果。
<邀请人提供的完整 URL，含 #invite= 和完整邀请码>
```

Windows 和 MacBook 都从同一个邀请入口获取版本。已安装的受邀者可以用原邀请重新执行安装命令以获取新版本，前提是邀请人保留该邀请码。安装程序在受邀者的电脑上注册插件并创建独立 Python 环境。使用者自行提供 Codex 登录、可选在线服务授权和商业软件许可。请仅私下转发邀请，任何取得完整链接的人都可以解密该版本。

## 新建论文

安装后重新打开 Codex，在新对话中调用 `$math-modeling-championship-maxx`，提供题目、附件、题号和完整队号。2026 英文赛要求首页摘要概括方法和主要结论，每页标明队号和页码。演练版将摘要安排在一页、目录从第二页开始，正文目标为 22–24 页，演练上限为 25 页，附录单列。截至北京时间 2026 年 11 月 20 日，已核实的正式规则没有给出这一正文页数上限。[竞赛通知入口](https://m.saikr.com/vse/apmcm26)

官方承诺书随赛题发布，由全体成员签署并单独提交。在正式题包发布前，插件输出独立的演练核对清单。若使用 AI，按当届规定记录使用位置、工具和人工修改，另备使用详情 PDF。插件保存可编辑 Word、实际导出的 PDF 和本地材料包。2025 英文赛、2026 中文赛和华为杯项目分别按对应届次和赛项核对。

## 安装与检查

Windows 使用 PowerShell 安装器，macOS/Linux 使用 shell 和 Python 安装器。自动导出 PDF 支持 Windows Word 或 LibreOffice；macOS/Linux 使用 LibreOffice。按当前发布提交查看各平台安装和文档导出结果。[安装步骤](CODEX_INSTALL.md) · [附加功能和依赖](DEPENDENCIES.md) · [常见问题](TROUBLESHOOTING.md) · [跨平台测试记录](https://github.com/zyh051128-beep/math-modeling-championship-max-invite/actions/workflows/portable-release.yml)
