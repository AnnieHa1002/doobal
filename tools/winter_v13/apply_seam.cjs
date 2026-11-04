// imagegen 연결부 편집을 x3950..4249 안에만 적용하고 그 밖의 픽셀은 보존한다.
const sharp=require('sharp'),fs=require('fs'),path=require('path');
const root=__dirname;
async function fix(region,input){
 const file=`bg_far_${region}_winter_wide_v13_clean.png`,master=path.join(root,'clean',file);
 const {data:a}=await sharp(master).ensureAlpha().raw().toBuffer({resolveWithObject:true});
 const before=Buffer.from(a);
 const {data:b}=await sharp(input).resize(1024,1536).ensureAlpha().raw().toBuffer({resolveWithObject:true});
 let alphaChanges=0;
 for(let x=3950;x<4250;x++){
  const local=x-3588;let oldTop=1536,newTop=1536;
  for(let y=0;y<1536;y++){if(oldTop===1536&&a[(y*6144+x)*4+3]>=128)oldTop=y;if(newTop===1536&&b[(y*1024+local)*4+3]>=250)newTop=y;}
  if(Math.abs(oldTop-newTop)>24)throw Error('Unexpected skyline shift in seam repair');
  const fade=Math.min(1,(x-3950)/24,(4249-x)/24);
  for(let y=0;y<1536;y++){
   const i=(y*6144+x)*4,j=(y*1024+local)*4,pa=y>=newTop?255:y===newTop-1?128:0;
   for(let c=0;c<3;c++)a[i+c]=Math.round(a[i+c]*(1-fade)+b[j+c]*fade);
   let aa=Math.round(a[i+3]*(1-fade)+pa*fade);if(aa<25)aa=0;if(aa>=250)aa=255;
   if(aa!==a[i+3])alphaChanges++;a[i+3]=aa;if(!aa)a[i]=a[i+1]=a[i+2]=0;
  }
 }
 let outsideChanges=0;for(let y=0;y<1536;y++)for(let x=0;x<6144;x++)if(x<3950||x>=4250){const i=(y*6144+x)*4;for(let c=0;c<4;c++)if(a[i+c]!==before[i+c])outsideChanges++;}
 if(outsideChanges)throw Error('Out-of-range edit');
 await sharp(a,{raw:{width:6144,height:1536,channels:4}}).png().toFile(master+'.tmp.png');fs.renameSync(master+'.tmp.png',master);
 for(let j=0;j<3;j++)await sharp(master).extract({left:j*2048,top:0,width:2048,height:1536}).png().toFile(path.join(root,'tiles',file.replace('_clean',`_part${j+1}_clean`)));
 const bp=await sharp(before,{raw:{width:6144,height:1536,channels:4}}).extract({left:3588,top:0,width:1024,height:1536}).resize(512,768).png().toBuffer();
 const ap=await sharp(master).extract({left:3588,top:0,width:1024,height:1536}).resize(512,768).png().toBuffer();
 await sharp({create:{width:1040,height:768,channels:4,background:'#efe3cb'}}).composite([{input:bp,left:0,top:0},{input:ap,left:528,top:0}]).png().toFile(path.join(root,'qa',`seam_fix_${region}.png`));
 const reportPath=path.join(root,'qa',`${region}_report.json`),report=JSON.parse(fs.readFileSync(reportPath));
 report.seamRepair={range:[3950,4250],outsideChangedChannels:outsideChanges,alphaChangedInsideRange:alphaChanges,method:'imagegen context edit; narrowly masked placement; remove generated sky haze outside terrain'};
 report.originalAlphaMismatch=alphaChanges;
 fs.writeFileSync(reportPath,JSON.stringify(report,null,2));console.log(report.seamRepair);
}
fix(...process.argv.slice(2)).catch(e=>{console.error(e);process.exit(1)});
