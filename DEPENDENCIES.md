# 数模-MAXx：受邀者安装与完整能力接通说明

适用：受邀者自己的 Codex、电脑和账号；默认华为杯赛前演练。核对日期：2026-09-18。

完整邀请包包含 MAXx 总控、基础建模流程、随包技能、审计程序、模板和本说明。Python 库、Word/LibreOffice、LaTeX、MATLAB 等程序，以及 Wolfram、SciSpace 的账号连接需在接收者环境准备。下表把每个能力家族对应到实际运行条件；没有选用的专业应用不会阻断基础流程，但不能把其状态写成“已全部验证”。

## 1. 发给受邀者的完整指令

把收到的**完整邀请链接（保留末尾 `#invite=...`）**与以下文字一起发给 Codex：

> 请用这个完整邀请链接安装或更新“数模-MAXx”。从邀请仓库全新克隆，按仓库安装说明启用 SetupRuntime、extended 环境和 word 交付配置。使用我本机的真实 Python，准备独立环境，保留安装与依赖检查回执。读取插件内 external-installation.md，检查下表的全部能力家族：配置基础数值、建模、代码绘图、文档/PDF 和审计功能；按题型准备可选应用，并在宿主实际支持的插件搜索/连接流程中检查 Wolfram 和 SciSpace。对需要我完成的登录、授权或许可证操作给出准确入口；连接完成后用公开合成示例验证。运行 Doctor、集成冒烟检查，并分别报告已通过、采用替代路线、待连接、未实测和失败项，不把“找到安装路径”当作“可执行”。保留外部功能安装说明和后续修复命令；完成后提示我重启 Codex 并新建任务加载新版。

安装入口以[邀请仓库说明](https://github.com/zyh051128-beep/math-modeling-championship-max-invite)为准。现有用户也用同一完整链接重新安装；无需访问所有者私有仓库。不要使用发件人电脑上的 `marketplacePath` 或 Python 绝对路径。

Windows 手工执行时，先安装 [Git](https://git-scm.com/downloads/) 并确认 `git --version` 成功。邀请安装器还要求当前 PowerShell 能通过 `Get-Command codex` 找到官方 Codex CLI，并成功执行下面两项预检；桌面程序能打开不证明 CLI 已加入当前 PATH。

```powershell
if (-not (Get-Command codex -ErrorAction SilentlyContinue)) { throw 'NOT_READY: 当前终端找不到 Codex CLI，请先完成官方 CLI 定位或安装。' }
codex --version
if ($LASTEXITCODE -ne 0) { throw 'NOT_READY: Codex CLI 不能运行。' }
codex plugin --help
if ($LASTEXITCODE -ne 0) { throw 'NOT_READY: 当前 Codex CLI 不支持邀请安装器所需的 plugin 命令。' }
```

若缺失 CLI，先让 Codex 定位宿主附带的官方 CLI；宿主没有可用 CLI 时，按 [Codex CLI 官方文档](https://developers.openai.com/codex/cli/)选择当前平台的安装方法。更新当前终端 PATH 或重新打开终端后再次预检；未通过应保留 `NOT_READY`，不要继续宣告插件安装成功。随后在 PowerShell 使用全新目录：

```powershell
$maxxDownload = Join-Path $env:TEMP ('shumo-maxx-invite-' + [guid]::NewGuid().ToString('N'))
git clone --depth 1 https://github.com/zyh051128-beep/math-modeling-championship-max-invite.git $maxxDownload
if ($LASTEXITCODE -ne 0) { throw '邀请仓库下载失败，请修复网络后重试。' }
& (Join-Path $maxxDownload 'install.ps1') -InviteUrl '<粘贴完整邀请链接>' -SetupRuntime -RuntimeProfile extended -Delivery word
```

如 PowerShell 的执行策略阻止脚本，交给 Codex 按当前设备/组织策略处理；不要关闭系统安全功能。安装器是 Windows 路线。macOS/Linux 用户须由 Codex 根据当前宿主支持的插件安装方式完成安装，不能把 Windows 安装器已验证当作跨平台验证。

## 2. 基础环境与 Python 库

已存在的 Codex 工作区解释器可继续使用；本版环境引导要求真实的 CPython 3.11 或以上。没有可用解释器时，从 [Python 官方下载页](https://www.python.org/downloads/)安装 64 位 Python。优先选有目标包二进制轮子支持的版本；版本由实际依赖解析与运行测试决定，不以“最新”代替兼容性验证。Windows 的 `WindowsApps` 商店别名不等于可用解释器。

插件 `scripts/bootstrap_runtime.py` 负责创建独立 `venv`，核心包和扩展包分别按 `--profile core`、`--profile extended` 安装。它只接受 PyPI 二进制轮子；缺少兼容轮子时保留失败原因，改用支持的解释器或该应用的官方专用安装方式，不在后台悄悄编译任意源代码。`--dry-run` 仅预览。此工具的目标是隔离运行依赖，不安装桌面应用，也不连接在线账号。

```powershell
# 将两个占位路径替换为本机实际值；MAXx技能目录中应能看到 SKILL.md 和 scripts。
& '<真实Python绝对路径>' '<MAXx技能目录>\scripts\bootstrap_runtime.py' --profile extended --dry-run
& '<真实Python绝对路径>' '<MAXx技能目录>\scripts\bootstrap_runtime.py' --profile extended
```

默认运行环境根目录为 Windows `%LOCALAPPDATA%\ShumoMAXx\runtime`；非 Windows 为 `$XDG_DATA_HOME/shumo-maxx/runtime` 或 `~/.local/share/shumo-maxx/runtime`。也可用 `--runtime-root <专用目录>` 指定。**以脚本返回的解释器路径为准**，之后所有安装、检查与模型计算都使用同一个解释器。不要移动或分发已经建成的 `venv`；换电脑重新创建环境。参见 [Python venv](https://docs.python.org/3/library/venv.html)与 [PyPA 安装指南](https://packaging.python.org/en/latest/tutorials/installing-packages/)。

| 环境组 | 随安装引导准备的包 | 支持的功能 |
|---|---|---|
| `core`（15 个直接依赖） | NumPy、pandas、SciPy、scikit-learn、Matplotlib、Seaborn、Pillow、openpyxl、python-docx、lxml、pypdf、PyMuPDF、SymPy、Requests、rarfile | 数据处理、统计/机器学习基线、优化、源程序绘图、XLSX、DOCX构造、PDF读取/渲染、符号复核、引文HTTP访问及RAR成员清单 |
| `extended`（共 23 个直接依赖） | 包含 core，另加 statsmodels、NetworkX、SimPy、pymoo、OR-Tools、Plotly、SciencePlots、xlrd | 统计模型、网络、离散事件仿真、多目标/离散优化、交互图、学术绘图样式及旧XLS输入 |
| 题型专用 | 见下表；不批量强制安装 | 只在题目确实需要时启用，运行后记录版本与许可证/资源条件 |

基础包的官方安装资料：[NumPy](https://numpy.org/install/)、[pandas](https://pandas.pydata.org/docs/getting_started/install.html)、[SciPy](https://scipy.org/install/)、[scikit-learn](https://scikit-learn.org/stable/install.html)、[Matplotlib](https://matplotlib.org/stable/install/index.html)、[Seaborn](https://seaborn.pydata.org/installing.html)、[python-docx](https://python-docx.readthedocs.io/en/latest/user/install.html)、[openpyxl](https://openpyxl.readthedocs.io/en/stable/tutorial.html)、[pypdf](https://pypdf.readthedocs.io/en/stable/user/installation.html)、[PyMuPDF](https://pymupdf.readthedocs.io/en/latest/installation.html)。

安装后使用该环境解释器运行 `-m pip check`；再执行本文第 6 节的实际调用测试。仅 `pip check` 通过不代表扩展模块、系统动态库和渲染程序已经可用。每个题目交付包应保存实跑后的确切依赖版本，不能仅用本说明中的包名重建多年后的环境。

随包 Python 脚本的模块级、函数内及常量动态导入已纳入依赖回归检查；Doctor 的动态 XLS 探测由 extended 中的 `xlrd` 覆盖。引文技能的 DOI、元数据、OpenAlex、PubMed 和引用检查脚本使用 [Requests](https://requests.readthedocs.io/en/latest/user/install/)，现由 core 提供；网络服务仍需实际连接验证。PDF 的旧 `PyPDF2` 导入仅为兼容回退，主路线已提供 `pypdf`；`fitz` 由 PyMuPDF 提供，**不要另装同名 `fitz` 包**。RAR 清单可由 core 的 [rarfile](https://github.com/markokr/rarfile)读取；压缩成员解压还可能需要官方外部后端，见第 5 节。所有直接依赖及版本范围以 `runtime-profiles.json` 为准，传递依赖的确切版本保存在安装冻结清单。

## 3. 全部已登记能力家族的接通关系

安装后，在MAXx技能目录的 `references/` 中查看完整机器可读清单 `capability-integration-registry.json` 和调用/证据规则 `application-routing.md`。其中的“可选技能名”是附加工作指导，不是必须逐个安装的程序。全部核心行为已有随包流程或独立实现的回退；许可不明的第三方技能不进入邀请包。本说明也可在解密前公开阅读；这里提到的插件内文件会在安装时取得。

| 能力家族 | 本插件已有功能 | 额外准备与缺失时路线 | 验证重点 |
|---|---|---|---|
| 流程与状态 | X0–X11、阶段检查、断点续作、哈希、双份交付 | Codex + Python + Git；无需另装 CrewAI 或独立多智能体框架 | 阶段文件可重读，失败不会被标为通过 |
| 文档与交付 | 模板契约、公式/编号要求、论文与材料包审计 | Word/LibreOffice 路线或 XeLaTeX+Pandoc 路线；选定的一条必须具备真实渲染器 | DOCX/PDF实开、中文字体、公式、逐页检查 |
| 数据与表格 | 附件清单、来源哈希、清洗和单位检查 | core 支持 CSV/XLSX；extended 增加 xlrd 处理旧 XLS；大数据才加 Polars/Dask | 小样本读写、类型/单位/缺失值及输入哈希 |
| 检索与引文 | 引文技能、离线整理、论点—来源台账、SciSpace回包整理 | SciSpace由接收者自己连接；文献回退为出版方/DOI/作者库或用户提供原文 | 真实元数据、版本、已读原文页节；未读条目保留未核验 |
| 统计、学习与不确定性 | 基线、数据划分、防泄漏、敏感性及校准要求 | core+extended覆盖常见模型；SHAP/PyMC/TimesFM按题型；可回退可解释基线和重采样 | 留出数据、边界、置信/预测区间含义、独立复算 |
| 优化、仿真与符号 | 目标方向、约束回代、可行性、边界检查 | SciPy/SymPy + extended；MATLAB/Octave/Wolfram为可选路线 | 已知小问题、约束残差、随机种子、独立算法对照 |
| 可复算可视化 | 两个随包绘图技能、源数据/源代码/运行回执要求 | Matplotlib/Seaborn为本地默认；Graphviz、Plotly/Kaleido、R、MATLAB可选 | PNG/PDF/SVG真实导出、字体、配色、页内可读性 |
| 代码审查与复现 | MATLAB代码审查指导、一致性审计、静态检查、重跑清单 | 对实际语言准备解释器/许可证；静态审查本身不等于代码已运行 | 干净目录重跑、错误路径、数值测试、结果哈希 |
| 学术写作与复核 | 论点证据契约、摘要要求、术语锁、双轮复核记录 | 由受邀者的 Codex 模型执行，无额外写作服务硬依赖 | 数字与图表一致、来源完整、AI内容台账、人工复核状态 |
| 专业题型 | 按题意加载、一般数值建模路线 | NetworkX/GeoPandas/Astropy/FluidSim/OpenPIV按需；专业方法不能用无关基线冒充 | 专业数据、坐标/单位、已知解或标准样例；缺专业条件保留缺口 |

## 4. 桌面应用、转换器与在线连接

“论文能生成”与“论文能正确渲染”是两项检查。Windows 推荐先具备 Word 或 LibreOffice；需要 LaTeX 交付再添加 MiKTeX/TeX Live 和 Pandoc。应用安装后重新打开终端/Codex，使新增 PATH 生效；也可在运行记录中保留程序的实际绝对路径。

| 应用/功能 | 安装与配置 | 最小验证与替代路线 |
|---|---|---|
| Word | 按 [Microsoft 官方说明](https://support.microsoft.com/en-us/office/lifecycle/officeinstall/download-install-or-reinstall-microsoft-365-or-office-2024-on-a-pc-or-mac)安装并用受邀者自己的许可激活 | 打开含中文、公式、表格、图片的测试DOCX并导出PDF；没有许可可选LibreOffice |
| LibreOffice | 从[官方页面](https://www.libreoffice.org/download/)安装；确认 `soffice` 可定位，Windows通常需定位安装目录下 `program/soffice.exe` | `soffice --version` 后实际转换测试DOCX；[转换参数说明](https://help.libreoffice.org/latest/en-US/text/shared/guide/start_parameters.html)。逐页核对公式、换行与字体，不假定与Word完全等价 |
| MiKTeX / TeX Live | Windows按 [MiKTeX](https://miktex.org/howto/install-miktex)或 [TeX Live](https://tug.org/texlive/acquire-netinstall.html)官方流程二选一；准备XeLaTeX、中文模板所需包和字体 | `xelatex --version` 后编译真实模板测试页；无此路线可选Word/LibreOffice，但不能交付声称已编译的LaTeX论文 |
| Pandoc | 按[官方安装说明](https://pandoc.org/installing.html)安装 | `pandoc --version` 后转换小样本并检查公式；Pandoc本身不提供所有PDF引擎，LaTeX路线另需XeLaTeX |
| PDF读取与渲染 | core提供pypdf/PyMuPDF；[Poppler上游](https://poppler.freedesktop.org/)作为可选工具，系统发行版/包管理器安装时同时保留其数据资源 | PDF页数与文本抽取，加逐页渲染；若Poppler出现`nameToUnicode`、资源错误或错误文件大小，停止采用其结果，改用已测试的PyMuPDF/pypdf |
| Graphviz | 按[官方平台安装页](https://graphviz.org/download/)安装真正的`dot`程序；仅安装同名Python包装库不够 | `dot -V` 后将小型`.dot`源文件导出SVG/PDF；否则用有源代码的Matplotlib关系示意图 |
| R | 从 [CRAN](https://cran.r-project.org/)选择平台安装；Windows入口为[官方Windows包](https://cran.r-project.org/bin/windows/base/)；题型包在项目中按需安装 | `Rscript --version`，再运行 `Rscript -e 'stopifnot(sum(c(1,2,3)) == 6); sessionInfo()'`；数值与绘图小样本均需实跑。可回退Python |
| MATLAB | 按 [MathWorks官方流程](https://www.mathworks.com/help/install/ug/install-products-with-internet-connection.html)安装并使用本人的学校/个人许可，按方法选工具箱 | `matlab -batch "disp(version); assert(abs(sqrt(4)-2)<1e-12); ver"`；另实测所用工具箱函数。找得到MATLAB路径不证明许可和工具箱可用 |
| MATLAB Engine | 只有需要Python调用MATLAB时才安装。先核对[Python兼容表](https://www.mathworks.com/support/requirements/python-compatibility.html)，再按[Engine官方说明](https://www.mathworks.com/help/matlab/matlab_external/install-the-matlab-engine-for-python.html)选择与本机MATLAB版本对应的Engine；必要时使用单独环境 | 实际 `import matlab.engine`、启动引擎、计算已知结果并退出。不能盲装最新Engine；Engine包、MATLAB Runtime均不等于完整可用MATLAB |
| GNU Octave | 从[官方平台下载页](https://octave.org/download)安装 | `octave --version` 后 `octave --no-gui --quiet --eval "assert(abs(sqrt(4)-2)<1e-12); disp(version)"`；必须再测试题目代码。专有工具箱、语法和图形行为不保证与MATLAB一致 |
| Wolfram连接 | 在**受邀者的当前Codex**请求查找Wolfram插件；使用宿主实际返回的安装/连接提示，完成本人账号和工作区授权。网站登录不等于Codex连接 | 用公开精确表达式做一次真实求解，再用本地SymPy/SciPy比对；具体流程在插件内 `references/wolfram-crosscheck.md`。未连接时本地符号/数值路线仍可执行 |
| SciSpace连接 | 在**受邀者的当前Codex**请求查找SciSpace插件，按实际安装/连接提示操作；不假定付费全文、额度或账号随邀请转移 | 用公开主题实际检索，保存回包并对一条候选回源核验；具体流程在插件内 `references/scispace-evidence.md`。失败时用出版方/DOI/作者库检索，已下载原文可离线整理 |

Wolfram与SciSpace没有在本插件中嵌入共享账号、API密钥或第三方订阅。受邀者可直接告诉Codex：“请检查我这里的Wolfram和SciSpace连接；若未连接，请显示当前宿主实际支持的安装/连接入口，连接后分别运行公开小样例。” 若地区、账号或工作区策略不提供某项服务，应报告“当前不可用”和本地替代能力，不能虚构连接入口。服务官方网站仅用于了解产品：[Wolfram|Alpha](https://www.wolframalpha.com/)、[SciSpace](https://scispace.com/)；它们不是本插件的账号授权按钮。

## 5. 题型专用与绘图增强组件

以下是在已经选定方法之后的安装清单。代码中的 `PYTHON` 表示实际项目环境解释器，不能直接将该单词作为命令。通用形式为 `PYTHON -m pip install 包名`；安装后至少运行“导入 + 官方最小样例 + 本题代表性样例”，并记录确切版本。专业组件依赖与core冲突时另建题目专用环境，保持基础环境可运行。

| 场景 | 官方来源与安装包 | 验证及缺失处理 |
|---|---|---|
| 旧Excel | extended 已含 `xlrd`；core 用户遇到`.xls`时可重跑 extended，XLSX继续用openpyxl | 读一份已知内容的XLS，核对行列数、日期和缺失值；可要求提供CSV/XLSX副本并保留原件 |
| RAR/7z附件 | core含[rarfile](https://github.com/markokr/rarfile)用于RAR成员清单；需要解压压缩成员时按其文档准备官方 [UnRAR](https://www.rarlab.com/rar_add.htm) 或 [7-Zip](https://www.7-zip.org/)；7z清单/解压需另验证外部工具 | 先列目录并审查路径，再解压到新目录；加密或不支持的压缩类型保留缺口。只安装rarfile不能证明外部解压后端可用；可由用户提供保留原件的ZIP/已解压副本 |
| Google Scholar附加检索 | 随包 `search_google_scholar.py` 可选依赖[scholarly官方安装说明](https://scholarly.readthedocs.io/en/stable/quickstart.html)中的 `scholarly`，不在core/extended；只在确需该抓取路线时由Codex在独立环境按当前官方依赖准备 | 先导入检查，再用公开查询实调；不启用`--use-proxy`或公共代理。被拦截、缺模块或无返回时保留未运行/失败，使用已连接SciSpace或Requests支持的OpenAlex/PubMed/DOI路线 |
| 专项色觉/色空间分析 | 当前随包脚本没有 `colorspacious` 导入；需要专项分析时才按[上游项目](https://github.com/njsmith/colorspacious)在项目环境安装 `colorspacious`，不属于默认依赖 | 用已知颜色做转换/回转数值检查并实际查看图。默认绘图和审查可使用Matplotlib配色、线型/点型及灰度核查；不能将未运行的色觉模拟标为通过 |
| 更大表格 | [Polars](https://docs.pola.rs/user-guide/installation/)：`polars`；[Dask](https://docs.dask.org/en/stable/install.html)：`dask[dataframe]` | 用相同小表与pandas对照；资源允许时回退pandas分块处理 |
| 统计/解释/贝叶斯 | [statsmodels](https://www.statsmodels.org/stable/install.html)：已在extended；[SHAP](https://shap.readthedocs.io/en/latest/)：`shap`；[PyMC](https://www.pymc.io/projects/docs/en/stable/installation.html)：按官方当前平台指导安装 | 回归系数与已知例子一致；SHAP解释同一已训练模型；PyMC检查采样诊断。可用基线、重采样或敏感性分析，但需说明推断方法改变 |
| 多目标/离散优化及仿真 | [pymoo](https://www.pymoo.org/installation.html)、[OR-Tools](https://developers.google.com/optimization/install/python)、[SimPy](https://simpy.readthedocs.io/en/latest/simpy_intro/installation.html)：已在extended | 使用已知最优/可行例子，核对约束和仿真时钟；回退SciPy或可核验的自写事件模型 |
| 符号与单位 | [SymPy](https://docs.sympy.org/latest/install.html)：已在core；[Pint](https://pint.readthedocs.io/en/stable/getting/index.html)：`pint` | 验证符号解代回原式、单位换算和维度；可人工单位表与数值交叉检查 |
| Plotly静态图 | extended含`plotly`；另装`kaleido`，按[官方导出说明](https://plotly.com/python/static-image-export/)准备兼容Chrome/Chromium | Kaleido 1及之后不随包带Chrome；实际执行PNG/PDF导出。浏览器不可用时用Matplotlib导出，不能只有交互窗口截图 |
| 学术绘图样式 | extended含[SciencePlots](https://github.com/garrettj403/SciencePlots)；如没有TeX，使用支持无TeX的样式组合 | 实际测试中文、数学符号、灰度和彩色输出；样式不提升数据真实性，默认Matplotlib路线仍可用 |
| 网络与空间 | [NetworkX](https://networkx.org/documentation/stable/install.html)：已在extended；[GeoPandas](https://geopandas.org/en/stable/getting_started/install.html)：`geopandas`或官方建议的专用conda环境 | 最短路已知例子；空间数据读写、坐标参考系与重投影检查。无地理组件时不可将经纬度直接当平面距离 |
| 天文/流体/测速 | [Astropy](https://docs.astropy.org/en/stable/install.html)：`astropy`；[FluidSim](https://fluidsim.readthedocs.io/en/latest/install.html)：依官方平台/FFTW等要求；[OpenPIV](https://github.com/OpenPIV/openpiv-python)：按维护仓库当前说明 | 仅对应题型启用；物理量、边界条件、标准案例/已知位移分别测试。编译或系统依赖不满足时报告该专业路线未运行 |
| 时间序列基础模型 | [Google Research TimesFM](https://github.com/google-research/timesfm)官方仓库 | 根据固定版本准备其Python后端与模型权重，记录下载来源/权重版本和硬件条件；不能只安装包就声称可推理。默认仍比较朴素预测及statsmodels基线 |
| 文档内容转换 | [Microsoft MarkItDown](https://github.com/microsoft/markitdown)：只安装实际所需格式的额外依赖 | 比对提取文字/表格与原件。Markdown转换不保留完整论文版式，不能替代Word/LaTeX源稿及PDF逐页检查 |

其他未在当前能力登记表中的领域技能，应先看题目是否需要、许可证和依赖是否明确，再加入项目。高星仓库并不等于已审查，也不等于所有依赖可在当前系统安装。

## 6. 受邀者必须完成的验收

2.3新增的路线图/逐问步骤图使用已有core中的Matplotlib、Pillow与PyMuPDF，无新增桌面软件或在线账号硬依赖。安装后必须能找到 `render_flowcharts.py`、`presentation_audit.py` 和 `presentation-workflow.md`；缺失说明安装包或缓存不完整。中文需要本机合法且覆盖所用字形的字体，缺字会明确失败，不允许静默生成方框。按随包合成示例至少导出一次SVG/PDF/PNG；正式项目复制渲染源码到项目内并使用 `--project-root`。模板字体、商业许可证和可选Graphviz依旧按本说明单独准备，不随邀请共享。

1. **插件加载**：重启Codex、新建普通任务，确认能调用 `math-modeling-championship-maxx`，并找到本文件和随包审计程序。安装状态与运行环境状态分别保留。
2. **当前交付路线检查**：使用实际环境解释器运行 `scripts/max_doctor.py --delivery word --profile championship --inputs csv xlsx`；LaTeX选`latex`，双份交付选`both`。Windows也可用 `scripts/max_doctor.ps1 -Delivery word -Profile championship`。自定义解释器时可设置当前会话 `MATHMODEL_PYTHON` 为其完整路径。`ready: true`只代表该配置的基础条件通过，并不证明所有可选应用已实跑。
3. **实际集成测试**：用同一解释器运行 `scripts/app_integration_smoke.py --output-dir <全新空目录>`。核对生成的图、DOCX、PDF与运行回执。`PASS_WITH_FALLBACK`应说明替代了什么；`NOT_RUN`不能计为通过。此测试为合成数据，只核验工具链，不证明具体题目解答正确。
4. **所选外部应用逐项验证**：按第4–5节运行最小样例；在线服务每个接收者自行连接并实调。输出清单至少包含应用/包、版本或版本未知、解释器/程序路径、测试输入、返回/产物、退出状态、时间及缺口。缺少许可、登录、网络或系统依赖时保留原状态与修复办法。
5. **正式演练题目回归**：拿题面和附件从输入清单开始完整运行，检查代码、约束、数值与图文一致性、非程序AI内容台账、逐页版式、材料包清单和二次复核。仅当所选路线全部满足该题需求，才宣告这台电脑的该题工作流可交付。

## 7. 常见断链与恢复

| 现象 | 处理 |
|---|---|
| 邀请链接可打开但无法解密 | 检查完整链接是否保留`#invite=`片段；从新临时目录重新克隆。口令验证失败时不尝试绕过，也不把口令写入公开问题报告 |
| 更新后仍加载旧版本 | 保留安装回执，完全退出并重开Codex、新建任务；检查实际加载技能路径/版本。不要反复覆盖正在使用的缓存目录 |
| `python`跳转商店/找不到模块 | 使用真实解释器绝对路径；所有安装都用该路径的`-m pip`。核对环境回执，而非改用系统另一个pip |
| 桌面Codex可打开，但安装器找不到`codex` | 先完成第1节的CLI路径、`codex --version`和`codex plugin --help`预检；未通过为`NOT_READY`。使用宿主官方CLI或官方文档，不从无关第三方安装同名程序 |
| 缺少兼容二进制轮子或包冲突 | 根据错误与官方支持范围新建兼容环境，重新运行引导；不把全量包不断叠加进同一个环境。保留基础环境与失败日志 |
| Doctor提示缺Word/LibreOffice/XeLaTeX | 按所选交付路线安装渲染器，重启后再检；Word的Python库不能代替Word/LibreOffice程序 |
| 应用已安装但探测不到 | 核对实际启动器文件，在当前终端PATH中加入其目录或明确记录绝对路径；随后实跑。探测只查有限范围，不靠重装插件修复PATH |
| 中文缺字、公式漂移、PDF页数不一致 | 安装模板实际使用且许可允许的字体，核对转换器与原稿、重新导出并逐页查看。不能仅依据导出命令成功 |
| 图表只在屏幕显示/静态导出失败 | 保存绘图源、数据及Matplotlib PNG/PDF/SVG；Plotly需补Kaleido和浏览器，Graphviz需真正的dot程序 |
| MATLAB Engine导入/启动失败 | 检查64位、MATLAB/Engine/Python版本匹配和许可；可直接用MATLAB批处理绕过Engine桥接，或改用经验证的Python实现 |
| Wolfram/SciSpace未出现或授权过期 | 在受邀者当前宿主重新发现插件与连接状态；使用实际连接提示。服务被工作区禁用时采用本地/公开来源路线并保留功能缺口 |
| 外部网站链接失效 | 通过该项目官方主页或维护仓库定位新安装页，记录更新后的来源与日期；本地随包说明、核心审计与计算不依赖某个在线页面持续可用 |
| 网络不可用 | 已安装本地计算/绘图/审计可以继续；在线文献与服务查询标为未运行。需要离线复现时提前保存合法可得的依赖轮子/原文及哈希，不把账号凭据放进材料包 |

本说明给出全部已登记能力的安装、验证和替代关系；外部服务的可用性、额度、许可证和专业题型硬件仍由接收者实际环境决定。交付的就绪报告必须明确这些状态，任何失败都不能被“全部功能已安装”一句话掩盖。
