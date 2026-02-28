//+------------------------------------------------------------------+
//|                                          Sample_TrailingStop.mqh |
//|                                        MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property version   "1.00"

class CTrailingStop{
   protected:
      string m_symbol;              // symbol
      ENUM_TIMEFRAMES m_timeframe;  // timeframe
      bool m_eachtick;              // work on each tick
      bool m_indicator;             // show indicator on chart
      bool m_button;                // show "turn on/turn off" button
      int m_button_x;               // x coordinate of button
      int m_button_y;               // y coordinate of button
      color m_bgcolor;              // button color
      color m_txtcolor;             // button caption color
      int m_shift;                  // bar shift
      bool m_onoff;                 // turned on/turned off
      int m_handle;                 // indicator handle
      datetime m_lasttime;          // time of trailing stop last execution
      MqlTradeRequest m_request;    // trade request structure
      MqlTradeResult m_result;      // structure of trade request result
      int m_digits;                 // number of digits after comma for price
      double m_point;               // value of point
      string m_objname;             // button name
      string m_typename;            // name of trailing stop type
      string m_caption;             // button caption
   public:   
   void CTrailingStop(){};
   void ~CTrailingStop(){};
      //--- Trailing stop initialization method
      void Init(string             symbol,
                ENUM_TIMEFRAMES timeframe,
                bool    eachtick  =  true,
                bool    indicator = false,
                bool    button    = false,
                int     button_x  =     5,
                int     button_y  =    15,
                color   bgcolor   = Silver,
                color   txtcolor  =   Blue)
           {
         //--- set parameters
         m_symbol    = symbol;    // symbol
         m_timeframe = timeframe; // timeframe
         m_eachtick  = eachtick;  // true - work on each tick, false - work once per bar 
            //--- set bar, from which indicator value is used
            if(eachtick){ 
               m_shift=0; // created bar in per tick mode
            }
            else{
               m_shift=1;  // created bar in per bar mode
            }          
         m_indicator = indicator; // true - attach indicator to chart
         m_button = button;       // true - create button to turn on/turn off trailing stop
         m_button_x = button_x;   // x coordinate of button
         m_button_y = button_y;   // y coordinate of button
         m_bgcolor = bgcolor;     // button color
         m_txtcolor = txtcolor;   // button caption color   
         //--- get unchanged market history     
         m_digits=(int)SymbolInfoInteger(m_symbol,SYMBOL_DIGITS); // number of digits after comma for price
         m_point=SymbolInfoDouble(m_symbol,SYMBOL_POINT);         // value of point           
         //--- creating button name and button caption
         m_objname="CTrailingStop_"+m_typename+"_"+symbol;        // button name
         m_caption=symbol+" "+m_typename+" Trailing";             // button caption
         //--- filling the trade request structure
         m_request.symbol=m_symbol;                               // preparing trade request structure, setting symbol
         m_request.action=TRADE_ACTION_SLTP;                      // preparing trade request structure, setting type of trade action
         //--- creating button
            if(m_button){ 
               ObjectCreate(0,m_objname,OBJ_BUTTON,0,0,0);                 // creating
               ObjectSetInteger(0,m_objname,OBJPROP_XDISTANCE,m_button_x); // setting x coordinate
               ObjectSetInteger(0,m_objname,OBJPROP_YDISTANCE,m_button_y); // setting y coordinate
               ObjectSetInteger(0,m_objname,OBJPROP_BGCOLOR,m_bgcolor);    // setting background color
               ObjectSetInteger(0,m_objname,OBJPROP_COLOR,m_txtcolor);     // setting caption color
               ObjectSetInteger(0,m_objname,OBJPROP_XSIZE,120);            // setting width
               ObjectSetInteger(0,m_objname,OBJPROP_YSIZE,15);             // setting height
               ObjectSetInteger(0,m_objname,OBJPROP_FONTSIZE,7);           // setting font size
               ObjectSetString(0,m_objname,OBJPROP_TEXT,m_caption);        // setting button caption 
               ObjectSetInteger(0,m_objname,OBJPROP_STATE,false);          // setting button state, turned off by default
               ObjectSetInteger(0,m_objname,OBJPROP_SELECTABLE,false);     // user can't select and move button, only click it
               ChartRedraw();                                              // chart redraw 
            }
         //--- setting state of trailing stop          
         m_onoff=false;                                                    // state of trailing stop - turned on/turned off, turned off by default            
      };
      //--- Start timer
      bool StartTimer(){
         return(EventSetTimer(1));
      };
      //--- Stop timer
      void StopTimer(){
         EventKillTimer();
      };
      //--- Turn on trailing stop
      void On(){
         m_onoff=true; 
            // if button is used, it is "pressed"
            if(m_button){ 
               if(!ObjectGetInteger(0,m_objname,OBJPROP_STATE)){
                  ObjectSetInteger(0,m_objname,OBJPROP_STATE,true);
               }
            }
      }
      //--- Turn off trailing stop
      void Off(){ 
         m_onoff=false;
            // if button is used, it is "depressed"
            if(m_button){ 
               if(ObjectGetInteger(0,m_objname,OBJPROP_STATE)){
                  ObjectSetInteger(0,m_objname,OBJPROP_STATE,false);
               }
            }
      }   
      //--- Main method of controlling level of Stop Loss position   
      bool DoStoploss(){
            //--- if trailing stop is turned off
            if(!m_onoff){
               return(true);
            } 
         datetime tm[1];
            //--- get the time of last bar in per bar mode
            if(!m_eachtick){ 
               //--- if unable to copy time, finish method, repeat on next tick 
               if(CopyTime(m_symbol,m_timeframe,0,1,tm)==-1){
                  return(false); 
               }
               //--- if the bar time is equal to time of method's last execution - finish method
               if(tm[0]==m_lasttime){ 
                  return(true);
               }
            }               
            //--- get indicator values
            if(!Refresh()){ 
               return(false);
            }    
         double sl;                          
            //--- depending on trend, shown by indicator, do various actions
            switch (Trend()){ 
               //--- Up trend
               case 1: 
                  //--- select position. if succeeded, then position exists
                  if(PositionSelect(m_symbol)){ 
                     //--- if position is buy
                     if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY){ 
                        //--- get Stop Loss value for the buy position
                        sl=BuyStoploss(); 
                        //--- find out allowed level of Stop Loss placement for the buy position
                        double minimal=SymbolInfoDouble(m_symbol,SYMBOL_BID)-m_point*SymbolInfoInteger(m_symbol,SYMBOL_TRADE_STOPS_LEVEL); 
                        //--- value normalizing
                        sl=NormalizeDouble(sl,m_digits); 
                        //--- value normalizing
                        minimal=NormalizeDouble(minimal,m_digits); 
                        //--- if unable to place Stop Loss on level, obtained from indicator, this Stop Loss will be placed on closest possible level
                        sl=MathMin(sl,minimal); 
                        //--- value of Stop Loss position
                        double possl=PositionGetDouble(POSITION_SL); 
                        //--- value normalizing
                        possl=NormalizeDouble(possl,m_digits); 
                           //--- if new value of Stop Loss if bigger than current value of Stop Loss, an attempt to move Stop Loss on a new level will be made
                           if(sl>possl){ 
                              //--- filling request structure
                              m_request.sl=sl; 
                              //--- filling request structure
                              m_request.tp=PositionGetDouble(POSITION_TP); 
                              //--- request
                              OrderSend(m_request,m_result); 
                                 //--- check request result
                                 if(m_result.retcode!=TRADE_RETCODE_DONE){ 
                                    //--- log error message 
                                    printf("Unable to move Stop Loss of position %s, error #%I64u",m_symbol,m_result.retcode); 
                                    //--- unable to move Stop Loss, finishing
                                    return(false); 
                                 }
                           }
                     }
                  }
               break;
               //--- Down trend
               case -1: 
                  if(PositionSelect(m_symbol)){
                     if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL){
                        sl=SellStoploss();
                        //--- adding spread, since Sell is closing by the Ask price
                        sl+=(SymbolInfoDouble(m_symbol,SYMBOL_ASK)-SymbolInfoDouble(m_symbol,SYMBOL_BID)); 
                        double minimal=SymbolInfoDouble(m_symbol,SYMBOL_ASK)+m_point*SymbolInfoInteger(m_symbol,SYMBOL_TRADE_STOPS_LEVEL);
                        sl=NormalizeDouble(sl,m_digits);
                        minimal=NormalizeDouble(minimal,m_digits);
                        sl=MathMax(sl,minimal);
                        double possl=PositionGetDouble(POSITION_SL);
                        possl=NormalizeDouble(possl,m_digits);
                           if(sl<possl || possl==0){
                              m_request.sl=sl;
                              m_request.tp=PositionGetDouble(POSITION_TP);
                              OrderSend(m_request,m_result);
                                 if(m_result.retcode!=TRADE_RETCODE_DONE){
                                    printf("Unable to move Stop Loss of position %s, error #%I64u",m_symbol,m_result.retcode);
                                    return(false);
                                 }
                           }
                     }
                  }
               break;
            }
         //--- remember the time of method's last execution
         m_lasttime=tm[0]; 
         return(true);
      }
      //--- Method of tracking button state - turned on/turned off
      void EventHandle(const int id,const long & lparam,const double& dparam,const string& sparam){
         //--- there is an event with button
         if(id==CHARTEVENT_OBJECT_CLICK && sparam==m_objname){ 
            //--- check button state
            if(ObjectGetInteger(0,m_objname,OBJPROP_STATE)){ 
               On();  // turn on
            }
            else{
               Off(); // turn off
            }
         }
      }
      //--- Method of deinitialization
      void Deinit(){
         StopTimer();                     // stop timer
         IndicatorRelease(m_handle);      // release indicator handle
            if(m_button){
               ObjectDelete(0,m_objname); // delete button
               ChartRedraw(); 
            }
      }
      //--- Method of getting indicator values
      virtual bool Refresh(){
         return(false);
      }
      //--- Method of setting indicator parameters
      virtual void SetParameters(){
      };
      //--- Method of finding trend, shown by indicator
      virtual int Trend(){ 
         return(0);
      };
      //--- Method of getting Stop Loss value for buy
      virtual double BuyStoploss(){
         return(0);
      };   
      //--- Method of getting Stop Loss value for sell      
      virtual double SellStoploss(){
         return(0);
      };   
};

class CParabolicStop: public CTrailingStop {
   protected:
      double pricebuf[1]; // value of price
      double indbuf[1];   // value of indicator
   public:  
      void  CParabolicStop(){
         m_typename="SAR"; // setting name of trailing stop type
      };
      //--- Method of setting parameters and loading the indicator
      bool SetParameters(double sarstep=0.02,double sarmaximum=0.2){
         //--- loading the indicator
         m_handle=iSAR(m_symbol,m_timeframe,sarstep,sarmaximum); 
            //--- if unable to load indicator, method returns false
            if(m_handle==-1){
               return(false); 
            }
            if(m_indicator){
               //--- attach indicator to chart
               ChartIndicatorAdd(0,0,m_handle); 
            }         
         return(true);
      }
      //--- Method of getting indicator values
      bool Refresh(){
            //--- if unable to copy value to array, return false
            if(CopyBuffer(m_handle,0,m_shift,1,indbuf)==-1){
               return(false); 
            } 
            //--- if unable to copy value to array, return false
            if(CopyClose(m_symbol,m_timeframe,m_shift,1,pricebuf)==-1){
               return(false); 
            }  
         return(true);                   
      }
      //--- Method of finding trend
      int Trend(){
            //--- price is higher than indicator line, up trend
            if(pricebuf[0]>indbuf[0]){ 
               return(1);
            }
            //--- price is lower than indicator line, down trend
            if(pricebuf[0]<indbuf[0]){ 
               return(-1);
            }            
         return(0);
      } 
      //--- Method of finding out Stop Loss level for buy
      virtual double BuyStoploss(){
         return(indbuf[0]);
      };   
      //--- Method of finding out Stop Loss level for sell
      virtual double SellStoploss(){
         return(indbuf[0]);
      };            
};  
      


class CNRTRStop : public CTrailingStop {
   protected:
   double sup[1]; // value of support level
   double res[1]; // value of resistance level  
   public:  
      void  CNRTRStop(){
         m_typename="NRTR"; // setting name of trailing stop type
      };
      //--- Method of setting parameters and loading the indicator
      bool SetParameters(int period,double k){
         m_handle=iCustom(m_symbol,m_timeframe,"NRTR",period,k); // loading indicator
            //--- if unable to load indicator, method returns false
            if(m_handle==-1){ 
               return(false); 
            }
            if(m_indicator){  
               //--- attach indicator to chart
               ChartIndicatorAdd(0,0,m_handle); 
            }
         return(true);
      }
      //--- Method of getting indicator values
      bool Refresh(){
            //--- if unable to copy value to array, return false
            if(CopyBuffer(m_handle,0,m_shift,1,sup)==-1){
               return(false); 
            }      
            //--- if unable to copy value to array, return false
            if(CopyBuffer(m_handle,1,m_shift,1,res)==-1){
               return(false); 
            }              
         return(true);
      }
      //--- Method of finding trend
      int Trend(){
            //--- there is support line, then it is up trend
            if(sup[0]!=0){ 
               return(1);
            }
            //--- there is resistance line, then it is down trend
            if(res[0]!=0){ 
               return(-1);
            }            
         return(0);
      }

      //--- Method of finding out Stop Loss level for buy
      double BuyStoploss(){
         return(sup[0]);
      }; 
      //--- Method of finding out Stop Loss level for sell
      double SellStoploss(){
         return(res[0]);
      };       
};  
  



