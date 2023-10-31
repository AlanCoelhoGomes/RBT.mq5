//+------------------------------------------------------------------+
//|                                                          RBT.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Include                                                          |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
static input long    InpMagicnumber = 546812;  //Magic Number
static input double  InpLotSize     = 0.01;    //Lot Size
input int            InpRSIPeriod   = 21;      //RSI Period
input int            InpRSILevel    = 70;      //RSI Level (upper)
input int            InpMAPeriod    = 21;      //MA period
input ENUM_TIMEFRAMES InpMATimeframe = PERIOD_H1; //MA timmerframe
input int            InpStopLoss    = 200;     //Stop Loss in points (o=off)
input int            InpTakeProfit  = 100;     //Take Profit in points (0=off)
input bool           InpCloseSignal = false;   //Close Trades by opposite signal

//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+
int handleRSI;
int handleMA;
double bufferRSI[];
double bufferMA[];
MqlTick currentTick;
CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //check user inputs
   if(InpMagicnumber<=0) {
      Alert("Magicnumber <= 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpLotSize<=0 || InpLotSize>10) {
      Alert("Lot Size <= 0 or > 10");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpRSIPeriod<=1) {
      Alert("RSI Period <= 1");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpRSILevel>=100 || InpRSILevel <=50) {
      Alert("RSI Level >= 100 or <= 50");
      return INIT_PARAMETERS_INCORRECT;
   }
    if(InpMAPeriod<=1) {
      Alert("MA Period <= 1");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpStopLoss<0) {
      Alert("Stop Loss < 0");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpTakeProfit<0) {
      Alert("Take Profit <0");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   //Set magic number to trade object
   trade.SetExpertMagicNumber(InpMagicnumber);
   
   //create rsi handle
   handleRSI = iRSI(_Symbol,PERIOD_CURRENT,InpRSIPeriod,PRICE_OPEN);
   if(handleRSI == INVALID_HANDLE){
      Alert("Failed to create indicator handle");
      return INIT_FAILED;
   }
   handleMA = iMA(_Symbol,InpMATimeframe,InpMAPeriod,0,MODE_SMA,PRICE_OPEN);
   if(handleMA == INVALID_HANDLE){
      Alert("Failed to create indicator handle");
      return INIT_FAILED;
   }
   
   //set buffer as series
   ArraySetAsSeries(bufferRSI,true);
   ArraySetAsSeries(bufferMA,true);
   
  return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //release indicator handle
   if(handleRSI!=INVALID_HANDLE){IndicatorRelease(handleRSI);}
   if(handleMA!=INVALID_HANDLE){IndicatorRelease(handleMA);}

}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //check if current tick is a new bar open tick
   if(!IsNewBar()){return;}
   
   //get current ticks
   if(!SymbolInfoTick(_Symbol,currentTick)){Print("Failed to get current tick"); return;}
   
   //get rsi values
   int values = CopyBuffer(handleRSI,0,0,2,bufferRSI);
   if(values!=2){
      Print("Failed to get RSI values");
      return;
   }
   //get ma values
   values = CopyBuffer(handleMA,0,0,1,bufferMA);
   if(values!=1){
      Print("Failed to get MA values");
      return;
   }
   
   Comment("bufferRSI[0]:",bufferRSI[0],
           "\nbufferRSI[1]:",bufferRSI[1],
           "\nbufferMA[0]:",bufferMA[0]);
   
   //count open positions
   int cntBuy,cntSell;
   if(!CountOpenPositions(cntBuy,cntSell)){return;}
   
   //check for buy position
   if(cntBuy==0 && bufferRSI[1]>=(100-InpRSILevel) && bufferRSI[0]<(100-InpRSILevel) && currentTick.ask>bufferMA[0]){
   
      if(InpCloseSignal){if(!ClosePositions(2)){return;}}
      double sl = InpStopLoss==0 ? 0 : currentTick.bid - InpStopLoss * _Point;
      double tp = InpTakeProfit==0 ? 0 : currentTick.bid + InpTakeProfit * _Point;
      if(!NormalizePrice(sl)){return;}
      if(!NormalizePrice(tp)){return;}
      
      trade.PositionOpen(_Symbol,ORDER_TYPE_BUY,InpLotSize,currentTick.ask,sl,tp,"RSI MA filter EA");
   }
   
   //check for sell position
   if(cntBuy==0 && bufferRSI[1]<=InpRSILevel && bufferRSI[0]>InpRSILevel && currentTick.bid<bufferMA[0]){
 
      if(InpCloseSignal){if(!ClosePositions(1)){return;}}
      double sl = InpStopLoss==0 ? 0 : currentTick.bid + InpStopLoss * _Point;
      double tp = InpTakeProfit==0 ? 0 : currentTick.bid - InpTakeProfit * _Point;
      if(!NormalizePrice(sl)){return;}
      if(!NormalizePrice(tp)){return;}
      
      trade.PositionOpen(_Symbol,ORDER_TYPE_SELL,InpLotSize,currentTick.bid,sl,tp,"RSI MA filter EA");
   }
   
}

//+------------------------------------------------------------------+
//| Custom function                                                  |
//+------------------------------------------------------------------+

//check if we have a bar open tick
bool IsNewBar(){
   
   static datetime previousTime = 0;
   datetime curretTime = iTime(_Symbol,PERIOD_CURRENT,0);
   if(previousTime!=curretTime){
      previousTime=curretTime;
      return true;
   }
   return false;

}


//count open positions
bool CountOpenPositions(int &cntBuy, int &cntSell){
   
   cntBuy  = 0;
   cntSell = 0;
   int total = PositionsTotal();
   for(int i=total-1; i>=0; i--){
      ulong ticket = PositionGetTicket(i);
      if(ticket<=0){Print("Failed to get position ticket");return false;}
      long magic;
      if(!PositionGetInteger(POSITION_MAGIC,magic)){Print("Failed to get position magicnumber");return false;}
      if(magic==InpMagicnumber){
         long type;
         if(!PositionGetInteger(POSITION_TYPE,type)){Print("Failed to get position type"); return false;}
         if(type==POSITION_TYPE_BUY){cntBuy++;}
         if(type==POSITION_TYPE_SELL){cntSell++;}
      }
   }
   
   return true;
}

//normalize price
bool NormalizePrice(double &price){
   
   double tickSize=0;
   if(!SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE,tickSize)){
      Print("Failed to get tick size");
      return false;
   }
   price = NormalizeDouble(MathRound(price/tickSize)*tickSize,_Digits);
   
   return true;
}



//close positions
bool ClosePositions(int all_buy_sell){
   
   int total = PositionsTotal();
   for(int i=total-1; i>=0; i--){
      ulong ticket = PositionGetTicket(i);
      if(ticket<=0){Print("Failed to get position ticket"); return false;}
      if(!PositionSelectByTicket(ticket)){Print("Failed to select position");return false;}
      long magic;
      if(!PositionGetInteger(POSITION_MAGIC,magic)){Print("Failed to get position magicnumber");return false;}
      if(magic==InpMagicnumber){
         long type;
         if(!PositionGetInteger(POSITION_TYPE,type)){Print("Failed to get position type"); return false;}
         if(all_buy_sell==1 && type==POSITION_TYPE_SELL){continue;}
         if(all_buy_sell==2 && type==POSITION_TYPE_BUY){continue;}
         trade.PositionClose(ticket);
         if(trade.ResultRetcode()!=TRADE_RETCODE_DONE){
            Print("Failed to close position. ticket:",
                 (string)ticket,"result:",(string)trade.ResultRetcode(),":",trade.CheckResultRetcodeDescription());
         }
      }
   }
   return true;

}






//+------------------------------------------------------------------+
