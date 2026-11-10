import http from "node:http";
import { readFile, stat } from "node:fs/promises";
import { dirname, extname, join, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "public");
const port = Number(process.env.PORT || 3000);
const host = process.env.HOST || "0.0.0.0";
const version = process.env.DUODECK_VERSION || "1.1.0";
const commit = process.env.SOURCE_COMMIT || process.env.GIT_COMMIT_SHA || "unpublished";
const assetVersion = encodeURIComponent(commit === "unpublished" ? version : commit);
const mime = Object.freeze({
  ".html":"text/html; charset=utf-8",".css":"text/css; charset=utf-8",".js":"text/javascript; charset=utf-8",
  ".png":"image/png",".svg":"image/svg+xml",".webp":"image/webp",".ico":"image/x-icon",
  ".woff2":"font/woff2",".txt":"text/plain; charset=utf-8",".xml":"application/xml; charset=utf-8",
});
const route = Object.freeze({"/":"/index.html","/privacy":"/privacy.html","/terms":"/terms.html"});
const errorPage = '<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Not found · DuoDeck</title><body style="background:#ffffff;color:#0b0d12;font:16px system-ui;margin:12vh auto;max-width:640px;padding:1.5em"><h1>That page could not be found.</h1><p>Return to <a style="color:#2f55e4" href="/">DuoDeck</a>.</p></body></html>';
function security(res) {
  res.setHeader("X-Content-Type-Options","nosniff");
  res.setHeader("Referrer-Policy","strict-origin-when-cross-origin");
  res.setHeader("X-Frame-Options","DENY");
  res.setHeader("Permissions-Policy","camera=(), microphone=(), geolocation=()");
  res.setHeader("Content-Security-Policy","default-src 'self'; script-src 'self'; style-src 'self'; font-src 'self'; img-src 'self' data:; connect-src 'self'; object-src 'none'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'");
}
const macDownloadURL = "https://github.com/samihalawa/2026-CODEX-DuoDeck/releases/latest/download/DuoDeck-Host-macOS.dmg";
let downloadState = {status:"unknown",checkedAt:0,confirmedAt:0};
let downloadCheck;
async function currentDownloads() {
  const ttl = downloadState.status==="available" ? 300_000 : 60_000;
  if(Date.now()-downloadState.checkedAt >= ttl && !downloadCheck) {
    downloadCheck = (async()=>{
      try {
        const response = await fetch(macDownloadURL,{method:"HEAD",redirect:"follow",signal:AbortSignal.timeout(6000)});
        if(response.status===200 || response.status===404) {
          downloadState.status=response.status===200?"available":"pending";
          downloadState.confirmedAt=Date.now();
        }
      } catch { /* A failed lookup is neither a missing release nor a confirmed download. */ }
      downloadState.checkedAt=Date.now();
    })().finally(()=>{downloadCheck=undefined;});
  }
  if(downloadCheck) await downloadCheck;
  const status=Date.now()-downloadState.confirmedAt<600_000?downloadState.status:"unknown";
  const available=status==="available";
  return {mac:{available,url:available?macDownloadURL:null,status}};
}
const app = http.createServer(async (req,res)=>{
  security(res);
  if(req.method !== "GET" && req.method !== "HEAD") {
    res.writeHead(405,{"Allow":"GET, HEAD"});res.end();return;
  }
  let pathname;
  try{pathname=new URL(req.url || "/", "https://duodeck.megawebs.com").pathname;}catch{res.writeHead(400);res.end();return;}
  if(pathname==="/api/downloads"){
    const downloads=await currentDownloads();
    res.writeHead(200,{"Content-Type":"application/json; charset=utf-8","Cache-Control":"no-store"});
    res.end(req.method==="HEAD"?undefined:JSON.stringify(downloads));return;
  }
  if(pathname==="/api/health"){
    res.writeHead(200,{"Content-Type":"application/json; charset=utf-8","Cache-Control":"no-store"});
    if(req.method!=="HEAD")res.end(JSON.stringify({status:"ok",product:"DuoDeck",version,commit}));
    else res.end();
    return;
  }
  if(pathname==="/robots.txt"){
    res.writeHead(200,{"Content-Type":"text/plain; charset=utf-8"});
    res.end(req.method==="HEAD"?"":"User-agent: *\nAllow: /\nSitemap: https://duodeck.megawebs.com/sitemap.xml\n");return;
  }
  if(pathname==="/sitemap.xml"){
    res.writeHead(200,{"Content-Type":"application/xml; charset=utf-8"});
    res.end(req.method==="HEAD"?"":'<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"><url><loc>https://duodeck.megawebs.com/</loc></url><url><loc>https://duodeck.megawebs.com/privacy</loc></url><url><loc>https://duodeck.megawebs.com/terms</loc></url></urlset>');return;
  }
  const mapped = route[pathname] ?? pathname;
  if(mapped.includes("\0")||mapped.includes("\\")||mapped.includes("//")||mapped.split("/").includes("..")){
    res.writeHead(400);res.end();return;
  }
  const full=resolve(root, "." + mapped);
  if(full!==root && !full.startsWith(root+sep)){
    res.writeHead(403);res.end();return;
  }
  try{
    const info=await stat(full);
    if(!info.isFile())throw new Error("not a file");
    let data=await readFile(full);
    if(full.endsWith(".html")) data=Buffer.from(data.toString("utf8").replaceAll("__ASSET_VERSION__",assetVersion));
    res.writeHead(200,{
      "Content-Type":mime[extname(full)] ?? "application/octet-stream",
      "Content-Length":data.byteLength,
      "Cache-Control":full.endsWith(".html")?"no-cache":"public, max-age=3600",
    });
    res.end(req.method==="HEAD" ? undefined:data);
  }catch {
    res.writeHead(404,{"Content-Type":"text/html; charset=utf-8"});
    res.end(req.method==="HEAD" ? undefined:errorPage);
  }
});
app.listen(port,host,()=>console.log(JSON.stringify({event:"duodeck-site-listening",host,port,version})));
const shutdown=()=>app.close(()=>process.exit(0));
process.on("SIGINT",shutdown);process.on("SIGTERM",shutdown);
