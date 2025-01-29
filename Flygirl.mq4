//+------------------------------------------------------------------+
//|            Enhanced Multi-Indicator Trading Strategy             |
//+------------------------------------------------------------------+
#property copyright "Your Name"
#property link      "Your Website"
#property version   "1.02"
#property strict

// Input parameters
input int RSI_Period = 14;
input int RSI_Overbought = 70;
input int RSI_Oversold = 30;
input int FVG_Lookback = 20;
input int OB_Lookback = 20;
input double Risk_Percent = 0.25;
input int TP_Pips = 100;
input int SL_Pips = 35;
input int Slippage = 3;

// Global variables
int ticket = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Clean up code here if needed
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    if(!IsNewBar()) return;
    
    // Check for open positions
    if(OrdersTotal() > 0) return;
    
    // Analyze market conditions
    bool isTrending = IsTrending();
    double support = FindSupport();
    double resistance = FindResistance();
    double fvg = FindFairValueGap();
    double ob = FindOrderBlock();
    
    // Calculate lot size
    double lotSize = CalculateLotSize(Risk_Percent, SL_Pips);
    
    // Check for long setup
    if(IsBuySetup(support, fvg, ob, isTrending))
    {
        // Check if there's enough free margin for the trade
        if(IsEnoughFreeMargin(OP_BUY, lotSize))
        {
            ticket = OrderSend(Symbol(), OP_BUY, lotSize, Ask, Slippage, Ask - SL_Pips * Point, Ask + TP_Pips * Point, "Buy Order", 0, 0, Green);
            if(ticket < 0)
            {
                Print("OrderSend failed with error #", GetLastError());
            }
        }
        else
        {
            Print("Not enough free margin for BUY order");
        }
    }
    
    // Check for short setup
    else if(IsSellSetup(resistance, fvg, ob, isTrending))
    {
        // Check if there's enough free margin for the trade
        if(IsEnoughFreeMargin(OP_SELL, lotSize))
        {
            ticket = OrderSend(Symbol(), OP_SELL, lotSize, Bid, Slippage, Bid + SL_Pips * Point, Bid - TP_Pips * Point, "Sell Order", 0, 0, Red);
            if(ticket < 0)
            {
                Print("OrderSend failed with error #", GetLastError());
            }
        }
        else
        {
            Print("Not enough free margin for SELL order");
        }
    }
}

//+------------------------------------------------------------------+
//| Check if it's a new bar                                          |
//+------------------------------------------------------------------+
bool IsNewBar()
{
    static datetime lastBar;
    datetime currentBar = iTime(Symbol(), PERIOD_CURRENT, 0);
    if(currentBar != lastBar)
    {
        lastBar = currentBar;
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Check if the market is trending                                  |
//+------------------------------------------------------------------+
bool IsTrending()
{
    double ma20 = iMA(Symbol(), PERIOD_D1, 20, 0, MODE_SMA, PRICE_CLOSE, 0);
    double ma50 = iMA(Symbol(), PERIOD_D1, 50, 0, MODE_SMA, PRICE_CLOSE, 0);
    return (ma20 > ma50);
}

//+------------------------------------------------------------------+
//| Find support level                                               |
//+------------------------------------------------------------------+
double FindSupport()
{
    double support = Low[iLowest(Symbol(), PERIOD_CURRENT, MODE_LOW, 20, 1)];
    return support;
}

//+------------------------------------------------------------------+
//| Find resistance level                                            |
//+------------------------------------------------------------------+
double FindResistance()
{
    double resistance = High[iHighest(Symbol(), PERIOD_CURRENT, MODE_HIGH, 20, 1)];
    return resistance;
}

//+------------------------------------------------------------------+
//| Find Fair Value Gap                                              |
//+------------------------------------------------------------------+
double FindFairValueGap()
{
    for(int i = 1; i < FVG_Lookback; i++)
    {
        if(Low[i] > High[i+1])
            return (Low[i] + High[i+1]) / 2;
        if(High[i] < Low[i+1])
            return (High[i] + Low[i+1]) / 2;
    }
    return 0;
}

//+------------------------------------------------------------------+
//| Find Order Block                                                 |
//+------------------------------------------------------------------+
double FindOrderBlock()
{
    double highestHigh = High[iHighest(Symbol(), PERIOD_CURRENT, MODE_HIGH, OB_Lookback, 1)];
    double lowestLow = Low[iLowest(Symbol(), PERIOD_CURRENT, MODE_LOW, OB_Lookback, 1)];
    return (highestHigh + lowestLow) / 2;
}

//+------------------------------------------------------------------+
//| Check for buy setup                                              |
//+------------------------------------------------------------------+
bool IsBuySetup(double support, double fvg, double ob, bool isTrending)
{
    double rsi = iRSI(Symbol(), PERIOD_CURRENT, RSI_Period, PRICE_CLOSE, 0);
    bool isNearSupport = MathAbs(Close[0] - support) < Point * 10;
    bool isNearFVG = fvg > 0 && MathAbs(Close[0] - fvg) < Point * 10;
    bool isNearOB = MathAbs(Close[0] - ob) < Point * 10;
    bool isOversold = rsi < RSI_Oversold;
    
    return (isNearSupport || isNearFVG || isNearOB) && isOversold && isTrending;
}

//+------------------------------------------------------------------+
//| Check for sell setup                                             |
//+------------------------------------------------------------------+
bool IsSellSetup(double resistance, double fvg, double ob, bool isTrending)
{
    double rsi = iRSI(Symbol(), PERIOD_CURRENT, RSI_Period, PRICE_CLOSE, 0);
    bool isNearResistance = MathAbs(Close[0] - resistance) < Point * 10;
    bool isNearFVG = fvg > 0 && MathAbs(Close[0] - fvg) < Point * 10;
    bool isNearOB = MathAbs(Close[0] - ob) < Point * 10;
    bool isOverbought = rsi > RSI_Overbought;
    
    return (isNearResistance || isNearFVG || isNearOB) && isOverbought && !isTrending;
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk percentage                      |
//+------------------------------------------------------------------+
double CalculateLotSize(double riskPercent, int stopLoss)
{
    double accountBalance = AccountBalance();
    double riskAmount = accountBalance * riskPercent / 100;
    double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
    double lotSize = riskAmount / (stopLoss * tickValue);
    double minLot = MarketInfo(Symbol(), MODE_MINLOT);
    double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
    double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
    
    lotSize = MathFloor(lotSize / lotStep) * lotStep;
    lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
    
    return lotSize;
}
//+------------------------------------------------------------------+
//| Check if there's enough free margin for the trade                |
//+------------------------------------------------------------------+
bool IsEnoughFreeMargin(int operation, double volume)
{
    double margin = MarketInfo(Symbol(), MODE_MARGINREQUIRED) * volume;
    
    if(AccountFreeMarginCheck(Symbol(), operation, volume) <= 0 || AccountFreeMargin() - margin < 0)
        return false;
    
    if((AccountStopoutMode() == 1 && AccountFreeMarginCheck(Symbol(), operation, volume) > AccountStopoutLevel()) ||
       (AccountStopoutMode() == 0 && ((AccountEquity() / (AccountEquity() - AccountFreeMarginCheck(Symbol(), operation, volume))) * 100 > AccountStopoutLevel())))
    {
        return true;
    }
    
    return false;
}

