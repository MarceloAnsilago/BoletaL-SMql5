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
#include <Trade\Trade.mqh>

#define BOL_PREFIX        "bol_"
#define DLG_NAME          BOL_PREFIX"dialog"

#define LB_COMPRA_NAME    BOL_PREFIX"lb_compra"
#define ED_COMPRA_NAME    BOL_PREFIX"ed_compra"

#define LB_VENDA_NAME     BOL_PREFIX"lb_venda"
#define ED_VENDA_NAME     BOL_PREFIX"ed_venda"

#define BTN_SEARCH_NAME   BOL_PREFIX"btn_search"
#define BTN_TRADE_NAME    BOL_PREFIX"btn_trade"
#define LB_STATUS_NAME    BOL_PREFIX"lb_status"

const long BOL_MAGIC = 987654321;

#include "bol_strat.mqh"

// globais
CAppDialog g_dialog;
CLabel     g_lbCompra;
CEdit      g_edCompra;
CLabel     g_lbVenda;
CEdit      g_edVenda;
CButton    g_btnSearch;
CButton    g_btnTrade;
CLabel     g_lbStatus;
bool       g_pair_open = false;
string     g_pair_base = "";
string     g_pair_over = "";

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
CLabel     g_lbPLVenda;
CLabel     g_lbPLCompra;
CLabel     g_lbPLTotal;

// trade
CTrade     g_trade;

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

// ajusta volume para min/max/step do simbolo
double NormalizeVolume(const double desired,const string symbol)
  {
   double v   = desired;
   double min = SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
   double max = SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
   double stp = SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);

   if(v < min) v = min;
   if(v > max) v = max;
   if(stp > 0)
      v = min + MathFloor((v - min) / stp) * stp;

   return v;
  }

bool HasPosition(const string symbol,const ENUM_POSITION_TYPE type,double &volume)
  {
   volume = 0.0;
   if(!PositionSelect(symbol))
      return(false);

   long magic = PositionGetInteger(POSITION_MAGIC);
   ENUM_POSITION_TYPE t = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   if(magic != BOL_MAGIC || t != type)
      return(false);

   volume = PositionGetDouble(POSITION_VOLUME);
   return(true);
  }

bool IsPairOpen(const string base_symbol,const string overlay_symbol)
  {
   double vb, vo;
   bool has_sell = HasPosition(base_symbol,POSITION_TYPE_SELL,vb);
   bool has_buy  = HasPosition(overlay_symbol,POSITION_TYPE_BUY,vo);
   return(has_sell && has_buy);
  }

void UpdateTradeUI(const string base_symbol,const string overlay_symbol)
  {
   double vol_sell=0, vol_buy=0;
   double pl_sell=0, pl_buy=0;
   double open_sell=0, open_buy=0;
   double now_sell=0, now_buy=0;
   bool has_sell=false, has_buy=false;

   if(PositionSelect(base_symbol) && PositionGetInteger(POSITION_MAGIC)==BOL_MAGIC)
     {
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
        {
         has_sell  = true;
         vol_sell  = PositionGetDouble(POSITION_VOLUME);
         pl_sell   = PositionGetDouble(POSITION_PROFIT);
         open_sell = PositionGetDouble(POSITION_PRICE_OPEN);
         now_sell  = SymbolInfoDouble(base_symbol,SYMBOL_BID);
        }
     }

   if(PositionSelect(overlay_symbol) && PositionGetInteger(POSITION_MAGIC)==BOL_MAGIC)
     {
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
        {
         has_buy  = true;
         vol_buy  = PositionGetDouble(POSITION_VOLUME);
         pl_buy   = PositionGetDouble(POSITION_PROFIT);
         open_buy = PositionGetDouble(POSITION_PRICE_OPEN);
         now_buy  = SymbolInfoDouble(overlay_symbol,SYMBOL_BID);
        }
     }

   g_pair_open = (has_sell && has_buy);
   g_btnTrade.Text(g_pair_open ? "Encerrar operacao" : "Iniciar operacao");

   if(has_sell)
      g_lbPLVenda.Text(StringFormat("P&L vendido: %.2f (vol: %.2f | %.2f -> %.2f)",pl_sell,vol_sell,open_sell,now_sell));
   else
      g_lbPLVenda.Text("P&L vendido: sem posicao.");

   if(has_buy)
      g_lbPLCompra.Text(StringFormat("P&L comprado: %.2f (vol: %.2f | %.2f -> %.2f)",pl_buy,vol_buy,open_buy,now_buy));
   else
      g_lbPLCompra.Text("P&L comprado: sem posicao.");

   g_lbPLTotal.Text(StringFormat("P&L total: %.2f",pl_sell+pl_buy));

   if(g_pair_open)
      g_lbStatus.Text("Operacao aberta: vende "+base_symbol+" / compra "+overlay_symbol);
   else
      g_lbStatus.Text("Nenhuma operacao aberta.");
  }

bool ClosePair(const string base_symbol,const string overlay_symbol)
  {
   bool ok = true;

   if(PositionSelect(base_symbol) && PositionGetInteger(POSITION_MAGIC)==BOL_MAGIC)
      ok = g_trade.PositionClose(base_symbol) && ok;

   if(PositionSelect(overlay_symbol) && PositionGetInteger(POSITION_MAGIC)==BOL_MAGIC)
      ok = g_trade.PositionClose(overlay_symbol) && ok;

   return ok;
  }

bool OpenPair(const string base_symbol,const string overlay_symbol,const double qty_base,const double qty_over)
  {
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
     {
      MessageBox("Negociacao automatica desabilitada.","bol",MB_ICONERROR);
      return(false);
     }

   if(!SymbolSelect(base_symbol,true) || !SymbolSelect(overlay_symbol,true))
     {
      MessageBox("Falha ao selecionar simbolos.","bol",MB_ICONERROR);
      return(false);
     }

   if(SymbolInfoInteger(base_symbol,SYMBOL_TRADE_MODE)==SYMBOL_TRADE_MODE_DISABLED ||
      SymbolInfoInteger(overlay_symbol,SYMBOL_TRADE_MODE)==SYMBOL_TRADE_MODE_DISABLED)
     {
      MessageBox("Um dos simbolos esta com trade desabilitado.","bol",MB_ICONERROR);
      return(false);
     }

   double vol_base = NormalizeVolume(qty_base,base_symbol);
   double vol_over = NormalizeVolume(qty_over,overlay_symbol);

   if(vol_base<=0 || vol_over<=0)
     {
      MessageBox("Volumes invalidos para abrir operacao.","bol",MB_ICONERROR);
      return(false);
     }

   if(PositionSelect(base_symbol) && PositionGetInteger(POSITION_MAGIC)!=BOL_MAGIC)
     {
      MessageBox("Ja existe posicao em "+base_symbol+" com outro magic.","bol",MB_ICONERROR);
      return(false);
     }

   if(PositionSelect(overlay_symbol) && PositionGetInteger(POSITION_MAGIC)!=BOL_MAGIC)
     {
      MessageBox("Ja existe posicao em "+overlay_symbol+" com outro magic.","bol",MB_ICONERROR);
      return(false);
     }

   g_trade.SetExpertMagicNumber(BOL_MAGIC);
   g_trade.SetTypeFillingBySymbol(base_symbol);
   g_trade.SetTypeFillingBySymbol(overlay_symbol);

   if(!g_trade.Sell(vol_base,base_symbol))
     {
      MessageBox("Falha ao vender "+base_symbol+" (retcode "+IntegerToString((int)g_trade.ResultRetcode())+").","bol",MB_ICONERROR);
      return(false);
     }

   if(!g_trade.Buy(vol_over,overlay_symbol))
     {
      MessageBox("Falha ao comprar "+overlay_symbol+" (retcode "+IntegerToString((int)g_trade.ResultRetcode())+").","bol",MB_ICONERROR);
      return(false);
     }

   return(true);
  }


// cria a interface gráfica
bool CreateInterface()
  {
   long chart_id = ChartID();

   if(!g_dialog.Create(chart_id, DLG_NAME, 0, 10, 10, 620, 520))
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

   g_trade.SetExpertMagicNumber(BOL_MAGIC);
   UpdateTradeUI(g_last_venda_text,g_last_compra_text);

   return INIT_SUCCEEDED;
  }
// OnDeinit
void OnDeinit(const int reason)
  {
   g_dialog.Destroy(reason);
  }

// OnTick
void OnTick()
  {
   if(g_pair_open)
     {
      string venda  = NormalizeSymbol(g_edVenda.Text());
      string compra = NormalizeSymbol(g_edCompra.Text());
      UpdateTradeUI(venda,compra);
     }
  }


// EVENTOS
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {
   g_dialog.ChartEvent(id, lparam, dparam, sparam);

   bool is_change_evt = false;

   // cobre formatos possiveis do SpinEdit (EventChartCustom)
   if(id == CHARTEVENT_CUSTOM + ON_CHANGE &&
      (lparam == g_edLoteVenda.Id() || lparam == g_edLoteCompra.Id() ||
       sparam == ED_LOTE_VENDA_NAME || sparam == ED_LOTE_COMPRA_NAME))
      is_change_evt = true;
   else if(id == CHARTEVENT_CUSTOM && lparam == ON_CHANGE &&
           (dparam == g_edLoteVenda.Id() || dparam == g_edLoteCompra.Id() ||
            sparam == ED_LOTE_VENDA_NAME || sparam == ED_LOTE_COMPRA_NAME))
      is_change_evt = true;
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

   // botao trade (iniciar/encerrar)
   if(id == CHARTEVENT_CUSTOM + ON_CLICK && lparam == g_btnTrade.Id())
     {
      string venda  = NormalizeSymbol(g_edVenda.Text());
      string compra = NormalizeSymbol(g_edCompra.Text());

      if(venda == "" || compra == "")
        {
         MessageBox("Preencha os dois ativos para operar.","bol",MB_ICONWARNING);
         return;
        }

      if(g_pair_open)
        {
         if(ClosePair(venda,compra))
            UpdateTradeUI(venda,compra);
         else
            MessageBox("Falha ao encerrar completamente a operacao.","bol",MB_ICONERROR);
        }
      else
        {
         double qty_base = (double)g_edLoteVenda.Value();
         double qty_over = (double)g_edLoteCompra.Value();

         if(OpenPair(venda,compra,qty_base,qty_over))
            UpdateTradeUI(venda,compra);
        }
      return;
     }

   // botao pesquisar
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

      UpdateTradeUI(venda,compra);
     }
  }










