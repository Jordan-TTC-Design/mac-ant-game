export interface Mail {
  to: string;
  subject: string;
  text: string;
}

/** Sends email. Development prints it; the real one (Resend) comes with deployment (DESIGN.md §9). */
export interface Mailer {
  send(mail: Mail): Promise<void>;
}

/** Prints the mail on the terminal, links and all, so you can click them while developing. */
export class ConsoleMailer implements Mailer {
  async send(mail: Mail) {
    console.log(`\n──── mail to ${mail.to} ────\n${mail.subject}\n\n${mail.text}\n────────────────────\n`);
  }
}

/** Sends through Resend (https://resend.com): the sending domain must be verified there (DNS records). */
export class ResendMailer implements Mailer {
  constructor(
    private readonly apiKey: string,
    /** 「哥布林營地 <noreply@your-domain>」 */
    private readonly from: string,
    private readonly fetchImpl: typeof fetch = fetch,
  ) {}

  async send(mail: Mail) {
    const res = await this.fetchImpl("https://api.resend.com/emails", {
      method: "POST",
      headers: { authorization: `Bearer ${this.apiKey}`, "content-type": "application/json" },
      body: JSON.stringify({ from: this.from, to: [mail.to], subject: mail.subject, text: mail.text }),
    });
    if (!res.ok) throw new Error(`Resend answered ${res.status}: ${(await res.text()).slice(0, 300)}`);
  }
}

/** Keeps the mail for tests to read. */
export class MemoryMailer implements Mailer {
  readonly sent: Mail[] = [];
  async send(mail: Mail) {
    this.sent.push(mail);
  }
  last(to?: string): Mail | undefined {
    return [...this.sent].reverse().find((m) => to === undefined || m.to === to);
  }
}
