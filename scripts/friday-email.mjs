// ============================================================
// Friday pending-payments email.
// Runs in GitHub Actions every Friday. Reads pending balances
// from Supabase and emails a summary with one-tap WhatsApp links.
//
// Reads these from environment (set as GitHub repo Secrets):
//   SUPABASE_URL, SUPABASE_SERVICE_KEY, RESEND_API_KEY,
//   EMAIL_TO, EMAIL_FROM
// ============================================================
import { createClient } from "@supabase/supabase-js";

const {
  SUPABASE_URL, SUPABASE_SERVICE_KEY,
  RESEND_API_KEY, EMAIL_TO, EMAIL_FROM
} = process.env;

const sb = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
const inr = n => Number(n || 0).toLocaleString("en-IN", { maximumFractionDigits: 2 });

const { data, error } = await sb
  .from("pending_summary")
  .select("*")
  .order("pending", { ascending: false });

if (error) { console.error(error); process.exit(1); }

if (!data || data.length === 0) {
  console.log("No pending payments. Nothing to send.");
  process.exit(0);
}

const grandTotal = data.reduce((s, r) => s + Number(r.pending), 0);

const rows = data.map(r => {
  const msg = encodeURIComponent(
    `Hello ${r.name}, a gentle reminder that ₹${inr(r.pending)} is pending for your bricks order. Thank you!`
  );
  const wa = `https://wa.me/${r.phone}?text=${msg}`;
  return `
    <tr>
      <td style="padding:10px 12px;border-bottom:1px solid #eee">
        <strong>${r.name}</strong><br>
        <span style="color:#888;font-size:13px">${r.phone} · billed ₹${inr(r.total_billed)} · paid ₹${inr(r.total_paid)} · last ${r.last_delivery}</span>
      </td>
      <td style="padding:10px 12px;border-bottom:1px solid #eee;text-align:right;white-space:nowrap">
        ₹${inr(r.pending)}
      </td>
      <td style="padding:10px 12px;border-bottom:1px solid #eee;text-align:right">
        <a href="${wa}" style="background:#25852f;color:#fff;text-decoration:none;
           padding:7px 12px;border-radius:8px;font-size:13px;white-space:nowrap">Remind</a>
      </td>
    </tr>`;
}).join("");

const html = `
  <div style="font-family:-apple-system,Segoe UI,Roboto,sans-serif;max-width:560px;margin:auto">
    <h2 style="color:#a8451f">🧱 Friday pending payments</h2>
    <p style="color:#555">${data.length} customer(s) owe a total of
       <strong>₹${inr(grandTotal)}</strong>. Tap “Remind” to open WhatsApp with the
       message ready.</p>
    <table style="width:100%;border-collapse:collapse;font-size:15px">${rows}</table>
    <p style="color:#aaa;font-size:12px;margin-top:20px">Sent automatically by your Bricks Tracker.</p>
  </div>`;

const res = await fetch("https://api.resend.com/emails", {
  method: "POST",
  headers: {
    Authorization: `Bearer ${RESEND_API_KEY}`,
    "Content-Type": "application/json"
  },
  body: JSON.stringify({
    from: EMAIL_FROM,
    to: EMAIL_TO,
    subject: `Pending payments — ₹${inr(grandTotal)} across ${data.length} customer(s)`,
    html
  })
});

if (!res.ok) {
  console.error("Email failed:", await res.text());
  process.exit(1);
}
console.log(`Sent reminder for ${data.length} customers, ₹${inr(grandTotal)} total.`);
