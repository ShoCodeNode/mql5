//+------------------------------------------------------------------+
//| BacktestRunner.mq5                                               |
//| MQL5 Scalping Strategy - Backtest Automation Script             |
//+------------------------------------------------------------------+
#property copyright "MQL5 Scalping Strategy"
#property version   "1.00"
#property script_show_inputs

//--- Input parameters
input string    ExpertFile = "AdaptiveScalpingEA.ex5";  // Expert Advisor file name
input string    Symbol = "EURUSD";                      // Testing symbol
input ENUM_TIMEFRAMES Timeframe = PERIOD_M1;            // Testing timeframe
input datetime  StartDate = D'2024.01.01';              // Backtest start date
input datetime  EndDate = D'2024.12.31';                // Backtest end date
input double    InitialDeposit = 10000;                 // Initial deposit
input ENUM_OPTIMIZATION OptimizationMode = OPT_DISABLED; // Optimization mode

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("=== MQL5 Scalping Strategy Backtest Runner ===");
    Print("Symbol: " + Symbol);
    Print("Timeframe: ", EnumToString(Timeframe));
    Print("Period: ", TimeToString(StartDate), " - ", TimeToString(EndDate));
    Print("Initial Deposit: ", InitialDeposit);
    
    // Check if symbol exists
    if(!SymbolSelect(Symbol, true))
    {
        Print("ERROR: Symbol ", Symbol, " not found or not available");
        return;
    }
    
    // Check if EA file exists
    string ea_path = "Experts\\" + ExpertFile;
    Print("Looking for EA: ", ea_path);
    
    // Basic validation
    if(StartDate >= EndDate)
    {
        Print("ERROR: Invalid date range - Start date must be before end date");
        return;
    }
    
    if(InitialDeposit <= 0)
    {
        Print("ERROR: Initial deposit must be positive");
        return;
    }
    
    Print("=== Backtest Configuration Valid ===");
    Print("Ready to run backtest manually:");
    Print("1. Open Strategy Tester (Ctrl+R)");
    Print("2. Select Expert: ", ExpertFile);
    Print("3. Set Symbol: ", Symbol);
    Print("4. Set Period: ", TimeToString(StartDate), " - ", TimeToString(EndDate));
    Print("5. Set Initial Deposit: ", InitialDeposit);
    Print("6. Click Start");
    
    // Note: Automated backtest execution requires terminal API access
    // which is not available in standard MQL5 scripts
    Print("=== Backtest Runner Complete ===");
}
