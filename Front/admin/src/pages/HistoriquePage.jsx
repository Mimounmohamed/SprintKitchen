import React from "react";
import { useNavigate } from "react-router-dom";
import {
  ArrowLeft, ChevronDown, ChevronLeft, ChevronRight as ChevronRightIcon,
  Search, Printer, Circle, Calendar, Smile, X, CheckCircle2, RotateCcw, Ban,
} from "lucide-react";
import { orderService, paymentService } from "../services";

const COLORS = {
  bg:"#F5F4F0",cardBg:"#FFFFFF",ink:"#1C1917",brown:"#2E2117",
  yellow:"#F2B705",muted:"#8B8378",border:"#E7E4DD",green:"#2FAE5C",
  red:"#C0392B",redBg:"#FBEAE7",blue:"#2E5BD9",blueBg:"#EAF0FE",rowHover:"#FAF9F6",
};
const TAB_STATUS = { terminees:"terminee", attente:"en_attente", encaisser:"a_encaisser", repas:"repas_employe" };
const PAYMENT_LABELS = { especes:"Especes", carte_bancaire:"Carte Bancaire", sans_contact:"Sans Contact", ticket_restaurant:"Ticket Restaurant", mixte:"Paiement Mixte" };
const FR_MONTHS=["JANVIER","FEVRIER","MARS","AVRIL","MAI","JUIN","JUILLET","AOUT","SEPTEMBRE","OCTOBRE","NOVEMBRE","DECEMBRE"];
const FR_DAYS_SHORT=["L","M","M","J","V","S","D"];
const RANGE_BG="#FDE9A0";
const TODAY=new Date();

function fmtDate(d){return new Date(d).toLocaleDateString("fr-FR");}
function fmtTime(d){return new Date(d).toLocaleTimeString("fr-FR");}
function fmtPrice(n){return `${(n||0).toFixed(2).replace(".",",")} DA`;}
function addDays(d,n){const r=new Date(d);r.setDate(r.getDate()+n);return r;}
function startOfMonth(d){return new Date(d.getFullYear(),d.getMonth(),1);}
function endOfMonth(d){return new Date(d.getFullYear(),d.getMonth()+1,0);}
function formatDate(d){if(!d)return"";return `${String(d.getDate()).padStart(2,"0")}/${String(d.getMonth()+1).padStart(2,"0")}/${d.getFullYear()}`;}
function isSameDay(a,b){return a&&b&&a.getFullYear()===b.getFullYear()&&a.getMonth()===b.getMonth()&&a.getDate()===b.getDate();}

/* OrderDetailDrawer */
function OrderDetailDrawer({order,onClose,onRefund}){
  const[detail,setDetail]=React.useState(null);
  const[payment,setPayment]=React.useState(null);
  const[loading,setLoading]=React.useState(true);
  const[cancelling,setCancelling]=React.useState(false);
  const isSurPlace=order.orderType==="sur_place";
  const isRefunded=order.status==="annulee";
  React.useEffect(()=>{
    let active=true;
    setLoading(true);
    Promise.all([
      orderService.getById(order._id),
      paymentService.getByOrder(order._id).catch(()=>({data:{data:[]}})),
    ]).then(([oRes,pRes])=>{
      if(!active)return;
      setDetail(oRes.data.data);
      const pays=Array.isArray(pRes.data.data)?pRes.data.data:[];
      setPayment(pays[0]||null);
      setLoading(false);
    }).catch(()=>{if(active)setLoading(false);});
    return()=>{active=false;};
  },[order._id]);
  const handleCancel=async()=>{
    if(cancelling)return;
    setCancelling(true);
    try{await orderService.cancel(order._id,"Remboursement demande");onRefund(order._id);}
    catch(e){console.error(e);setCancelling(false);}
  };
  const payLabel=payment?(PAYMENT_LABELS[payment.method]||payment.method):null;
  const payRef=payment?.cardReference||(payment?._id?payment._id.slice(-6).toUpperCase():null);
  const paySub=payment?.method==="especes"?`Rendu : ${fmtPrice(payment.change||0)}`:"Paiement electronique";
  return(
    <>
      <div onClick={onClose} style={{position:"fixed",inset:0,background:"rgba(28,25,23,.35)",zIndex:300}}/>
      <div style={{position:"fixed",top:0,right:0,height:"100vh",width:500,background:COLORS.bg,zIndex:301,display:"flex",flexDirection:"column",boxShadow:"-8px 0 40px rgba(0,0,0,.18)",overflowY:"auto"}}>
        <div style={{padding:"20px 24px 16px",borderBottom:`1px solid ${COLORS.border}`,background:COLORS.cardBg,flexShrink:0}}>
          <div style={{display:"flex",alignItems:"center",justifyContent:"space-between"}}>
            <div style={{display:"flex",alignItems:"center",gap:12}}>
              <div style={{width:40,height:40,borderRadius:10,background:COLORS.brown,color:COLORS.yellow,display:"flex",alignItems:"center",justifyContent:"center",fontWeight:800,fontSize:13,flexShrink:0}}>SK</div>
              <div>
                <div style={{display:"flex",alignItems:"center",gap:10}}>
                  <span style={{fontSize:18,fontWeight:800,color:COLORS.ink,letterSpacing:"0.03em"}}>COMMANDE #{order.ticketNumber}</span>
                  <span style={{fontSize:11,fontWeight:700,background:isRefunded?"#FBEAE7":"#E6F9EE",color:isRefunded?COLORS.red:COLORS.green,padding:"3px 10px",borderRadius:999}}>{isRefunded?"Annulee":"Terminee"}</span>
                </div>
                <div style={{fontSize:12,color:COLORS.muted,marginTop:2}}>Historique de vente</div>
              </div>
            </div>
            <button onClick={onClose} style={{display:"inline-flex",alignItems:"center",gap:6,padding:"7px 12px",border:`1px solid ${COLORS.border}`,borderRadius:8,background:COLORS.cardBg,cursor:"pointer",fontSize:13,fontWeight:600,fontFamily:"inherit",color:COLORS.ink}}>
              <X size={14}/> Fermer
            </button>
          </div>
        </div>
        <div style={{flex:1,padding:"16px 20px",display:"flex",flexDirection:"column",gap:12}}>
          <div style={{background:COLORS.cardBg,border:`1px solid ${COLORS.border}`,borderRadius:12,padding:"16px 20px"}}>
            <div style={{display:"grid",gridTemplateColumns:"1fr 1fr",gap:"12px 24px"}}>
              <div>
                <div style={{fontSize:10,fontWeight:700,letterSpacing:"0.07em",color:COLORS.muted,textTransform:"uppercase",marginBottom:5}}>Date et Heure</div>
                <div style={{fontSize:13.5,fontWeight:500,color:COLORS.ink,display:"flex",alignItems:"center",gap:6}}><Calendar size={13} color={COLORS.muted}/>{fmtDate(order.createdAt)} a {fmtTime(order.createdAt)}</div>
              </div>
              <div>
                <div style={{fontSize:10,fontWeight:700,letterSpacing:"0.07em",color:COLORS.muted,textTransform:"uppercase",marginBottom:5}}>Caisse</div>
                <div style={{fontSize:13.5,fontWeight:500,color:COLORS.ink,display:"flex",alignItems:"center",gap:6}}><Circle size={7} fill={COLORS.green} color={COLORS.green}/>{order.registerId?.name||"Caisse 01"}</div>
              </div>
              <div>
                <div style={{fontSize:10,fontWeight:700,letterSpacing:"0.07em",color:COLORS.muted,textTransform:"uppercase",marginBottom:5}}>Client</div>
                <div style={{fontSize:13.5,fontWeight:600,color:COLORS.ink}}>{order.buzzerNumber||order.clientName||"Client Passant"}</div>
              </div>
              <div>
                <div style={{fontSize:10,fontWeight:700,letterSpacing:"0.07em",color:COLORS.muted,textTransform:"uppercase",marginBottom:5}}>Mode</div>
                <span style={{display:"inline-flex",alignItems:"center",gap:5,fontSize:12,fontWeight:700,padding:"3px 10px",borderRadius:999,background:isSurPlace?COLORS.redBg:COLORS.blueBg,color:isSurPlace?COLORS.red:COLORS.blue}}>{isSurPlace?"Sur place":"A emporter"}</span>
              </div>
            </div>
          </div>
          {loading?(
            <div style={{background:COLORS.cardBg,border:`1px solid ${COLORS.border}`,borderRadius:12,padding:"32px",textAlign:"center",color:COLORS.muted}}>Chargement...</div>
          ):(
            <div style={{background:COLORS.cardBg,border:`1px solid ${COLORS.border}`,borderRadius:12,overflow:"hidden"}}>
              <div style={{display:"grid",gridTemplateColumns:"40px 1fr auto",padding:"10px 16px",borderBottom:`1px solid ${COLORS.border}`,background:"#FBFAF8"}}>
                <span style={{fontSize:10,fontWeight:700,color:COLORS.muted}}>QTE</span>
                <span style={{fontSize:10,fontWeight:700,color:COLORS.muted}}>ARTICLE</span>
                <span style={{fontSize:10,fontWeight:700,color:COLORS.muted,textAlign:"right"}}>PRIX</span>
              </div>
              {(detail?.items||[]).length===0&&<div style={{padding:"20px 16px",color:COLORS.muted,fontSize:13,textAlign:"center"}}>Aucun article</div>}
              {(detail?.items||[]).map((item,i)=>(
                <div key={i} style={{display:"grid",gridTemplateColumns:"40px 1fr auto",padding:"14px 16px",borderBottom:i<(detail.items.length-1)?`1px solid ${COLORS.border}`:"none",gap:"0 8px"}}>
                  <div style={{fontSize:13,fontWeight:700,color:COLORS.muted,paddingTop:2}}>{item.quantity}x</div>
                  <div>
                    <div style={{fontWeight:700,fontSize:14,color:COLORS.ink}}>{item.productName}</div>
                    {(item.customizations||[]).map((c,ci)=>(
                      <div key={ci} style={{fontSize:12,color:COLORS.muted,marginTop:2}}>{c.groupName}: {(c.selectedOptions||[]).map(o=>o.label).join(", ")}</div>
                    ))}
                    {(item.removedIngredients||[]).map((r,ri)=>(
                      <div key={ri} style={{fontSize:12,color:"#B07A00",fontWeight:600,marginTop:2}}>Sans {r}</div>
                    ))}
                    {item.notes&&<div style={{fontSize:12,color:"#B07A00",fontWeight:600,marginTop:2}}>{item.notes}</div>}
                  </div>
                  <div style={{fontSize:13.5,fontWeight:700,color:COLORS.ink,textAlign:"right",paddingTop:2}}>{fmtPrice(item.lineTotal)}</div>
                </div>
              ))}
            </div>
          )}
          {!loading&&(
            <div style={{background:COLORS.cardBg,border:`1px solid ${COLORS.border}`,borderRadius:12,padding:"14px 20px",display:"flex",justifyContent:"space-between",alignItems:"center"}}>
              <div>
                <div style={{fontSize:11,fontWeight:700,letterSpacing:"0.07em",color:COLORS.muted,textTransform:"uppercase"}}>Total Paye</div>
                <div style={{fontSize:10,color:COLORS.muted,marginTop:1}}>Toutes taxes comprises</div>
              </div>
              <span style={{fontSize:26,fontWeight:800,color:COLORS.ink}}>{fmtPrice(detail?.totalTTC??order.totalTTC)}</span>
            </div>
          )}
          {!loading&&(
            <div style={{background:"#F0FAF4",border:"1px solid #C3EDD4",borderRadius:12,padding:"12px 16px",display:"flex",alignItems:"center",gap:12}}>
              <CheckCircle2 size={20} color={COLORS.green} fill="#D4F5E2" strokeWidth={2} style={{flexShrink:0}}/>
              <div>
                <div style={{fontSize:13,fontWeight:700,color:"#1A7A42"}}>{payLabel?`Paye par ${payLabel}`:"Paiement enregistre"}</div>
                <div style={{fontSize:12,color:COLORS.muted,marginTop:1}}>{payRef?`${paySub} - Ref #${payRef}`:"Transaction confirmee"}</div>
              </div>
            </div>
          )}
        </div>
        <div style={{padding:"14px 20px",borderTop:`1px solid ${COLORS.border}`,background:COLORS.cardBg,display:"flex",flexDirection:"column",gap:10,flexShrink:0}}>
          <button style={{width:"100%",padding:"13px",borderRadius:11,border:"none",background:COLORS.yellow,color:COLORS.brown,fontSize:14,fontWeight:800,cursor:"pointer",fontFamily:"inherit",display:"flex",alignItems:"center",justifyContent:"center",gap:10}}>
            <Printer size={16}/> IMPRIMER LE TICKET DE CAISSE
          </button>
          <div style={{display:"flex",gap:10}}>
            <button style={{flex:1,padding:"11px",borderRadius:10,border:`1px solid ${COLORS.border}`,background:COLORS.cardBg,color:COLORS.ink,fontSize:12.5,fontWeight:600,cursor:"pointer",fontFamily:"inherit",display:"flex",alignItems:"center",justifyContent:"center",gap:7}}>
              <RotateCcw size={14}/> Reimprimer Bon Cuisine
            </button>
            {!isRefunded&&(
              <button onClick={handleCancel} disabled={cancelling}
                style={{flex:1,padding:"11px",borderRadius:10,border:`1px solid ${COLORS.redBg}`,background:COLORS.redBg,color:COLORS.red,fontSize:12.5,fontWeight:600,cursor:cancelling?"default":"pointer",fontFamily:"inherit",display:"flex",alignItems:"center",justifyContent:"center",gap:7,opacity:cancelling?0.6:1}}>
                <Ban size={14}/> {cancelling?"En cours...":"Remboursement / Annulation"}
              </button>
            )}
          </div>
        </div>
      </div>
    </>
  );
}


/* Shared helpers */
function ModePill({mode}){
  const isSurPlace=mode==="sur-place";
  return(<span style={{display:"inline-flex",alignItems:"center",gap:6,fontSize:12,fontWeight:600,padding:"4px 10px",borderRadius:999,background:isSurPlace?COLORS.redBg:COLORS.blueBg,color:isSurPlace?COLORS.red:COLORS.blue}}><Circle size={6} fill={isSurPlace?COLORS.red:COLORS.blue} color={isSurPlace?COLORS.red:COLORS.blue}/>{isSurPlace?"Sur place":"A emporter"}</span>);
}
function Tab({children,active,waiting,badge,onClick}){
  return(<button onClick={onClick} style={{display:"inline-flex",alignItems:"center",gap:8,fontSize:13,fontWeight:700,padding:"10px 16px",borderRadius:10,background:active?COLORS.brown:COLORS.cardBg,border:`1px solid ${active?COLORS.brown:COLORS.border}`,color:active?"#F5F0E6":COLORS.muted,cursor:"pointer",fontFamily:"inherit"}}>{waiting&&<Circle size={6} fill={COLORS.yellow} color={COLORS.yellow}/>}{children}{badge!=null&&<span style={{background:active?COLORS.yellow:"#EFECE4",color:active?COLORS.brown:COLORS.ink,fontSize:11,fontWeight:800,padding:"1px 7px",borderRadius:999}}>{badge}</span>}</button>);
}
function PageBtn({children,active,disabled,onClick}){
  return(<button disabled={disabled} onClick={onClick} style={{minWidth:34,height:34,padding:"0 10px",borderRadius:8,border:`1px solid ${active?COLORS.brown:COLORS.border}`,background:active?COLORS.brown:COLORS.cardBg,color:disabled?"#C7C0B4":active?"#F5F0E6":COLORS.ink,fontSize:13,fontWeight:600,cursor:disabled?"default":"pointer",fontFamily:"inherit"}}>{children}</button>);
}
function cellStyle(i,total){return{padding:"14px 20px",fontSize:13.5,borderBottom:i===total-1?"none":`1px solid ${COLORS.border}`,color:COLORS.ink,verticalAlign:"middle"};}

/* MonthGrid */
function MonthGrid({year,month,lo,hi,picking,hovered,onDayClick,onDayHover}){
  let startDow=new Date(year,month,1).getDay();
  startDow=startDow===0?6:startDow-1;
  const daysInMonth=new Date(year,month+1,0).getDate();
  const cells=[];
  for(let i=0;i<startDow;i++)cells.push(null);
  for(let d=1;d<=daysInMonth;d++)cells.push(new Date(year,month,d));
  const effHi=hi||(picking&&hovered?hovered:null);
  const realLo=lo&&effHi?(lo<=effHi?lo:effHi):lo;
  const realHi=lo&&effHi?(lo<=effHi?effHi:lo):null;
  return(
    <div style={{flex:1,minWidth:0}}>
      <div style={{textAlign:"center",fontWeight:800,fontSize:12.5,letterSpacing:"0.07em",color:COLORS.ink,marginBottom:12}}>{FR_MONTHS[month]} {year}</div>
      <div style={{display:"grid",gridTemplateColumns:"repeat(7,34px)",rowGap:1,justifyContent:"center"}}>
        {FR_DAYS_SHORT.map((d,i)=>(<div key={i} style={{textAlign:"center",fontSize:11,fontWeight:700,color:COLORS.muted,paddingBottom:6,height:22,display:"flex",alignItems:"center",justifyContent:"center"}}>{d}</div>))}
        {cells.map((d,i)=>{
          if(!d)return<div key={`e${i}`} style={{height:36}}/>;
          const isStart=realLo&&isSameDay(d,realLo);
          const isEnd=realHi&&isSameDay(d,realHi);
          const isBoth=isStart&&isEnd;
          const inRange=realLo&&realHi&&d>realLo&&d<realHi;
          const isToday=isSameDay(d,TODAY);
          const isSelect=isStart||isEnd;
          let cellBg="transparent";
          if(!isBoth){
            if(isStart&&realHi)cellBg=`linear-gradient(to right,transparent 50%,${RANGE_BG} 50%)`;
            else if(isEnd)cellBg=`linear-gradient(to left,transparent 50%,${RANGE_BG} 50%)`;
            else if(inRange)cellBg=RANGE_BG;
          }
          return(
            <div key={i} onClick={()=>onDayClick(d)} onMouseEnter={()=>onDayHover(d)} style={{height:36,display:"flex",alignItems:"center",justifyContent:"center",cursor:"pointer",background:cellBg}}>
              <span style={{display:"inline-flex",alignItems:"center",justifyContent:"center",width:32,height:32,borderRadius:"50%",fontSize:13,fontWeight:isSelect?700:400,background:isSelect?COLORS.brown:inRange?RANGE_BG:"transparent",color:isSelect?"#FFF8E7":inRange?"#7A5C00":isToday?COLORS.brown:COLORS.ink,boxShadow:isToday&&isEnd&&!isBoth?`0 0 0 2px ${COLORS.brown},0 0 0 4.5px ${COLORS.yellow}`:isToday&&!isSelect?`0 0 0 2px ${COLORS.yellow}`:"none"}}>{d.getDate()}</span>
            </div>
          );
        })}
      </div>
    </div>
  );
}

/* DateRangeModal */
function DateRangeModal({onClose,onApply,initialRange}){
  const[rangeStart,setRangeStart]=React.useState(initialRange?.start||addDays(TODAY,-6));
  const[rangeEnd,setRangeEnd]=React.useState(initialRange?.end||TODAY);
  const[hovered,setHovered]=React.useState(null);
  const[picking,setPicking]=React.useState(false);
  const[activeKey,setActiveKey]=React.useState("7j");
  const[rightMonth,setRightMonth]=React.useState({year:TODAY.getFullYear(),month:TODAY.getMonth()});
  const leftMonth=rightMonth.month===0?{year:rightMonth.year-1,month:11}:{year:rightMonth.year,month:rightMonth.month-1};
  const apply=(fn,key)=>{fn();setActiveKey(key);setPicking(false);};
  const shortcuts=[
    {key:"today",label:"Aujourd'hui",fn:()=>{setRangeStart(TODAY);setRangeEnd(TODAY);}},
    {key:"hier",label:"Hier",fn:()=>{const y=addDays(TODAY,-1);setRangeStart(y);setRangeEnd(y);}},
    {key:"7j",label:"7 derniers jours",fn:()=>{setRangeStart(addDays(TODAY,-6));setRangeEnd(TODAY);}},
    {key:"mois",label:"Ce mois-ci",fn:()=>{setRangeStart(startOfMonth(TODAY));setRangeEnd(TODAY);}},
    {key:"last",label:"Mois dernier",fn:()=>{const lm=new Date(TODAY.getFullYear(),TODAY.getMonth()-1,1);setRangeStart(lm);setRangeEnd(endOfMonth(lm));}},
    {key:"custom",label:"Personnalise",chevron:true,fn:()=>{}},
  ];
  const handleDayClick=(d)=>{
    setActiveKey("custom");
    if(!picking){setRangeStart(d);setRangeEnd(null);setPicking(true);}
    else{if(d<rangeStart){setRangeEnd(rangeStart);setRangeStart(d);}else{setRangeEnd(d);}setPicking(false);}
  };
  const effEnd=rangeEnd||rangeStart;
  const lo=rangeStart&&effEnd?(rangeStart<=effEnd?rangeStart:effEnd):rangeStart;
  const hi=rangeStart&&effEnd?(rangeStart<=effEnd?effEnd:rangeStart):null;
  const dayCount=lo&&hi?Math.round(Math.abs(hi-lo)/86400000)+1:1;
  const navBtn=(onClick,icon)=>(<button onClick={onClick} style={{background:"none",border:`1px solid ${COLORS.border}`,borderRadius:8,width:30,height:30,cursor:"pointer",display:"flex",alignItems:"center",justifyContent:"center",color:COLORS.ink,flexShrink:0}}>{icon}</button>);
  return(
    <div onClick={e=>e.target===e.currentTarget&&onClose()} style={{position:"fixed",inset:0,background:"rgba(28,25,23,.5)",zIndex:400,display:"flex",alignItems:"center",justifyContent:"center",padding:20}}>
      <div style={{background:COLORS.cardBg,borderRadius:16,width:"min(760px,96vw)",boxShadow:"0 24px 80px rgba(0,0,0,.3)",overflow:"hidden"}}>
        <div style={{display:"flex",alignItems:"flex-start",justifyContent:"space-between",padding:"18px 22px 16px"}}>
          <div style={{display:"flex",alignItems:"center",gap:12}}>
            <div style={{width:38,height:38,borderRadius:9,background:"#F1F0EC",display:"flex",alignItems:"center",justifyContent:"center",flexShrink:0}}><Calendar size={17} color={COLORS.ink}/></div>
            <div>
              <div style={{fontSize:15.5,fontWeight:800,color:COLORS.ink}}>SELECTIONNER UNE PERIODE DE VENTE</div>
              <div style={{fontSize:12,color:COLORS.muted,marginTop:3}}>Filtrer l'historique des encaissements et tickets</div>
            </div>
          </div>
          <button onClick={onClose} style={{background:"none",border:"none",cursor:"pointer",color:COLORS.muted,padding:4,flexShrink:0}}><X size={16}/></button>
        </div>
        <div style={{height:1,background:COLORS.border}}/>
        <div style={{display:"flex"}}>
          <div style={{width:185,borderRight:`1px solid ${COLORS.border}`,padding:"14px 0",flexShrink:0}}>
            <div style={{fontSize:10,fontWeight:700,letterSpacing:"0.09em",color:COLORS.muted,textTransform:"uppercase",padding:"0 14px 10px"}}>Raccourcis</div>
            {shortcuts.map(s=>{
              const on=activeKey===s.key;
              return(
                <button key={s.key} onClick={()=>apply(s.fn,s.key)} style={{display:"flex",alignItems:"center",justifyContent:"space-between",width:on?"calc(100% - 12px)":"100%",margin:on?"3px 6px":"3px 0",padding:"9px 14px",background:on?COLORS.brown:"transparent",border:"none",cursor:"pointer",fontFamily:"inherit",textAlign:"left",borderRadius:on?9:0}}>
                  <span style={{fontSize:13,fontWeight:600,color:on?"#FFF8E7":COLORS.ink}}>{s.label}</span>
                  <span style={{display:"flex",alignItems:"center",gap:5,flexShrink:0}}>
                    {on&&<span style={{fontSize:10,fontWeight:800,background:COLORS.yellow,color:COLORS.brown,padding:"2px 8px",borderRadius:999}}>Actif</span>}
                    {s.chevron&&<ChevronRightIcon size={12} color={COLORS.muted}/>}
                  </span>
                </button>
              );
            })}
          </div>
          <div style={{flex:1,padding:"14px 8px 18px"}} onMouseLeave={()=>setHovered(null)}>
            <div style={{display:"flex",alignItems:"flex-start",gap:6}}>
              <div style={{paddingTop:2,flexShrink:0}}>{navBtn(()=>setRightMonth(p=>p.month===0?{year:p.year-1,month:11}:{year:p.year,month:p.month-1}),<ChevronLeft size={13}/>)}</div>
              <div style={{display:"flex",flex:1,gap:8,minWidth:0}}>
                <MonthGrid {...leftMonth} lo={lo} hi={hi} picking={picking} hovered={hovered} onDayClick={handleDayClick} onDayHover={setHovered}/>
                <MonthGrid {...rightMonth} lo={lo} hi={hi} picking={picking} hovered={hovered} onDayClick={handleDayClick} onDayHover={setHovered}/>
              </div>
              <div style={{paddingTop:2,flexShrink:0}}>{navBtn(()=>setRightMonth(p=>p.month===11?{year:p.year+1,month:0}:{year:p.year,month:p.month+1}),<ChevronRightIcon size={13}/>)}</div>
            </div>
          </div>
        </div>
        <div style={{height:1,background:COLORS.border}}/>
        <div style={{display:"flex",alignItems:"center",justifyContent:"space-between",padding:"14px 22px",gap:12,flexWrap:"wrap"}}>
          <div style={{display:"flex",alignItems:"center",gap:8}}>
            <span style={{fontSize:13,color:COLORS.ink,fontWeight:500}}>Periode :</span>
            <span style={{fontSize:12,fontWeight:600,background:"#F5F4F0",border:`1px solid ${COLORS.border}`,borderRadius:7,padding:"4px 10px",fontFamily:"monospace",whiteSpace:"nowrap"}}>
              {formatDate(lo)} - {formatDate(hi||lo)}
              {dayCount>0&&<span style={{color:COLORS.muted,marginLeft:5}}>({dayCount} jour{dayCount>1?"s":""})</span>}
            </span>
          </div>
          <div style={{display:"flex",gap:10,flexShrink:0}}>
            <button onClick={onClose} style={{padding:"9px 18px",borderRadius:9,border:`1px solid ${COLORS.border}`,background:COLORS.cardBg,fontSize:13,fontWeight:600,cursor:"pointer",fontFamily:"inherit",color:COLORS.ink}}>Annuler</button>
            <button onClick={()=>{onApply(lo,hi||lo);onClose();}} style={{padding:"9px 20px",borderRadius:9,border:"none",background:COLORS.yellow,fontSize:13,fontWeight:800,cursor:"pointer",fontFamily:"inherit",color:COLORS.brown}}>Appliquer la periode</button>
          </div>
        </div>
      </div>
    </div>
  );
}

/* Page */
export default function HistoriquePage(){
  const navigate=useNavigate();
  const[activeTab,setActiveTab]=React.useState("terminees");
  const[page,setPage]=React.useState(1);
  const[search,setSearch]=React.useState("");
  const[showDatePicker,setShowDatePicker]=React.useState(false);
  const[appliedRange,setAppliedRange]=React.useState({start:addDays(new Date(),-6),end:new Date()});
  const[selectedOrder,setSelectedOrder]=React.useState(null);
  const[orders,setOrders]=React.useState([]);
  const[loading,setLoading]=React.useState(true);
  const[totalOrders,setTotalOrders]=React.useState(0);
  const[totalPages,setTotalPages]=React.useState(1);

  const fetchOrders=React.useCallback(async()=>{
    setLoading(true);
    try{
      const endDate=new Date(appliedRange.end);
      endDate.setHours(23,59,59,999);
      const res=await orderService.getAll({status:TAB_STATUS[activeTab],search:search||undefined,page,limit:10,from:appliedRange.start.toISOString(),to:endDate.toISOString()});
      setOrders(res.data.data||[]);
      setTotalOrders(res.data.total||0);
      setTotalPages(res.data.totalPages||1);
    }catch(err){console.error(err);setOrders([]);}
    finally{setLoading(false);}
  },[activeTab,page,search,appliedRange]);

  React.useEffect(()=>{fetchOrders();},[fetchOrders]);

  const handleTabChange=(tab)=>{setActiveTab(tab);setPage(1);};
  const handleSearch=(val)=>{setSearch(val);setPage(1);};
  const handleRange=(s,e)=>{setAppliedRange({start:s,end:e});setPage(1);};
  const handleRefund=(id)=>{setOrders(prev=>prev.map(o=>o._id===id?{...o,status:"annulee"}:o));setSelectedOrder(null);};

  const pageNumbers=(()=>{
    const nums=[];
    let start=Math.max(1,Math.min(page-2,totalPages-4));
    for(let n=start;n<=Math.min(totalPages,start+4);n++)nums.push(n);
    return nums;
  })();

  return(
    <div style={{minHeight:"100vh",background:COLORS.bg,fontFamily:"'Inter',-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif",color:COLORS.ink,display:"flex",flexDirection:"column"}}>
      <header style={{display:"flex",alignItems:"center",justifyContent:"space-between",padding:"14px 32px",borderBottom:`1px solid ${COLORS.border}`,background:COLORS.cardBg}}>
        <div style={{display:"flex",alignItems:"center",gap:18}}>
          <button onClick={()=>navigate("/")} style={{display:"inline-flex",alignItems:"center",gap:8,fontSize:13,fontWeight:600,color:COLORS.ink,background:COLORS.cardBg,border:`1px solid ${COLORS.border}`,borderRadius:8,padding:"8px 14px",cursor:"pointer",fontFamily:"inherit"}}>
            <ArrowLeft size={15}/> Retour
          </button>
          <div style={{display:"flex",alignItems:"center",gap:10}}>
            <div style={{width:30,height:30,borderRadius:"50%",background:COLORS.brown,color:COLORS.yellow,display:"flex",alignItems:"center",justifyContent:"center"}}><Smile size={16}/></div>
            <span style={{fontSize:15,fontWeight:800,letterSpacing:"0.02em"}}>SPRINTKITCHEN</span>
          </div>
        </div>
        <span style={{display:"inline-flex",alignItems:"center",gap:6,fontSize:12,fontWeight:600,padding:"6px 12px",borderRadius:999,background:"#F1F0EC",color:COLORS.ink}}><Circle size={6} fill={COLORS.green} color={COLORS.green}/> Caisse 01</span>
      </header>

      <main style={{flex:1,padding:"24px 32px 32px",maxWidth:1280,margin:"0 auto",width:"100%"}}>
        <div style={{display:"flex",alignItems:"flex-start",justifyContent:"space-between",gap:24,flexWrap:"wrap"}}>
          <div>
            <span style={{fontSize:11,fontWeight:600,letterSpacing:"0.05em",color:COLORS.muted}}>HISTORIQUE DES VENTES</span>
            <div style={{display:"flex",alignItems:"center",gap:10,marginTop:6}}>
              <div style={{width:30,height:30,borderRadius:8,background:"#F1F0EC",display:"flex",alignItems:"center",justifyContent:"center",color:COLORS.ink,flexShrink:0}}><Calendar size={16}/></div>
              <h1 style={{margin:0,fontSize:21,fontWeight:800,letterSpacing:"0.01em",textTransform:"uppercase"}}>Commandes du {formatDate(appliedRange.start)} au {formatDate(appliedRange.end)}</h1>
              <ChevronDown size={16} color={COLORS.muted} style={{cursor:"pointer"}} onClick={()=>setShowDatePicker(true)}/>
            </div>
          </div>
          <div style={{display:"flex",alignItems:"center",gap:10,flexShrink:0}}>
            <div style={{display:"flex",alignItems:"center",gap:8,background:COLORS.cardBg,border:`1px solid ${COLORS.border}`,borderRadius:10,padding:"10px 14px",minWidth:260,color:COLORS.muted}}>
              <Search size={15}/>
              <input type="text" placeholder="Rechercher ticket, client..." value={search} onChange={e=>handleSearch(e.target.value)} style={{border:"none",outline:"none",fontSize:13,fontFamily:"inherit",flex:1,background:"transparent",color:COLORS.ink}}/>
            </div>
            <button onClick={()=>setShowDatePicker(true)} style={{display:"inline-flex",alignItems:"center",gap:8,fontSize:13,fontWeight:700,color:COLORS.ink,background:COLORS.cardBg,border:`1px solid ${COLORS.border}`,borderRadius:10,padding:"10px 16px",cursor:"pointer",fontFamily:"inherit",whiteSpace:"nowrap"}}>
              <Printer size={15}/> Imprimer Cloture
            </button>
          </div>
        </div>

        <div style={{display:"flex",alignItems:"center",justifyContent:"space-between",gap:20,marginTop:22,flexWrap:"wrap"}}>
          <div style={{display:"flex",gap:8}}>
            <Tab waiting onClick={()=>handleTabChange("attente")} active={activeTab==="attente"}>En attente</Tab>
            <Tab onClick={()=>handleTabChange("encaisser")} active={activeTab==="encaisser"}>A encaisser</Tab>
            <Tab active={activeTab==="terminees"} badge={activeTab==="terminees"?totalOrders:null} onClick={()=>handleTabChange("terminees")}>Terminees</Tab>
            <Tab onClick={()=>handleTabChange("repas")} active={activeTab==="repas"}>Repas Empl.</Tab>
          </div>
          <span style={{fontSize:12.5,color:COLORS.muted}}><b style={{color:COLORS.ink}}>{totalOrders}</b> commande{totalOrders!==1?"s":""} &bull; page {page}/{totalPages}</span>
        </div>

        <div style={{marginTop:20,background:COLORS.cardBg,border:`1px solid ${COLORS.border}`,borderRadius:14,overflow:"hidden"}}>
          <div style={{overflowX:"auto"}}>
            <table style={{width:"100%",borderCollapse:"collapse",minWidth:800}}>
              <thead>
                <tr>
                  {["DATE","HEURE","NUMERO","MONTANT","CAISSE","CLIENT","MODE"].map(h=>(<th key={h} style={{textAlign:"left",fontSize:10.5,fontWeight:700,letterSpacing:"0.06em",color:COLORS.muted,padding:"14px 20px",borderBottom:`1px solid ${COLORS.border}`,background:"#FBFAF8"}}>{h}</th>))}
                  <th style={{textAlign:"right",fontSize:10.5,fontWeight:700,letterSpacing:"0.06em",color:COLORS.muted,padding:"14px 20px",borderBottom:`1px solid ${COLORS.border}`,background:"#FBFAF8"}}>ACTIONS</th>
                </tr>
              </thead>
              <tbody>
                {loading?(
                  <tr><td colSpan={8} style={{padding:48,textAlign:"center",color:COLORS.muted,fontSize:14}}>Chargement...</td></tr>
                ):orders.length===0?(
                  <tr><td colSpan={8} style={{padding:48,textAlign:"center",color:COLORS.muted,fontSize:14}}>Aucune commande</td></tr>
                ):orders.map((o,i)=>{
                  const isRefunded=o.status==="annulee";
                  const highlight=i===0&&!isRefunded;
                  const client=o.buzzerNumber||o.clientName||"Client Passant";
                  const clientMuted=!o.clientName&&!o.buzzerNumber;
                  const mode=o.orderType==="sur_place"?"sur-place":"emporter";
                  return(
                    <tr key={o._id} style={{boxShadow:isRefunded?`inset 3px 0 0 ${COLORS.red}`:highlight?`inset 3px 0 0 ${COLORS.yellow}`:"none",opacity:isRefunded?0.7:1}}
                      onMouseEnter={e=>{if(!highlight&&!isRefunded)Array.from(e.currentTarget.cells).forEach(c=>c.style.background=COLORS.rowHover);}}
                      onMouseLeave={e=>{if(!highlight&&!isRefunded)Array.from(e.currentTarget.cells).forEach(c=>c.style.background="transparent");}}>
                      <td style={cellStyle(i,orders.length)}>{fmtDate(o.createdAt)}</td>
                      <td style={cellStyle(i,orders.length)}>{fmtTime(o.createdAt)}</td>
                      <td style={cellStyle(i,orders.length)}>
                        <div style={{display:"flex",alignItems:"center",gap:7,flexWrap:"wrap"}}>
                          <span style={{display:"inline-flex",alignItems:"center",gap:6,background:isRefunded?"#FBEAE7":"#F1F0EC",borderRadius:6,padding:"3px 9px",fontSize:12.5,fontWeight:700,fontFamily:"monospace",textDecoration:isRefunded?"line-through":"none",color:isRefunded?COLORS.red:COLORS.ink}}>
                            {highlight&&<Circle size={6} fill={COLORS.green} color={COLORS.green}/>}
                            {isRefunded&&<Circle size={6} fill={COLORS.red} color={COLORS.red}/>}
                            #{o.ticketNumber}
                          </span>
                          {isRefunded&&<span style={{fontSize:10,fontWeight:800,background:COLORS.redBg,color:COLORS.red,padding:"2px 8px",borderRadius:999,textTransform:"uppercase"}}>Annulee</span>}
                        </div>
                      </td>
                      <td style={{...cellStyle(i,orders.length),fontWeight:700,textDecoration:isRefunded?"line-through":"none",color:isRefunded?COLORS.muted:COLORS.ink}}>{fmtPrice(o.totalTTC)}</td>
                      <td style={cellStyle(i,orders.length)}><span style={{background:"#F1F0EC",color:COLORS.muted,fontSize:12,fontWeight:600,padding:"3px 10px",borderRadius:6}}>{o.registerId?.name||"Caisse"}</span></td>
                      <td style={{...cellStyle(i,orders.length),color:clientMuted?COLORS.muted:COLORS.ink,fontStyle:clientMuted?"italic":"normal"}}>{client}</td>
                      <td style={cellStyle(i,orders.length)}><ModePill mode={mode}/></td>
                      <td style={{...cellStyle(i,orders.length),textAlign:"right",whiteSpace:"nowrap"}}>
                        <button onClick={()=>setSelectedOrder(o)} style={{fontSize:12.5,fontWeight:700,padding:"8px 16px",borderRadius:8,border:`1px solid ${highlight?COLORS.brown:COLORS.border}`,background:highlight?COLORS.brown:COLORS.cardBg,color:highlight?"#F5F0E6":COLORS.ink,cursor:"pointer",fontFamily:"inherit"}}>Details</button>
                        {highlight&&(<button style={{width:32,height:32,borderRadius:8,border:`1px solid ${COLORS.border}`,background:COLORS.cardBg,color:COLORS.muted,display:"inline-flex",alignItems:"center",justifyContent:"center",cursor:"pointer",marginLeft:8}}><Printer size={14}/></button>)}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
          <div style={{display:"flex",alignItems:"center",justifyContent:"space-between",padding:"16px 20px",flexWrap:"wrap",gap:12}}>
            <span style={{fontSize:12.5,color:COLORS.muted}}>{totalOrders} commande{totalOrders!==1?"s":""} au total</span>
            <div style={{display:"flex",alignItems:"center",gap:6}}>
              <PageBtn disabled={page<=1} onClick={()=>setPage(p=>p-1)}>Precedent</PageBtn>
              {pageNumbers.map(n=><PageBtn key={n} active={page===n} onClick={()=>setPage(n)}>{n}</PageBtn>)}
              <PageBtn disabled={page>=totalPages} onClick={()=>setPage(p=>p+1)}>Suivant</PageBtn>
            </div>
          </div>
        </div>
      </main>

      <footer style={{display:"flex",alignItems:"center",justifyContent:"space-between",padding:"16px 32px",borderTop:`1px solid ${COLORS.border}`}}>
        <span style={{display:"inline-flex",alignItems:"center",gap:6,fontSize:12,fontWeight:600,color:COLORS.ink}}><Circle size={6} fill={COLORS.green} color={COLORS.green}/> Connecte</span>
        <span style={{fontSize:12,color:COLORS.muted}}>SprintKitchen OS v2.4.0-PROD</span>
      </footer>

      {showDatePicker&&(<DateRangeModal initialRange={appliedRange} onClose={()=>setShowDatePicker(false)} onApply={handleRange}/>)}
      {selectedOrder&&(<OrderDetailDrawer order={selectedOrder} onClose={()=>setSelectedOrder(null)} onRefund={handleRefund}/>)}
    </div>
  );
}

