# 开发细则

## 功能模型与异步协调

### 模型职责与生命周期

- 写操作前暂停相关读取并等待收尾，避免读写交叠。切换和退出也要收尾依赖当前上下文的任务，防止旧结果回流。见 [WorkspaceModel](MonoDeck/Features/Workspace/WorkspaceModel.swift) 与 [AppModel](MonoDeck/App/AppModel.swift)。
- 添加仓库和创建分组的表单绑定打开时的工作区上下文。创建分组时，Core 在锁内复核所选仓库身份，避免使用已过期的选择。见 [ManagementModel](MonoDeck/Features/Management/ManagementModel.swift) 与 [WorktreeService](MonoDeckCore/Workflows/WorktreeService.swift)。

### Git 读取与缓存

- Git 浏览与 CLI 查询只读本地数据。App 的子模块可见性规则仅用于浏览，写入安全检查使用现场 Git 状态。见 [GitInspection](MonoDeckCore/Infrastructure/Git/GitInspection.swift)。
- 当前详情优先，避免后台查询拖慢切换。磁盘快照可先回显以缩短等待，随后仍须读取实时状态。调度与失效见 [GitBrowserModel](MonoDeck/Features/GitBrowser/GitBrowserModel.swift)，持久化与历史复用见 [RepositoryDiskCache](MonoDeckCore/Infrastructure/Persistence/RepositoryDiskCache.swift) 和 [RepositoryHistoryCache](MonoDeckCore/Workflows/RepositoryHistoryCache.swift)。
- 在目标进程的环境中设置 `MONO_DECK_READ_DIAGNOSTICS=1`，可在其标准错误查看读取阶段、命令量和缓存统计。见 [RepositoryReadDiagnostics](MonoDeckCore/Models/RepositoryReadDiagnostics.swift)。

### 工作区加载与维护

- 自动刷新与登记变更通知只触发只读同步。目录修复、登记清理和内置工作流同步属于维护。刷新调度与失败恢复见 [WorkspaceModel](MonoDeck/Features/Workspace/WorkspaceModel.swift)，维护的用户影响见 [工作区文件与自动提交](README.md#工作区文件与自动提交)。
- 自动提交要求本地分支，且仅提交指定文件，以保留用户其他暂存内容。新增仓库在移入工作区前复核提交条件，避免因分支不符合要求留下部分效果。见 [RepositoryService](MonoDeckCore/Workflows/RepositoryService.swift) 与 [GitWorkspace](MonoDeckCore/Infrastructure/Git/GitWorkspace.swift)。

### 启动与设置

- 启动时先只读恢复已保存的工作区与当前详情，再维护，以缩短首次浏览的等待。启动与退出协调见 [AppModel](MonoDeck/App/AppModel.swift) 与 [AppDelegate](MonoDeck/App/AppDelegate.swift)。
- 缺失登记只在引导确认或通过设置手动切换时初始化或恢复。遇到损坏或版本不受支持的登记时保留原文件。见 [SetupModel](MonoDeck/Features/Setup/SetupModel.swift) 与 [WorkspaceRecovery](MonoDeckCore/Workflows/WorkspaceRecovery.swift)。

### 自动更新

- 用户确认后才下载和安装。App 完成收尾并确认独立安装进程就绪后退出，再由安装进程替换并重启。见 [AppUpdateModel](MonoDeck/Features/Updates/AppUpdateModel.swift)、[AppUpdateInstaller](MonoDeckCore/Infrastructure/AppUpdateInstaller.swift) 与 [安装包契约](#ci-与安装包契约)。

### CLI 与领域契约

- 对外格式、预演和确认规则见 [外部数据与 CLI 契约](GLOSSARY.md#external-data-and-cli-contract)。
- 工作区 YAML 导入在锁外克隆，避免网络等待占用工作区锁，发布前在锁内复核登记与目标路径。重试可复用经核验的工作树。见 [YAMLService](MonoDeckCore/Workflows/YAMLService.swift) 与 [WorktreeService](MonoDeckCore/Workflows/WorktreeService.swift)。
- 删除执行时在锁内复核 Git 归属与已授权目标，防止因预演过期误删。符合条件时将物理文件清理交给后台，以缩短同步等待。见 [DeletionService](MonoDeckCore/Workflows/DeletionService.swift) 与 [WorktreeCleanup](MonoDeckCore/Infrastructure/FileSystem/WorktreeCleanup.swift)。

## 构建启动与调试

在仓库根目录使用完整 Xcode（含命令行工具）和 Task 3。工具链与部署目标见 [CI](.github/workflows/ci.yml) 和 [Xcode 工程](MonoDeck.xcodeproj/project.pbxproj)。

| 用途 | 命令 |
| --- | --- |
| 隔离启动并激活临时 Git 场景 | `task mock` |
| 隔离验证启动，输出 PID 后保持运行 | `task verify -- --mock linked-worktree-selected` |
| 启动开发版 | `task run` |
| 清除已保存的工作区选择并启动开发版 | `task run -- --reset` |

- 启动验证只检查 App 进程完成启动。启动前查阅 [关键风险](AGENTS.md#关键风险)，验证后按 [临时实例收尾](#临时实例收尾) 操作。
- `task debug`、`task logs` 和 `task telemetry` 可追加 `-- --mock linked-worktree-selected`。LLDB 中输入 `run` 启动。日志流按本次 PID 收集，开始收集后按 Ctrl-C 只停止日志流。追加 `--verbose` 到透传参数可查看完整构建日志。
- mock 默认复用开发构建产物，需要独立产物时设置本次专用的 `MONO_DECK_DERIVED_DATA_PATH`。可用 `task --dry --verbose <任务>` 核对命令。任务与参数见 [Taskfile.yml](Taskfile.yml) 和 [build_and_run.sh](script/build_and_run.sh)。

## 测试执行与诊断

测试范围与隔离约定见 [验证与交付](AGENTS.md#验证与交付)，夹具复用 [Fixture](MonoDeckTests/MonoDeckTests.swift)。

| 用途 | 命令 |
| --- | --- |
| 按测试类筛选 | `task test TEST_FILTER=MonoDeckTests/VersionTests` |
| 枚举测试标识，用于筛选单个测试方法 | `task test -- -enumerate-tests` |
| 将结果包保存到新路径 | `task test TEST_FILTER=MonoDeckTests/VersionTests -- -resultBundlePath "/tmp/MonoDeck Tests.xcresult"` |
| 运行全量测试 | `task test` |

- 沙箱内先只读核对用户级 SwiftPM 缓存的写入权限。已确认需要提权时，首次运行即申请。
- 零用例或全跳过会失败，枚举除外。失败时查看输出指定的完整日志，追加 `-- --verbose` 可实时输出。结果包默认清理，无法确认测试环境收尾时保留现场并返回失败。见 [run_tests.py](script/run_tests.py)。

## 临时实例收尾

1. 启动前记录已有实例。启动后记录本次 PID、可执行路径、参数、启动时间、临时目录与辅助进程。
2. 核对本次实例身份。如被调试器暂停，先恢复运行。用 `task quit PID=<本次进程号>` 正常退出并确认该 PID 已结束。失败时重新核实身份，再定向终止。见 [quit_app.swift](script/quit_app.swift) 与 [find_mock_app.py](script/find_mock_app.py)。
3. 确认退出后停止本次辅助进程，核对本次数据和偏好，按精确路径处理日志及临时脚本。mock 遗留数据用 `task mock:cleanup DIRECTORY="<本次临时目录>"` 清理。实例归属与保留规则见 [关键风险](AGENTS.md#关键风险)。

## 版本打包与发布

- 产品版本与构建号维护在 [Version.xcconfig](Version.xcconfig)。`task package` 构建并打包 arm64 DMG，`CI` 为空时自动打开产物。见 [generate_version.sh](script/generate_version.sh) 与 [package_app.sh](script/package_app.sh)。
- 显式调用发布 skill 并请求完整流程时，授权范围限于暂存和提交 `Version.xcconfig`、`CHANGELOG.md` 及创建对应本地 tag。推送分支或 tag、创建 GitHub Release 需另有明确授权。流程和校验命令见 [发布 skill](.agents/skills/release-mono-deck/SKILL.md)。

### CI 与安装包契约

- 推送 `v*` tag 会触发 CI 发布。tag、产品版本、发布说明与 `MonoDeck-<版本号>-arm64.dmg` 须一致，打包和测试通过后才发布。见 [CI](.github/workflows/ci.yml)。
- 更新检查查询 GitHub 的 latest Release，只接受更高版本的正式发布。自动安装要求附件提供有效的 SHA-256 摘要，并核对下载文件的大小和摘要。见 [AppUpdateService](MonoDeckCore/Infrastructure/AppUpdateService.swift) 与 [AppUpdateInstaller](MonoDeckCore/Infrastructure/AppUpdateInstaller.swift)。

## 文档与提示词维护

- 使用方法和用户风险写入 [README](README.md)，领域术语和对外字段写入 [GLOSSARY](GLOSSARY.md)，仓库协作约定写入 [AGENTS](AGENTS.md)。本文件保留开发入口与跨模块约束，具体规则和参数查实现与测试。
- 修改 CLI 契约时同步核对使用文档、内置工作流与 [CLIContractTests](MonoDeckTests/CLIContractTests.swift)。修改提示词时同时核对描述、默认提示词与调用策略。见 [内置工作流](MonoDeck/Resources/mono-deck-workflow/SKILL.md)、[内置调用配置](MonoDeck/Resources/mono-deck-workflow/agents/openai.yaml) 与 [发布调用配置](.agents/skills/release-mono-deck/agents/openai.yaml)。
- 纯文档改动检查路径、命令、章节引用与 `git diff --check`。
