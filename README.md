# Microsoft Defender for Endpoint ヘルスチェックスクリプト

Microsoft Defender for Endpoint（MDE）の動作状態を確認するためのスクリプト集です。各OS（macOS、Linux、Windows）向けに最適化されたスクリプトを提供しています。

## 概要

これらのスクリプトは、Microsoft Defender for Endpointの以下の主要機能を検証します：

1. **リアルタイム保護検証** - リアルタイム保護と動作監視機能の状態確認
2. **クラウド保護検証** - クラウドベースの保護機能と自動サンプル送信の確認
3. **ネットワーク接続検証** - MDEクラウドサービスへの接続状態の確認
4. **構成検証** - 設定ファイルやプロファイルの整合性チェック

## ファイル構成

- `mde_health_check_macOS.sh` - macOS用スクリプト
- `mde_health_check_Linux.sh` - Linux用スクリプト
- `mde_health_check_windows.ps1` - Windows用PowerShellスクリプト

## 使用方法

### macOS

```bash
# 基本的な実行
bash mde_health_check_macOS.sh

# 詳細モードで実行
bash mde_health_check_macOS.sh -v

# 動作監視テストを含めて実行（管理者の許可が必要）
bash mde_health_check_macOS.sh -b

# ヘルプを表示
bash mde_health_check_macOS.sh -h
```

### Linux

```bash
# 基本的な実行
sudo bash mde_health_check_Linux.sh

# 詳細モードで実行
sudo bash mde_health_check_Linux.sh -v

# 動作監視テストを含めて実行（管理者の許可が必要）
sudo bash mde_health_check_Linux.sh -b

# ヘルプを表示
bash mde_health_check_Linux.sh -h
```

**注意**: Linux環境では、多くのMDEコマンドにroot権限が必要なため、`sudo`での実行を推奨します。

### Windows

```powershell
# 管理者権限でPowerShellを開いて実行

# 基本的な実行
.\mde_health_check_windows.ps1

# 動作監視テストを含めて実行
.\mde_health_check_windows.ps1 -BehaviorTest

# ヘルプを表示
.\mde_health_check_windows.ps1 -Help
```

**注意**: Windowsでは必ず管理者権限でPowerShellを実行してください。

## オプション

### 共通オプション（macOS/Linux）

- `-h, --help` - ヘルプメッセージを表示
- `-v, --verbose` - 詳細モードで実行（デバッグ情報を表示）
- `-b, --behavior-test` - 動作監視機能のテストを実行

### Windowsオプション

- `-Help` - ヘルプメッセージを表示
- `-BehaviorTest` - 動作監視機能のテストを実行

## 動作監視テストについて

`-b`（Linux/macOS）または `-BehaviorTest`（Windows）オプションを使用すると、MDEの動作監視機能が正常に動作しているかをテストします。

**重要な注意事項**:
- このテストは実際に脅威として検出される可能性があります
- 企業環境では管理者やセキュリティチームに通知される場合があります
- 実行前に必ず管理者の許可を得てください
- テストは自動的にクリーンアップされますが、脅威検出ログには記録が残ります

## 出力結果

各スクリプトは以下の形式で結果を出力します：

- **コンソール出力** - リアルタイムで状態を表示
- **ログファイル** - `mde_[OS]_check_result_[タイムスタンプ].txt`形式でスクリプトと同じディレクトリに保存

### 結果の見方

- ✓ または [OK] - 正常に動作している項目
- ⚠ または [WARNING] - 注意が必要な項目（設定により正常な場合もあります）
- ✗ または [ERROR] - 問題が検出された項目
- ℹ または [INFO] - 情報提供

## 必要な環境

### macOS
- macOS 10.15 (Catalina) 以降
- Microsoft Defender for Endpoint for Mac インストール済み
- `mdatp`コマンドへのアクセス権限

### Linux
- サポートされているLinuxディストリビューション（RHEL、Ubuntu、SLES等）
- Microsoft Defender for Endpoint for Linux インストール済み
- root権限またはsudoアクセス
- `mdatp`コマンドへのアクセス権限

### Windows
- Windows 10/11またはWindows Server 2016以降
- Microsoft Defender for Endpoint インストール済み
- PowerShell 5.1以降
- 管理者権限

## トラブルシューティング

### "mdatpコマンドが見つかりません"エラー

MDEが正しくインストールされていない可能性があります。公式ドキュメントに従ってインストールを確認してください。

### 接続テストが失敗する

- ファイアウォールやプロキシの設定を確認
- 必要なURLへのアクセスが許可されているか確認
- ネットワーク管理者に相談

### リアルタイム保護が無効と表示される

組織のポリシーによって無効化されている可能性があります。IT管理者に確認してください。

## セキュリティ上の注意事項

- これらのスクリプトは診断目的のみに使用してください
- 本番環境で実行する前に、必ずテスト環境で動作を確認してください
- 動作監視テストは実際の脅威として検出されるため、慎重に使用してください
- ログファイルには機密情報が含まれる可能性があるため、適切に管理してください

## 参考情報

- [Microsoft Defender for Endpoint ドキュメント](https://docs.microsoft.com/microsoft-365/security/defender-endpoint/)
- [MDEトラブルシューティングガイド](https://docs.microsoft.com/microsoft-365/security/defender-endpoint/troubleshoot-microsoft-defender-antivirus)

## ライセンス

これらのスクリプトは診断ツールとして提供されています。使用に際しては、各組織のセキュリティポリシーに従ってください。

## 免責事項

これらのスクリプトは「現状のまま」提供されており、いかなる保証もありません。使用による結果について、作成者は一切の責任を負いません。