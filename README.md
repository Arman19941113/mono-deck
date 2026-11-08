# MonoDeck

MonoDeck 是一款 macOS 原生客户端。它按任务组织多个 Git 仓库的工作树，帮助开发者在一个地方管理多个跨仓库开发任务，打造专属 AI 工作流。

![MonoDeck](./.github/assets/mono-deck-mock.png)

## 主要功能

- 批量添加和更新 Git 仓库，按任务创建、编辑和清理工作树分组。
- 查看工作树的本地更改、独有提交和落后提交，在外部工具中打开分组或成员目录。
- 支持 Agent 通过 `mono-deck` CLI 和 `mono-deck-workflow` SKILL 管理仓库与分组。

## 工作区如何组织

工作区根目录是一个独立的 Git 仓库，可存放提示词、技能、项目文档等内容。

分组的根目录是工作区仓库的关联工作树，成员则是所选业务仓库的关联工作树。

```text
example-workspace/               # 工作区根目录
├── repositories/
│   ├── order-service/
│   └── storefront-web/
└── worktrees/
    └── feature-checkout/        # 分组根目录，一次任务的工作树分组
        ├── order-service/       # 分组成员，关联业务仓库的工作树
        └── storefront-web/
```

## 开始使用

从 [Releases](https://github.com/qimaotech/mono-deck/releases) 下载 Apple Silicon 版 DMG，将 `MonoDeck.app` 拖入“应用程序”。

当前安装包采用 ad-hoc 签名，尚未经过 Apple 公证。若下载隔离标记阻止 App 打开，确认安装包来源可信后，可运行以下命令再打开 App。

```bash
xattr -dr com.apple.quarantine /Applications/MonoDeck.app
```

1. 启动 MonoDeck，按引导安装 CLI 并选择工作区目录。首次使用可选一个专用的空目录。
2. 通过 URL 添加仓库，或在添加窗口的“导入”菜单中扫描本地仓库。两种方式都使用本机 Git 认证从远端克隆，本地仓库的未提交改动留在原目录。
3. 如需最新的远端分支，先更新主仓库，再创建分组并选择成员。分组名须是符合 Git 分支命名规则的单层目录名，例如 `feature-checkout`。初始分支名默认与分组同名，也可填写 `feature/checkout`。新增成员沿用该设置，有可用的同名本地分支时会复用。
4. 选中分组或单个成员，通过工具栏在已安装的 Agent、编辑器、终端或 Git 工具中打开，在外部工具中完成开发、提交和合并。
5. 在 Git Browser 查看本地更改、独有提交和落后提交。对比以本地记录的远端默认分支为基准。

重装后，可在引导或设置中选择原工作区。登记缺失时，MonoDeck 会尝试从本地 Git 数据重建登记，保留已识别仓库和工作树的分支及改动。

## CLI 与 Agent

按引导安装 CLI 后，在工作区目录下运行以下命令。示例假设已添加 `order-service` 和 `storefront-web`。

```bash
mono-deck workspace tree --json
mono-deck group create feature-checkout --branch feature/checkout --repo order-service --repo storefront-web
mono-deck group delete feature-checkout --dry-run
```

`--repo` 使用仓库 ID，也就是仓库 URL 末段去掉 `.git` 后缀后的名称。在工作区外运行时，可用 `--workspace` 指定根目录。参数见各子命令的 `--help`，JSON 输出格式见 [CLI 契约](GLOSSARY.md#external-data-and-cli-contract)。

`group edit --repo` 指定完整的目标成员集合，省略的成员会被删除。用 `--dry-run` 预览删除，目标有变化时重新预览。交互终端会请求确认，使用 `--json` 或在非交互环境中执行删除时，需通过 `--yes` 授权本次命令的删除目标。

安装内置工作流技能后，从工作区根目录启动 Agent，可显式调用 `$mono-deck-workflow` 管理仓库和分组。

### 工作区文件与自动提交

MonoDeck 维护以下工作区文件，并按需自动提交到工作区仓库。请提前配置 Git 提交身份与签名环境。

- **`.gitignore`** 会按需补充忽略规则。自动提交包含整个文件，可能一并提交你的手动修改。
- **`mono-deck-workflow`** SKILL 会在打开或重新加载工作区时同步，如有本地改动会被丢弃，如果需要自定义流程可另建 `.agents/skills/mono-deck-workflow-addon/SKILL.md`。

## 使用须知

- **分享配置**可在“设置 → 配置”导出 YAML，再导入空工作区。YAML 只保存仓库清单、分组和初始分支等配置，代码、提交历史及未提交改动需单独备份。
- **删除成员或分组**会永久移除对应工作树及其当前本地分支。未提交改动随工作树移除，未合并提交可能丢失。删除主仓库会先删除关联成员，再将主仓库移至废纸篓。确认前请核对范围和需要保留的内容。
- **取消或部分失败**可能保留已完成的效果，请按结果列表核对已完成和待处理的项目。
- 包含 **Git 子模块**的仓库暂不支持创建分组成员工作树。

版本变化见[更新日志](CHANGELOG.md)，构建与测试见[开发细则](DEVELOPMENT.md)。
