# Deprecated Patterns — Đừng Dùng Trong Project Mới

Patterns này vẫn có thể gặp trong legacy code hoặc tutorials cũ.
Biết để tránh, không phải để học.

---

## Frontend

| Pattern | Deprecated since | Thay bằng | Lý do |
|---------|-----------------|-----------|-------|
| Create React App (CRA) | 2023 | Vite, Next.js, Remix | Không maintained, slow, no SSR |
| React class components | React 16.8 (2019) | Function components + hooks | Verbose, no concurrent mode support |
| `componentDidMount` / `componentDidUpdate` | React 16.8 | `useEffect` | Lifecycle methods legacy |
| Redux cho server state | 2021 | React Query / TanStack Query | Redux không thiết kế cho async server state |
| Redux `connect()` HOC | Redux 7.1 (2019) | `useSelector` / `useDispatch` hooks | Verbose, harder to type |
| `PropTypes` | React 15.5+ | TypeScript | Runtime-only, không catch errors sớm |
| Moment.js | 2020 | `dayjs` (2KB) / `date-fns` (tree-shakeable) | 67KB gzipped, không tree-shakeable, maintenance mode |
| `styled-components` v5 | 2023 | CSS Modules, Tailwind, `styled-components` v6 | Runtime CSS-in-JS có performance cost |
| Webpack 4 | 2021 | Webpack 5, Vite, Turbopack | Slow builds, no Module Federation |
| CommonJS (`require()`) | 2022+ | ESM (`import`/`export`) | Không tree-shakeable, không async |
| IE11 support | 2022 | Không cần polyfill | Microsoft dropped support |
| `var` keyword | ES6 (2015) | `const` / `let` | Function scope dễ gây bugs |

---

## Auth & Security

| Pattern | Deprecated since | Thay bằng | Lý do |
|---------|-----------------|-----------|-------|
| OAuth 2.0 Implicit Flow | OAuth 2.1 (2023) | Authorization Code + PKCE | Access token trong URL → bị log, bị lấy qua Referer header |
| HTTP Basic Auth trên API | — | Bearer token / API key | Credentials gửi mỗi request, base64 encode (không encrypt) |
| MD5 / SHA-1 password hashing | Lâu rồi | `bcrypt` (cost 12+) / `argon2id` | Rainbow table attack, GPU crack < 1s |
| SHA-256 password hashing | — | `bcrypt` / `argon2id` | Fast hash = dễ brute force (GPU 1B ops/s với SHA-256) |
| `eval()` trong JS | Always bad | Không dùng | Code injection, XSS vector |
| CORS `*` wildcard cho API auth | — | Explicit origin allowlist | Bất kỳ site nào có thể call API với user credentials |
| Cookies không có `Secure` flag | — | `Secure; HttpOnly; SameSite=Lax` | Cookie gửi qua HTTP → intercept |
| Storing raw passwords trong DB | Always | Never, hash trước khi lưu | Data breach = expose all passwords |
| `Content-Security-Policy: unsafe-inline` | — | Nonces / hashes | Cho phép inline scripts → XSS dễ hơn |

---

## Backend

| Pattern | Deprecated since | Thay bằng | Lý do |
|---------|-----------------|-----------|-------|
| Long polling | Pre-WebSocket | WebSocket / SSE | Inefficient, nhiều connections, latency cao |
| FTP / SFTP cho app file transfer | — | S3 presigned URL, SFTP chỉ cho legacy | Không có access control tốt, không scalable |
| Monolith-to-microservices ngay từ đầu | ~2018 | Monolith trước, tách khi cần | Premature complexity, team nhỏ không quản lý được |
| 2PC (Two-Phase Commit) cross-service | — | Saga pattern | Blocking, SPOF, performance thảm hại |
| XML API (SOAP) | ~2010 | REST, GraphQL, gRPC | Verbose, slow parse, tooling kém |
| `SELECT *` trong production | Always bad | Explicit columns | Over-fetching, break khi schema thay đổi |
| Storing sessions in-memory (single server) | — | Redis session store | Không work với multiple instances / horizontal scale |
| Cron jobs trên app server | — | Dedicated scheduler (BullMQ, Sidekiq, K8s CronJob) | Race condition khi scale, không retry khi fail |

---

## Mobile

| Pattern | Deprecated since | Thay bằng | Lý do |
|---------|-----------------|-----------|-------|
| React Native `AsyncStorage` cho sensitive data | — | `react-native-keychain` | Không encrypted, accessible khi rooted |
| React Native `AsyncStorage` cho perf-critical data | — | MMKV | 10× nhanh hơn, synchronous reads |
| CodePush (Microsoft AppCenter) | 2024 | EAS Update (Expo) | Microsoft AppCenter bị deprecated tháng 3/2025 |
| React Native `Image` cho list lớn | — | `@shopify/flash-list` | 10× nhanh hơn nhờ cell recycling |
| Custom URL scheme `myapp://` cho deep links | — | Universal Links / App Links | Có thể bị hijack bởi malicious app |
| React Native Bridge architecture | React Native 0.76 | New Architecture (JSI) | Bridge deprecated, sẽ bị remove |
| Flutter `Navigator 1.0` | Flutter 2 (2021) | GoRouter / Navigator 2.0 | Không support deep linking tốt |
| Expo SDK < 49 | 2024 | SDK 51+ | SDK 49 end of life |

---

## Database

| Pattern | Deprecated since | Thay bằng | Lý do |
|---------|-----------------|-----------|-------|
| MySQL `MYISAM` engine | MySQL 5.5 | `InnoDB` | Không có transactions, không có FK support |
| PostgreSQL `timestamp` (no timezone) | — | `timestamptz` | Timezone bugs khi server ở khác timezone |
| MongoDB `$where` với JS expression | MongoDB 4.4 | `$expr`, aggregation pipeline | JS execution overhead, injection risk |
| Storing large files (>1MB) trong DB | — | S3 / blob storage, store URL trong DB | DB size bloat, slow backup, slow queries |
| MySQL `utf8` charset | MySQL 5.5 | `utf8mb4` | `utf8` trong MySQL chỉ support 3-byte, không support emoji (4-byte) |

---

## Infrastructure & Ops

| Pattern | Deprecated since | Thay bằng | Lý do |
|---------|-----------------|-----------|-------|
| Manual server provisioning (click ops) | ~2015 | Terraform, Pulumi (IaC) | Không reproducible, không auditable |
| `latest` Docker image tag trong production | Always bad | Explicit version tags (`node:20.11.0`) | `latest` thay đổi → unexpected breaks |
| Secrets trong environment variables committed | Always bad | Secret manager, `.env` không commit | Secrets in git history forever |
| Self-signed TLS certificates | — | Let's Encrypt (free) / ACM | Browser warnings, không trusted |
| `docker run` trực tiếp trên prod server | — | Kubernetes, ECS, Docker Swarm | Không có restart, health check, rolling update |
| SSH vào production để debug | — | Structured logging, distributed tracing, ephemeral debug containers | Không auditable, không reproducible |

---

## Migration Paths — Deprecated → Recommended

Không chỉ biết cái gì deprecated, mà còn biết migrate như thế nào.

### Create React App → Vite

```bash
# 1. Tạo project Vite mới
npm create vite@latest my-app -- --template react-ts

# 2. Move src/ và public/ từ CRA sang Vite project
cp -r old-project/src ./src
cp -r old-project/public ./public

# 3. Update imports (CRA dùng process.env.REACT_APP_, Vite dùng import.meta.env.VITE_)
# BAD (CRA): process.env.REACT_APP_API_URL
# GOOD (Vite): import.meta.env.VITE_API_URL

# 4. Update vite.config.ts (aliases, proxies)
# 5. Replace react-scripts in package.json với vite scripts
# Time: 1-2 days for medium project
```

### Moment.js → dayjs

```typescript
// BAD (Moment.js)
import moment from 'moment'
const formatted = moment(date).format('DD/MM/YYYY')
const added = moment(date).add(7, 'days')
const diff = moment(end).diff(moment(start), 'days')

// GOOD (dayjs — same API, 2KB vs 67KB)
import dayjs from 'dayjs'
const formatted = dayjs(date).format('DD/MM/YYYY')
const added = dayjs(date).add(7, 'days')
const diff = dayjs(end).diff(dayjs(start), 'days')
// API almost identical — find/replace moment( → dayjs(
```

### Redux for server state → React Query

```typescript
// BAD: Redux for API data (users fetch + store + selector + action = 50 lines)
// actions.ts + reducer.ts + selectors.ts + thunks.ts

// GOOD: React Query (3 lines replace all of that)
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'

function UserProfile({ userId }) {
  // Replaces: fetch on mount + loading state + error state + caching
  const { data: user, isLoading, error } = useQuery({
    queryKey: ['user', userId],
    queryFn: () => fetchUser(userId),
    staleTime: 5 * 60 * 1000,
  })

  // Replaces: dispatch(updateUser()) + optimistic update + invalidation
  const { mutate: updateUser } = useMutation({
    mutationFn: (data) => patchUser(userId, data),
    onSuccess: () => queryClient.invalidateQueries(['user', userId])
  })
}

// Migration strategy:
// 1. Install React Query
// 2. Migrate 1 endpoint at a time (start with read-only)
// 3. Remove Redux slices as they're migrated
// 4. Remove Redux entirely when all data is migrated
```

### CommonJS → ESM

```javascript
// BAD (CommonJS)
const express = require('express')
const { readFile } = require('fs/promises')
module.exports = { myFunction }

// GOOD (ESM)
import express from 'express'
import { readFile } from 'fs/promises'
export { myFunction }

// package.json: add "type": "module"
// tsconfig.json: "module": "ESNext", "moduleResolution": "Bundler"
// Note: __dirname and __filename not available in ESM
// Fix: import { fileURLToPath } from 'url'
//      const __dirname = path.dirname(fileURLToPath(import.meta.url))
```

### AsyncStorage (RN) → MMKV

```typescript
// BAD (AsyncStorage — slow, not encrypted)
import AsyncStorage from '@react-native-async-storage/async-storage'
const value = await AsyncStorage.getItem('key')  // async, slow
await AsyncStorage.setItem('key', JSON.stringify(data))

// GOOD (MMKV — 10x faster, synchronous, optional encryption)
import { MMKV } from 'react-native-mmkv'
const storage = new MMKV({ id: 'app-storage', encryptionKey: 'my-key' })

// Synchronous reads (faster for rendering)
const value = storage.getString('key')
storage.set('key', JSON.stringify(data))

// Zustand persistence with MMKV (replace AsyncStorage backend):
import { create } from 'zustand'
import { persist, createJSONStorage } from 'zustand/middleware'
const useStore = create(persist(
  (set) => ({ count: 0, increment: () => set(s => ({ count: s.count + 1 })) }),
  {
    name: 'app-store',
    storage: createJSONStorage(() => ({
      getItem: (key) => storage.getString(key) ?? null,
      setItem: (key, value) => storage.set(key, value),
      removeItem: (key) => storage.delete(key),
    }))
  }
))
```

### OAuth Implicit Flow → Authorization Code + PKCE

```typescript
// BAD: Implicit Flow (access token in URL fragment — logged, leaked)
// redirect: /callback#access_token=abc123&expires_in=3600
// Token in URL → in browser history, server logs, Referer headers

// GOOD: Authorization Code + PKCE
import { generateCodeVerifier, generateCodeChallenge } from 'pkce-challenge'

// Step 1: Generate PKCE pair
const codeVerifier = generateCodeVerifier()
const codeChallenge = await generateCodeChallenge(codeVerifier)
sessionStorage.setItem('pkce_code_verifier', codeVerifier)

// Step 2: Redirect with code_challenge
const authUrl = new URL('https://auth.example.com/authorize')
authUrl.searchParams.set('response_type', 'code')         // NOT 'token'
authUrl.searchParams.set('code_challenge', codeChallenge)
authUrl.searchParams.set('code_challenge_method', 'S256')
window.location.href = authUrl.toString()

// Step 3: Exchange code for token (server-side or with PKCE)
const response = await fetch('https://auth.example.com/token', {
  method: 'POST',
  body: new URLSearchParams({
    grant_type: 'authorization_code',
    code: urlParams.get('code'),
    code_verifier: sessionStorage.getItem('pkce_code_verifier'),
  })
})
// Token returned in response body (not URL) → much safer
```
