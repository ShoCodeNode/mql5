# MySimpleEA 仕様書（日本語）

## 1. 概要
`MySimpleEA` は、前バーの実体方向（陽線/陰線）に基づくシンプルなエントリーを行う MQL5 Expert Advisor です。  
再現性を高めるため、新規バー確定時のみ売買判定を行います。

## 2. 使用インジケータ
- 標準インジケータは未使用
- 価格系列関数（`iOpen`, `iClose`, `iTime`）を使用

## 3. パラメータ設定
- `input_MagicNumber`（int, 26022801）: 識別用マジックナンバー
- `input_LotSize`（double, 0.10）: 固定ロット
- `input_StopLossPoints`（int, 300）: 損切りポイント
- `input_TakeProfitPoints`（int, 600）: 利確ポイント
- `input_MaxSpreadPoints`（int, 30）: 許容最大スプレッド
- `input_AllowLong`（bool, true）: 買いエントリー許可
- `input_AllowShort`（bool, false）: 売りエントリー許可

## 4. エントリー/エグジット条件
- エントリー判定タイミング: 新規バー時のみ
- エントリー前条件:
  - 同一シンボルかつ同一マジック番号のポジションがない
  - スプレッドが `input_MaxSpreadPoints` 以下
- 買い条件:
  - `input_AllowLong == true`
  - 前バーが陽線（`Close[1] > Open[1]`）
- 売り条件:
  - `input_AllowShort == true`
  - 前バーが陰線（`Close[1] < Open[1]`）
- エグジット:
  - 注文時に固定 SL/TP を設定

## 5. リスク管理
- `input_MagicNumber` によるポジション識別
- スプレッドフィルタで不利な約定を抑制
- ロットはシンボルの最小・最大・ステップに正規化
- 注文失敗時は `GetLastError()` と `ResultRetcode()` をログ出力

## 6. 変更履歴
- 2026-02-28: 初版作成（EA新規作成、日英仕様書作成）
