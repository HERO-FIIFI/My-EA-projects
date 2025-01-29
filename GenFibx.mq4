//+------------------------------------------------------------------+
//|                                                      GenFibx.mq4 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict// Expert Advisor parameters
// Expert Advisor parameters
input double RiskManagementOption = 0.005; // 0.5% risk per trade
input double RiskManagementOptionProfit = 0.01; // 1% risk per trade after 25% profit

// Declare variables
double initial_balance;
double current_risk_option; // Variable to track current risk management option
string symbols[] = {"EURUSD", "GBPUSD", "GBPJPY", "NZDUSD"};
ENUM_TIMEFRAMES timeframe = PERIOD_H4;
datetime lastTradeTime;

// Initialization function
void OnInit()
{
    initial_balance = AccountBalance();
    Print("Initial balance: ", initial_balance);
    current_risk_option = RiskManagementOption;
    lastTradeTime = TimeCurrent();
}

// Function to calculate lot size based on risk percentage
double CalculateLotSize(double riskPercentage, double stopLoss, double askPrice)
{
    double lotSize = (riskPercentage * AccountBalance()) / (askPrice - stopLoss);
    return lotSize;
}

// Function to check if TP and SL are equal
bool IsTPEqualSL(double tp, double sl)
{
    const double tolerance = 0.0001; // Tolerance to handle floating point comparison
    return MathAbs(tp - sl) < tolerance;
}

// Expert Advisor tick function
void OnTick()
{
    for (int i = 0; i < ArraySize(symbols); i++)
    {
        MqlRates rates[];
        int copied = CopyRates(symbols[i], timeframe, 0, 100, rates);
        if (copied < 0)
        {
            Print("Failed to retrieve market data for ", symbols[i]);
            continue;
        }

        double high = iHigh(symbols[i], timeframe, 0);
        double low = iLow(symbols[i], timeframe, 0);
        double diff = high - low;

        double fibLevels[];
        ArrayResize(fibLevels, 6); // Allocate memory for the fibLevels array
        fibLevels[0] = high - 0.236 * diff;
        fibLevels[1] = high - 0.382 * diff;
        fibLevels[2] = high - 0.500 * diff;
        fibLevels[3] = high - 0.618 * diff;
        fibLevels[4] = high - 0.786 * diff;
        fibLevels[5] = high - 0.75 * diff;

        bool uptrend = rates[0].low > rates[1].low && rates[0].high > rates[1].high;
        bool downtrend = rates[0].low < rates[1].low && rates[0].high < rates[1].high;

        double sl, tp, lot_size;
        double price = SymbolInfoDouble(symbols[i], SYMBOL_ASK);

        // Place orders based on conditions
        if (uptrend && rates[0].close <= fibLevels[5])
        {
            sl = low;
            tp = high;

            // Check if tp and sl are not equal
            if (!IsTPEqualSL(tp, sl))
            {
                lot_size = CalculateLotSize(current_risk_option, sl, price);

                if (lot_size <= 0.0)
                {
                    Print("Invalid lot size for ", symbols[i]);
                    continue; // Skip this iteration
                }

                int ticket = OrderSend(symbols[i], OP_BUYLIMIT, lot_size, price, 20, sl, tp, "Buy limit order", 0, Blue);
                if (ticket < 0)
                {
                    Print("Order send failed for ", symbols[i], ". Error code: ", GetLastError());
                }
                else
                {
                    Print("Order placed: Buy ", lot_size, " lots of ", symbols[i], " at ", price);
                    lastTradeTime = TimeCurrent(); // Update the last trade time
                }
            }
            else
            {
                Print("Cannot place order for ", symbols[i], ". Take Profit and Stop Loss are equal.");
            }
        }
        else if (downtrend && rates[0].close >= fibLevels[5])
        {
            sl = high;
            tp = low;

            // Check if tp and sl are not equal
            if (!IsTPEqualSL(tp, sl))
            {
                lot_size = CalculateLotSize(current_risk_option, sl, price);

                if (lot_size <= 0.0)
                {
                    Print("Invalid lot size for ", symbols[i]);
                    continue; // Skip this iteration
                }

                int ticket = OrderSend(symbols[i], OP_SELLLIMIT, lot_size, price, 20, sl, tp, "Sell limit order", 0, Red);
                if (ticket < 0)
                {
                    Print("Order send failed for ", symbols[i], ". Error code: ", GetLastError());
                }
                else
                {
                    Print("Order placed: Sell ", lot_size, " lots of ", symbols[i], " at ", price);
                    lastTradeTime = TimeCurrent(); // Update the last trade time
                }
            }
            else
            {
                Print("Cannot place order for ", symbols[i], ". Take Profit and Stop Loss are equal.");
            }
        }
    }

    // Update risk management if in profit by 25% of initial balance
    double current_balance = AccountBalance();
    if (current_balance >= initial_balance * 1.25)
    {
        current_risk_option = RiskManagementOptionProfit;
        Print("Account balance increased by 25%. Adjusting risk management.");
    }

    Sleep(300000); // Sleep for 5 minutes
}

// Expert Advisor deinitialization function
void OnDeinit(const int reason)
{
    Print("Expert Advisor deactivated. Reason: ", reason);
}
