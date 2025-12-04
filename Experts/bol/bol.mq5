//+------------------------------------------------------------------+
//|                                                          bol.mq5 |
//+------------------------------------------------------------------+
#property strict
#property copyright "2025"
#property version   "1.10"

#include <Controls\Dialog.mqh>
#include <Controls\Label.mqh>
#include <Controls\Edit.mqh>
#include <Controls\Button.mqh>
#include <Controls\SpinEdit.mqh>

#define BOL_PREFIX        "bol_"
#define DLG_NAME          BOL_PREFIX"dialog"

#define LB_COMPRA_NAME    BOL_PREFIX"lb_compra"
#define ED_COMPRA_NAME    BOL_PREFIX"ed_compra"

#define LB_VENDA_NAME     BOL_PREFIX"lb_venda"
#define ED_VENDA_NAME     BOL_PREFIX"ed_venda"

#define BTN_SEARCH_NAME   BOL_PREFIX"btn_search"

#include "bol_strat.mqh"

// globais
CAppDialog g_dialog;
CLabel     g_lbCompra;
CEdit      g_edCompra;
CLabel     g_lbVenda;
CEdit      g_edVenda;
CButton    g_btnSearch;

CLabel     g_lbLoteVenda;
CSpinEdit  g_edLoteVenda;
CLabel     g_lbLoteCompra;
CSpinEdit  g_edLoteCompra;
CLabel     g_lbValVenda;
CLabel     g_lbValCompra;
CLabel     g_lbFormVenda;
CLabel     g_lbFormCompra;
CLabel     g_lbSaldo;
CLabel     g_lbSaldoDet;

string     g_last_overlay_name = "";
string     g_last_compra_text  = "";
string     g_last_venda_text   = "";

bool       g_recalc_in_progress = false;
int        g_suppress_change_events = 0;

// normaliza símbolo
string NormalizeSymbol(string s)
  {
   StringTrimLeft(s);
   StringTrimRight(s);
   StringToUpper(s);
   return s;
  }

// cria a interface gráfica
bool CreateInterface()
  {
   long chart_id = ChartID();

   if(!g_dialog.Create(chart_id, DLG_NAME, 0, 10, 10, 540, 360))
      return false;

   if(!g_lbVenda.Create(chart_id, LB_VENDA_NAME, 0, 20, 30, 160, 50))
      return false;
   g_lbVenda.Text("Ativo vendido:");
   g_dialog.Add(g_lbVenda);

   if(!g_edVenda.Create(chart_id, ED_VENDA_NAME, 0, 170, 30, 360, 50))
      return false;
   g_edVenda.Text(g_last_venda_text);
   g_dialog.Add(g_edVenda);

   if(!g_lbCompra.Create(chart_id, LB_COMPRA_NAME, 0, 20, 80, 160, 100))
      return false;
   g_lbCompra.Text("Ativo comprado:");
   g_dialog.Add(g_lbCompra);

   if(!g_edCompra.Create(chart_id, ED_COMPRA_NAME, 0, 170, 80, 360, 100))
      return false;
   g_edCompra.Text(g_last_compra_text);
   g_dialog.Add(g_edCompra);

   if(!g_btnSearch.Create(chart_id, BTN_SEARCH_NAME, 0, 130, 110, 260, 140))
      return false;
   g_btnSearch.Text("Pesquisar");
   g_dialog.Add(g_btnSearch);

   if(!Strat_CreateUI(chart_id, g_dialog))
      return false;

   g_dialog.Run();
   return true;
  }

// OnInit
int OnInit()
  {
   g_last_venda_text = NormalizeSymbol(Symbol());

   if(!CreateInterface())
      return INIT_FAILED;

   g_recalc_in_progress = true;
   Strat_UpdateTotals(ChartID(), g_last_venda_text, g_last_compra_text);
   g_recalc_in_progress = false;

   return INIT_SUCCEEDED;
  }

// OnDeinit
void OnDeinit(const int reason)
  {
   g_dialog.Destroy(reason);
  }

// OnTick
void OnTick() {}


// EVENTOS
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {
   g_dialog.ChartEvent(id, lparam, dparam, sparam);

   bool is_change_evt = false;

   if(id == CHARTEVENT_CUSTOM + ON_CHANGE)
     is_change_evt = (lparam == g_edLoteVenda.Id() ||
                      lparam == g_edLoteCompra.Id());

   if(id == CHARTEVENT_CUSTOM && lparam == ON_CHANGE)
     {
      long cid = (long)dparam;
      is_change_evt = (cid == g_edLoteVenda.Id() ||
                       cid == g_edLoteCompra.Id());
     }

   // ← ← ← **PARTE CRUCIAL** → → →
   if(is_change_evt)
     {
      if(g_suppress_change_events > 0)
        {
         g_suppress_change_events--;
         return;
        }

      if(g_recalc_in_progress)
         return;

      g_recalc_in_progress = true;

      string b = NormalizeSymbol(g_edVenda.Text());
      string o = NormalizeSymbol(g_edCompra.Text());

      Strat_UpdateTotals(ChartID(), b, o);

      g_recalc_in_progress = false;
      return;
     }

   // botão pesquisar
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == BTN_SEARCH_NAME)
     {
      string venda  = NormalizeSymbol(g_edVenda.Text());
      string compra = NormalizeSymbol(g_edCompra.Text());

      g_last_venda_text = venda;
      g_last_compra_text = compra;

      ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)Period();
      SymbolSelect(venda,true);
      ChartSetSymbolPeriod(ChartID(), venda, tf);

      if(g_last_overlay_name != "")
        ChartIndicatorDelete(ChartID(), 1, g_last_overlay_name);

      if(compra != "")
        {
         int h = iCustom(venda,tf,"SimpleOverlay",compra);
         if(h != INVALID_HANDLE)
           {
            ChartIndicatorAdd(ChartID(),1,h);
            g_last_overlay_name = "Overlay: "+compra;
           }
        }

      g_recalc_in_progress = true;
      Strat_UpdateTotals(ChartID(), venda, compra);
      g_recalc_in_progress = false;
     }
  }
