import type { Mail } from "./mailer.ts";

const sign = "\n\n— 哥布林營地\n（這封信是自動寄出的，請不要直接回覆。）";

export function verifyMail(to: string, name: string, link: string): Mail {
  return {
    to,
    subject: "確認你的信箱｜哥布林營地",
    text: `${name}，歡迎來到哥布林營地！\n\n請打開下面的連結確認這是你的信箱（24 小時內有效）：\n${link}\n\n如果你沒有註冊，不用理會這封信。${sign}`,
  };
}

export function alreadyRegisteredMail(to: string, loginLink: string, resetLink: string): Mail {
  return {
    to,
    subject: "有人想用你的信箱註冊｜哥布林營地",
    text: `剛剛有人想用這個信箱註冊哥布林營地，但這個信箱已經有帳號了。\n\n如果是你：直接登入就好 ${loginLink}\n忘記密碼的話：${resetLink}\n\n如果不是你，不用理會這封信，你的帳號沒有任何改變。${sign}`,
  };
}

export function resetMail(to: string, link: string): Mail {
  return {
    to,
    subject: "重新設定密碼｜哥布林營地",
    text: `請打開下面的連結設定新密碼（1 小時內有效）：\n${link}\n\n設定新密碼之後，所有裝置都會登出，需要重新登入。\n如果你沒有要求重設密碼，不用理會這封信。${sign}`,
  };
}
