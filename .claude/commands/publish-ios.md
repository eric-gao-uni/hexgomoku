# iOS App Store 发布流程

完整执行以下发布步骤，每步完成后报告状态。如果任何步骤失败，停下来诊断原因。

## 步骤 1: 预检查

1. 运行 `flutter test` 确保所有测试通过，如果失败则停止发布
2. 运行 `flutter analyze` 确保无 error（info/warning 可忽略）
3. 检查 git 工作区是否干净（`git status`），如有未提交改动提醒用户先提交
4. 读取 `pubspec.yaml` 中的当前版本号，展示给用户

## 步骤 2: Bump 版本号

- 读取 `pubspec.yaml` 中当前 `version: X.Y.Z+N`
- 自动递增 build number（+N → +N+1），version 部分保持不变
- 如果用户需要递增 version（如 1.1.3 → 1.2.0），询问用户确认
- 修改 `pubspec.yaml` 并展示新版本号给用户确认

## 步骤 3: 构建并上传

运行：
```bash
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
```

ExportOptions.plist 配置了 `destination: upload`，构建完成后会自动上传到 App Store Connect，**不需要 Transporter**。

### 判断是否成功

- 如果输出包含 `Built IPA to` → 完全成功
- 如果输出包含 `Starting upload` 和 `Progress` 日志但最后报 `PathNotFoundException` → 上传已成功，这是 Flutter 的已知 bug（统计文件大小时崩溃），可以忽略
- 如果报 `Redundant Binary Upload` → build number 已被使用，回到步骤 2 继续递增
- 如果报签名或证书错误 → 停下来让用户检查 Xcode 签名配置
- 其他错误 → 尝试 `flutter clean` 后重试一次

上传后 Apple 需要几分钟处理构建，用户会收到邮件通知。

## 步骤 4: 提交 Git 并推送

```bash
git add pubspec.yaml
git commit -m "chore: bump version to X.Y.Z+N for App Store upload"
git push origin master
```

## 步骤 5: 生成 What's New

1. 找到上一次版本 bump 的 commit：`git log --oneline --grep="bump version"` 取第二条（第一条是刚才的）
2. 运行 `git log --oneline <上次bump commit>..HEAD` 查看所有变更
3. 用简洁、面向用户的英文总结变更：
   - 不写技术细节（不提 minimax、refactor、函数名等）
   - 每条一行，用 `- ` 开头
   - 最后加一条 `- Bug fixes and stability improvements`
4. 展示给用户确认
5. 用户确认后，将 What's New 文本写入临时文件再复制到剪贴板：
   ```bash
   cat <<'EOF' | pbcopy
   （这里放生成的 What's New 文本，每行一条）
   EOF
   ```
   注意：不要用 echo，避免 shell 转义问题。只复制 What's New 文本本身，不要包含其他内容。

## 步骤 6: 提交审查

提示用户：
1. 打开 https://appstoreconnect.apple.com → HexGomoku
2. 如需新建版本，点击"+" 添加版本号
3. 等 build 处理完成后选择刚上传的构建
4. 在"此版本的新增内容"粘贴 What's New（已在剪贴板）
5. 点击"提交以供审查"

## 项目信息

- Bundle ID: `com.hexgomoku.hexgomoku`
- Team ID: `NLCJF28Y8U`
- App ID: `6759946555`
