PBF=PBF or {}
-- Control points of a closed Catmull-Rom loop, in metres. The first segment is the start
-- straight: the grid sits behind point 1 and the line is at s = 0. Zones are placed by `at`, a
-- fraction of the lap, because the length is only known once the spline has been resampled.
PBF.Courses={
 {
  id='vivec',name='ヴィベク・サーキット',blurb='広いコーナーが続く入門コース',laps=3,width=13,
  elevation={{0,0},{.12,0},{.24,22},{.36,8},{.5,-16},{.64,14},{.82,3},{1,0}},
  points={{200,0},{600,0},{900,60},{1100,260},{1100,560},{900,780},{600,860},{300,800},{150,950},{-100,1000},{-400,900},{-550,650},{-500,350},{-420,150},{-200,0}},
  zones={
   {kind='pad',at=0.06,len=16,d=-5,width=6},
   {kind='slip',at=0.25,len=52,d=3,width=18},
   {kind='jump',at=0.36,len=9,d=0,width=18},
   {kind='pad',at=0.44,len=16,d=5,width=6},
   {kind='heal',at=0.80,len=42,d=-8,width=5},
  },
 },
 {
  id='bruma',name='ブルーマ・ヘアピン',blurb='急カーブと連続S字の技巧派コース',laps=3,width=12,
  elevation={{0,0},{.1,5},{.22,38},{.36,12},{.5,-24},{.63,30},{.78,8},{.9,-10},{1,0}},
  points={{100,0},{500,0},{800,-40},{1000,-200},{950,-420},{700,-520},{450,-420},{400,-200},{250,-80},{0,-120},{-150,-300},{-100,-520},{-300,-640},{-600,-560},{-700,-300},{-600,-100},{-300,0}},
  zones={
   {kind='pad',at=0.05,len=16,d=0,width=7},
   {kind='rough',at=0.30,len=50,d=0,width=24},
   {kind='slip',at=0.47,len=46,d=-2,width=18},
   {kind='pad',at=0.62,len=16,d=-5,width=6},
   {kind='jump',at=0.73,len=9,d=0,width=17},
   {kind='heal',at=0.88,len=40,d=8,width=5},
  },
 },
 {
  id='solitude',name='ソリチュード・リッジ',blurb='うねる中速コーナーが連続する上級コース',laps=3,width=11,scale=.6,
  elevation={{0,0},{.1,8},{.2,42},{.31,68},{.42,24},{.54,-18},{.66,36},{.78,72},{.9,18},{1,0}},
  points={{300,0},{900,0},{1400,0},{1750,200},{1700,550},{1300,700},{900,600},{600,780},{600,1100},{900,1300},{1300,1380},{1500,1650},{1200,1900},{700,1900},{300,1700},{-100,1850},{-500,1700},{-650,1300},{-450,900},{-700,600},{-750,250},{-300,0}},
  zones={
   {kind='pad',at=0.03,len=18,d=0,width=7},
   {kind='slip',at=0.36,len=60,d=0,width=22},
   {kind='jump',at=0.47,len=10,d=0,width=16},
   {kind='pad',at=0.55,len=18,d=4,width=6},
   {kind='loop',at=0.62,len=12,d=0,width=18,distance=150,height=24},
   {kind='slip',at=0.70,len=48,d=2,width=17},
   {kind='jump',at=0.79,len=10,d=-1,width=16},
   {kind='heal',at=0.90,len=44,d=-7,width=5},
  },
 },
}
