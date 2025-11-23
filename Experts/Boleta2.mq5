//+------------------------------------------------------------------+
//|                                                      Boleta2.mq5 |
//|             Boleta L&S usando CAppDialog e biblioteca Controls   |
//+------------------------------------------------------------------+
#property strict
#property copyright "Copyright 2025"
#property version   "1.45"

//--- includes da biblioteca GUI
#include <Controls\Dialog.mqh>
#include <Controls\Label.mqh>
#include <Controls\Edit.mqh>
#include <Controls\Button.mqh>
#include <Controls\SpinEdit.mqh>

// nomes / prefixos
#define BOLETA_PREFIX          "boleta_"
#define DIALOG_NAME            "boleta_dialog"

#define OBJ_ATIVO_LABEL        BOLETA_PREFIX"ativo_label"

#define OBJ_LB_COMPRA          BOLETA_PREFIX"lb_compra"
#define OBJ_ED_COMPRA          BOLETA_PREFIX"ed_compra"

#define OBJ_LB_VENDA           BOLETA_PREFIX"lb_venda"
#define OBJ_ED_VENDA           BOLETA_PREFIX"ed_venda"

#define OBJ_BTN_SEARCH         BOLETA_PREFIX"btn_search"
#define OBJ_SEPARATOR          BOLETA_PREFIX"separator"
#define OBJ_COL_DIVIDER        BOLETA_PREFIX"col_divider"

#define OBJ_LB_LOTE_BASE       BOLETA_PREFIX"lb_lote_base"
#define OBJ_ED_LOTE_BASE       BOLETA_PREFIX"ed_lote_base"
#define OBJ_LB_VAL_BASE        BOLETA_PREFIX"lb_val_base"

#define OBJ_LB_LOTE_OVER       BOLETA_PREFIX"lb_lote_over"
#define OBJ_ED_LOTE_OVER       BOLETA_PREFIX"ed_lote_over"
#define OBJ_LB_VAL_OVER        BOLETA_PREFIX"lb_val_over"

#define OBJ_LB_MULT_BASE       BOLETA_PREFIX"lb_mult_base"
#define OBJ_LB_MULT_OVER       BOLETA_PREFIX"lb_mult_over"
#define OBJ_LB_FORM_BASE       BOLETA_PREFIX"lb_form_base"
#define OBJ_LB_FORM_OVER       BOLETA_PREFIX"lb_form_over"

#define OBJ_LB_SALDO           BOLETA_PREFIX"lb_saldo"
#define OBJ_LB_SALDO_DET       BOLETA_PREFIX"lb_saldo_det"

// Cores do gráfico
color BULL_COLOR = clrDeepSkyBlue;
color BEAR_COLOR = clrOrangeRed;

// Paleta da boleta (estilo janela padrão MT5)
color COL_PANEL        = C'238,241,245';   // fundo do diálogo (cinza claro)
color COL_TEXT_MAIN    = C'30,30,30';      // texto principal
color COL_TEXT_SECOND  = C'80,80,80';      // texto secundário

color COL_EDIT_BG      = C'255,255,255';   // fundo das textbox
color COL_EDIT_BORDER  = C'150,150,160';

color COL_BTN_BG       = C'206,212,221';   // botão normal (cinza)
color COL_BTN_BG_DOWN  = C'150,180,220';   // botão pressionado (azul claro)
color COL_BTN_BORDER   = C'120,130,150';
color COL_BTN_TEXT     = C'20,20,20';

// último overlay
string g_last_overlay_name = "";

// chart id “oficial” do EA (para Destroy, etc.)
long g_chart_id = 0;

//+------------------------------------------------------------------+
//| Auxiliares                                                       |
//+------------------------------------------------------------------+
string Boleta_MakeGVName(const long chart_id,const string base,const string overlay)
  {
   return("boleta_"+IntegerToString((long)chart_id)+"_"+base+"_"+overlay);
  }

//--- remove todos os objetos da boleta (prefixo)
void Boleta_ClearObjects(const long chart_id)
  {
   int total = ObjectsTotal(chart_id,0,-1);
   for(int i = total-1; i >= 0; i--)
     {
      string name = ObjectName(chart_id,i);
      if(StringFind(name,BOLETA_PREFIX) == 0 || name == DIALOG_NAME)
         ObjectDelete(chart_id,name);
     }
  }

//--- adiciona overlay
bool Boleta_AddOverlay(const long chart_id,const string base_symbol,const string overlay_symbol,const ENUM_TIMEFRAMES tf)
  {
   if(g_last_overlay_name != "")
      ChartIndicatorDelete(chart_id,1,g_last_overlay_name);

   ChartIndicatorDelete(chart_id,1,"SimpleOverlay");

   string overlay_short = "Overlay: " + overlay_symbol;
   ResetLastError();
   int handle = iCustom(base_symbol,tf,"SimpleOverlay",overlay_symbol);
   if(handle == INVALID_HANDLE)
     {
      int err = GetLastError();
      MessageBox("Erro ao criar handle de SimpleOverlay. Codigo: "+IntegerToString(err),"Boleta L&S",MB_ICONERROR);
      return(false);
     }

   if(!ChartIndicatorAdd(chart_id,1,handle))
     {
      int err = GetLastError();
      MessageBox("Falha ao adicionar SimpleOverlay. Codigo: "+IntegerToString(err),"Boleta L&S",MB_ICONERROR);
      return(false);
     }

   g_last_overlay_name = overlay_short;
   return(true);
  }

// aplica estilo de botão (normal ou pressionado)
void Boleta_StyleButton(const long chart_id,const string name,bool pressed=false)
  {
   ObjectSetInteger(chart_id,name,OBJPROP_BGCOLOR, pressed ? COL_BTN_BG_DOWN : COL_BTN_BG);
   ObjectSetInteger(chart_id,name,OBJPROP_COLOR,   COL_BTN_TEXT);
   ObjectSetInteger(chart_id,name,OBJPROP_BORDER_COLOR,COL_BTN_BORDER);
   ObjectSetInteger(chart_id,name,OBJPROP_FONTSIZE,9);
  }

//+------------------------------------------------------------------+
//| Classe da Boleta (Dialog)                                        |
//+------------------------------------------------------------------+
class CBoletaDialog : public CAppDialog
  {
public:
   // Controles
   CLabel    m_lbAtivo;
   CLabel    m_lbVenda;
   CLabel    m_lbCompra;
   CEdit     m_edVenda;
   CEdit     m_edCompra;

   CLabel    m_lbLoteBase;
   CSpinEdit m_edLoteBase;
   CLabel    m_lbMultBase;
   CLabel    m_lbValBase;
   CLabel    m_lbFormBase;

   CLabel    m_lbLoteOver;
   CSpinEdit m_edLoteOver;
   CLabel    m_lbMultOver;
   CLabel    m_lbValOver;
   CLabel    m_lbFormOver;

   CLabel    m_lbSaldo;
   CLabel    m_lbSaldoDet;

   CButton   m_btnSearch;

   CLabel    m_lbSeparator;   // separador dentro do diálogo
   CLabel    m_lbColDivider;  // divisão vertical (colunas)

   bool      m_isUpdating;

   // criação do diálogo
   bool CreateBoleta(const long chart_id)
     {
      int subwin=0;
      const int dlg_x      = 10;
      const int dlg_y      = 30;
      const int dlg_width  = 620;  // mant?m largura original
      const int dlg_height = 395;

      const int col1_x     = 20;   // margem esquerda da coluna 1
      const int col_width  = 300;  // componentes compactados na metade esquerda
      const int col_gap    = 20;   // espa?o vazio entre colunas
      const int divider_x  = col1_x + col_width + (col_gap/2); // divisor central

      const int field_x    = col1_x + 120; // x dos edits de texto
      const int field_w    = 120;          // largura dos edits de texto

      Boleta_ClearObjects(chart_id);
      m_isUpdating = false;

      // cria o diálogo principal
      ResetLastError();
      if(!Create(chart_id,DIALOG_NAME,subwin,
                 dlg_x,dlg_y,
                 dlg_x + dlg_width,
                 dlg_y + dlg_height))
        {
         Print("CreateBoleta: falha ao criar dialog, err=",GetLastError());
         return(false);
        }

      ObjectSetInteger(chart_id,Name(),OBJPROP_BGCOLOR, COL_PANEL);
      ObjectSetInteger(chart_id,Name(),OBJPROP_COLOR,   COL_BTN_BORDER);
      ObjectSetInteger(chart_id,Name(),OBJPROP_WIDTH,   1);
      ObjectSetInteger(chart_id,Name(),OBJPROP_STYLE,   STYLE_SOLID);
      ObjectSetInteger(chart_id,Name(),OBJPROP_BACK,    true);

      // --- Ativo do grafico (mais acima)
      const int y_ativo     = 15;
      const int y_venda     = 40;
      const int y_compra    = 70;
      const int y_btn       = 100;
      const int y_sep       = 130;
      const int y_lote_base = 145;
      const int y_lote_over = 175;
      const int y_calc_start= y_lote_over + 60; // início da área de cálculos abaixo dos spinners

      m_lbAtivo.Create(chart_id,OBJ_ATIVO_LABEL,subwin,col1_x,y_ativo,col1_x+col_width-20,y_ativo+16);
      m_lbAtivo.Text("Ativo do grafico: "+_Symbol);
      Add(m_lbAtivo);
      ObjectSetInteger(chart_id,OBJ_ATIVO_LABEL,OBJPROP_COLOR, COL_TEXT_SECOND);

      // --- VENDA (base)
      m_lbVenda.Create(chart_id,OBJ_LB_VENDA,subwin,col1_x,y_venda,col1_x+col_width-80,y_venda+16);
      m_lbVenda.Text("Ativo vendido:");
      Add(m_lbVenda);
      ObjectSetInteger(chart_id,OBJ_LB_VENDA,OBJPROP_COLOR, COL_TEXT_MAIN);

      m_edVenda.Create(chart_id,OBJ_ED_VENDA,subwin,field_x,y_venda,field_x+field_w,y_venda+22);
      m_edVenda.Text(_Symbol);
      Add(m_edVenda);
      ObjectSetInteger(chart_id,OBJ_ED_VENDA,OBJPROP_COLOR,       COL_TEXT_MAIN);
      ObjectSetInteger(chart_id,OBJ_ED_VENDA,OBJPROP_BGCOLOR,     COL_EDIT_BG);
      ObjectSetInteger(chart_id,OBJ_ED_VENDA,OBJPROP_BORDER_COLOR,COL_EDIT_BORDER);

      // --- COMPRA (overlay)
      m_lbCompra.Create(chart_id,OBJ_LB_COMPRA,subwin,col1_x,y_compra,col1_x+col_width-60,y_compra+16);
      m_lbCompra.Text("Ativo comprado:");
      Add(m_lbCompra);
      ObjectSetInteger(chart_id,OBJ_LB_COMPRA,OBJPROP_COLOR, COL_TEXT_MAIN);

      m_edCompra.Create(chart_id,OBJ_ED_COMPRA,subwin,field_x,y_compra,field_x+field_w,y_compra+22);
      m_edCompra.Text("");
      Add(m_edCompra);
      ObjectSetInteger(chart_id,OBJ_ED_COMPRA,OBJPROP_COLOR,       COL_TEXT_MAIN);
      ObjectSetInteger(chart_id,OBJ_ED_COMPRA,OBJPROP_BGCOLOR,     COL_EDIT_BG);
      ObjectSetInteger(chart_id,OBJ_ED_COMPRA,OBJPROP_BORDER_COLOR,COL_EDIT_BORDER);

      // --- Botao PESQUISAR (mais à esquerda)
      int bx = col1_x + 10;
      m_btnSearch.Create(chart_id,OBJ_BTN_SEARCH,subwin,bx,y_btn,bx+220,y_btn+28);
      m_btnSearch.Text("[>] PESQUISAR ATIVOS");
      Add(m_btnSearch);
      Boleta_StyleButton(chart_id,OBJ_BTN_SEARCH,false);
      ObjectSetString(chart_id,OBJ_BTN_SEARCH,OBJPROP_TOOLTIP,
                      "Clique para carregar o ativo vendido e o overlay em D1");

      // --- Separador como CLabel (anda junto com o dialogo)
      m_lbSeparator.Create(chart_id,OBJ_SEPARATOR,subwin,col1_x,y_sep,col1_x+col_width,y_sep+1);
      m_lbSeparator.Text("");
      Add(m_lbSeparator);
      ObjectSetInteger(chart_id,OBJ_SEPARATOR,OBJPROP_BGCOLOR, COL_BTN_BORDER);
      ObjectSetInteger(chart_id,OBJ_SEPARATOR,OBJPROP_COLOR,   COL_BTN_BORDER);
      ObjectSetInteger(chart_id,OBJ_SEPARATOR,OBJPROP_BACK,true);

      // --- Divisor vertical para separar as duas colunas
      m_lbColDivider.Create(chart_id,OBJ_COL_DIVIDER,subwin,divider_x,15,divider_x+1,dlg_height-20);
      m_lbColDivider.Text("");
      Add(m_lbColDivider);
      ObjectSetInteger(chart_id,OBJ_COL_DIVIDER,OBJPROP_BGCOLOR, COL_BTN_BORDER);
      ObjectSetInteger(chart_id,OBJ_COL_DIVIDER,OBJPROP_COLOR,   COL_BTN_BORDER);
      ObjectSetInteger(chart_id,OBJ_COL_DIVIDER,OBJPROP_BACK,true);

      // layout interno para quantidades
      const int colA_x   = col1_x;
      const int colB_x   = col1_x; // compra fica abaixo da venda
      const int spin_w   = 60;
      const int spin_h   = 22;
      const int mult_w   = 20;
      const int fieldA_x = colA_x + 120;
      const int fieldB_x = colB_x + 120;
      const int multA_x  = fieldA_x + spin_w + 6;
      const int multB_x  = fieldB_x + spin_w + 6;

      // --- Coluna esquerda (vendido)
      m_lbLoteBase.Create(chart_id,OBJ_LB_LOTE_BASE,subwin,colA_x,y_lote_base,colA_x+140,y_lote_base+16);
      m_lbLoteBase.Text("Qtd vendida (acoes):");
      Add(m_lbLoteBase);
      ObjectSetInteger(chart_id,OBJ_LB_LOTE_BASE,OBJPROP_COLOR, COL_TEXT_MAIN);

      m_edLoteBase.Create(chart_id,OBJ_ED_LOTE_BASE,subwin,fieldA_x,y_lote_base,fieldA_x+spin_w,y_lote_base+spin_h);
      Add(m_edLoteBase);
      ObjectSetInteger(chart_id,OBJ_ED_LOTE_BASE,OBJPROP_COLOR,       COL_TEXT_MAIN);
      ObjectSetInteger(chart_id,OBJ_ED_LOTE_BASE,OBJPROP_BGCOLOR,     COL_EDIT_BG);
      ObjectSetInteger(chart_id,OBJ_ED_LOTE_BASE,OBJPROP_BORDER_COLOR,COL_EDIT_BORDER);

      m_edLoteBase.MinValue(100);
      m_edLoteBase.MaxValue(1000000);
      m_edLoteBase.Step(100);
      m_edLoteBase.Value(100);
      ObjectSetString(chart_id,OBJ_ED_LOTE_BASE,OBJPROP_TEXT,"100");

      m_lbMultBase.Create(chart_id,OBJ_LB_MULT_BASE,subwin,multA_x,y_lote_base,multA_x+mult_w,y_lote_base+16);
      m_lbMultBase.Text("unid.");
      Add(m_lbMultBase);
      ObjectSetInteger(chart_id,OBJ_LB_MULT_BASE,OBJPROP_COLOR, COL_TEXT_SECOND);

      m_lbValBase.Create(chart_id,OBJ_LB_VAL_BASE,subwin,colA_x,y_calc_start,col1_x+col_width,y_calc_start+16);
      m_lbValBase.Text("");
      Add(m_lbValBase);
      ObjectSetInteger(chart_id,OBJ_LB_VAL_BASE,OBJPROP_COLOR, COL_TEXT_SECOND);

      m_lbFormBase.Create(chart_id,OBJ_LB_FORM_BASE,subwin,colA_x,y_calc_start+20,col1_x+col_width,y_calc_start+20+16);
      m_lbFormBase.Text("");
      Add(m_lbFormBase);
      ObjectSetInteger(chart_id,OBJ_LB_FORM_BASE,OBJPROP_COLOR, COL_TEXT_SECOND);

      // --- Coluna direita (comprado) agora abaixo
      m_lbLoteOver.Create(chart_id,OBJ_LB_LOTE_OVER,subwin,colB_x,y_lote_over,colB_x+140,y_lote_over+16);
      m_lbLoteOver.Text("Qtd comprada (acoes):");
      Add(m_lbLoteOver);
      ObjectSetInteger(chart_id,OBJ_LB_LOTE_OVER,OBJPROP_COLOR, COL_TEXT_MAIN);

      m_edLoteOver.Create(chart_id,OBJ_ED_LOTE_OVER,subwin,fieldB_x,y_lote_over,fieldB_x+spin_w,y_lote_over+spin_h);
      Add(m_edLoteOver);
      ObjectSetInteger(chart_id,OBJ_ED_LOTE_OVER,OBJPROP_COLOR,       COL_TEXT_MAIN);
      ObjectSetInteger(chart_id,OBJ_ED_LOTE_OVER,OBJPROP_BGCOLOR,     COL_EDIT_BG);
      ObjectSetInteger(chart_id,OBJ_ED_LOTE_OVER,OBJPROP_BORDER_COLOR,COL_EDIT_BORDER);

      m_edLoteOver.MinValue(100);
      m_edLoteOver.MaxValue(1000000);
      m_edLoteOver.Step(100);
      m_edLoteOver.Value(100);
      ObjectSetString(chart_id,OBJ_ED_LOTE_OVER,OBJPROP_TEXT,"100");

      m_lbMultOver.Create(chart_id,OBJ_LB_MULT_OVER,subwin,multB_x,y_lote_over,multB_x+mult_w,y_lote_over+16);
      m_lbMultOver.Text("unid.");
      Add(m_lbMultOver);
      ObjectSetInteger(chart_id,OBJ_LB_MULT_OVER,OBJPROP_COLOR, COL_TEXT_SECOND);

      m_lbValOver.Create(chart_id,OBJ_LB_VAL_OVER,subwin,colB_x,y_calc_start+40,colB_x+col_width-180,y_calc_start+40+16);
      m_lbValOver.Text("");
      Add(m_lbValOver);
      ObjectSetInteger(chart_id,OBJ_LB_VAL_OVER,OBJPROP_COLOR, COL_TEXT_SECOND);

      m_lbFormOver.Create(chart_id,OBJ_LB_FORM_OVER,subwin,colB_x,y_calc_start+60,colB_x+col_width-180,y_calc_start+60+16);
      m_lbFormOver.Text("");
      Add(m_lbFormOver);
      ObjectSetInteger(chart_id,OBJ_LB_FORM_OVER,OBJPROP_COLOR, COL_TEXT_SECOND);

      // --- Saldo
      m_lbSaldo.Create(chart_id,OBJ_LB_SALDO,subwin,col1_x,y_calc_start+90,col1_x+col_width,y_calc_start+90+16);
      m_lbSaldo.Text("");
      Add(m_lbSaldo);
      ObjectSetInteger(chart_id,OBJ_LB_SALDO,OBJPROP_COLOR, COL_TEXT_MAIN);

      m_lbSaldoDet.Create(chart_id,OBJ_LB_SALDO_DET,subwin,col1_x,y_calc_start+110,col1_x+col_width,y_calc_start+110+16);
      m_lbSaldoDet.Text("");
      Add(m_lbSaldoDet);
      ObjectSetInteger(chart_id,OBJ_LB_SALDO_DET,OBJPROP_COLOR, COL_TEXT_SECOND);

      return(Run());
     }

   // --- atualiza totais (agora spinners já estão em ações)
   void UpdateTotals(const string base_symbol,const string overlay_symbol)
     {
      long chart_id = ChartID();
      m_isUpdating = true;

      double base_price = SymbolInfoDouble(base_symbol,SYMBOL_BID);
      if(base_price<=0) base_price = iClose(base_symbol,Period(),0);
      double over_price = SymbolInfoDouble(overlay_symbol,SYMBOL_BID);
      if(over_price<=0) over_price = iClose(overlay_symbol,Period(),0);

      if(base_price<=0 || over_price<=0)
        {
         m_isUpdating = false;
         return;
        }

      // agora o valor do spin já é quantidade de ações
      double qty_base = (double)m_edLoteBase.Value();
      double qty_over = (double)m_edLoteOver.Value();
      if(qty_base<100) qty_base = 100;
      if(qty_over<100) qty_over = 100;

      double value_base = base_price * qty_base;
      double value_over = over_price * qty_over;

      string base_info = StringFormat("Preco: R$ %.2f  Total: R$ %.2f",base_price,value_base);
      string over_info = StringFormat("Preco: R$ %.2f  Total: R$ %.2f",over_price,value_over);

      ObjectSetString(chart_id,OBJ_LB_VAL_BASE,OBJPROP_TEXT,base_info);
      ObjectSetString(chart_id,OBJ_LB_VAL_OVER,OBJPROP_TEXT,over_info);

      string base_formula = StringFormat("%.0f x R$ %.2f = R$ %.2f",qty_base,base_price,value_base);
      string over_formula = StringFormat("%.0f x R$ %.2f = R$ %.2f",qty_over,over_price,value_over);
      ObjectSetString(chart_id,OBJ_LB_FORM_BASE,OBJPROP_TEXT,base_formula);
      ObjectSetString(chart_id,OBJ_LB_FORM_OVER,OBJPROP_TEXT,over_formula);

      double saldo = value_base - value_over;

      string saldo_txt = StringFormat("Saldo (vendido - comprado): R$ %.2f",saldo);
      string situacao;

      if(saldo > 0.01)
         situacao = "Recebe na montagem (vendido > comprado)";
      else if(saldo < -0.01)
         situacao = "Paga na montagem (comprado > vendido)";
      else
         situacao = "Montagem neutra (valores equilibrados)";

      string detalhe = StringFormat("%s | Vend: %.0f  Comp: %.0f",
                                    situacao,
                                    qty_base,
                                    qty_over);

      ObjectSetString(chart_id,OBJ_LB_SALDO,OBJPROP_TEXT,saldo_txt);
      ObjectSetString(chart_id,OBJ_LB_SALDO_DET,OBJPROP_TEXT,detalhe);

      m_isUpdating = false;
     }

   // tratamento de eventos (botão PESQUISAR + ON_CHANGE dos spins)
   virtual bool OnEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
     {
      long chart_id = ChartID();

      if(m_isUpdating)
         return(CAppDialog::OnEvent(id,lparam,dparam,sparam));

      // símbolos atuais
      string txtCompra = ObjectGetString(chart_id,OBJ_ED_COMPRA,OBJPROP_TEXT);
      string txtVenda  = ObjectGetString(chart_id,OBJ_ED_VENDA, OBJPROP_TEXT);

      StringTrimLeft(txtCompra);
      StringTrimRight(txtCompra);
      StringTrimLeft(txtVenda);
      StringTrimRight(txtVenda);

      StringToUpper(txtCompra);
      StringToUpper(txtVenda);

      string base_symbol    = (txtVenda == "" ? _Symbol : txtVenda);
      string overlay_symbol = (txtCompra == "" ? _Symbol : txtCompra);
      ENUM_TIMEFRAMES tf    = PERIOD_D1;

      // clique em controles
      if(id == CHARTEVENT_CUSTOM + ON_CLICK)
        {
         // Botão PESQUISAR
         if(lparam == m_btnSearch.Id())
           {
            Boleta_StyleButton(chart_id,OBJ_BTN_SEARCH,true);
            ChartRedraw();

            if(!SymbolSelect(base_symbol,true))
              {
               Boleta_StyleButton(chart_id,OBJ_BTN_SEARCH,false);
               ChartRedraw();
               MessageBox("Simbolo '" + base_symbol + "' nao encontrado.","Boleta L&S",MB_ICONERROR);
               return(true);
              }

            if(!SymbolSelect(overlay_symbol,true))
              {
               Boleta_StyleButton(chart_id,OBJ_BTN_SEARCH,false);
               ChartRedraw();
               MessageBox("Simbolo '" + overlay_symbol + "' nao encontrado.","Boleta L&S",MB_ICONERROR);
               return(true);
              }

            string gv_name = Boleta_MakeGVName(chart_id,base_symbol,overlay_symbol);
            GlobalVariableSet(gv_name,(double)TimeCurrent());

            bool changed = ChartSetSymbolPeriod(chart_id,base_symbol,tf);

            if(!changed || (ChartSymbol(chart_id)==base_symbol && Period()==tf))
              {
               GlobalVariableDel(gv_name);
               Boleta_AddOverlay(chart_id,base_symbol,overlay_symbol,tf);
              }

            Boleta_StyleButton(chart_id,OBJ_BTN_SEARCH,false);
            ChartRedraw();
            return(true);
           }
        }

      // mudança nos spinners -> recalcula com novos valores
      if(id == CHARTEVENT_CUSTOM + ON_CHANGE)
        {
         if(lparam == m_edLoteBase.Id() || lparam == m_edLoteOver.Id())
           {
            UpdateTotals(base_symbol,overlay_symbol);
            return(true);
           }
        }

      return(CAppDialog::OnEvent(id,lparam,dparam,sparam));
     }
  }; // fim da classe

// instância global
CBoletaDialog g_boleta;

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   g_chart_id = ChartID();

   // aparência do gráfico
   ChartSetInteger(ChartID(),CHART_SHOW_GRID,false);
   ChartSetInteger(ChartID(),CHART_COLOR_CANDLE_BULL,BULL_COLOR);
   ChartSetInteger(ChartID(),CHART_COLOR_CANDLE_BEAR,BEAR_COLOR);
   ChartSetInteger(ChartID(),CHART_COLOR_CHART_UP,BULL_COLOR);
   ChartSetInteger(ChartID(),CHART_COLOR_CHART_DOWN,BEAR_COLOR);

   if(!g_boleta.CreateBoleta(g_chart_id))
     {
      Print("OnInit: falha ao criar boleta, INIT_FAILED");
      return(INIT_FAILED);
     }

   ChartRedraw();
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   g_boleta.Destroy(reason);

   if(g_last_overlay_name!="")
      ChartIndicatorDelete(ChartID(),1,g_last_overlay_name);
   ChartIndicatorDelete(ChartID(),1,"SimpleOverlay");
  }

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
  {
   // se quiser, pode atualizar totais em tempo real aqui depois
  }

//+------------------------------------------------------------------+
//| OnChartEvent: só repassa para o dialog                           |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
   g_boleta.ChartEvent(id,lparam,dparam,sparam);
  }
//+------------------------------------------------------------------+
