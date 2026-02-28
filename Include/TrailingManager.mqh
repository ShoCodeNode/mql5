//+------------------------------------------------------------------+
//|                                      TrailingManager.mqh        |
//|                                  Copyright 2025, ShoCodeNode     |
//|                                       https://github.com/...     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ShoCodeNode"
#property link      "https://github.com/ShoCodeNode/mql5_scalping_strategy"

#include "ScalpingConfig.mqh"

//--- トレーリング情報構造体
struct TrailingInfo
{
   ulong             ticket;              // ポジションチケット
   double            initial_sl;          // 初期ストップロス
   double            highest_profit;      // 最高利益
   double            trailing_level;      // 現在のトレーリングレベル
   bool              trailing_started;    // トレーリング開始フラグ
   datetime          last_update;         // 最終更新時間
};

//+------------------------------------------------------------------+
//| ATRベース・トレーリングマネージャー                              |
//+------------------------------------------------------------------+
class CTrailingManager
{
private:
   CScalpingConfig   *m_config;
   TrailingInfo      m_trailing_positions[];
   int               m_atr_handle;
   
   // プライベートメソッド
   int               FindTrailingPosition(ulong ticket);
   double            GetATRValue(string symbol, ENUM_TIMEFRAMES timeframe);
   double            CalculateTrailingLevel(double atr_value, double current_profit, ENUM_POSITION_TYPE type);
   bool              UpdateTrailingStop(ulong ticket, double new_sl);
   
public:
                     CTrailingManager(CScalpingConfig *config);
                    ~CTrailingManager(void);
   
   // メイン機能
   void              Initialize(string symbol);
   void              AddPosition(ulong ticket);
   void              RemovePosition(ulong ticket);
   void              UpdateAllPositions(void);
   void              UpdatePosition(ulong ticket);
   
   // 設定・取得
   bool              IsTrailingActive(ulong ticket);
   double            GetMinProfitForTrailing(string symbol);
   double            GetTrailingStep(string symbol);
   string            GetTrailingReport(void);
   
   // クリーンアップ
   void              CleanupClosedPositions(void);
};

//+------------------------------------------------------------------+
//| コンストラクタ                                                   |
//+------------------------------------------------------------------+
CTrailingManager::CTrailingManager(CScalpingConfig *config)
{
   m_config = config;
   ArrayResize(m_trailing_positions, 0);
}

//+------------------------------------------------------------------+
//| デストラクタ                                                     |
//+------------------------------------------------------------------+
CTrailingManager::~CTrailingManager(void)
{
   if(m_atr_handle != INVALID_HANDLE)
      IndicatorRelease(m_atr_handle);
}

//+------------------------------------------------------------------+
//| 初期化                                                           |
//+------------------------------------------------------------------+
void CTrailingManager::Initialize(string symbol)
{
   // ATRインジケーター初期化
   m_atr_handle = iATR(symbol, PERIOD_M1, m_config.GetSettings().ATR_Period);
   
   if(m_atr_handle == INVALID_HANDLE)
   {
      Print("Failed to create ATR indicator for ", symbol);
   }
}

//+------------------------------------------------------------------+
//| ポジション追加                                                   |
//+------------------------------------------------------------------+
void CTrailingManager::AddPosition(ulong ticket)
{
   if(!PositionSelectByTicket(ticket))
      return;
   
   // 既存チェック
   if(FindTrailingPosition(ticket) >= 0)
      return;
   
   // 新しいトレーリング情報を追加
   int size = ArraySize(m_trailing_positions);
   ArrayResize(m_trailing_positions, size + 1);
   
   m_trailing_positions[size].ticket = ticket;
   m_trailing_positions[size].initial_sl = PositionGetDouble(POSITION_SL);
   m_trailing_positions[size].highest_profit = 0.0;
   m_trailing_positions[size].trailing_level = 0.0;
   m_trailing_positions[size].trailing_started = false;
   m_trailing_positions[size].last_update = TimeCurrent();
   
   Print("Added position to trailing manager: ", ticket);
}

//+------------------------------------------------------------------+
//| ポジション削除                                                   |
//+------------------------------------------------------------------+
void CTrailingManager::RemovePosition(ulong ticket)
{
   int index = FindTrailingPosition(ticket);
   if(index < 0)
      return;
   
   // 配列から削除
   int size = ArraySize(m_trailing_positions);
   for(int i = index; i < size - 1; i++)
   {
      m_trailing_positions[i] = m_trailing_positions[i + 1];
   }
   ArrayResize(m_trailing_positions, size - 1);
   
   Print("Removed position from trailing manager: ", ticket);
}

//+------------------------------------------------------------------+
//| 全ポジション更新                                                 |
//+------------------------------------------------------------------+
void CTrailingManager::UpdateAllPositions(void)
{
   CleanupClosedPositions();
   
   for(int i = ArraySize(m_trailing_positions) - 1; i >= 0; i--)
   {
      UpdatePosition(m_trailing_positions[i].ticket);
   }
}

//+------------------------------------------------------------------+
//| 個別ポジション更新                                               |
//+------------------------------------------------------------------+
void CTrailingManager::UpdatePosition(ulong ticket)
{
   int index = FindTrailingPosition(ticket);
   if(index < 0)
      return;
   
   if(!PositionSelectByTicket(ticket))
   {
      RemovePosition(ticket);
      return;
   }
   
   string symbol = PositionGetString(POSITION_SYMBOL);
   double current_price = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(symbol, SYMBOL_ASK);
   
   double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   double current_profit = PositionGetDouble(POSITION_PROFIT);
   ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   
   // ATR値取得
   double atr_value = GetATRValue(symbol, PERIOD_M1);
   if(atr_value <= 0)
      return;
   
   // 利益をpipsで計算
   double profit_pips;
   if(StringFind(symbol, "JPY") > 0)
   {
      profit_pips = MathAbs(current_price - open_price) * 100;  // JPY
   }
   else
   {
      profit_pips = MathAbs(current_price - open_price) * 10000; // その他
   }
   
   if(pos_type == POSITION_TYPE_SELL)
      profit_pips = (open_price - current_price) * (StringFind(symbol, "JPY") > 0 ? 100 : 10000);
   else
      profit_pips = (current_price - open_price) * (StringFind(symbol, "JPY") > 0 ? 100 : 10000);
   
   // 最高利益更新
   if(profit_pips > m_trailing_positions[index].highest_profit)
      m_trailing_positions[index].highest_profit = profit_pips;
   
   // トレーリング開始条件チェック
   double start_threshold = atr_value * m_config.GetSettings().ATR_StartMultiplier;
   double start_threshold_pips = start_threshold * (StringFind(symbol, "JPY") > 0 ? 100 : 10000);
   
   if(!m_trailing_positions[index].trailing_started && profit_pips >= start_threshold_pips)
   {
      m_trailing_positions[index].trailing_started = true;
      Print("Trailing started for position: ", ticket, " at profit: ", profit_pips, " pips");
   }
   
   // トレーリング実行
   if(m_trailing_positions[index].trailing_started)
   {
      double step_pips = atr_value * m_config.GetSettings().ATR_StepMultiplier * (StringFind(symbol, "JPY") > 0 ? 100 : 10000);
      double min_profit_pips = atr_value * m_config.GetSettings().ATR_MinProfitMultiplier * (StringFind(symbol, "JPY") > 0 ? 100 : 10000);
      
      // 新しいストップレベル計算
      double new_sl_pips = m_trailing_positions[index].highest_profit - step_pips;
      new_sl_pips = MathMax(new_sl_pips, min_profit_pips); // 最小利益保証
      
      // 価格に変換
      double new_sl_price;
      if(pos_type == POSITION_TYPE_BUY)
      {
         new_sl_price = open_price + (new_sl_pips / (StringFind(symbol, "JPY") > 0 ? 100 : 10000));
      }
      else
      {
         new_sl_price = open_price - (new_sl_pips / (StringFind(symbol, "JPY") > 0 ? 100 : 10000));
      }
      
      // 現在のSLより有利な場合のみ更新
      double current_sl = PositionGetDouble(POSITION_SL);
      bool should_update = false;
      
      if(pos_type == POSITION_TYPE_BUY && new_sl_price > current_sl)
         should_update = true;
      else if(pos_type == POSITION_TYPE_SELL && new_sl_price < current_sl)
         should_update = true;
      
      if(should_update)
      {
         if(UpdateTrailingStop(ticket, new_sl_price))
         {
            m_trailing_positions[index].trailing_level = new_sl_price;
            m_trailing_positions[index].last_update = TimeCurrent();
            Print("Updated trailing stop for ", ticket, " to: ", new_sl_price, " (", new_sl_pips, " pips profit)");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| ATR値取得                                                        |
//+------------------------------------------------------------------+
double CTrailingManager::GetATRValue(string symbol, ENUM_TIMEFRAMES timeframe)
{
   if(m_atr_handle == INVALID_HANDLE)
      return(0.0);
   
   double atr_buffer[1];
   if(CopyBuffer(m_atr_handle, 0, 1, 1, atr_buffer) != 1)
      return(0.0);
   
   return(atr_buffer[0]);
}

//+------------------------------------------------------------------+
//| トレーリングストップ更新                                         |
//+------------------------------------------------------------------+
bool CTrailingManager::UpdateTrailingStop(ulong ticket, double new_sl)
{
   if(!PositionSelectByTicket(ticket))
      return(false);
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_SLTP;
   request.position = ticket;
   request.sl = new_sl;
   request.tp = PositionGetDouble(POSITION_TP);
   
   return(OrderSend(request, result));
}

//+------------------------------------------------------------------+
//| トレーリングポジション検索                                       |
//+------------------------------------------------------------------+
int CTrailingManager::FindTrailingPosition(ulong ticket)
{
   for(int i = 0; i < ArraySize(m_trailing_positions); i++)
   {
      if(m_trailing_positions[i].ticket == ticket)
         return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| クローズドポジション清理                                         |
//+------------------------------------------------------------------+
void CTrailingManager::CleanupClosedPositions(void)
{
   for(int i = ArraySize(m_trailing_positions) - 1; i >= 0; i--)
   {
      if(!PositionSelectByTicket(m_trailing_positions[i].ticket))
      {
         RemovePosition(m_trailing_positions[i].ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| トレーリングレポート生成                                         |
//+------------------------------------------------------------------+
string CTrailingManager::GetTrailingReport(void)
{
   string report = "\n=== Trailing Manager Report ===\n";
   report += StringFormat("Active Trailing Positions: %d\n", ArraySize(m_trailing_positions));
   
   for(int i = 0; i < ArraySize(m_trailing_positions); i++)
   {
      report += StringFormat("Position %d: Ticket=%d, Started=%s, Profit=%.1f pips\n", 
                            i+1, 
                            m_trailing_positions[i].ticket,
                            m_trailing_positions[i].trailing_started ? "Yes" : "No",
                            m_trailing_positions[i].highest_profit);
   }
   
   return report;
}