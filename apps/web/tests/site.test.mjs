import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import net from "node:net";

let child;
let origin;
const limit = 15_000;
async function unusedPort() {
  return new Promise((resolve,reject)=>{
    const s=net.createServer();
    s.on("error",reject);
    s.listen(0,"127.0.0.1",()=> {const p=s.address().port;s.close(()=>resolve(p));});
  });
}
before(async()=>{
  const port=await unusedPort();
  origin="http://127.0.0.1:"+port;
  child=spawn(process.execPath,["server.mjs"],{cwd: new URL("..",import.meta.url),env:{...process.env,PORT:String(port),HOST:"127.0.0.1",SOURCE_COMMIT:"web-cache-test"},stdio:"ignore"});
  let ready=false;
  for(let i=0;i<100;i++){
    if(child.exitCode!==null)break;
    try{const r=await fetch(origin+"/api/health");if(r.ok){ready=true;break;}}catch{}
    await new Promise(done=>setTimeout(done,100));
  }
  assert.ok(ready,"DuoDeck web server must start and pass health check within 10 seconds");
},{timeout:limit});
after(()=>child?.kill("SIGTERM"));

test("health supplies actual product identity and no secrets",async()=>{
  const response=await fetch(origin+"/api/health");
  assert.equal(response.status,200);
  const body=await response.json();
  assert.equal(body.status,"ok");assert.equal(body.product,"DuoDeck");
  assert.equal(body.version,"1.1.0");assert.equal(body.commit,"web-cache-test");assert.equal("token" in body,false);
  assert.equal(response.headers.get("cache-control"),"no-store");
});
test("homepage has distinct brand and real claims",async()=>{
  const r=await fetch(origin+"/");
  assert.equal(r.status,200);
  assert.match(r.headers.get("content-type"),/text\/html/);
  const body=await r.text();
  assert.match(body,/<title>DuoDeck/);
  assert.match(body,/Control your Mac from your iPhone or iPad/);
  assert.match(body,/Get DuoDeck on both devices/);
  assert.match(body,/not a system-wide trackpad/i);
  assert.match(body,/href="\/styles\.css\?v=web-cache-test"/);
  assert.match(body,/src="\/app\.js\?v=web-cache-test"/);
  assert.equal(r.headers.get("cache-control"),"no-cache");
  assert.equal(body.includes("__ASSET_VERSION__"),false);
  assert.match(body,/github\.com\/samihalawa\/2026-CODEX-DuoDeck/);
});
test("real published icon is available",async()=>{
  const r=await fetch(origin+"/icon.png");
  assert.equal(r.status,200);
  assert.equal(r.headers.get("content-type"),"image/png");
  const b=Buffer.from(await r.arrayBuffer());
  assert.equal(b.subarray(1,4).toString(),"PNG");
});
test("web controls are real runnable JavaScript",async()=>{
  const r=await fetch(origin+"/app.js");assert.equal(r.status,200);
  const text=await r.text();
  assert.match(text,/pointermove/);
  assert.match(text,/aria-pressed/);
  assert.match(text,/sceneSelector\.addEventListener/);
});
test("visual stylesheet includes mobile and reduced-motion behavior",async()=>{
  const r=await fetch(origin+"/styles.css");assert.equal(r.status,200);
  const css=await r.text();
  assert.match(css,/@media\(max-width:560px\)/);
  assert.match(css,/@media\(prefers-reduced-motion:reduce\)/);
});
test("privacy and terms are readable, accurate and linked",async()=>{
  for(const path of ["/privacy","/terms"]){
    const r=await fetch(origin+path);assert.equal(r.status,200);
    const body=await r.text();
    assert.match(body,/DuoDeck/);
    assert.match(body,/Agents AI Ltd/);
    assert.match(body,/href="\/"/);
  }
});
test("security response headers prevent embedding and sniffing",async()=>{
  const r=await fetch(origin+"/");
  assert.equal(r.headers.get("x-frame-options"),"DENY");
  assert.equal(r.headers.get("x-content-type-options"),"nosniff");
  assert.match(r.headers.get("content-security-policy"),/frame-ancestors 'none'/);
});
test("rejects writes and unknown assets",async()=>{
  assert.equal((await fetch(origin+"/",{method:"POST"})).status,405);
  assert.equal((await fetch(origin+"/does-not-exist.js")).status,404);
});
test("HEAD requests return metadata without payload",async()=>{
  const r=await fetch(origin+"/",{method:"HEAD"});
  assert.equal(r.status,200);
  assert.equal((await r.text()).length,0);
});
test("robots and sitemap routes use correct origin",async()=>{
  const robots=await (await fetch(origin+"/robots.txt")).text();
  assert.match(robots,/duodeck\.megawebs\.com\/sitemap\.xml/);
  const sitemap=await (await fetch(origin+"/sitemap.xml")).text();
  assert.match(sitemap,/https:\/\/duodeck\.megawebs\.com\//);
});
