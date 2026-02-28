# MySimpleEA Specification (English)

## 1. Overview
`MySimpleEA` is a simple MQL5 Expert Advisor that enters trades based on the previous candle body direction.  
To improve reproducibility, trade decisions are executed only on a new bar.

## 2. Indicators Used
- No standard indicators are used
- Price series functions are used (`iOpen`, `iClose`, `iTime`)

## 3. Parameters
- `input_MagicNumber` (int, 26022801): Unique magic number
- `input_LotSize` (double, 0.10): Fixed lot size
- `input_StopLossPoints` (int, 300): Stop loss in points
- `input_TakeProfitPoints` (int, 600): Take profit in points
- `input_MaxSpreadPoints` (int, 30): Maximum allowed spread
- `input_AllowLong` (bool, true): Enable long entries
- `input_AllowShort` (bool, false): Enable short entries

## 4. Entry / Exit Rules
- Entry evaluation timing: only at a new bar
- Pre-entry conditions:
  - No existing position for the same symbol and magic number
  - Current spread is less than or equal to `input_MaxSpreadPoints`
- Long condition:
  - `input_AllowLong == true`
  - Previous candle is bullish (`Close[1] > Open[1]`)
- Short condition:
  - `input_AllowShort == true`
  - Previous candle is bearish (`Close[1] < Open[1]`)
- Exit:
  - Fixed SL/TP is set when placing the order

## 5. Risk Management
- Position identification by `input_MagicNumber`
- Spread filter to avoid poor execution conditions
- Volume normalization to symbol min/max/step constraints
- On order failure, logs `GetLastError()` and `ResultRetcode()`

## 6. Changelog
- 2026-02-28: Initial version created (new EA and bilingual specs)
