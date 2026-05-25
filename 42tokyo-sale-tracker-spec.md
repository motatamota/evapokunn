# 42Tokyo Sale Tracker - 仕様書

42Tokyo のユーザーサイトで開催される「sale」を追跡し、開始/終了/次回予測を通知するクロスプラットフォームアプリ。

## 1. 要件サマリ

| 項目 | 内容 |
|---|---|
| プラットフォーム | Android / iOS |
| フレームワーク | **Flutter** (Dart) |
| 利用形態 | 個人利用（シングルユーザー） |
| 認証 | 端末内に資格情報を安全保存し、アプリ内で自動ログイン |
| データ取得 | 通知一覧をスクレイピング、約2時間ごとにバックグラウンド実行 |
| 通知 | ローカルプッシュ通知（sale 開始 / 終了 / 次回予測） |
| サーバー | 不要（端末完結） |

## 2. 技術スタック

```yaml
# pubspec.yaml の主要依存
dependencies:
  flutter:
    sdk: flutter

  # HTTP + Cookie セッション管理
  dio: ^5.4.0
  cookie_jar: ^4.0.8
  dio_cookie_manager: ^3.1.1

  # HTML パース
  html: ^0.15.4

  # 資格情報の安全保存
  flutter_secure_storage: ^9.0.0

  # ローカルDB（sale 履歴の永続化）
  drift: ^2.14.0
  sqlite3_flutter_libs: ^0.5.0
  path_provider: ^2.1.0
  path: ^1.8.0

  # バックグラウンド実行
  workmanager: ^0.5.2

  # ローカル通知
  flutter_local_notifications: ^16.3.0
  timezone: ^0.9.2

  # 状態管理
  flutter_riverpod: ^2.4.0

  # 日付ユーティリティ
  intl: ^0.19.0

dev_dependencies:
  drift_dev: ^2.14.0
  build_runner: ^2.4.0
```

## 3. アーキテクチャ

```
lib/
├── main.dart                          # エントリポイント、WorkManager 初期化
├── app.dart                           # MaterialApp
├── core/
│   ├── auth/
│   │   ├── credential_storage.dart    # FlutterSecureStorage ラッパ
│   │   └── auth_service.dart          # ログインフロー、セッション復元
│   ├── http/
│   │   ├── http_client.dart           # Dio + CookieJar の供給
│   │   └── interceptors.dart          # 401時の自動再ログイン
│   └── notifications/
│       └── notification_service.dart  # ローカル通知ラッパ
├── features/
│   ├── sale/
│   │   ├── data/
│   │   │   ├── sale_repository.dart       # フェッチ + 差分検出
│   │   │   ├── notification_parser.dart   # HTML → Sale モデル変換
│   │   │   └── sale_dao.dart              # drift DAO
│   │   ├── domain/
│   │   │   ├── sale.dart                  # Sale モデル (id, startAt, endAt, title)
│   │   │   └── sale_predictor.dart        # 次回予測ロジック
│   │   └── presentation/
│   │       ├── home_page.dart             # 現在/直近/次回予測表示
│   │       └── history_page.dart          # sale 履歴一覧
│   └── settings/
│       └── settings_page.dart         # ログイン情報、ポーリング間隔、通知設定
└── background/
    └── background_worker.dart         # WorkManager の callbackDispatcher
```

## 4. 主要コンポーネントの実装方針

### 4.1 認証 (`auth_service.dart`)

42Tokyo のユーザーサイト（Intra）は**フォームログイン + セッション Cookie** で認証。OAuth ではない。

```dart
// 擬似コード
class AuthService {
  final Dio _dio;
  final CookieJar _cookieJar;
  final CredentialStorage _storage;

  /// 1. ログインページ GET → CSRF トークン (authenticity_token) を抽出
  /// 2. POST /users/sign_in に email/password/token を送信
  /// 3. 成功時は Cookie が CookieJar に自動保存される
  /// 4. ログイン後ページの存在で成否を判定
  Future<bool> login(String email, String password) async { ... }

  /// 保存済み Cookie でアクセス試行 → 401/リダイレクトなら再ログイン
  Future<bool> ensureAuthenticated() async { ... }
}
```

**注意点**
- ログインフォームの URL・フィールド名は実サイトで確認すること（実装時に DevTools でリクエストを観察）
- 2要素認証が有効な場合は別途設計（初期実装ではスコープ外、TODO 化）
- Cookie の有効期限切れに備え、リクエスト前に `ensureAuthenticated()` を必ず呼ぶ
- `Dio` の `InterceptorsWrapper` で 401/302→ログインページへのリダイレクトを検知して自動再ログイン

### 4.2 資格情報の保存 (`credential_storage.dart`)

```dart
// FlutterSecureStorage は iOS Keychain / Android EncryptedSharedPreferences を使用
class CredentialStorage {
  static const _emailKey = 'ft_email';
  static const _passwordKey = 'ft_password';
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Future<void> save({required String email, required String password}) async { ... }
  Future<({String email, String password})?> read() async { ... }
  Future<void> clear() async { ... }
}
```

**iOS の `accessibility` は `first_unlock` 推奨**（バックグラウンドで取得できる必要があるため `unlocked` 不可）。

### 4.3 HTML パース (`notification_parser.dart`)

通知一覧ページから sale 関連の通知を抽出。

```dart
// 擬似コード
class NotificationParser {
  /// 通知一覧ページの HTML を入力に、Sale イベントのリストを返す
  List<SaleEvent> parse(String html) {
    final doc = html_parser.parse(html);
    // 通知アイテムの DOM 構造に応じてセレクタを選択
    // sale 関連を文言マッチで抽出（"sale", "セール" 等）
    // 開始/終了の判別、日時パース
  }
}

enum SaleEventType { start, end }
class SaleEvent {
  final SaleEventType type;
  final DateTime occurredAt;  // 通知が発生した時刻
  final String rawTitle;
  final String? sourceUrl;
}
```

**実装時に確認すべき点**
- 通知一覧の URL とページ構造
- sale 関連通知の文言パターン（開始通知と終了通知の見分け方）
- ページネーション有無、最新N件で十分か
- 日時のタイムゾーン（JST 想定だが要確認）

### 4.4 sale 履歴の永続化 (drift)

```dart
// Sales テーブル
class Sales extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get startAt => dateTime()();
  DateTimeColumn get endAt => dateTime().nullable()();  // 終了未検出なら null
  TextColumn get title => text()();
  DateTimeColumn get detectedAt => dateTime()();  // 検出時刻
}
```

通知パースで取得した SaleEvent を、開始イベントは新規 Sale 行として挿入、終了イベントは直近の終了未確定 Sale を更新する形で対応付ける。

### 4.5 次回予測 (`sale_predictor.dart`)

過去の sale 履歴から次回時期を予測。シンプルなロジックで十分。

```dart
class SalePredictor {
  /// 直近 N 回の sale 開始間隔から中央値を取り、最終 sale 開始日 + 中央値を予測値とする
  /// データが2件未満なら null
  PredictionResult? predict(List<Sale> history) { ... }
}

class PredictionResult {
  final DateTime expectedStart;
  final Duration uncertainty;  // 標準偏差を信頼区間として返す
  final int sampleSize;
}
```

**改善余地**（最初は不要）
- 曜日傾向の考慮
- 月初/月末バイアスの検出
- 平均ではなく中央値を使う（外れ値耐性）

### 4.6 バックグラウンド実行 (`workmanager`)

```dart
// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    'sale-check',
    'checkSale',
    frequency: const Duration(hours: 2),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );
  runApp(const ProviderScope(child: App()));
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, data) async {
    // 1. AuthService.ensureAuthenticated()
    // 2. 通知一覧ページを GET
    // 3. NotificationParser でパース
    // 4. 新規 sale 開始 → 通知 + DB 保存
    // 5. sale 終了検出 → 通知 + DB 更新
    return Future.value(true);
  });
}
```

**プラットフォーム制約（重要）**

- **Android**: `workmanager` の最小周期は 15 分。2時間は問題なし。Doze モードで遅延の可能性あり。
- **iOS**: バックグラウンド実行は OS が裁量で決定する。`BGAppRefreshTask` を登録しても**2時間ごとの実行は保証されない**。ユーザーがアプリをよく使うと頻度が上がり、使わないと数日に1回まで落ちる。これは iOS の仕様で回避不可。
- 確実性を上げるには別途サーバーを立ててプッシュ通知を送る構成が必要だが、今回は端末完結スコープなので**「ベストエフォート」で運用**する。

### 4.7 ローカル通知 (`notification_service.dart`)

```dart
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async { /* チャンネル登録、権限要求 */ }

  Future<void> notifySaleStarted(Sale sale) async { ... }
  Future<void> notifySaleEnded(Sale sale) async { ... }
  Future<void> notifyPredictedSale(PredictionResult prediction) async { ... }
}
```

iOS は通知権限を初回起動時にリクエスト。Android 13+ も `POST_NOTIFICATIONS` 権限要求が必要。

## 5. プラットフォーム別の設定

### Android (`android/app/src/main/AndroidManifest.xml`)

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
```

### iOS (`ios/Runner/Info.plist`)

```xml
<key>UIBackgroundModes</key>
<array>
  <string>fetch</string>
  <string>processing</string>
</array>
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
  <string>be.tramckrijte.workmanager.sale-check</string>
</array>
```

iOS は最小ターゲット 12.0 以上。

## 6. サイトへの配慮（重要）

42Tokyo のサイトに過剰な負荷をかけないこと。

- ポーリング間隔は2時間より短くしない
- 取得ページは**通知一覧のみ**（HTML を辿らない）
- `User-Agent` を識別可能なものに設定: `42TokyoSaleTracker/1.0 (personal use)`
- `If-Modified-Since` / `If-None-Match` ヘッダーで条件付き GET、304 なら以降の処理スキップ
- 連続エラー時は指数バックオフ（5分 → 15分 → 1時間 → 次の定期実行）
- レート制限らしき応答（429, 503）を受けたら最低6時間は停止

## 7. 画面構成（最低限）

| 画面 | 内容 |
|---|---|
| Home | 現在 sale 中か / 直近 sale 期間 / 次回予測 |
| History | 過去 sale 一覧（開始日・終了日・期間） |
| Settings | ログイン情報入力、手動更新ボタン、最終取得時刻 |

## 8. 実装順序（推奨）

1. プロジェクト初期化、依存追加、ディレクトリ構造作成
2. `CredentialStorage` + 簡易ログイン画面
3. `AuthService` でログイン成功確認（手動ボタンで実行）
4. 通知一覧 HTML を取得して画面に生表示 → DOM 構造を把握
5. `NotificationParser` 実装 + テスト
6. `drift` でローカル DB セットアップ、SaleEvent → Sale 変換
7. Home 画面で「sale 中か」「直近 sale」表示
8. `SalePredictor` 実装、Home に予測表示
9. `NotificationService` でローカル通知
10. `workmanager` でバックグラウンド実行を組み込み
11. エラーハンドリング、リトライ、バックオフ
12. iOS / Android 実機で動作確認

## 9. テスト方針

- `NotificationParser`: 実 HTML サンプルをフィクスチャ化してユニットテスト
- `SalePredictor`: 既知の sale 履歴で予測値が妥当か検証
- `AuthService`: モック Dio で 401 / 302 リトライ動作を検証
- バックグラウンド実行は実機での手動確認（`adb shell cmd jobscheduler run` でAndroid強制実行可）

## 10. 既知の制約・未確定事項（実装時に確認）

- 42Tokyo の通知一覧 URL とログインフォームの仕様 → DevTools で確認
- sale 通知の文言パターン → サンプル収集が必要
- 2FA が有効な場合の挙動 → スコープ外、TODO
- iOS のバックグラウンド実行頻度はベストエフォート
- 利用規約上スクレイピングが禁止されていないか念のため確認すること

## 11. 開発者へのお願い（Claude Code 向け補足）

- 実装前に `pubspec.yaml` のバージョンは `flutter pub outdated` で最新を確認
- 42Tokyo ユーザーサイトに**アクセスできない開発環境**の場合、`NotificationParser` のテストは手元のサンプル HTML を使うこと
- ログイン情報を含む通信のログ出力は **release ビルドでは無効化**すること（`kReleaseMode` でガード）
- Secure Storage の中身を `print` しないこと
