# HarmonyOS 接入预留

当前本机标准 Flutter SDK 不接受 `--platforms ohos`。切换到 OpenHarmony 兼容版 Flutter SDK 后，在 `frontend` 目录执行：

```bash
flutter create --platforms ohos .
flutter pub get
flutter run -d <deviceId> --dart-define=LING_TARGET_PLATFORM=ohos
```

如果需要正式打包，可使用：

```bash
flutter build hap --release --dart-define=LING_TARGET_PLATFORM=ohos
```

更详细的环境配置、DevEco / OpenHarmony SDK 依赖与注意事项，请查看仓库根目录下的 `docs/跨平台开发说明.md`。

仓库已预置 `entry/src/main/ets/entryability/EntryAbility.ets`、`entry/src/main/ets/ling/LingBridgePlugin.ets` 与 `entry/src/main/module.json5`，用于承接现有 Dart MethodChannel/EventChannel。生成平台壳后，如 SDK 覆盖这些文件，请把桥接注册迁回对应路径。
