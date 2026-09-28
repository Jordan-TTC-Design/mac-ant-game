/**
 * The names the Mac gives its residents from their seeds (mac/Sources/GoblinCamp/Names.swift: the same lists and the same
 * steps, in 64-bit arithmetic), so a resident is called the same on the phone as on the Mac. If Names.swift changes, change
 * this with it.
 */
const sounds = ["咕", "嚕", "嘎", "啾", "噗", "嘟", "嘰", "嘿", "呱", "叭", "嗚", "嘻", "嘶", "啪", "咚", "噠", "嚓", "嗒", "咯", "哈", "嘭", "嗶", "吼", "嗡", "咻", "咔", "嚷", "嘖"];
const endings = ["牙", "耳", "鼻", "腳", "爪", "角", "尾", "肚", "眼", "毛", "骨", "皮"];
const kana = ["波", "皮", "卡", "米", "咪", "布", "比", "潘", "妮", "莉", "露", "琪", "蒂", "迪", "奇", "基", "克", "庫", "姆", "尼", "諾", "洛", "托", "塔", "達", "特", "娜", "拉", "蘭", "里", "利", "曼", "梅", "蜜", "摩", "莫", "歐", "帕", "派", "芬", "佩", "菲", "弗", "赫", "伊", "傑", "凱", "科", "朗", "雷", "索", "提", "烏", "維", "沃", "希", "西", "澤", "茲", "貝", "芭", "芙", "薇", "蕾", "艾", "亞", "雅", "奧", "可", "嘉", "咖", "圖", "多", "朵", "妲", "蕊", "娃", "溫", "威", "瓦", "芝", "吉", "姬", "奈", "豆", "果", "栗", "桃", "棗", "芋", "綠", "苔"];
const cuteSuffixes = ["醬", "君", "丸", "助", "太", "兒", "仔", "寶", "球", "糖", "豆", "泡", "丁", "喵"];
const honorifics = ["小", "老", "大", "阿", "嘟"];
const looks = ["歪", "扁", "尖", "圓", "胖", "瘦", "禿", "臭", "醜", "髒", "黏", "皺", "麻", "斑", "刺", "彎", "缺", "破", "腫", "長"];
const parts = ["牙", "耳", "鼻", "腳", "爪", "角", "尾", "肚", "眼", "毛", "骨", "皮", "舌", "膝", "指", "頭"];
const stuff = ["泥", "石", "苔", "蘑", "蟲", "蛙", "蝸", "鏽", "灰", "煙", "炭", "骨", "菇", "蕈", "根", "藤", "沼", "霧", "渣", "焦", "菌", "刺", "蜂", "霜"];
const stuffEndings = ["巴", "頭", "仔", "蛋", "包", "球", "塊", "渣", "團", "角"];
const elfStarts = ["艾", "琉", "希", "瑟", "菈", "莉", "伊", "奧", "薇", "妮", "芙", "蘭", "緹", "雅", "塞", "洛", "菲", "露", "梅", "歐", "瑪", "蕾", "茵", "黛", "卡", "蒂", "芮", "娜", "諾", "璃"];
const elfMiddles = ["菈", "瑟", "恩", "薇", "莉", "爾", "妮", "朵", "莎", "琳", "娜", "緹", "維", "蘭", "露", "伊", "希", "雅", "芙", "絲"];
const elfEnds = ["兒", "恩", "爾", "絲", "娜", "莉", "薇", "亞", "朵", "琳", "瑟", "音", "妮", "蕾", "雅"];
const elfNature = ["月", "星", "葉", "露", "霜", "風", "雲", "花", "蕨", "苔", "晨", "夜", "溪", "雪", "光", "影", "鈴", "羽", "蘚", "櫻"];
const elfNatureEnds = ["語", "歌", "影", "羽", "紋", "息", "芽", "鈴", "音", "眠", "紗", "痕", "瓣", "心"];
const boneSounds = ["咔", "啦", "喀", "噠", "嘎", "骨", "叩", "嗑", "咯", "喳"];
const soulSounds = ["幽", "冥", "朧", "魅", "霧", "嗚", "颯", "螢", "影", "寂", "夜", "燐"];
const undeadEnds = ["丸", "仔", "露", "兒", "寶", "醬", "嚕", "啾", "米", "妮"];

const M = (1n << 64n) - 1n;
/** splitmix64, as Names.mix */
function mix(x: bigint): bigint {
  let z = (x + 0x9e3779b97f4a7c15n) & M;
  z = ((z ^ (z >> 30n)) * 0xbf58476d1ce4e5b9n) & M;
  z = ((z ^ (z >> 27n)) * 0x94d049bb133111ebn) & M;
  return z ^ (z >> 31n);
}

function picker(start: bigint) {
  let h = start;
  const pick = (list: string[]) => {
    const item = list[Number(h % BigInt(list.length))]!;
    h = mix(h);
    return item;
  };
  return {
    pick,
    step: () => (h = mix(h)),
    mod: (n: number) => Number(h % BigInt(n)),
  };
}

function goblin(seed: bigint): string {
  const p = picker(mix(seed));
  const maybe = (list: string[], n = 2) => {
    const take = p.mod(n) === 0;
    p.step();
    return take ? p.pick(list) : "";
  };
  const roll = p.mod(100);
  p.step();
  if (roll < 15) {
    const name = p.pick(sounds) + p.pick(sounds);
    return p.mod(4) === 0 ? name + p.pick(endings) : name;
  }
  if (roll < 40) return p.pick(kana) + p.pick(kana) + p.pick(kana);
  if (roll < 60) return p.pick(kana) + p.pick(kana) + p.pick(cuteSuffixes);
  if (roll < 70) {
    const mixed = p.mod(2) === 0 ? p.pick(sounds) + p.pick(kana) : p.pick(kana) + p.pick(sounds);
    return mixed + maybe(cuteSuffixes);
  }
  if (roll < 80) return p.pick(honorifics) + p.pick(kana) + p.pick(kana);
  if (roll < 90) {
    const k = p.pick(kana);
    return k + k + maybe(cuteSuffixes);
  }
  if (roll < 95) return p.pick(honorifics) + p.pick(looks) + p.pick(parts);
  return p.pick(honorifics) + p.pick(stuff) + p.pick(stuffEndings);
}

function elf(seed: bigint): string {
  const p = picker(mix(seed ^ 0xe1fn));
  const roll = p.mod(100);
  p.step();
  if (roll < 45) return p.pick(elfStarts) + p.pick(elfMiddles) + p.pick(elfEnds);
  if (roll < 75) return p.pick(elfStarts) + p.pick(elfEnds);
  return p.pick(elfNature) + p.pick(elfNatureEnds);
}

function undead(seed: bigint): string {
  const p = picker(mix(seed ^ 0xdeadn));
  const roll = p.mod(100);
  p.step();
  if (roll < 30) return p.pick(boneSounds) + p.pick(boneSounds);
  if (roll < 55) {
    const s = p.pick(soulSounds);
    return s + s;
  }
  if (roll < 80) return p.pick([...boneSounds, ...soulSounds]) + p.pick(undeadEnds);
  return p.pick(soulSounds) + p.pick(boneSounds) + p.pick(undeadEnds);
}

/** A resident's name as the Mac has it: from its old 64-bit seed if it came from an old save, else its seed. */
export function residentNameFromSeed(race: string, seed: number, legacySeed?: string | null): string {
  const s = (legacySeed ? BigInt(legacySeed) : BigInt(Math.max(0, Math.floor(seed)))) & M;
  return race === "elf" ? elf(s) : race === "undead" ? undead(s) : goblin(s);
}
