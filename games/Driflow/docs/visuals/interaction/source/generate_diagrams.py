"""Generate original editable SVG + PNG documentation diagrams; no game screenshots are altered."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import math, html, sys

OUT=Path(sys.argv[1]) if len(sys.argv)>1 else Path(__file__).resolve().parents[1]
OUT.mkdir(parents=True,exist_ok=True)
FONT='/System/Library/Fonts/STHeiti Light.ttc'
BOLD='/System/Library/Fonts/STHeiti Medium.ttc'
C={'ink':'#142B40','muted':'#51677B','line':'#C9D6E1','bg':'#F5F8FB','white':'#FFFFFF','teal':'#087F8C','blue':'#316AC5','purple':'#7855B7','amber':'#A16A11','red':'#B44646','gray':'#687D90'}
F={'teal':'#E6F5F3','blue':'#EAF1FC','purple':'#F0EBF9','amber':'#FFF3D9','red':'#FCECEC','gray':'#EDF2F6'}
class Figure:
 def __init__(self,slug,title,subtitle,h=960):
  self.slug=slug; self.w=1440; self.h=h; self.s=2
  self.im=Image.new('RGB',(self.w*2,h*2),C['bg']); self.d=ImageDraw.Draw(self.im)
  self.svg=[f'<svg xmlns="http://www.w3.org/2000/svg" width="1440" height="{h}" viewBox="0 0 1440 {h}"><rect width="1440" height="{h}" fill="{C["bg"]}"/>']
  self.text(52,36,title,40,bold=True)
  self.text(54,96,subtitle,24,color=C['muted'],width=1330)
  self.line([(52,h-66),(1388,h-66)],C['line'],1)
  self.text(54,h-47,'DRIFLOW / INTERACTION SYSTEM',18,color=C['muted'])
  self.text(1115,h-47,'概念圖 · 2026-11-05',18,color=C['muted'])
 def font(self,n,bold=False):return ImageFont.truetype(BOLD if bold else FONT,int(n*2))
 def measure(self,t,n,bold=False):return self.d.textlength(t,font=self.font(n,bold))/2
 def wrap(self,t,n,width,bold=False):
  result=[]
  for paragraph in str(t).split('\n'):
   line=''
   for ch in paragraph:
    if self.measure(line+ch,n,bold)>width and line:result.append(line);line=ch
    else:line+=ch
   result.append(line)
  return result
 def text(self,x,y,t,n=26,color=None,bold=False,width=None,center=False):
  color=color or C['ink'];lines=self.wrap(t,n,width,bold) if width else str(t).split('\n');lh=n*1.4
  for i,line in enumerate(lines):
   px=x-self.measure(line,n,bold)/2 if center else x
   py=y+i*lh
   assert px>=0 and py+lh<self.h, (self.slug,line,px,py)
   self.d.text((int(px*2),int(py*2)),line,font=self.font(n,bold),fill=color,anchor='lt')
   self.svg.append(f'<text x="{px:.2f}" y="{py+n:.2f}" font-family="Heiti TC,STHeiti,PingFang TC,sans-serif" font-size="{n}" font-weight="{600 if bold else 400}" fill="{color}">{html.escape(line)}</text>')
  return len(lines)*lh
 def rect(self,x,y,w,h,fill=None,stroke=None,r=16):
  fill=fill or C['white'];stroke=stroke or C['line']
  self.d.rounded_rectangle((x*2,y*2,(x+w)*2,(y+h)*2),radius=r*2,fill=fill,outline=stroke,width=2)
  self.svg.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}" stroke="{stroke}"/>')
 def box(self,x,y,w,h,title,sub='',role='teal'):
  h=max(h,100 if sub else 72)
  lines=self.wrap(title,28,w-36,True); sublines=self.wrap(sub,22,w-36) if sub else []
  total=len(lines)*39+len(sublines)*31+(8 if sub else 0)
  h=max(h,total+20)
  self.rect(x,y,w,h,F[role])
  yy=y+(h-total)/2
  for line in lines:self.text(x+w/2,yy,line,28,bold=True,center=True); yy+=39
  if sub:yy+=8
  for line in sublines:self.text(x+w/2,yy,line,22,color=C['muted'],center=True); yy+=31
 def line(self,pts,color=None,width=2):
  color=color or C['line'];self.d.line([(int(x*2),int(y*2)) for x,y in pts],fill=color,width=width*2,joint='curve')
  self.svg.append('<polyline points="'+' '.join(f'{x},{y}' for x,y in pts)+f'" fill="none" stroke="{color}" stroke-width="{width}"/>')
 def arrow(self,pts,label='',at=None,role='gray'):
  self.line(pts,C[role],2); a,b=pts[-2:];angle=math.atan2(b[1]-a[1],b[0]-a[0]); sz=11
  p=[b,(b[0]-sz*math.cos(angle-.45),b[1]-sz*math.sin(angle-.45)),(b[0]-sz*math.cos(angle+.45),b[1]-sz*math.sin(angle+.45))]
  self.d.polygon([(x*2,y*2) for x,y in p],fill=C[role]);self.svg.append('<polygon points="'+' '.join(f'{x},{y}' for x,y in p)+f'" fill="{C[role]}"/>')
  if label and at:self.text(at[0],at[1],label,22,color=C['muted'])
 def circle(self,x,y,r,role='teal',fill=False,width=2):
  self.d.ellipse(((x-r)*2,(y-r)*2,(x+r)*2,(y+r)*2),fill=F[role] if fill else None,outline=C[role],width=width*2)
  self.svg.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{F[role] if fill else "none"}" stroke="{C[role]}" stroke-width="{width}"/>')
 def finish(self):
  self.im.resize((self.w,self.h),Image.Resampling.LANCZOS).save(OUT/(self.slug+'.png'))
  (OUT/(self.slug+'.svg')).write_text('\n'.join(self.svg+['</svg>']))

# 1. Runtime flow: decision and effect are separate.
f=Figure('05-interaction-flow','一次互動，從按鍵到物件反應','全域入口只決定「對誰、何時」；物件自己的訊號回呼決定「做什麼」。',1120)
f.arrow([(720,272),(720,320)])
f.arrow([(950,370),(1080,370),(1080,245)],'無有效目標',(970,333))
f.arrow([(720,420),(720,455),(335,455),(335,490)],'DIRECT',(355,425))
f.arrow([(720,420),(720,455),(1105,455),(1105,490)],'MENU',(1040,425))
f.arrow([(335,582),(335,640)])
f.arrow([(1105,582),(1105,640)])
f.arrow([(335,732),(335,765),(720,765),(720,800)])
f.arrow([(1105,732),(1105,765),(720,765),(720,800)])
f.arrow([(720,900),(720,940)])
f.box(560,190,320,82,'按 E／手把 Y','interact 動作')
f.box(490,320,460,100,'重新選擇有效目標','主角狀態 → 距離 → 優先級／最近')
f.box(1080,190,300,100,'不執行反應','沒有物件／超出範圍\n或互動已被封鎖','gray')
f.box(150,490,370,92,'直接反應','使用 direct_action_id','purple')
f.box(920,490,370,92,'開啟物件選單','顯示可用的 InteractionOption','purple')
f.box(150,640,370,92,'送出預設動作','不需要選單','amber')
f.box(920,640,370,92,'玩家選定選項','關選單 → 重新驗證狀態','amber')
f.box(500,800,440,100,'activate() 最後確認','仍在範圍、仍可用、選項仍有效')
f.box(500,940,440,80,'interacted(actor, action_id)','開門／動畫／燈光／劇情等反應','amber');f.finish()

# 2. Responsibilities and data flow.
f=Figure('06-responsibility-map','程式怎麼分工：管理器、組件、反應','箭頭表示呼叫或訊號；三個核心腳本不依賴特定角色與對話 addon。',1000)
f.arrow([(410,280),(540,280)],'主角群組',(422,240))
f.arrow([(900,280),(1030,280)],'查詢／啟動',(905,240))
f.arrow([(720,350),(720,460)],'顯示目標與選單',(745,395))
f.arrow([(540,315),(475,315),(475,520),(410,520)],'選單狀態訊號',(420,408))
f.arrow([(1200,480),(1200,350)],'選項資料',(1220,400))
f.arrow([(1370,300),(1390,300),(1390,750),(900,750)],'interacted 訊號',(1020,695))
f.box(70,210,340,140,'player.gd','群組與 can_interact() hook','blue')
f.box(540,210,360,140,'InteractionManager','單一輸入入口、選定互動目標')
f.box(1030,210,340,140,'互動物件組件','InteractableComponent\n距離、模式、可用性','purple')
f.box(70,460,340,140,'角色輸入防護','鎖住移動／跳躍，保留物理','blue')
f.box(540,460,360,140,'提示與選單 UI','Control／CanvasLayer')
f.box(1030,480,340,130,'InteractionOption','動作 ID、文字、啟用設定','purple')
f.box(540,690,360,140,'物件自己的反應腳本','範例：interaction_props.gd','amber')
f.text(70,850,'改反應 → 找物件腳本　　改距離 → 找組件　　改選目標／UI → 找管理器',26);f.finish()

# 3. Radius and overlap rules; coordinates to scale within each panel.
f=Figure('07-distance-priority','進入半徑後，究竟選哪個物件？','距離從主角根節點（腳底）算到組件位置；以下為示例，兩物件半徑皆為 100 px。',900)
for i in range(2):
 x=50+i*700
 f.rect(x,190,650,600)
 f.text(x+28,216,'同優先級：選最近' if i==0 else '優先級不同：先比優先級',30,bold=True)
 ay=460;ax=x+210;ac=x+270;bc=x+330
 f.circle(ac,ay,150,'teal',False,3 if i==0 else 1)
 f.circle(bc,ay,150,'purple',False,3 if i==1 else 1)
 f.circle(ax,ay-52,13,'blue',True)
 f.line([(ax,ay-38),(ax,ay-10),(ax-14,ay),(ax,ay-10),(ax+14,ay)],C['blue'],4)
 f.circle(ax,ay,5,'blue',True)
 f.rect(ac-10,ay-10,20,20,F['teal'],C['teal'],3)
 f.rect(bc-10,ay-10,20,20,F['purple'],C['purple'],3)
 f.text(ax-48,ay+30,'主角',24,color=C['blue'])
 f.text(ac-4,ay-50,'A',26,color=C['teal'],bold=True)
 f.text(bc-4,ay-50,'B',26,color=C['purple'],bold=True)
 f.text(x+28,650,'A：40 px／priority 0',25)
 f.text(x+28,693,'B：80 px／priority '+('0' if i==0 else '2'),25)
 f.box(x+385,657,230,85,'選 A' if i==0 else '選 B','最近' if i==0 else '高優先級優先', 'teal' if i==0 else 'purple')
f.finish()

# 4. Scene composition and file mapping.
f=Figure('08-scene-structure','場景節點與檔案：物件怎麼接進關卡','左側是節點關係；右側是要打開或編輯的檔案。省略外觀與碰撞子節點。',1040)
f.line([(100,280),(100,535),(130,535)],C['gray'])
f.line([(100,385),(130,385)],C['gray'])
f.line([(160,580),(160,685),(180,685)],C['gray'])
f.line([(210,730),(210,835),(230,835)],C['gray'])
for yy in [235,385,535,685,835]:f.arrow([(620,yy),(780,yy)])
f.box(70,190,550,90,'MotionLab (Node2D)','遊戲主場景','blue')
f.box(130,340,490,90,'女偵探 (CharacterBody2D)','由 lab.gd 在 runtime 建立','blue')
f.box(130,490,490,90,'InteractionProps','新增的場景實例')
f.box(180,640,440,90,'Cabinet (Node2D)','可互動的展示物件','amber')
f.box(230,790,390,90,'Interactable (Node2D)','物件的子節點組件','purple')
f.box(780,190,570,90,'scenes/lab.tscn','主場景新增 InteractionProps')
f.box(780,340,570,90,'scripts/player.gd','主角群組、條件與選單防護','blue')
f.box(780,490,570,90,'scenes/interaction_props.tscn','三種展示物件與 Inspector 設定')
f.box(780,640,570,90,'scripts/interaction_props.gd','具體反應，連接 interacted 訊號','amber')
f.box(780,790,570,120,'InteractableComponent.gd','options → InteractionOption 資源','purple');f.finish()

# 5. Why input guard exists.
f=Figure('09-input-guard','A 按鈕確認選單，為什麼不會順便跳躍？','GUI 消耗事件不會清除 Input 輪詢；角色控制器必須隔離關閉當幀的動作。',930)
for i,(head,gui,physics) in enumerate([
 ('選單開啟','UI 接收方向與確認','清零水平移動與跳躍緩衝\n保留重力、碰撞與姿勢更新'),
 ('按 A 確認','選定選項 → 關閉選單','額外隔離一次物理更新\n避免同一個 A 被當成 jump'),
 ('下一次正常更新','選單已關閉','恢復一般移動與跳躍\n跳躍不沿用選單確認事件')]):
 x=50+i*470
 f.text(x+200,205,head,30,bold=True,center=True)
 f.box(x,310,400,120,gui,'UI／事件路徑')
 f.box(x,510,400,170,physics,'角色／物理路徑','blue')
 if i<2:
  f.arrow([(x+400,370),(x+470,370)])
  f.arrow([(x+400,595),(x+470,595)])
 f.arrow([(x+200,430),(x+200,510)])
f.text(60,755,'實作位置：player.gd 的 menu_state_changed 回呼與 _interaction_input_guard',26)
f.text(60,805,'效果：可以確認選項，同時避免跳躍緩衝或水平移動從選單滲入遊戲。',25,color=C['muted']);f.finish()

# 6. Object lifecycle.
f=Figure('10-interaction-lifecycle','物件與選單的生命週期','可重複物件回到就緒；一次性線索在成功反應前先禁用，防止重入。',1000)
f.arrow([(380,285),(560,285)],'進入範圍',(395,240))
f.arrow([(560,315),(380,315)],'離開／失效',(390,335))
f.arrow([(880,285),(1040,285)],'MENU',(920,240))
f.arrow([(720,350),(720,460)],'DIRECT',(745,395))
f.arrow([(1190,350),(1190,510),(880,510)],'選定有效選項',(1000,450))
f.arrow([(1040,315),(960,315),(960,200),(720,200),(720,240)],'取消',(835,160))
f.arrow([(560,510),(480,510),(480,390),(620,390),(620,350)],'一般物件',(335,445))
f.arrow([(720,570),(720,700)],'單次使用：發訊號前先禁用',(760,620))
f.box(80,240,300,110,'不可互動','範圍外／停用\n或主角狀態不符','gray')
f.box(560,240,320,110,'就緒：目前目標','有效且在範圍內')
f.box(1040,240,300,110,'選單開啟','持續驗證距離與目標','purple')
f.box(560,460,320,110,'執行物件反應','發出 interacted 訊號','amber')
f.box(560,700,320,110,'已使用：禁用','外觀與存檔由回呼另處理','gray')
f.text(60,865,'任何時候刪除主角／物件／場景：關閉殘留選單並清除目標，不沿用舊參照。',26);f.finish()

# 7. Modification guide with faithful property names.
f=Figure('11-add-an-object','新增一個物件：只接四個地方','右側是欄位對照示意，並非 Godot 編輯器截圖；數值是範例。',1120)
steps=[('1  主角註冊','主角根節點加入 interaction_actor 群組'),('2  加入組件','物件下加入 Node2D\n掛上 InteractableComponent.gd'),('3  設定模式與選項','DIRECT 或 MENU\n選項使用 InteractionOption'),('4  接上具體反應','連接 interacted(actor, action_id) 訊號')]
for i,(title,sub) in enumerate(steps):
 y=210+i*190
 f.box(60,y,440,140,title,sub,'blue' if i==0 else 'purple' if i<3 else 'amber')
 if i<3:f.arrow([(280,y+140),(280,y+190)])
f.arrow([(500,660),(590,660)])
f.rect(590,210,790,770)
f.text(620,240,'InteractableComponent 欄位對照',30,bold=True)
rows=[('interaction_radius','96 px','互動半徑，世界像素'),('priority','0','同級取最近者'),('response_mode','MENU','開選單或直接反應'),('options','look / open','每個選項使用唯一 ID'),('disable_after_use','true / false','是否單次使用'),('show_prompt','true','是否顯示動作提示')]
for i,(key,value,desc) in enumerate(rows):
 y=315+i*96
 f.text(620,y,key,25,bold=True)
 f.text(1110,y,value,25,color=C['purple'])
 f.text(620,y+38,desc,23,color=C['muted'])
 if i<5:f.line([(620,y+79),(1350,y+79)])
f.text(620,915,'實際反應寫在物件腳本，不塞入管理器。',25,color=C['amber']);f.finish()

# 8. Shared platform geometry and concurrency-safe integration.
f=Figure('12-platform-data','平台調整後，互動物件為什麼仍能對齊？','以 lab.gd 的具名常數作為共同資料，避免三份程式各自保存舊座標。',960)
f.box(360,190,720,160,'scripts/lab.gd：共用平台資料','GROUND_Y = 620\nCLIMB_PLATFORM = (500, 415, 160, 20)','blue')
for cx in [250,720,1190]:f.arrow([(720,350),(720,405),(cx,405),(cx,480)])
f.box(50,480,400,190,'平台外觀與物理','lab.platform(Rect2)\n建立地板、平台與碰撞','blue')
f.box(520,480,400,190,'展示物件位置','interaction_props.gd\n櫃子在空地、線索在台面','purple')
f.box(990,480,400,190,'整合與動作測試','讀取同一份平台資料\n推算接近、落地與抓邊位置','teal')
f.text(60,730,'本次合併：先偵測到並行修改 → 保留較新平台 → 調整展示物件 → 重跑回歸。',26)
f.text(60,785,'想手動放置展示物件：關閉 InteractionProps.align_to_lab_platforms。',25,color=C['muted']);f.finish()

# 9. Verification map, with actual counts only.
f=Figure('13-verification-map','驗證分成三層，分別回答不同問題','63 項互動檢查之外，另外執行原有動作測試；不把數值通過等同正式美術驗收。',900)
data=[('42 項核心檢查','interaction_smoke.gd',['距離邊界／優先級','隱藏、禁用與單次使用','真實輸入、GUI 點擊','過期選項與場景清理'],'teal'),('21 項角色整合','driflow_interaction.gd',['女偵探操作實際物件','選單鎖住移動與跳躍','A 確認不觸發 jump','空中、懸掛、攀爬防護'],'blue'),('原有動作回歸','smoke.gd',['走跑跳蹲與原地轉身','抓邊／攀爬與動態阻擋','手掌與鞋底接觸','平台可達性與恢復走動'],'purple')]
for i,(title,script,items,role) in enumerate(data):
 x=50+i*470
 f.rect(x,220,400,440,F[role])
 f.text(x+28,250,title,31,bold=True)
 f.text(x+28,305,script,22,color=C['muted'],width=350)
 for j,item in enumerate(items):f.text(x+28,390+j*58,'• '+item,25,width=350)
 f.box(x+80,700,240,75,'PASS','',role)
f.finish()
print('Generated 9 editable SVG diagrams and 9 PNG images.')
