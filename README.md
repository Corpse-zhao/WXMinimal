# WXMinimal：第一阶段诊断源码

## 当前状态

这是未经 iOS 编译及真机测试的 Theos Objective-C 诊断源码，不含防撤回功能。目标测试环境由用户提供：iPhone 14 Pro Max / iOS 16.6 / 微信 8.0.75 / Relaxin。Relaxin 具体版本、注入组件与设备兼容性仍需核实；GitHub Actions 只负责尝试编译，不证明产物可在该设备安装或运行。

## GitHub 云编译

1. 将整个项目目录（包括隐藏的 `.github` 目录）上传为 GitHub 仓库，或在 GitHub 新建仓库后把本项目内容推送上去。Actions 需要在仓库的 **Settings → Actions → General** 中启用；组织策略可能限制 workflow。
2. 打开仓库 **Actions → Theos cloud build → Run workflow** 手动启动。仅手动触发，不在每次推送或 PR 时自动消耗构建额度；私有仓库请留意 GitHub Actions 的 macOS 分钟配额和账单设置。
3. 等待工作流完成。成功时进入该次运行页面底部 **Artifacts**，下载 `WXMinimal-diagnostic-<commit>`。压缩包内是 `.deb`。失败时先看 `Build package` 日志；失败日志不产生可用包。

工作流使用 GitHub 官方 `actions/checkout` 与 `actions/upload-artifact`，在 GitHub 托管的 `macos-14` 上使用预装 Xcode/iOS SDK，并从 `roothide/theos` 官方仓库浅克隆 Theos 及其子模块；项目 checkout 也请求递归子模块。无私有密钥、发布或推送步骤；Theos 构建可能使用 ldid 做临时签名，不等于 Apple 开发者证书签名。成功时上传 .deb；构建步骤生成的 build.log 在失败时也尝试上传。Artifact 保留 7 天。

云端构建工具链会随 GitHub runner/Xcode 更新；`iphone:clang:latest:16.0` 中 `latest` 指 runner 上可用 SDK，最低部署版本为 16.0，不锁定 iOS 16.6 SDK。工作流若失败于 scheme、SDK 或架构兼容，不能靠该工作流成功与否推断目标设备兼容。

## 诊断版做什么

- 过滤到 `com.tencent.xin`，并在代码中再次检查进程包名。
- 加载后第 5 秒和第 20 秒，检查三个候选类是否存在。
- 只记录候选类自身方法中含 revoke / retract / sysmsg 的方法名称、类型编码，以及微信和系统版本。
- 类名 `CMessageMgr` / `CMessageWrap` / `MessageService` 只是探测候选，不是已确认的 8.0.75 私有接口。继承方法、其他命名和其他处理路径可能遗漏。
- 报告写入微信数据容器的 `Library/Caches/WXMinimal/diagnostics.json`，第二次覆盖第一次。
- 不 hook、不调用微信私有方法、不读取消息、账号、联系人、实名或聊天数据库；不联网、不上传。

## 构建/安装限制

工作流没有修改 Makefile 或 control：项目当前声明 `THEOS_PACKAGE_SCHEME = roothide`、`ARCHS = arm64 arm64e`，并将包架构写为 `iphoneos-arm64e`。我无法从可访问的官方文档确认该 RootHide/Relaxin 组合对这些值、安装前缀和依赖的兼容性，因此保留原值，避免把未验证的猜测写入包配置。必须由目标 RootHide/Relaxin 版本维护者或设备端实际工具链确认；“成功编译”不等于包可安装、注入或安全运行。不得将云端产物用于未经授权的设备或账户。

没有 Apple 开发者证书签名或设备安装验证步骤，包不是 App Store 产品；ldid 临时签名也不代表已适配设备注入。GitHub Actions 所用 SDK/Xcode 版本与 iOS 16.6 不完全绑定。当前代码未确认 Relaxin 注入器所需 package dependency；不应盲目补充依赖或安装。仅在自有测试设备上、完成兼容性核验后评估。

## 本地诊断及真机测试

本地构建需要带合法来源 iOS SDK 的 Theos 环境，以及与设备当前 Relaxin/注入环境匹配的工具链：

```sh
export THEOS=/你的实际路径/theos
make clean package
```

若提示 scheme 不存在，应核对 RootHide/Relaxin 当前文档，不要为了编译通过而直接改成 rootless。不同打包 scheme、架构、安装位置、签名和注入依赖不可混用。

1. 备份重要聊天记录，只在自有测试设备上操作。
2. 保持原微信安装不动，不使用来源不明的修改版 IPA，不覆盖安装微信。
3. 完成目标环境核验后，用设备现有包管理器安装，并通过现有注入管理方式仅允许该插件注入微信。具体步骤依实际环境确定。
4. 完全退出后重新打开微信，停留至少 20 秒。
5. 使用设备已有文件管理器，在微信的**数据容器**（不是应用安装目录）查找上述 JSON 文件。不要导出整个微信容器或聊天数据库。
6. 仅分享 `diagnostics.json`。报告只含运行环境和方法元数据，但分享前仍建议自行查看。
7. 没有报告不等于“不支持”：也可能是注入未开启、路径不对、进程未重启或系统没有给足运行时间。先检查注入器日志。

## 停用与卸载

若微信异常，先在已有注入管理器停用本插件，或使用越狱环境现有安全模式，再卸载 `local.wxminimal.diagnostics`。不需要删除微信或聊天数据。具体安全模式入口取决于实际环境，请在测试前确认。报告可单独删除；这是可被系统清理的缓存文件。插件没有修改消息记录。

## 后续开发门槛

取得诊断报告后，仍需确认真实调用路径、参数意义和 UI 更新方式；仅凭方法名不能可靠实现防撤回。不能盲目屏蔽所有系统消息或统一 return。下一阶段需在自有测试账号间验证：普通文本、图片、群聊、重复消息、撤回提示、重启后状态和关闭模块后的恢复。

首版防撤回只讨论本机已收到的消息，不承诺恢复历史已撤回内容。未越狱设备另行评估，不承诺这份 dylib 可直接安装。

“实名末字”尚未实现，需明确合法且已授权的数据来源；不实现绕过隐私限制查询他人隐藏实名。
