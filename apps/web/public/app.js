const scenes = Object.freeze({
  editing: [{label:"Copy",shortcut:"⌘ C"},{label:"Paste",shortcut:"⌘ V"},{label:"Undo",shortcut:"⌘ Z"},{label:"Find",shortcut:"⌘ F"},{label:"Switch apps",shortcut:"⌘ Tab"},{label:"Spotlight",shortcut:"⌘ Space"}],
  browsing: [{label:"Address",shortcut:"⌘ L"},{label:"New tab",shortcut:"⌘ T"},{label:"Reload",shortcut:"⌘ R"},{label:"Find",shortcut:"⌘ F"},{label:"Back",shortcut:"⌘ ["},{label:"Forward",shortcut:"⌘ ]"}],
  windows: [{label:"Switch apps",shortcut:"⌘ Tab"},{label:"Close",shortcut:"⌘ W"},{label:"Minimize",shortcut:"⌘ M"},{label:"Mission Control",shortcut:"⌃ ↑"},{label:"Space left",shortcut:"⌃ ←"},{label:"Space right",shortcut:"⌃ →"}],
  code: [{label:"Save",shortcut:"⌘ S"},{label:"Find",shortcut:"⌘ F"},{label:"Copy",shortcut:"⌘ C"},{label:"Undo",shortcut:"⌘ Z"},{label:"Switch apps",shortcut:"⌘ Tab"},{label:"Spotlight",shortcut:"⌘ Space"}],
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
const settings = $("previewSettings");
const modes = Array.from(document.querySelectorAll(".mode[data-mode]"));
const storageKey = "duodeck.website.preview";
let anchor = {x:.65,y:.45};
let pointerSession = null;
let statusReset;
let clickReset;
function announce(message) {
  status.textContent = message;
  clearTimeout(statusReset);
  statusReset = setTimeout(() => { status.textContent = "Preview only · no Mac connected"; }, 3200);
}
function persist() {
  try { localStorage.setItem(storageKey, JSON.stringify({mode:shell.dataset.mode,scene:sceneSelector.value,speed:Number(speedInput.value)})); } catch {}
}
function movePointer(dx,dy) {
  anchor.x = Math.max(.02,Math.min(.92,anchor.x+dx));
  anchor.y = Math.max(.03,Math.min(.82,anchor.y+dy));
  pointer.style.left = (anchor.x*100).toFixed(2)+"%";
  pointer.style.top = (anchor.y*100).toFixed(2)+"%";
}
function clickPointer() {
  pointer.classList.add("clicked");
  clearTimeout(clickReset);
  clickReset = setTimeout(()=>pointer.classList.remove("clicked"),150);
  announce("Click · preview");
}
function setMode(selected,notify=true) {
  if(!["small","medium","full"].includes(selected)) selected="small";
  shell.dataset.mode = selected;
  for(const item of modes) {
    const active = item.dataset.mode === selected;
    item.classList.toggle("active",active);
    item.setAttribute("aria-pressed",String(active));
  }
  persist();
  if(notify) announce("Trackpad size: "+selected);
}
function renderScenes() {
  const selected = scenes[sceneSelector.value] || scenes.editing;
  sceneGrid.replaceChildren();
  for(const action of selected) {
    const button = document.createElement("button");
    button.type = "button";
    button.title = action.shortcut;
    button.setAttribute("aria-label", action.label+", "+action.shortcut+", preview");
    const key = document.createElement("kbd");
    key.textContent = action.shortcut;
    key.setAttribute("aria-hidden","true");
    const label = document.createElement("span");
    label.textContent = action.label;
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
  renderScenes();
  persist();
  announce(sceneSelector.selectedOptions[0].text+" shortcuts");
});
speedInput.addEventListener("input",()=>{
  speedLabel.value=(Number(speedInput.value)/100).toFixed(2)+"×";
  persist();
});
function closeSettings() {
  settings.close();
  $("settingsOpen").focus({preventScroll:true});
}
$("settingsOpen").addEventListener("click",()=>settings.showModal());
$("settingsClose").addEventListener("click",closeSettings);
$("settingsDone").addEventListener("click",closeSettings);
settings.addEventListener("click",event=>{
  const rect=settings.getBoundingClientRect();
  if(event.target===settings && (event.clientX<rect.left || event.clientX>rect.right || event.clientY<rect.top || event.clientY>rect.bottom)) closeSettings();
});
pad.addEventListener("pointerdown",event=>{
  if(pointerSession || (event.pointerType==="mouse" && event.button!==0)) return;
  pad.setPointerCapture(event.pointerId);
  pointerSession={id:event.pointerId,x:event.clientX,y:event.clientY,distance:0};
  pad.focus({preventScroll:true});
});
pad.addEventListener("pointermove",event=>{
  if(!pointerSession || pointerSession.id!==event.pointerId) return;
  const bounds=pad.getBoundingClientRect();
  const dx=event.clientX-pointerSession.x;
  const dy=event.clientY-pointerSession.y;
  pointerSession.distance+=Math.hypot(dx,dy);
  pointerSession.x=event.clientX;
  pointerSession.y=event.clientY;
  const speed=Number(speedInput.value)/100;
  movePointer(dx/Math.max(1,bounds.width)*speed,dy/Math.max(1,bounds.height)*speed);
});
function endInteraction(event) {
  if(!pointerSession || pointerSession.id!==event.pointerId) return;
  if(event.type==="pointerup") {
    if(pointerSession.distance<8) clickPointer();
    else announce("Pointer moved · preview");
  }
  pointerSession=null;
  if(pad.hasPointerCapture(event.pointerId)) pad.releasePointerCapture(event.pointerId);
}
pad.addEventListener("pointerup",endInteraction);
pad.addEventListener("pointercancel",endInteraction);
pad.addEventListener("lostpointercapture",()=>{pointerSession=null;});
pad.addEventListener("wheel",event=>{event.preventDefault();announce("Scroll · preview");},{passive:false});
pad.addEventListener("keydown",event=>{
  const step=(event.shiftKey?.07:.025)*Number(speedInput.value)/100;
  const keys={ArrowLeft:[-step,0],ArrowRight:[step,0],ArrowUp:[0,-step],ArrowDown:[0,step]};
  if(keys[event.key]) {event.preventDefault();movePointer(...keys[event.key]);}
  if(event.key==="Enter" || event.key===" ") {event.preventDefault();clickPointer();}
});
$("resetDemo").addEventListener("click",()=>{
  anchor={x:.65,y:.45};
  speedInput.value="125";
  speedLabel.value="1.25×";
  sceneSelector.value="editing";
  setMode("small",false);
  renderScenes();
  movePointer(0,0);
  announce("Preview reset");
});
let saved;
try {saved=JSON.parse(localStorage.getItem(storageKey)||"null");} catch {}
if(saved && typeof saved==="object") {
  if(scenes[saved.scene]) sceneSelector.value=saved.scene;
  if(Number.isFinite(saved.speed) && saved.speed>=65 && saved.speed<=230) speedInput.value=String(saved.speed);
}
setMode(saved?.mode||"small",false);
speedLabel.value=(Number(speedInput.value)/100).toFixed(2)+"×";
renderScenes();
movePointer(0,0);
