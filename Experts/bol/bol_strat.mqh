//+------------------------------------------------------------------+
//| Helpers de estratificacao: criacao de UI e calculos de saldo     |
//+------------------------------------------------------------------+
#ifndef __BOL_STRAT_MQH__
#define __BOL_STRAT_MQH__

#include <Controls\Label.mqh>
#include <Controls\Edit.mqh>
#include <Controls\Button.mqh>
#include <Controls\SpinEdit.mqh>

// nomes dos controles extra
#define LB_LOTE_VENDA_NAME   BOL_PREFIX"lb_lote_venda"
#define ED_LOTE_VENDA_NAME   BOL_PREFIX"ed_lote_venda"
#define LB_LOTE_COMPRA_NAME  BOL_PREFIX"lb_lote_compra"
#define ED_LOTE_COMPRA_NAME  BOL_PREFIX"ed_lote_compra"

#define LB_VAL_VENDA_NAME    BOL_PREFIX"lb_val_venda"
#define LB_VAL_COMPRA_NAME   BOL_PREFIX"lb_val_compra"
#define LB_FORM_VENDA_NAME   BOL_PREFIX"lb_form_venda"
#define LB_FORM_COMPRA_NAME  BOL_PREFIX"lb_form_compra"

#define LB_SALDO_NAME        BOL_PREFIX"lb_saldo"
#define LB_SALDO_DET_NAME    BOL_PREFIX"lb_saldo_det"
#define LB_STATUS_NAME       BOL_PREFIX"lb_status"
#define BTN_TRADE_NAME       BOL_PREFIX"btn_trade"

// declaracoes dos controles (definidos no bol.mq5)
extern CLabel    g_lbLoteVenda;
extern CSpinEdit g_edLoteVenda;
extern CLabel    g_lbLoteCompra;
extern CSpinEdit g_edLoteCompra;

extern CLabel  g_lbValVenda;
extern CLabel  g_lbValCompra;
extern CLabel  g_lbFormVenda;
extern CLabel  g_lbFormCompra;
extern CLabel  g_lbSaldo;
extern CLabel  g_lbSaldoDet;
extern CLabel  g_lbStatus;
extern CButton g_btnTrade;

extern bool    g_recalc_in_progress;
extern int     g_suppress_change_events;

// passo base
const int STRAT_STEP = 100;

// cria os controles de estratificacao
bool Strat_CreateUI(const long chart_id,CAppDialog &dlg)
  {
   // linha de lotes
   if(!g_lbLoteVenda.Create(chart_id,LB_LOTE_VENDA_NAME,0,20,145,150,165))
      return(false);
   g_lbLoteVenda.Text("Qtd vendida:");
   if(!dlg.Add(g_lbLoteVenda))
      return(false);

   if(!g_edLoteVenda.Create(chart_id,ED_LOTE_VENDA_NAME,0,20,165,100,195))
      return(false);
   g_edLoteVenda.Step(STRAT_STEP);
   g_edLoteVenda.MinValue(STRAT_STEP);
   g_edLoteVenda.MaxValue(10000000);
   g_edLoteVenda.Value(STRAT_STEP);
   if(!dlg.Add(g_edLoteVenda))
      return(false);

   if(!g_lbLoteCompra.Create(chart_id,LB_LOTE_COMPRA_NAME,0,220,145,360,165))
      return(false);
   g_lbLoteCompra.Text("Qtd comprada:");
   if(!dlg.Add(g_lbLoteCompra))
      return(false);

   if(!g_edLoteCompra.Create(chart_id,ED_LOTE_COMPRA_NAME,0,220,165,300,195))
      return(false);
   g_edLoteCompra.Step(STRAT_STEP);
   g_edLoteCompra.MinValue(STRAT_STEP);
   g_edLoteCompra.MaxValue(10000000);
   g_edLoteCompra.Value(STRAT_STEP);
   if(!dlg.Add(g_edLoteCompra))
      return(false);

   // valores e formulas
   if(!g_lbValVenda.Create(chart_id,LB_VAL_VENDA_NAME,0,20,200,200,220))
      return(false);
   g_lbValVenda.Text("Preco/Total vend:");
   if(!dlg.Add(g_lbValVenda))
      return(false);

   if(!g_lbValCompra.Create(chart_id,LB_VAL_COMPRA_NAME,0,210,200,430,220))
      return(false);
   g_lbValCompra.Text("Preco/Total comp:");
   if(!dlg.Add(g_lbValCompra))
      return(false);

   if(!g_lbFormVenda.Create(chart_id,LB_FORM_VENDA_NAME,0,20,225,200,245))
      return(false);
   g_lbFormVenda.Text("");
   if(!dlg.Add(g_lbFormVenda))
      return(false);

   if(!g_lbFormCompra.Create(chart_id,LB_FORM_COMPRA_NAME,0,210,225,430,245))
      return(false);
   g_lbFormCompra.Text("");
   if(!dlg.Add(g_lbFormCompra))
      return(false);

   // saldo
   if(!g_lbSaldo.Create(chart_id,LB_SALDO_NAME,0,20,255,430,275))
      return(false);
   g_lbSaldo.Text("");
   if(!dlg.Add(g_lbSaldo))
      return(false);

   if(!g_lbSaldoDet.Create(chart_id,LB_SALDO_DET_NAME,0,20,280,430,300))
      return(false);
   g_lbSaldoDet.Text("");
   if(!dlg.Add(g_lbSaldoDet))
      return(false);

   // status operacao
   if(!g_lbStatus.Create(chart_id,LB_STATUS_NAME,0,20,310,430,330))
      return(false);
   g_lbStatus.Text("Nenhuma operacao aberta.");
   if(!dlg.Add(g_lbStatus))
      return(false);

   // botao trade (iniciar/encerrar)
   if(!g_btnTrade.Create(chart_id,BTN_TRADE_NAME,0,20,340,220,370))
      return(false);
   g_btnTrade.Text("Iniciar operacao");
   if(!dlg.Add(g_btnTrade))
      return(false);

   return(true);
  }

// recalcula totais, formulas e saldo
void Strat_UpdateTotals(const long chart_id,const string base_symbol,const string overlay_symbol)
  {
   string base = base_symbol;
   string over = overlay_symbol;

   if(base == "") base = Symbol();
   if(over == "") over = Symbol();

   g_lbLoteVenda.Text("Qtd vendida ("+base+"):"); 
   g_lbLoteCompra.Text("Qtd comprada ("+over+"):");

   SymbolSelect(base,true);
   SymbolSelect(over,true);

   ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)Period();

   double base_price = SymbolInfoDouble(base,SYMBOL_BID);
   if(base_price<=0) base_price = iClose(base,tf,0);

   double over_price = SymbolInfoDouble(over,SYMBOL_BID);
   if(over_price<=0) over_price = iClose(over,tf,0);

   if(base_price<=0 || over_price<=0)
      return;

   double qty_base = (double)g_edLoteVenda.Value();
   double qty_over = (double)g_edLoteCompra.Value();

   double value_base = base_price * qty_base;
   double value_over = over_price * qty_over;

   g_lbValVenda.Text(StringFormat("Preco: %.2f  Total: %.2f",base_price,value_base));
   g_lbValCompra.Text(StringFormat("Preco: %.2f  Total: %.2f",over_price,value_over));

   g_lbFormVenda.Text(StringFormat("%.0f x %.2f = %.2f",qty_base,base_price,value_base));
   g_lbFormCompra.Text(StringFormat("%.0f x %.2f = %.2f",qty_over,over_price,value_over));

   double saldo = value_base - value_over;

   string situacao;
   if(saldo > 0.01)      situacao = "Recebe na montagem (vendido > comprado)";
   else if(saldo < -0.01) situacao = "Paga na montagem (comprado > vendido)";
   else                   situacao = "Montagem neutra (equilibrado)";

   g_lbSaldo.Text(StringFormat("Saldo (vend - comp): %.2f",saldo));
   g_lbSaldoDet.Text(StringFormat("%s | Vend: %.0fa  Comp: %.0fa", situacao, qty_base, qty_over));

   ChartRedraw(chart_id);
  }

#endif // __BOL_STRAT_MQH__
