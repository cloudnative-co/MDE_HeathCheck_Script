#!/bin/bash

# Microsoft Defender for Endpoint Linux 動作確認スクリプト
# 4つの主要項目をチェック：
# 1. リアルタイム保護検証
# 2. クラウド保護検証
# 3. ネットワークとクラウド間の接続検証
# 4. 構成プロファイル・crontab検証

# 使用方法表示
show_usage() {
    echo "使用方法: $0 [オプション]"
    echo ""
    echo "オプション:"
    echo "  -h, --help           このヘルプを表示"
    echo "  -v, --verbose        詳細モードで実行"
    echo "  -b, --behavior-test  動作監視のデモテストを実行（注意：実際に脅威として検出されます）"
    echo ""
    echo "このスクリプトは Microsoft Defender for Endpoint の動作状態を確認します。"
    echo ""
    echo "動作監視テストについて:"
    echo "  -b オプションを使用すると、疑似的な脅威活動をシミュレートして"
    echo "  動作監視機能が正常に動作しているかをテストします。"
    echo "  このテストは実際に脅威として検出され、企業環境では管理者に通知される"
    echo "  可能性があるため、事前に管理者の許可を得てから実行してください。"
}

# 変数の初期化
BEHAVIOR_TEST=false

# コマンドライン引数の処理
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -v|--verbose)
            set -x
            shift
            ;;
        -b|--behavior-test)
            BEHAVIOR_TEST=true
            echo "警告: 動作監視デモテストが有効になりました。"
            echo "このテストは実際に脅威として検出される可能性があります。"
            echo "企業環境では管理者に通知される場合があります。"
            echo -n "続行しますか？ (y/N): "
            read -r confirmation
            if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
                echo "テストをキャンセルしました。"
                exit 0
            fi
            shift
            ;;
        *)
            echo "不明なオプション: $1"
            show_usage
            exit 1
            ;;
    esac
done

# 結果出力ファイル（スクリプトと同じディレクトリに作成）
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_FILE="$SCRIPT_DIR/mde_linux_check_result_$(date +%Y%m%d_%H%M%S).txt"

# デバッグ情報
echo "Debug: 設定確認"
echo "BEHAVIOR_TEST = $BEHAVIOR_TEST"
echo "OUTPUT_FILE = $OUTPUT_FILE"
echo ""

# ヘッダー出力
print_header() {
    echo "========================================" | tee -a "$OUTPUT_FILE"
    echo "$1" | tee -a "$OUTPUT_FILE"
    echo "========================================" | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
}

# 結果出力
print_result() {
    local status="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$status" in
        "OK")
            echo "[$timestamp] ✓ $message" | tee -a "$OUTPUT_FILE"
            ;;
        "WARNING")
            echo "[$timestamp] ⚠ $message" | tee -a "$OUTPUT_FILE"
            ;;
        "ERROR")
            echo "[$timestamp] ✗ $message" | tee -a "$OUTPUT_FILE"
            ;;
        "INFO")
            echo "[$timestamp] ℹ $message" | tee -a "$OUTPUT_FILE"
            ;;
    esac
}

# Linuxディストリビューション検出
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    else
        echo "unknown"
    fi
}

# メイン処理開始
echo "Microsoft Defender for Endpoint Linux 動作確認" | tee "$OUTPUT_FILE"
echo "実行開始時刻: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$OUTPUT_FILE"
echo "結果ファイル: $OUTPUT_FILE" | tee -a "$OUTPUT_FILE"
echo "OS: $(detect_distro)" | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

# 事前チェック：mdatpコマンドの存在確認
if ! command -v mdatp &> /dev/null; then
    print_result "ERROR" "mdatpコマンドが見つかりません。Microsoft Defender for Endpointがインストールされていない可能性があります。"
    echo "" | tee -a "$OUTPUT_FILE"
    echo "確認を中止します。" | tee -a "$OUTPUT_FILE"
    exit 1
fi

print_result "OK" "mdatpコマンドが見つかりました"

# バージョン情報取得
version=$(mdatp version 2>/dev/null)
if [ $? -eq 0 ]; then
    print_result "INFO" "バージョン: $version"
fi

echo "" | tee -a "$OUTPUT_FILE"

# 1. リアルタイム保護・動作監視検証
print_header "1. リアルタイム保護・動作監視検証"

rtp_status=$(mdatp health --field real_time_protection_enabled 2>/dev/null)
case "$rtp_status" in
    "1"|"true")
        print_result "OK" "リアルタイム保護: 有効"
        ;;
    "0"|"false")
        print_result "ERROR" "リアルタイム保護: 無効"
        ;;
    *)
        print_result "WARNING" "リアルタイム保護の状態を取得できませんでした (戻り値: $rtp_status)"
        ;;
esac

# 適用レベルの確認
enforcement_level=$(mdatp health --field enforcement_level 2>/dev/null)
case "$enforcement_level" in
    "real_time")
        print_result "OK" "適用レベル: リアルタイム保護モード"
        ;;
    "on_demand")
        print_result "WARNING" "適用レベル: オンデマンドモード（リアルタイム保護は無効）"
        ;;
    "passive")
        print_result "INFO" "適用レベル: パッシブモード（他のウイルス対策製品と共存）"
        ;;
    *)
        print_result "WARNING" "適用レベルを取得できませんでした (戻り値: $enforcement_level)"
        ;;
esac

# 動作監視の状態確認
behavior_monitoring=$(mdatp health --field behavior_monitoring 2>/dev/null)
case "$behavior_monitoring" in
    "1"|"true"|"enabled")
        print_result "OK" "動作監視: 有効"
        ;;
    "0"|"false"|"disabled")
        print_result "WARNING" "動作監視: 無効"
        ;;
    *)
        print_result "WARNING" "動作監視の状態を取得できませんでした (戻り値: $behavior_monitoring)"
        ;;
esac

# 動作監視のデモテスト（オプション）
echo "Debug: BEHAVIOR_TEST = $BEHAVIOR_TEST" | tee -a "$OUTPUT_FILE"
if [ "$BEHAVIOR_TEST" = "true" ]; then
    echo "" | tee -a "$OUTPUT_FILE"
    print_result "INFO" "動作監視デモテストを実行中..."
    print_result "WARNING" "これは実際に脅威として検出される可能性があります"
    
    # Linux用の簡易的な動作監視テスト
    test_script="/tmp/behavior_test_$(date +%s).sh"
    cat > "$test_script" << 'EOF'
#!/bin/bash
# 疑似的な脅威活動をシミュレート
echo "behavior_test_$(date)" > /tmp/suspicious_file_$(date +%s).txt
chmod +x /tmp/suspicious_file_*.txt 2>/dev/null
sleep 3
rm -f /tmp/suspicious_file_*.txt 2>/dev/null
EOF

    chmod +x "$test_script"
    
    print_result "INFO" "動作監視テストスクリプトを実行中... ($test_script)"
    
    # Linux用のタイムアウト処理（timeoutコマンドが利用可能な場合は使用）
    if command -v timeout &> /dev/null; then
        if timeout 10s bash "$test_script" 2>&1 | tee -a "$OUTPUT_FILE"; then
            print_result "WARNING" "テストスクリプトが正常終了しました（動作監視が無効の可能性があります）"
        else
            exit_code=$?
            case $exit_code in
                124)
                    print_result "WARNING" "テストスクリプトがタイムアウトしました"
                    ;;
                137|143)
                    print_result "OK" "テストスクリプトが強制終了されました（動作監視が動作している可能性があります）"
                    ;;
                *)
                    print_result "INFO" "テストスクリプトが終了しました（終了コード: $exit_code）"
                    ;;
            esac
        fi
    else
        # timeoutコマンドが利用できない場合のフォールバック
        bash "$test_script" &
        script_pid=$!
        sleep 10
        if kill -0 "$script_pid" 2>/dev/null; then
            kill -TERM "$script_pid" 2>/dev/null
            print_result "WARNING" "テストスクリプトを手動で終了しました"
        fi
    fi
    
    # 少し待ってから脅威検出を確認
    sleep 2
    print_result "INFO" "脅威検出リストを確認中..."
    
    recent_threats=$(mdatp threat list 2>/dev/null | grep -E "($(date +%Y-%m-%d))" || echo "")
    
    if [ -n "$recent_threats" ]; then
        print_result "OK" "動作監視による脅威検出: 成功"
        echo "--- 検出された脅威詳細 ---" | tee -a "$OUTPUT_FILE"
        echo "$recent_threats" | tee -a "$OUTPUT_FILE"
        echo "--- 脅威詳細終了 ---" | tee -a "$OUTPUT_FILE"
    else
        print_result "INFO" "最近の脅威検出はありませんでした"
    fi
    
    # テストファイルをクリーンアップ
    rm -f "$test_script" 2>/dev/null
    rm -f /tmp/suspicious_file_*.txt 2>/dev/null
    
    print_result "INFO" "動作監視デモテスト完了（テストファイルを削除しました）"
fi

echo "" | tee -a "$OUTPUT_FILE"

# 2. クラウド保護検証
print_header "2. クラウド保護検証"

# クラウド保護有効状態
cloud_enabled=$(mdatp health --field cloud_enabled 2>/dev/null)
case "$cloud_enabled" in
    "1"|"true")
        print_result "OK" "クラウド保護: 有効"
        ;;
    "0"|"false")
        print_result "WARNING" "クラウド保護: 無効"
        ;;
    *)
        print_result "WARNING" "クラウド保護の状態を取得できませんでした (戻り値: $cloud_enabled)"
        ;;
esac

# 自動サンプル送信状態
auto_sample=$(mdatp health --field automatic_sample_submission 2>/dev/null)
case "$auto_sample" in
    "1"|"true"|"safe"|"all")
        print_result "OK" "自動サンプル送信: 有効 ($auto_sample)"
        ;;
    "0"|"false"|"none")
        print_result "INFO" "自動サンプル送信: 無効 (設定により正常な場合があります)"
        ;;
    *)
        print_result "WARNING" "自動サンプル送信の状態を取得できませんでした (戻り値: $auto_sample)"
        ;;
esac

# 自動定義更新状態
auto_def_update=$(mdatp health --field automatic_definition_update_enabled 2>/dev/null)
case "$auto_def_update" in
    "1"|"true")
        print_result "OK" "自動定義更新: 有効"
        ;;
    "0"|"false")
        print_result "WARNING" "自動定義更新: 無効"
        ;;
    *)
        print_result "WARNING" "自動定義更新の状態を取得できませんでした (戻り値: $auto_def_update)"
        ;;
esac

# 診断レベル
diagnostic_level=$(mdatp health --field diagnostic_level 2>/dev/null)
if [ -n "$diagnostic_level" ]; then
    print_result "INFO" "診断レベル: $diagnostic_level"
fi

echo "" | tee -a "$OUTPUT_FILE"

# 3. ネットワークとクラウド間の接続検証
print_header "3. ネットワークとクラウド間の接続検証"

print_result "INFO" "クラウドサービスとの接続テストを実行中..."
echo "" | tee -a "$OUTPUT_FILE"

# mdatp connectivity testを実行
connectivity_output=$(mdatp connectivity test 2>&1)
connectivity_exit_code=$?

if [ $connectivity_exit_code -eq 0 ]; then
    print_result "OK" "接続テスト: 成功"
    echo "--- 接続テスト詳細結果 ---" | tee -a "$OUTPUT_FILE"
    echo "$connectivity_output" | tee -a "$OUTPUT_FILE"
    echo "--- 接続テスト詳細結果終了 ---" | tee -a "$OUTPUT_FILE"
else
    print_result "ERROR" "接続テスト: 失敗 (終了コード: $connectivity_exit_code)"
    echo "--- 接続テストエラー詳細 ---" | tee -a "$OUTPUT_FILE"
    echo "$connectivity_output" | tee -a "$OUTPUT_FILE"
    echo "--- 接続テストエラー詳細終了 ---" | tee -a "$OUTPUT_FILE"
fi

echo "" | tee -a "$OUTPUT_FILE"

# 追加の基本的な接続確認（手動テスト）
print_result "INFO" "追加の基本接続確認を実行中..."

# 主要なエンドポイントへの接続確認
test_urls=(
    "https://x.cp.wd.microsoft.com/api/report"
    "https://cdn.x.cp.wd.microsoft.com/ping"
)

for url in "${test_urls[@]}"; do
    if curl -s --connect-timeout 10 "$url" >/dev/null 2>&1; then
        print_result "OK" "接続確認: $url"
    else
        print_result "WARNING" "接続確認失敗: $url"
    fi
done

echo "" | tee -a "$OUTPUT_FILE"

# 4. 構成プロファイル・crontab検証
print_header "4. 構成プロファイル・crontab検証"

# 構成プロファイルの確認
config_file="/etc/opt/microsoft/mdatp/managed/mdatp_managed.json"

if [ -f "$config_file" ]; then
    print_result "OK" "構成プロファイルファイル発見: $config_file"
    
    # JSON構文チェック
    if command -v python3 &> /dev/null; then
        if python3 -m json.tool "$config_file" >/dev/null 2>&1; then
            print_result "OK" "構成プロファイル構文: 正常"
        else
            print_result "ERROR" "構成プロファイル構文: エラー"
        fi
    elif command -v python &> /dev/null; then
        if python -m json.tool "$config_file" >/dev/null 2>&1; then
            print_result "OK" "構成プロファイル構文: 正常"
        else
            print_result "ERROR" "構成プロファイル構文: エラー"
        fi
    else
        print_result "WARNING" "JSON構文チェックツールが見つかりません（pythonが必要）"
    fi
    
    # ファイルサイズチェック
    file_size=$(stat -c%s "$config_file" 2>/dev/null || echo "0")
    if [ "$file_size" -gt 0 ]; then
        print_result "OK" "構成プロファイルサイズ: $file_size バイト"
    else
        print_result "WARNING" "構成プロファイルが空またはアクセスできません"
    fi
    
    # 構成プロファイルの内容を出力
    echo "" | tee -a "$OUTPUT_FILE"
    echo "--- 構成プロファイル内容開始 ---" | tee -a "$OUTPUT_FILE"
    
    if command -v python3 &> /dev/null; then
        if python3 -m json.tool "$config_file" 2>/dev/null | tee -a "$OUTPUT_FILE"; then
            print_result "OK" "構成プロファイル内容: 正常に読み取りました"
        else
            cat "$config_file" 2>/dev/null | tee -a "$OUTPUT_FILE"
            print_result "WARNING" "構成プロファイル内容: 生JSON形式で出力"
        fi
    else
        cat "$config_file" 2>/dev/null | tee -a "$OUTPUT_FILE"
        print_result "INFO" "構成プロファイル内容: 生JSON形式で出力"
    fi
    
    echo "--- 構成プロファイル内容終了 ---" | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
    
else
    print_result "INFO" "構成プロファイルファイル未発見: $config_file"
    print_result "INFO" "デフォルト設定またはコマンドライン設定で動作している可能性があります"
fi

# crontabの確認
print_result "INFO" "Microsoft Defender for Endpoint関連のcrontabエントリを確認中..."

# rootのcrontabを確認
root_crontab=$(crontab -l 2>/dev/null | grep -i "mdatp\|defender" || echo "")
if [ -n "$root_crontab" ]; then
    print_result "OK" "rootのcrontabでDefender関連エントリを発見"
    echo "--- rootのcrontab（Defender関連）---" | tee -a "$OUTPUT_FILE"
    echo "$root_crontab" | tee -a "$OUTPUT_FILE"
    echo "--- rootのcrontab終了 ---" | tee -a "$OUTPUT_FILE"
else
    print_result "INFO" "rootのcrontabにDefender関連エントリはありません"
fi

# システム全体のcron.dを確認
cron_d_files=$(find /etc/cron.d/ -name "*mdatp*" -o -name "*defender*" 2>/dev/null || echo "")
if [ -n "$cron_d_files" ]; then
    print_result "OK" "/etc/cron.d/でDefender関連ファイルを発見"
    for file in $cron_d_files; do
        echo "--- $file の内容 ---" | tee -a "$OUTPUT_FILE"
        cat "$file" 2>/dev/null | tee -a "$OUTPUT_FILE"
        echo "--- $file 終了 ---" | tee -a "$OUTPUT_FILE"
    done
else
    print_result "INFO" "/etc/cron.d/にDefender関連ファイルはありません"
fi

# ディストリビューション別の更新コマンドの推奨事項
distro=$(detect_distro)
echo "" | tee -a "$OUTPUT_FILE"
print_result "INFO" "検出されたディストリビューション: $distro"

case "$distro" in
    "rhel"|"centos"|"fedora"|"ol")
        print_result "INFO" "推奨更新コマンド: sudo yum update mdatp"
        ;;
    "sles"|"opensuse"*)
        print_result "INFO" "推奨更新コマンド: sudo zypper update mdatp"
        ;;
    "ubuntu"|"debian")
        print_result "INFO" "推奨更新コマンド: sudo apt-get install --only-upgrade mdatp"
        ;;
    *)
        print_result "INFO" "不明なディストリビューション。手動での更新方法を確認してください"
        ;;
esac

# サービス状態確認
print_result "INFO" "Defenderサービス状態を確認中..."

if systemctl is-active mdatp >/dev/null 2>&1; then
    print_result "OK" "mdatpサービス: アクティブ"
else
    print_result "WARNING" "mdatpサービス: 非アクティブまたは確認できません"
fi

if systemctl is-enabled mdatp >/dev/null 2>&1; then
    print_result "OK" "mdatpサービス: 自動起動有効"
else
    print_result "WARNING" "mdatpサービス: 自動起動無効"
fi

echo "" | tee -a "$OUTPUT_FILE"

# 5. 総合判定
print_header "5. 総合判定"

# 重要な項目をカウント
critical_ok=0
critical_total=0

# リアルタイム保護
critical_total=$((critical_total + 1))
if [ "$rtp_status" = "1" ] || [ "$rtp_status" = "true" ]; then
    critical_ok=$((critical_ok + 1))
fi

# 接続テスト
critical_total=$((critical_total + 1))
if [ $connectivity_exit_code -eq 0 ]; then
    critical_ok=$((critical_ok + 1))
fi

# サービス実行
critical_total=$((critical_total + 1))
if systemctl is-active mdatp >/dev/null 2>&1; then
    critical_ok=$((critical_ok + 1))
fi

# 判定結果
if [ "$critical_ok" -eq "$critical_total" ]; then
    print_result "OK" "総合判定: Microsoft Defender for Endpoint は正常に動作しています ($critical_ok/$critical_total)"
    exit_code=0
elif [ "$critical_ok" -gt 0 ]; then
    print_result "WARNING" "総合判定: 一部の機能に問題がある可能性があります ($critical_ok/$critical_total)"
    exit_code=1
else
    print_result "ERROR" "総合判定: 重大な問題が検出されました ($critical_ok/$critical_total)"
    exit_code=2
fi

echo "" | tee -a "$OUTPUT_FILE"
echo "確認完了時刻: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$OUTPUT_FILE"
echo "結果は $OUTPUT_FILE に保存されました" | tee -a "$OUTPUT_FILE"

exit $exit_code