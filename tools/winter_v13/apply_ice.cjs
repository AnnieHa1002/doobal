// imagegen의 얼음 그림을 담수 마스크 안에만 합성한다. 육지·외곽 알파 보존.
const fs=require('fs'),path=require('path'),sharp=require('sharp');
const root=__dirname,W=6144,H=1536;
async function main(region,generated){
 const before=path.join(root,'ice_fix',`${region}_before.png`);
 const a=await sharp(before).ensureAlpha().raw().toBuffer();
 const gm=await sharp(generated).metadata();
 const b=await sharp(generated).resize(W,2048,{fit:'fill'}).extract({left:0,top:256,width:W,height:H}).ensureAlpha().raw().toBuffer();
 const flags=new Uint8Array(W*H),mask=Buffer.alloc(W*H),queue=new Int32Array(W*H);
 for(let y=750;y<H;y++)for(let x=0;x<W;x++){const i=(y*W+x)*4;flags[y*W+x]=a[i+2]-a[i]>10&&a[i+1]-a[i]>3&&a[i+2]-a[i+1]>=-4&&a[i+3]===255?1:0;}
 const selected=[];
 for(let z=750*W;z<flags.length;z++){
  if(flags[z]!==1)continue;
  let n=1,j=0,miny=H,maxy=0;queue[0]=z;flags[z]=2;
  while(j<n){const k=queue[j++],x=k%W,y=Math.floor(k/W);miny=Math.min(miny,y);maxy=Math.max(maxy,y);
   for(const v of [k-W,k+W,x?k-1:-1,x<W-1?k+1:-1])if(v>=0&&v<flags.length&&flags[v]===1){flags[v]=2;queue[n++]=v;}}
  const keep=n>100&&(region==='chungcheong'?miny>=820&&maxy>=900&&miny<1220:region==='jeolla'?miny>=1020:miny>=940);
  if(keep){for(let k=0;k<n;k++)mask[queue[k]]=255;selected.push({pixels:n,miny,maxy});}
 }
 // 물 위의 가는 밝은 선 틈을 메우고 강가에서 2px 정도만 부드럽게 합성한다.
 const soft=await sharp(mask,{raw:{width:W,height:H,channels:1}}).dilate(3).blur(1).greyscale().raw().toBuffer();
 if(soft.length!==W*H)throw Error('Water mask must have one channel');
 const out=Buffer.from(a);let changed=0,waterPixels=0,outsideChanged=0,alphaChanged=0;
 for(let p=0;p<W*H;p++){const i=p*4,w=soft[p]/255;if(w&&a[i+3]){waterPixels++;for(let c=0;c<3;c++)out[i+c]=Math.round(a[i+c]*(1-w)+b[i+c]*w);}if(out[i]!==a[i]||out[i+1]!==a[i+1]||out[i+2]!==a[i+2]){changed++;if(!soft[p])outsideChanged++;}if(out[i+3]!==a[i+3])alphaChanged++;}
 // 기존 반복 양끝에 한해 생성 RGB의 좌우 차이를 해소한다.
 for(let y=0;y<H;y++)for(let x=0;x<64;x++){const l=(y*W+x)*4,r=(y*W+W-1-x)*4,w=(1-x/63)**2;for(let c=0;c<3;c++){const av=(out[l+c]+out[r+c])/2;out[l+c]=Math.round(out[l+c]*(1-w)+av*w);out[r+c]=Math.round(out[r+c]*(1-w)+av*w);}}
 const file=`bg_far_${region}_winter_wide_v13_clean.png`,target=path.join(root,'clean',file);
 await sharp(out,{raw:{width:W,height:H,channels:4}}).toColourspace('srgb').png().toFile(target);
 for(let j=0;j<3;j++)await sharp(target).extract({left:j*2048,top:0,width:2048,height:H}).png().toFile(path.join(root,'tiles',file.replace('_clean',`_part${j+1}_clean`)));
 await sharp(mask,{raw:{width:W,height:H,channels:1}}).png().toFile(path.join(root,'ice_fix',`${region}_water_mask.png`));
 const prev=await sharp(before).resize(1536,384).png().toBuffer(),next=await sharp(target).resize(1536,384).png().toBuffer();
 await sharp({create:{width:1536,height:800,channels:4,background:'#efe3cb'}}).composite([{input:prev,left:0,top:0},{input:next,left:0,top:416}]).png().toFile(path.join(root,'qa',`ice_before_after_${region}.png`));
 const rp=path.join(root,'qa',`${region}_report.json`),report=JSON.parse(fs.readFileSync(rp));report.iceRepair={generated:path.basename(generated),generatedSize:[gm.width,gm.height],selectedWaterComponents:selected,maskedPixels:waterPixels,changedPixels:changed,alphaChanged,outsideWaterMaskChangedBeforeWrap:outsideChanged,method:'imagegen freshwater ice; blue-water components only, banks feathered 2px; original alpha; sea horizon in jeolla excluded; final 64px outer wrap normalization'};fs.writeFileSync(rp,JSON.stringify(report,null,2));
 console.log({region,...report.iceRepair});
}
if(require.main===module)main(...process.argv.slice(2)).catch(e=>{console.error(e);process.exit(1)});
