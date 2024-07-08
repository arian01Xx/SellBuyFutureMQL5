#include <Trade/Trade.mqh>

//trade
input double AccountRisk=0.1;
input double RiskPercent=2.0;
input double Lots=0.1;
input int TslPoints=5;
input int TslTriggerPoints=10;
input int OrderDistPoints=100;
input int ExpirationMinutes=15;
int takeProfits=100;
int stopLoss=100;
int magic=11;
ulong buyPos; 
ulong sellPos;
int totalBars;
double ask;
double bid;
double tpB;
double slB;
double tpS;
double slS;
int bars;

//bollinger Bands
int bollingerBans;
double middelBandArray[];
double upperBandArray[];
double lowerBandArray[];
double middelBandA;
double upperBandA;
double lowerBandA;

//rsi
int Rsi;
double RSI[];
double RSIvalue;

//stochastic
int stoch;
double KArray[];
double DArray[];
double KAvalue0;
double DAvalue0;
double KAvalue1;
double DAvalue1;

//MA indicator
int handleTrendMaFast;
int handleTrendMaSlow;
double maTrendFast[];
double maTrendSlow[];
double FastValue;
double SlowValue;

CTrade trade;

int OnInit(){
   
   //bollinger Bands 
   bollingerBans=iBands(_Symbol,PERIOD_M5,20,0,2,PRICE_CLOSE);
   
   //rsi
   Rsi=iRSI(_Symbol,PERIOD_M15,14,PRICE_CLOSE);
   
   //stochastic
   stoch=iStochastic(_Symbol,PERIOD_M15,14,3,3,MODE_EMA,STO_LOWHIGH);
   
   //MA indicator
   handleTrendMaFast=iMA(_Symbol,PERIOD_M15,8,0,MODE_EMA,PRICE_CLOSE);
   handleTrendMaSlow=iMA(_Symbol,PERIOD_M15,21,0,MODE_EMA,PRICE_CLOSE);
   
   //trade
   ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   bars=iBars(_Symbol,PERIOD_M15);
   
   //buying
   tpB=ask+takeProfits*_Point;
   slB=ask-stopLoss*_Point;
   
   tpB=NormalizeDouble(tpB,_Digits);
   slB=NormalizeDouble(slB,_Digits);
   
   //selling
   tpS=bid-takeProfits*_Point;
   slS=bid+takeProfits*_Point;
   
   tpS=NormalizeDouble(tpS,_Digits);
   slS=NormalizeDouble(slS,_Digits);
   
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){
 
}

void OnTick(){

   //bollinger bands
   ArraySetAsSeries(middelBandArray,true);
   ArraySetAsSeries(upperBandArray,true);
   ArraySetAsSeries(lowerBandArray,true);
   
   CopyBuffer(bollingerBans,0,0,3,middelBandArray);
   CopyBuffer(bollingerBans,1,0,3,upperBandArray);
   CopyBuffer(bollingerBans,2,0,3,lowerBandArray);
   
   middelBandA=NormalizeDouble(middelBandArray[0],_Digits);
   upperBandA=NormalizeDouble(upperBandArray[0],_Digits);
   lowerBandA=NormalizeDouble(lowerBandArray[0],_Digits);
   
   //rsi
   ArraySetAsSeries(RSI,true);
   CopyBuffer(Rsi,0,0,3,RSI);
   RSIvalue=NormalizeDouble(RSI[0],_Digits);
   
   //stochastic
   ArraySetAsSeries(KArray,true);
   ArraySetAsSeries(DArray,true);
   
   CopyBuffer(stoch,0,0,3,KArray);
   CopyBuffer(stoch,1,0,3,DArray);
   
   KAvalue0=NormalizeDouble(KArray[0],_Digits);
   DAvalue0=NormalizeDouble(DArray[0],_Digits);
   KAvalue1=NormalizeDouble(KArray[1],_Digits);
   DAvalue1=NormalizeDouble(DArray[1],_Digits);
   
   //MA indicator
   ArraySetAsSeries(maTrendFast,true);
   ArraySetAsSeries(maTrendSlow,true);
   
   CopyBuffer(handleTrendMaFast,0,0,3,maTrendFast);
   CopyBuffer(handleTrendMaSlow,1,0,3,maTrendSlow);
   
   FastValue=NormalizeDouble(maTrendFast[0],_Digits);
   SlowValue=NormalizeDouble(maTrendSlow[0],_Digits);
   
   //trade
   processPos(buyPos);
   processPos(sellPos);
   trade.Buy(Lots,_Symbol,ask,slB,tpB);
   trade.Sell(Lots,_Symbol,bid,slS,tpS);
   
   //strategy all indicator
   if(ask>lowerBandA){
     if((KAvalue0<50 && DAvalue0<50) && (KAvalue1<DAvalue1)){
       if(RSIvalue<30 && KAvalue0<20 && DAvalue0<20){
         //buying
         if(totalBars!=bars){
            totalBars=bars;
            if(buyPos<=0){
              executeBuy(ask);
              trade.Buy(Lots,_Symbol,ask,slB,tpB);
            }
         }
       }
     }
   }else if(bid>upperBandA){
     if((KAvalue0>50 && DAvalue0>50) && (KAvalue1>DAvalue1)){
       if(RSIvalue>70 && KAvalue0>80 && DAvalue0>80){
         //selling
         if(totalBars!=bars){
            totalBars=bars;
            if(sellPos<=0){
              executeSell(bid);
              trade.Sell(Lots,_Symbol,bid,slS,tpS);
            }
         }
       }
     }
   }
}

void OnTradeTransaction(
   const MqlTradeTransaction& trans,
   const MqlTradeRequest& request,
   const MqlTradeResult& result
   ){
   
   if(trans.type==TRADE_TRANSACTION_ORDER_ADD){
     COrderInfo order;
     if(order.Select(trans.order)){
       if(order.Magic()==magic){
         if(order.OrderType()==ORDER_TYPE_BUY_STOP){
           buyPos=order.Ticket();
         }else if(order.OrderType()==ORDER_TYPE_SELL_STOP){
           sellPos=order.Ticket();
         }
       }
     }
   }

}

void processPos(ulong &posTicket){
   if(posTicket<=0) return;
   if(OrderSelect(posTicket)) return;
   
   CPositionInfo pos;
   if(!pos.SelectByTicket(posTicket)){
     posTicket=0;
     return;
   }else{
     if(pos.PositionType()==POSITION_TYPE_BUY){
       double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
       if(bid>pos.PriceCurrent()+TslTriggerPoints*_Point){
         double sl=bid-TslPoints*_Point;
         if(sl>pos.StopLoss()){
           trade.PositionModify(pos.Ticket(),sl,pos.TakeProfit());
         }
       }
     }else if(pos.PositionType()==POSITION_TYPE_SELL){
       double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
       if(ask<pos.PriceOpen()-TslTriggerPoints*_Point){
         double sl=ask+TslPoints*_Point;
         sl=NormalizeDouble(sl,_Digits);
         if(sl<pos.StopLoss() || pos.StopLoss()==0){
           trade.PositionModify(pos.Ticket(),sl,pos.TakeProfit());
         }
       }
     }
   }
}

void executeBuy(double entry){
   
   entry=NormalizeDouble(entry,_Digits);
   if(ask>entry-OrderDistPoints*_Point) return;
   
   double tp=entry+takeProfits*_Point; //tppoints es el takeprofit
   tp=NormalizeDouble(tp,_Digits);
   
   double sl=entry-stopLoss*_Point; //slpoints es el stoplos
   sl=NormalizeDouble(sl,_Digits);
   
   double lots=Lots;
   if(RiskPercent>0) lots=calcLots(entry-sl);
   
   datetime expiration=iTime(_Symbol,PERIOD_M15,0)+ExpirationMinutes*PeriodSeconds(PERIOD_M15); //timeframe period_m15
   trade.BuyStop(lots,entry,_Symbol,sl,tp,ORDER_TIME_SPECIFIED,expiration);
   buyPos=trade.ResultOrder();
}

void executeSell(double entry){
   
   entry=NormalizeDouble(entry,_Digits);
   if(bid<entry+OrderDistPoints*_Point) return;
   
   double tp=entry-OrderDistPoints*_Point;
   tp=NormalizeDouble(tp,_Digits);
   
   double sl=entry+stopLoss*_Point;
   sl=NormalizeDouble(sl,_Digits);
   
   double lots=Lots;
   if(RiskPercent>0) lots=calcLots(sl-entry);
   
   datetime expiration=iTime(_Symbol,PERIOD_M15,0)+ExpirationMinutes*PeriodSeconds(PERIOD_M15);
   
   trade.SellStop(lots,entry,_Symbol,sl,tp,ORDER_TIME_SPECIFIED,expiration);
   sellPos=trade.ResultOrder();
}

double calcLots(double slPoints){
   double risk=AccountInfoDouble(ACCOUNT_BALANCE)*RiskPercent/100;
   double tickSize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tickValue=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double lotstep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   
   double moneyPerLotstep=slPoints/tickSize*tickValue*lotstep;
   double lots=MathFloor(risk/moneyPerLotstep)*lotstep;
   
   lots=MathMin(lots,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX));
   lots=MathMax(lots,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN));
   
   return lots;
}