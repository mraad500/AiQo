// AiQo app is a native iOS client — CORS is not strictly required for the
// mobile fetch path, but Supabase Edge Functions respond to browser-origin
// preflights too, so we expose a conservative allowlist. Native fetch ignores
// CORS, so mobile requests pass through regardless of these headers.
export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
} as const;

export function handlePreflight(request: Request): Response | null {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  return null;
}
