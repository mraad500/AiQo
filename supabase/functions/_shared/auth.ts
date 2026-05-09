// Lightweight JWT validation for AiQo Edge Functions.
//
// Verifies that the incoming Authorization header carries a valid Supabase
// session JWT. We don't trust the `sub` claim beyond "a real user exists" —
// server-side tier gating should re-query the user row in `profiles` when a
// tier check is required, since the JWT itself is cached for up to an hour
// and may lag behind StoreKit entitlement changes.

import { createClient } from "jsr:@supabase/supabase-js@2";

export interface AuthenticatedUser {
  id: string;
  email: string | null;
  jwt: string;
}

export class AuthError extends Error {
  constructor(public readonly status: number, message: string) {
    super(message);
    this.name = "AuthError";
  }
}

/**
 * Extracts the Supabase JWT from the `Authorization: Bearer …` header and
 * verifies it against the project's Supabase instance.
 *
 * Relies on two Edge Function secrets:
 *   - SUPABASE_URL            — same URL the client app uses
 *   - SUPABASE_ANON_KEY       — public anon key (safe in the function)
 *
 * Throws `AuthError` with an HTTP status on failure so the caller can surface
 * a clean response without leaking internals to the user.
 */
export async function authenticateRequest(
  request: Request,
): Promise<AuthenticatedUser> {
  const authHeader = request.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    throw new AuthError(401, "missing_authorization_header");
  }

  const jwt = authHeader.slice("Bearer ".length).trim();
  if (jwt.length === 0) {
    throw new AuthError(401, "empty_jwt");
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !supabaseAnonKey) {
    throw new AuthError(500, "supabase_config_missing");
  }

  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data, error } = await supabase.auth.getUser(jwt);
  if (error || !data.user) {
    throw new AuthError(401, "invalid_jwt");
  }

  return {
    id: data.user.id,
    email: data.user.email ?? null,
    jwt,
  };
}

export function jsonError(status: number, code: string): Response {
  return new Response(JSON.stringify({ error: code }), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
