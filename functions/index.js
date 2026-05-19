/**
 * ClothNear Firebase Cloud Functions
 *
 * paymongo_create_link  — creates a PayMongo payment link server-side,
 *                         bypassing browser CORS restrictions.
 * paymongo_get_link     — retrieves the status of an existing link.
 *
 * The PAYMONGO_SECRET_KEY is stored in Firebase Functions config / Secret Manager,
 * never exposed to the client bundle.
 *
 * Deploy:
 *   firebase deploy --only functions
 *
 * Set secret (run once):
 *   firebase functions:secrets:set PAYMONGO_SECRET_KEY
 */

const functions = require("firebase-functions/v2/https");
const fetch = require("node-fetch");

const PAYMONGO_BASE = "https://api.paymongo.com/v1";

// ── Helper: build Basic Auth header ──────────────────────────────────────────
function basicAuth(secretKey) {
  return "Basic " + Buffer.from(secretKey + ":").toString("base64");
}

// ── Helper: get secret key from environment ───────────────────────────────────
function getSecretKey() {
  // Firebase Functions v2: secrets are injected as process.env
  const key = process.env.PAYMONGO_SECRET_KEY || "";
  if (!key) {
    throw new functions.HttpsError(
      "failed-precondition",
      "PayMongo secret key is not configured. Set PAYMONGO_SECRET_KEY in Firebase secrets."
    );
  }
  return key;
}

// ── CORS helper: only allow requests from your Firebase Hosting domain ────────
const ALLOWED_ORIGINS = [
  "https://clothnear.web.app",
  "https://clothnear.firebaseapp.com",
  // local dev
  "http://localhost",
  "http://localhost:5000",
  "http://localhost:8080",
];

function setCorsHeaders(req, res) {
  const origin = req.headers.origin || "";
  const allowed =
    ALLOWED_ORIGINS.includes(origin) || origin.startsWith("http://localhost");
  res.set("Access-Control-Allow-Origin", allowed ? origin : ALLOWED_ORIGINS[0]);
  res.set("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  res.set("Access-Control-Max-Age", "3600");
}

// ── paymongo_create_link ──────────────────────────────────────────────────────
exports.paymongo_create_link = functions.onRequest(
  { secrets: ["PAYMONGO_SECRET_KEY"], cors: ALLOWED_ORIGINS },
  async (req, res) => {
    setCorsHeaders(req, res);

    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    if (req.method !== "POST") {
      res.status(405).json({ error: "Method not allowed" });
      return;
    }

    try {
      const secretKey = getSecretKey();
      const { amountInCentavos, description, remarks } = req.body;

      if (!amountInCentavos || !description) {
        res.status(400).json({ error: "amountInCentavos and description are required" });
        return;
      }

      const payload = {
        data: {
          attributes: {
            amount: amountInCentavos,
            description: description,
            ...(remarks ? { remarks } : {}),
          },
        },
      };

      const pmRes = await fetch(`${PAYMONGO_BASE}/links`, {
        method: "POST",
        headers: {
          Authorization: basicAuth(secretKey),
          "Content-Type": "application/json",
          Accept: "application/json",
        },
        body: JSON.stringify(payload),
      });

      const pmBody = await pmRes.json();

      if (pmRes.status !== 200 && pmRes.status !== 201) {
        const detail =
          pmBody?.errors?.[0]?.detail ||
          `PayMongo error ${pmRes.status}`;
        res.status(pmRes.status).json({ error: detail });
        return;
      }

      const attrs = pmBody.data.attributes;
      res.status(200).json({
        linkId: pmBody.data.id,
        checkoutUrl: attrs.checkout_url,
        referenceNumber: attrs.reference_number || "",
        status: attrs.status || "unpaid",
        amountInCentavos: amountInCentavos,
      });
    } catch (err) {
      console.error("paymongo_create_link error:", err);
      if (err instanceof functions.HttpsError) {
        res.status(400).json({ error: err.message });
      } else {
        res.status(500).json({ error: "Internal server error: " + err.message });
      }
    }
  }
);

// ── paymongo_get_link ─────────────────────────────────────────────────────────
exports.paymongo_get_link = functions.onRequest(
  { secrets: ["PAYMONGO_SECRET_KEY"], cors: ALLOWED_ORIGINS },
  async (req, res) => {
    setCorsHeaders(req, res);

    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    if (req.method !== "GET") {
      res.status(405).json({ error: "Method not allowed" });
      return;
    }

    try {
      const secretKey = getSecretKey();
      const linkId = req.query.linkId;

      if (!linkId) {
        res.status(400).json({ error: "linkId query param is required" });
        return;
      }

      const pmRes = await fetch(`${PAYMONGO_BASE}/links/${linkId}`, {
        method: "GET",
        headers: {
          Authorization: basicAuth(secretKey),
          Accept: "application/json",
        },
      });

      if (pmRes.status !== 200) {
        res.status(pmRes.status).json({ error: "PayMongo error " + pmRes.status });
        return;
      }

      const pmBody = await pmRes.json();
      const status = pmBody?.data?.attributes?.status || "unknown";
      res.status(200).json({ status });
    } catch (err) {
      console.error("paymongo_get_link error:", err);
      res.status(500).json({ error: "Internal server error: " + err.message });
    }
  }
);
