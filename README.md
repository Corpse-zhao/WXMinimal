# WXMinimal 防撤回版 v0.2.0

基于真机诊断报告（`diagnostics(1).json`，微信 8.0.75.33 / iOS 16.6）实现的防撤回插件。

## 依据

诊断报告确认以下候选类/方法真实存在：

- `CMessageMgr`（存在）— `RevokeMsg:MsgWrap:Counter:` 与 `RevokeMsg:MsgWrap:Counter:revokeTicket:viewController:` 两个重载；`PostInsertParsedXmlSysMsg:ChatName:`；`GetRevokeMsgBySvrId:` 等
- `CMessageWrap`（存在）— `doRevokeHistoryRecord`、`revokeBatchId` 等批量撤回相关
- `MessageService`（不存在）— Android 类名，已排除

## 实现

- hook `CMessageMgr` 的**两个** `RevokeMsg` 重载，直接返回 `NO`，阻止撤回在本地生效。之所以两个都 hook：报告无法证明运行时实际走 3 参数还是 5 参数路径，必须双保险。
- hook `PostInsertParsedXmlSysMsg:ChatName:`，仅当内容含 `revokemsg` 时抑制撤回提示的插入，其它系统消息原样 `%orig` 放行。
- hook `CMessageWrap` 的 `doRevokeHistoryRecord` 返回 `NO`，拦截批量撤回。副作用：自己的批量撤回也会被禁用。
- 每次拦截写一行日志到微信数据容器 `Library/Caches/WXMinimal/antirevoke.log`（只记方法名与时间，不记录任何消息内容），便于真机确认哪个 hook 生效。

## 安装与验证

1. 这是 0.2.0 原地升级，包名与 dylib 名和 0.1.0 诊断版一致：用设备现有包管理器直接升级 `local.wxminimal.diagnostics` 即可，会覆盖旧版，无需卸载（也不要同时装两版）。
2. 完全退出微信重开，用另一账号给自己发消息后撤回。
3. 查看容器里的 `antirevoke.log`：有 `RevokeMsg... -> NO` 说明核心 hook 命中；只有 `loaded` 一行说明注入成功但没有撤回事件发生。

## 风险与限制

- 方法存在 ≠ 这是唯一处理路径。若撤回仍生效，优先把 `antirevoke.log` 发回，根据实际触发情况调整 hook，不要盲目扩大拦截范围。
- 拦截系统消息有被微信检测/影响正常功能（如群公告、系统提示）的风险。日志可帮助定位。
- 仅在自有测试设备与账号上使用。不承诺恢复历史已撤回内容，只保留本机已收到的消息。
- 编译成功不等于真机可运行：未经真机验证 Relaxin 注入与运行时兼容。

## 卸载

在注入管理器停用，或卸载 `local.wxminimal.diagnostics`。聊天数据不受影响。
