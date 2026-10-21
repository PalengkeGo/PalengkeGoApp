// Ambient type definitions for Deno runtime and Supabase Edge Functions in VS Code / IDE.
// These definitions satisfy the IDE's TypeScript language server when viewing edge functions.

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

declare module 'npm:*' {
  const value: any;
  export default value;
  export const createRemoteJWKSet: any;
  export const jwtVerify: any;
  export const createClient: any;
  export const stripe: any;
}

declare module 'jsr:*' {
  const value: any;
  export default value;
}
