//+------------------------------------------------------------------+
//|                                         ScalpingConfig.mqh       |
//|                                  Copyright 2025, ShoCodeNode     |
//|                                       https://github.com/...     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ShoCodeNode"
#property link      "https://github.com/ShoCodeNode/mql5_scalping_strategy"

//--- 戦略設定
//--- 戦略設定構造体
struct StrategySettings
{
   // 基本設定
   double            RiskPercent;           // 残高に対するリスク%
   int               MaxPositionsPerPair;   // 通貨ペアあたりの最大ポジション数
   double            MaxSpreadPips;         // 最大スプレッド（pips）
   
   // 時間フィルター
   int               LondonStartHour;       // ロンドン開始時間
   int               LondonEndHour;         // ロンドン終了時間
   int               NewYorkStartHour;      // ニューヨーク開始時間
   int               NewYorkEndHour;        // ニューヨーク終了時間
   bool              AvoidFridayLate;       // 金曜日遅い時間の回避
   
   // EMA設定
   int               EMA_Fast;              // 高速EMA期間
   int               EMA_Medium;            // 中速EMA期間
   int               EMA_Slow;              // 低速EMA期間
   ENUM_TIMEFRAMES   TrendTimeframe;        // トレンド確認時間軸
   ENUM_TIMEFRAMES   EntryTimeframe;       // エントリー時間軸
   
   // RSI設定
   int               RSI_Period;            // RSI期間
   double            RSI_Oversold;          // 売られ過ぎレベル
   double            RSI_Overbought;        // 買われ過ぎレベル
   
   // MACD設定
   int               MACD_FastEMA;          // 高速EMA
   int               MACD_SlowEMA;          // 低速EMA
   int               MACD_SignalSMA;        // シグナルSMA
   
   // ATR設定（トレーリング用）
   int               ATR_Period;            // ATR期間
   double            ATR_StartMultiplier;   // トレーリング開始倍率
   double            ATR_StepMultiplier;    // トレーリング間隔倍率
   double            ATR_MinProfitMultiplier; // 最小利益保証倍率
   
   // ストップロス・テイクプロフィット
   double            InitialStopLossPips;   // 初期ストップロス（pips）
   double            InitialTakeProfitPips; // 初期テイクプロフィット（pips）
   
   // 価格アクション設定
   double            PinBarMinBodyRatio;    // ピンバー最小実体比率
   double            PinBarMaxBodyRatio;    // ピンバー最大実体比率
   double            EngulfingMinSize;      // エンガルフィング最小サイズ
};

//--- デフォルト設定
class CScalpingConfig
{
private:
   StrategySettings  m_settings;
   
public:
                     CScalpingConfig(void);
   void              LoadDefaultSettings(void);
   void              LoadSettings(string filename);
   void              SaveSettings(string filename);
   
   // ゲッター
   StrategySettings  GetSettings(void) { return m_settings; }
   double            GetRiskPercent(void) { return m_settings.RiskPercent; }
   int               GetMaxPositions(void) { return m_settings.MaxPositionsPerPair; }
   double            GetMaxSpread(void) { return m_settings.MaxSpreadPips; }
   
   // セッター  
   void              SetRiskPercent(double risk) { m_settings.RiskPercent = risk; }
   void              SetMaxPositions(int max) { m_settings.MaxPositionsPerPair = max; }
   void              SetMaxSpread(double spread) { m_settings.MaxSpreadPips = spread; }
   
   // 時間フィルター
   bool              IsTradingTime(void);
   bool              IsLondonSession(void);
   bool              IsNewYorkSession(void);
   bool              IsSessionOverlap(void);
   
   // 通貨ペア管理
   bool              IsValidSymbol(string symbol);
   string            GetTradingSymbols(void);
};

//+------------------------------------------------------------------+
//| コンストラクタ                                                   |
//+------------------------------------------------------------------+
CScalpingConfig::CScalpingConfig(void)
{
   LoadDefaultSettings();
}

//+------------------------------------------------------------------+
//| デフォルト設定をロード                                           |
//+------------------------------------------------------------------+
void CScalpingConfig::LoadDefaultSettings(void)
{
   // 基本設定
   m_settings.RiskPercent = 1.0;            // 1%リスク
   m_settings.MaxPositionsPerPair = 1;       // 1通貨ペア1ポジション
   m_settings.MaxSpreadPips = 3.0;           // 最大3pipsスプレッド
   
   // 時間設定（JST）
   m_settings.LondonStartHour = 16;          // 16:00
   m_settings.LondonEndHour = 20;            // 20:00
   m_settings.NewYorkStartHour = 22;         // 22:00
   m_settings.NewYorkEndHour = 2;            // 02:00
   m_settings.AvoidFridayLate = true;        // 金曜日遅い時間回避
   
   // タイムフレーム
   m_settings.TrendTimeframe = PERIOD_M5;    // トレンド確認
   m_settings.EntryTimeframe = PERIOD_M1;    // エントリータイミング
   
   // EMA設定
   m_settings.EMA_Fast = 5;
   m_settings.EMA_Medium = 10;
   m_settings.EMA_Slow = 20;
   
   // RSI設定
   m_settings.RSI_Period = 14;
   m_settings.RSI_Oversold = 30.0;
   m_settings.RSI_Overbought = 70.0;
   
   // MACD設定
   m_settings.MACD_FastEMA = 12;
   m_settings.MACD_SlowEMA = 26;
   m_settings.MACD_SignalSMA = 9;
   
   // ATR設定
   m_settings.ATR_Period = 14;
   m_settings.ATR_StartMultiplier = 1.5;     // ATR×1.5で開始
   m_settings.ATR_StepMultiplier = 0.8;      // ATR×0.8間隔
   m_settings.ATR_MinProfitMultiplier = 0.5; // ATR×0.5最小利益
   
   // SL/TP設定
   m_settings.InitialStopLossPips = 10.0;    // 10pips SL
   m_settings.InitialTakeProfitPips = 15.0;  // 15pips TP（固定TP使用時）
   
   // 価格アクション
   m_settings.PinBarMinBodyRatio = 0.1;      // 実体10%以下
   m_settings.PinBarMaxBodyRatio = 0.3;      // 実体30%以下
   m_settings.EngulfingMinSize = 5.0;        // 最小5pipsサイズ
}

//+------------------------------------------------------------------+
//| 取引時間かチェック                                               |
//+------------------------------------------------------------------+
bool CScalpingConfig::IsTradingTime(void)
{
   MqlDateTime time_struct;
   TimeCurrent(time_struct);
   
   int current_hour = time_struct.hour;
   int current_day = time_struct.day_of_week;
   
   // 金曜日遅い時間の回避
   if(m_settings.AvoidFridayLate && current_day == 5 && current_hour >= 22)
      return(false);
   
   // ロンドンセッション
   if(current_hour >= m_settings.LondonStartHour && current_hour < m_settings.LondonEndHour)
      return(true);
      
   // ニューヨークセッション
   if(current_hour >= m_settings.NewYorkStartHour || current_hour < m_settings.NewYorkEndHour)
      return(true);
      
   return(false);
}

//+------------------------------------------------------------------+
//| 有効な通貨ペアかチェック                                         |
//+------------------------------------------------------------------+
bool CScalpingConfig::IsValidSymbol(string symbol)
{
   string valid_pairs[] = {"EURUSD", "GBPUSD", "USDJPY", "USDCHF", "AUDUSD"};
   
   for(int i = 0; i < ArraySize(valid_pairs); i++)
   {
      if(symbol == valid_pairs[i])
         return(true);
   }
   return(false);
}