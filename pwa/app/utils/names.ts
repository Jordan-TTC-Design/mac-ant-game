/**
 * A name for the resident on a new note, in the style of the account's race (the Mac's Names.swift, picked at random here:
 * a note's name is chosen once and synced, so it does not need to come from a seed).
 */
const pick = (list: readonly string[]) => list[Math.floor(Math.random() * list.length)]!;
const chars = (s: string) => [...s];

const goblin = {
  sounds: chars("咕嚕嘎啾噗嘟嘰嘿呱叭嗚嘻嘶啪咚噠嚓嗒咯哈嘭嗶吼嗡咻咔嚷嘖"),
  endings: chars("牙耳鼻腳爪角尾肚眼毛骨皮"),
  kana: chars("波皮卡米咪布比潘妮莉露琪蒂迪奇基克庫姆尼諾洛托塔達特娜拉蘭里利曼梅蜜摩莫歐帕派芬佩菲弗赫伊傑凱科朗雷索提烏維沃希西澤茲貝芭芙薇蕾艾亞雅奧可嘉咖圖多朵妲蕊娃溫威瓦芝吉姬奈豆果栗桃棗芋綠苔"),
  cute: chars("醬君丸助太兒仔寶球糖豆泡丁喵"),
  honorifics: chars("小老大阿嘟"),
};
const elf = {
  starts: chars("艾琉希瑟菈莉伊奧薇妮芙蘭緹雅塞洛菲露梅歐瑪蕾茵黛卡蒂芮娜諾璃"),
  middles: chars("菈瑟恩薇莉爾妮朵莎琳娜緹維蘭露伊希雅芙絲"),
  ends: chars("兒恩爾絲娜莉薇亞朵琳瑟音妮蕾雅"),
  nature: chars("月星葉露霜風雲花蕨苔晨夜溪雪光影鈴羽蘚櫻"),
  natureEnds: chars("語歌影羽紋息芽鈴音眠紗痕瓣心"),
};
const undead = {
  bone: chars("咔啦喀噠嘎骨叩嗑咯喳"),
  soul: chars("幽冥朧魅霧嗚颯螢影寂夜燐"),
  ends: chars("丸仔露兒寶醬嚕啾米妮"),
};

export function residentName(race: string): string {
  const roll = Math.random() * 100;
  if (race === "elf") {
    if (roll < 45) return pick(elf.starts) + pick(elf.middles) + pick(elf.ends);
    if (roll < 75) return pick(elf.starts) + pick(elf.ends);
    return pick(elf.nature) + pick(elf.natureEnds);
  }
  if (race === "undead") {
    if (roll < 30) return pick(undead.bone) + pick(undead.bone);
    if (roll < 55) {
      const s = pick(undead.soul);
      return s + s;
    }
    if (roll < 80) return pick([...undead.bone, ...undead.soul]) + pick(undead.ends);
    return pick(undead.soul) + pick(undead.bone) + pick(undead.ends);
  }
  if (roll < 20) return pick(goblin.sounds) + pick(goblin.sounds) + (Math.random() < 0.25 ? pick(goblin.endings) : "");
  if (roll < 45) return pick(goblin.kana) + pick(goblin.kana) + pick(goblin.kana);
  if (roll < 70) return pick(goblin.kana) + pick(goblin.kana) + pick(goblin.cute);
  if (roll < 85) return pick(goblin.honorifics) + pick(goblin.kana) + pick(goblin.kana);
  const k = pick(goblin.kana);
  return k + k + (Math.random() < 0.5 ? pick(goblin.cute) : "");
}
