#!/bin/bash

# Microsoft Defender for Endpoint macOS 簡易動作確認スクリプト
# 4つの主要項目をチェック：
# 1. ネットワークとクラウド間の接続検証
# 2. クラウド保護検証
# 3. リアルタイム保護検証
# 4. プロパティリストの検証

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
    echo "  -b オプションを使用すると、Microsoftの公式デモスクリプトを実行して"
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
OUTPUT_FILE="$SCRIPT_DIR/mde_macos_check_result_$(date +%Y%m%d_%H%M%S).txt"

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

# メイン処理開始
echo "Microsoft Defender for Endpoint macOS 簡易動作確認" | tee "$OUTPUT_FILE"
echo "実行開始時刻: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$OUTPUT_FILE"
echo "結果ファイル: $OUTPUT_FILE" | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

# 事前チェック：mdatpコマンドの存在確認
if ! command -v mdatp &> /dev/null; then
    print_result "ERROR" "mdatpコマンドが見つかりません。Microsoft Defender for Endpointがインストールされていない可能性があります。"
    echo "" | tee -a "$OUTPUT_FILE"
    echo "確認を中止します。" | tee -a "$OUTPUT_FILE"
    exit 1
fi

print_result "OK" "mdatpコマンドが見つかりました"
echo "" | tee -a "$OUTPUT_FILE"

# 1. リアルタイム保護検証
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

# エンジン有効状態も確認
engine_enabled=$(mdatp health --field engine_enabled 2>/dev/null)
case "$engine_enabled" in
    "1"|"true")
        print_result "OK" "ウイルス対策エンジン: 有効"
        ;;
    "0"|"false")
        print_result "ERROR" "ウイルス対策エンジン: 無効"
        ;;
    *)
        print_result "WARNING" "ウイルス対策エンジンの状態を取得できませんでした (戻り値: $engine_enabled)"
        ;;
esac

# 動作監視のデモテスト（オプション）
echo "Debug: BEHAVIOR_TEST = $BEHAVIOR_TEST" | tee -a "$OUTPUT_FILE"
if [ "$BEHAVIOR_TEST" = "true" ]; then
    echo "" | tee -a "$OUTPUT_FILE"
    print_result "INFO" "動作監視デモテストを実行中..."
    print_result "WARNING" "これは実際に脅威として検出される可能性があります"
    
    # 一時的なテストスクリプトを作成
    test_script="/tmp/BM_test_$(date +%s).sh"
    cat > "$test_script" << 'EOF'
#!/usr/bin/bash
echo " " >> /tmp/9a74c69a-acdc-4c6d-84a2-0410df8ee480.txt
echo " " >> /tmp/f918b422-751c-423e-bfe1-dbbb2ab4385a.txt
sleep 5
EOF

    chmod +x "$test_script"
    
    print_result "INFO" "動作監視テストスクリプトを実行中... ($test_script)"
    
    # macOSではtimeoutコマンドが標準で利用できないため、代替実装
    # バックグラウンドでスクリプトを実行し、一定時間後に停止
    bash "$test_script" &
    script_pid=$!
    
    # 10秒間待機
    sleep_count=0
    max_sleep=10
    script_killed=false
    
    while [ $sleep_count -lt $max_sleep ]; do
        if ! kill -0 "$script_pid" 2>/dev/null; then
            # プロセスが既に終了している
            wait "$script_pid"
            script_exit_code=$?
            break
        fi
        sleep 1
        sleep_count=$((sleep_count + 1))
    done
    
    # まだ実行中の場合は強制終了
    if kill -0 "$script_pid" 2>/dev/null; then
        print_result "INFO" "テストスクリプトを強制終了中..."
        kill -TERM "$script_pid" 2>/dev/null
        sleep 1
        if kill -0 "$script_pid" 2>/dev/null; then
            kill -KILL "$script_pid" 2>/dev/null
        fi
        script_killed=true
        script_exit_code=143  # SIGTERM
    fi
    
    # 結果の判定
    if [ "$script_killed" = true ]; then
        print_result "OK" "テストスクリプトが強制終了されました（動作監視が動作している可能性があります）"
    elif [ $script_exit_code -eq 0 ]; then
        print_result "WARNING" "テストスクリプトが正常終了しました（動作監視が無効の可能性があります）"
    else
        print_result "INFO" "テストスクリプトが終了しました（終了コード: $script_exit_code）"
    fi
    
    # 少し待ってから脅威検出を確認
    sleep 2
    print_result "INFO" "脅威検出リストを確認中..."
    
    recent_threats=$(mdatp threat list 2>/dev/null | grep -E "(MacOSChangeFileTest|$(date +%Y-%m-%d))" || echo "")
    
    if [ -n "$recent_threats" ]; then
        print_result "OK" "動作監視による脅威検出: 成功"
        echo "--- 検出された脅威詳細 ---" | tee -a "$OUTPUT_FILE"
        echo "$recent_threats" | tee -a "$OUTPUT_FILE"
        echo "--- 脅威詳細終了 ---" | tee -a "$OUTPUT_FILE"
    else
        print_result "INFO" "最近の脅威検出はありませんでした（MacOSChangeFileTestが見つかりませんでした）"
    fi
    
    # テストファイルをクリーンアップ
    rm -f "$test_script" 2>/dev/null
    rm -f /tmp/9a74c69a-acdc-4c6d-84a2-0410df8ee480.txt 2>/dev/null
    rm -f /tmp/f918b422-751c-423e-bfe1-dbbb2ab4385a.txt 2>/dev/null
    
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
    "1"|"true")
        print_result "OK" "自動サンプル送信: 有効"
        ;;
    "0"|"false")
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

# 4. プロパティリストの検証
print_header "4. プロパティリストの検証"

# 主要な設定ファイルの存在と検証
plist_files=(
    "/Library/Managed Preferences/com.microsoft.wdav.plist"
    "/Library/Application Support/Microsoft/Defender/com.microsoft.wdav.plist"
)

plist_found=false

for plist_file in "${plist_files[@]}"; do
    if [ -f "$plist_file" ]; then
        print_result "INFO" "プロパティリストファイル発見: $plist_file"
        plist_found=true
        
        # プロパティリストの構文チェック
        if plutil -lint "$plist_file" >/dev/null 2>&1; then
            print_result "OK" "プロパティリスト構文: 正常 ($plist_file)"
        else
            print_result "ERROR" "プロパティリスト構文: エラー ($plist_file)"
        fi
        
        # ファイルサイズチェック（空ファイルでないか）
        file_size=$(stat -f%z "$plist_file" 2>/dev/null || echo "0")
        if [ "$file_size" -gt 0 ]; then
            print_result "OK" "プロパティリストサイズ: $file_size バイト ($plist_file)"
        else
            print_result "WARNING" "プロパティリストが空またはアクセスできません ($plist_file)"
        fi
        
        # プロパティリストの実際の内容を出力
        echo "" | tee -a "$OUTPUT_FILE"
        echo "--- プロパティリスト内容開始: $(basename "$plist_file") ---" | tee -a "$OUTPUT_FILE"
        
        # 人間が読みやすい形式で出力を試行
        if plutil -p "$plist_file" 2>/dev/null | tee -a "$OUTPUT_FILE"; then
            print_result "OK" "プロパティリスト内容: 正常に読み取りました"
        else
            # 代替方法として defaults read を使用
            echo "plutil での読み取りに失敗。defaults read を試行中..." | tee -a "$OUTPUT_FILE"
            if defaults read "${plist_file%.plist}" 2>/dev/null | tee -a "$OUTPUT_FILE"; then
                print_result "OK" "プロパティリスト内容: defaults read で読み取り成功"
            else
                # 最後の手段として生のXMLを出力
                echo "defaults read も失敗。生XMLを出力中..." | tee -a "$OUTPUT_FILE"
                if cat "$plist_file" 2>/dev/null | tee -a "$OUTPUT_FILE"; then
                    print_result "WARNING" "プロパティリスト内容: 生XML形式で出力"
                else
                    print_result "ERROR" "プロパティリスト内容: 読み取りに失敗しました"
                fi
            fi
        fi
        
        echo "--- プロパティリスト内容終了: $(basename "$plist_file") ---" | tee -a "$OUTPUT_FILE"
        echo "" | tee -a "$OUTPUT_FILE"
        
    else
        print_result "INFO" "プロパティリストファイル未発見: $plist_file"
    fi
done

if [ "$plist_found" = false ]; then
    print_result "WARNING" "管理用プロパティリストファイルが見つかりません（デフォルト設定で動作している可能性があります）"
    
    # デフォルト設定の確認
    echo "" | tee -a "$OUTPUT_FILE"
    echo "--- デフォルト設定値の確認 ---" | tee -a "$OUTPUT_FILE"
    print_result "INFO" "mdatpコマンドから直接設定値を取得中..."
    
    # 主要な設定値をmdatpコマンドから取得
    key_settings=(
        "real_time_protection_enabled:リアルタイム保護"
        "cloud_enabled:クラウド保護"
        "automatic_sample_submission:自動サンプル送信"
        "automatic_definition_update_enabled:自動定義更新"
        "licensed:ライセンス状態"
        "healthy:全体的な健全性"
        "engine_enabled:エンジン有効状態"
        "full_disk_access_enabled:フルディスクアクセス"
        "network_protection_enabled:ネットワーク保護"
        "tamper_protection_enabled:改ざん防止"
    )
    
    for setting in "${key_settings[@]}"; do
        key=$(echo "$setting" | cut -d':' -f1)
        description=$(echo "$setting" | cut -d':' -f2)
        
        value=$(mdatp health --field "$key" 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$value" ]; then
            echo "$description: $value" | tee -a "$OUTPUT_FILE"
        else
            echo "$description: 取得できませんでした" | tee -a "$OUTPUT_FILE"
        fi
    done
    
    echo "--- デフォルト設定値の確認終了 ---" | tee -a "$OUTPUT_FILE"
    echo "" | tee -a "$OUTPUT_FILE"
fi

# Defenderプロセスの動作確認（プロパティリストが正しく読み込まれているかの間接確認）
defender_process=$(pgrep -f "wdavdaemon" | head -1)
if [ -n "$defender_process" ]; then
    print_result "OK" "Defenderプロセス (wdavdaemon): 動作中 (PID: $defender_process)"
else
    print_result "ERROR" "Defenderプロセス (wdavdaemon): 停止中"
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

# プロセス実行
critical_total=$((critical_total + 1))
if [ -n "$defender_process" ]; then
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