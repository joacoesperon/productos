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

---

## Sesión 4 — Debug admin + RLS fix + mejoras UX + eliminar productos y planes

Esta sesión fue principalmente de corrección de errores críticos que impedían el funcionamiento del panel de administración y la tienda pública. Se descubrió un bug sistémico en RLS (Row Level Security) de Supabase que afectaba a prácticamente toda la aplicación.

---

### 1. Bug: admin redirige a /dashboard en vez de mostrar el panel

**Síntoma:** Al acceder a `http://localhost:3000/admin` con una cuenta admin (autenticada con Google OAuth), la aplicación redirigía automáticamente a `/dashboard`.

**Diagnóstico:** Se añadieron `console.log` en `proxy.ts` y se observó que el fetch de perfil devolvía correctamente `[{"role":"admin"}]` pero el 307 redirect seguía ocurriendo. Esto llevó a descubrir que **había dos puntos de verificación de rol**: uno en `proxy.ts` y otro en `app/admin/layout.tsx`.

**Causa raíz en `proxy.ts`:** La función `createClient` de `@supabase/ssr` tiene incompatibilidades en el Edge Runtime de Next.js cuando la sesión fue creada vía Google OAuth. La query a `profiles` devolvía null silenciosamente, causando la redirección.

**Fix en `proxy.ts`:** Se reemplazó la llamada a Supabase por un `fetch` nativo directo a la REST API de Supabase usando la service role key:

```typescript
const res = await fetch(
  `${supabaseUrl}/rest/v1/profiles?id=eq.${user.id}&select=role`,
  { headers: { apikey: serviceKey!, Authorization: `Bearer ${serviceKey!}` } }
)
const rows: { role: string }[] = await res.json()
if (rows[0]?.role !== 'admin') { /* redirect */ }
```

Este approach funciona en Edge Runtime sin depender del cliente Supabase y bypasea las limitaciones de SSR con OAuth.

**Fix en `app/admin/layout.tsx`:** Tenía la misma lógica de verificación de rol pero usando `createClient()` (anon key). Se migró a `createServiceClient()` (ver punto 2).

---

### 2. Nuevo: `createServiceClient()` en `lib/supabase/server.ts`

Se añadió una función `createServiceClient()` que crea un cliente Supabase con la `SUPABASE_SERVICE_ROLE_KEY`. A diferencia del cliente normal que usa la anon key + cookies del usuario, este cliente bypasa completamente RLS.

**Cuándo usarlo:**
- En páginas/acciones admin donde se necesitan datos de todos los usuarios
- En páginas públicas que consultan productos/planes (para evitar los problemas de RLS descritos abajo)
- Nunca se exporta al cliente browser — solo en Server Components y API routes

```typescript
import { createClient as createSupabaseClient } from '@supabase/supabase-js'

export function createServiceClient() {
  return createSupabaseClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!
  )
}
```

---

### 3. Bug crítico: RLS infinite recursion (error 42P17)

**Síntoma:** Todas las páginas del admin mostraban datos vacíos aunque había registros en la base de datos. El error en logs era `42P17: infinite recursion detected in policy for relation "profiles"`.

**Causa raíz:** La política RLS `"Admin reads all profiles"` en la tabla `profiles` tenía esta lógica:
```sql
EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
```
Esta política se evaluaba recursivamente: al consultar `profiles` para verificar si el usuario es admin, PostgreSQL evaluaba de nuevo la misma política, que volvía a consultar `profiles`, eternamente.

El problema se amplificaba porque **todas las políticas de admin** en otras tablas usaban la misma sub-query a `profiles`. Al estar logueado como admin y hacer cualquier query, PostgreSQL evaluaba las políticas aplicables usando OR, disparando la recursión.

**Solución completa:**
1. Eliminar la política problemática: `DROP POLICY IF EXISTS "Admin reads all profiles" ON profiles`
2. Migrar todas las páginas admin (10 archivos) de `createClient()` a `createServiceClient()`
3. Migrar las páginas públicas también (ver punto 4)

**Archivos migrados a `createServiceClient()`:**
- `app/admin/page.tsx`
- `app/admin/products/page.tsx`
- `app/admin/products/[id]/plans/page.tsx`
- `app/admin/products/[id]/edit/page.tsx`
- `app/admin/orders/page.tsx`
- `app/admin/reviews/page.tsx`
- `app/admin/customers/page.tsx`
- `app/admin/licenses/page.tsx`
- `app/admin/licenses/[id]/page.tsx`
- `app/admin/coupons/page.tsx`

---

### 4. Bug: productos no aparecían en `/products`

**Síntoma:** La página pública `/products` mostraba "no products found" aunque había productos publicados confirmados en la DB.

**Causa:** El mismo problema de recursión RLS. Cuando un admin (sesión autenticada) visitaba la página pública, las políticas admin de la tabla `products` se evaluaban e intentaban consultar `profiles` → recursión → query fallaba silenciosamente → array vacío.

**Fix:** `app/page.tsx`, `app/products/page.tsx` y `app/products/[slug]/page.tsx` migrados a `createServiceClient()`. Al usar la service role key, RLS se bypasa completamente y los productos publicados siempre son visibles.

---

### 5. Bug: upload de archivos fallaba con "Bucket not found" y luego "42P17"

**Primera fase — Bucket not found:** El bucket `product-files` no existía en Supabase Storage. El usuario lo creó manualmente desde el Dashboard de Supabase (bucket privado, sin acceso público).

**Segunda fase — error 42P17:** Una vez creado el bucket, el upload fallaba con el mismo error de recursión RLS. Las políticas de Storage también consultaban `profiles` para verificar el rol admin.

**Fix:** En lugar de intentar arreglar las políticas de Storage, se creó una API route server-side que usa la service role key para hacer el upload, evitando RLS completamente.

**`app/api/admin/upload/route.ts`** (nuevo):
- `POST /api/admin/upload` — recibe `FormData` con `file`, `productId` y opcionalmente `currentFilePath`. Elimina el archivo anterior si existe, sube el nuevo, devuelve `{ path }`.
- `DELETE /api/admin/upload` — recibe `{ filePath }` en JSON, elimina el archivo del bucket.
- Ambos endpoints verifican que el usuario es admin antes de proceder con `requireAdmin()`.

**`components/admin/FileUpload.tsx`** actualizado: en lugar de llamar directamente a `supabase.storage`, ahora hace `fetch('/api/admin/upload', { method: 'POST', body: formData })`. Esto desacopla completamente el upload del cliente browser y las restricciones de RLS.

---

### 6. Mejoras UX — comportamiento adaptativo por tipo de plan y producto

**Motivación:** Al probar el flujo de compra se detectaron inconsistencias entre lo que mostraba la UI y lo que realmente se estaba generando en la base de datos.

#### 6a. Texto del botón en `PlanCard.tsx`
**Problema anterior:** El botón siempre decía "Start free trial" independientemente del tipo de plan.

**Solución:** Texto adaptativo según tipo y precio:
```typescript
if (plan.type === 'trial')       → "Start free trial — X days"
if (plan.price === 0)            → "Get for free"
if (plan.type === 'subscription') → "Subscribe — $X.XX/mo" o "/yr"
default                          → "Buy now — $X.XX"
```

También se añadió `intervalLabel` (`/mo` vs `/yr`) según `billing_interval`.

#### 6b. Bug: licencias perpetuas gratuitas con status 'trial'
**Problema:** Un plan de tipo `perpetual` con `price = 0` generaba la licencia con `status: 'trial'` en la DB.

**Causa:** En `app/api/checkout/route.ts`, la condición para path directo era `plan.price === 0 || plan.type === 'trial'`, pero en ambos casos se asignaba `status: 'trial'`.

**Fix:**
```typescript
const isTrial = plan.type === 'trial'
// En licenses.insert:
status: isTrial ? 'trial' : 'active',
type: plan.type as 'perpetual' | 'subscription' | 'trial',
```
La ruta también devuelve `{ licenseKey, planType }` para que el cliente pueda mostrar el toast correcto ("Trial activated!" vs "Product unlocked!").

#### 6c. Dashboard de licencias adaptativo por tipo de producto

**`app/dashboard/licenses/[id]/page.tsx`** reescrito para adaptar la UI según `product.type`:

| Tipo de producto | UI mostrada |
|---|---|
| `software` | Clave de licencia + conteo de activaciones + lista de dispositivos activos |
| `ebook` / `template` | Solo botón de descarga del archivo |
| `course` | Botón "Go to course" (link a `/dashboard/courses/[productId]`) |

**`components/licenses/LicenseCard.tsx`** actualizado: el hint debajo del nombre del plan es adaptativo:
- `software` → "X / Y activations"
- `ebook` / `template` → "download available"
- `course` → "course access"

**`app/dashboard/licenses/page.tsx`** migrado a `createServiceClient()` para la query de licencias (mantiene `createClient()` solo para `getUser()`).

---

### 7. Eliminar plan de licencia con cascade

**Problema:** Al intentar eliminar un plan desde `app/admin/products/[id]/plans/page.tsx`, PostgreSQL lanzaba:
```
update or delete on table "license_plans" violates foreign key constraint
```
Esto ocurre porque `order_items.license_plan_id` referencia `license_plans.id` con `ON DELETE RESTRICT` implícito.

**Solución:** Cascade manual en la función `deletePlan()` en el servidor:
1. Obtener todas las licencias del plan → eliminar sus `license_activations` y `license_events`
2. Eliminar las `licenses`
3. Obtener los `order_items` del plan → eliminarlos → eliminar órdenes que quedaron sin items
4. Eliminar el plan

---

### 8. Eliminar producto con cascade + botón de confirmación

**Motivación:** No había forma de eliminar un producto desde la UI. Si un admin quería borrar un producto, tenía que hacerlo directamente con SQL.

**`components/admin/DeleteProductButton.tsx`** (nuevo): Client Component con `AlertDialog` de shadcn para confirmar antes de eliminar. Muestra el nombre del producto en el mensaje de confirmación. Al confirmar llama al server action `onDelete()` y si tiene éxito redirige a `/admin/products`.

> **Nota:** Este fue el motivo por el que se instaló el componente `alert-dialog` de shadcn.

**`app/admin/products/[id]/edit/page.tsx`** actualizado:
- Server action `deleteProduct()` con cascade completo: `license_activations` → `license_events` → `licenses` → `order_items` → órdenes huérfanas → `license_plans` → archivo en Storage → producto.
- Se añadió una sección "Zona de peligro" al final del formulario de edición con fondo rojo tenue, visible solo al editar (no en `/new`).

---

## Sesión 5 — Recuperación de contraseña + descarga de archivos desde admin

---

### 1. Instalación de `alert-dialog` de shadcn

**Motivo:** `components/admin/DeleteProductButton.tsx` importaba `@/components/ui/alert-dialog` pero el componente no estaba instalado, causando un error de build.

**Fix:**
```bash
npx shadcn@latest add alert-dialog --yes
```
Creó `components/ui/alert-dialog.tsx`.

---

### 2. Descarga de archivos desde el admin (botón Download en FileUpload)

**Problema:** El admin podía subir, reemplazar y eliminar archivos adjuntos a productos, pero no había forma de descargarlos. La única opción era ir al dashboard de usuario, tener una licencia activa y descargar desde ahí — claramente incómodo para el administrador.

**Solución:**

**`app/api/admin/upload/route.ts`** — nuevo handler `GET`:
```typescript
GET /api/admin/upload?filePath=...
```
Genera una URL firmada de Supabase Storage válida por 60 segundos y la devuelve como `{ url }`. Requiere autenticación como admin.

**`components/admin/FileUpload.tsx`** — añadido botón "Download":
- Estado `downloading` para deshabilitar el botón mientras se obtiene la URL
- `handleDownload()`: hace GET al endpoint, recibe la URL firmada, crea un `<a>` temporal con `download` attribute y lo clickea programáticamente
- El orden de botones es: **Download → Replace → Remove**

---

### 3. Flujo completo de recuperación de contraseña

**Motivación:** Solo existía login con email/contraseña y Google OAuth. No había mecanismo para que un usuario que olvidó su contraseña pudiera recuperarla. Era una funcionalidad básica que faltaba desde el inicio.

**Cómo funciona con Supabase:**
1. `supabase.auth.resetPasswordForEmail(email, { redirectTo })` envía un email con un link
2. El link apunta a `/auth/callback?code=TOKEN&next=/auth/reset-password`
3. El callback intercambia el code por sesión y redirige al path indicado por `next`
4. En `/auth/reset-password`, el usuario (ya autenticado) llama `supabase.auth.updateUser({ password })`

**`lib/utils/validators.ts`** — se añadieron dos schemas:
```typescript
forgotPasswordSchema  → { email: string }
resetPasswordSchema   → { password, confirmPassword } con refinement de igualdad
```
Y sus tipos exportados: `ForgotPasswordFormValues`, `ResetPasswordFormValues`.

**`app/auth/forgot-password/page.tsx`** (nuevo): Client Component con formulario de email. Tras enviar muestra un estado de confirmación con el email al que se envió el link. Usa `window.location.origin` como fallback si `NEXT_PUBLIC_SITE_URL` no está definida (útil en localhost).

**`app/auth/reset-password/page.tsx`** (nuevo): Client Component con formulario de nueva contraseña + confirmación. Llama `supabase.auth.updateUser({ password })`. En caso de éxito redirige a `/dashboard`. El middleware no bloquea esta ruta porque solo protege `/dashboard/**` y `/admin/**`.

**`app/auth/callback/route.ts`** — corregido bug de prioridad de redirección:

**Problema original:**
```typescript
const next = searchParams.get('next') ?? '/'
const redirectTo = searchParams.get('redirectTo') ?? '/dashboard'
// redirectTo nunca era null → siempre redirigía a /dashboard
new URL(redirectTo ?? next, request.url)
```

**Fix:**
```typescript
const destination =
  searchParams.get('next') ?? searchParams.get('redirectTo') ?? '/dashboard'
```
Ahora `next` tiene prioridad, lo que permite que el link de reset de contraseña lleve correctamente a `/auth/reset-password` en lugar de `/dashboard`.

**`app/auth/login/page.tsx`** — añadido link "Forgot password?" inline junto a la label del campo de contraseña, apuntando a `/auth/forgot-password`.

---

## Sesión 6 — Preservar nombre original del archivo al subir

**Problema:** Al subir un archivo desde el admin, el nombre original se modificaba de dos formas:
1. Los espacios se reemplazaban por guiones bajos (`replace(/\s+/g, '_')`)
2. Se añadía un prefijo de timestamp (`Date.now()_`) delante del nombre

Esto hacía que el archivo quedara guardado y descargado con un nombre diferente al original, lo que resulta confuso tanto para el admin como para el usuario final que descarga el producto.

**Causa del diseño original:** El prefijo de timestamp se añadió para evitar colisiones de nombre si se subían dos archivos distintos al mismo producto. Sin embargo, dado que el upload siempre elimina el archivo anterior antes de subir el nuevo (`remove([currentFilePath])`) y usa `upsert: true`, no puede haber colisiones dentro del mismo producto. Entre distintos productos tampoco hay colisión porque la ruta incluye el `productId` como carpeta (`productId/filename`).

**Fix en `app/api/admin/upload/route.ts`:**
```typescript
// Antes:
const safeName = file.name.replace(/\s+/g, '_')
const path = `${productId}/${Date.now()}_${safeName}`

// Después:
const path = `${productId}/${file.name}`
```

El nombre del archivo ahora se preserva exactamente como se llama en el sistema del administrador.

---

## Sesión 7 — Link a Dashboard en el header

**Problema:** Un usuario logueado solo podía acceder a `/dashboard` abriendo el dropdown del avatar en el header. No había ningún link directo visible en la barra de navegación principal, lo que hacía la navegación menos intuitiva.

**Contexto:** El `<nav>` del header ya mostraba "Products" siempre y "Admin" condicionalmente para admins, pero no había un equivalente para usuarios normales logueados.

**Fix en `components/layout/Header.tsx`:** Se añadió el link "Dashboard" en el `<nav>` principal, visible únicamente cuando hay sesión activa (`user !== null`). El orden resultante de la nav es:

```
Products  →  Dashboard (si logueado)  →  Admin (si admin)
```

El link sigue el mismo estilo visual que los demás enlaces de la nav (`text-muted-foreground hover:text-foreground transition-colors`). En mobile el nav está oculto (`hidden md:flex`), así que en pantallas pequeñas el acceso sigue siendo por el dropdown del avatar.
