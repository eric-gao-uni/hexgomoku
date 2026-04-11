# iOS App Store 发布流程

完整执行以下发布步骤，每步完成后报告状态。如果任何步骤失败，停下来诊断原因。

## 步骤 1: 预检查

- 运行 `flutter test` 确保所有测试通过
- 运行 `flutter analyze` 确保无错误
- 读取 `pubspec.yaml` 中的当前版本号，展示给用户确认
- 检查 git 工作区是否干净（无未提交改动），如有提醒用户先提交

## 步骤 2: 构建 IPA

```bash
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
```

构建成功后报告 IPA 文件路径和大小。

## 步骤 3: 上传到 App Store Connect

使用 Transporter 上传 IPA：

```bash
open -a Transporter
```

提示用户：
- Transporter 已打开，请将 IPA 文件拖入 Transporter 窗口
- IPA 文件位置：`build/ios/ipa/hexgomoku.ipa`
- 点击"交付"等待上传完成
- 上传后 Apple 需要几分钟处理构建，处理完成后会收到邮件通知

## 步骤 4: 生成 What's New 文档

根据自上次发布以来的 git log 变更，生成英文版的 What's New 文本：

- 运行 `git log` 查看上次发布标签或版本 bump 以来的所有提交
- 用简洁、用户友好的英文总结变更（不要写技术细节，面向 App Store 用户）
- 格式要求：简短的要点列表，每条不超过一行
- 展示给用户确认，用户确认后复制到剪贴板

示例格式：
```
- Fixed turn order: each player now correctly moves their own piece first, then the red piece
- Improved AI difficulty levels with distinct play styles
- Bug fixes and stability improvements
```

## 步骤 5: 提交审查

提示用户在 App Store Connect 网页完成以下操作：
1. 打开 https://appstoreconnect.apple.com
2. 选择 HexGomoku app
3. 在新版本中选择刚上传的构建版本
4. 粘贴 What's New 文本到"此版本的新增内容"字段
5. 点击"提交以供审查"

## 注意事项

- Bundle ID: com.hexgomoku.hexgomoku
- Team ID: NLCJF28Y8U
- 如果 `flutter build ipa` 失败，尝试 `flutter clean` 后重试
- 如果 Transporter 报签名错误，检查 Xcode 中的证书和描述文件配置
