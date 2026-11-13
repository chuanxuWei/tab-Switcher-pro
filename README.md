# Tab Switcher Pro

在 macOS 的 Google Chrome 中重现 Arc 的 Control–Tab 手势：按最近使用顺序浏览横向预览卡片，松开 Control 才切换标签。另提供 **Command–Control–C** 复制当前标签 URL。

这是 **macOS 菜单栏应用**，不是 Chrome 扩展。支持 macOS 14+，无需 npm 或第三方库。当前是可编译的 0.1 原型，尚不能宣称与 Arc 完全一致。

## 快捷键

| 按键 | 行为 |
| --- | --- |
| `⌃ Tab` | 选择最近访问的上一个标签；继续按 Tab 向后选择 |
| 松开 `⌃` | 提交选择，切换 Chrome 标签 |
| `⌃ ⇧ Tab` | 反向选择 |
| `Esc` | 关闭浮层，不切换标签 |
| `⌘ ⌃ C` | 将当前标签完整 URL 写入剪贴板，并显示提示 |

短按不闪现浮层；按住约 120 ms 显示卡片。每次手势冻结排序，连续快速手势可以在最近两个标签之间往返。仅作用于前台的 Google Chrome、当前窗口；切换到其他应用会取消选择。菜单栏可暂停或退出。

## 构建与安装

需要 Xcode Command Line Tools：

```sh
./scripts/test.sh
./scripts/build.sh
./scripts/install.sh
```

安装脚本复制到 `~/Applications/Tab Switcher Pro.app`，随后在 Finder 中双击应用。首次打开会显示使用说明。

1. 系统设置 → 隐私与安全性 → **辅助功能**：添加并开启 Tab Switcher Pro。然后点击菜单栏图标 →「授权辅助功能并重试」。
2. 回到 Chrome；首次出现自动化提示时，允许该应用控制 **Google Chrome**。拒绝后可在系统设置 → 隐私与安全性 → **自动化** 中修改。
3. 如需网页预览，菜单栏 →「启用缩略图（屏幕录制权限）」，在系统设置的**屏幕录制 / 屏幕与系统音频录制**中授权，必要时退出并重新打开应用。不授权也可切换，卡片显示域名。
4. 在 Chrome 打开几个标签，各停留约一秒以建立历史。按住 Control，再按 Tab；松开 Control 确认。

重新构建会改变本地临时签名；若系统权限失效，移除旧授权条目后重新添加安装位置的应用。没有开发者证书签名或公证，不提供绕过 Gatekeeper 的脚本。未自动设置开机启动；如需要可自行加入系统登录项。

## 为什么不是纯扩展

Chrome 的 [Commands API](https://developer.chrome.com/docs/extensions/reference/api/commands) 支持的普通快捷键不含 Tab，并明确指出部分浏览器快捷键不可覆盖。原生 CGEventTap 在 Chrome 处理之前拦截 Control–Tab，并检测 Control 的释放；Apple Events 读取和切换标签，ScreenCaptureKit 获取窗口预览。无需开启 Chrome 的「允许来自 Apple 事件的 JavaScript」。

## 与 Arc 的差异和当前边界

- 通过每 300 ms 读取 Chrome 前台窗口来维护最近使用顺序；启动前的访问历史不可恢复，300 ms 内的外部快速切换可能漏记。第一次出现的未访问标签保持标签栏顺序。
- 缩略图来自访问过的**整个 Chrome 窗口**，含浏览器工具栏；不是浏览器内部的每页实时截图。稳定停留 550 ms 后可截图，最多每两秒一次。没访问过、没授权或无痕窗口显示域名占位卡。页面滚动/加载后预览有延迟。
- 缩略图仅在内存，退出清除，不写盘、不上传。不截图无痕窗口。切换窗口时清理旧窗口预览，内存最多保留 80 张。
- 仅当前窗口，未跨窗口或跨浏览器；快捷键触发前刚切换窗口时，缓存可能短暂落后，提交前会核对窗口，避免切错窗口。
- 中文/英文键盘通过物理 C 键识别复制快捷键；其他键盘布局未实测。
- 目前不支持鼠标点选卡片、拖动、关闭标签或自动登录启动。浮层在鼠标所在屏幕中央。
- macOS 的安全输入、其他快捷键管理器、Chrome 卡顿或权限被撤销可能影响响应；失败原因可在菜单「状态与使用说明」查看。退出应用立即恢复 Chrome 原生行为。

## 验证

`./scripts/test.sh` 检查 MRU 排序、冻结会话、正反向循环、空/单标签、关闭标签清理、最近两页往返、窗口隔离和 40 种列表长度；同时校验 Info.plist。`./scripts/build.sh` 编译并生成本机架构的临时签名应用。

实机验收清单见 [TESTING.md](TESTING.md)。编译/模型测试通过不等于系统权限、真实键盘释放、Chrome 自动化和截图链路已经通过验收。

## 项目结构

- `Sources/Model.swift`：可独立测试的 MRU 和选择模型。
- `Sources/Chrome.swift`：Chrome Apple Events 适配，按稳定标签 ID 重新定位。
- `Sources/App.swift`：菜单、权限、事件拦截、延迟显示、提交、截图缓存。
- `Sources/Overlay.swift`：原生毛玻璃浮层与粉色选中卡片。
- `demo/`：本地用户参考视频（不上传）。

无外部网络请求，无遥测，无自动更新。程序只把复制命令指定的 URL 写入系统剪贴板。
