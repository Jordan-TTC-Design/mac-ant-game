import type { ServerEvent } from "@goblincamp/shared";

/** One open WebSocket, as the hub sees it. */
export interface Socket {
  send(data: string): void;
  close(code?: number, reason?: string): void;
}

/** Who is connected, so a change on one device can be told to the others right away. */
export class Hub {
  private byUser = new Map<string, Map<Socket, string>>(); // user → socket → session

  add(userId: string, sessionId: string, socket: Socket) {
    let sockets = this.byUser.get(userId);
    if (!sockets) this.byUser.set(userId, (sockets = new Map()));
    sockets.set(socket, sessionId);
  }

  remove(userId: string, socket: Socket) {
    const sockets = this.byUser.get(userId);
    sockets?.delete(socket);
    if (sockets?.size === 0) this.byUser.delete(userId);
  }

  /**
   * Tells every socket of the user. `exceptSession`: not that sign-in's sockets (it made the change and already has the
   * answer: telling it would only make it ask again for what it holds).
   */
  notify(userId: string, event: ServerEvent, exceptSession?: string) {
    const data = JSON.stringify(event);
    for (const [socket, session] of this.byUser.get(userId) ?? []) {
      if (exceptSession !== undefined && session === exceptSession) continue;
      try {
        socket.send(data);
      } catch {
        // a socket that is going away; its close event removes it
      }
    }
  }

  /** A session was signed out: its sockets close too. `sessionId` undefined = every session of the user. */
  close(userId: string, sessionId?: string) {
    for (const [socket, session] of this.byUser.get(userId) ?? []) {
      if (sessionId === undefined || session === sessionId) socket.close(4001, "signed out");
    }
  }

  count(userId: string): number {
    return this.byUser.get(userId)?.size ?? 0;
  }

  /** Everyone connected right now: how many sockets, how many accounts. */
  size(): { sockets: number; users: number } {
    let sockets = 0;
    for (const s of this.byUser.values()) sockets += s.size;
    return { sockets, users: this.byUser.size };
  }

  /** Tells everyone connected. */
  notifyAll(event: ServerEvent) {
    for (const userId of this.byUser.keys()) this.notify(userId, event);
  }
}
