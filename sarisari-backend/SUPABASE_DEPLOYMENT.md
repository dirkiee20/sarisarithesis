# Supabase Deployment

This backend is wired to use Supabase as a hosted PostgreSQL database while keeping the cashier app summary-only. The cashier app still stores products, barcodes, images, and transaction details on the user's phone. The backend receives revenue summaries, cashier summaries, inventory counts, and redacted product sales/stocks only.

Official Supabase references:

- Database connection strings: https://supabase.com/docs/guides/database/connecting-to-postgres
- Supabase recommends SSL for database connections wherever possible.
- Use Direct connection for persistent servers when IPv6 works, Session pooler for persistent servers that need IPv4, and Transaction pooler for serverless or short-lived connections.

## 1. Create the Supabase Database

1. Create a Supabase project.
2. Open the project dashboard and click **Connect**.
3. Choose the connection string:
   - Persistent backend on a VM/container: Direct connection if IPv6 works.
   - Persistent backend without IPv6: Session pooler.
   - Serverless backend: Transaction pooler.
4. Replace the password placeholder in the connection string with your database password.

Do not connect the Flutter cashier app directly to Supabase. Keep Flutter pointed at this backend so the phone only uploads allowed summaries.

## 2. Configure the Backend

Create `sarisari-backend/.env` using `sarisari-backend/.env.example` as the template.

Required production values:

```env
NODE_ENV=production
PORT=3000
DATABASE_URL=postgresql://postgres.<project-ref>:<database-password>@aws-0-<region>.pooler.supabase.com:5432/postgres
DB_SSL=require
SUPABASE_DB=true
SKIP_DB_CREATE=true
SUMMARY_ONLY_MODE=true
CORS_ORIGINS=https://your-admin-web-domain.com
JWT_SECRET=<random-secret>
JWT_REFRESH_SECRET=<different-random-secret>
```

Generate each JWT secret:

```bash
node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"
```

## 3. Create Tables in Supabase

From `sarisari-backend`:

```bash
npm install
npm run setup-db:supabase
npm run seed-admin
```

`setup-db:supabase` skips local database creation and applies the schema to the existing Supabase database. `seed-admin` creates the platform admin account.

Do not run `seed-demo-store` on production Supabase. It is only for local demos and inserts legacy product/transaction detail data.

## 4. Deploy the Backend

Deploy `sarisari-backend` to your chosen Node host and set the same environment variables there.

Start command:

```bash
npm start
```

Health check:

```bash
GET https://your-backend-domain.com/health
```

## 5. Point the Admin Web App to the Backend

For `sarisari-admin-web`, set:

```env
NEXT_PUBLIC_API_URL=https://your-backend-domain.com
```

This value should not include `/api` because the admin app already adds `/api/...` paths.

## 6. Point the Cashier App to the Backend

Build the Flutter app with:

```bash
flutter build apk --dart-define=API_BASE_URL=https://your-backend-domain.com/api
```

This value must include `/api` because the Flutter API client calls routes such as `/summaries/cashier`.

You can also set `API_BASE_URL` in `sarisaristore/env.json` and build with:

```bash
flutter build apk --dart-define-from-file=env.json
```

## 7. Verify Summary-Only Sync

After login from the cashier app, make a sale or edit stock. The app should upload a summary to:

```text
POST /api/summaries/cashier
```

Expected backend data:

- Store/cashier revenue totals
- Payment method totals
- Expense totals by category
- Inventory summary counts
- Redacted product names, categories, stock, units sold, sales revenue, and profit

Rejected backend data:

- Product images
- Barcodes
- Product IDs from the phone
- Customer records
- Raw transaction line items
