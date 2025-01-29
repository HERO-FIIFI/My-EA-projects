//+------------------------------------------------------------------+
//|                                                   GenXSilver.mq4 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict


// Define input parameters
input int LondonOpenHour = 3;    // London Open hour in server time
input int NewYorkAMHour = 10;    // New York AM session hour in server time
input int NewYorkPMHour = 14;    // New York PM session hour in server time
input double TradeVolume = 0.1;  // Trading volume in lots
input double RiskRewardRatio = 1.0;  // Risk-reward ratio for TP to SL distance
input double BreakEvenBuffer = 10.0; // Break-even buffer in points

// Define global variables
datetime lastTradeTime = 0;      // Variable to track the last trade time
bool trailingStopActivated = false; // Flag to indicate if trailing stop is activated

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialization code here
   Print("Expert initialized");
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Cleanup code here
   Print("Expert deinitialized");
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Get current server time
   datetime serverTime = TimeCurrent();

   // Convert server time to local time for clarity (optional)
   int gmtOffset = TimeGMTOffset();
   datetime localTime = serverTime + gmtOffset * 60; // Convert seconds to minutes

   // Check if it's time to trade according to the Silver Bullet strategy
   if (IsTimeToTrade(localTime))
   {
      // Place trade based on strategy (e.g., market order, buy or sell)
      PlaceTrade();
   }
   // Check if trailing stop should be activated
   if (trailingStopActivated)
   {
      TrailStopLoss();
   }
}
//+------------------------------------------------------------------+
//| Function to check if it's time to trade according to strategy    |
//+------------------------------------------------------------------+
bool IsTimeToTrade(datetime currentTime)
{
   int hour = TimeHour(currentTime);

   // Check if current hour matches any of the specified trading hours
   if (hour == LondonOpenHour || hour == NewYorkAMHour || hour == NewYorkPMHour)
   {
      // Check if enough time has passed since the last trade (optional, for spacing trades)
      if (lastTradeTime == 0 || currentTime - lastTradeTime >= PeriodSeconds(PERIOD_H1))
      {
         lastTradeTime = currentTime;
         return true;
      }
   }
   return false;
}
//+------------------------------------------------------------------+
//| Function to place a trade                                        |
//+------------------------------------------------------------------+
void PlaceTrade()
{
   // Example: place a market order based on strategy
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double stopLoss = 0, takeProfit = 0;

   // Calculate stop-loss and take-profit levels based on risk-reward ratio
   if (OrderType() == OP_BUY)
   {
      stopLoss = price - (RiskRewardRatio * (price - Bid));
      takeProfit = price + (RiskRewardRatio * (Bid - price));
   }
   else if (OrderType() == OP_SELL)
   {
      stopLoss = price + (RiskRewardRatio * (Ask - price));
      takeProfit = price - (RiskRewardRatio * (price - Ask));
   }

   // Place the order with calculated SL and TP
   int ticket = OrderSend(_Symbol, OrderType(), TradeVolume, price, 3, stopLoss, takeProfit, "SilverBullet", 0, Blue);

   if (ticket < 0)
   {
      Print("Error placing order: ", GetLastError());
   }
   else
   {
      Print("Trade placed successfully: ", OrderType(), " ", TradeVolume, " lots at ", price);
   }
}
//+------------------------------------------------------------------+
//| Function to trail stop-loss once TP reaches 1:1 RR               |
//+------------------------------------------------------------------+
void TrailStopLoss()
{
   double currentPrice = OrderType() == OP_BUY ? Bid : Ask;
   double stopLossLevel = OrderType() == OP_BUY ? OrderOpenPrice() : OrderOpenPrice();

   // Calculate distance from entry to current price
   double entryToCurrent = MathAbs(currentPrice - OrderOpenPrice());

   // If price moves favorably by 1:1 RR, move stop-loss to breakeven + buffer
   if (entryToCurrent >= RiskRewardRatio * (OrderTakeProfit() - OrderOpenPrice()))
   {
      // Update stop-loss to entry price + buffer
      double newStopLoss = OrderOpenPrice() + BreakEvenBuffer * Point;

      // Modify order with new stop-loss level
      if (!OrderModify(OrderTicket(), OrderOpenPrice(), newStopLoss, OrderTakeProfit(), 0, Blue))
      {
         Print("Error modifying order: ", GetLastError());
      }
      else
      {
         Print("Stop-loss moved to breakeven");
         trailingStopActivated = false; // Disable trailing stop once at breakeven
      }
   }
}
