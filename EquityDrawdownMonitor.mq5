//+------------------------------------------------------------------+
//|                                        EquityDrawdownMonitor.mq5 |
//|                                          AntiGravity Assistant   |
//|                        https://github.com/google-deepmind/       |
//+------------------------------------------------------------------+
#property copyright "AntiGravity Assistant"
#property link      "https://github.com/google-deepmind/"
#property version   "1.10"
#property strict

#include <Trade\Trade.mqh>

//--- Input parameters
input int      InpLookbackDays       = 60;           // Lookback Days for Magic Discovery
input int      InpRefreshRateSeconds = 1;            // Refresh Rate (seconds)
input int      InpHelpXPosition      = 950;          // Help Text X Position
input bool     InpEnableAutoStop     = true;         // Enable Emergency Stop

// Drawdown limit configurations (format: "MagicNumber,MaxDrawdown")
input string   InpCheck1  = "";  // Check 1: Magic,MaxDD
input string   InpCheck2  = "";  // Check 2: Magic,MaxDD
input string   InpCheck3  = "";  // Check 3: Magic,MaxDD
input string   InpCheck4  = "";  // Check 4: Magic,MaxDD
input string   InpCheck5  = "";  // Check 5: Magic,MaxDD
input string   InpCheck6  = "";  // Check 6: Magic,MaxDD
input string   InpCheck7  = "";  // Check 7: Magic,MaxDD
input string   InpCheck8  = "";  // Check 8: Magic,MaxDD
input string   InpCheck9  = "";  // Check 9: Magic,MaxDD
input string   InpCheck10 = "";  // Check 10: Magic,MaxDD
input string   InpCheck11 = "";  // Check 11: Magic,MaxDD
input string   InpCheck12 = "";  // Check 12: Magic,MaxDD
input string   InpCheck13 = "";  // Check 13: Magic,MaxDD
input string   InpCheck14 = "";  // Check 14: Magic,MaxDD
input string   InpCheck15 = "";  // Check 15: Magic,MaxDD
input string   InpCheck16 = "";  // Check 16: Magic,MaxDD
input string   InpCheck17 = "";  // Check 17: Magic,MaxDD
input string   InpCheck18 = "";  // Check 18: Magic,MaxDD
input string   InpCheck19 = "";  // Check 19: Magic,MaxDD
input string   InpCheck20 = "";  // Check 20: Magic,MaxDD

//--- Class to monitor a single Magic Number
class CMagicMonitor {
private:
   long     m_magic;
   double   m_realized_profit;
   double   m_floating_profit;
   double   m_current_equity;
   double   m_max_equity;
   double   m_current_drawdown; 
   double   m_max_drawdown;
   double   m_max_allowed_drawdown; // Configured limit
   bool     m_emergency_stopped;    // Emergency stop flag
   
   // Optimization members
   datetime m_last_history_time;
   ulong    m_last_deal_ticket;

public:
   CMagicMonitor(long magic, double max_allowed_dd = 0.0) : m_magic(magic), m_max_allowed_drawdown(max_allowed_dd) {
      m_realized_profit = 0.0;
      m_floating_profit = 0.0;
      m_current_equity = 0.0;
      m_max_equity = -DBL_MAX; 
      m_current_drawdown = 0.0;
      m_max_drawdown = 0.0;
      m_emergency_stopped = false;
      
      m_last_history_time = 0;
      m_last_deal_ticket = 0;
   }

   long GetMagic() const { return m_magic; }
   double GetRealizedOutput() const { return m_realized_profit; }
   double GetFloating() const { return m_floating_profit; }
   double GetEquity() const { return m_current_equity; }
   double GetDrawdown() const { return m_current_drawdown; }
   double GetMaxDrawdown() const { return m_max_drawdown; }
   double GetDrawdownPercent() const { 
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      if(balance <= 0) return 0.0;
      return (m_current_drawdown / balance) * 100.0; 
   }
   
   double GetMaxDrawdownPercent() const {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      if(balance <= 0) return 0.0;
      return (m_max_drawdown / balance) * 100.0;
   }
   
   double GetMaxAllowedDrawdown() const { return m_max_allowed_drawdown; }
   bool IsEmergencyStopped() const { return m_emergency_stopped; }
   
   color GetRowColor() const {
      if(m_emergency_stopped) return clrGray; // Stopped magic
      if(m_max_allowed_drawdown <= 0.0) return clrWhite; // No limit configured
      
      // Compare percentage drawdown with percentage limit
      double current_dd_percent = GetDrawdownPercent();
      double ratio = current_dd_percent / m_max_allowed_drawdown;
      
      if(ratio >= 1.0) return clrRed;      // 100% or more
      if(ratio >= 0.9) return clrOrange;   // 90% or more
      if(ratio >= 0.8) return clrYellow;   // 80% or more
      return clrWhite;                      // Below 80%
   }
   
   void TriggerEmergencyStop() {
      if(m_emergency_stopped) return; // Already stopped
      
      m_emergency_stopped = true;
      
      // 1. Close all positions for this magic
      CloseAllPositionsByMagic(m_magic);
      
      // 2. Set global variable
      string var_name = "EDM_STOP_MAGIC_" + IntegerToString(m_magic);
      GlobalVariableSet(var_name, 1);
      
      // 3. Send Email
      string subject = "EMERGENCY STOP - Magic " + IntegerToString(m_magic);
      string body = StringFormat(
         "DRAWDOWN LIMIT ERREICHT!\n\n" +
         "Magic Number: %d\n" +
         "Aktueller Drawdown: %.1f%%\n" +
         "Limit: %.1f%%\n\n" +
         "Alle Positionen wurden geschlossen!\n" +
         "Zeit: %s",
         m_magic, 
         GetDrawdownPercent(), 
         m_max_allowed_drawdown,
         TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS)
      );
      
      if(!SendMail(subject, body)) {
         Print("Failed to send email. Check MT5 Email settings!");
      }
      
      // 4. Log
      Print("EMERGENCY STOP triggered for Magic ", m_magic);
      
      // 5. Show alert
      ShowEmergencyAlert(m_magic, GetDrawdownPercent(), m_max_allowed_drawdown);
   }

   // Core logic to process history within a time range
   void ProcessHistory(datetime start, datetime end) {
      if(!HistorySelect(start, end)) {
         return; 
      }
      
      int total_deals = HistoryDealsTotal();
      for(int i = 0; i < total_deals; i++) {
         ulong ticket = HistoryDealGetTicket(i);
         
         if(ticket > m_last_deal_ticket) {
            long deal_magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
            
            if(deal_magic == m_magic) {
               long type = HistoryDealGetInteger(ticket, DEAL_TYPE);
               
               if(type == DEAL_TYPE_BUY || type == DEAL_TYPE_SELL) {
                  double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                  double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
                  double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
                  m_realized_profit += (profit + commission + swap);
               }
            }
            
            m_last_deal_ticket = ticket;
            datetime time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
            if(time > m_last_history_time) {
               m_last_history_time = time;
            }
         }
      }
   }

   // Initialize realized profit from history
   void InitFromHistory() {
      m_realized_profit = 0.0;
      m_last_deal_ticket = 0;
      m_last_history_time = 0;
      
      // Load everything from start of time until now
      ProcessHistory(0, TimeCurrent());
      
      // Initialize equity - this is the starting point, the "high water mark"
      m_current_equity = m_realized_profit;
      // Start with current equity as max (even if negative - it's still the highest we've seen)
      m_max_equity = m_current_equity;
      // No drawdown at start
      m_current_drawdown = 0.0;
   }

   // Update floating profit and stats
   void Update() {
      // 1. Update Realized Profit (Incremental)
      ProcessHistory(m_last_history_time, TimeCurrent() + 60); 

      // 2. Update Floating Profit
      m_floating_profit = 0.0;
      
      int total_positions = PositionsTotal();
      for(int i = 0; i < total_positions; i++) {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0) {
            if(PositionGetInteger(POSITION_MAGIC) == m_magic) {
               double profit = PositionGetDouble(POSITION_PROFIT);
               double swap = PositionGetDouble(POSITION_SWAP);
               m_floating_profit += (profit + swap);
            }
         }
      }

      // 3. Calc Metrics
      m_current_equity = m_realized_profit + m_floating_profit;

      // Update High Water Mark
      if(m_current_equity > m_max_equity) {
         m_max_equity = m_current_equity;
         m_current_drawdown = 0.0;
      } else {
         m_current_drawdown = m_max_equity - m_current_equity;
      }

      // Update Max Drawdown
      if(m_current_drawdown > m_max_drawdown) {
         m_max_drawdown = m_current_drawdown;
      }
      
      // Check for emergency stop
      if(InpEnableAutoStop && !m_emergency_stopped && m_max_allowed_drawdown > 0.0) {
         double current_dd_percent = GetDrawdownPercent();
         if(current_dd_percent >= m_max_allowed_drawdown) {
            TriggerEmergencyStop();
         }
      }
   }
};

//--- Global Variables
CMagicMonitor *monitors[];
int monitor_count = 0;
bool show_help = false; // Toggle for help text display

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Parse drawdown limits into a map
   string check_inputs[];
   ArrayResize(check_inputs, 20);
   check_inputs[0] = InpCheck1; check_inputs[1] = InpCheck2; check_inputs[2] = InpCheck3; check_inputs[3] = InpCheck4;
   check_inputs[4] = InpCheck5; check_inputs[5] = InpCheck6; check_inputs[6] = InpCheck7; check_inputs[7] = InpCheck8;
   check_inputs[8] = InpCheck9; check_inputs[9] = InpCheck10; check_inputs[10] = InpCheck11; check_inputs[11] = InpCheck12;
   check_inputs[12] = InpCheck13; check_inputs[13] = InpCheck14; check_inputs[14] = InpCheck15; check_inputs[15] = InpCheck16;
   check_inputs[16] = InpCheck17; check_inputs[17] = InpCheck18; check_inputs[18] = InpCheck19; check_inputs[19] = InpCheck20;
   
   // Structure to hold magic -> max_dd mapping
   long limit_magics[20];
   double limit_values[20];
   int limit_count = 0;
   
   // Initialize arrays to 0
   for(int i = 0; i < 20; i++) {
      limit_magics[i] = 0;
      limit_values[i] = 0.0;
   }
   
   for(int i = 0; i < 20; i++) {
      if(StringLen(check_inputs[i]) > 0) {
         string parts[];
         if(StringSplit(check_inputs[i], ',', parts) == 2) {
            long magic = StringToInteger(parts[0]);
            double max_dd = StringToDouble(parts[1]);
            limit_magics[limit_count] = magic;
            limit_values[limit_count] = max_dd;
            limit_count++;
         }
      }
   }
   
   // Auto-discover Magic Numbers from history
   datetime lookback_time = TimeCurrent() - (InpLookbackDays * 86400);
   
   if(!HistorySelect(lookback_time, TimeCurrent())) {
      Print("Failed to select history for magic discovery");
      return(INIT_FAILED);
   }
   
   // Collect unique magic numbers
   long discovered_magics[];
   int magic_count = 0;
   
   int total_deals = HistoryDealsTotal();
   for(int i = 0; i < total_deals; i++) {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0) {
         long magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
         long deal_type = HistoryDealGetInteger(ticket, DEAL_TYPE);
         
         // Only consider actual trades (not balance operations)
         if(deal_type == DEAL_TYPE_BUY || deal_type == DEAL_TYPE_SELL) {
            // Check if magic already in list
            bool found = false;
            for(int j = 0; j < magic_count; j++) {
               if(discovered_magics[j] == magic) {
                  found = true;
                  break;
               }
            }
            
            if(!found) {
               ArrayResize(discovered_magics, magic_count + 1);
               discovered_magics[magic_count] = magic;
               magic_count++;
            }
         }
      }
   }
   
   // Create monitors for discovered magics
   monitor_count = magic_count;
   ArrayResize(monitors, monitor_count);
   
   for(int i = 0; i < monitor_count; i++) {
      // Find if this magic has a configured limit
      double max_allowed = 0.0;
      for(int j = 0; j < limit_count; j++) {
         if(limit_magics[j] == discovered_magics[i]) {
            max_allowed = limit_values[j];
            break;
         }
      }
      
      monitors[i] = new CMagicMonitor(discovered_magics[i], max_allowed);
      monitors[i].InitFromHistory();
   }
   
   Print("Discovered ", monitor_count, " magic numbers in last ", InpLookbackDays, " days");
   
   // Setup timer
   EventSetTimer(InpRefreshRateSeconds);
   
   // Initial display
   UpdateDashboard();
   
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   ObjectsDeleteAll(0, "EDM_"); // Clear all our objects (labels and button)
   
   // Clean up memory
   for(int i = 0; i < monitor_count; i++) {
      if(CheckPointer(monitors[i]) == POINTER_DYNAMIC) {
         delete monitors[i];
      }
   }
   ArrayFree(monitors);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
   for(int i = 0; i < monitor_count; i++) {
      monitors[i].Update();
   }
   UpdateDashboard();
  }
//+------------------------------------------------------------------+
//| Chart event handler                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id == CHARTEVENT_OBJECT_CLICK) {
      if(sparam == "EDM_InfoButton") {
         show_help = !show_help; // Toggle help
         UpdateDashboard(); // Refresh display
         ObjectSetInteger(0, "EDM_InfoButton", OBJPROP_STATE, false); // Unpress button
      }
   }
  }
//+------------------------------------------------------------------+
//| Custom functions                                                 |
//+------------------------------------------------------------------+
void CloseAllPositionsByMagic(long magic) {
   CTrade trade;
   trade.SetAsyncMode(false); // Synchronous mode
   
   // Loop backwards to handle position array changes
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0) {
         if(PositionGetInteger(POSITION_MAGIC) == magic) {
            if(!trade.PositionClose(ticket)) {
               Print("Failed to close position ", ticket, " for Magic ", magic, ". Error: ", GetLastError());
            } else {
               Print("Closed position ", ticket, " for Magic ", magic);
            }
         }
      }
   }
}

void ShowEmergencyAlert(long magic, double dd_percent, double limit) {
   string message = StringFormat(
      "⚠ DRAWDOWN LIMIT ERREICHT! ⚠\n\n" +
      "Magic Number: %d\n" +
      "Aktueller Drawdown: %.1f%%\n" +
      "Konfiguriertes Limit: %.1f%%\n\n" +
      "ALLE POSITIONEN GESCHLOSSEN!\n\n" +
      "Globale Variable gesetzt:\n" +
      "EDM_STOP_MAGIC_%d = 1\n\n" +
      "Andere EAs mit dieser Magic müssen\n" +
      "diese Variable prüfen!",
      magic, dd_percent, limit, magic
   );
   
   MessageBox(message, "EMERGENCY STOP - Magic " + IntegerToString(magic), MB_OK | MB_ICONERROR);
}

void DrawLabel(string name, string text, int x, int y, int size=10, color clr=clrWhite) {
   if(ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas"); 
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   }
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

void CreateInfoButton() {
   string btn_name = "EDM_InfoButton";
   if(ObjectFind(0, btn_name) < 0) {
      ObjectCreate(0, btn_name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, btn_name, OBJPROP_XDISTANCE, 680);
      ObjectSetInteger(0, btn_name, OBJPROP_YDISTANCE, 20);
      ObjectSetInteger(0, btn_name, OBJPROP_XSIZE, 30);
      ObjectSetInteger(0, btn_name, OBJPROP_YSIZE, 20);
      ObjectSetInteger(0, btn_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetString(0, btn_name, OBJPROP_TEXT, "?");
      ObjectSetInteger(0, btn_name, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, btn_name, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, btn_name, OBJPROP_BGCOLOR, clrBlue);
   }
}

void ShowHelp(int y_start) {
   int y = y_start;
   int step = 18;
   int x = InpHelpXPosition; // Use configurable position
   
   DrawLabel("EDM_Help_Title", "=== SPALTEN-ERKLÄRUNG ===", x, y, 10, clrYellow);
   y += step * 2;
   
   DrawLabel("EDM_Help_1", "Realzd: Summe aller GESCHLOSSENEN Trades", x, y, 9, clrSilver);
   y += step;
   DrawLabel("EDM_Help_2", "Float: Gewinn/Verlust aller OFFENEN Positionen", x, y, 9, clrSilver);
   y += step;
   DrawLabel("EDM_Help_3", "Equity: Gesamtstand (Realzd + Float)", x, y, 9, clrSilver);
   y += step * 2;
   
   DrawLabel("EDM_Help_4", "DD%: Aktueller Drawdown vom höchsten Punkt", x, y, 9, clrSilver);
   y += step;
   DrawLabel("EDM_Help_5", "  -> Berechnet relativ zum Account Balance", x, y, 9, clrSilver);
   y += step;
   DrawLabel("EDM_Help_6", "  -> 0% = Am höchsten Punkt (High Water Mark)", x, y, 9, clrSilver);
   y += step * 2;
   
   DrawLabel("EDM_Help_7", "MaxDD%: Größter Drawdown jemals beobachtet", x, y, 9, clrSilver);
   y += step * 2;
   
   DrawLabel("EDM_Help_8", "MaxAlw: Konfiguriertes Drawdown-Limit", x, y, 9, clrSilver);
   y += step;
   DrawLabel("EDM_Help_9", "  -> Bei DD% >= Limit: EMERGENCY STOP!", x, y, 9, clrRed);
   y += step;
   DrawLabel("EDM_Help_10", "  -> Alle Positionen werden geschlossen", x, y, 9, clrOrange);
   y += step;
   DrawLabel("EDM_Help_11", "  -> Status wird auf STOPPED gesetzt", x, y, 9, clrYellow);
   y += step * 2;
   
   DrawLabel("EDM_Help_12", "Status: ACTIVE = Normal / STOPPED = Limit erreicht", x, y, 9, clrSilver);
}

void HideHelp() {
   for(int i = 1; i <= 12; i++) {
      ObjectDelete(0, "EDM_Help_" + IntegerToString(i));
   }
   ObjectDelete(0, "EDM_Help_Title");
}

void UpdateDashboard() {
   int y_base = 20;
   int y_step = 22; // Adjusted for smaller font
   
   // Create Info Button
   CreateInfoButton();
   
   // Title
   DrawLabel("EDM_Label_Title", "Equity Drawdown Monitor v1.10", 20, y_base, 12, clrWhite);
   y_base += 26;
   
   if(show_help) {
      // Show help instead of table
      HideHelp(); // Clear first
      ShowHelp(y_base);
      return;
   } else {
      HideHelp(); // Make sure help is hidden
   }
   
   // Header
   string header = StringFormat("%-6s | %-7s | %-7s | %-7s | %-6s | %-6s | %-6s | %-7s", 
                        "Magic", "Realzd", "Float", "Equity", "DD%", "MaxDD%", "MaxAlw", "Status");
   DrawLabel("EDM_Label_Header", header, 20, y_base, 10, clrSilver);
   y_base += y_step;
   
   DrawLabel("EDM_Label_Sep", "-------------------------------------------------------------------------------", 20, y_base, 10, clrSilver);
   y_base += y_step;
   
   for(int i = 0; i < monitor_count; i++) {
      string max_allowed_str = monitors[i].GetMaxAllowedDrawdown() > 0 ? 
                               DoubleToString(monitors[i].GetMaxAllowedDrawdown(), 1) + "%" : "--";
      
      string status_str = monitors[i].IsEmergencyStopped() ? "STOPPED" : "ACTIVE";
      
      string line = StringFormat("%-6d | %-7.1f | %-7.1f | %-7.1f | %-6.1f%% | %-6.1f%% | %-6s | %-7s",
         monitors[i].GetMagic(),
         monitors[i].GetRealizedOutput(),
         monitors[i].GetFloating(),
         monitors[i].GetEquity(),
         monitors[i].GetDrawdownPercent(),
         monitors[i].GetMaxDrawdownPercent(),
         max_allowed_str,
         status_str
      );
      
      color row_color = monitors[i].GetRowColor();
      DrawLabel("EDM_Label_Row_"+IntegerToString(i), line, 20, y_base, 10, row_color);
      y_base += y_step;
   }
}
