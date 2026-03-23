# Mobile App Architecture — Reference

---

## 1. Chọn Approach: Native vs Cross-platform

### So sánh chi tiết

| | React Native | Flutter | Native iOS/Android |
|-|-------------|---------|-------------------|
| Language | TypeScript | Dart | Swift / Kotlin |
| Renderer | Native views | Skia/Impeller (own renderer) | Platform native |
| Performance | Tốt (JSI bridge-less từ New Arch) | Rất tốt | Tốt nhất |
| Code share | ~70–80% logic | ~80–90% | 0% |
| UI fidelity | Native feel, auto-follows OS | Pixel-perfect nhưng không phải native | Pixel-perfect native |
| Ecosystem | Lớn (npm) | Đang lớn, pub.dev | Mature |
| Hot reload | Có | Có (hot reload tốt nhất) | Không |
| Hire | Dễ (JS devs) | Khó hơn (Dart ít phổ biến) | Dễ (iOS), khó (Android) |

### Choosing approach — with reasoning

**React Native**:
- Team đã biết React/TypeScript → ramp-up nhanh
- Muốn share logic với web (React Query, Zustand, tRPC đều reuse được)
- App thông thường: e-commerce, social, news, dashboard
- **Không phù hợp**: game, AR/VR, app cần custom native animation phức tạp

**Flutter**:
- App cần UI nhất quán tuyệt đối trên cả hai platform
- Heavy animation, custom drawing, game-like UI
- Team không có React background
- **Không phù hợp**: cần deep native integration mà Flutter chưa có plugin

**Native iOS/Android**:
- Finance, banking (biometrics, secure enclave, certificate pinning nghiêm ngặt)
- Camera-heavy (ARKit, ML Vision)
- App phải follow platform HIG nghiêm ngặt (Apple Watch, iOS widgets)
- Cần tuyệt đối performance (AAA game)

**PWA** (Progressive Web App):
- App đơn giản, không cần App Store
- Offline cơ bản (service worker cache)
- Limitations: Không access đầy đủ hardware, iOS Safari còn nhiều hạn chế

---

## 2. Architecture Patterns

### Clean Architecture (áp dụng cho cả RN và Flutter)

```
Presentation Layer
  → UI components, ViewModels (RN: hooks), Controllers (Flutter: BLoC/Cubit)
  → Không chứa business logic
  → Chỉ biết về Domain layer

Domain Layer (Core — pure, không phụ thuộc framework)
  → Use cases (PlaceOrderUseCase, GetUserProfileUseCase)
  → Entities (User, Order, Product)
  → Repository interfaces (định nghĩa contract, không implement)
  → Không biết gì về API, DB, UI

Data Layer
  → Repository implementations
  → Remote data sources (Axios/Dio, REST/GraphQL)
  → Local data sources (SQLite/MMKV/Hive)
  → DTOs và mappers (API response → Domain entity)
```

**Rule quan trọng**: Domain layer không được import bất cứ thứ gì từ Presentation hay Data. Dependency direction: Presentation → Domain ← Data.

### React Native — Feature-Sliced Design

```
src/
  app/               → App entry, providers, navigation root
  features/
    auth/
      screens/       → Login, Register, ForgotPassword
      components/    → OTPInput, BiometricPrompt
      hooks/         → useAuth, useOTP
      api/           → authApi (React Query mutations)
      store/         → authStore (Zustand)
      types.ts
    home/
    product/
    cart/
  shared/
    components/      → Button, Input, Card (design system)
    api/             → apiClient (Axios instance, interceptors)
    store/           → cartStore, userStore
    hooks/           → usePermissions, useNetwork
    utils/
    constants/
```

### Flutter — Feature + BLoC

```
lib/
  core/
    network/         → Dio setup, interceptors, error handling
    storage/         → Hive/Isar setup
    router/          → GoRouter config
    di/              → Dependency injection (get_it/injectable)
  features/
    auth/
      bloc/          → AuthBloc, AuthEvent, AuthState
      data/
        repositories/
        datasources/
        models/
      domain/
        repositories/    → abstract interface
        usecases/
        entities/
      presentation/
        pages/
        widgets/
```

---

## 3. State Management Chi Tiết

### React Native — phân loại state

```
Server state (API data)    → TanStack Query v5
  → Caching, background refetch, pagination, optimistic updates
  → Không nhét API data vào Zustand

Persistent local state     → Zustand + MMKV persist
  → Auth token, user preferences, cart
  → MMKV nhanh hơn AsyncStorage 10x

Navigation state           → React Navigation (managed internally)
  → Không cần store ngoài

Form state                 → React Hook Form
  → Không dùng useState cho form phức tạp

UI/ephemeral state         → useState / useReducer
  → Modal open, tab active, loading spinner
```

### Edge cases state management

**Race condition với async updates**:
```
User navigates away trước khi API call complete
→ Component unmount nhưng setState vẫn chạy
→ Solution: Cleanup với AbortController hoặc React Query tự handle
```

**Stale closure trong useEffect**:
```
useEffect(() => {
  // count ở đây là giá trị cũ (stale closure)
  setTimeout(() => console.log(count), 1000)
}, []) // ← thiếu dependency

// Fix:
}, [count]) // hoặc dùng useRef
```

**Zustand với immer cho nested updates**:
```ts
// Không dùng immer → dễ mutation bug
setState(state => ({ ...state, user: { ...state.user, name: 'new' } }))

// Dùng immer → clear hơn
setState(produce(state => { state.user.name = 'new' }))
```

---

## 4. Offline First — Deep Dive

### Correct offline-first architecture

```
UI Layer
  → Observe Room/SQLite (Flow/LiveData) — luôn read từ local
  → User action → write local first → queue sync

Repository Layer
  → Read: local DB as source of truth
  → Write: save locally với flag isSynced=false, enqueue WorkManager job

Sync Engine (background)
  → Runs independently của UI
  → Check pending uploads → process với retry + backoff
  → Check server changes → download → merge → notify UI

Local DB (Room/SQLite/Isar)
  → Single source of truth
  → Tất cả queries từ local, không block UI
```

### Sync strategies by data priority

```
Priority HIGH (không được mất):
  → User-created content: posts, orders, form submissions
  → Immediate retry với exponential backoff
  → Persist queue qua app restart (WorkManager/BGTaskScheduler)
  → Alert user nếu sync fail sau X giờ

Priority MEDIUM:
  → User preferences, settings
  → Retry khi có network, không urgent

Priority LOW (có thể lose):
  → Analytics events, read receipts, view counts
  → Best-effort, fail silently
```

### Conflict resolution strategies

**Last-write-wins (LWW)**:
```
Cách hoạt động: Server accept record có timestamp mới hơn
Tốt cho: Settings, preferences, profile updates
Nguy hiểm cho: Financial data, inventory — có thể mất data
```

**Server-wins**:
```
Client luôn overwrite bằng server version khi sync
Tốt cho: Read-mostly data (product catalog)
```

**Client-wins**:
```
Server accept tất cả changes từ client
Tốt cho: Draft content
```

**Merge (field-level)**:
```
User A offline: thay đổi firstName
User B online: thay đổi lastName
Merge result: cả hai thay đổi được giữ lại (khác field)
Conflict: cả hai thay đổi cùng field → cần strategy khác
```

**User-assisted**:
```
App hiện conflict resolution UI: "Which version do you want to keep?"
Tốt cho: Collaborative apps, document editing
```

**CRDTs (Conflict-free Replicated Data Types)**:
```
Data structures designed để merge tự động, không cần coordination
Examples: Yjs (text editing), Automerge
Phức tạp nhưng tốt nhất cho real-time collaboration
```

### Offline sync edge cases

**Partial sync failure**:
```
Sync 100 records → fail ở record 50 → retry toàn bộ hay chỉ từ 50?
Solution: Checkpoint-based sync + idempotent operations
Server endpoint: POST /sync/batch với idempotency key
```

**Clock skew**:
```
Device clock sai → LWW conflict resolution sai
Solution: Dùng server timestamp, không trust client clock
Server: SET updated_at = NOW() không nhận timestamp từ client
```

**Deleted while offline**:
```
User A: delete record offline
User B: update same record online
User A sync: record không tồn tại trên server
Solution: Soft delete (deleted_at timestamp) không xóa cứng
Server giữ tombstone record đủ lâu (e.g. 30 ngày)
```

**Large attachment offline**:
```
User attach 50MB file khi offline
File không thể sync ngay → queue riêng
Show progress khi sync, cần thể cancel
Solution: Chunked upload, resumable upload protocol
```

**Incremental sync**:
```
Thay vì sync toàn bộ data mỗi lần:
GET /api/changes?since=2024-01-15T10:00:00Z
Server trả về chỉ records thay đổi sau timestamp đó
Client track lastSyncedAt locally
```

---

## 5. Navigation

### React Navigation — patterns hay dùng

```tsx
// Stack trong Tab (pattern phổ biến)
<Tab.Navigator>
  <Tab.Screen name="Home" component={HomeStack} />
  <Tab.Screen name="Profile" component={ProfileStack} />
</Tab.Navigator>

// Deep link config
const linking = {
  prefixes: ['myapp://', 'https://myapp.com'],
  config: {
    screens: {
      Home: 'home',
      Product: 'product/:id',
      Profile: { path: 'profile/:userId', parse: { userId: Number } }
    }
  }
}
```

### Navigation edge cases

**Back button trên Android**:
```
Hardware back button phải behave đúng
- Modal: dismiss modal, không pop stack
- Form với unsaved changes: confirm dialog
- Root screen: minimize app, không exit
```

**Deep link khi app chưa open**:
```
App → killed → nhận deep link → cần restore navigation state đúng
Solution: Link từ notification phải handle cold start vs warm start
Test cả 2 scenarios
```

**Navigation và authentication state**:
```
Pattern: Dùng conditional navigator dựa trên auth state
if (isAuthenticated) render <AppNavigator />
else render <AuthNavigator />
Transition giữa 2 navigators phải smooth, không flicker
```

---

## 6. Performance

### React Native — New Architecture (Fabric + JSI)

**Vấn đề cũ (Bridge)**: JS ↔ Native communication qua JSON serialization → overhead, async only

**New Architecture (React Native 0.76+)**:
- JSI: Direct JS ↔ C++ call, không cần serialize/deserialize
- Fabric: Synchronous rendering, tốt hơn cho animations
- TurboModules: Lazy loading native modules

**Khi nào enable New Architecture**: Kiểm tra tất cả dependencies support Fabric trước. Nhiều thư viện cũ chưa support.

### FlatList vs FlashList

```
FlatList: Built-in, đủ dùng cho list < 500 items
FlashList (Shopify): 
  - Recycle cell views (như RecyclerView trên Android)
  - 10x nhanh hơn FlatList trên list lớn
  - Cần estimatedItemSize để accurate
  - Dùng cho: Chat list, feed, product list
```

### Image performance

```
React Native Image pitfalls:
- Không dùng inline object style trong Image (re-create mỗi render)
- Luôn specify width/height để tránh layout thrash
- Dùng FastImage thay Image: caching tốt hơn, smoother loading
- Resize ảnh trên server trước khi deliver (CDN transform)
- Progressive JPEG cho ảnh lớn
```

### Memory management

```
Common leaks trong React Native:
- Event listeners không cleanup trong useEffect
- setInterval / setTimeout không clear
- WebSocket không close
- LottieView trên background tab

Fix pattern:
useEffect(() => {
  const sub = eventEmitter.addListener('event', handler)
  return () => sub.remove() // cleanup
}, [])
```

---

## 7. Security Mobile

### Lưu trữ sensitive data

```
❌ KHÔNG dùng:
  AsyncStorage (không encrypted, accessible nếu device rooted)
  Zustand persisted (cũng dùng AsyncStorage)
  SecureStore (Expo) trên Android không truly secure nếu device rooted

✅ NÊN dùng:
  iOS Keychain → passwords, tokens, private keys
  Android Keystore → cryptographic keys
  MMKV với encryption key (stored in Keychain/Keystore)

React Native: react-native-keychain
Expo: expo-secure-store
```

### Certificate pinning

```
Ngăn MITM attack, đặc biệt quan trọng cho banking, finance

React Native: react-native-ssl-pinning
Android: OkHttp Certificate Pinner
iOS: URLSession với custom URLSessionDelegate

Edge case: Certificate expire → app bị broken nếu không có backup pins
Solution: Pin 2 certs (current + next), rotate overlap period
```

### Jailbreak/Root detection

```
react-native-jail-monkey
Tuy nhiên: Detection có thể bypass, không dựa hoàn toàn vào đây
Defense-in-depth: Detect + limit features + extra server-side validation
```

### Deep link security

```
URL scheme (myapp://) có thể bị hijack bởi malicious app
Solution: Dùng Universal Links (iOS) / App Links (Android)
  → HTTPS URLs, verify ownership qua apple-app-site-association / assetlinks.json
  → Malicious app không thể hijack HTTPS domain
```

---

## 8. Push Notifications — Edge Cases

### Flow đầy đủ

```
1. Request permission (iOS phải xin, Android 13+ phải xin)
2. Nhận FCM/APNs token
3. Send token lên server kèm: userId, deviceId, platform, appVersion
4. Server lưu, dùng để gửi notification
5. Token refresh → app phải update server (onTokenRefresh callback)
6. User logout → server phải invalidate/delete token
```

### Edge cases notifications

**Token stale sau reinstall**:
```
User uninstall → reinstall → nhận new token
Old token → FCM trả về NotRegistered error
Server phải xóa old token khi nhận error này
```

**Multiple devices cùng user**:
```
User login trên iPhone và iPad
Server cần lưu multiple tokens per user
Notification gửi đến tất cả devices? Hay chỉ active nhất?
Cần business logic rõ ràng
```

**Silent push notification** (background update):
```
iOS: content-available: 1, không có alert
App được wake up 30 giây để fetch data
iOS limit số lần per ngày (~3 lần, không documented)
Không reliable cho critical updates
```

**Notification khi app foreground**:
```
iOS: Notification bị suppress khi app foreground (mặc định)
Fix: willPresentNotification delegate để show banner
Android: Notification hiển thị bình thường
```

---

## 9. App Store & CI/CD

### Build variants đầy đủ

```
Dev          → Local dev, debug tools, mock data (optional), dev API
Staging      → Internal testing, staging API, crash reporting enabled
Production   → App Store/Play Store, prod API, obfuscation, no debug logs
```

Mỗi variant cần config riêng: API URL, analytics key, feature flags.

### CI/CD pipeline mobile

```
Code push
  ├── Lint + Type check (tsc --noEmit)
  ├── Unit tests (Jest)
  ├── E2E tests (Detox/Maestro) — optional, chậm
  ├── Build (EAS Build / Fastlane / Codemagic)
  │   ├── iOS: xcodebuild, code signing với Match
  │   └── Android: Gradle, keystore
  └── Upload artifacts
      ├── iOS: TestFlight
      └── Android: Play Store Internal Track

Manual approval → Production release
```

### OTA Updates (React Native only)

```
EAS Update / CodePush:
  - Update JS bundle + assets, không cần App Store review
  - Không thể update native code (new native modules, platform config)
  - Apple policy: không được change app behavior fundamentally
  - Good for: bug fixes, content updates, minor feature tweaks

Rollout strategy:
  Stage 1: 5% users (staging testers)
  Stage 2: 20% users (monitor crash rate)
  Stage 3: 100% (if metrics good)

Rollback: ngay lập tức nếu cần, không chờ App Store
```

---

---

## 11. Performance Profiling

### React Native — Flipper + DevTools

```
Flipper (Meta's debugging tool):
  Install: npx react-native doctor → check Flipper installed
  Plugins:
    React DevTools:   Component tree, props, hooks state
    Network:          HTTP requests/responses (intercepts fetch)
    Hermes Debugger:  JS execution, breakpoints
    React Native Perf Monitor: FPS, JS thread, UI thread
    Layout Inspector: View hierarchy, measure renders

  Key metrics to watch:
    JS thread:  Should be < 50ms per frame (60fps = 16ms budget)
    UI thread:  < 16ms per frame
    RAM:        Alert if > 512MB (OOM risk on low-end devices)
    FPS:        Target 60fps, alert < 55fps sustained

React DevTools Profiler:
  Start profiling → interact → stop → see component render times
  Flame graph: Width = time, depth = component tree
  Look for: Components rendering when they shouldn't (missed memo)
```

### Flutter — DevTools

```dart
// Flutter DevTools (dart devtools) includes:
// Performance view:  Frame rendering timeline, shader compilation
// Memory view:       Heap allocation, leak detection
// CPU profiler:      Which Dart code is most expensive
// Widget inspector:  Layout tree, paint bounds

// In-app performance overlay:
MaterialApp(
  showPerformanceOverlay: kDebugMode,  // Shows GPU/CPU frame bars
  // Green: < 16ms (60fps)  Yellow: 16-32ms  Red: > 32ms
)

// Profile mode build (not debug, not release — closest to prod perf):
// flutter run --profile
// Use for: accurate performance numbers
// Debug mode: 5-10x slower than release (VM interpreter)
```

### iOS — Instruments

```
Xcode → Product → Profile → Instruments

Key templates:
  Time Profiler:    CPU usage per function, find hot paths
  Allocations:      Memory allocation over time, find leaks
  Leaks:            Detect reference cycles (retain cycles in ObjC/Swift)
  Core Animation:   GPU rendering, off-screen rendering (red = expensive)
  Network:          All URL requests with timing

Common issues found via Instruments:
  Off-screen rendering: Shadow, cornerRadius+clips, masks → GPU layer
    Fix: .layer.shouldRasterize = true for static views
  Overdraw: Multiple layers painting same pixels
    Fix: Set backgroundColor on views, use Xcode's Color Blended Layers
  Retain cycles: ARC not freeing objects
    Fix: [weak self] in closures

Time Profiler workflow:
  1. Run app on REAL device (not simulator — different CPU)
  2. Record 30 seconds of slow interaction
  3. Filter: Hide System Libraries → see only app code
  4. Find heaviest stack trace → optimize
```

### Android — Android Profiler

```
Android Studio → View → Tool Windows → Profiler

4 profilers:
  CPU Profiler:
    Method tracing: Record all method calls, find slow methods
    System Trace: UI thread, RenderThread, measure/layout/draw
    Target: Main thread tasks < 16ms (60fps), < 8ms (120fps)

  Memory Profiler:
    Heap dump: See all allocated objects
    Allocation recording: Track where objects are created
    Look for: Objects not being GC'd (potential leaks)

  Network Profiler:
    Timeline of all network requests
    Request/response details
    Find: Requests on main thread, redundant API calls

  Energy Profiler:
    CPU, GPS, network usage → battery impact
    Important for background services

Key Android-specific issues:
  RecyclerView not recycling: Check ViewHolder reuse
  Bitmap too large: Decode at display size, not original
  Main thread I/O: StrictMode.setThreadPolicy to detect
  Layout inflation slow: ViewStub for complex conditional views
```

---

## 12. Background Processing

### iOS — BGTaskScheduler

```swift
// iOS 13+ — required for background work > 30s
// Must register in AppDelegate BEFORE app finishes launching

// Step 1: Register task identifier in Info.plist
// BGTaskSchedulerPermittedIdentifiers: com.app.data-refresh

// Step 2: Register handler at launch
BGTaskScheduler.shared.register(
    forTaskWithIdentifier: "com.app.data-refresh",
    using: .main
) { task in
    self.handleDataRefresh(task: task as! BGAppRefreshTask)
}

// Step 3: Schedule task
func scheduleDataRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: "com.app.data-refresh")
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)  // 15 min
    try? BGTaskScheduler.shared.submit(request)
}

// Step 4: Handle task execution
func handleDataRefresh(task: BGAppRefreshTask) {
    // Must complete or cancel within time limit (~30 seconds)
    task.expirationHandler = {
        // Called if time runs out — cancel work immediately
        syncOperation.cancel()
    }

    Task {
        do {
            try await syncData()
            task.setTaskCompleted(success: true)
        } catch {
            task.setTaskCompleted(success: false)
        }
        // Re-schedule for next run
        scheduleDataRefresh()
    }
}

// Types:
// BGAppRefreshTask: Short background fetch (< 30s)
// BGProcessingTask: Long processing (minutes, requires charging + WiFi configurable)
```

### Android — WorkManager

```kotlin
// WorkManager: battery-efficient background work (API 14+)
// Survives app death and device restart

// Define work
class DataSyncWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        return try {
            syncRepository.syncData()
            Result.success()
        } catch (e: Exception) {
            // Retry up to 3 times with backoff
            if (runAttemptCount < 3) Result.retry()
            else Result.failure()
        }
    }
}

// Schedule periodic work
val constraints = Constraints.Builder()
    .setRequiredNetworkType(NetworkType.CONNECTED)
    .setRequiresBatteryNotLow(true)      // Don't run on low battery
    .build()

val syncRequest = PeriodicWorkRequestBuilder<DataSyncWorker>(
    repeatInterval = 15, repeatIntervalTimeUnit = TimeUnit.MINUTES
)
    .setConstraints(constraints)
    .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
    .build()

WorkManager.getInstance(context).enqueueUniquePeriodicWork(
    "DataSync",
    ExistingPeriodicWorkPolicy.KEEP,  // Don't reschedule if already queued
    syncRequest
)

// Check work status
WorkManager.getInstance(context)
    .getWorkInfoByIdLiveData(syncRequest.id)
    .observe(this) { info ->
        if (info.state == WorkInfo.State.SUCCEEDED) {
            Log.d("Sync", "Work completed successfully")
        }
    }
```

### React Native — background tasks

```typescript
// @react-native-community/background-fetch (cross-platform)
import BackgroundFetch from 'react-native-background-fetch'

BackgroundFetch.configure({
  minimumFetchInterval: 15,     // minutes (iOS may override)
  enableHeadless: true,         // Android: run when app killed
  forceAlarmManager: false,     // Android: use AlarmManager (exact timing)
  stopOnTerminate: false,       // Android: continue after app terminated
  startOnBoot: true,            // Android: restart on device boot
}, async (taskId) => {
  console.log('[BackgroundFetch] taskId:', taskId)
  await syncData()
  BackgroundFetch.finish(taskId)   // REQUIRED: signal iOS task completion
}, (taskId) => {
  console.log('[BackgroundFetch] TIMEOUT taskId:', taskId)
  BackgroundFetch.finish(taskId)   // REQUIRED: even on timeout
})

// Push notification + silent push → trigger background work
// iOS: content-available: 1 → wakes app for ~30s
// Android: high priority FCM message → wakes app
```


## Checklist mobile architecture

> 🔴 MUST = block ship | 🟠 SHOULD = fix trước prod | 🟡 NICE = tech debt

🔴 MUST:
- [ ] Sensitive data (tokens, keys) trong Keychain/Keystore — KHÔNG AsyncStorage
- [ ] Build variants tách biệt: dev/staging/prod với config riêng
- [ ] Deep linking không dùng custom URL scheme (`myapp://`) — dùng Universal Links / App Links
- [ ] Không log sensitive data (token, password, PII)

🟠 SHOULD:
- [ ] Clean Architecture: UI không biết về DB, Domain không biết về framework
- [ ] Offline state handled: show cached data, queue writes, sync khi online
- [ ] Conflict resolution strategy documented nếu offline-first
- [ ] Push notification: token lifecycle (refresh, logout invalidate), multiple devices
- [ ] Performance baseline: cold start < 2s, frames ≥ 60fps
- [ ] Accessibility: Dynamic Type support, VoiceOver/TalkBack tested

🟡 NICE:
- [ ] OTA update strategy (React Native: EAS Update, rollout stages)
- [ ] Certificate pinning (chỉ cần cho finance/banking)
- [ ] Jailbreak/root detection (layered defense, không rely hoàn toàn)
- [ ] App size optimization (hermes, ProGuard, asset compression)
