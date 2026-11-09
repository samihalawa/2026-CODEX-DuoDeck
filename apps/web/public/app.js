const scenes = Object.freeze({
  editing:[{label:"Copy",shortcut:"⌘ C"},{label:"Paste",shortcut:"⌘ V"},{label:"Undo",shortcut:"⌘ Z"},{label:"Find",shortcut:"⌘ F"},{label:"Switch apps",shortcut:"⌘ Tab"},{label:"Spotlight",shortcut:"⌘ Space"}],
  browsing:[{label:"Address",shortcut:"⌘ L"},{label:"New tab",shortcut:"⌘ T"},{label:"Reload",shortcut:"⌘ R"},{label:"Find",shortcut:"⌘ F"},{label:"Back",shortcut:"⌘ ["},{label:"Forward",shortcut:"⌘ ]"}],
  windows:[{label:"Switch apps",shortcut:"⌘ Tab"},{label:"Close",shortcut:"⌘ W"},{label:"Minimize",shortcut:"⌘ M"},{label:"Mission Control",shortcut:"⌃ ↑"},{label:"Space left",shortcut:"⌃ ←"},{label:"Space right",shortcut:"⌃ →"}],
  code:[{label:"Run",shortcut:"⌘ R"},{label:"Build",shortcut:"⌘ B"},{label:"Save",shortcut:"⌘ S"},{label:"Find all",shortcut:"⇧ ⌘ F"},{label:"Comment",shortcut:"⌘ /"},{label:"Next window",shortcut:"⌘ \u0060"}],
});
const $ = id => document.getElementById(id);
const shell = document.querySelector(".preview-shell");
const pad = $("demoPad");
const pointer = $("previewPointer");
const status = $("demoStatus");
const speedInput = $("speed");
const speedLabel = $("speedValue");
const sceneSelector = $("sceneSelect");
const sceneGrid = $("sceneGrid");
const shortcuts = $("shortcutDisclosure");
const settings = $("previewSettings");
const modes = Array.from(document.querySelectorAll(".mode[data-mode]"));
const tasks = Array.from(document.querySelectorAll(".demo-task"));
const storageKey = "duodeck.website.preview";
let anchor = {x:.72,y:.48};
let pointerSession = null;
let statusReset;
let clickReset;

function announce(message) {
  status.textContent=message;
  clearTimeout(statusReset);
  statusReset=setTimeout(()=>{status.textContent="Browser preview";},3500);
}
function persist() {
  try { localStorage.setItem(storageKey,JSON.stringify({mode:shell.dataset.mode,scene:sceneSelector.value,speed:Number(speedInput.value),shortcuts:shortcuts.open})); } catch {}
}
function movePointer(dx,dy) {
  anchor.x=Math.max(.01,Math.min(.92,anchor.x+dx));
  anchor.y=Math.max(.01,Math.min(.84,anchor.y+dy));
  pointer.style.left=(anchor.x*100).toFixed(2)+"%";
  pointer.style.top=(anchor.y*100).toFixed(2)+"%";
}
function clickPointer() {
  pointer.classList.add("clicked");
  clearTimeout(clickReset);
  clickReset=setTimeout(()=>pointer.classList.remove("clicked"),150);
  const rect=pointer.getBoundingClientRect();
  const target=document.elementFromPoint(rect.left+4,rect.top+3)?.closest(".demo-task");
  if(target) target.click();
  else announce("Click");
}
tasks.forEach(task=>task.addEventListener("click",()=>{
  const checked=task.getAttribute("aria-checked")!=="true";
  task.setAttribute("aria-checked",String(checked));
  announce(task.textContent.trim()+(checked?" — checked":" — unchecked"));
}));
function setMode(selected,notify=true) {
  if(!["small","medium","full"].includes(selected)) selected="small";
  shell.dataset.mode=selected;
  for(const item of modes) {
    const active=item.dataset.mode===selected;
    item.classList.toggle("active",active);
    item.setAttribute("aria-pressed",String(active));
  }
  $("trackpadSizeLabel").textContent=selected[0].toUpperCase()+selected.slice(1);
  persist();
  if(notify) announce("Trackpad size: "+selected);
}
function renderScenes() {
  const selected=scenes[sceneSelector.value]||scenes.editing;
  sceneGrid.replaceChildren();
  for(const action of selected) {
    const button=document.createElement("button");
    button.type="button";
    button.title=action.shortcut;
    button.setAttribute("aria-label",action.label+", "+action.shortcut+", preview");
    const key=document.createElement("kbd");
    key.textContent=action.shortcut;
    key.setAttribute("aria-hidden","true");
    const label=document.createElement("span");
    label.textContent=action.label;
    button.append(key,label);
    button.addEventListener("click",()=>{
      announce(action.label+" · "+action.shortcut+" · preview");
      button.classList.add("action-flash");
      setTimeout(()=>button.classList.remove("action-flash"),180);
    });
    sceneGrid.append(button);
  }
}
modes.forEach(control=>control.addEventListener("click",()=>setMode(control.dataset.mode)));
sceneSelector.addEventListener("change",()=>{
  renderScenes();persist();
  announce(sceneSelector.selectedOptions[0].text+" shortcuts");
});
shortcuts.addEventListener("toggle",persist);
speedInput.addEventListener("input",()=>{
  speedLabel.value=(Number(speedInput.value)/100).toFixed(2)+"×";persist();
});
$("settingsOpen").addEventListener("click",()=>settings.showModal());
$("settingsClose").addEventListener("click",()=>settings.close());
$("settingsDone").addEventListener("click",()=>settings.close());
settings.addEventListener("close",()=>$("settingsOpen").focus({preventScroll:true}));
settings.addEventListener("click",event=>{
  const rect=settings.getBoundingClientRect();
  if(event.target===settings&&(event.clientX<rect.left||event.clientX>rect.right||event.clientY<rect.top||event.clientY>rect.bottom)) settings.close();
});
pad.addEventListener("pointerdown",event=>{
  if(pointerSession||(event.pointerType==="mouse"&&event.button!==0)) return;
  pad.setPointerCapture(event.pointerId);
  pointerSession={id:event.pointerId,x:event.clientX,y:event.clientY,distance:0};
  pad.focus({preventScroll:true});
});
pad.addEventListener("pointermove",event=>{
  if(!pointerSession||pointerSession.id!==event.pointerId)return;
  const bounds=pad.getBoundingClientRect();
  const dx=event.clientX-pointerSession.x;
  const dy=event.clientY-pointerSession.y;
  pointerSession.distance+=Math.hypot(dx,dy);
  pointerSession.x=event.clientX;pointerSession.y=event.clientY;
  const speed=Number(speedInput.value)/100;
  movePointer(dx/Math.max(1,bounds.width)*speed,dy/Math.max(1,bounds.height)*speed);
});
function endInteraction(event) {
  if(!pointerSession||pointerSession.id!==event.pointerId)return;
  if(event.type==="pointerup"){
    if(pointerSession.distance<8)clickPointer();
    else announce("Pointer moved");
  }
  pointerSession=null;
  if(pad.hasPointerCapture(event.pointerId))pad.releasePointerCapture(event.pointerId);
}
pad.addEventListener("pointerup",endInteraction);
pad.addEventListener("pointercancel",endInteraction);
pad.addEventListener("lostpointercapture",()=>{pointerSession=null;});
pad.addEventListener("wheel",event=>{event.preventDefault();announce("Scroll · preview");},{passive:false});
pad.addEventListener("keydown",event=>{
  const step=(event.shiftKey?.07:.025)*Number(speedInput.value)/100;
  const keys={ArrowLeft:[-step,0],ArrowRight:[step,0],ArrowUp:[0,-step],ArrowDown:[0,step]};
  if(keys[event.key]){event.preventDefault();movePointer(...keys[event.key]);}
  if(event.key==="Enter"||event.key===" "){event.preventDefault();clickPointer();}
});
$("resetDemo").addEventListener("click",()=>{
  anchor={x:.72,y:.48};speedInput.value="125";speedLabel.value="1.25×";
  sceneSelector.value="editing";shortcuts.open=false;
  tasks.forEach((task,index)=>task.setAttribute("aria-checked",String(index===0)));
  setMode("small",false);renderScenes();movePointer(0,0);announce("Preview reset");
});
let saved;
try{saved=JSON.parse(localStorage.getItem(storageKey)||"null");}catch{}
if(saved&&typeof saved==="object"){
  if(scenes[saved.scene])sceneSelector.value=saved.scene;
  if(Number.isFinite(saved.speed)&&saved.speed>=65&&saved.speed<=230)speedInput.value=String(saved.speed);
  shortcuts.open=saved.shortcuts===true;
}
setMode(saved?.mode||"small",false);
speedLabel.value=(Number(speedInput.value)/100).toFixed(2)+"×";
renderScenes();movePointer(0,0);

let downloadRefreshTimer;
async function refreshDownloads(){
  clearTimeout(downloadRefreshTimer);
  const link=$("macDownload");
  try{
    const response=await fetch("/api/downloads",{cache:"no-store"});
    if(!response.ok)return;
    const {mac}=await response.json();
    const expected="https://github.com/samihalawa/2026-CODEX-DuoDeck/releases/latest/download/DuoDeck-Host-macOS.dmg";
    if(mac?.available&&mac.url===expected){
      link.href=expected;link.removeAttribute("aria-disabled");link.removeAttribute("tabindex");
      link.textContent="Download for Mac";
      $("macDownloadStatus").textContent="Signed and notarized Mac companion.";
    }else if(mac?.available===false){
      link.removeAttribute("href");link.setAttribute("aria-disabled","true");link.setAttribute("tabindex","-1");
      link.textContent="Mac download coming soon";
      $("macDownloadStatus").textContent="The Mac download is being prepared.";
    }
  }catch{ /* Keep the current availability and retry while the page is visible. */ }
  finally{
    if(link.hasAttribute("aria-disabled")&&!document.hidden)downloadRefreshTimer=setTimeout(refreshDownloads,65_000);
  }
}
refreshDownloads();
document.addEventListener("visibilitychange",()=>{
  clearTimeout(downloadRefreshTimer);
  if(!document.hidden)refreshDownloads();
});
