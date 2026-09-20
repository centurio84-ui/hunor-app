import { withSupabase } from "npm:@supabase/server@^1";
import { SignJWT, importPKCS8 } from "npm:jose@^6";

const APNS_HOST = "https://api.push.apple.com";

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

function typeLabel(type: AlertRecord["type"]): string {
  switch (type) {
    case "exercise":
      return "GYAKORLAT";
    case "standby":
      return "KÉSZENLÉTBE HELYEZÉS";
    case "alert":
      return "RIASZTÁS";
  }
}

async function createProviderToken(): Promise<string> {
  const keyId = Deno.env.get("APNS_KEY_ID");
  const teamId = Deno.env.get("APNS_TEAM_ID");
  const privateKey = Deno.env.get("APNS_P8_KEY");

  if (!keyId || !teamId || !privateKey) {
    throw new Error("APNs secrets are not configured.");
  }

  const pem = privateKey.replace(/\\n/g, "\n");
  const key = await importPKCS8(pem, "ES256");

  return await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: keyId })
    .setIssuer(teamId)
    .setIssuedAt()
    .sign(key);
}

async function sendToDevice(
  token: string,
  providerToken: string,
  topic: string,
  alert: AlertRecord,
): Promise<{ ok: boolean; status: number; reason?: string }> {
  const response = await fetch(`${APNS_HOST}/3/device/${token}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${providerToken}`,
      "apns-topic": topic,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      aps: {
        alert: {
          title: `HUNOR • ${typeLabel(alert.type)}`,
          body: alert.message,
        },
        sound: "default",
        badge: 1,
      },
      alert_id: alert.id,
      alert_type: alert.type,
    }),
  });

  if (response.ok) {
    return { ok: true, status: response.status };
  }

  let reason = response.statusText;
  try {
    const body = await response.json();
    reason = body.reason ?? reason;
  } catch {
    // Keep the HTTP status text.
  }

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

    const topic = Deno.env.get("APNS_BUNDLE_ID");
    if (!topic) {
      return Response.json({ error: "APNS_BUNDLE_ID is not configured" }, { status: 500 });
    }

    const { data: devices, error } = await ctx.supabaseAdmin
      .from("device_tokens")
      .select("id, token")
      .eq("platform", "ios");

    if (error) {
      return Response.json({ error: error.message }, { status: 500 });
    }

    if (!devices || devices.length === 0) {
      return Response.json({ sent: 0, invalid: 0, message: "No registered iOS devices." });
    }

    const providerToken = await createProviderToken();
    let sent = 0;
    let invalid = 0;

    for (const device of devices) {
      const result = await sendToDevice(device.token, providerToken, topic, alert);

      if (result.ok) {
        sent += 1;
      } else if (result.status === 410 || result.reason === "BadDeviceToken" || result.reason === "DeviceTokenNotForTopic") {
        invalid += 1;
        await ctx.supabaseAdmin
          .from("device_tokens")
          .delete()
          .eq("id", device.id);
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
