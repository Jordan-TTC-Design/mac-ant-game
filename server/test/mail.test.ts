import { describe, expect, it } from "vitest";
import { ResendMailer } from "../src/mail/mailer.ts";

describe("ResendMailer", () => {
  it("sends the mail to Resend's API with the key", async () => {
    const calls: { url: string; init: RequestInit }[] = [];
    const fake = (async (url: string, init: RequestInit) => {
      calls.push({ url, init });
      return new Response(JSON.stringify({ id: "x" }), { status: 200 });
    }) as unknown as typeof fetch;
    await new ResendMailer("re_key", "哥布林營地 <noreply@example.com>", fake).send({ to: "a@example.com", subject: "hi", text: "body" });
    expect(calls[0]!.url).toBe("https://api.resend.com/emails");
    expect((calls[0]!.init.headers as Record<string, string>).authorization).toBe("Bearer re_key");
    expect(JSON.parse(String(calls[0]!.init.body))).toEqual({ from: "哥布林營地 <noreply@example.com>", to: ["a@example.com"], subject: "hi", text: "body" });
  });

  it("fails loudly when Resend refuses", async () => {
    const fake = (async () => new Response("domain not verified", { status: 403 })) as unknown as typeof fetch;
    await expect(new ResendMailer("k", "f", fake).send({ to: "a@example.com", subject: "s", text: "t" })).rejects.toThrow("Resend answered 403");
  });
});
