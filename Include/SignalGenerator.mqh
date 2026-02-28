//+------------------------------------------------------------------+
//|                                    SignalGenerator.mqh          |
//|                                  Copyright 2025, ShoCodeNode     |
//|                                       https://github.com/...     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ShoCodeNode"
#property link      "https://github.com/ShoCodeNode/mql5_scalping_strategy"

#include "ScalpingConfig.mqh"

//--- シグナル種類
enum ENUM_SIGNAL_TYPE
{
   SIGNAL_NONE = 0,       // シグナルなし
   SIGNAL_BUY = 1,        // 買いシグナル
   SIGNAL_SELL = -1       // 売りシグナル
};

//--- シグナル情報構造体
struct SignalInfo
{
   ENUM_SIGNAL_TYPE      type;              // シグナル種類
   double                strength;          // シグナル強度 (0-100)
   double                entry_price;       // エントリー価格
   double                stop_loss;         // ストップロス
   double                take_profit;       // テイクプロフィット
   string                reason;            // シグナル理由
   datetime              timestamp;         // シグナル時間
   bool                  is_valid;          // 有効性フラグ
};

//+------------------------------------------------------------------+
//| マルチタイムフレーム シグナル生成クラス                          |
//+------------------------------------------------------------------+
class CSignalGenerator
{
private:
   CScalpingConfig       *m_config;
   
   // インジケーターハンドル
   int                   m_ema_fast_handle;
   int                   m_ema_medium_handle;  
   int                   m_ema_slow_handle;
   int                   m_ema_trend_handle;   // トレンド確認用
   int                   m_rsi_handle;
   int                   m_macd_handle;
   int                   m_atr_handle;
   
   // バッファー
   double                m_ema_fast[];
   double                m_ema_medium[];
   double                m_ema_slow[];
   double                m_ema_trend[];
   double                m_rsi[];
   double                m_macd_main[];
   double                m_macd_signal[];
   double                m_atr[];
   
   // プライベートメソッド
   bool                  InitializeIndicators(string symbol);
   bool                  UpdateIndicatorData(void);
   ENUM_SIGNAL_TYPE      CheckTrendDirection(void);
   ENUM_SIGNAL_TYPE      CheckEMAAlignment(void);
   bool                  CheckRSICondition(ENUM_SIGNAL_TYPE signal_type);
   bool                  CheckMACDCondition(ENUM_SIGNAL_TYPE signal_type);
   bool                  CheckPriceAction(ENUM_SIGNAL_TYPE signal_type);
   double                CalculateSignalStrength(ENUM_SIGNAL_TYPE signal_type);
   double                CalculateStopLoss(ENUM_SIGNAL_TYPE signal_type, double entry_price);
   double                CalculateTakeProfit(ENUM_SIGNAL_TYPE signal_type, double entry_price);
   
public:
                        CSignalGenerator(CScalpingConfig *config);
                       ~CSignalGenerator(void);
   
   // メイン機能
   bool                  Initialize(string symbol);
   SignalInfo            GenerateSignal(string symbol);
   bool                  ValidateSignal(const SignalInfo &signal, string symbol);
   
   // 個別チェック機能
   bool                  IsTrendFavorable(ENUM_SIGNAL_TYPE signal_type);
   bool                  IsVolatilityAcceptable(string symbol);
   bool                  IsPriceActionConfirmed(ENUM_SIGNAL_TYPE signal_type);
   
   // 統計・レポート
   string                GetSignalReport(const SignalInfo &signal);
   string                GetIndicatorStatus(void);
};

//+------------------------------------------------------------------+
//| コンストラクタ                                                   |
//+------------------------------------------------------------------+
CSignalGenerator::CSignalGenerator(CScalpingConfig *config)
{
   m_config = config;
   
   // ハンドル初期化
   m_ema_fast_handle = INVALID_HANDLE;
   m_ema_medium_handle = INVALID_HANDLE;
   m_ema_slow_handle = INVALID_HANDLE;
   m_ema_trend_handle = INVALID_HANDLE;
   m_rsi_handle = INVALID_HANDLE;
   m_macd_handle = INVALID_HANDLE;
   m_atr_handle = INVALID_HANDLE;
   
   // 配列設定
   ArraySetAsSeries(m_ema_fast, true);
   ArraySetAsSeries(m_ema_medium, true);
   ArraySetAsSeries(m_ema_slow, true);
   ArraySetAsSeries(m_ema_trend, true);
   ArraySetAsSeries(m_rsi, true);
   ArraySetAsSeries(m_macd_main, true);
   ArraySetAsSeries(m_macd_signal, true);
   ArraySetAsSeries(m_atr, true);
}

//+------------------------------------------------------------------+
//| デストラクタ                                                     |
//+------------------------------------------------------------------+
CSignalGenerator::~CSignalGenerator(void)
{
   if(m_ema_fast_handle != INVALID_HANDLE) IndicatorRelease(m_ema_fast_handle);
   if(m_ema_medium_handle != INVALID_HANDLE) IndicatorRelease(m_ema_medium_handle);
   if(m_ema_slow_handle != INVALID_HANDLE) IndicatorRelease(m_ema_slow_handle);
   if(m_ema_trend_handle != INVALID_HANDLE) IndicatorRelease(m_ema_trend_handle);
   if(m_rsi_handle != INVALID_HANDLE) IndicatorRelease(m_rsi_handle);
   if(m_macd_handle != INVALID_HANDLE) IndicatorRelease(m_macd_handle);
   if(m_atr_handle != INVALID_HANDLE) IndicatorRelease(m_atr_handle);
}

//+------------------------------------------------------------------+
//| 初期化                                                           |
//+------------------------------------------------------------------+
bool CSignalGenerator::Initialize(string symbol)
{
   return InitializeIndicators(symbol);
}

//+------------------------------------------------------------------+
//| インジケーター初期化                                             |
//+------------------------------------------------------------------+
bool CSignalGenerator::InitializeIndicators(string symbol)
{
   StrategySettings settings = m_config.GetSettings();
   
   // EMA (エントリー用 M1)
   m_ema_fast_handle = iMA(symbol, settings.EntryTimeframe, settings.EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   m_ema_medium_handle = iMA(symbol, settings.EntryTimeframe, settings.EMA_Medium, 0, MODE_EMA, PRICE_CLOSE);
   m_ema_slow_handle = iMA(symbol, settings.EntryTimeframe, settings.EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   
   // EMA (トレンド確認用 M5)
   m_ema_trend_handle = iMA(symbol, settings.TrendTimeframe, settings.EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   
   // RSI
   m_rsi_handle = iRSI(symbol, settings.EntryTimeframe, settings.RSI_Period, PRICE_CLOSE);
   
   // MACD
   m_macd_handle = iMACD(symbol, settings.EntryTimeframe, 
                        settings.MACD_FastEMA, settings.MACD_SlowEMA, 
                        settings.MACD_SignalSMA, PRICE_CLOSE);
   
   // ATR
   m_atr_handle = iATR(symbol, settings.EntryTimeframe, settings.ATR_Period);
   
   // ハンドル確認
   if(m_ema_fast_handle == INVALID_HANDLE || m_ema_medium_handle == INVALID_HANDLE ||
      m_ema_slow_handle == INVALID_HANDLE || m_ema_trend_handle == INVALID_HANDLE ||
      m_rsi_handle == INVALID_HANDLE || m_macd_handle == INVALID_HANDLE ||
      m_atr_handle == INVALID_HANDLE)
   {
      Print("Failed to initialize indicators for ", symbol);
      return(false);
   }
   
   Print("Indicators initialized successfully for ", symbol);
   return(true);
}

//+------------------------------------------------------------------+
//| シグナル生成                                                     |
//+------------------------------------------------------------------+
SignalInfo CSignalGenerator::GenerateSignal(string symbol)
{
   SignalInfo signal = {};
   signal.type = SIGNAL_NONE;
   signal.strength = 0.0;
   signal.is_valid = false;
   signal.timestamp = TimeCurrent();
   
   // インジケーターデータ更新
   if(!UpdateIndicatorData())
   {
      signal.reason = "Failed to update indicator data";
      return signal;
   }
   
   // 1. トレンド方向チェック (M5)
   ENUM_SIGNAL_TYPE trend_direction = CheckTrendDirection();
   if(trend_direction == SIGNAL_NONE)
   {
      signal.reason = "No clear trend direction";
      return signal;
   }
   
   // 2. EMAアライメントチェック (M1)
   ENUM_SIGNAL_TYPE ema_signal = CheckEMAAlignment();
   if(ema_signal != trend_direction)
   {
      signal.reason = "EMA alignment doesn't match trend";
      return signal;
   }
   
   // 3. RSI条件チェック
   if(!CheckRSICondition(trend_direction))
   {
      signal.reason = "RSI condition not met";
      return signal;
   }
   
   // 4. MACD条件チェック
   if(!CheckMACDCondition(trend_direction))
   {
      signal.reason = "MACD condition not met";
      return signal;
   }
   
   // 5. 価格アクションチェック
   if(!CheckPriceAction(trend_direction))
   {
      signal.reason = "Price action not confirmed";
      return signal;
   }
   
   // シグナル生成
   signal.type = trend_direction;
   signal.strength = CalculateSignalStrength(trend_direction);
   signal.entry_price = (trend_direction == SIGNAL_BUY) ? 
                       SymbolInfoDouble(symbol, SYMBOL_ASK) : 
                       SymbolInfoDouble(symbol, SYMBOL_BID);
   signal.stop_loss = CalculateStopLoss(trend_direction, signal.entry_price);
   signal.take_profit = CalculateTakeProfit(trend_direction, signal.entry_price);
   signal.is_valid = true;
   signal.reason = StringFormat("Multi-timeframe %s signal confirmed", 
                               (trend_direction == SIGNAL_BUY) ? "BUY" : "SELL");
   
   return signal;
}

//+------------------------------------------------------------------+
//| インジケーターデータ更新                                         |
//+------------------------------------------------------------------+
bool CSignalGenerator::UpdateIndicatorData(void)
{
   // EMA データ
   if(CopyBuffer(m_ema_fast_handle, 0, 0, 3, m_ema_fast) != 3) return(false);
   if(CopyBuffer(m_ema_medium_handle, 0, 0, 3, m_ema_medium) != 3) return(false);
   if(CopyBuffer(m_ema_slow_handle, 0, 0, 3, m_ema_slow) != 3) return(false);
   if(CopyBuffer(m_ema_trend_handle, 0, 0, 3, m_ema_trend) != 3) return(false);
   
   // RSI データ
   if(CopyBuffer(m_rsi_handle, 0, 0, 3, m_rsi) != 3) return(false);
   
   // MACD データ
   if(CopyBuffer(m_macd_handle, MAIN_LINE, 0, 3, m_macd_main) != 3) return(false);
   if(CopyBuffer(m_macd_handle, SIGNAL_LINE, 0, 3, m_macd_signal) != 3) return(false);
   
   // ATR データ
   if(CopyBuffer(m_atr_handle, 0, 0, 3, m_atr) != 3) return(false);
   
   return(true);
}

//+------------------------------------------------------------------+
//| トレンド方向チェック (M5 EMA20)                                  |
//+------------------------------------------------------------------+
ENUM_SIGNAL_TYPE CSignalGenerator::CheckTrendDirection(void)
{
   double current_price = (SymbolInfoDouble(Symbol(), SYMBOL_ASK) + SymbolInfoDouble(Symbol(), SYMBOL_BID)) / 2.0;
   
   if(current_price > m_ema_trend[0] && m_ema_trend[0] > m_ema_trend[1])
      return SIGNAL_BUY;   // 上昇トレンド
   else if(current_price < m_ema_trend[0] && m_ema_trend[0] < m_ema_trend[1])
      return SIGNAL_SELL;  // 下降トレンド
   
   return SIGNAL_NONE;
}

//+------------------------------------------------------------------+
//| EMAアライメントチェック (M1)                                     |
//+------------------------------------------------------------------+
ENUM_SIGNAL_TYPE CSignalGenerator::CheckEMAAlignment(void)
{
   // 買い: EMA5 > EMA10 > EMA20
   if(m_ema_fast[0] > m_ema_medium[0] && m_ema_medium[0] > m_ema_slow[0])
      return SIGNAL_BUY;
   
   // 売り: EMA5 < EMA10 < EMA20  
   if(m_ema_fast[0] < m_ema_medium[0] && m_ema_medium[0] < m_ema_slow[0])
      return SIGNAL_SELL;
   
   return SIGNAL_NONE;
}

//+------------------------------------------------------------------+
//| RSI条件チェック                                                  |
//+------------------------------------------------------------------+
bool CSignalGenerator::CheckRSICondition(ENUM_SIGNAL_TYPE signal_type)
{
   StrategySettings settings = m_config.GetSettings();
   
   if(signal_type == SIGNAL_BUY)
      return (m_rsi[0] <= settings.RSI_Oversold && m_rsi[0] > m_rsi[1]); // 反転開始
   else if(signal_type == SIGNAL_SELL)
      return (m_rsi[0] >= settings.RSI_Overbought && m_rsi[0] < m_rsi[1]); // 反転開始
   
   return false;
}

//+------------------------------------------------------------------+
//| MACD条件チェック                                                 |
//+------------------------------------------------------------------+
bool CSignalGenerator::CheckMACDCondition(ENUM_SIGNAL_TYPE signal_type)
{
   if(signal_type == SIGNAL_BUY)
   {
      // MACDがシグナルラインを下から上に抜ける
      return (m_macd_main[0] > m_macd_signal[0] && m_macd_main[1] <= m_macd_signal[1]);
   }
   else if(signal_type == SIGNAL_SELL)
   {
      // MACDがシグナルラインを上から下に抜ける
      return (m_macd_main[0] < m_macd_signal[0] && m_macd_main[1] >= m_macd_signal[1]);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| 価格アクション確認                                               |
//+------------------------------------------------------------------+
bool CSignalGenerator::CheckPriceAction(ENUM_SIGNAL_TYPE signal_type)
{
   MqlRates rates[];
   if(CopyRates(Symbol(), PERIOD_M1, 0, 3, rates) != 3)
      return false;
   
   double body_size = MathAbs(rates[0].close - rates[0].open);
   double candle_size = rates[0].high - rates[0].low;
   double upper_shadow = rates[0].high - MathMax(rates[0].open, rates[0].close);
   double lower_shadow = MathMin(rates[0].open, rates[0].close) - rates[0].low;
   
   if(signal_type == SIGNAL_BUY)
   {
      // ハンマー・ピンバーパターン (下影が長い)
      if(lower_shadow > body_size * 2 && upper_shadow < body_size)
         return(true);
      
      // 陽線のエンガルフィング
      if(rates[0].close > rates[0].open && rates[1].close < rates[1].open &&
         rates[0].open < rates[1].close && rates[0].close > rates[1].open)
         return(true);
   }
   else if(signal_type == SIGNAL_SELL)
   {
      // シューティングスター (上影が長い)
      if(upper_shadow > body_size * 2 && lower_shadow < body_size)
         return true;
      
      // 陰線のエンガルフィング
      if(rates[0].close < rates[0].open && rates[1].close > rates[1].open &&
         rates[0].open > rates[1].close && rates[0].close < rates[1].open)
         return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| シグナル強度計算                                                 |
//+------------------------------------------------------------------+
double CSignalGenerator::CalculateSignalStrength(ENUM_SIGNAL_TYPE signal_type)
{
   double strength = 0.0;
   
   // トレンドアライメント (30ポイント)
   if(CheckTrendDirection() == signal_type) strength += 30.0;
   
   // EMAアライメント (25ポイント)
   if(CheckEMAAlignment() == signal_type) strength += 25.0;
   
   // RSI (20ポイント)
   if(CheckRSICondition(signal_type)) strength += 20.0;
   
   // MACD (15ポイント)
   if(CheckMACDCondition(signal_type)) strength += 15.0;
   
   // 価格アクション (10ポイント)
   if(CheckPriceAction(signal_type)) strength += 10.0;
   
   return strength;
}

//+------------------------------------------------------------------+
//| ストップロス計算                                                 |
//+------------------------------------------------------------------+
double CSignalGenerator::CalculateStopLoss(ENUM_SIGNAL_TYPE signal_type, double entry_price)
{
   StrategySettings settings = m_config.GetSettings();
   string symbol = Symbol();
   
   double sl_pips = settings.InitialStopLossPips;
   double pip_size = (StringFind(symbol, "JPY") > 0) ? 0.01 : 0.0001;
   
   if(signal_type == SIGNAL_BUY)
      return entry_price - (sl_pips * pip_size);
   else
      return entry_price + (sl_pips * pip_size);
}

//+------------------------------------------------------------------+
//| テイクプロフィット計算                                           |
//+------------------------------------------------------------------+
double CSignalGenerator::CalculateTakeProfit(ENUM_SIGNAL_TYPE signal_type, double entry_price)
{
   StrategySettings settings = m_config.GetSettings();
   string symbol = Symbol();
   
   double tp_pips = settings.InitialTakeProfitPips;
   double pip_size = (StringFind(symbol, "JPY") > 0) ? 0.01 : 0.0001;
   
   if(signal_type == SIGNAL_BUY)
      return entry_price + (tp_pips * pip_size);
   else
      return entry_price - (tp_pips * pip_size);
}

//+------------------------------------------------------------------+
//| シグナルレポート生成                                             |
//+------------------------------------------------------------------+
string CSignalGenerator::GetSignalReport(const SignalInfo &signal)
{
   string report = "\n=== Signal Report ===\n";
   report += StringFormat("Type: %s\n", (signal.type == SIGNAL_BUY) ? "BUY" : 
                         (signal.type == SIGNAL_SELL) ? "SELL" : "NONE");
   report += StringFormat("Strength: %.1f%%\n", signal.strength);
   report += StringFormat("Entry: %.5f\n", signal.entry_price);
   report += StringFormat("Stop Loss: %.5f\n", signal.stop_loss);
   report += StringFormat("Take Profit: %.5f\n", signal.take_profit);
   report += StringFormat("Reason: %s\n", signal.reason);
   report += StringFormat("Valid: %s\n", signal.is_valid ? "Yes" : "No");
   
   return report;
}