# 🧱 Bricks Delivery Tracker

A simple web app to track brick deliveries per customer — search by name,
view their full transaction history, record payments (UPI / Cash / Net Banking…),
and get an automatic **Friday email** listing everyone with pending payments,
each with a one-tap WhatsApp reminder link.

All free: GitHub (hosting + Friday job), Supabase (database), Resend (email).

---

## What's in here

| File | What it does |
|------|--------------|
| `index.html` | The app (search, customer view, deliveries, payments) |
| `config.js` | Where you paste your Supabase keys |
| `schema.sql` | Database tables — run once in Supabase |
| `scripts/friday-email.mjs` | Builds and sends the Friday email |
| `.github/workflows/friday-email.yml` | Runs the email every Friday |

### How deliveries and payments work
Each **delivery** records bricks × price = what the customer owes. Each **payment** is money received (UPI, Cash, Net Banking…), recorded separately — so a customer can pay in **several installments** over time. The **pending balance** shown everywhere is total delivered minus total paid. Entries can be **edited**, or **voided** (a safe soft-delete that hides them from balances but keeps them recoverable). The Friday email lists everyone whose balance is still above zero, ignoring voided entries.

---

## Setup — about 25 minutes, one time

### 1. Database (Supabase)
1. Create a free account at supabase.com and make a new project. Save the database password somewhere.
2. In the left menu open **SQL Editor → New query**. Paste everything from `schema.sql` and click **Run**. This creates the `customers` and `transactions` tables plus the `pending_summary` view.
3. Open **Project Settings → Data API**. Copy the **Project URL**.
4. Open **Project Settings → API Keys**. Copy the **anon / publishable** key (public, safe for the app) and also reveal and copy the **service_role** key (secret — used only by the Friday job, never in the app).

### 2. Turn on Row Level Security (important for a public repo)
Because the app's anon key sits in a public file, lock writes down. Quickest safe option for a single-user tool: in **SQL Editor**, run:

```sql
alter table customers  enable row level security;
alter table deliveries enable row level security;
alter table payments   enable row level security;
-- Allow the public anon key to read/write (fine for a private single-user tool).
create policy "anon all customers"  on customers  for all using (true) with check (true);
create policy "anon all deliveries" on deliveries for all using (true) with check (true);
create policy "anon all payments"   on payments   for all using (true) with check (true);
```

> If you want stronger protection later, add Supabase Auth and a login screen — ask and it can be added. For one shop owner using a private link, the above is a reasonable start.

### 3. Connect the app
Open `config.js`, paste your **Project URL** and **anon key**, save.

### 4. Host it (GitHub + Vercel)
1. Create a new GitHub repo and upload this whole folder (or `git push`).
2. Go to vercel.com, sign in with GitHub, **Add New → Project**, pick the repo, click **Deploy**. No settings needed — it's a static site.
3. Vercel gives you a URL like `your-bricks.vercel.app`. That's the app. Bookmark it on the phone's home screen.

*(Alternative: GitHub Pages also works — Settings → Pages → deploy from `main`. Vercel is suggested because the repo can stay private and still deploy.)*

### 5. Friday email
1. Sign up free at resend.com. Verify a sender (either verify your own domain, or use their test sender to email yourself). Copy your **API key**.
2. In your GitHub repo: **Settings → Secrets and variables → Actions → New repository secret**. Add these five:

   | Secret name | Value |
   |-------------|-------|
   | `SUPABASE_URL` | your Project URL |
   | `SUPABASE_SERVICE_KEY` | the **service_role** key |
   | `RESEND_API_KEY` | your Resend key |
   | `EMAIL_TO` | the address that should receive the Friday list |
   | `EMAIL_FROM` | a verified Resend sender, e.g. `reminders@yourdomain.com` |

3. Test it now without waiting for Friday: repo **Actions** tab → "Friday pending-payments email" → **Run workflow**. Check your inbox.

The cron is set to **9:00 AM IST every Friday**. To change the time, edit the `cron` line in `.github/workflows/friday-email.yml` (it's in UTC).

---

## Using it day to day
- **Search** a name at the top → tap the customer → see deliveries, payments, and the running pending balance.
- **+ Add delivery** → enter bricks and price; order value computes automatically.
- **+ Record payment** → enter the amount received and method. Quick buttons fill the full pending amount or a part of it. Record as many payments as you like.
- **Edit** any delivery or payment with the Edit button on that entry — fix a wrong amount, date, or note.
- **Void** (instead of delete): the Void button asks you to type the word VOID to confirm. A voided entry is hidden and stops counting toward balances, but is never erased. Tick **Show voided entries** to see them and **Restore** any one. Voiding a payment raises the pending balance; voiding a delivery lowers the amount billed.
- New name? Type it in search and tap **add**.
- The **WhatsApp reminder** button is on the customer screen too, not just Fridays.

## Phone numbers
Store numbers **with country code, no `+` or spaces** — e.g. `919876543210`. That's what makes the WhatsApp links work.
