#property strict

#include <Trade/Trade.mqh>

input int    input_MagicNumber      = 26022801;
input double input_LotSize          = 0.10;
input int    input_StopLossPoints   = 300;
input int    input_TakeProfitPoints = 600;
input int    input_MaxSpreadPoints  = 30;
input bool   input_AllowLong        = true;
input bool   input_AllowShort       = false;

CTrade   g_trade;
datetime g_lastBarTime = 0;

bool IsNewBar()
{
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime <= 0)
      return false;

   if(currentBarTime == g_lastBarTime)
      return false;

   g_lastBarTime = currentBarTime;
   return true;
}

bool GetBidAsk(double &bid, double &ask)
{
   if(!SymbolInfoDouble(_Symbol, SYMBOL_BID, bid))
   {
      Print("Failed to get BID. Error: ", GetLastError());
      return false;
   }

   if(!SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask))
   {
      Print("Failed to get ASK. Error: ", GetLastError());
      return false;
   }

   return true;
}

int GetSpreadPoints()
{
   double bid = 0.0;
   double ask = 0.0;
   if(!GetBidAsk(bid, ask))
      return INT_MAX;

   return (int)MathRound((ask - bid) / _Point);
}

double NormalizeVolume(double volume)
{
   double minVolume  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxVolume  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(stepVolume <= 0.0)
      return minVolume;

   double normalized = MathFloor(volume / stepVolume) * stepVolume;
   normalized = MathMax(normalized, minVolume);
   normalized = MathMin(normalized, maxVolume);
   return normalized;
}

bool HasOpenPositionByMagic()
{
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      long magic    = PositionGetInteger(POSITION_MAGIC);

      if(symbol == _Symbol && magic == input_MagicNumber)
         return true;
   }

   return false;
}

bool OpenBuy()
{
   double bid = 0.0;
   double ask = 0.0;
   if(!GetBidAsk(bid, ask))
      return false;

   double volume = NormalizeVolume(input_LotSize);
   double sl = (input_StopLossPoints > 0) ? ask - input_StopLossPoints * _Point : 0.0;
   double tp = (input_TakeProfitPoints > 0) ? ask + input_TakeProfitPoints * _Point : 0.0;

   if(!g_trade.Buy(volume, _Symbol, 0.0, sl, tp, "MySimpleEA Buy"))
   {
      Print("Buy failed. Retcode=", g_trade.ResultRetcode(), " Error=", GetLastError());
      return false;
   }

   Print("Buy opened successfully. Ticket=", g_trade.ResultOrder());
   return true;
}

bool OpenSell()
{
   double bid = 0.0;
   double ask = 0.0;
   if(!GetBidAsk(bid, ask))
      return false;

   double volume = NormalizeVolume(input_LotSize);
   double sl = (input_StopLossPoints > 0) ? bid + input_StopLossPoints * _Point : 0.0;
   double tp = (input_TakeProfitPoints > 0) ? bid - input_TakeProfitPoints * _Point : 0.0;

   if(!g_trade.Sell(volume, _Symbol, 0.0, sl, tp, "MySimpleEA Sell"))
   {
      Print("Sell failed. Retcode=", g_trade.ResultRetcode(), " Error=", GetLastError());
      return false;
   }

   Print("Sell opened successfully. Ticket=", g_trade.ResultOrder());
   return true;
}

int OnInit()
{
   g_trade.SetExpertMagicNumber(input_MagicNumber);
   g_trade.SetDeviationInPoints(10);

   Print("MySimpleEA initialized. Symbol=", _Symbol, " Period=", EnumToString(_Period));
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   Print("MySimpleEA deinitialized. Reason=", reason);
}

void OnTick()
{
   // Execute logic only once per new bar to improve stability and backtest reproducibility.
   if(!IsNewBar())
      return;

   if(HasOpenPositionByMagic())
      return;

   int spread = GetSpreadPoints();
   if(spread > input_MaxSpreadPoints)
   {
      Print("Spread filter blocked entry. Spread=", spread, " points");
      return;
   }

   double prevOpen  = iOpen(_Symbol, _Period, 1);
   double prevClose = iClose(_Symbol, _Period, 1);

   // Simple momentum signal using previous candle body direction.
   bool bullish = (prevClose > prevOpen);
   bool bearish = (prevClose < prevOpen);

   if(input_AllowLong && bullish)
   {
      OpenBuy();
      return;
   }

   if(input_AllowShort && bearish)
      OpenSell();
}
