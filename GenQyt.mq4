//+------------------------------------------------------------------+
//|                                                       GenQyt.mq4 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
//+------------------------------------------------------------------+
// Define constants and variables
#define PERIOD_SMA 100
#define PERIOD_MFI 14
double smaValue, mfiValue;
int lookBackPeriod = 50;

// Define functions
double getMFI(int period) {
    double positiveMoneyFlow = 0;
    double negativeMoneyFlow = 0;
    for (int i = 1; i <= period; i++) {
        double typicalPrice = (High[i] + Low[i] + Close[i]) / 3;
        double previousTypicalPrice = (High[i+1] + Low[i+1] + Close[i+1]) / 3;
        double moneyFlow = typicalPrice * Volume[i];

        if (typicalPrice > previousTypicalPrice) {
            positiveMoneyFlow += moneyFlow;
        } else if (typicalPrice < previousTypicalPrice) {
            negativeMoneyFlow += moneyFlow;
        }
    }

    if (negativeMoneyFlow == 0) {
        return 100; // or another default value that makes sense
    }

    double moneyRatio = positiveMoneyFlow / negativeMoneyFlow;
    return 100 - (100 / (1 + moneyRatio));
}

bool isEngulfingCandle(bool isBullish) {
    if (isBullish) {
        return (Close[1] > Open[1] && Close[1] > Close[2] && Open[1] < Close[2]);
    } else {
        return (Close[1] < Open[1] && Close[1] < Close[2] && Open[1] > Close[2]);
    }
}

// Add closing conditions
void closeTrades() {
    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            if (OrderType() == OP_BUY) {
                if (Close[1] < smaValue || isEngulfingCandle(false) || mfiValue < 50) {
                    if (!OrderClose(OrderTicket(), OrderLots(), Bid, 3, clrRed)) {
                        Print("Error closing buy order: ", GetLastError());
                    }
                }
            } else if (OrderType() == OP_SELL) {
                if (Close[1] > smaValue || isEngulfingCandle(true) || mfiValue > 50) {
                    if (!OrderClose(OrderTicket(), OrderLots(), Ask, 3, clrGreen)) {
                        Print("Error closing sell order: ", GetLastError());
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
void OnInit() {
    smaValue = iMA(NULL, 0, PERIOD_SMA, 0, MODE_SMA, PRICE_CLOSE, 0);
    mfiValue = getMFI(PERIOD_MFI);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    smaValue = iMA(NULL, 0, PERIOD_SMA, 0, MODE_SMA, PRICE_CLOSE, 0);
    mfiValue = getMFI(PERIOD_MFI);

    // Long conditions
    if (Close[1] > smaValue && isEngulfingCandle(true) && mfiValue > 50 && mfiValue < 80) {
        for (int i = 1; i <= lookBackPeriod; i++) {
            if (getMFI(i) < 20) {
                double stopLoss = Low[1] - (High[1] - Low[1]) * 2;
                double takeProfit = Close[1] + (Close[1] - stopLoss) * 2;
                int ticket = OrderSend(Symbol(), OP_BUY, 0.1, Ask, 3, stopLoss, takeProfit, "Buy order", 0, 0, clrGreen);
                if (ticket < 0) {
                    Print("Error opening buy order: ", GetLastError());
                }
                break;
            }
        }
    }

    // Short conditions
    if (Close[1] < smaValue && isEngulfingCandle(false) && mfiValue < 50 && mfiValue > 20) {
        for (int i = 1; i <= lookBackPeriod; i++) {
            if (getMFI(i) > 80) {
                double stopLoss = High[1] + (High[1] - Low[1]) * 2;
                double takeProfit = Close[1] - (stopLoss - Close[1]) * 2;
                int ticket = OrderSend(Symbol(), OP_SELL, 0.1, Bid, 3, stopLoss, takeProfit, "Sell order", 0, 0, clrRed);
                if (ticket < 0) {
                    Print("Error opening sell order: ", GetLastError());
                }
                break;
            }
        }
    }

    // Manage open positions
    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            if (OrderType() == OP_BUY) {
                if (Bid - OrderOpenPrice() >= (OrderTakeProfit() - OrderOpenPrice()) / 2) {
                    if (!OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), OrderTakeProfit(), 0, clrGreen)) {
                        Print("Error modifying buy order: ", GetLastError());
                    }
                }
            } else if (OrderType() == OP_SELL) {
                if (OrderOpenPrice() - Ask >= (OrderOpenPrice() - OrderTakeProfit()) / 2) {
                    if (!OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), OrderTakeProfit(), 0, clrRed)) {
                        Print("Error modifying sell order: ", GetLastError());
                    }
                }
            }
        }
    }

    // Close trades based on new conditions
    closeTrades();
}
