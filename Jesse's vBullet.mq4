//+------------------------------------------------------------------+
//|                                                    FVG_Trading.mql4 |
//+------------------------------------------------------------------+
#property copyright "2024"
#property version   "1.01"

// Input parameters
input int FVGPeriod = PERIOD_M5;                // Timeframe for FVG detection
input double RiskReward = 2.0;           // Risk:Reward ratio
input double LotSize = 0.1;              // Position size
input int Slippage = 3;                  // Allowed slippage in points

// Global variables
datetime lastTradeTime = 0;
bool tradingAllowed = false;
datetime currentDayStart = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
    // Verify timeframe
    if(Period() != FVGPeriod)
    {
        Print("Please set chart timeframe to ", FVGPeriod);
        return(INIT_FAILED);
    }
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Get session high/low prices                                        |
//+------------------------------------------------------------------+
void GetSessionLevels(double &sessionHigh, double &sessionLow)
{
    datetime startTime = StringToTime(TimeToString(TimeCurrent(), TIME_DATE) + " 06:00");
    datetime endTime = StringToTime(TimeToString(TimeCurrent(), TIME_DATE) + " 07:30");
    
    sessionHigh = -1;
    sessionLow = 999999;
    
    for(int i = 0; i < Bars; i++)
    {
        datetime barTime = Time[i];
        if(barTime < startTime) break;
        if(barTime >= startTime && barTime <= endTime)
        {
            sessionHigh = MathMax(sessionHigh, High[i]);
            sessionLow = MathMin(sessionLow, Low[i]);
        }
    }
}

//+------------------------------------------------------------------+
//| Check if current time is within trading hours                      |
//+------------------------------------------------------------------+
bool IsWithinTradingHours()
{
    datetime currentTime = TimeCurrent();
    int currentHour = TimeHour(currentTime);
    int currentMinute = TimeMinute(currentTime);
    
    // Check if we're in 10-11am EST or 2-3pm EST
    bool isMorningSession = (currentHour == 10);
    bool isAfternoonSession = (currentHour == 14);
    
    return (isMorningSession || isAfternoonSession);
}

//+------------------------------------------------------------------+
//| Check if session range has been taken                             |
//+------------------------------------------------------------------+
bool IsSessionRangeTaken()
{
    double sessionHigh, sessionLow;
    GetSessionLevels(sessionHigh, sessionLow);
    
    if(sessionHigh == -1 || sessionLow == 999999) return false;
    
    double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    
    // Check if current price has taken out either the high or low
    return (currentPrice > sessionHigh || currentPrice < sessionLow);
}

//+------------------------------------------------------------------+
//| Detect FVG formation                                              |
//+------------------------------------------------------------------+
bool DetectFVG(bool& isBearish)
{
    // Get recent candles from the current timeframe
    double candle1High = High[2];
    double candle1Low = Low[2];
    double candle2High = High[1];
    double candle2Low = Low[1];
    double candle3High = High[0];
    double candle3Low = Low[0];
    
    // Bullish FVG
    if(candle1High < candle3Low && candle2Low > candle1High) {
        isBearish = false;
        return true;
    }
    
    // Bearish FVG
    if(candle1Low > candle3High && candle2High < candle1Low) {
        isBearish = true;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Calculate position size based on risk                             |
//+------------------------------------------------------------------+
double CalculatePositionSize(double stopLoss)
{
    double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
    double accountRiskAmount = AccountBalance() * 0.02; // 2% risk per trade
    double stopLossPips = MathAbs(stopLoss - SymbolInfoDouble(Symbol(), SYMBOL_BID)) / Point;
    double positionSize = accountRiskAmount / (stopLossPips * tickValue);
    
    return NormalizeDouble(MathMin(positionSize, MarketInfo(Symbol(), MODE_MAXLOT)), 2);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check if it's a new trading day
    if(TimeDay(TimeCurrent()) != TimeDay(currentDayStart)) {
        currentDayStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
        tradingAllowed = false;
    }
    
    // Only proceed after 9:30 EST
    if(TimeHour(TimeCurrent()) < 9 || (TimeHour(TimeCurrent()) == 9 && TimeMinute(TimeCurrent()) < 30))
        return;
        
    // Check if session range has been taken
    if(!tradingAllowed) {
        tradingAllowed = IsSessionRangeTaken();
        if(!tradingAllowed) return;
    }
    
    // Check if we're within valid trading hours
    if(!IsWithinTradingHours())
        return;
        
    // Detect FVG
    bool isBearish;
    if(!DetectFVG(isBearish))
        return;
        
    // Get session high/low
    double sessionHigh, sessionLow;
    GetSessionLevels(sessionHigh, sessionLow);
    
    // Check if price has reached required level
    double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    if((isBearish && currentPrice < sessionHigh) || (!isBearish && currentPrice > sessionLow))
        return;
        
    // Calculate entry and stop loss
    double entryPrice = High[1]; // Middle candle
    double stopLoss = High[2];   // First candle
    double takeProfit = entryPrice + (RiskReward * MathAbs(entryPrice - stopLoss));
    
    if(isBearish) {
        entryPrice = Low[1];
        stopLoss = Low[2];
        takeProfit = entryPrice - (RiskReward * MathAbs(entryPrice - stopLoss));
    }
    
    // Calculate position size
    double posSize = CalculatePositionSize(stopLoss);
    
    // Open two positions
    int ticket1 = OrderSend(Symbol(), isBearish ? OP_SELL : OP_BUY, posSize, entryPrice, 
                           Slippage, stopLoss, takeProfit, "FVG Trade 1", 0, 0, 
                           isBearish ? clrRed : clrGreen);
                           
    if(ticket1 > 0) {
        int ticket2 = OrderSend(Symbol(), isBearish ? OP_SELL : OP_BUY, posSize, entryPrice, 
                               Slippage, stopLoss, 0, "FVG Trade 2", 0, 0, 
                               isBearish ? clrRed : clrGreen);
                               
        lastTradeTime = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Close any remaining positions at end of day
    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        if(OrderSelect(i, SELECT_BY_POS)) {
            if(OrderSymbol() == Symbol() && OrderMagicNumber() == 0) {
                double price = (OrderType() == OP_BUY) ? MarketInfo(Symbol(), MODE_BID) : MarketInfo(Symbol(), MODE_ASK);
                
                // Attempt to close the order
                if(!OrderClose(OrderTicket(), OrderLots(), price, Slippage)) {
                    // Handle the error
                    int errorCode = GetLastError();
                    Print("Failed to close order #", OrderTicket(), ". Error code: ", errorCode);
                    
                    // Optionally, you can reset the last error
                    ResetLastError();
                } else {
                    Print("Order #", OrderTicket(), " closed successfully.");
                }
            }
        }
    }
}