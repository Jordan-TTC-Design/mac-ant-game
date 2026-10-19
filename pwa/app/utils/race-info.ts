// The races told in words, for the 種族 page (RACES.md, RACES_BEAST.md). The numbers (births, caps, lifespans) come from
// shared/src/camp/races.ts on the page itself; what is here is what no table has: what the race is like to play.

export interface BreedInfo {
  /** The breed id (a sprite sheet of the race: common, scout, brute, sage, golden). */
  id: string;
  role: string;
  name: string;
  blurb: string;
}

export interface RaceInfo {
  id: string;
  name: string;
  /** One line. */
  tagline: string;
  /** How it plays, one fact each: [label, text]. */
  traits: [string, string][];
  /** For whom (so a choice can be made). */
  suits: string;
  camp: string;
  land: string;
  princess: string;
  breeds: BreedInfo[];
  /** The camp's look (public/camps/<id>/stage1-3.png). */
  campId: string;
  /** The land: its ground tile and the things standing on it (public/terrain/<name>.png), left to right. */
  ground: string;
  props: string[];
  /** Lairs that drop the race's 信物 are in race.vue (TOKEN_FROM). */
}

export const RACE_ORDER = ["goblin", "elf", "undead", "beast"] as const;

export const RACE_INFO: Record<string, RaceInfo> = {
  goblin: {
    id: "goblin",
    name: "哥布林",
    tagline: "量多、生得快、單隻弱，靠人海取勝",
    traits: [
      ["出生", "最快：營地大約 5 分鐘生一隻，人口上限最高（營地 300 隻）。"],
      ["壽命", "標準壽命，會老死。"],
      ["食物", "十種食物的加成都照原本的算，什麼都吃，不挑。"],
      ["工作", "砍樹、挖石都行，是最好上手的種族。"],
      ["打仗", "圍毆：靠人多壓過去，單隻不強。"],
      ["白天黑夜", "沒有特別的加成或減益。"],
    ],
    suits: "第一次玩、想要穩穩擴張、喜歡堆人數和資源的人。",
    camp: "洞穴（再長大是岩洞、樹洞、帳篷）。",
    land: "草地、森林、雪地、沼澤，每個世界隨機一種。",
    princess: "人類公主。金皮哥布林會追求她，成功的話可能有混血寶寶（偏哥布林、各半、偏人類）。",
    campId: "cave",
    ground: "ground-meadow",
    props: ["tree-meadow-0", "totem-meadow", "firepit-meadow", "rack-meadow", "log-meadow"],
    breeds: [
      { id: "common", role: "平民", name: "平民", blurb: "最普通的哥布林，什麼都會一點。" },
      { id: "scout", role: "斥候", name: "敏捷", blurb: "瘦小、腿快、眼尖，但一次只拿得動一份，比較短命。" },
      { id: "brute", role: "前排", name: "壯碩", blurb: "身強體壯，走得慢，一次搬兩份，活得也久。" },
      { id: "sage", role: "支援", name: "聰明", blurb: "愛動腦筋，很會找食物，也很會叫同伴來幫忙。" },
      { id: "golden", role: "稀有隊長", name: "金皮", blurb: "罕見，每一方面都好一點，壽命兩倍，整隊加成。" },
    ],
  },
  elf: {
    id: "elf",
    name: "精靈",
    tagline: "生得慢、活得久、單隻強，和森林一起生活",
    traits: [
      ["出生", "慢：大約 10 分鐘生一隻，營地上限 180 隻。"],
      ["壽命", "兩倍以上（銀月精靈到四倍），老死很少。"],
      ["食物", "果實、野莓、蜂蜜、清水的加成 ×1.5；不吃肉，烤肉、烤魚沒有加成。"],
      ["工作", "不砍樹：改成種樹、採果實、採藥草；挖石照舊。"],
      ["打仗", "遠程：站遠一點射箭，比較少受傷。"],
      ["白天黑夜", "沒有特別的加成或減益。"],
    ],
    suits: "喜歡慢慢經營、精兵少而強、想穩穩守著家園的人。",
    camp: "樹墩、樹屋、花環與月光池。",
    land: "精靈古林：樹比一般森林多一倍、巨木、山坡台地，沒有樹樁（精靈不砍樹），晚上螢火蟲更多。",
    princess: "狐族公主。銀月精靈會追求她，寶寶是獸血精靈，偏獸的是近戰精靈，站前排。",
    campId: "stump",
    ground: "ground-elfwood",
    props: ["tree-elfwood-0", "lantern-elfwood", "mushrooms-elfwood", "fern-elfwood-0", "lantern-elfwood"],
    breeds: [
      { id: "common", role: "平民", name: "林民", blurb: "住在森林裡的精靈，會採集、會射箭，活得比哥布林久得多。" },
      { id: "scout", role: "斥候", name: "綠斗篷", blurb: "披著綠斗篷、背著弓，腳步輕、眼睛利，遠遠就看得到獵物。" },
      { id: "brute", role: "前排", name: "樹皮精靈", blurb: "高大、穿著樹皮盔甲，走得慢，一次搬兩份，站在最前面。" },
      { id: "sage", role: "支援", name: "鹿角精靈", blurb: "頂著小鹿角、留著長髮，懂得草藥，也很會叫同伴來幫忙。" },
      { id: "golden", role: "稀有隊長", name: "銀月精靈", blurb: "罕見，銀髮上戴著月亮頭環，每一方面都好一點。" },
    ],
  },
  undead: {
    id: "undead",
    name: "死靈",
    tagline: "不吃、不會老、夜晚最強，從魂魄和骨頭長出來",
    traits: [
      ["出生", "營地大約 7.5 分鐘一隻（上限 240 隻）；魂塔的靈魂之火收集魂魄長出魂系，搬回骨頭長出骨系。"],
      ["壽命", "不會老死，只會在戰鬥中倒下（受傷太重就散架）。"],
      ["食物", "不吃東西。改放帶顏色的魂魄：藍魂攻擊 +20%、綠魂回血 +50%、紫魂魂塔收集加快。"],
      ["工作", "挖石、挖骨頭，不砍樹。"],
      ["打仗", "不怕痛：受傷不回營地休息，打到散架為止。"],
      ["白天黑夜", "晚上攻擊 +30%、走路更快；白天慢一點。"],
    ],
    suits: "喜歡夜裡出擊、不想顧吃喝與壽命、愛打仗的人。",
    camp: "魂塔，中間燒著靈魂之火，周圍是墓園、骨堆。",
    land: "死靈墓地：灰黑的地面、枯樹、墓碑與石棺，偶爾飄過霧氣；晚上比別的場地暗，魂塔照亮附近。",
    princess: "精靈公主，高貴的靈魂。黑曜骨陪她在靈魂之火旁說話，默契夠深會誕生更強的「靈裔」（不會懷孕）。",
    campId: "soultower",
    ground: "ground-graveyard",
    props: ["tree-graveyard-0", "grave-graveyard-0", "bonepile-graveyard", "grave-graveyard-1", "firepit-graveyard"],
    breeds: [
      { id: "common", role: "平民", name: "骷髏", blurb: "骨系。圓圓的骷髏頭加一副細骨頭，不會老，也不吃東西。" },
      { id: "scout", role: "斥候", name: "幽影", blurb: "魂系。圓圓的小幽靈，飄著走，很快，遠遠就看得到東西。" },
      { id: "brute", role: "前排", name: "巨骨", blurb: "骨系。大一號的骷髏，頭上長角，一次搬兩份，站在最前面。" },
      { id: "sage", role: "支援", name: "鬼火", blurb: "魂系。一團圓圓的靈火，會補血，也讓魂塔收集得快一點。" },
      { id: "golden", role: "稀有隊長", name: "黑曜骨", blurb: "骨系。罕見，黑色發亮的骷髏，金骨冠、暗紅斗篷，每一方面都好一點。" },
    ],
  },
  beast: {
    id: "beast",
    name: "獸人",
    tagline: "部落與狩獵：吃肉、愛打獵，滿月的晚上狂暴",
    traits: [
      ["出生", "大約 6.5 分鐘一隻，營地上限 240 隻。"],
      ["壽命", "標準的 1.5 倍。"],
      ["食物", "烤肉、烤魚加成 ×1.5；果實、野莓、蜂蜜只有 ×0.5。"],
      ["工作", "砍樹、挖石，牛頭人一次搬得多；狼和狐會主動去追動物，打到的肉直接進食材櫃。"],
      ["打仗", "包抄：牛頭人正面擋（第一下有衝撞加成），灰狼和赤狐繞到旁邊咬，銀狐在後面補血。"],
      ["滿月", "農曆十四到十六的晚上狂暴：攻擊 +40%、走路 +15%，但受傷比較重、回營地休息比較久。新月那晚大家待在篝火旁，產出少一點。"],
    ],
    suits: "喜歡打獵與包抄、愛肉食、想在特定的夜晚爆發的人。",
    camp: "岩壁獸穴：紅岩上挖的洞，洞口掛獸頭骨，再大有狼頭圖騰柱和篝火。",
    land: "赤岩荒谷：塵土色的谷底、紅岩崖壁與石柱、乾河床，有嚎月岩（滿月時狼族站上去）、曬肉架和小水窪。",
    princess: "精靈公主。白狼王追求她，寶寶是「森之子」，偏精靈的會射箭，是獸人裡少數的遠程。",
    campId: "den",
    ground: "ground-redrock",
    props: ["pillar-redrock-0", "totem-redrock", "firepit-redrock", "rack-redrock", "oxskull-redrock", "pillar-redrock-1"],
    breeds: [
      { id: "common", role: "平民", name: "灰狼", blurb: "部落裡最多的狼族，臉上畫著戰紋，空手就很能打，愛吃肉、愛打獵。" },
      { id: "scout", role: "斥候", name: "赤狐", blurb: "紅毛狐狸，比狼小一號，圍著紅頭巾，跑得快、鼻子靈。" },
      { id: "brute", role: "前排", name: "牛頭人", blurb: "大塊頭，一對粗角、重鼻環、扛著雙刃斧，走得慢，一次搬兩份。" },
      { id: "sage", role: "支援", name: "銀狐", blurb: "年紀大的銀毛狐狸，拄著骷髏手杖，會補血，也很會叫同伴。" },
      { id: "golden", role: "稀有隊長", name: "白狼王", blurb: "罕見的白狼，骨冠、一眼帶疤、紅色獸皮披風，滿月時才拔出骨製大劍。" },
    ],
  },
};
