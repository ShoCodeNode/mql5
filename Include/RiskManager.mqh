//+------------------------------------------------------------------+
//|                                         RiskManager.mqh         |
//|                                  Copyright 2025, ShoCodeNode     |
//|                                       https://github.com/...     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ShoCodeNode"
#property link      "https://github.com/ShoCodeNode/mql5_scalping_strategy"

#include "ScalpingConfig.mqh"

//+------------------------------------------------------------------+
//| リスク管理クラス                                                 |
//+------------------------------------------------------------------+
class CRiskManager
{
private:
   CScalpingConfig   *m_config;
   double            m_account_balance;
   double            m_account_equity;
   double            m_account_free_margin;
   
public:
                     CRiskManager(CScalpingConfig *config);
                    ~CRiskManager(void) {}
   
   // 口座情報更新
   void              UpdateAccountInfo(void);
   
   // ロット計算
   double            CalculateLotSize(double stop_loss_pips);
   double            CalculateMaxLotSize(void);
   double            NormalizeLotSize(double lot_size);
   
   // リスクチェック
   bool              CanOpenPosition(string symbol);
   bool              IsSpreadAcceptable(string symbol);
   bool              IsAccountHealthy(void);
   bool              IsDrawdownAcceptable(void);
   
   // ポジション管理
   int               CountPositions(string symbol = "");
   int               CountPositionsByType(ENUM_POSITION_TYPE type);
   double            GetTotalExposure(void);
   double            GetSymbolExposure(string symbol);
   
   // 統計情報
   double            GetAccountRiskPercent(void);
   double            GetCurrentDrawdown(void);
   double            GetDailyPnL(void);
   string            GetRiskReport(void);
};

//+------------------------------------------------------------------+
//| コンストラクタ                                                   |
//+------------------------------------------------------------------+
CRiskManager::CRiskManager(CScalpingConfig *config)
{
   m_config = config;
   UpdateAccountInfo();
}

//+------------------------------------------------------------------+
//| 口座情報更新                                                     |
//+------------------------------------------------------------------+
void CRiskManager::UpdateAccountInfo(void)
{
   m_account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   m_account_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   m_account_free_margin = AccountInfoDouble(ACCOUNT_FREEMARGIN);
}

//+------------------------------------------------------------------+
//| ロットサイズ計算                                                 |
//+------------------------------------------------------------------+
double CRiskManager::CalculateLotSize(double stop_loss_pips)
{
   UpdateAccountInfo();
   
   // リスク金額計算
   double risk_amount = m_account_balance * (m_config.GetRiskPercent() / 100.0);
   
   // 1pipの値段を取得
   string symbol = Symbol();
   double pip_value = 0.0;
   
   if(StringFind(symbol, "JPY") > 0)
   {
      // JPYペアの場合
      pip_value = (0.01 / SymbolInfoDouble(symbol, SYMBOL_ASK)) * SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   }
   else
   {
      // その他の通貨ペア
      pip_value = (0.0001 / SymbolInfoDouble(symbol, SYMBOL_ASK)) * SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   }
   
   // ロットサイズ計算
   double lot_size = risk_amount / (stop_loss_pips * pip_value);
   
   // 正規化
   return(NormalizeLotSize(lot_size));
}

//+------------------------------------------------------------------+
//| ロットサイズ正規化                                               |
//+------------------------------------------------------------------+
double CRiskManager::NormalizeLotSize(double lot_size)
{
   string symbol = Symbol();
   
   double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   // 最小値以下の場合
   if(lot_size < min_lot)
      return(0.0);
   
   // 最大値以上の場合
   if(lot_size > max_lot)
      lot_size = max_lot;
   
   // ステップに合わせて調整
   lot_size = MathFloor(lot_size / lot_step) * lot_step;
   
   return(lot_size);
}

//+------------------------------------------------------------------+
//| ポジション開設可能かチェック                                     |
//+------------------------------------------------------------------+
bool CRiskManager::CanOpenPosition(string symbol)
{
   // 口座の健全性チェック
   if(!IsAccountHealthy())
      return(false);
   
   // スプレッドチェック
   if(!IsSpreadAcceptable(symbol))
      return(false);
   
   // 最大ポジション数チェック
   if(CountPositions(symbol) >= m_config.GetMaxPositions())
      return(false);
   
   // ドローダウンチェック  
   if(!IsDrawdownAcceptable())
      return(false);
   
   return(true);
}

//+------------------------------------------------------------------+
//| スプレッドが許容範囲かチェック                                   |
//+------------------------------------------------------------------+
bool CRiskManager::IsSpreadAcceptable(string symbol)
{
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double spread = ask - bid;
   
   // pipsに変換
   double spread_pips;
   if(StringFind(symbol, "JPY") > 0)
      spread_pips = spread * 100;  // JPYペア
   else
      spread_pips = spread * 10000; // その他
   
   return(spread_pips <= m_config.GetMaxSpread());
}

//+------------------------------------------------------------------+
//| 口座の健全性チェック                                             |
//+------------------------------------------------------------------+
bool CRiskManager::IsAccountHealthy(void)
{
   UpdateAccountInfo();
   
   // 証拠金維持率チェック
   double margin_level = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   if(margin_level < 200.0 && margin_level > 0)  // 200%未満は危険
      return(false);
   
   // フリーマージンチェック
   if(m_account_free_margin < 100.0)  // $100未満は危険
      return(false);
   
   return(true);
}

//+------------------------------------------------------------------+
//| ドローダウンが許容範囲かチェック                                 |
//+------------------------------------------------------------------+
bool CRiskManager::IsDrawdownAcceptable(void)
{
   double drawdown = GetCurrentDrawdown();
   return(drawdown < 5.0);  // 5%未満
}

//+------------------------------------------------------------------+
//| ポジション数カウント                                             |
//+------------------------------------------------------------------+
int CRiskManager::CountPositions(string symbol = "")
{
   int count = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == "" || !PositionSelect(PositionGetSymbol(i)))
         continue;
         
      if(symbol == "" || PositionGetString(POSITION_SYMBOL) == symbol)
         count++;
   }
   
   return count;
}

//+------------------------------------------------------------------+
//| 現在のドローダウン計算                                           |
//+------------------------------------------------------------------+
double CRiskManager::GetCurrentDrawdown(void)
{
   UpdateAccountInfo();
   
   if(m_account_balance <= 0)
      return 0.0;
   
   double drawdown = (m_account_balance - m_account_equity) / m_account_balance * 100.0;
   return MathMax(0.0, drawdown);
}

//+------------------------------------------------------------------+
//| 日次P&L取得                                                      |
//+------------------------------------------------------------------+
double CRiskManager::GetDailyPnL(void)
{
   double daily_pnl = 0.0;
   datetime today_start = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   
   // 今日のクローズドポジションのP&Lを計算
   if(!HistorySelect(today_start, TimeCurrent()))
      return 0.0;
   
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      
      if(HistoryDealGetInteger(ticket, DEAL_TYPE) == DEAL_TYPE_BUY || 
         HistoryDealGetInteger(ticket, DEAL_TYPE) == DEAL_TYPE_SELL)
      {
         daily_pnl += HistoryDealGetDouble(ticket, DEAL_PROFIT);
      }
   }
   
   return daily_pnl;
}

//+------------------------------------------------------------------+
//| リスクレポート生成                                               |
//+------------------------------------------------------------------+
string CRiskManager::GetRiskReport(void)
{
   UpdateAccountInfo();
   
   string report = "\n=== Risk Management Report ===\n";
   report += StringFormat("Balance: %.2f\n", m_account_balance);
   report += StringFormat("Equity: %.2f\n", m_account_equity);
   report += StringFormat("Free Margin: %.2f\n", m_account_free_margin);
   report += StringFormat("Drawdown: %.2f%%\n", GetCurrentDrawdown());
   report += StringFormat("Daily P&L: %.2f\n", GetDailyPnL());
   report += StringFormat("Open Positions: %d\n", CountPositions());
   report += StringFormat("Risk per Trade: %.2f%%\n", m_config.GetRiskPercent());
   
   return report;
}