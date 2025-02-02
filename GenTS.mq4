//--- Define strategy parameters
input int    i_TSVM_Period = 14;
input int    i_SMA_Period  = 50;
input double LotSize       = 0.1;
input double StopLossPips  = 20;
input double TakeProfitPips = 40;

//--- Global variables
double g_TSVM[], g_SMA[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Indicator buffers
   IndicatorBuffers(2);
   SetIndexBuffer(0, g_TSVM);
   SetIndexBuffer(1, g_SMA);
   
   //--- SMA
   SetIndexStyle(1, DRAW_LINE);
   SetIndexLabel(1, "SMA");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Calculate indicator values
   double tsv_value = iCustom(NULL, 0, "Time Segmented Volume (TSV)", i_TSVM_Period, 0, 0);
   double sma_value = iMA(NULL, 0, i_SMA_Period, 0, MODE_SMA, PRICE_CLOSE, 0);
   
   //--- Check for open positions
   if (OrdersTotal() == 0)
   {
      //--- Check for buy conditions
      if (tsv_value > 0 && Close[0] > sma_value)
      {
         //--- Open buy position
         double stopLoss = Bid - StopLossPips * Point;
         double takeProfit = Bid + TakeProfitPips * Point;
         int ticket = OrderSend(Symbol(), OP_BUY, LotSize, Ask, 3, stopLoss, takeProfit, "TSV Buy", 0, 0, Blue);
         if (ticket < 0) {
            Print("Error opening buy order: ", GetLastError());
         }
      }
      
      //--- Check for sell conditions
      else if (tsv_value < 0 && Close[0] < sma_value)
      {
         //--- Open sell position
         stopLoss = Ask + StopLossPips * Point;
         takeProfit = Ask - TakeProfitPips * Point;
         ticket = OrderSend(Symbol(), OP_SELL, LotSize, Bid, 3, stopLoss, takeProfit, "TSV Sell", 0, 0, Red);
         if (ticket < 0) {
            Print("Error opening sell order: ", GetLastError());
         }
      }
   }
   else
   {
      for (int i = OrdersTotal() - 1; i >= 0; i--)
      {
         if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         {
            //--- Check for open buy positions
            if (OrderType() == OP_BUY)
            {
               //--- Break-even mechanism
               if (Bid >= OrderOpenPrice() + StopLossPips * Point)
               {
                  double newStopLoss = OrderOpenPrice() + 5 * Point; // Move stop-loss to break-even + 5 pips
                  if (!OrderModify(OrderTicket(), OrderOpenPrice(), newStopLoss, OrderTakeProfit(), 0, Blue)) {
                     Print("Error modifying buy order: ", GetLastError());
                  }
               }
               
               //--- Check for sell exit conditions
               if (tsv_value < 0 || Close[0] < sma_value)
               {
                  if (!OrderClose(OrderTicket(), OrderLots(), Bid, 3, White)) {
                     Print("Error closing buy order: ", GetLastError());
                  }
               }
            }
            
            //--- Check for open sell positions
            else if (OrderType() == OP_SELL)
            {
               //--- Break-even mechanism
               if (Ask <= OrderOpenPrice() - StopLossPips * Point)
               {
                   newStopLoss = OrderOpenPrice() - 5 * Point; // Move stop-loss to break-even + 5 pips
                  if (!OrderModify(OrderTicket(), OrderOpenPrice(), newStopLoss, OrderTakeProfit(), 0, Red)) {
                     Print("Error modifying sell order: ", GetLastError());
                  }
               }
               
               //--- Check for buy exit conditions
               if (tsv_value > 0 || Close[0] > sma_value)
               {
                  if (!OrderClose(OrderTicket(), OrderLots(), Ask, 3, White)) {
                     Print("Error closing sell order: ", GetLastError());
                  }
               }
            }
         }
      }
   }
}
