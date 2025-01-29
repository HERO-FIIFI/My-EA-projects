//+------------------------------------------------------------------+
//|                                                  Hand of God.mq4 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
/*
EvaluateEntry : Buy when price above vwap and volume>1240 and vwap is lime green, Sell when price below vwap  and volume>1240 and vwap is red

EvaluateExit /tp: exit buy when price reaches previous highest high in 54 bars, exit sell when price reaches previous lowest low in 54 bars 

StopLoss : exit buy when price reaches previous lowest low in 25 bars, exit sell when price reaches previous highest high in 25 bars 

ExecuteTrailingStop : To insert your trailing stop rules
*/

#property version       "1.00"
#property strict
#property copyright     "The_Generalist"
#property description   "The Lord hand Automated EA" 
#property description   "   "
#property description   "works using the custom indicator vwap+(1) "
#property description   "WARNING : You use this software at your own risk."
#property description   "The creator of these plugins cannot be held responsible for any damage or loss."
#property description   " "
//---

//---


enum ENUM_HOUR{
   h00=00,     //00:00
   h01=01,     //01:00
   h02=02,     //02:00
   h03=03,     //03:00
   h04=04,     //04:00
   h05=05,     //05:00
   h06=06,     //06:00
   h07=07,     //07:00
   h08=08,     //08:00
   h09=09,     //09:00
   h10=10,     //10:00
   h11=11,     //11:00
   h12=12,     //12:00
   h13=13,     //13:00
   h14=14,     //14:00
   h15=15,     //15:00
   h16=16,     //16:00
   h17=17,     //17:00
   h18=18,     //18:00
   h19=19,     //19:00
   h20=20,     //20:00
   h21=21,     //21:00
   h22=22,     //22:00
   h23=23,     //23:00
};

enum ENUM_SIGNAL_ENTRY{
   SIGNAL_ENTRY_NEUTRAL=0,    //SIGNAL ENTRY NEUTRAL
   SIGNAL_ENTRY_BUY=1,        //SIGNAL ENTRY BUY
   SIGNAL_ENTRY_SELL=-1,      //SIGNAL ENTRY SELL
};

enum ENUM_SIGNAL_EXIT{
   SIGNAL_EXIT_NEUTRAL=0,     //SIGNAL EXIT NEUTRAL
   SIGNAL_EXIT_BUY=1,         //SIGNAL EXIT BUY
   SIGNAL_EXIT_SELL=-1,       //SIGNAL EXIT SELL
   SIGNAL_EXIT_ALL=2,         //SIGNAL EXIT ALL
};

enum ENUM_TRADING_ALLOW_DIRECTION{
   TRADING_ALLOW_BOTH=0,      //ALLOW BOTH BUY AND SELL
   TRADING_ALLOW_BUY=1,       //ALLOW BUY ONLY
   TRADING_ALLOW_SELL=-1,     //ALLOW SELL ONLY
};

enum ENUM_RISK_BASE{
   RISK_BASE_EQUITY=1,        //EQUITY
   RISK_BASE_BALANCE=2,       //BALANCE
   RISK_BASE_FREEMARGIN=3,    //FREE MARGIN
};

enum ENUM_RISK_DEFAULT_SIZE{
   RISK_DEFAULT_FIXED=1,      //FIXED SIZE
   RISK_DEFAULT_AUTO=2,       //AUTOMATIC SIZE BASED ON RISK
};

enum ENUM_MODE_SL{
   SL_FIXED=0,                //FIXED STOP LOSS
   SL_AUTO=1,                 //AUTOMATIC STOP LOSS
};

enum ENUM_MODE_TP{
   TP_FIXED=0,                //FIXED TAKE PROFIT
   TP_AUTO=1,                 //AUTOMATIC TAKE PROFIT
};

enum ENUM_MODE_SL_BY{
   SL_BY_POINTS=0,            //STOP LOSS PASSED IN POINTS
   SL_BY_PRICE=1,             //STOP LOSS PASSED BY PRICE
};

input string Comment_strategy="==========";                          //Entry And Exit Settings
input int MAValueInput = 35; // Default MA period as an input
input color IndicatorColorInput = clrNONE; // Default color as an input

int MAValue; // Actual MA period to be used in the strategy
color IndicatorColor; // Actual color to be used in the strategy

//General input parameters
input string Comment_0="==========";                                 //Risk Management Settings
input ENUM_RISK_DEFAULT_SIZE RiskDefaultSize=RISK_DEFAULT_AUTO;      //Position Size Mode
input double DefaultLotSize=1;                                       //Position Size (if fixed or if no stop loss defined)
input ENUM_RISK_BASE RiskBase=RISK_BASE_BALANCE;                     //Risk Base
input int MaxRiskPerTrade=2;                                         //Percentage To Risk Each Trade
input double MinLotSize=0.01;                                        //Minimum Position Size Allowed
input double MaxLotSize=100;                                         //Maximum Position Size Allowed

input string Comment_1="==========";                                 //Trading Hours Settings
input bool UseTradingHours=false;                                    //Limit Trading Hours
input ENUM_HOUR TradingHourStart=h07;                                //Trading Start Hour (Broker Server Hour)
input ENUM_HOUR TradingHourEnd=h19;                                  //Trading End Hour (Broker Server Hour)

input string Comment_2="==========";                                 //Stop Loss And Take Profit Settings
input ENUM_MODE_SL StopLossMode=SL_FIXED;                            //Stop Loss Mode
input int DefaultStopLoss=0;                                         //Default Stop Loss In Points (0=No Stop Loss)
input int MinStopLoss=0;                                             //Minimum Allowed Stop Loss In Points
input int MaxStopLoss=5000;                                          //Maximum Allowed Stop Loss In Points
input ENUM_MODE_TP TakeProfitMode=TP_FIXED;                          //Take Profit Mode
input int DefaultTakeProfit=0;                                       //Default Take Profit In Points (0=No Take Profit)
input int MinTakeProfit=0;                                           //Minimum Allowed Take Profit In Points
input int MaxTakeProfit=5000;                                        //Maximum Allowed Take Profit In Points

input string Comment_3="==========";                                 //Trailing Stop Settings
input bool UseTrailingStop=false;                                    //Use Trailing Stop

input string Comment_4="==========";                                 //Additional Settings
input int MagicNumber=0;                                             //Magic Number For The Orders Opened By This EA
input string OrderNote="";                                           //Comment For The Orders Opened By This EA
input int Slippage=5;                                                //Slippage in points
input int MaxSpread=100;                                             //Maximum Allowed Spread To Trade In Points
bool IsPreChecksOk=false;                 //Indicates if the pre checks are satisfied
bool IsNewCandle=false;                   //Indicates if this is a new candle formed
bool IsSpreadOK=false;                    //Indicates if the spread is low enough to trade
bool IsOperatingHours=false;              //Indicates if it is possible to trade at the current time (server time)
bool IsTradedThisBar=false;               //Indicates if an order was already executed in the current candle

double TickValue=0;                       //Value of a tick in account currency at 1 lot
double LotSize=0;                         //Lot size for the position

int OrderOpRetry=10;                      //Number of attempts to retry the order submission
int TotalOpenOrders=0;                    //Number of total open orders
int TotalOpenBuy=0;                       //Number of total open buy orders
int TotalOpenSell=0;                      //Number of total open sell orders
int StopLossBy=SL_BY_POINTS;              //How the stop loss is passed for the lot size calculation

ENUM_SIGNAL_ENTRY SignalEntry=SIGNAL_ENTRY_NEUTRAL;      //Entry signal variable
ENUM_SIGNAL_EXIT SignalExit=SIGNAL_EXIT_NEUTRAL;         //Exit signal variable

string ErrorDescription(int error_code) {
    string error_message;
    switch(error_code) {
        case 0: error_message = "No error"; break;
        case 1: error_message = "No error, but no confirmation was received"; break;
        case 2: error_message = "Common error"; break;
        case 3: error_message = "Invalid trade parameters"; break;
        case 4: error_message = "Trade server is busy"; break;
        case 5: error_message = "Old version of the client terminal"; break;
        // Add more cases as needed
        default: error_message = "Unknown error code: " + IntegerToString(error_code); break;
    }
    return error_message;
}


int OnInit(){
   //It is useful to set a function to check the integrity of the initial parameters and call it as first thing
   CheckPreChecks();
      
   
  MAValue = (int)iCustom(NULL, 0, "Vwap+(1)", 0, 1);
  IndicatorColor = (color)iCustom(NULL, 0, "Vwap+(1)", 1, 1);


   InitializeVariables();
   return(INIT_SUCCEEDED);
}

void CheckPreChecks(){
   IsPreChecksOk=true;
   if(!IsTesting() && !IsTradeAllowed()){
      IsPreChecksOk=false;
      Print("Error: Automated trading is disabled in platform");
   }
   if(AccountFreeMargin()<100){
      IsPreChecksOk=false;
      Print("Error: Not enough free margin to trade");
   }
}

void InitializeVariables(){
   IsSpreadOK=false;
   IsOperatingHours=false;
   IsNewCandle=false;
   IsTradedThisBar=false;
   SignalEntry=SIGNAL_ENTRY_NEUTRAL;
   SignalExit=SIGNAL_EXIT_NEUTRAL;
}

bool ScanOrders(){
   TotalOpenOrders=0;
   TotalOpenBuy=0;
   TotalOpenSell=0;
   for(int i=0;i<OrdersTotal();i++){
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)){
         if(OrderMagicNumber()==MagicNumber){
            TotalOpenOrders++;
            if(OrderType()==OP_BUY) TotalOpenBuy++;
            if(OrderType()==OP_SELL) TotalOpenSell++;
         }
      }
   }
   return(true);
}

void CheckNewBar(){
   static datetime NewTime=0;
   if(NewTime!=Time[0]){
      NewTime=Time[0];
      IsNewCandle=true;
      IsTradedThisBar=false;
   }
   else IsNewCandle=false;
}

void CheckOperationHours(){
   if(UseTradingHours){
      int currentHour=Hour();
      if(currentHour>=TradingHourStart && currentHour<=TradingHourEnd){
         IsOperatingHours=true;
      }
   }
   else IsOperatingHours=true;
}

void CheckSpread() {
    double currentSpread = MarketInfo(Symbol(), MODE_SPREAD);
    IsSpreadOK = (currentSpread <= MaxSpread);
}


void CheckTradedThisBar(){
   if(!IsNewCandle) IsTradedThisBar=true;
}

bool VWAPConditionBuy() {
    double vwap = iCustom(NULL, 0, "Vwap+(1)", 0, 1);
    color vwapColor = (color)iCustom(NULL, 0, "Vwap+(1)", 1, 1);
    return (Close[0] > vwap && Volume[0] > 1240 && vwapColor == clrLime);
}


bool VWAPConditionSell(){
   double vwap = iCustom(NULL, 0, "Vwap+(1)", 0, 1);
   double vwapColorDouble = iCustom(NULL, 0, "Vwap+(1)", 1, 1);
   color vwapColor = (color)int(vwapColorDouble); // explicit type casting
   return (Close[0] < vwap && Volume[0] > 1240 && vwapColor == clrRed);
}

void EvaluateEntry(){
   if(!IsSpreadOK || !IsOperatingHours || IsTradedThisBar) return;
   
   if(VWAPConditionBuy()) SignalEntry=SIGNAL_ENTRY_BUY;
   if(VWAPConditionSell()) SignalEntry=SIGNAL_ENTRY_SELL;
}

void ExecuteEntry(){
   if(SignalEntry==SIGNAL_ENTRY_NEUTRAL) return;
   if(TotalOpenOrders>0) return;

   double lotSize=CalculateLotSize();
   
   int ticket=0;
   double openPrice=0;
   double stopLoss=0;
   double takeProfit=0;

   if(SignalEntry==SIGNAL_ENTRY_BUY){
      openPrice=Ask;
      if(StopLossMode==SL_FIXED) stopLoss=openPrice-DefaultStopLoss*Point;
      if(TakeProfitMode==TP_FIXED) takeProfit=openPrice+DefaultTakeProfit*Point;
      ticket=OrderSend(Symbol(),OP_BUY,lotSize,openPrice,Slippage,stopLoss,takeProfit,OrderNote,MagicNumber,0,clrNONE);
   }
   
   if(SignalEntry==SIGNAL_ENTRY_SELL){
      openPrice=Bid;
      if(StopLossMode==SL_FIXED) stopLoss=openPrice+DefaultStopLoss*Point;
      if(TakeProfitMode==TP_FIXED) takeProfit=openPrice-DefaultTakeProfit*Point;
      ticket=OrderSend(Symbol(),OP_SELL,lotSize,openPrice,Slippage,stopLoss,takeProfit,OrderNote,MagicNumber,0,clrNONE);
   }
   
if(ticket < 0) {
    int lastError = GetLastError();
    Print("Error opening order: ", ErrorDescription(lastError));
    return;
}
   
   IsTradedThisBar=true;
}

void EvaluateExit(){
   if(!IsSpreadOK || !IsOperatingHours || IsTradedThisBar) return;
   
   double highestHigh54 = iHigh(NULL, 0, 54);
   double lowestLow54 = iLow(NULL, 0, 54);

   for(int i=0;i<OrdersTotal();i++){
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)){
         if(OrderMagicNumber()!=MagicNumber) continue;

         if(OrderType()==OP_BUY && Close[0] >= highestHigh54){
            SignalExit=SIGNAL_EXIT_BUY;
         }

         if(OrderType()==OP_SELL && Close[0] <= lowestLow54){
            SignalExit=SIGNAL_EXIT_SELL;
         }
      }
   }
}

void ExecuteExit(){
   if(SignalExit==SIGNAL_EXIT_NEUTRAL) return;

   for(int i=0;i<OrdersTotal();i++){
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)){
         if(OrderMagicNumber()!=MagicNumber) continue;
         
         if(SignalExit==SIGNAL_EXIT_BUY && OrderType()==OP_BUY){
            if(OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, clrNONE) == false)
          Print("Error opening order: ", ErrorDescription(GetLastError()));
;
         }
         
         if(SignalExit==SIGNAL_EXIT_SELL && OrderType()==OP_SELL){
            if(OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, clrNONE) == false)
              Print("Error opening order: ", ErrorDescription(GetLastError()));
;
         }
      }
   }
}

double CalculateLotSize(){
   double lotSize=DefaultLotSize;
   
   if(RiskDefaultSize==RISK_DEFAULT_FIXED){
      lotSize=DefaultLotSize;
   }
   else{
      double risk=MaxRiskPerTrade/100.0;
      double base=0;
      
      if(RiskBase==RISK_BASE_BALANCE) base=AccountBalance();
      if(RiskBase==RISK_BASE_EQUITY) base=AccountEquity();
      if(RiskBase==RISK_BASE_FREEMARGIN) base=AccountFreeMargin();
      
      if(StopLossMode==SL_FIXED){
         double stopLossInPoints=DefaultStopLoss;
         if(StopLossBy==SL_BY_PRICE) stopLossInPoints=MathAbs(Ask-DefaultStopLoss)/Point;
         double valuePerPoint=MarketInfo(Symbol(),MODE_TICKVALUE)*MarketInfo(Symbol(),MODE_TICKSIZE)/Point;
         lotSize=(risk*base)/(stopLossInPoints*valuePerPoint);
      }
      else{
         double valuePerPoint=MarketInfo(Symbol(),MODE_TICKVALUE)*MarketInfo(Symbol(),MODE_TICKSIZE)/Point;
         lotSize=(risk*base)/valuePerPoint;
      }
   }
   
   if(lotSize<MinLotSize) lotSize=MinLotSize;
   if(lotSize>MaxLotSize) lotSize=MaxLotSize;
   
   return lotSize;
}

void ExecuteTrailingStop(){
   // Placeholder for your trailing stop logic
}

void OnDeinit(const int reason){
   // No return value is needed
}
