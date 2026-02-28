//+------------------------------------------------------------------+
//| CommonFunctions.mqh                                              |
//| Common functions library for EAs                                |
//+------------------------------------------------------------------+
#ifndef COMMON_FUNCTIONS_H
#define COMMON_FUNCTIONS_H

//+------------------------------------------------------------------+
//| Get symbol point value                                          |
//+------------------------------------------------------------------+
double GetSymbolPoint(string symbol)
{
    return SymbolInfoDouble(symbol, SYMBOL_POINT);
}

//+------------------------------------------------------------------+
//| Get symbol digits                                               |
//+------------------------------------------------------------------+
int GetSymbolDigits(string symbol)
{
    return (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
}

//+------------------------------------------------------------------+
//| Convert pips to price                                           |
//+------------------------------------------------------------------+
double PipsToPrice(int pips, string symbol = "")
{
    if(symbol == "")
        symbol = Symbol();
    
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    return pips * point;
}

//+------------------------------------------------------------------+
//| Convert price to pips                                           |
//+------------------------------------------------------------------+
int PriceToP(double price, string symbol = "")
{
    if(symbol == "")
        symbol = Symbol();
    
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    return (int)(price / point);
}

//+------------------------------------------------------------------+
//| Get bar high/low for last N bars                                |
//+------------------------------------------------------------------+
double GetHighestHigh(int bars, int shift = 0)
{
    double highest = 0;
    for(int i = shift; i < shift + bars; i++)
    {
        double high = iHigh(Symbol(), PERIOD_CURRENT, i);
        if(high > highest)
            highest = high;
    }
    return highest;
}

double GetLowestLow(int bars, int shift = 0)
{
    double lowest = DBL_MAX;
    for(int i = shift; i < shift + bars; i++)
    {
        double low = iLow(Symbol(), PERIOD_CURRENT, i);
        if(low < lowest)
            lowest = low;
    }
    return lowest;
}

//+------------------------------------------------------------------+
//| Check if new bar has formed                                     |
//+------------------------------------------------------------------+
bool IsNewBar()
{
    static datetime lastBarTime = 0;
    datetime currentBarTime = iTime(Symbol(), PERIOD_CURRENT, 0);
    
    if(lastBarTime != currentBarTime)
    {
        lastBarTime = currentBarTime;
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| PRICE ACTION FUNCTIONS                                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Detect Bullish Pin Bar                                          |
//+------------------------------------------------------------------+
bool IsBullishPinBar(MqlRates &bar, double wickRatioThreshold = 0.67, double bodyPositionThreshold = 0.33)
{
    double totalRange = bar.high - bar.low;
    if(totalRange <= 0) return false;
    
    double body = MathAbs(bar.open - bar.close);
    double lowerWick = MathMin(bar.open, bar.close) - bar.low;
    double upperWick = bar.high - MathMax(bar.open, bar.close);
    
    // Lower wick must be >= 67% of total range
    if(lowerWick / totalRange < wickRatioThreshold) return false;
    
    // Body position: must be in upper 33% of the bar
    double bodyTopPosition = MathMax(bar.open, bar.close);
    if((bar.high - bodyTopPosition) / totalRange > bodyPositionThreshold) return false;
    
    // Close above open (bullish)
    if(bar.close <= bar.open) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Detect Bearish Pin Bar                                          |
//+------------------------------------------------------------------+
bool IsBearishPinBar(MqlRates &bar, double wickRatioThreshold = 0.67, double bodyPositionThreshold = 0.33)
{
    double totalRange = bar.high - bar.low;
    if(totalRange <= 0) return false;
    
    double body = MathAbs(bar.open - bar.close);
    double lowerWick = MathMin(bar.open, bar.close) - bar.low;
    double upperWick = bar.high - MathMax(bar.open, bar.close);
    
    // Upper wick must be >= 67% of total range
    if(upperWick / totalRange < wickRatioThreshold) return false;
    
    // Body position: must be in lower 33% of the bar
    double bodyBottomPosition = MathMin(bar.open, bar.close);
    if((bodyBottomPosition - bar.low) / totalRange > bodyPositionThreshold) return false;
    
    // Close below open (bearish)
    if(bar.close >= bar.open) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Detect Inside Bar (Consolidation Pattern)                       |
//+------------------------------------------------------------------+
bool IsInsideBar(MqlRates &current, MqlRates &previous)
{
    // Current bar is completely inside previous bar
    if(current.high < previous.high && current.low > previous.low)
        return true;
    return false;
}

//+------------------------------------------------------------------+
//| Detect Bullish Engulfing Pattern                                |
//+------------------------------------------------------------------+
bool IsBullishEngulfing(MqlRates &previous, MqlRates &current)
{
    // Previous bar is bearish (close < open)
    if(previous.close >= previous.open) return false;
    
    // Current bar is bullish (close > open)
    if(current.close <= current.open) return false;
    
    // Current bar's body engulfs previous bar's body
    double prevBody = previous.open - previous.close;
    double currBody = current.close - current.open;
    
    if(current.open <= previous.close && current.close >= previous.open)
        return true;
    
    return false;
}

//+------------------------------------------------------------------+
//| Detect Bearish Engulfing Pattern                                |
//+------------------------------------------------------------------+
bool IsBearishEngulfing(MqlRates &previous, MqlRates &current)
{
    // Previous bar is bullish (close > open)
    if(previous.close <= previous.open) return false;
    
    // Current bar is bearish (close < open)
    if(current.close >= current.open) return false;
    
    // Current bar's body engulfs previous bar's body
    if(current.open >= previous.close && current.close <= previous.open)
        return true;
    
    return false;
}

//+------------------------------------------------------------------+
//| Get ATR value (Average True Range)                              |
//+------------------------------------------------------------------+
double GetATR(int handle, int period = 1, int shift = 0)
{
    double atrBuffer[];
    ArraySetAsSeries(atrBuffer, true);
    CopyBuffer(handle, 0, shift, period, atrBuffer);
    return atrBuffer[0];
}

//+------------------------------------------------------------------+
//| Calculate Dynamic Lot Size Based on Risk Management             |
//+------------------------------------------------------------------+
double CalculateLotSize(double equity, double riskPercent, int stopLossPips, string symbol = "")
{
    if(symbol == "")
        symbol = Symbol();
    
    if(stopLossPips <= 0 || riskPercent <= 0) return 0;
    
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    
    // Get contract size (multiplier)
    double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
    
    // Calculate risk in currency
    double riskAmount = equity * (riskPercent / 100.0);
    
    // Calculate lot size: riskAmount / (stopLossPips * point * tickValue * contractSize)
    double lotSize = riskAmount / (stopLossPips * point * tickValue);
    
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    
    // Normalize lot size
    lotSize = MathFloor(lotSize / step) * step;
    
    if(lotSize < minLot) return minLot;
    if(lotSize > maxLot) return maxLot;
    
    return lotSize;
}

//+------------------------------------------------------------------+
//| Get EMA value                                                   |
//+------------------------------------------------------------------+
double GetEMA(int handle, int shift = 0)
{
    double emaBuffer[];
    ArraySetAsSeries(emaBuffer, true);
    CopyBuffer(handle, 0, shift, 1, emaBuffer);
    return emaBuffer[0];
}

//+------------------------------------------------------------------+
//| Detect Fractal High (Support/Resistance)                        |
//+------------------------------------------------------------------+
bool IsFractalHigh(MqlRates &bar2, MqlRates &bar1, MqlRates &barCurrent, MqlRates &barMinus1, MqlRates &barMinus2)
{
    // Fractal High: H[i] > H[i-1], H[i] > H[i-2], H[i] > H[i+1], H[i] > H[i+2]
    if(barCurrent.high > bar1.high && barCurrent.high > bar2.high &&
       barCurrent.high > barMinus1.high && barCurrent.high > barMinus2.high)
        return true;
    return false;
}

//+------------------------------------------------------------------+
//| Detect Fractal Low (Support/Resistance)                         |
//+------------------------------------------------------------------+
bool IsFractalLow(MqlRates &bar2, MqlRates &bar1, MqlRates &barCurrent, MqlRates &barMinus1, MqlRates &barMinus2)
{
    // Fractal Low: L[i] < L[i-1], L[i] < L[i-2], L[i] < L[i+1], L[i] < L[i+2]
    if(barCurrent.low < bar1.low && barCurrent.low < bar2.low &&
       barCurrent.low < barMinus1.low && barCurrent.low < barMinus2.low)
        return true;
    return false;
}

//+------------------------------------------------------------------+
//| Calculate Pivot Points                                          |
//+------------------------------------------------------------------+
struct PivotPoints
{
    double pp;   // Pivot Point
    double r1;   // Resistance 1
    double r2;   // Resistance 2
    double s1;   // Support 1
    double s2;   // Support 2
};

PivotPoints CalculatePivots(MqlRates &bar)
{
    PivotPoints pivots;
    
    pivots.pp = (bar.high + bar.low + bar.close) / 3.0;
    pivots.r1 = (2 * pivots.pp) - bar.low;
    pivots.s1 = (2 * pivots.pp) - bar.high;
    pivots.r2 = pivots.pp + (bar.high - bar.low);
    pivots.s2 = pivots.pp - (bar.high - bar.low);
    
    return pivots;
}

#endif
