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
