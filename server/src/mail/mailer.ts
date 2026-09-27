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
