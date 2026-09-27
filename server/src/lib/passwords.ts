import { hash, verify } from "@node-rs/argon2";

// argon2id (the library's default) with the OWASP settings: 19 MiB, 2 passes, 1 lane.
const options = { memoryCost: 19456, timeCost: 2, parallelism: 1 };

export function hashPassword(password: string): Promise<string> {
  return hash(password, options);
}

export async function verifyPassword(stored: string, password: string): Promise<boolean> {
  try {
    return await verify(stored, password);
  } catch {
    return false;
  }
}

let dummy: Promise<string> | undefined;

/** Checks a password against a made-up hash, so a login for an address that does not exist takes as long as a real one. */
export async function burnPasswordTime(password: string): Promise<void> {
  dummy ??= hashPassword("not-a-real-password-for-timing");
  await verifyPassword(await dummy, password);
}
