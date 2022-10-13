## 2022/02/22

[Added] 支持 Parse Gerrit Git URL

[Added] 支持 Parse Gitlab 的 subgroup

[Added] 现在可以从环境变量中 Parse Option/Flag 类型的参数

[Fixed] 修复 NSString/NSArray/NSDictionary 转换为 JSON 字符串会 Crash

[Fixed] 修复透传原始参数时，遇到同名参数会透传失败

[Fixed] Launcher 检测逻辑现在只会检查当前 Launcher，不会递归检查依赖

[Fixed] 外部命令如果带空格，MBox 检查该命令是否有效时会分析出错

[Fixed] 修复 Crash 发生后的异常捕捉又发生二次 Crash 导致进程卡死

[Fixed] 修复 `--api` 模式下无法输出 `verbose` 日志

[Fixed] 使用 `brew list --cask` 代替过期的 `brew cask` 命令

[Fixed] MBox 进程中调用其他命令，其他命令可能会再调用 MBox 命令，这时候 MBox 环境变量会影响第二个 MBox 进程，增加环境变量清理重置逻辑修复这个问题

[Fixed] 修复检测首次启动 Xcode 的命令失效

[Fixed] 一个命令 invoke 另外一个现在也会执行 validate 了

[Optimize] 优化 arm64 架构设备的 Homebrew 安装策略

[Optimize] 在非交互式终端下如果出现用户交互行为现在会执行失败，不再卡死等待用户输入

[Optimize] 优化插件加载算法，增加仲裁算法，更改环境变量 `export MBOX_PRINT_PLUGIN=1` 可打印插件加载日志

[Added] 插件描述文件新增 `FORWARD_DEPENDENCIES` 字段，可以描述该插件激活的前缀依赖，只有前置依赖激活，该插件才能激活。例如：
```
FORWARD_DEPENDENCIES: 
- MBoxWorkspace: null
```
代表该插件只有在 Workspace 下才能被激活。同时配合 `REQUIRED` 和用户的设置，达到自动激活和选择性激活的效果

[Added] 添加 `linenoise` 三方库功能，提供更强大的终端处理和交互功能

[Changed] 重新设计插件模块，现在每个插件包可以包含多个 Module，而每个 Module 可以使用 `FORWARD_DEPENDENCIES` 来选择性激活插件包内的某些模块。例如：
```yaml
# MBoxDebug/manifest.yml
NAME: MBoxDebug
DEPENDENCIES:
- MBoxCore
FORWARD_DEPENDENCIES:
- MBoxWorkspace: null
MODULES:
- MBoxDebug/iOS
- MBoxDebug/Android

# MBoxDebug/iOS/manifest.yml
NAME: MBoxDebug/iOS
DEPENDENCIES:
- MBoxCore
- MBoxDebug
FORWARD_DEPENDENCIES:
- MBoxWorkspace: null
- MBoxIOS: null

# MBoxDebug/Android/manifest.yml
NAME: MBoxDebug/Android
DEPENDENCIES:
- MBoxCore
- MBoxDebug
FORWARD_DEPENDENCIES:
- MBoxWorkspace: null
- MBoxAndroid: null
```
上面的例子中，`MBoxDebug` 有 3 个 Module，分别是 `MBoxDebug`/`MBoxDebug/iOS`/`MBoxDebug/Android`，当用户激活了 `MBoxDebug` 插件后，且当前执行是 Workspace 环境（`MBoxWorkspace`激活了)，则 `MBoxDebug` 模块激活，当前 Workspace 如果为 iOS 项目（`MBoxIOS`激活了），则 `MBoxDebug/iOS` 模块激活，而 `MBoxDebug/Android` 模块并不会激活。

[Changed] 移除插件的 `ALIAS` 字段，不再支持别名功能

[Changed] 移除 `MBSession`，拆解为 `MBProcess` 和 `MBThread`，支持 Swift 5.5 的 `async` 功能

[Changed] 移除 `CocoaLumberjack` 三方库，重新实现一套轻量的日志系统

