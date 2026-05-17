---
trigger: always_on
---
- name: project-analysis-summary-rule
- 描述: 当用户要求“分析项目”、“生成项目总结”、“生成README”、“上传项目总结”或类似指令时，AI 需深入分析项目所有源代码，并输出一份详细的项目总结文档（Markdown 格式）保存到项目根目录，命名为 README.md，可直接 Git 提交作为仓库说明文档。AI 在执行该任务时必须保证不中断，直至成功生成文件。
- 规则:
    1. **扫描范围**：递归读取项目根目录下的所有源代码文件（包括但不限于 .js, .ts, .tsx, .py, .java, .go, .c, .cpp, .rs, .html, .css, .vue, .json, .json5, .yaml, .xml, .ets, .hml, .arkts 等），忽略 node_modules、.git、dist、build、__pycache__、.idea、oh_modules 等常见忽略文件夹。
    2. **分析内容**：
        - 项目整体架构（如 MVC、微服务、前后端分离、鸿蒙 Stage 模型等）
        - 主要模块/包及其职责
        - 技术栈（框架、数据库、第三方库等）
        - 关键代码逻辑（核心类/函数、重要算法、业务流）
        - 配置文件说明（数据库连接、环境变量等）
        - 依赖关系（包管理文件如 package.json、oh-package.json5、requirements.txt、go.mod 等）
        - 代码量统计（文件数、行数估算）
        - 潜在的改进点或风险（如有）
        - **鸿蒙项目特有分析**（当检测到鸿蒙项目时，额外包含以下内容）：
            * 识别项目类型：HarmonyOS 应用 / OpenHarmony 应用 / 元服务
            * 应用模型：Stage 模型（主要）或 FA 模型
            * 模块结构：列出所有模块（entry、feature、library、har、hsp 等）及其类型
            * 关键配置文件：app.json5、module.json5、build-profile.json5、oh-package.json5
            * 编程语言：ArkTS（优先）、JS、C++（Native）
            * UI 框架：ArkUI（声明式）、兼容 XML 布局等
            * Ability 组件：UIAbility、ExtensionAbility、ServiceExtensionAbility 等
            * 系统能力调用：如相机、位置、通知、分布式数据等
            * 签名与证书：调试签名/发布签名配置
            * 鸿蒙特有的目录结构：entry/src/main/ets、resources、ohosTest 等
    3. **生成文档**：
        - 文件名固定为 `README.md`
        - 保存路径：项目根目录（即当前打开工作区的根目录）
        - 使用中文撰写，结构清晰，适合作为项目的说明文档（应包含：项目名称、简介、快速开始、详细设计、技术栈、构建部署等章节）
        - 必须包含项目名称（从根目录或已有 README 推断）、分析时间戳、分析所覆盖的文件清单概要
    4. **执行行为（保证不中断）**：
        - AI 必须先完整扫描理解项目，再生成总结，不得直接输出模板。
        - 如果项目文件过多（超过 50 个），优先分析核心目录（src、lib、app、entry、feature、backend、frontend 等），并在总结中注明“部分次要文件未详细分析”。
        - **严格禁止**：不得因为单个文件读取失败、某些依赖缺失、长时间运行、token 预估不足或任何其他原因中止任务。若遇到暂时性错误（如文件权限、编码问题），应跳过该文件并继续扫描其余文件，并在 README 末尾记录跳过的文件列表及原因。
        - **重试机制**：分析过程中如果遇到网络/工具调用瞬断，应自动重试（最多3次）；如果无法恢复，则基于已获取的信息先生成 README 并标记“分析不完整”。
        - **进度提示**：分析过程中向用户每处理完一个目录输出一次简短进度（如“已分析 src/ 目录，继续中…”），确保用户感知到任务未中断。
        - 生成文件后，必须提示用户：“项目 README 已生成，可直接提交到 Git 仓库。”
        - 该任务未完成前，不得自动开始任何其他用户请求的新话题或任务，除非用户明确强制打断。