const DEBUG_PORT = 9228;
const OUT = "/home/philip/.claude/jobs/aac5949e/tmp/v03";
import { writeFileSync, rmSync } from "node:fs";
rmSync(`${OUT}-p3`, { recursive: true, force: true });
const proc = Bun.spawn(["brave","--headless=new",`--remote-debugging-port=${DEBUG_PORT}`,"--no-first-run","--disable-gpu",`--user-data-dir=${OUT}-p3`,"about:blank"],{stdout:"ignore",stderr:"ignore"});
async function waitForCdp(){for(let i=0;i<60;i++){try{const r=await fetch(`http://127.0.0.1:${DEBUG_PORT}/json/list`);const t=await r.json() as any[];const p=t.find(x=>x.type==="page");if(p)return p.webSocketDebuggerUrl;}catch{}await Bun.sleep(250);}throw new Error("no cdp");}
const ws=new WebSocket(await waitForCdp());await new Promise(ok=>ws.onopen=ok);
let id=0;const pend=new Map();ws.onmessage=e=>{const m=JSON.parse(String(e.data));if(m.id&&pend.has(m.id)){pend.get(m.id)(m);pend.delete(m.id);}};
const cdp=(m:string,p:object={})=>{const i=++id;ws.send(JSON.stringify({id:i,method:m,params:p}));return new Promise<any>(ok=>pend.set(i,ok));};
const js=async(x:string)=>(await cdp("Runtime.evaluate",{expression:x,awaitPromise:true,returnByValue:true})).result?.result?.value;
await cdp("Page.enable");await cdp("Runtime.enable");
await cdp("Emulation.setDeviceMetricsOverride",{width:1440,height:1100,deviceScaleFactor:1,mobile:false});
await cdp("Page.navigate",{url:"http://127.0.0.1:8491/"});await Bun.sleep(1500);
await js(`document.querySelector(".go").click()`);await Bun.sleep(1500);
const shot=async(n:string)=>{const r=await cdp("Page.captureScreenshot",{format:"png"});writeFileSync(`${OUT}/${n}.png`,Buffer.from(r.result.data,"base64"));};
await shot("15-guest-empty-library");
// open the add panel
await js(`[...document.querySelectorAll(".linklike")].find(b=>/\\+ (add|neu)/.test(b.textContent))?.click()`);await Bun.sleep(600);
await shot("16-guest-add-panel");
// pick from shelf inside add panel
await js(`document.querySelector(".shelfrow")?.click()`);await Bun.sleep(1800);
await shot("17-guest-after-shelf-add");
proc.kill();console.log("done");
