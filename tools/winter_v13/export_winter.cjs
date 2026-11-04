// 규격 정리 전용. 눈과 겨울 그림은 imagegen 편집 결과를 사용한다.
const fs=require('fs'),path=require('path'),sharp=require('sharp');
const root=__dirname;
async function exportOne(region,source,edited){
 const {data:o,info:oi}=await sharp(source).ensureAlpha().raw().toBuffer({resolveWithObject:true});
 if(oi.width!==6144||oi.height!==1536)throw Error('Unexpected original canvas');
 const gm=await sharp(edited).metadata();
 if(Math.abs(gm.width/gm.height-3)>.01)throw Error('Generated working canvas must be 3:1');
 const {data:g}=await sharp(edited).resize(6144,2048,{fit:'fill'}).extract({left:0,top:256,width:6144,height:1536}).ensureAlpha().raw().toBuffer({resolveWithObject:true});
 const out=Buffer.alloc(o.length);let restored=0,interior=0;const deltas=[];
 for(let x=0;x<6144;x++){
  let a=-1,b=-1;
  for(let y=0;y<1536;y++){
   const i=(y*6144+x)*4,oa=o[i+3],ga=g[i+3];
   if(a<0&&oa>=128)a=y;if(b<0&&ga>=128)b=y;
   if(oa>=250){interior++;if(ga<20)restored++;}
   // 원본 외곽/알파를 복원하고 눈에 보이지 않는 알파 먼지만 제거한다.
   const alpha=oa<25?0:oa>=250?255:oa;
   out[i+3]=alpha;
   if(alpha){const w=ga/255;for(let c=0;c<3;c++)out[i+c]=Math.round(g[i+c]*w+o[i+c]*(1-w));}
  }
  if(a>=0&&b>=0)deltas.push(Math.abs(a-b));
 }
 if(restored/interior>.002)throw Error('Too many transparent gaps inside source terrain');
 deltas.sort((a,b)=>a-b);
 // 반복 경계의 RGB만 연결한다. 외곽 알파는 유지한다.
 const edge=64;
 for(let y=0;y<1536;y++)for(let x=0;x<edge;x++){
  const l=(y*6144+x)*4,r=(y*6144+6143-x)*4,w=(1-x/(edge-1))**2;
  for(let c=0;c<3;c++){const a=out[l+c],b=out[r+c],mean=(a+b)/2;out[l+c]=Math.round(a*(1-w)+mean*w);out[r+c]=Math.round(b*(1-w)+mean*w);}
  if(!out[l+3])out[l]=out[l+1]=out[l+2]=0;
  if(!out[r+3])out[r]=out[r+1]=out[r+2]=0;
 }
 const file=`bg_far_${region}_winter_wide_v13_clean.png`;
 const target=path.join(root,'clean',file);
 await sharp(out,{raw:{width:6144,height:1536,channels:4}}).toColourspace('srgb').png().toFile(target);
 const tiles=[];
 for(let j=0;j<3;j++){
  const f=file.replace('_clean',`_part${j+1}_clean`);tiles.push(f);
  await sharp(target).extract({left:j*2048,top:0,width:2048,height:1536}).png().toFile(path.join(root,'tiles',f));
 }
 const bg=await sharp(source).resize(1536,384).png().toBuffer(),wg=await sharp(target).resize(1536,384).png().toBuffer();
 await sharp({create:{width:1536,height:800,channels:4,background:'#efe3cb'}}).composite([{input:bg,left:0,top:0},{input:wg,left:0,top:416}]).png().toFile(path.join(root,'qa',`winter_vs_v10_${region}.png`));
 let alphaMismatch=0,edgeMismatch=0,low=0;
 for(let i=0;i<o.length;i+=4){const expected=o[i+3]<25?0:o[i+3]>=250?255:o[i+3];if(expected!==out[i+3])alphaMismatch++;if(out[i+3]>0&&out[i+3]<25)low++;}
 for(let y=0;y<1536;y++)for(let c=0;c<4;c++)if(out[(y*6144)*4+c]!==out[(y*6144+6143)*4+c])edgeMismatch++;
 const tileBuffers=await Promise.all(tiles.map(f=>sharp(path.join(root,'tiles',f)).raw().toBuffer()));
 let tileMismatch=0;for(let y=0;y<1536;y++)for(let j=0;j<3;j++){const row=tileBuffers[j].subarray(y*2048*4,(y+1)*2048*4);if(!row.equals(out.subarray((y*6144+j*2048)*4,(y*6144+(j+1)*2048)*4)))tileMismatch++;}
 const report={region,file,tiles,source:path.basename(source),generated:path.basename(edited),generatedSize:[gm.width,gm.height],exportSize:[6144,1536],originalAlphaMismatch:alphaMismatch,lowAlphaPixels:low,wrapEdgeChannelMismatch:edgeMismatch,tilesReassemblyMismatchRows:tileMismatch,sourceBoundaryFallbackPixels:restored,fallbackRatio:restored/interior,generatedContourBeforeNormalization:{medianPx:deltas[Math.floor(deltas.length*.5)],p95Px:deltas[Math.floor(deltas.length*.95)]},normalization:'3:1 padded source: remove 256px vertical pads after resize; original silhouette/alpha restored; RGB wrap band64px. No code-painted snow.',appRuntimeVerified:false};
 fs.writeFileSync(path.join(root,'qa',`${region}_report.json`),JSON.stringify(report,null,2));return report;
}
module.exports={exportOne};
if(require.main===module){exportOne(...process.argv.slice(2)).then(r=>console.log(JSON.stringify(r))).catch(e=>{console.error(e);process.exit(1)});}
