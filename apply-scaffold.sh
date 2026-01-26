#!/usr/bin/env bash
set -euo pipefail

echo "Creating scaffold files for TradeFlow MVP..."

# Create directories
mkdir -p pages/api components pages/admin prisma public styles

# package.json
cat > package.json <<'JSON'
{
  "name": "tradeflow",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev -p 3000",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "prisma:generate": "prisma generate",
    "prisma:migrate": "prisma migrate dev --name init"
  },
  "dependencies": {
    "next": "14.x",
    "react": "18.x",
    "react-dom": "18.x",
    "tailwindcss": "^3.5.0",
    "prisma": "^5.0.0",
    "@prisma/client": "^5.0.0",
    "axios": "^1.5.0",
    "zod": "^4.20.0",
    "next-auth": "^4.25.0"
  },
  "devDependencies": {
    "typescript": "^5.1.0",
    "postcss": "^8.4.0",
    "autoprefixer": "^10.4.0"
  }
}
JSON

# .gitignore
cat > .gitignore <<'TXT'
node_modules
.next
.env
.env.local
.env.development.local
.env.test.local
.env.production.local
prisma/dev.db
.DS_Store
.vscode
coverage
TXT

# Prisma schema
cat > prisma/schema.prisma <<'PRISMA'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id        String   @id @default(cuid())
  email     String   @unique
  name      String?
  role      Role     @default(MEMBER)
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  posts     Post[]
  audits    PostAudit[]
}

enum Role {
  ADMIN
  MEMBER
  VERIFIED_PROFESSIONAL
}

model Pillar {
  id          String   @id @default(cuid())
  slug        String   @unique
  name        String
  description String?
  template    Json
  requireApproval Boolean @default(true)
  createdAt   DateTime @default(now())
}

model Post {
  id            String   @id @default(cuid())
  pillar        Pillar   @relation(fields: [pillarId], references: [id])
  pillarId      String
  author        User     @relation(fields: [authorId], references: [id])
  authorId      String
  type          String
  commodity     String?
  quantityMin   Int?
  quantityMax   Int?
  location      String?
  readinessDate DateTime?
  freeText      String
  status        PostStatus @default(PENDING)
  flags         Int      @default(0)
  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt
  audits        PostAudit[]
}

enum PostStatus {
  PENDING
  APPROVED
  REJECTED
  FLAGGED
}

model PostAudit {
  id        String   @id @default(cuid())
  post      Post     @relation(fields: [postId], references: [id])
  postId    String
  user      User?    @relation(fields: [userId], references: [id])
  userId    String?
  change    Json
  reason    String?
  createdAt DateTime @default(now())
}

model ProfessionalProfile {
  id          String  @id @default(cuid())
  user        User    @relation(fields: [userId], references: [id])
  userId      String  @unique
  serviceType String
  routes      Json
  capacity    String?
  verified    Boolean @default(false)
  verifiedBy  String?
  verifiedAt  DateTime?
  createdAt   DateTime @default(now())
}
PRISMA

# Next config
cat > next.config.js <<'JS'
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  swcMinify: true
}
module.exports = nextConfig;
JS

# tsconfig
cat > tsconfig.json <<'TS'
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "forceConsistentCasingInFileNames": true,
    "noEmit": true,
    "esModuleInterop": true,
    "moduleResolution": "node",
    "isolatedModules": true,
    "jsx": "react-jsx",
    "module": "esnext",
    "resolveJsonModule": true
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx"],
  "exclude": ["node_modules"]
}
TS

# tailwind + postcss
cat > tailwind.config.js <<'TW'
module.exports = {
  content: ["./pages/**/*.{js,ts,jsx,tsx}", "./components/**/*.{js,ts,jsx,tsx}"],
  theme: { extend: {} },
  plugins: [],
}
TW

cat > postcss.config.js <<'PC'
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
PC

# pages/_app.tsx
mkdir -p pages
cat > pages/_app.tsx <<'APP'
import '../styles/globals.css'
import type { AppProps } from 'next/app'

export default function App({ Component, pageProps }: AppProps) {
  return <Component {...pageProps} />
}
APP

# styles/globals.css
mkdir -p styles
cat > styles/globals.css <<'CSS'
@tailwind base;
@tailwind components;
@tailwind utilities;

html, body, #__next {
  height: 100%;
  background: #f8fafc;
  color: #0f172a;
  font-family: Inter, ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial;
}
CSS

# pages/index.tsx
cat > pages/index.tsx <<'IDX'
import Link from 'next/link'
import PostForm from '../components/PostForm'

export default function Home() {
  return (
    <main className="min-h-screen p-6">
      <div className="max-w-3xl mx-auto">
        <h1 className="text-2xl font-semibold mb-4">TradeFlow — Scaffold</h1>
        <p className="mb-4 text-sm text-slate-600">Invisible infrastructure for trade coordination. This is a starter scaffold tailored to the TradeFlow MVP.</p>

        <section className="mb-6">
          <h2 className="font-medium">Create a Pillar Post (Pulse)</h2>
          <p className="text-sm text-slate-500 mb-2">WhatsApp-friendly, text-first</p>
          <PostForm pillarSlug="pulse" />
        </section>

        <section>
          <h2 className="font-medium">Admin</h2>
          <Link href="/admin/dashboard"><a className="text-sky-700 underline">Open admin dashboard (stub)</a></Link>
        </section>
      </div>
    </main>
  )
}
IDX

# API endpoint
cat > pages/api/posts.ts <<'API'
import type { NextApiRequest, NextApiResponse } from "next";
import { z } from "zod";
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

const PostSchema = z.object({
  pillarSlug: z.string(),
  type: z.string(),
  commodity: z.string().optional(),
  quantityMin: z.number().int().optional(),
  quantityMax: z.number().int().optional(),
  location: z.string().optional(),
  readinessDate: z.string().optional(),
  freeText: z.string().min(5)
});

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method === "POST") {
    const parse = PostSchema.safeParse(req.body);
    if (!parse.success) return res.status(400).json({ error: parse.error.issues });

    const { pillarSlug, ...payload } = parse.data;

    const pillar = await prisma.pillar.findUnique({ where: { slug: pillarSlug } });
    if (!pillar) return res.status(404).json({ error: "Pillar not found" });

    const status = pillar.requireApproval ? "PENDING" : "APPROVED";
    const authorId = req.headers["x-test-user"] as string || null;
    if (!authorId) return res.status(401).json({ error: "Unauthenticated (use x-test-user header in dev)" });

    const post = await prisma.post.create({
      data: {
        pillarId: pillar.id,
        authorId,
        type: payload.type,
        commodity: payload.commodity,
        quantityMin: payload.quantityMin,
        quantityMax: payload.quantityMax,
        location: payload.location,
        readinessDate: payload.readinessDate ? new Date(payload.readinessDate) : null,
        freeText: payload.freeText,
        status
      }
    });

    await prisma.postAudit.create({
      data: {
        postId: post.id,
        userId: authorId,
        change: { created: true }
      }
    });

    return res.status(201).json({ post });
  }

  if (req.method === "GET") {
    const pillarSlug = req.query.pillarSlug as string | undefined;
    const where = pillarSlug ? { pillar: { slug: pillarSlug } } : {};
    const posts = await prisma.post.findMany({
      where,
      orderBy: { createdAt: "desc" },
      take: 100
    });
    return res.status(200).json({ posts });
  }

  return res.status(405).end();
}
API

# components/PostForm.tsx
mkdir -p components
cat > components/PostForm.tsx <<'COMP'
import React, { useState } from "react";
import axios from "axios";

export default function PostForm({ pillarSlug }: { pillarSlug: string }) {
  const [freeText, setFreeText] = useState("");
  const [commodity, setCommodity] = useState("");
  const [quantityMin, setQuantityMin] = useState<number | "">("");
  const [quantityMax, setQuantityMax] = useState<number | "">("");
  const [location, setLocation] = useState("");
  const [submitting, setSubmitting] = useState(false);

  async function submit() {
    setSubmitting(true);
    try {
      const resp = await axios.post("/api/posts", {
        pillarSlug,
        type: "sell",
        commodity,
        quantityMin: quantityMin || undefined,
        quantityMax: quantityMax || undefined,
        location,
        freeText
      }, { headers: { "x-test-user": "test-user-1" }});
      alert("Posted: " + resp.data.post.id);
    } catch (err: any) {
      alert("Error: " + (err?.response?.data?.error || err.message));
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="max-w-xl p-4 bg-white rounded shadow-sm text-sm">
      <div className="mb-2">
        <label className="block font-medium">Commodity</label>
        <input value={commodity} onChange={e => setCommodity(e.target.value)} className="w-full border p-2" />
      </div>
      <div className="mb-2">
        <label className="block font-medium">Quantity (min - max)</label>
        <div className="flex gap-2">
          <input type="number" value={quantityMin as any} onChange={e => setQuantityMin(e.target.value ? Number(e.target.value) : "")} className="w-1/2 border p-2" placeholder="min" />
          <input type="number" value={quantityMax as any} onChange={e => setQuantityMax(e.target.value ? Number(e.target.value) : "")} className="w-1/2 border p-2" placeholder="max" />
        </div>
      </div>
      <div className="mb-2">
        <label className="block font-medium">Location</label>
        <input value={location} onChange={e => setLocation(e.target.value)} className="w-full border p-2" />
      </div>
      <div className="mb-2">
        <label className="block font-medium">Details (WhatsApp-friendly)</label>
        <textarea value={freeText} onChange={e => setFreeText(e.target.value)} rows={4} className="w-full border p-2" />
      </div>
      <div className="flex justify-between items-center">
        <button onClick={submit} disabled={submitting} className="px-4 py-2 bg-sky-700 text-white rounded">
          {submitting ? "Posting..." : "Post"}
        </button>
        <button onClick={() => {
          const message = formatWhatsAppPost({ commodity, quantityMin, quantityMax, location, freeText });
          navigator.clipboard.writeText(message);
          alert("Copied WhatsApp template");
        }} className="text-sm text-slate-600">Copy for WhatsApp</button>
      </div>
    </div>
  );
}

function formatWhatsAppPost({ commodity, quantityMin, quantityMax, location, freeText }: any) {
  const qty = quantityMin || quantityMax ? `${quantityMin || ''}${quantityMin && quantityMax ? ' - ' : ''}${quantityMax || ''}`.trim() : "Unknown";
  return `TradeFlow • ${commodity || 'Commodity'}
Qty: ${qty}
Location: ${location || 'TBC'}
Details: ${freeText || ''}
(Platform: TradeFlow — no payment on platform. Contact offline to proceed.)`;
}
COMP

# admin dashboard stub
mkdir -p pages/admin
cat > pages/admin/dashboard.tsx <<'ADM'
export default function AdminDashboard() {
  return (
    <main className="min-h-screen p-6">
      <div className="max-w-4xl mx-auto">
        <h1 className="text-2xl font-semibold mb-4">Admin — Demand Signals (stub)</h1>
        <p className="text-sm mb-4">This page will show aggregated commodity interest, volume ranges, and location clusters. (MVP placeholder)</p>
        <div className="bg-white p-4 rounded shadow-sm">No data yet �� run seed script to create pillars and test posts.</div>
      </div>
    </main>
  )
}
ADM

# README (markdown block)
cat > README.md <<'REND'
# TradeFlow (scaffold)

Trade coordination system scaffold focused on offline-first and WhatsApp-friendly trade coordination.

This scaffold contains a minimal Next.js + Prisma starter tailored to the TradeFlow MVP.

Getting started:
1. Install dependencies:
   npm install
2. Set DATABASE_URL in `.env` (Postgres). Example: postgres://USER:PASS@HOST:5432/dbname
3. Generate Prisma client and migrate:
   npx prisma generate
   npx prisma migrate dev --name init
4. Run dev server:
   npm run dev
REND

# git add & commit
git add .
git commit -m "chore(scaffold): add TradeFlow MVP starter (Next.js + Prisma + Tailwind)"

# push branch
BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "Pushing branch ${BRANCH} to origin..."
git push --set-upstream origin "${BRANCH}"

# create PR using gh
if command -v gh >/dev/null 2>&1; then
  echo "Creating PR using GitHub CLI..."
  gh pr create --title "scaffold: TradeFlow MVP" --body "Adds a minimal Next.js + Prisma + Tailwind scaffold for TradeFlow MVP. Includes Pillar/Post models, posts API, admin stub, and WhatsApp-friendly post UI." --base main --head "${BRANCH}"
  echo "PR created."
else
  echo "gh CLI not found. Please create a PR from branch ${BRANCH} manually."
fi

echo "Done. Run 'npm install' and then 'npm run dev' to start the dev server."