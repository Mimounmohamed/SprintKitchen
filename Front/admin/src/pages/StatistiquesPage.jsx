import React from "react";
import { useNavigate } from "react-router-dom";
import { ArrowLeft, Circle, Download, Printer, ChevronRight, TrendingUp, TrendingDown } from "lucide-react";

const C={bg:"#F5F4F0",cardBg:"#FFFFFF",ink:"#1C1917",brown:"#2E2117",yellow:"#F2B705",yellowBg:"#FCEFCB",muted:"#8B8378",border:"#E7E4DD",green:"#2FAE5C",greenBg:"#E6F9EE",red:"#C0392B",redBg:"#FBEAE7",blue:"#2E5BD9"};

function fmtDA(n){return `${(n||0).toLocaleString("fr-FR",{minimumFractionDigits:2,maximumFractionDigits:2})} DA`;}

const PERIODS=["Aujourd'hui","Hier","7 Derniers Jours","Ce Mois-ci"];
const STATS={"Aujourd'hui":{ca:1450,caDelta:14,caUp:true,tickets:142,ticketsDelta:6,ticketsUp:true,panier:10.21,panierDelta:0.73,panierUp:true,tva:131.82,tva10:119.94,tva55:11.88},"Hier":{ca:1271,caDelta:3,caUp:false,tickets:134,ticketsDelta:2,ticketsUp:false,panier:9.48,panierDelta:0.12,panierUp:false,tva:115.54,tva10:104.13,tva55:11.41},"7 Derniers Jours":{ca:9840,caDelta:8,caUp:true,tickets:920,ticketsDelta:42,ticketsUp:true,panier:10.70,panierDelta:0.50,panierUp:true,tva:894.55,tva10:805.51,tva55:89.04},"Ce Mois-ci":{ca:34200,caDelta:11,caUp:true,tickets:3210,ticketsDelta:120,ticketsUp:true,panier:10.65,panierDelta:0.35,panierUp:true,tva:3109.09,tva10:2800,tva55:309.09}};
const HOURLY=[{h:"11h",v:45},{h:"12h",v:340,peak:true},{h:"13h",v:210},{h:"14h",v:80},{h:"15h",v:60},{h:"16h",v:55},{h:"17h",v:45},{h:"18h",v:90},{h:"19h",v:180},{h:"20h",v:260},{h:"21h",v:85,active:true}];
const TOP=[{rank:1,name:"Menu B4 Cheese",sub:"Menu x 9,00 DA",ca:420,qty:42},{rank:2,name:"Menu BBQ Bacon",sub:"Burger x 12,50 DA",ca:280,qty:26},{rank:3,name:"Burger Double Cheese",sub:"Burger x 9,00 DA",ca:180,qty:20},{rank:4,name:"Frites Maison XL",sub:"Frite x 5,00 DA",ca:126,qty:26}];
const PAYMENTS=[{label:"Carte Bancaire (Sans Contact)",amount:1044,pct:72,color:C.brown},{label:"Especes (Tiroir Caisse)",amount:319,pct:22,color:C.red},{label:"Titres Restaurant / Autres",amount:97,pct:6,color:C.yellow}];
const CANAUX=[{label:"Sur Place",tickets:85,pct:60,color:C.brown},{label:"A Emporter",tickets:42,pct:30,color:C.muted},{label:"Livraison (Coursiers)",tickets:15,pct:10,color:C.yellow}];

function Card({children,style={}}){return <div style={{background:C.cardBg,border:`1px solid ${C.border}`,borderRadius:14,padding:"16px 18px",...style}}>{children}</div>;}
function SecTitle({children,right}){return <div style={{display:"flex",alignItems:"center",justifyContent:"space-between",marginBottom:14}}><span style={{color:"#583926",fontFamily:"'Bebas Neue',sans-serif",fontSize:18,fontStyle:"normal",fontWeight:400,lineHeight:"22.5px",letterSpacing:"0.45px"}}>{children}</span>{right&&<span style={{fontSize:11,fontWeight:600,color:C.muted}}>{right}</span>}</div>;}
function Bar({pct,color}){return <div style={{height:6,borderRadius:3,background:"#EDEAE3"}}><div style={{height:"100%",width:`${pct}%`,background:color,borderRadius:3}}/></div>;}
function Delta({v,up,suffix=""}){return <span style={{display:"inline-flex",alignItems:"center",gap:3,fontSize:10.5,fontWeight:700,color:up?C.green:C.red}}>{up?<TrendingUp size={10}/>:<TrendingDown size={10}/>}{up?"+":"-"}{v}{suffix}</span>;}

function KpiCard({label,value,accent,delta,deltaUp,deltaLabel,sub,icon}){
  return(
    <Card style={{minWidth:0}}>
      <div style={{display:"flex",alignItems:"center",justifyContent:"space-between",marginBottom:6}}>
        <span style={{color:"#78716C",fontFamily:"Inter,sans-serif",fontSize:10,fontStyle:"normal",fontWeight:700,lineHeight:"15px",letterSpacing:"0.5px",textTransform:"uppercase"}}>{label}</span>
        {icon&&<div style={{width:24,height:24,borderRadius:6,background:"#F1F0EC",display:"flex",alignItems:"center",justifyContent:"center",fontSize:12,flexShrink:0}}>{icon}</div>}
      </div>
      <div style={{color:"#583926",fontFamily:"'Bebas Neue',sans-serif",fontSize:24,fontStyle:"normal",fontWeight:400,lineHeight:"24px",letterSpacing:"0.6px",marginTop:4}}>{value}</div>
      {sub&&<div style={{fontSize:10,color:C.muted,marginTop:3}}>{sub}</div>}
      {delta!==undefined&&<div style={{display:"flex",alignItems:"center",gap:5,marginTop:4}}><Delta v={delta} up={deltaUp} suffix="%"/>{deltaLabel&&<span style={{fontSize:10,color:C.muted}}>{deltaLabel}</span>}</div>}
    </Card>
  );
}

function HourlyChart({isMobile}){
  const maxV=Math.max(...HOURLY.map(h=>h.v));
  return(
    <Card>
      <div style={{display:"flex",alignItems:"flex-start",justifyContent:"space-between",gap:8,marginBottom:10,flexWrap:"wrap"}}>
        <div><div style={{color:"#583926",fontFamily:"'Bebas Neue',sans-serif",fontSize:18,fontStyle:"normal",fontWeight:400,lineHeight:"22.5px",letterSpacing:"0.45px"}}>Evolution des Ventes par Heure</div><div style={{fontSize:11,color:C.muted,marginTop:3}}>Distribution du CA de 11:00 a 22:00</div></div>
        <span style={{fontSize:10.5,fontWeight:700,background:C.yellowBg,color:C.brown,padding:"3px 9px",borderRadius:6,whiteSpace:"nowrap",flexShrink:0}}>Pic : 12h-13h ({fmtDA(340)})</span>
      </div>
      <div style={{textAlign:"right",fontSize:9.5,color:C.muted,marginBottom:3}}>{maxV} DA</div>
      <div style={{display:"flex",alignItems:"flex-end",gap:isMobile?3:5,height:110}}>
        {HOURLY.map((bar,i)=>{
          const pct=bar.v/maxV;
          return(
            <div key={i} style={{flex:1,display:"flex",flexDirection:"column",alignItems:"center",justifyContent:"flex-end",height:"100%",gap:2}}>
              {bar.peak&&<span style={{fontSize:8,fontWeight:800,background:C.yellow,color:C.brown,padding:"1px 3px",borderRadius:3}}>{Math.round(pct*100)}%</span>}
              <div style={{width:"100%",borderRadius:"3px 3px 0 0",height:`${Math.max(pct*100,2)}%`,background:bar.peak?C.brown:bar.active?C.yellow:"#D4CFC8"}}/>
            </div>
          );
        })}
      </div>
      <div style={{display:"flex",gap:isMobile?3:5,marginTop:5}}>
        {HOURLY.map((bar,i)=><div key={i} style={{flex:1,textAlign:"center",fontSize:8.5,color:bar.active?C.yellow:C.muted,fontWeight:bar.active?700:400}}>{bar.h}</div>)}
      </div>
      <div style={{display:"flex",alignItems:"center",gap:14,marginTop:10,flexWrap:"wrap"}}>
        <span style={{display:"inline-flex",alignItems:"center",gap:5,fontSize:10.5,color:C.muted}}><span style={{width:9,height:9,borderRadius:2,background:C.yellow,display:"inline-block"}}/>Creneau du Midi : 835,00 DA (58%)</span>
        <span style={{fontSize:10.5,color:C.muted,fontStyle:"italic"}}>* En cours</span>
      </div>
    </Card>
  );
}

function TopArticles(){
  const total=TOP.reduce((s,a)=>s+a.ca,0);
  return(
    <Card>
      <SecTitle right="Top 4">Articles les Plus Vendus</SecTitle>
      <div style={{fontSize:11,color:C.muted,marginTop:-8,marginBottom:12}}>Classement par volume de commande</div>
      {TOP.map((a,i)=>(
        <div key={i} style={{display:"flex",alignItems:"center",gap:10,padding:"10px 0",borderBottom:i<TOP.length-1?`1px solid ${C.border}`:"none"}}>
          <div style={{width:24,height:24,borderRadius:"50%",background:a.rank===1?C.brown:a.rank===2?"#6B7280":"#B58B3A",color:"#fff",display:"flex",alignItems:"center",justifyContent:"center",fontSize:11,fontWeight:800,flexShrink:0}}>{a.rank}</div>
          <div style={{flex:1,minWidth:0}}>
            <div style={{fontSize:13,fontWeight:700,color:C.ink,overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap"}}>{a.name}</div>
            <div style={{fontSize:10.5,color:C.muted}}>{a.sub}</div>
          </div>
          <div style={{textAlign:"right",flexShrink:0}}>
            <div style={{fontSize:12.5,fontWeight:700,color:C.ink}}>{fmtDA(a.ca)}</div>
            {a.qty&&<div style={{fontSize:10,color:C.muted}}>{a.qty} qt</div>}
          </div>
        </div>
      ))}
      <div style={{display:"flex",alignItems:"center",justifyContent:"space-between",marginTop:12,paddingTop:12,borderTop:`1px solid ${C.border}`}}>
        <span style={{fontSize:11,color:C.muted}}>Total : {((total/1450)*100).toFixed(1)}% du CA</span>
        <span style={{display:"inline-flex",alignItems:"center",gap:3,fontSize:11,fontWeight:700,color:C.blue,cursor:"pointer"}}>Catalogue complet <ChevronRight size={12}/></span>
      </div>
    </Card>
  );
}


function Canaux(){
  return(
    <Card>
      <SecTitle right="Tickets">Canaux de Restauration</SecTitle>
      <div style={{fontSize:11,color:C.muted,marginTop:-8,marginBottom:14}}>Volume de tickets par type de service</div>
      {CANAUX.map((canal,i)=>(
        <div key={i} style={{marginBottom:i<CANAUX.length-1?14:0}}>
          <div style={{display:"flex",alignItems:"center",justifyContent:"space-between",marginBottom:5}}>
            <div style={{display:"flex",alignItems:"center",gap:6}}><span style={{width:9,height:9,borderRadius:2,background:canal.color,display:"inline-block",flexShrink:0}}/><span style={{fontSize:12,fontWeight:600,color:C.ink}}>{canal.label}</span></div>
            <span style={{fontSize:12,fontWeight:700,color:C.ink}}>{canal.tickets} <span style={{fontWeight:400,color:C.muted}}>({canal.pct}%)</span></span>
          </div>
          <Bar pct={canal.pct} color={canal.color}/>
        </div>
      ))}
    </Card>
  );
}

export default function StatistiquesPage(){
  const navigate=useNavigate();
  const[period,setPeriod]=React.useState("Aujourd'hui");
  const[mobile,setMobile]=React.useState(window.innerWidth<900);
  React.useEffect(()=>{const h=()=>setMobile(window.innerWidth<900);window.addEventListener("resize",h);return()=>window.removeEventListener("resize",h);},[]);
  const s=STATS[period]||STATS["Aujourd'hui"];
  const pad=mobile?"14px 14px":"24px 32px 40px";
  return(
    <div style={{minHeight:"100vh",background:C.bg,fontFamily:"'Inter',-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif",color:C.ink,display:"flex",flexDirection:"column"}}>
      <header style={{display:"flex",alignItems:"center",justifyContent:"space-between",padding:mobile?"11px 14px":"13px 32px",borderBottom:`1px solid ${C.border}`,background:C.cardBg,flexShrink:0}}>
        <div style={{display:"flex",alignItems:"center",gap:12}}>
          <button onClick={()=>navigate("/")} style={{display:"inline-flex",alignItems:"center",gap:7,fontSize:12.5,fontWeight:600,color:C.ink,background:C.cardBg,border:`1px solid ${C.border}`,borderRadius:8,padding:"7px 12px",cursor:"pointer",fontFamily:"inherit"}}>
            <ArrowLeft size={13}/>{mobile?"":"Retour au Hub"}
          </button>
          <div style={{display:"flex",alignItems:"center",gap:8}}>
            <div style={{width:28,height:28,borderRadius:"50%",background:C.brown,color:C.yellow,display:"flex",alignItems:"center",justifyContent:"center",fontSize:11,fontWeight:800}}>SK</div>
            {!mobile&&<span style={{fontSize:14,fontWeight:800,letterSpacing:"0.02em"}}>SPRINTKITCHEN</span>}
          </div>
        </div>

      </header>

      <main style={{flex:1,padding:pad,maxWidth:1340,margin:"0 auto",width:"100%",boxSizing:"border-box"}}>
        <div style={{marginBottom:18}}>
          <div style={{fontSize:10,fontWeight:700,letterSpacing:"0.06em",color:C.muted,marginBottom:4}}>PORTAIL OPERATIONNEL &bull; <span style={{color:C.green}}>RAPPORTS &amp; STATISTIQUES</span></div>
          <h1 style={{margin:"0 0 4px",color:"#583926",fontFamily:"'Bebas Neue',sans-serif",fontSize:30,fontStyle:"normal",fontWeight:400,lineHeight:"30px",letterSpacing:"0.75px"}}>RAPPORTS &amp; STATISTIQUES</h1>
          <p style={{margin:0,fontSize:12,color:C.muted}}>Performances de caisse et export comptable en direct.</p>
        </div>

        {/* Period tabs */}
        <div style={{display:"flex",gap:6,overflowX:"auto",paddingBottom:4,marginBottom:14}}>
          {PERIODS.map(p=>(
            <button key={p} onClick={()=>setPeriod(p)} style={{padding:"9px 15px",borderRadius:9,border:`1px solid ${period===p?C.brown:C.border}`,background:period===p?C.brown:C.cardBg,color:period===p?"#F5F0E6":C.ink,fontSize:12.5,fontWeight:700,cursor:"pointer",fontFamily:"inherit",whiteSpace:"nowrap",flexShrink:0}}>{p}</button>
          ))}
        </div>

        {/* Action buttons */}
        <div style={{display:"flex",flexDirection:mobile?"column":"row",gap:10,marginBottom:20}}>
          <button style={{display:"flex",alignItems:"center",justifyContent:"center",gap:10,padding:"13px 20px",borderRadius:11,border:"none",background:"#FACC15",color:"#583926",cursor:"pointer",fontFamily:"inherit",flex:mobile?undefined:1}}>
            <Printer size={15}/><span style={{color:"#583926",textAlign:"center",fontFamily:"Inter,sans-serif",fontSize:12,fontStyle:"normal",fontWeight:700,lineHeight:"16px",letterSpacing:"0.6px",textTransform:"uppercase"}}>CLÔTURE DE CAISSE</span>
          </button>
          <button style={{display:"flex",alignItems:"center",justifyContent:"center",gap:8,padding:"11px 20px",borderRadius:11,border:`1px solid ${C.border}`,background:C.cardBg,color:C.ink,fontSize:13,fontWeight:600,cursor:"pointer",fontFamily:"inherit",flexShrink:0}}>
            <Download size={14}/> Exporter (.CSV)
          </button>
        </div>

        {/* KPI cards */}
        <div style={{display:"grid",gridTemplateColumns:mobile?"1fr 1fr":"repeat(3,1fr)",gap:12,marginBottom:16}}>
          <KpiCard label="Chiffre d'Affaires" value={fmtDA(s.ca)} delta={s.caDelta} deltaUp={s.caUp} deltaLabel="vs N-1" icon={<TrendingUp size={13} color={C.green}/>}/>
          <KpiCard label="Tickets Clotures" value={s.tickets} delta={s.ticketsDelta} deltaUp={s.ticketsUp} deltaLabel="vs N-1" icon="🧾"/>
          <KpiCard label="Panier Moyen" value={fmtDA(s.panier)} delta={s.panierDelta} deltaUp={s.panierUp} deltaLabel="vs N-1" icon="🛒"/>
        </div>

        {/* Chart + content */}
        {mobile?(
          <div style={{display:"flex",flexDirection:"column",gap:14}}>
            <HourlyChart isMobile={true}/>
            <TopArticles/>
            <Canaux/>
          </div>
        ):(
          <div style={{display:"flex",flexDirection:"column",gap:16}}>
            <div style={{display:"grid",gridTemplateColumns:"1.55fr 1fr",gap:16}}>
              <HourlyChart isMobile={false}/>
              <TopArticles/>
            </div>
            <Canaux/>
          </div>
        )}
      </main>

      <footer style={{display:"flex",alignItems:"center",padding:mobile?"11px 14px":"13px 32px",borderTop:`1px solid ${C.border}`,flexShrink:0}}>
        <span style={{display:"inline-flex",alignItems:"center",gap:6,fontSize:11.5,fontWeight:600,color:C.ink}}>
          <Circle size={6} fill={C.green} color={C.green}/> Connecte
        </span>
      </footer>
    </div>
  );
}
