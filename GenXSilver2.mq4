//+------------------------------------------------------------------+
//|                                           ICT Silver Bullet.mq4 |
//|                        Copyright 2024, Your Name                 |
//|                                             https://www.yourwebsite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Your Name"
#property link      "https://www.yourwebsite.com"
#property version   "1.00"
#property strict

// Input parameters
input double LotSize = 0.01;
input int StopLoss = 50;
input int TakeProfit = 100;
input bool UseLondonOpen = true;
input bool UseNYAMSession = true;
input bool UseNYPMSession = true;
input int FVGPeriods = 3;
input int LiquidityThreshold = 20;
input int MinutesBetweenTrades = 5;

// Global variables
datetime lastTradeTime = 0;
int magicNumber = 123456;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("ICT Silver Bullet initialized. Magic Number: ", magicNumber);
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("ICT Silver Bullet deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check if it's time for a Silver Bullet session
    if (IsSilverBulletTime())
    {
        // Check for fair value gaps and liquidity
        if (IsFairValueGap() && IsLiquidityNearby())
        {
            // Check if enough time has passed since the last trade
            if (TimeCurrent() - lastTradeTime > MinutesBetweenTrades * 60)
            {
                OpenTrade();
                lastTradeTime = TimeCurrent();  // Update last trade time
            }
        }
    }
    
    // Manage open trades
    ManageOpenTrades();
}

//+------------------------------------------------------------------+
//| Check if it's Silver Bullet time                                 |
//+------------------------------------------------------------------+
bool IsSilverBulletTime()
{
    datetime currentTime = TimeCurrent();
    int currentHour = TimeHour(currentTime);
    int currentMinute = TimeMinute(currentTime);
    
    // London Open Silver Bullet (3:00-4:00 AM EST)
    if (UseLondonOpen && currentHour == 3)
        return true;
    
    // New York AM Session Silver Bullet (10:00-11:00 AM EST)
    if (UseNYAMSession && currentHour == 10)
        return true;
    
    // New York PM Session Silver Bullet (2:00-3:00 PM EST)
    if (UseNYPMSession && currentHour == 14)
        return true;
    
    return false;
}

//+------------------------------------------------------------------+
//| Check for fair value gaps                                        |
//+------------------------------------------------------------------+
bool IsFairValueGap()
{
    double highestHigh = High[iHighest(NULL, 0, MODE_HIGH, FVGPeriods, 1)];
    double lowestLow = Low[iLowest(NULL, 0, MODE_LOW, FVGPeriods, 1)];
    double currentOpen = Open[0];
    double previousClose = Close[1];
    
    // Check for bullish fair value gap
    if (currentOpen > previousClose && previousClose < lowestLow)
        return true;
    
    // Check for bearish fair value gap
    if (currentOpen < previousClose && previousClose > highestHigh)
        return true;
    
    return false;
}

//+------------------------------------------------------------------+
//| Check for nearby liquidity                                       |
//+------------------------------------------------------------------+
bool IsLiquidityNearby()
{
    double currentPrice = Close[0];
    
    // Check for liquidity above or below
    for (int i = 1; i <= LiquidityThreshold; i++)
    {
        if (High[i] > currentPrice + (StopLoss * Point * 0.5) ||
            Low[i] < currentPrice - (StopLoss * Point * 0.5))
            return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Open a trade                                                     |
//+------------------------------------------------------------------+
void OpenTrade()
{
    int cmd = (Close[0] > Open[0]) ? OP_BUY : OP_SELL;
    double price = (cmd == OP_BUY) ? Ask : Bid;
    double sl = (cmd == OP_BUY) ? price - StopLoss * Point : price + StopLoss * Point;
    double tp = (cmd == OP_BUY) ? price + TakeProfit * Point : price - TakeProfit * Point;
    
    int ticket = OrderSend(Symbol(), cmd, LotSize, price, 3, sl, tp, "ICT Silver Bullet", magicNumber, 0, clrGreen);
    
    if (ticket > 0)
    {
        Print("Trade opened: ", ticket, " Type: ", cmd == OP_BUY ? "Buy" : "Sell", " Price: ", price);
    }
    else
    {
        Print("Error opening trade: ", GetLastError(), " Cmd: ", cmd, " Price: ", price, " SL: ", sl, " TP: ", tp);
    }
}

//+------------------------------------------------------------------+
//| Manage open trades                                               |
//+------------------------------------------------------------------+
void ManageOpenTrades()
{
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if (OrderMagicNumber() == magicNumber)
            {
                // Check if the trade has reached 1:1 RR
                double currentPrice = (OrderType() == OP_BUY) ? Bid : Ask;
                double entryPrice = OrderOpenPrice();
                double stopLoss = OrderStopLoss();
                double takeProfit = OrderTakeProfit();
                
                double riskAmount = MathAbs(entryPrice - stopLoss);
                double rewardAmount = MathAbs(currentPrice - entryPrice);
                
                if (rewardAmount >= riskAmount && stopLoss != entryPrice)
                {
                    // Move stop loss to break even
                    double newStopLoss = entryPrice;
                    
                    if (OrderModify(OrderTicket(), entryPrice, newStopLoss, takeProfit, 0, clrBlue))
                    {
                        Print("Stop loss moved to break even for order: ", OrderTicket());
                    }
                    else
                    {
                        Print("Error modifying order: ", GetLastError(), " Ticket: ", OrderTicket());
                    }
                }
            }
        }
    }
}
