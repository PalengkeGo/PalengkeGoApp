// Ambient type definitions for Deno runtime and Supabase Edge Functions in VS Code / IDE.
// Provides type information for Deno globals and npm/jsr specifiers when viewing files in the IDE.

declare namespace Deno {
  export interface Env {
    get(key: string): string | undefined;
    set(key: string, value: string): void;
    has(key: string): boolean;
    delete(key: string): void;
    toObject(): Record<string, string>;
  }
  export const env: Env;
  export function serve(
    handler: (req: Request) => Response | Promise<Response> | Promise<any> | any
  ): void;
}

declare module 'npm:*';
declare module 'jsr:*';

// The wildcard npm declaration above keeps other npm: imports quiet in VS Code,
// but it hides named exports. Declare the Firebase Admin exports used here.
declare module 'npm:firebase-admin@12.7.0/app' {
  export function cert(serviceAccount: Record<string, unknown>): unknown;
  export function getApps(): unknown[];
  export function initializeApp(options: { credential: unknown }): unknown;
}

declare module 'npm:firebase-admin@12.7.0/messaging' {
  export function getMessaging(): {
    sendEachForMulticast(message: {
      tokens: string[];
      notification: { title: string; body: string };
      data: Record<string, string>;
      android?: { priority: 'high'; notification: { channelId: string } };
      apns?: { payload: { aps: { sound: string } } };
    }): Promise<{
      responses: Array<{ success: boolean; error?: { code?: string } }>;
    }>;
  };
}

declare module 'npm:firebase-admin@12.7.0/auth' {
  export function getAuth(): {
    getUser(uid: string): Promise<{ customClaims?: Record<string, unknown> }>;
    setCustomUserClaims(uid: string, claims: Record<string, unknown>): Promise<void>;
  };
}
