# Registro de implementación

Todo lo que se construyó, en orden cronológico. Sirve de referencia para entender qué existe, por qué se tomaron ciertas decisiones y qué corregir si algo falla.

---

## Fase 1 — Infraestructura base

### Dependencias instaladas
```bash
npm install @supabase/supabase-js @supabase/ssr
npm install stripe @stripe/stripe-js
npm install react-hook-form @hookform/resolvers zod
npm install date-fns lucide-react
npx shadcn@latest init
npx shadcn@latest add button input label textarea select checkbox form card separator tabs sheet badge alert skeleton sonner dialog dropdown-menu table avatar pagination
```

### Archivos creados

**`lib/supabase/client.ts`**
Cliente Supabase para componentes del lado del browser (`createBrowserClient`).

**`lib/supabase/server.ts`**
Cliente Supabase para Server Components y API routes. Lee las cookies de Next.js para la sesión del usuario.

**`lib/supabase/admin.ts`**
Cliente con `SUPABASE_SERVICE_ROLE_KEY` — bypasa todas las políticas RLS. *Solo se importa en API routes (nunca en código cliente).*

**`lib/stripe/client.ts`**
Instancia de Stripe con `apiVersion: '2026-02-25.clover'` (versión actual del SDK v20).

**`lib/stripe/webhook-handlers.ts`**
Handlers por evento de Stripe:
- `handleCheckoutSessionCompleted`: crea `orders` → `order_items` → genera `license_key` → inserta en `licenses` → registra evento `issued`
- `handleInvoicePaymentSucceeded`: renueva `expires_at` en suscripciones
- `handleSubscriptionDeleted`: marca licencia como `expired`

> **Nota Stripe v20:** `invoice.subscription` ya no existe. Ahora es `invoice.parent?.subscription_details?.subscription`.

**`lib/licenses/generate.ts`**
```typescript
// Genera "ABCDE-FGHIJ-KLMNO-PQRST" — 20 chars hex aleatorios
export function generateLicenseKey(): string
export async function generateUniqueLicenseKey(checkExists, maxAttempts = 10): Promise<string | null>
```
La clave es aleatoria pura; toda la semántica (expiración, producto, tipo) vive en la DB.

**`lib/utils/formatters.ts`**
- `formatCurrency(cents)` — convierte centavos a string "$XX.XX"
- `formatDate(isoString)` — "Mar 6, 2025"
- `formatDateTime(isoString)` — con hora
- `toSlug(text)` — normaliza a slug URL

**`lib/utils/validators.ts`**
Schemas Zod exportados:
- `productSchema` / `ProductFormValues`
- `licensePlanSchema` / `LicensePlanFormValues`
- `profileSchema` / `ProfileFormValues`
- `loginSchema` / `LoginFormValues`
- `registerSchema` / `RegisterFormValues`
- `verifyLicenseSchema`, `activateLicenseSchema`, `deactivateLicenseSchema`
- `couponSchema`, `reviewSchema`

> **Fix importante:** `status: z.enum([...]).default('draft')` causaba errores con react-hook-form porque `.default()` hace el tipo de input `... | undefined`. Se eliminó el `.default()` y el default se pone en `useForm({ defaultValues })`.

**`types/database.ts`**
Tipos completos de todas las tablas de Supabase escritos manualmente (equivalente a `supabase gen types typescript`). Cada tabla tiene `Relationships: []` — esto es requerido por `@supabase/supabase-js` v2.98.0 (`GenericTable`), sin él los tipos `Insert`/`Update` resuelven a `never`.

**`types/index.ts`**
Row helpers, composite types para joins (`LicenseWithProduct`, `LicenseWithActivations`, `OrderWithItems`), constantes de etiquetas/colores, tipos de respuesta de la API.

**`middleware.ts`**
- Protege `/dashboard/**` y `/admin/**`
- Si no hay sesión: redirige a `/auth/login?redirectTo=<path>`
- Si hay sesión pero rol no es admin: redirige `/admin/**` → `/dashboard`

**`supabase/migration.sql`**
SQL completo para ejecutar en Supabase una sola vez:
- 9 tablas con constraints y checks
- Trigger `on_auth_user_created` → función `handle_new_user()` que inserta automáticamente en `profiles`
- Función `increment_coupon_usage()`
- Índices de rendimiento para búsquedas críticas
- Políticas RLS para cada tabla

---

## Fase 2 — Auth + Layout

**`app/layout.tsx`**
Root layout con fuentes Geist, `<Header />`, `<Footer />`, `<Toaster />` (sonner).

**`components/layout/Header.tsx`** (Server Component)
Muestra nav pública; si hay sesión, muestra dropdown con Dashboard / Profile / Admin (si es admin).

**`components/layout/HeaderSignOut.tsx`** (Client Component)
Botón de logout que llama `supabase.auth.signOut()` + `router.refresh()`.

**`app/auth/login/page.tsx`**
Formulario con `react-hook-form` + `zodResolver(loginSchema)`. Llama `supabase.auth.signInWithPassword`.

**`app/auth/register/page.tsx`**
Igual, con `registerSchema`. Incluye `full_name` en `raw_user_meta_data` del usuario (el trigger lo copia a `profiles`).

**`app/auth/callback/route.ts`**
GET handler para el code exchange de Supabase OAuth/magic link (`supabase.auth.exchangeCodeForSession(code)`).

---

## Fase 3 — Admin: Productos y Planes

**`app/admin/layout.tsx`**
Sidebar fijo con navegación: Dashboard / Productos / Licencias / Órdenes / Cupones / Reviews / Usuarios. Verifica `profile.role === 'admin'` — si no redirige `/dashboard`.

**`app/admin/AdminNavLink.tsx`** (Client Component)
Link activo que usa `usePathname` para resaltar la sección actual.

**`app/admin/page.tsx`**
Stats en paralelo (Promise.all): total revenue, licencias activas, órdenes completadas, productos, clientes. Lista las 5 órdenes más recientes.

**`app/admin/products/page.tsx`**
Tabla de productos con columna de conteo de planes. Botones: Editar y Planes.

**`app/admin/products/new/page.tsx`** + **`app/admin/products/[id]/edit/page.tsx`**
Usan `<ProductForm />` para crear/editar. Submit llama directamente al cliente Supabase (admin ya está autenticado en Server Component).

**`app/admin/products/[id]/plans/page.tsx`**
Gestión de planes del producto usando `<PlansManager />`.

**`components/admin/ProductForm.tsx`**
Form con shadcn `<Form />`, `<FormField />`. Campos: nombre, slug (auto-generado del nombre), tipo, estado, thumbnail URL, descripciones.

**`components/admin/LicensePlanForm.tsx`**
Form para crear/editar planes: nombre, tipo, precio, moneda, billing interval, trial_days, max_activations, features (array JSON).

**`components/admin/PlansManager.tsx`**
Client Component que lista los planes existentes del producto con botones de editar/eliminar, y formulario inline para agregar uno nuevo.

---

## Fase 4 — Storefront público

**`app/page.tsx`**
Hero con CTA, grid de categorías, sección de productos destacados (últimos 6 publicados con `license_plans`).

**`components/store/ProductCard.tsx`**
Card con thumbnail, badge de tipo, nombre, descripción corta, conteo de planes y precio mínimo ("desde $X.XX").

**`components/store/PlanCard.tsx`**
Card de plan individual: nombre, badge de tipo, precio, lista de features, max_activations. Resalta cuando está seleccionado.

**`components/store/PlanSelector.tsx`** (Client Component)
Gestiona `selectedPlanId`, campo de cupón, y el botón de compra. Llama `POST /api/checkout`:
- Si recibe `{ licenseKey }` → trial activado, muestra mensaje de éxito
- Si recibe `{ url }` → redirige a Stripe Checkout

**`app/products/page.tsx`**
Catálogo con filtro por tipo usando Tabs como links (`/products?type=software`).

**`app/products/[slug]/page.tsx`**
Detalle de producto: thumbnail, tipo, descripción, `<PlanSelector />`. Incluye `generateMetadata`.

---

## Fase 5 — Stripe + Generación de licencias

**`app/api/checkout/route.ts`**
```
POST /api/checkout
Body: { productId, planId, couponCode? }
```
1. Verifica sesión
2. Valida producto + plan activo
3. Si `plan.price === 0 || plan.type === 'trial'` → genera licencia directamente (sin Stripe), retorna `{ licenseKey }`
4. Si no → valida cupón, calcula descuento, crea Stripe Checkout Session, retorna `{ url }`

**`app/api/webhooks/stripe/route.ts`**
Lee raw body, verifica firma HMAC con `stripe.webhooks.constructEvent`. Delega a handlers en `lib/stripe/webhook-handlers.ts`.

**`app/api/coupons/validate/route.ts`**
```
POST /api/coupons/validate
Body: { code, planPrice }
```
Verifica que el cupón esté activo, no expirado, no agotado, y que el precio mínimo se cumpla. Retorna `{ valid, coupon: { discountAmount } }`.

**`components/store/CouponInput.tsx`**
Input con botón "Apply". Hace POST a `/api/coupons/validate` y muestra el descuento aplicado.

---

## Fase 6 — API pública de licencias v1

**`app/api/v1/licenses/verify/route.ts`**
```
POST /api/v1/licenses/verify
```
1. Rate limit (60 req/min/IP, en memoria)
2. Busca la clave por índice `idx_licenses_license_key`
3. Si la licencia expiró pero status no está actualizado → actualiza en DB + registra evento
4. Si se provee `machine_id` → verifica activación activa, actualiza `last_seen_at`
5. Registra evento `verified`
6. Cachea respuestas negativas 30 s (`public, max-age=30, s-maxage=30`), positivas: `no-store`

**`app/api/v1/licenses/activate/route.ts`**
```
POST /api/v1/licenses/activate
Body: { license_key, machine_id, machine_name? }
```
1. Rate limit (30 req/min/IP)
2. Verifica licencia activa y `activation_count < max_activations`
3. Upsert en `license_activations` (reactivación si ya existía inactive)
4. Incrementa `activation_count`
5. Registra evento `activated`

**`app/api/v1/licenses/deactivate/route.ts`**
```
POST /api/v1/licenses/deactivate
Body: { license_key, machine_id }
```
1. Rate limit
2. Marca `license_activations.is_active = false`
3. Decrementa `activation_count`
4. Registra evento `deactivated`

---

## Fase 7 — Dashboard de usuario

**`app/dashboard/layout.tsx`**
Sidebar con links: Overview / Licenses / Orders / Profile. Verifica sesión.

**`app/dashboard/page.tsx`**
Overview: stats (licencias activas, total órdenes), últimas 3 licencias (LicenseCard), últimas 5 órdenes con badge de estado.

**`app/dashboard/licenses/page.tsx`**
Grid de todas las licencias del usuario usando `<LicenseCard />`.

**`app/dashboard/licenses/[id]/page.tsx`**
Detalle de licencia:
- `<LicenseKeyDisplay />` — muestra la clave con botón copiar y badge de estado
- Card con detalles del plan (tipo, activaciones, expiración, fecha de emisión)
- `<ActivationList />` — lista de máquinas activas con botón desactivar

**`app/dashboard/orders/page.tsx`**
Lista de órdenes con producto(s), estado y total. Cada row linkea al detalle.

**`app/dashboard/orders/[id]/page.tsx`**
Detalle de orden: items con thumbnail, plan, precio. Resumen con subtotal, descuento, total, fecha, ref de Stripe.

**`app/dashboard/profile/page.tsx`** (Client Component)
Carga `profiles.full_name` desde Supabase y permite editarlo.

**`components/licenses/LicenseCard.tsx`**
Card con product name, plan name + tipo, badge de estado, conteo de activaciones, fecha de expiración. Linkea a `/dashboard/licenses/[id]`.

**`components/licenses/LicenseKeyDisplay.tsx`**
Muestra la clave en `<code>` con botón de copiar (usa `navigator.clipboard`). Badge de estado con colores.

**`components/licenses/ActivationList.tsx`**
Lista máquinas con `last_seen_at`. Botón de desactivar llama `POST /api/v1/licenses/deactivate` y hace `router.refresh()`.

---

## Fase 8 — Admin panel completo

### API routes de administración

**`app/api/admin/licenses/[id]/revoke/route.ts`**
```
POST /api/admin/licenses/:id/revoke
Body: { reason: string }
```
Solo admin. Actualiza `status = 'revoked'`, `revoked_at`, `revocation_reason`. Registra evento.

**`app/api/admin/licenses/[id]/suspend/route.ts`**
```
POST /api/admin/licenses/:id/suspend
```
Toggle suspend/reactivate. Si está `suspended` → vuelve a `active`. Registra evento `suspended` o `reactivated`.

### Páginas admin

**`app/admin/licenses/page.tsx`**
Búsqueda por `license_key` (ILIKE), filtro por status. Tabla con key, producto, status badge, activaciones, fechas.

**`app/admin/licenses/[id]/page.tsx`**
Vista completa de una licencia:
- Botones de acción: Suspend (toggle) y Revoke (sólo si no está revocada)
- Card de detalles del plan
- Lista de dispositivos activos con IP
- Historial de eventos cronológico (más reciente primero)

**`app/admin/orders/page.tsx`**
Tabla de todas las órdenes con filtro por status. Muestra ID truncado, productos, badge status, total, fecha.

**`app/admin/coupons/page.tsx`**
Tabla de cupones con botón de activar/desactivar. Botón "New coupon" abre `<CreateCouponDialog />`.

**`app/admin/reviews/page.tsx`**
Dos secciones: "Pending approval" (con botón Approve) y "Approved". Muestra producto, rating, título, cuerpo.

**`app/admin/customers/page.tsx`**
Lista de todos los usuarios con `role = 'customer'`: nombre, email, fecha de registro.

### Componentes admin creados

| Componente | Función |
|---|---|
| `RevokeDialog` | Dialog para revocar con campo de motivo obligatorio |
| `SuspendButton` | Botón toggle suspend/reactivate |
| `CreateCouponDialog` | Dialog para crear cupón (tipo, valor, max_uses, expires_at) |
| `ToggleCouponButton` | Botón para activar/desactivar cupón |
| `ApproveReviewButton` | Botón para aprobar review pendiente |

### Bug corregido en admin/page.tsx
`formatCurrency` ya divide entre 100 internamente. El código original hacía `formatCurrency(valor / 100)` lo que mostraba precios 100 veces más pequeños. Corregido a `formatCurrency(valor)`.

---

## Fase 9 — Escalabilidad y rendimiento

### Índices en DB (`supabase/migration.sql`)
```sql
idx_licenses_license_key   -- búsqueda primaria O(log n) en todas las rutas v1
idx_licenses_user_id
idx_licenses_status
idx_activations_license_id
idx_activations_machine_id
idx_events_license_id
idx_orders_user_id
idx_order_items_order_id
idx_reviews_product_id
```

### Cache en `/api/v1/licenses/verify`
```
valid: true  → Cache-Control: no-store
valid: false → Cache-Control: public, max-age=30, s-maxage=30, stale-while-revalidate=10
```
Las respuestas positivas nunca se cachean (el estado puede cambiar). Las negativas (revocada, no encontrada, expirada) se cachean 30 s en el edge (Vercel CDN, Cloudflare, etc.), reduciendo carga en la DB bajo ataques o picos.

### Script de load test (`scripts/load-test.mjs`)
```bash
node scripts/load-test.mjs TU-LICENSE-KEY 20 15
# [concurrency=20, duration=15s]
# Reporta: RPS, min, avg, p50, p95, p99, max
# Objetivo: p95 < 100ms
```

---

## Decisiones de diseño relevantes

### ¿Por qué no usar Supabase Gen Types?
Los tipos se escribieron manualmente en `types/database.ts` para control total y porque el entorno de desarrollo no tenía acceso a la CLI de Supabase. Cuando el proyecto tenga Supabase configurado en local, se puede reemplazar con `supabase gen types typescript --project-id XXX > types/database.ts`.

### ¿Por qué `createAdminClient` en los webhooks?
El webhook de Stripe corre en una API route pero **no tiene sesión de usuario**. Las políticas RLS de Supabase bloquearían los inserts en `licenses` y `orders`. El `service_role` bypasa RLS totalmente, lo que es seguro porque el código está en el servidor y la clave nunca llega al cliente.

### ¿Por qué rate limiting en memoria para la API pública?
Es suficiente para desarrollo y uso moderado. En producción con múltiples instancias (Vercel serverless), cada instancia tiene su propio mapa y el rate limit no se comparte. La solución correcta en producción es Upstash Redis con `@upstash/ratelimit`, que es stateless y distribuido.

### ¿Por qué trials sin Stripe?
Los trials son gratuitos — no hay nada que cobrar. La ruta `/api/checkout` detecta `plan.price === 0 || plan.type === 'trial'` y genera la licencia directamente usando el admin client. Esto simplifica el flujo enormemente (no hay redirects, no hay webhooks) y la respuesta incluye `{ licenseKey }` directamente.

### Formato de license key
`XXXXX-XXXXX-XXXXX-XXXXX` — 20 caracteres hex en mayúsculas, agrupados en 4 bloques. La clave NO codifica metadatos (a diferencia de JWT o claves con checksum). Toda la semántica vive en la DB, lo que permite revocar, transferir o modificar licencias sin invalidad la clave.

---

## Sesión 3 — Rebrand + entrega de archivos + Google OAuth + páginas legales

### Rebrand LicenseHub → DigiStore
`sed -i 's/LicenseHub/DigiStore/g'` sobre todos los `.tsx`, `.ts` y `.md`. Afectó: `Header`, `Footer`, `app/layout.tsx`, `terms/page.tsx`, `app/auth/register/page.tsx`.

### Google OAuth — `components/auth/GoogleButton.tsx`
Componente cliente reutilizable. Llama `supabase.auth.signInWithOAuth({ provider: 'google' })`. Redirige a Supabase callback y luego al `redirectTo` original. Añadido a `/auth/login` y `/auth/register` con separador "or". Google OAuth es gratis; los $300 de crédito de GCP son para otros servicios.

### Pages legales — `app/terms/page.tsx` + `app/privacy/page.tsx`
Terms of Service incluye sección destacada (fondo ámbar) con exención de responsabilidad explícita para productos de trading algorítmico. Footer actualizado con links.

### `middleware.ts` → `proxy.ts` (Next.js 16)
Next.js 16 deprecó el nombre `middleware` en favor de `proxy`. Migrado con el codemod oficial: `npx @next/codemod@canary middleware-to-proxy .`. La función también se renombró de `middleware()` a `proxy()`.

### Entrega de archivos — flujo completo
**`types/database.ts`**: campo `file_path: string | null` añadido a `products` (Row, Insert, Update).

**`components/admin/FileUpload.tsx`**: componente drag & drop para upload a Supabase Storage bucket `product-files` (privado). Acepta PDF, ZIP, PY, EX4/EX5, EXE y más. Límite 200MB. Si hay archivo existente, lo reemplaza antes de subir el nuevo.

**`components/admin/ProductForm.tsx`**: integra `FileUpload`. El archivo se sube directamente desde el cliente a Storage; el `file_path` resultante se pasa como segundo argumento al server action `onSubmit(values, filePath)`. Para productos nuevos (sin `id` todavía), el campo de upload muestra el mensaje "primero guarda el producto".

**`app/admin/products/new/page.tsx`** y **`[id]/edit/page.tsx`**: server actions actualizados para aceptar `filePath: string | null` y guardarlo en `products.file_path`.

**`app/api/downloads/[productId]/route.ts`**: `GET` protegido. Verifica sesión → busca `file_path` del producto → verifica que el usuario tiene licencia `active` o `trial` para ese producto → genera URL firmada de Supabase Storage (expira en 1 hora, fuerza descarga) → redirige. Sin URL firmada válida el archivo es inaccesible.

**`app/dashboard/licenses/[id]/page.tsx`**: añadido botón "Download product" que aparece solo cuando la licencia está activa/trial y el producto tiene archivo. Llama al endpoint de descarga.

**`supabase/migration.sql`** (append): `ALTER TABLE products ADD COLUMN IF NOT EXISTS file_path TEXT`. El bucket `product-files` hay que crearlo manualmente en Supabase Dashboard → Storage (privado, sin acceso público).

**`README.md`**: reescrito completamente. Describe DigiStore como tienda de productos digitales. Incluye ejemplos de integración en Python y MQL5 para verificación de licencias.
