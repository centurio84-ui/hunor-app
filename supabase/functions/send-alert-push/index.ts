import { withSupabase } from "npm:@supabase/server@^1";
import { SignJWT, importPKCS8 } from "npm:jose@^6";

const FCM_TOKEN_URL = "https://oauth2.googleapis.com/token";
const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";

interface AlertRecord {
  id: string;
  title: string;
  message: string;
  type: "exercise" | "standby" | "alert";
  status: "active" | "closed";
  expires_at: string | null;
}

interface WebhookPayload {
  type: string;
  table: string;
  record: AlertRecord;
}

interface DeviceToken {
  id: string;
  token: string;
  platform: "ios" | "android";
}

function typeLabel(type: AlertRecord["type"]): string {
  switch (type) {
    case "exercise": return "GYAKORLAT";
    case "standby": return "KÉSZENLÉTBE HELYEZÉS";
    case "alert": return "RIASZTÁS";
  }
}

async function createGoogleAccessToken(): Promise<string> {
  const clientEmail = Deno.env.get("FIREBASE_CLIENT_EMAIL");
  const privateKeyValue = Deno.env.get("FIREBASE_PRIVATE_KEY");

  if (!clientEmail || !privateKeyValue) {
    throw new Error("Firebase service-account secrets are not configured.");
  }

  const privateKey = privateKeyValue.replace(/\\n/g, "\n");
  const key = await importPKCS8(privateKey, "RS256");
  const now = Math.floor(Date.now() / 1000);

  const assertion = await new SignJWT({ scope: FCM_SCOPE })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(clientEmail)
    .setSubject(clientEmail)
    .setAudience(FCM_TOKEN_URL)
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);

  const response = await fetch(FCM_TOKEN_URL, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });

  if (!response.ok) {
    throw new Error(`Google OAuth token exchange failed: ${response.status} ${await response.text()}`);
  }

  const data = await response.json();
  if (!data.access_token) throw new Error("No access_token returned by Google OAuth.");

  return data.access_token as string;
}

async function sendToDevice(
  device: DeviceToken,
  accessToken: string,
  alert: AlertRecord,
  projectId: string,
): Promise<{ ok: boolean; status: number; reason?: string }> {
  const title = `HUNOR • ${typeLabel(alert.type)}`;

  const message = {
    token: device.token,
    notification: { title, body: alert.message },
    data: { alert_id: alert.id, alert_type: alert.type },
    android: {
      priority: "HIGH",
      notification: { channel_id: "hunor_alerts", sound: "default" },
    },
    apns: {
      headers: { "apns-push-type": "alert", "apns-priority": "10" },
      payload: {
        aps: {
          alert: { title, body: alert.message },
          sound: "default",
          badge: 1,
        },
      },
    },
  };

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json; charset=UTF-8",
      },
      body: JSON.stringify({ message }),
    },
  );

  if (response.ok) return { ok: true, status: response.status };

  let reason = response.statusText;
  try {
    const body = await response.json();
    reason = body?.error?.details?.[0]?.errorCode ??
      body?.error?.status ??
      body?.error?.message ??
      reason;
  } catch {}

  return { ok: false, status: response.status, reason };
}

export default {
  fetch: withSupabase({ auth: "secret" }, async (req, ctx) => {
    if (req.method !== "POST") {
      return Response.json({ error: "Method not allowed" }, { status: 405 });
    }

    const payload = (await req.json()) as WebhookPayload;
    if (payload.table !== "alerts" || payload.type !== "INSERT" || !payload.record?.id) {
      return Response.json({ ignored: true });
    }

    const alert = payload.record;
    if (alert.status !== "active") {
      return Response.json({ ignored: true, reason: "alert_not_active" });
    }

    const projectId = Deno.env.get("FIREBASE_PROJECT_ID");
    if (!projectId) {
      return Response.json({ error: "FIREBASE_PROJECT_ID is not configured" }, { status: 500 });
    }

    const { data: devices, error } = await ctx.supabaseAdmin
      .from("device_tokens")
      .select("id, token, platform");

    if (error) return Response.json({ error: error.message }, { status: 500 });
    if (!devices || devices.length === 0) {
      return Response.json({ sent: 0, invalid: 0, message: "No registered devices." });
    }

    const accessToken = await createGoogleAccessToken();
    let sent = 0;
    let invalid = 0;

    for (const device of devices as DeviceToken[]) {
      try {
        const result = await sendToDevice(device, accessToken, alert, projectId);

        if (result.ok) {
          sent += 1;
        } else if (
          result.status === 404 ||
          result.reason === "UNREGISTERED" ||
          result.reason === "INVALID_ARGUMENT"
        ) {
          invalid += 1;
          await ctx.supabaseAdmin.from("device_tokens").delete().eq("id", device.id);
        }
      } catch (error) {
        console.error("FCM send failed", device.id, error);
      }
    }

    return Response.json({
      alert_id: alert.id,
      attempted: devices.length,
      sent,
      invalid,
    });
  }),
};
