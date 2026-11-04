const fs=require('fs'),path=require('path'),sharp=require('sharp'),crypto=require('crypto');
const root=__dirname;
const regions=['capital','gangwon','chungcheong','jeolla','gyeongsang','jeju','sea'];
const ids=['11j8VBX09mNxsOZbrJuhbnZ5xB1OiqAgI','1JJiElYeoHC868c84D1s7Wt1Ba0g7Tevk','1wEvmlVruzKbHbhdoDf5kDOSCrDgkiXZN','1HAvN4x_UMArhmvS2iZYlW6SmjUDwD63p','1f99xr4-DRkyZPKS4K1rKmA98nGqm4WWp','1Mw2Et6kRT-AywvdKU3yCo79Pf7mw61sd','10F0H59DnIXbQ3hV0YUlIv8q1U7hIsfXe'];
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
async function main(){const records=[],contact=[],wrap=[];
for(let k=0;k<regions.length;k++){
 const r=regions[k],file=`bg_far_${r}_winter_wide_v13_clean.png`,p=path.join(root,'clean',file);
 const source=r==='gangwon'?path.join(root,'../winter_prep/bg_far_gangwon_wide_v10_clean.png'):path.join(root,k<4?'land_three':'other_three',`${r}_v10.png`);
 const a=await sharp(p).ensureAlpha().raw().toBuffer(),sourceBytes=fs.readFileSync(source),aInfo=await sharp(p).metadata();
 let edge=0,low=0;for(let y=0;y<1536;y++)for(let c=0;c<4;c++)if(a[(y*6144)*4+c]!==a[(y*6144+6143)*4+c])edge++;
 for(let i=3;i<a.length;i+=4)if(a[i]>0&&a[i]<25)low++;
 const tiles=[];let mismatch=0;
 for(let j=0;j<3;j++){
  const name=file.replace('_clean',`_part${j+1}_clean`),tp=path.join(root,'tiles',name),d=await sharp(tp).raw().toBuffer();
  for(let y=0;y<1536;y++)if(!d.subarray(y*2048*4,(y+1)*2048*4).equals(a.subarray((y*6144+j*2048)*4,(y*6144+(j+1)*2048)*4)))mismatch++;
  tiles.push({file:name,width:2048,height:1536,sha256:hash(fs.readFileSync(tp))});
 }
 if(edge||low||mismatch||aInfo.width!==6144||aInfo.height!==1536)throw Error('QA failed '+r);
 const old=await sharp(source).resize(1536,384).png().toBuffer(),now=await sharp(p).resize(1536,384).png().toBuffer();
 const comparison=await sharp({create:{width:1536,height:800,channels:4,background:'#efe3cb'}}).composite([{input:old,left:0,top:0},{input:now,left:0,top:416}]).png().toBuffer();
 fs.writeFileSync(path.join(root,'qa',`winter_vs_v10_${r}.png`),comparison);contact.push({input:await sharp(comparison).resize(1200,625).png().toBuffer(),left:0,top:k*645});
 const right=await sharp(p).extract({left:6048,top:640,width:96,height:896}).resize(96,448).png().toBuffer(),left=await sharp(p).extract({left:0,top:640,width:96,height:896}).resize(96,448).png().toBuffer();
 const pair=await sharp({create:{width:192,height:448,channels:4,background:'#efe3cb'}}).composite([{input:right,left:0,top:0},{input:left,left:96,top:0}]).png().toBuffer();wrap.push({input:pair,left:k*208,top:0});
 const report=JSON.parse(fs.readFileSync(path.join(root,'qa',`${r}_report.json`)));
 records.push({region:r,file,width:6144,height:1536,sha256:hash(fs.readFileSync(p)),sourceDriveId:ids[k],sourceSha256:hash(sourceBytes),wrapEdgeChannelMismatch:edge,lowAlphaPixels:low,tileReassemblyMismatchRows:mismatch,seamRepair:report.seamRepair??null,iceRepair:report.iceRepair??null,tiles});
}
await sharp({create:{width:1200,height:regions.length*645,channels:4,background:'#d6cbb6'}}).composite(contact).png().toFile(path.join(root,'qa/seven_regions_comparison.png'));
await sharp({create:{width:regions.length*208,height:448,channels:4,background:'#d6cbb6'}}).composite(wrap).png().toFile(path.join(root,'qa/wrap_seam_check.png'));
fs.writeFileSync(path.join(root,'asset_manifest.json'),JSON.stringify({version:13,date:'2026-11-03',status:'still-image-and-file-QA-passed; app-review-pending',driveFolderId:'1sED8ZGGoAIjyWib_F8dxR_0WPV7vxZFi',generation:{tool:'built-in imagegen',workingCanvas:[6144,2048],generatedCanvas:[2172,724],normalizedCanvas:[6144,1536],note:'Generated raster normalized/upscaled, not native 6144px generation. Original terrain alpha restored except narrow seam repairs.'},runtimeIntegration:false,sceneConfigChanged:false,masters:records},null,2));
console.log({masters:records.length,tiles:records.reduce((n,r)=>n+r.tiles.length,0),wrapPass:true,lowAlphaPass:true,tileReassemblyPass:true});}
main().catch(e=>{console.error(e);process.exit(1)});
