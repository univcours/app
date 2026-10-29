/**
 * API-only Cloudflare Worker managed in the univcours/app GitHub repository.
 *
 * Keeps ALL existing /api/* routes: monthly comptage, archived budget,
 * coordinator login and four barcode-control operations.
 * No ChatGPT Sites or Vinext runtime entrypoint is needed.
 *
 * The D1 database is a binding named DB. Do not switch traffic until
 * the required data has been safely migrated and verified.
 */
import { GET, POST, DELETE, OPTIONS } from "../app/api/[...path]/route";

export default {
  async fetch(request: Request): Promise<Response> {
    switch (request.method) {
      case "GET": return GET(request);
      case "POST": return POST(request);
      case "DELETE": return DELETE(request);
      case "OPTIONS": return OPTIONS(request);
      default:
        return Response.json({ error: "Méthode non autorisée." }, {
          status: 405, headers: { "Allow": "GET, POST, DELETE, OPTIONS" },
        });
    }
  },
};
