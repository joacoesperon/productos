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

---

## Sesión 8 — Sistema de límite de 1 licencia activa por plan por usuario

**Motivación:** No existía ningún mecanismo que impidiera a un usuario comprar el mismo plan varias veces. Cada checkout creaba una nueva licencia independientemente de si el usuario ya tenía una activa. Esto podía resultar en duplicados en la tabla `licenses` y cobros injustificados via Stripe.

**Diseño de la solución:** Se decidió bloquear en tres capas:
1. **Backend (`checkout/route.ts`)** — primera línea de defensa: si ya existe licencia `active` o `trial` para ese `(user_id, license_plan_id)`, devolver `409 Conflict` sin procesar nada.
2. **Backend (`webhook-handlers.ts`)** — idempotencia: si Stripe reintenta el webhook `checkout.session.completed` (comportamiento habitual de Stripe ante fallos), no crear una segunda licencia.
3. **Frontend (product page + PlanSelector + PlanCard)** — UX: mostrar visualmente qué planes ya posee el usuario, deshabilitar la compra y redirigir a `/dashboard/licenses`.

Se eligió verificar solo los estados `active` y `trial` (no `expired`, `revoked`, `suspended`), de modo que un usuario cuya licencia caducó SÍ puede volver a comprar o suscribirse.

---

### Capa 1 — `app/api/checkout/route.ts`

Se añadió un bloque de verificación tras obtener el plan (nuevo paso 4), antes de cualquier procesamiento de pago:

```typescript
// 4. Verificar que el usuario no tenga ya una licencia activa para este plan
const supabaseAdmin = createAdminClient()
const { data: existingLicense } = await supabaseAdmin
  .from('licenses')
  .select('id')
  .eq('user_id', user.id)
  .eq('license_plan_id', planId)
  .in('status', ['active', 'trial'])
  .maybeSingle()

if (existingLicense) {
  return NextResponse.json(
    { error: 'You already have an active license for this plan' },
    { status: 409 }
  )
}
```

`supabaseAdmin` (ya instanciado aquí) se reutiliza en el bloque de planes gratuitos/trial que viene después, eliminando la instanciación duplicada que existía dentro de ese bloque. Los pasos de comentario se renumeraron (4→5 para free plan, 5→6 para coupon, 6→7 para Stripe session).

---

### Capa 2 — `lib/stripe/webhook-handlers.ts`

En `handleCheckoutSessionCompleted`, se añadió una verificación de idempotencia inmediatamente después de obtener el plan y antes de crear la orden:

```typescript
const { data: existingLicense } = await supabase
  .from('licenses')
  .select('id')
  .eq('user_id', meta.user_id)
  .eq('license_plan_id', meta.license_plan_id)
  .in('status', ['active', 'trial'])
  .maybeSingle()

if (existingLicense) {
  console.log('[webhook] License already exists for this plan, skipping duplicate creation')
  return
}
```

Esto protege contra el escenario en que Stripe reintente el evento (hasta 3 días con backoff exponencial).

---

### Capa 3 — UI en la página de producto

**`app/products/[slug]/page.tsx`:**
- Se añadió `createClient` al import de `@/lib/supabase/server`.
- Se obtiene la sesión del usuario con `authClient.auth.getUser()`.
- Si hay usuario logueado, se consultan sus licencias `active`/`trial` para el producto actual, extrayendo los `license_plan_id`:

```typescript
let ownedPlanIds: string[] = []
if (user) {
  const { data: licenses } = await supabase
    .from('licenses')
    .select('license_plan_id')
    .eq('user_id', user.id)
    .eq('product_id', p.id)
    .in('status', ['active', 'trial'])
  ownedPlanIds = licenses?.map((l) => l.license_plan_id) ?? []
}
```
- Se pasa `ownedPlanIds` a `<PlanSelector>`.

**`components/store/PlanSelector.tsx`:**
- Nueva prop `ownedPlanIds?: string[]` (default `[]`).
- Nueva función `handleSelect(planId)` que ignora la selección si el plan está en `ownedPlanIds` — previene que se haga click y se intente comprar un plan ya poseído.
- En el map de `PlanCard` se pasa `isOwned={ownedPlanIds.includes(plan.id)}`.
- El botón "Continue" solo se muestra si el plan seleccionado NO está en `ownedPlanIds`.
- Se añadió manejo explícito del status `409`: muestra toast de error y redirige a `/dashboard/licenses` en lugar de mostrar un error genérico.

**`components/store/PlanCard.tsx`:**
- Nueva prop `isOwned?: boolean`.
- Import de `Link` de next/link.
- Cuando `isOwned = true`, la tarjeta muestra:
  - Borde verde (`border-green-500 ring-1 ring-green-500`)
  - Badge "Active" en verde en lugar del badge de tipo de plan
  - Botón "Manage license →" (variante `secondary`) como `<Link href="/dashboard/licenses">` en lugar del botón de compra
- Cuando `isOwned = false`, el comportamiento es idéntico al anterior.

---

## Sesión 9 — Ocultar "Create account" en homepage si hay sesión activa

**Problema:** El hero de la homepage (`app/page.tsx`) mostraba siempre dos botones: "Browse products" y "Create account". Un usuario ya logueado seguía viendo el botón de registro, lo cual no tiene sentido y puede resultar confuso.

**Causa:** La homepage usaba únicamente `createServiceClient()` para obtener los productos publicados, pero no obtenía la sesión del usuario, por lo que no tenía manera de saber si había alguien logueado.

**Fix en `app/page.tsx`:**
- Se añadió `createClient` al import de `@/lib/supabase/server`.
- Se obtiene la sesión al inicio de la función con `authClient.auth.getUser()`.
- El botón "Create account" se envuelve en `{!user && (...)}`, por lo que solo aparece cuando no hay sesión activa.
- El botón "Browse products" permanece siempre visible para todos los usuarios.

```tsx
{!user && (
  <Button size="lg" variant="outline" asChild>
    <Link href="/auth/register">Create account</Link>
  </Button>
)}
```

Un usuario logueado que visite la homepage solo verá el botón "Browse products" en el hero, y puede navegar al dashboard desde el link en la barra de navegación.

---

## Sesión 10 — Cambio de contraseña desde el perfil

### Diseño previo a la implementación

Antes de escribir código se razonó el diseño con especial atención al caso de usuarios de Google OAuth.

**El problema con Google OAuth:** Supabase Auth soporta múltiples proveedores de identidad. Un usuario registrado con Google **no tiene contraseña asignada** — su identity es exclusivamente `google`. Mostrarle un formulario de "cambiar contraseña" no solo es inútil sino confuso.

**Cómo detectarlo:** Supabase expone `user.identities[]` en el objeto del usuario. Cada entry tiene un campo `provider`. Si existe al menos una entry con `provider === 'email'`, el usuario tiene email/password. Si todas las identidades son de otro proveedor (p.ej. `google`), no tiene contraseña.

```typescript
const hasEmailIdentity = user.identities?.some(i => i.provider === 'email') ?? false
```

**Opciones evaluadas:**

| Opción | Descripción | Decisión |
|--------|-------------|----------|
| A — Ocultar sección para usuarios Google | Mostrar aviso explicativo | ✅ Elegida |
| B — Permitir a usuarios Google establecer contraseña | `updateUser({ password })` funciona incluso para OAuth users | ❌ Demasiado complejo sin caso de uso real |
| C — Mostrar formulario deshabilitado | Confuso | ❌ Descartada |

**Se eligió la Opción A** por ser la más simple y honesta. Los usuarios de Google ven un aviso: *"Your account uses Google Sign-In. Password management is handled by Google."*

**Flujo de seguridad para el cambio de contraseña:**

Se decidió exigir la contraseña actual antes de permitir el cambio. El motivo: si se omitiera, cualquiera con acceso a una sesión abierta en un dispositivo ajeno podría cambiar la contraseña. El flujo implementado:

1. Formulario: contraseña actual + nueva contraseña + confirmación
2. Verificar contraseña actual vía `signInWithPassword({ email, password: currentPassword })` — si falla, mostrar error en el campo
3. Si pasa la verificación, llamar `updateUser({ password: newPassword })`
4. Toast de éxito, limpiar formulario

---

### Implementación

**`lib/utils/validators.ts`** — nuevo schema `changePasswordSchema`:
```typescript
export const changePasswordSchema = z.object({
  currentPassword: z.string().min(1, 'Current password is required'),
  newPassword: z.string().min(6, 'New password must be at least 6 characters'),
  confirmPassword: z.string(),
}).refine(data => data.newPassword === data.confirmPassword, {
  message: 'Passwords do not match',
  path: ['confirmPassword'],
})
export type ChangePasswordFormValues = z.infer<typeof changePasswordSchema>
```

**`app/dashboard/profile/page.tsx`** — reescrito con las siguientes adiciones:

- Estado `hasEmailIdentity: boolean` inicialmente `false`, se establece en el `useEffect` de carga:
  ```typescript
  setHasEmailIdentity(user.identities?.some(i => i.provider === 'email') ?? false)
  ```

- Segundo `useForm` con `changePasswordSchema` para el formulario de contraseña, con sus propios `register`, `handleSubmit`, `setError` y `formState`.

- `onChangePassword()`: verifica primero via `signInWithPassword`, luego llama `updateUser`. Si `signInWithPassword` falla, setea el error directamente en el campo `currentPassword` via `setError`.

- Al final del JSX, condicional según `hasEmailIdentity`:
  - `true` → Card "Change Password" con formulario de 3 campos
  - `false` → Card "Password" con icono de Chrome y mensaje explicativo

---

## Sesión 11 — Admin: gestión avanzada de licencias

### Contexto y diseño previo

Antes de implementar se realizó una discusión de diseño sobre qué cambios hacer al panel de licencias del admin. El estado previo era:

- **Lista** (`/admin/licenses`): columnas license key, product, status, activations, expires, issued. Búsqueda solo por license key.
- **Detalle** (`/admin/licenses/[id]`): funciones de revocar y suspender ya implementadas, historial de eventos, lista de dispositivos activos. Sin información del usuario propietario.

Las preguntas planteadas fueron:
1. ¿Debe el admin ver quién posee cada licencia? → **Sí, imprescindible**.
2. ¿Debe poder revocar/eliminar? → **Revocar y suspender ya existían. Eliminar deliberadamente no se implementa** — borraría histórico de auditoría y es demasiado destructivo para uso normal.
3. ¿Tiene sentido la columna "Activations" para todos los tipos? → **No**. Para ebooks/templates/courses siempre es `0/1` y no aporta información. Solo tiene sentido para `software`.
4. ¿Cómo se aplica el patrón adaptativo por tipo al admin? → Igual que en el dashboard de usuario: el admin ve "Active Devices" solo si el producto es de tipo `software`.

**Problema técnico de JOIN**: `licenses.user_id` referencia `auth.users`, no `profiles` directamente. PostgREST no infiere ese join indirecto. Solución: dos queries separadas — primero licencias, luego profiles para los `user_id` resultantes.

### Cambios implementados

**`app/admin/licenses/page.tsx`**

- Query: se mantiene la query de licencias; se añade una segunda query a `profiles` con los `user_id` únicos del resultado, construyendo un `profileMap: Record<string, Profile>` para lookup en O(1).
- Búsqueda dual: si el término contiene `@` se interpreta como email → busca matching `profiles` primero, extrae sus IDs, filtra licencias por `user_id IN (ids)`. Si no, busca por `license_key` como antes. Si ningún perfil coincide con el email, devuelve lista vacía inmediatamente sin hacer la query de licencias.
- Columna "Activations" **eliminada** de la lista → sustituida por columna **"User"** con email del propietario.
- Placeholder del search actualizado: `"Search by license key or user email…"`
- Refactorizado con función `renderPage()` para evitar duplicar JSX en el early-return del caso email-sin-resultados.

**`app/admin/licenses/[id]/page.tsx`**

- Query actualizada para incluir `products.type` (antes solo era `id, name, slug`).
- Segunda query `profiles.select('id, email, full_name').eq('id', license.user_id)` para obtener datos del propietario.
- Nueva sección **"Owner"** (Card) antes de "Details": muestra nombre completo (si existe), email, y user_id en mono text.
- Sección **"Active Devices"** condicional: `{isSoftware && (<div>...)</div>)}` — solo se renderiza si `license.products.type === 'software'`.
- Igualmente en la card "Details", la fila de "Activations" solo aparece si `isSoftware`.
- Tipo `LicenseFull` actualizado: `products: Pick<Product, 'id' | 'name' | 'slug' | 'type'>` (añadido `type`).

---

## Sesión 12 — Cancelación de suscripciones por el usuario

### Contexto

Los usuarios con suscripciones activas no tenían ninguna forma de cancelarlas desde DigiStore. El mecanismo correcto de Stripe es `cancel_at_period_end: true` — el acceso se mantiene hasta el fin del período facturado y luego Stripe dispara `customer.subscription.deleted`, que nuestro handler existente ya convertía en `status = expired`.

El campo `cancel_at_period_end` no existía en la tabla `licenses` — fue necesario añadirlo.

### Diseño

- `cancel_at_period_end: true` → suscripción programada para cancelar al final del período; el usuario mantiene acceso
- `cancel_at_period_end: false` → suscripción activa y renovándose normalmente
- Posibilidad de "deshacer" la cancelación antes de que venza el período con un botón "Keep subscription"
- El webhook `customer.subscription.updated` actúa como safety net para sincronizar el estado si el usuario cancela desde fuera de DigiStore (p.ej. Stripe Dashboard)

### Archivos modificados / creados

**`supabase/migration.sql`** — append:
```sql
ALTER TABLE licenses ADD COLUMN IF NOT EXISTS cancel_at_period_end boolean NOT NULL DEFAULT false;
```

**`types/database.ts`** — `licenses`:
- Row: `cancel_at_period_end: boolean`
- Insert: `cancel_at_period_end?: boolean`
- Update: `cancel_at_period_end?: boolean`

**`app/api/subscriptions/cancel/route.ts`** (nuevo):
```
POST /api/subscriptions/cancel
Body: { licenseId: string, action: 'cancel' | 'reactivate' }
```
1. Verifica sesión del usuario
2. Obtiene licencia filtrando por `id` **y** `user_id` (previene IDOR)
3. Valida: `type === 'subscription'`, `status === 'active'`, `stripe_subscription_id` presente
4. Llama `stripe.subscriptions.update(subscriptionId, { cancel_at_period_end: action === 'cancel' })`
5. Actualiza DB: `licenses.update({ cancel_at_period_end })`

**`lib/stripe/webhook-handlers.ts`** — nuevo handler `handleSubscriptionUpdated`:
```typescript
export async function handleSubscriptionUpdated(subscription: Stripe.Subscription) {
  // busca licencia por stripe_subscription_id
  // actualiza cancel_at_period_end desde subscription.cancel_at_period_end
}
```

**`app/api/webhooks/stripe/route.ts`** — nuevo case:
```typescript
case 'customer.subscription.updated':
  await handleSubscriptionUpdated(event.data.object as Stripe.Subscription)
  break
```

**`components/licenses/CancelSubscriptionButton.tsx`** (nuevo, Client Component):
- Props: `licenseId`, `cancelAtPeriodEnd`, `expiresAt`
- Si `cancelAtPeriodEnd === false`: botón "Cancel subscription" → abre `AlertDialog` con mensaje explicativo → al confirmar llama la API con `action: 'cancel'` → `router.refresh()`
- Si `cancelAtPeriodEnd === true`: botón "Keep subscription" → llama API con `action: 'reactivate'` → `router.refresh()`

**`app/dashboard/licenses/[id]/page.tsx`** — cambios:
- Import de `CancelSubscriptionButton` y `AlertCircle`
- `isSubscription = license.type === 'subscription'`
- Cast de tipo actualizado para incluir `cancel_at_period_end: boolean`
- `expiresLabel = isSubscription && isActive && !cancel_at_period_end ? 'Renews' : 'Expires'` — refleja si la suscripción va a renovarse o terminar
- Banner naranja `AlertCircle` si `isSubscription && cancel_at_period_end && expires_at`
- `<CancelSubscriptionButton>` renderizado si `isSubscription && isActive`

---

## Sesión 13 — Fix botón "Cancel subscription" en planes gratuitos

### Problema

El botón "Cancel subscription" aparecía en el detail page de cualquier licencia de tipo `subscription` activa, incluyendo planes con `price = 0` que **no pasan por Stripe**. Para estos planes:
- `stripe_subscription_id` es `null` (checkout los procesa directamente sin Stripe)
- `expires_at` es `null` (no hay ciclo de facturación)
- Si el usuario pulsaba "Cancel subscription", la API route devolvía 400: `"No Stripe subscription found for this license"`

También se aclaró en esta sesión que para suscripciones gratuitas (price=0) **no hay fecha de renovación que mostrar** — es el comportamiento correcto, ya que no existe Stripe que gestione el ciclo.

### Fix

**`app/dashboard/licenses/[id]/page.tsx`** — condición del `<CancelSubscriptionButton>`:

```tsx
// Antes:
{isSubscription && isActive && (

// Después:
{isSubscription && isActive && license.stripe_subscription_id && (
```

El botón solo aparece si la licencia tiene un `stripe_subscription_id` asociado, lo que garantiza que la API de cancelación puede operar correctamente.

### Cómo probar suscripciones pagas con Stripe (test mode)

Para que la fecha de renovación aparezca, el plan debe tener `price > 0` y `type = 'subscription'`. Con una tarjeta de prueba `4242 4242 4242 4242` Stripe procesa el pago, crea una suscripción real (en test mode) y dispara los webhooks necesarios para que `expires_at` se establezca y se muestre en el dashboard.

Para recibir webhooks en localhost se necesita la Stripe CLI:
```bash
stripe listen --forward-to localhost:3000/api/webhooks/stripe
# copia el "whsec_..." que muestra y ponlo en STRIPE_WEBHOOK_SECRET en .env.local
```

---

## Sesión 14 — Fix precio en vista admin + Fix LicenseCard Expires/Renews

### ⚠️ ADVERTENCIA PERMANENTE: Nunca confundas centavos con dólares

**Este bug costó $0 porque estábamos en desarrollo. En producción, un error así puede cobrarle $0.30 a alguien que debería pagar $30 (pérdida directa de ingresos), o peor: cobrarle $3000 a alguien que debería pagar $30 (contracargos, disputas, reputación destruida).** Los bugs de plata no se parecen a ningún otro tipo de bug — no hay stack trace, no hay excepción, no hay test que falle en rojo. Simplemente el número es incorrecto y nadie lo nota hasta que alguien revisa su tarjeta.

**Regla de oro para este proyecto:** `license_plans.price` y `orders.total_amount` se almacenan siempre en **centavos** (entero). `formatCurrency(value)` ya divide por 100 internamente — nunca pasarle `value / 100`. El checkout de Stripe espera `unit_amount` en centavos — nunca pasarle dólares. Cada vez que toques código que involucre precios, verificá la unidad antes y después.

---

### Bug 1 — Precio 100x más barato en vista admin de planes

**Síntoma:** Al crear un plan con precio "30", la vista `/admin/products/[id]/plans` mostraba `$0.30/mes`. La tienda pública mostraba `$30.00/mo` correctamente y Stripe cobraba $30 correctamente.

**Causa:** Doble división por 100. El flujo completo:
1. Admin escribe "30" → `PlansManager` convierte a centavos: `Math.round(30 * 100) = 3000` → guarda 3000 en DB ✓
2. `formatCurrency(value)` divide por 100 internamente → `formatCurrency(3000) = $30.00` ✓
3. Pero `PlansManager` línea 118 hacía `formatCurrency(plan.price / 100)` → `formatCurrency(3000/100)` → `formatCurrency(30)` → `30/100 = $0.30` ✗

**Fix:** `components/admin/PlansManager.tsx` línea 118:
```tsx
// Antes (bug):
{plan.price === 0 ? 'Gratis' : formatCurrency(plan.price / 100)}

// Después (correcto):
{plan.price === 0 ? 'Gratis' : formatCurrency(plan.price)}
```

**Verificación post-fix:** se buscaron todos los usos de `formatCurrency` en el proyecto — ningún otro caso tiene doble división.

---

### Bug 2 — LicenseCard mostraba "Expires" para suscripciones activas

**Síntoma:** En `/dashboard/licenses` la tarjeta de una suscripción activa mostraba `"Expires Apr 12, 2026"`. En `/dashboard/licenses/[id]` el detalle mostraba `"Renews Apr 12, 2026"` (correcto, arreglado en Sesión 12). Inconsistencia entre la tarjeta y el detalle.

**Causa:** `LicenseCard.tsx` usaba hardcodeado `"Expires"` para toda fecha de expiración, sin considerar el tipo de licencia ni `cancel_at_period_end`.

**Fix:** `components/licenses/LicenseCard.tsx` — se añadió lógica de label contextual:
```tsx
const expiresLabel =
  isSubscription && isActive && !license.cancel_at_period_end
    ? 'Renews'
    : isSubscription && license.cancel_at_period_end
    ? 'Cancels'
    : 'Expires'
```
Además, cuando `cancel_at_period_end === true` el texto se muestra en `text-orange-600` para consistencia visual con el banner del detail page.

---

## Sesión 15 — Descartar licencias gratuitas desde el dashboard

### Contexto y decisiones de diseño

Los planes con `price = 0` y los trials generan licencias que nunca desaparecen solas del dashboard. Como los trials no tienen ningún job automático que cambie su status a `expired` al vencer la fecha (`expires_at` pasa pero el status queda como `trial` en DB), podían bloquear indefinidamente la re-compra del mismo plan (el check de 1-por-plan bloquea `active` y `trial`).

**Decisiones tomadas:**
- **Acción = `revoked` con `revocation_reason = 'Discarded by user'`** — mantiene audit trail, el admin puede distinguirlo de una revocación administrativa, y el usuario puede re-comprar (solo `active`/`trial` bloquean).
- **Condición de elegibilidad = `!stripe_subscription_id && status in ('active', 'trial')`** — solo licencias sin Stripe asociado. Las suscripciones pagas tienen su propio flujo (`CancelSubscriptionButton`).
- **Dashboard filtra `revoked`** — licencias descartadas desaparecen de la lista del usuario. El admin sigue viéndolas en `/admin/licenses` con el motivo visible.
- **`expired` permanece visible** — tiene valor psicológico de motivar re-compra.

### Archivos modificados / creados

**`app/dashboard/licenses/page.tsx`** — añadido `.neq('status', 'revoked')` a la query para excluir licencias descartadas de la vista del usuario.

**`app/api/licenses/[id]/discard/route.ts`** (nuevo — `POST /api/licenses/[id]/discard`):
1. Verifica sesión del usuario
2. Obtiene la licencia filtrando por `id` + `user_id` (anti-IDOR)
3. Valida: `stripe_subscription_id = null` y `status in ('active', 'trial')`
4. Actualiza: `status = 'revoked'`, `revoked_at = now()`, `revocation_reason = 'Discarded by user'`

**`components/licenses/DiscardLicenseButton.tsx`** (nuevo, Client Component):
- Botón "Discard license" con ícono `Trash2` y colores destructive
- `AlertDialog` de confirmación antes de actuar
- En éxito → `router.push('/dashboard/licenses')` (la licencia no aparece en la lista)

**`app/dashboard/licenses/[id]/page.tsx`** — import de `DiscardLicenseButton` + bloque condicional:
```tsx
{!license.stripe_subscription_id && isActive && (
  <DiscardLicenseButton licenseId={license.id} />
)}
```

---

## Sesión 16 — Sistema de trials mejorado: 1 trial por cuenta y suscripciones con trial de Stripe

### Contexto y motivación

El sistema de trials original tenía dos problemas fundamentales. Primero, no había ningún límite real de un trial por cuenta: como el botón "Discard" (Sesión 15) cambia el status a `revoked`, el check de licencia activa dejaba de bloquear, permitiendo al usuario obtener el trial repetidamente simplemente descartando el anterior. Segundo, no había ningún mecanismo para convertir un trial en suscripción de pago de forma automática — un plan de tipo `subscription` con `trial_days > 0` simplemente ofrecía la suscripción sin período de prueba.

### Diseño previo — opciones evaluadas

Se analizaron varias dimensiones del problema:

**1. ¿Dónde hacer el check de 1 trial por cuenta?**

| Opción | Descripción | Decisión |
|--------|-------------|----------|
| A — Check en cualquier status histórico | Buscar ANY licencia con `type = 'trial'` para ese plan, sin filtrar por status | ✅ Elegida — cierra el exploit de discard+retry |
| B — Check solo en `active`/`trial` | El check original | ❌ Descartada — un discard lo bypass inmediatamente |

Se optó por: si existe CUALQUIER licencia histórica con `type = 'trial'` para ese `license_plan_id` y ese `user_id`, independientemente del status, el checkout devuelve 409.

**2. ¿Verificación de tarjeta para trials gratuitos (tipo `trial`)?**

| Opción | Descripción | Decisión |
|--------|-------------|----------|
| A — Sin tarjeta | Trial standalone gratuito sin requerir pago | ✅ Elegida — máxima conversión, mínima fricción |
| B — Con tarjeta, cobro diferido | Guardar método de pago para cobrar al terminar | ❌ Descartada — alto ROI técnico, bajo ROI de negocio para productos de una sola compra |

Se decidió no requerir tarjeta para trials standalone (tipo `trial`). El riesgo de multi-cuenta abuse se aceptó como tolerable dado que estos trials son gratuitos de todas formas.

**3. ¿Cómo manejar suscripciones con período de prueba?**

| Opción | Descripción | Decisión |
|--------|-------------|----------|
| A — Trial nativo de Stripe | `subscription_data: { trial_period_days }` + `payment_method_collection: 'always'` | ✅ Elegida — Stripe gestiona todo el ciclo automáticamente |
| B — Perpetual trial + cobro manual | Trial sin Stripe + email al vencer | ❌ Descartada — complejidad manual innecesaria |
| C — Trial standalone sin tarjeta | Igual que el trial tipo `trial` pero para planes subscription | ❌ Descartada — no se convierte en suscripción sola |

Para planes `subscription` con `trial_days > 0` se usa el trial nativo de Stripe: se recoge la tarjeta de pago en el checkout (incluso para $0 inmediato), y Stripe cobra automáticamente cuando termina el trial. El evento `invoice.payment_succeeded` ya existía — renueva la licencia sin cambios.

### Implementación

**`app/api/checkout/route.ts`** — dos cambios:

*Check de trial histórico:* Para `plan.type === 'trial'`, en lugar de buscar licencias `active/trial`, se busca **cualquier licencia con `type = 'trial'`** para ese plan:
```typescript
if (plan.type === 'trial') {
  const { data: anyTrialLicense } = await supabaseAdmin
    .from('licenses').select('id')
    .eq('user_id', user.id)
    .eq('license_plan_id', planId)
    .eq('type', 'trial')
    .maybeSingle()
  if (anyTrialLicense) return NextResponse.json(
    { error: 'You have already used your trial for this plan' },
    { status: 409 }
  )
}
```

*Stripe trial session:* Para suscripciones con `trial_days > 0`:
```typescript
const hasStripeTrial = isSubscription && !!plan.trial_days && plan.trial_days > 0

// En la creación de session:
payment_method_collection: hasStripeTrial ? 'always' : undefined,
...(hasStripeTrial && {
  subscription_data: { trial_period_days: plan.trial_days! }
})
```
`payment_method_collection: 'always'` fuerza la recolección de tarjeta aunque el total inmediato sea $0.

**`lib/stripe/webhook-handlers.ts`** — detección de trial en webhook:

Cuando llega `checkout.session.completed` para una suscripción con trial, la licencia debe crearse con `status: 'trial'` y `expires_at = now + trial_days`:
```typescript
const hasStripeTrial = plan.type === 'subscription' && !!plan.trial_days && plan.trial_days > 0
const licenseStatus: 'trial' | 'active' = plan.type === 'trial' || hasStripeTrial ? 'trial' : 'active'
const expiresAt = hasStripeTrial
  ? addDays(new Date(), plan.trial_days!).toISOString()
  : calculateExpiresAt(plan.type as LicensePlanType, plan.billing_interval, plan.trial_days)
```
Al terminar el trial, Stripe dispara `invoice.payment_succeeded` → el handler existente `handleInvoicePaymentSucceeded` actualiza `status: 'active'` y calcula el nuevo `expires_at` con el interval de facturación normal. No se requirió ningún cambio en ese handler.

**`components/store/PlanCard.tsx`** — UI adaptativa para suscripción + trial:

Se añadió la variable `hasStripeTrial = plan.type === 'subscription' && !!plan.trial_days && plan.trial_days > 0`. Para estos planes:
- `priceLabel` muestra `"Free for N days"` en lugar del precio mensual
- `priceSublabel` (nuevo) muestra `"then $X/mo"` debajo del precio principal
- `buttonLabel` muestra `"Start N-day free trial"` en lugar de `"Subscribe — $X/mo"`
- `displayBadge` muestra `"Free Trial"` en lugar de `"Subscription"`

### Resultado y estado final

Los planes de tipo `trial` ahora solo se pueden usar una vez por cuenta (cualquier status histórico bloquea la re-obtención). Los planes de suscripción con `trial_days > 0` se presentan como trials con tarjeta requerida: el usuario ve el precio como "Free for N days, then $X/mo", paga $0 en el checkout de Stripe, y al finalizar el trial Stripe cobra automáticamente sin intervención manual. Si cancela durante el trial, la suscripción termina sin cargo.

---

## Sesión 17 — Normalización del comportamiento de trials: no descartables, UI "Trial used"

### Contexto y decisión de diseño

Al probar el sistema de trials implementado en la Sesión 16, se identificaron dos problemas:

1. **UI de la store mostraba el plan trial como "disponible"** incluso después de haberlo usado (porque `ownedPlanIds` solo miraba licencias con `status IN ('active', 'trial')`, y una licencia descartada tiene `status = 'revoked'`).
2. **Toast de error hardcodeado**: `PlanSelector` ignoraba el cuerpo JSON de la respuesta 409 y siempre mostraba "You already have an active license for this plan", independientemente de si el error era "trial ya usado" u otro.
3. **El botón "Discard" aparecía en licencias de tipo trial**, lo que no tiene sentido conceptualmente: un trial no se descarta, simplemente expira. Permitir descartarlo solo añade complejidad sin beneficio — el usuario pierde el trial y luego se encuentra con que no puede reclamarlo de nuevo.

La decisión de diseño alineada con el estándar de la industria (Stripe, Notion, Linear): **los trials no se descartan**. Se usan durante N días y expiran solos. Una vez usados, el slot queda consumido para siempre. El botón "Discard" tiene sentido únicamente para licencias perpetuas gratuitas (donde el usuario puede querer "eliminar" un producto que reclamó por error).

### Implementación

**`app/dashboard/licenses/[id]/page.tsx`** — condición del botón Discard extendida con `license.type !== 'trial'`:
```tsx
{!license.stripe_subscription_id && isActive && license.type !== 'trial' && (
  <DiscardLicenseButton licenseId={license.id} />
)}
```

**`components/store/PlanSelector.tsx`** — tres cambios:
- Toast de 409 lee el error real del JSON: `toast.error(data.error ?? 'You already have an active license for this plan')`
- Nueva prop `usedTrialPlanIds?: string[]` para recibir planes con trial histórico
- `handleSelect` rechaza silenciosamente planes con trial usado
- `PlanCard` recibe `isTrialUsed` calculado como `usedTrialPlanIds.includes(plan.id) && !ownedPlanIds.includes(plan.id)`
- Botón "Continue" no aparece para planes con trial usado

**`components/store/PlanCard.tsx`** — nuevo estado `isTrialUsed`:
- Tarjeta con `opacity-60`
- Badge "Trial used" (gris)
- Botón deshabilitado "Trial already used"

**`app/products/[slug]/page.tsx`** — segunda query para trials históricos:
```typescript
const { data: trialLicenses } = await supabase
  .from('licenses').select('license_plan_id')
  .eq('user_id', user.id).eq('product_id', p.id).eq('type', 'trial')
usedTrialPlanIds = trialLicenses?.map((l) => l.license_plan_id) ?? []
```
Esta query no filtra por status, por lo que captura cualquier licencia de tipo trial independientemente de si está activa, expirada o revocada.

### Resultado y estado final

El flujo de trials queda alineado con el estándar de la industria: 1 trial por cuenta, no descartable, expira naturalmente. En la store, un plan cuyo trial ya se usó muestra badge "Trial used" y botón deshabilitado. El botón "Discard" en el dashboard solo aparece para licencias perpetuas gratuitas (sin Stripe, tipo != 'trial').

---

## Sesión 18 — Eliminación de la feature "Discard license"

### Contexto y decisión

La feature "Discard license" (implementada en Sesión 15) fue concebida para que el usuario pudiera eliminar de su dashboard licencias de productos gratuitos que no quería. Sin embargo, al analizar el estándar de la industria y los problemas que generó, se decidió eliminarla completamente:

1. **No existe en la industria.** Plataformas como Gumroad, LemonSqueezy o Payhip no tienen un concepto de "descartar" una licencia. Una licencia gratuita simplemente está en tu biblioteca para siempre; si no la usás, la ignorás.
2. **Fue la raíz de toda la complejidad de los trials.** El exploit de discard+reclaim, la query histórica, `usedTrialPlanIds`, el status `revoked` para distinguir descartadas de revocadas por admin — todo surgió de esta feature.
3. **La motivación original no era de producto.** El botón se añadió porque durante el desarrollo se necesitaba limpiar datos de prueba, no porque los usuarios reales lo necesiten.

La única acción de usuario que sí existe en la industria y ya tenemos implementada es **cancelar suscripción** (`CancelSubscriptionButton`).

### Archivos eliminados

- **`components/licenses/DiscardLicenseButton.tsx`** — componente eliminado
- **`app/api/licenses/[id]/discard/route.ts`** — API route eliminada

### Archivos modificados

- **`app/dashboard/licenses/[id]/page.tsx`** — removidos import y bloque condicional de `DiscardLicenseButton`
- **`app/dashboard/licenses/page.tsx`** — removido `.neq('status', 'revoked')` de la query; las licencias revocadas por admin ahora son visibles al usuario (comportamiento correcto — el usuario debe saber si su licencia fue revocada)

---

## Sesión 19 — Ciclo de vida completo de licencias: pagos fallidos, emails transaccionales, cron y archivo

### Contexto y motivación

Tras la normalización del sistema de trials (Sesión 17) y la eliminación del botón "Discard license" (Sesión 18), se realizó un análisis comparativo del sistema frente a plataformas de referencia como Gumroad, LemonSqueezy y Paddle. Este análisis reveló cuatro brechas relevantes respecto al estándar de la industria.

La primera era un problema de sincronización en la product page: un trial expirado en base de datos —cuyo campo `expires_at` ya había pasado— seguía bloqueando la compra de planes de pago, porque la query de la tienda calculaba `ownedPlanIds` filtrando únicamente por `status IN ('active', 'trial')` sin verificar si la fecha ya había pasado. El sistema de expiración automática sí existía —el verify API lo realiza al detectar una licencia vencida— pero nunca se llamaba desde la tienda.

La segunda era la falta de gestión de pagos fallidos en suscripciones. Si Stripe no podía cobrar una renovación, la licencia permanecía como `active` durante todo el período de reintentos (hasta dos semanas), y el usuario no era notificado. En producción, esto implica que el usuario podría descubrir la pérdida de acceso solo cuando el período de gracia terminase, sin haber tenido oportunidad de actualizar su método de pago.

La tercera era la ausencia total de emails transaccionales. El sistema no enviaba ningún email ante eventos relevantes del ciclo de vida de una licencia —fallos de pago, cancelaciones, expiración de trials—. Esto es funcionalidad considerada básica en cualquier SaaS comercial.

La cuarta era la gestión del dashboard: a medida que un usuario acumula licencias (trials expirados, productos promocionales, planes descontinuados), el panel se llena de entradas irrelevantes sin ninguna forma de organización. Plataformas como Steam o itch.io permiten archivar o marcar como ocultas entradas de la biblioteca sin eliminarlas.

---

### Diseño previo — opciones evaluadas

**Manejo de pagos fallidos (Feature B):**

| Opción | Descripción | Decisión |
|--------|-------------|----------|
| A — Suspender con reintentos | Marcar como `suspended` y revertir a `active` si el pago se recupera | ✅ Elegida — ya teníamos el status `suspended` y el flujo de recuperación vía `invoice.payment_succeeded` |
| B — Cancelar inmediatamente | Pasar la licencia a `expired` al primer fallo | ❌ Descartada — Stripe recomienda no cancelar durante el período de reintentos y perjudica al usuario |
| C — No hacer nada | Esperar a `customer.subscription.deleted` para actuar | ❌ Descartada — el usuario queda sin información durante semanas |

**Proveedor de email transaccional (Feature C):**

| Opción | Descripción | Decisión |
|--------|-------------|----------|
| A — Resend + React Email | API REST limpia, templates como componentes React con tipado | ✅ Elegida — cohesión con el stack, developer experience excelente, dashboard con historial de emails |
| B — SendGrid | Orientado a email marketing masivo | ❌ Descartada — API más compleja, tier gratuito más restrictivo, overkill para emails transaccionales |
| C — nodemailer + SMTP | Envío directo con servidor SMTP externo | ❌ Descartada — añade dependencia de infraestructura, sin garantías de entregabilidad propias |

**Cron para aviso de trial expirando (Feature D):**

| Opción | Descripción | Decisión |
|--------|-------------|----------|
| A — Edge Function Deno → endpoint Next.js | La Edge Function es un dispatcher; toda la lógica vive en Next.js | ✅ Elegida — reutiliza los módulos y patrones del stack existente |
| B — Todo en la Edge Function Deno | Reimplementar lookup, rendering y Resend en Deno | ❌ Descartada — React Email `render()` depende de `react-dom/server`, no disponible en Deno |
| C — Vercel Cron Jobs | Endpoint HTTP con schedule en `vercel.json` | ❌ Descartada — crea dependencia de plataforma de despliegue |
| D — pg_cron (Postgres) | Función PL/pgSQL con schedule | ❌ Descartada — no puede hacer llamadas HTTP a Resend directamente |

**Ocultar licencias (Feature E):** la columna `hidden boolean NOT NULL DEFAULT false` se añadió directamente en `licenses`. La alternativa —una tabla separada de preferencias de UI por usuario— se descartó por añadir complejidad innecesaria para una única preferencia binaria.

---

### Planteamiento inicial vs. implementación real

En Feature C, se planteó inicialmente que las funciones de envío recibirían directamente el `userId` y todos los datos del producto como parámetros, para evitar hacer más queries. Al implementarlo, se comprobó que esto trasladaba responsabilidad de lookup al caller (los webhook handlers), que tendría que conocer más del dominio de los emails de lo necesario. Se adoptó un diseño más encapsulado: todas las funciones de `send.tsx` reciben únicamente el `licenseId`, y una función privada `getEmailData` deriva internamente el email del usuario, el nombre del producto, el nombre del plan y `expires_at`. Los webhook handlers solo necesitan pasar el ID.

En Feature D, el planteamiento inicial era incluir toda la lógica directamente en la Edge Function Deno. Al comenzar la implementación quedó claro que `@react-email/render` depende internamente de `react-dom/server`, que no está disponible en el runtime Deno de Supabase. Se pivotó al patrón dispatcher descrito arriba.

---

### Implementación

**`app/products/[slug]/page.tsx`** — la query de `ownedPlanIds` recibió un filtro adicional con `or('expires_at.is.null,expires_at.gt.TIMESTAMP')`. Este filtro excluye de "owned" las licencias cuya fecha de expiración ya ha pasado, permitiendo que el usuario vea y compre los planes de pago aunque tenga un trial expirado en DB con `status='trial'`. La query de `usedTrialPlanIds`, en cambio, no lleva este filtro: para controlar que no se repita un trial sí interesa detectar incluso los históricos expirados.

**`lib/stripe/webhook-handlers.ts`** — se añadieron tres cambios. Primero, el nuevo handler `handleInvoicePaymentFailed`, que extrae el `subscriptionId` desde `invoice.parent.subscription_details.subscription` (la estructura del Stripe API v2026, donde `invoice.subscription` ya no existe), busca la licencia por `stripe_subscription_id`, actualiza `status = 'suspended'`, registra un evento en `license_events` con `reason: 'payment_failed'` y despacha el email. Segundo, `handleInvoicePaymentSucceeded` se extendió para seleccionar también el campo `status` de la licencia y llamar a `sendPaymentRecoveredEmail` solo si el status previo era `suspended`, garantizando que el email de recuperación se envía únicamente cuando hay una suspensión anterior (no en cada renovación normal). Tercero, `handleSubscriptionUpdated` se extendió para también leer `cancel_at_period_end` antes del update y llamar a `sendSubscriptionCancelledEmail` solo cuando la transición es `false → true`, evitando emails duplicados en reconexiones o actualizaciones neutras.

**`lib/email/send.tsx`** — archivo con extensión `.tsx` (es necesaria porque usa JSX para instanciar los componentes React Email). Cada función pública protege su ejecución completa en un bloque `try/catch` con `console.error`, de modo que cualquier fallo de red, de Resend o de lookup de DB no propague una excepción al webhook handler —lo que provocaría que Stripe reintentase el evento indefinidamente—. Si la variable `RESEND_API_KEY` no está configurada, las funciones retornan sin hacer nada, lo que permite trabajar localmente sin una cuenta Resend activa.

**`app/api/internal/trial-reminder/route.ts`** — endpoint POST protegido con header `x-internal-secret`. Busca licencias con `status='trial'`, `expires_at` dentro del intervalo [ahora, ahora+3 días], y `metadata->>'trial_reminder_sent' IS NULL`. Para cada una, calcula los días restantes, llama a `sendTrialExpiringEmail`, y actualiza `metadata` fusionando el valor existente con `{ trial_reminder_sent: true }` para evitar reenvíos en ejecuciones futuras.

**`supabase/functions/trial-expiry-reminder/index.ts`** — Edge Function Deno mínima. Lee `SITE_URL` e `INTERNAL_SECRET` de los secrets de Supabase, hace una llamada `fetch POST` al endpoint interno de Next.js y devuelve la respuesta. El schedule se configura en el dashboard de Supabase con el cron `0 9 * * *` (diario a las 09:00 UTC).

**Feature E:** se añadió la columna `hidden boolean NOT NULL DEFAULT false` a la tabla `licenses` mediante migración. La ruta `PATCH /api/licenses/[id]/hide` aplica el filtro `user_id = auth.user.id` (anti-IDOR) y actualiza el campo. El dashboard de licencias pasa a ejecutar dos queries en paralelo con `Promise.all`: una para las licencias del modo actual (`hidden=false` o `hidden=true` según el query param `?show_hidden=1`) y otra para el conteo de licencias ocultas, que se muestra como enlace si es mayor que cero. El componente `HideLicenseButton` es un Client Component que hace la llamada PATCH y llama a `router.refresh()` para actualizar la vista sin recarga completa.

---

### Problemas técnicos

> **Problema:** al importar `render` desde `@react-email/components`, TypeScript no encontraba la función exportada.
>
> **Causa:** `render` no está re-exportada desde `@react-email/components`; vive en la sub-dependency `@react-email/render`, instalada automáticamente pero que debe importarse directamente.
>
> **Solución:** cambiar el import a `import { render } from '@react-email/render'`.

> **Problema:** el handler `handleSubscriptionUpdated` enviaba el email de cancelación en cada actualización del webhook, no solo al cancelar.
>
> **Causa:** el código actualizaba `cancel_at_period_end` en DB y luego llamaba al email condicionando únicamente en el valor nuevo (`subscription.cancel_at_period_end === true`), sin comparar con el estado previo en DB.
>
> **Solución:** se modificó la query inicial para incluir `cancel_at_period_end` en el select, permitiendo comparar `subscription.cancel_at_period_end && !license.cancel_at_period_end` antes de despachar el email.

> **Problema:** no era posible filtrar por la ausencia de una clave en un campo JSONB con el cliente Supabase JS usando `.is()`.
>
> **Causa:** el path JSONB con operador `->>` no es compatible con el método `.is()` del cliente, que espera un nombre de columna simple.
>
> **Solución:** usar `.filter('metadata->>trial_reminder_sent', 'is', null)`, que pasa el filtro como expresión de path al operador PostgREST subyacente.

---

### Resultado y estado final

El sistema dispone ahora de un ciclo de vida de licencias completamente instrumentado. Ante un fallo de pago, la licencia pasa a `suspended`, el usuario recibe un email explicando que el acceso se mantiene mientras Stripe reintenta el cobro. Si el pago se recupera, la licencia vuelve a `active` automáticamente y el usuario recibe confirmación. Si cancela una suscripción, recibe un email con la fecha exacta hasta la que mantiene acceso. Si su trial está a punto de expirar, recibe un aviso tres días antes gracias al cron diario. El dashboard permite además ocultar cualquier licencia que el usuario considere irrelevante, con posibilidad de restaurarla en cualquier momento desde `/dashboard/licenses?show_hidden=1`.

---

## Sesión 20 — Campo "días gratis" en formulario de plan de suscripción

### Contexto y motivación

En la Sesión 16 se implementó el soporte completo para suscripciones con trial nativo de Stripe: el checkout enviaba `subscription_data: { trial_period_days }`, el webhook creaba la licencia con `status='trial'`, y el sistema de emails notificaba al usuario cuando el período estaba por terminar. Sin embargo, toda esa infraestructura era inutilizable porque el formulario de creación de planes en el admin nunca exponía el campo `trial_days` para planes de tipo `subscription`. El campo solo aparecía al seleccionar el tipo `trial` (plan standalone gratuito). Un administrador que quisiera crear una suscripción con período de prueba no tenía forma de configurarlo desde la interfaz.

---

### Diseño previo — opciones evaluadas

La única opción razonable era extender la condición existente en el formulario para mostrar `trial_days` también cuando el tipo seleccionado es `subscription`. No se consideró añadir un checkbox separado para activar el trial, ya que el campo numérico vacío ya comunica suficientemente que es opcional: si no se rellena, la suscripción arranca con cobro inmediato; si se rellena, se activa el trial de Stripe.

Se planteó si era necesario añadir validación Zod para exigir `trial_days` cuando el tipo es `trial` standalone. Se decidió no añadirla para no sobrecargar el cambio; en la práctica el admin siempre lo completa y el campo tiene `min=1` en el input HTML.

---

### Implementación

**`components/admin/LicensePlanForm.tsx`** — la condición `{watchType === 'trial' && ...}` que rodeaba el campo `trial_days` se cambió a `{(watchType === 'trial' || watchType === 'subscription') && ...}`. Se añadió lógica condicional dentro del campo para diferenciar el contexto:

- **Label**: cuando el tipo es `subscription`, el label pasa a ser *"Días gratis antes del primer cobro (opcional)"*; cuando es `trial`, mantiene *"Días de prueba"*.
- **Placeholder**: cuando el tipo es `subscription`, muestra *"Ej: 7, 14, 30…"* para orientar al admin.
- **Descripción**: cuando el tipo es `subscription`, aparece un texto de ayuda: *"Se solicita tarjeta al registrarse. El cobro inicia al terminar el período de prueba."*

No fue necesario modificar el schema Zod (ya aceptaba `trial_days` como opcional para cualquier tipo), ni la server action de creación/actualización (ya guardaba el campo en la DB), ni ninguna otra capa del sistema.

---

### Resultado y estado final

El ciclo completo de una suscripción con trial está ahora totalmente accesible desde el admin. Al crear o editar un plan de suscripción, el campo de días de prueba aparece como campo opcional. Si se configura, los usuarios que suscriban ese plan verán el período de prueba en el checkout de Stripe (con tarjeta requerida desde el inicio), recibirán un aviso por email tres días antes del primer cobro, y su licencia pasará automáticamente de `trial` a `active` cuando Stripe procese el primer pago satisfactoriamente.

---

## Sesión 21 — Course viewer: curriculum builder en admin y player en dashboard

### Contexto y motivación

El tipo `course` ya existía como valor en `products.type` y el dashboard de licencias ya mostraba un botón "Go to course" en las licencias de tipo curso, pero la ruta `/dashboard/courses/[productId]` no existía y devolvía un 404. Tampoco existían en la base de datos estructuras para almacenar el contenido del curso (módulos y lecciones) ni el progreso del alumno. El sistema carecía de toda la capa de LMS (Learning Management System): ningún administrador podía crear contenido de curso, y ningún usuario podía consumirlo.

El objetivo era construir el ciclo completo en dos partes: (1) un curriculum builder en el panel de administración para que el admin pueda estructurar el contenido, y (2) un course viewer en el dashboard del usuario para que el alumno consuma el curso y realice seguimiento de su progreso.

---

### Diseño previo — opciones evaluadas

**Formato de vídeo:**

| Opción | Descripción | Decisión |
|--------|-------------|----------|
| A — Embed por URL (YouTube/Vimeo) | El admin pega una URL pública; la plataforma la convierte a iframe en el render | ✅ Elegida — coste cero, infraestructura gestionada por terceros, sin límites de almacenamiento |
| B — Upload directo al bucket de Supabase Storage | Vídeo almacenado en la plataforma, entregado con URL firmada | ❌ Descartada — coste de almacenamiento elevado, complejidad de codificación/streaming, innecesario cuando los proveedores gratuitos ya ofrecen CDN global |

**Estructura de contenido:**

| Opción | Descripción | Decisión |
|--------|-------------|----------|
| A — Módulos → Lecciones (dos niveles) | Cada curso tiene módulos que agrupan lecciones | ✅ Elegida — estándar de la industria (Udemy, Teachable, Thinkific), intuitivo para admin y alumno |
| B — Solo lecciones (un nivel) | Sin agrupación por tema | ❌ Descartada — no escala para cursos con más de 10 lecciones; carece de organización temática |

**Reordenamiento en el curriculum builder:**

| Opción | Descripción | Decisión |
|--------|-------------|----------|
| A — Botones ▲▼ | Flechas de subir/bajar que hacen swap de `position` entre ítems adyacentes | ✅ Elegida — sin dependencias externas, implementación clara, suficiente para la escala esperada |
| B — Drag & drop (react-beautiful-dnd, dnd-kit) | Arrastrar para reordenar | ❌ Descartada — añade una dependencia grande para funcionalidad no crítica; la UX para admin que construye curriculum no exige velocidad de reordenamiento |

**Progreso del alumno:**

La única opción razonable era una tabla `course_progress` con `UNIQUE(user_id, lesson_id)` para registrar qué lecciones ha completado cada usuario. El toggle se implementó como INSERT ON CONFLICT (marcar completa) y DELETE (desmarcar), lo que garantiza idempotencia sin race conditions.

**Cómo proteger el acceso al contenido:**

Se evaluó si la política RLS debería restringir el acceso a `course_modules` y `course_lessons` solo a usuarios con licencia activa. Se decidió dar acceso SELECT a todos los autenticados en la capa RLS, y hacer la verificación de licencia en la server component (`app/dashboard/courses/[productId]/page.tsx`), que redirige a `/dashboard/licenses` si no encuentra una licencia activa. Este enfoque es coherente con el patrón ya establecido en otras páginas del dashboard y simplifica las políticas RLS.

---

### Planteamiento inicial vs. implementación real

El planteamiento inicial contemplaba un curriculum builder con drag & drop para reordenar módulos y lecciones. Durante la discusión de diseño previo a la implementación se descartó esta opción porque añadía una dependencia de peso (dnd-kit o react-beautiful-dnd) para funcionalidad no crítica. Los botones ▲▼ resultan suficientes para la escala de un curso típico (decenas de lecciones, no cientos) y no requieren ninguna librería adicional.

La lógica de "posición actual de la lección" se planteó inicialmente en el server component directamente a partir de `searchParams.lesson`. Al implementarla, se añadió la lógica de fallback: si no hay `searchParams.lesson`, se selecciona la primera lección incompleta del primer módulo; si todas están completas, se vuelve a la primera lección del primer módulo. Este comportamiento proporciona una experiencia de retomar el curso más natural para el alumno.

---

### Implementación

**`supabase/migration.sql`** — se añadieron tres tablas al final del archivo de migraciones acumulativo:

- `course_modules`: `product_id`, `title`, `position` (entero para ordenación), `created_at`.
- `course_lessons`: `module_id`, `product_id` (redundante respecto a la FK por módulo, pero facilita queries directas sin join), `title`, `video_url` (URL cruda de YouTube o Vimeo; la conversión a URL de embed se realiza en render), `content` (texto plano/markdown), `position`, timestamps.
- `course_progress`: `user_id`, `lesson_id`, `product_id`, `completed_at`, con restricción `UNIQUE(user_id, lesson_id)` para garantizar un único registro de progreso por alumno por lección.

También se añadieron índices en `(product_id)`, `(module_id)` y `(user_id, product_id)` para las queries más frecuentes, y políticas RLS que permiten SELECT a todos los autenticados para módulos y lecciones, y gestión propia del progreso para los usuarios.

**`types/database.ts`** — se añadieron los tres tipos generados (`course_modules`, `course_lessons`, `course_progress`) con sus variantes Row, Insert y Update.

**`types/index.ts`** — se exportaron los alias `CourseModule`, `CourseLesson`, `CourseProgress`, y el tipo compuesto `ModuleWithLessons = CourseModule & { course_lessons: CourseLesson[] }` utilizado en el player.

**`lib/utils/course.ts`** — función `getEmbedUrl(url)` que convierte URLs de YouTube (`watch?v=` y `youtu.be/`) y Vimeo a URLs de iframe embebido. Devuelve `null` para cualquier otra URL, de modo que el componente no renderiza el iframe si no hay vídeo reconocible.

**`app/admin/products/page.tsx`** — se añadió un botón "Curriculum" en la columna de acciones de cada fila de la tabla de productos, visible únicamente cuando `product.type === 'course'`. El botón enlaza a `/admin/products/[id]/curriculum`. Dado que la tabla ya tenía botones "Planes" y "Editar", este cambio siguió el mismo patrón sin tocar la estructura de la página.

**`app/admin/products/[id]/curriculum/page.tsx`** — Server Component que también define ocho server actions: `createModule`, `updateModule`, `deleteModule`, `moveModule`, `createLesson`, `updateLesson`, `deleteLesson`, `moveLesson`. La lógica de reordenamiento (`move*`) obtiene todos los hermanos del ítem ordenados por `position`, localiza el ítem objetivo y su vecino inmediato, y realiza dos `UPDATE` para intercambiar sus valores de `position`. La página carga el producto (con 404 si no existe o no es de tipo `course`), y los módulos con sus lecciones ordenadas, pasándolo todo al componente cliente `CurriculumBuilder`.

**`components/admin/CurriculumBuilder.tsx`** — Client Component que gestiona la interfaz completa del curriculum builder. Usa `useTransition` para deshabilitar botones mientras se ejecutan las server actions y `router.refresh()` para sincronizar el estado tras cada mutación. Cada módulo es expandible y muestra su lista de lecciones. Dispone de formularios inline para crear/editar módulos (solo `title`) y lecciones (`title`, `video_url`, `content`). Los botones ▲▼ están deshabilitados en los extremos de la lista para evitar operaciones sin efecto.

**`app/api/courses/[productId]/progress/route.ts`** — API route POST que recibe `{ lesson_id, completed: boolean }`. Antes de ejecutar la operación, verifica: (1) que el usuario tiene sesión activa, (2) que posee una licencia con `status IN ('active', 'trial')` para el producto (anti-IDOR), y (3) que el `lesson_id` pertenece efectivamente al `productId` indicado. Para marcar completa usa `upsert` con `ignoreDuplicates: true`; para desmarcar usa `delete` filtrando por `user_id` y `lesson_id`.

**`app/dashboard/courses/[productId]/page.tsx`** — Server Component de la vista de curso. Verifica que el producto existe y es de tipo `course`; verifica que el usuario tiene una licencia activa (`active` o `trial`) para ese producto, redirigiendo a `/dashboard/licenses` si no la tiene. Carga los módulos con sus lecciones ordenadas por `position`, y el progreso del usuario. Implementa la lógica de selección de lección inicial: usa `searchParams.lesson` si es válido; sino busca la primera lección sin entrada en `course_progress`; sino usa la primera lección del primer módulo.

**`components/courses/CourseViewer.tsx`** — Client Component con layout de dos columnas: sidebar (288px, colapsable) y área de contenido principal. El sidebar muestra la barra de progreso (`completedCount / totalLessons`) y la lista de módulos con sus lecciones, indicando con `CheckCircle2` (verde) o `Circle` las lecciones completadas y pendientes respectivamente, y resaltando la lección activa. El área principal muestra el título de la lección, el iframe de vídeo en proporción 16:9 (si hay URL reconocible), el contenido textual, y los botones de navegación Anterior/Siguiente calculados desde la lista plana de todas las lecciones. El botón "Marcar como completada" realiza una actualización optimista del estado local (un `Set<string>` de IDs completados) y llama a la API de progreso; si la llamada falla, revierte el estado y muestra un toast de error. Al marcar completa una lección que tiene siguiente, el componente navega automáticamente a la siguiente.

---

### Problemas técnicos

No se encontraron problemas técnicos significativos durante esta sesión. Las únicas advertencias del diagnóstico de TypeScript eran pre-existentes (clases canónicas de Tailwind) y no afectaban a los archivos nuevos.

---

### Resultado y estado final

El sistema dispone ahora de un LMS básico completamente funcional. Un administrador puede navegar a la página de curriculum de cualquier producto de tipo `course` y construir la estructura del curso: crear módulos temáticos, añadir lecciones a cada módulo con URL de vídeo de YouTube o Vimeo y/o texto explicativo, y reordenar tanto módulos como lecciones con los botones ▲▼. Un usuario con licencia activa de un curso puede acceder al player en `/dashboard/courses/[productId]`, ver el vídeo embebido de cada lección, leer el contenido de texto, marcar lecciones como completadas (con barra de progreso en tiempo real), navegar entre lecciones con los botones Anterior/Siguiente, y recargar la página manteniendo el progreso guardado en base de datos. Si el usuario no tiene licencia activa para el curso, es redirigido al dashboard de licencias.

---

## Sesión 22 — Markdown y archivos adjuntos por lección

### Contexto

Tras completar el course viewer en la sesión anterior, surgió la necesidad de enriquecer el contenido de las lecciones con dos capacidades que son estándar en los LMS de la industria: renderizado de texto en Markdown (para formateo rico sin editor WYSIWYG) y adjuntar un archivo descargable por lección (PDFs, ZIPs, recursos complementarios).

---

### Diseño previo

**Formato del contenido de lección:**

| Opción | Descripción | Decisión |
|--------|-------------|----------|
| A — Texto plano | `white-space: pre-wrap`, sin parsing | ❌ Descartada — sin capacidad de formateo; poco profesional para contenido educativo |
| B — WYSIWYG (TipTap, Quill, Slate) | Editor visual con toolbar | ❌ Descartada — añaden una dependencia muy pesada (100-300 kB); la complejidad de serialización/deserialización no compensa para el alcance del proyecto |
| C — Markdown con preview | Textarea de edición + toggle "Vista previa" que renderiza con `react-markdown` | ✅ Elegida — estándar en plataformas educativas modernas (Notion, GitHub), ligero (~15 kB), soporta GFM (tablas, listas de tareas, bloques de código, `strikethrough`) |

**Archivo adjunto por lección:**

| Opción | Descripción | Decisión |
|--------|-------------|----------|
| A — URL externa | Admin introduce una URL directa al archivo | ❌ Descartada — no hay control de acceso; cualquiera con la URL puede descargar sin licencia |
| B — Upload al bucket `product-files` de Supabase | Almacenamiento en el bucket existente; descarga mediante URL firmada con verificación de licencia | ✅ Elegida — reutiliza la infraestructura existente; la entrega segura ya estaba implementada para archivos de productos; coherente con el patrón establecido |

**Ruta de almacenamiento dentro del bucket:**

Se eligió `courses/{lessonId}/{filename}` para distinguir los archivos de lección (que son más granulares y cambian con frecuencia) de los archivos de producto que se almacenan en `{productId}/{filename}`.

**ID temporal para lecciones nuevas:**

Las lecciones nuevas no tienen ID de base de datos mientras el formulario está abierto. Se resuelve generando un UUID estable en el cliente con `crypto.randomUUID()` en el montaje del componente (`useState(() => initial?.id ?? crypto.randomUUID())`). Este ID se usa como carpeta en storage; si la lección finalmente no se crea, el archivo queda huérfano (comportamiento aceptado, mismo patrón que los archivos de producto).

---

### Planteamiento inicial vs. implementación real

El planteamiento inicial consideraba que la columna `file_path` ya existiría en `course_lessons`. Al implementarlo se verificó que no se había incluido en la migración de la sesión anterior, por lo que fue necesario añadir un `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` como nueva sección en `migration.sql`.

La preview de Markdown en el admin se planteó inicialmente como un panel lateral (split view). Durante la implementación se simplificó a un toggle Edit/Vista previa sobre el mismo área, lo que requiere menos espacio y es suficiente para validar el contenido antes de guardar.

La integración de `@tailwindcss/typography` en un proyecto con Tailwind v4 requirió registrar el plugin via `@plugin "@tailwindcss/typography"` en `globals.css` en lugar del método clásico de `tailwind.config.js`, ya que el proyecto usa la configuración CSS-first de Tailwind v4.

---

### Implementación

**`supabase/migration.sql`** — se añadió al final del archivo:
```sql
-- Sesión 22: archivo adjunto por lección
ALTER TABLE course_lessons ADD COLUMN IF NOT EXISTS file_path TEXT;
```

**`types/database.ts`** — se añadió `file_path: string | null` a las variantes Row, Insert y Update de `course_lessons`.

**`app/globals.css`** — se añadió la línea `@plugin "@tailwindcss/typography"` para registrar el plugin de tipografía de Tailwind v4 (necesario para las clases `prose`).

**`app/api/admin/lesson-upload/route.ts`** — nueva API route que gestiona subida y eliminación de archivos de lección:
- `POST`: recibe `FormData` con `file`, `lessonId` y opcionalmente `currentFilePath` (archivo anterior a reemplazar). Elimina el archivo previo si existe, sube el nuevo a `courses/{lessonId}/{filename}` con `upsert: true`, y devuelve `{ path }`.
- `DELETE`: recibe `{ filePath }` y elimina el archivo del bucket.
- Ambas operaciones requieren rol `admin` verificado con `requireAdmin()`.

**`app/api/courses/[productId]/lessons/[lessonId]/download/route.ts`** — nueva API route GET que genera una URL firmada para descarga:
1. Verifica sesión activa del usuario.
2. Comprueba que la lección existe y pertenece al `productId` indicado (anti-IDOR).
3. Verifica que la lección tiene `file_path`.
4. Verifica licencia activa (`active` o `trial`) del usuario para el producto.
5. Genera URL firmada con `createSignedUrl(path, 3600, { download: true })` y redirige.

**`components/admin/CurriculumBuilder.tsx`** — se actualizó la interfaz `LessonValues` para incluir `file_path`; se reescribió `LessonForm` con:
- Toggle Edit/Vista previa para el campo `content`, con `<ReactMarkdown remarkPlugins={[remarkGfm]}>` en modo preview.
- Área de adjunto de archivo: muestra el nombre del archivo subido con botón de eliminar, o una zona de drop/click (`<input type="file">` oculto) con estado `uploading`. La subida se realiza en el momento de seleccionar el archivo (no al guardar el formulario).
- En la lista de lecciones, se añadió el icono `Paperclip` para indicar que la lección tiene un archivo adjunto.

**`app/admin/products/[id]/curriculum/page.tsx`** — se actualizó la interface `LessonValues` local y las tres server actions afectadas:
- `createLesson` y `updateLesson`: incluyen `file_path: values.file_path || null`.
- `deleteLesson`: antes de eliminar el registro de BD, consulta `file_path` de la lección y, si existe, lo elimina del bucket `product-files` con `createServiceClient().storage.from('product-files').remove([file_path])` para evitar archivos huérfanos.

**`components/courses/CourseViewer.tsx`** — se reemplazó el renderizado de texto plano por `<ReactMarkdown remarkPlugins={[remarkGfm]}>` dentro de un `<div className="prose prose-sm max-w-none dark:prose-invert">`. Se añadió un enlace de descarga que apunta a `/api/courses/${productId}/lessons/${currentLesson.id}/download`, visible únicamente cuando `currentLesson.file_path` es no nulo.

---

### Problemas técnicos

**`@tailwindcss/typography` en Tailwind v4:** el método habitual (`plugins: [require(...)]` en `tailwind.config.js`) no funciona porque el proyecto usa la sintaxis CSS-first de Tailwind v4. La solución es `@plugin "@tailwindcss/typography"` en `globals.css`.

**Bash tool timeout en `npm install`:** el primer intento de `npm install react-markdown remark-gfm @tailwindcss/typography` respondió con "No active request". Se resolvió ejecutando el mismo comando con `timeout: 60000`, que completó con éxito.

---

### Resultado y estado final

Las lecciones de los cursos ahora soportan contenido enriquecido con Markdown completo (GFM: tablas, listas de tareas, bloques de código, negrita, cursiva, etc.) con preview en tiempo real durante la edición en el admin. Además, el administrador puede adjuntar un archivo por lección (PDF, ZIP, imagen, etc.) que se almacena en el bucket `product-files`; los alumnos con licencia activa pueden descargarlo desde el player mediante una URL firmada de Supabase Storage válida durante una hora. El borrado de una lección limpia automáticamente su archivo del bucket. No se requirió ninguna nueva variable de entorno ni configuración de Stripe.

