# Plataforma de Gestión de Licencias Digitales

## ¿Qué es este proyecto?

Es una plataforma SaaS completa para **vender y gestionar licencias de productos digitales** (software, ebooks, cursos, plantillas). El núcleo del sistema no es una tienda de descargas, sino un motor de **control de licencias**: generación segura de claves, validación remota en tiempo real, control de activaciones por máquina, expiración automática, revocación y una API pública que cualquier programa externo puede consultar para verificar si una licencia es válida.

---

## Stack técnico

| Capa | Tecnología |
|------|------------|
| Framework | Next.js 16 (App Router, TypeScript) |
| UI | shadcn/ui + Tailwind CSS v4 |
| Base de datos | Supabase (PostgreSQL + Auth + Storage) |
| Pagos | Stripe (Checkout Sessions + Subscriptions + Webhooks) |
| Validación de forms | Zod + react-hook-form |
| Utilidades | date-fns, lucide-react, sonner |

---

## Modelo de negocio

Un administrador crea **productos digitales** y les asigna hasta tres **planes de licencia**:

| Tipo de plan | Stripe Mode | Expiración | Caso de uso |
|---|---|---|---|
| `perpetual` | `payment` (único) | Nunca | Compra de por vida |
| `subscription` | `subscription` (recurrente) | Renueva cada mes/año | SaaS con pago mensual |
| `trial` | Sin Stripe | `now + trial_days` | Prueba gratuita con límite de tiempo |

Cada licencia controla cuántos dispositivos/máquinas pueden activarla simultáneamente (`max_activations`). El usuario puede ver y desactivar sus máquinas desde el dashboard.

---

## Flujo completo de compra

```
Usuario → /products/[slug] → elige plan → POST /api/checkout
  ├─ Trial (precio 0): genera licencia directamente sin Stripe
  └─ Pago/Suscripción: → Stripe Checkout Session → redirect a Stripe
       └─ Pago exitoso → Stripe llama a POST /api/webhooks/stripe
            └─ checkout.session.completed → genera licencia → la guarda en DB
                 └─ Usuario pasa por /checkout/success
```

---

## API Pública de Licencias (`/api/v1/licenses/...`)

Esta es la parte de mayor valor técnico del proyecto. Permite que **software externo** (una aplicación de escritorio, CLI, extensión, etc.) consulte la validez de una licencia sin necesidad de sesión de usuario.

### `POST /api/v1/licenses/verify`

Verifica si una clave es válida. Si se incluye `machine_id`, también verifica que esa máquina esté activada.

**Request:**
```json
{ "license_key": "ABCDE-FGHIJ-KLMNO-PQRST", "machine_id": "optional-fingerprint" }
```

**Response:**
```json
{
  "valid": true,
  "status": "active",
  "type": "perpetual",
  "expires_at": null,
  "product": { "id": "uuid", "name": "Mi Software" },
  "activations": { "current": 1, "max": 3 }
}
```

**Caché:** respuestas negativas (`valid: false`) se cachean 30 s en el edge para reducir carga en DB. Respuestas positivas son siempre `no-store`.

### `POST /api/v1/licenses/activate`

Registra un nuevo dispositivo en la licencia. Falla si ya se alcanzó `max_activations`.

**Request:**
```json
{ "license_key": "...", "machine_id": "fingerprint", "machine_name": "MacBook Pro" }
```

### `POST /api/v1/licenses/deactivate`

Desvincula un dispositivo. Decrementa `activation_count`.

**Request:**
```json
{ "license_key": "...", "machine_id": "fingerprint" }
```

**Rate limiting:** las tres rutas tienen límite de 60 request/min/IP (en memoria; para producción usar Upstash Redis).

---

## Estructura de carpetas

```
app/
├── page.tsx                           # Home pública (hero, catálogo destacado)
├── products/
│   ├── page.tsx                       # Catálogo con filtro por tipo
│   └── [slug]/page.tsx               # Detalle de producto + selector de planes
├── checkout/
│   ├── success/page.tsx
│   └── cancel/page.tsx
├── auth/
│   ├── login/page.tsx
│   ├── register/page.tsx
│   └── callback/route.ts             # Supabase code exchange
├── dashboard/                        # Protegido: usuarios autenticados
│   ├── layout.tsx                    # Sidebar con navegación
│   ├── page.tsx                      # Overview: licencias activas, órdenes recientes
│   ├── licenses/
│   │   ├── page.tsx                  # Mis licencias
│   │   └── [id]/page.tsx            # Detalle: clave, activaciones, desactivar máquinas
│   ├── orders/
│   │   ├── page.tsx
│   │   └── [id]/page.tsx
│   └── profile/page.tsx
├── admin/                            # Protegido: role = 'admin'
│   ├── layout.tsx                    # Sidebar admin
│   ├── page.tsx                      # Stats: revenue, licencias, órdenes, clientes
│   ├── products/
│   │   ├── page.tsx
│   │   ├── new/page.tsx
│   │   └── [id]/
│   │       ├── edit/page.tsx
│   │       └── plans/page.tsx        # CRUD de planes del producto
│   ├── licenses/
│   │   ├── page.tsx                  # Buscar por clave, filtrar por estado
│   │   └── [id]/page.tsx            # Revocar, suspender, historial de eventos
│   ├── orders/page.tsx
│   ├── coupons/page.tsx
│   ├── reviews/page.tsx
│   └── customers/page.tsx
└── api/
    ├── v1/licenses/
    │   ├── verify/route.ts
    │   ├── activate/route.ts
    │   └── deactivate/route.ts
    ├── admin/licenses/[id]/
    │   ├── revoke/route.ts
    │   └── suspend/route.ts
    ├── webhooks/stripe/route.ts
    ├── checkout/route.ts
    └── coupons/validate/route.ts

components/
├── layout/        Header, Footer, HeaderSignOut
├── store/         ProductCard, ProductGrid, PlanCard, PlanSelector
├── licenses/      LicenseCard, LicenseKeyDisplay, ActivationList
└── admin/         ProductForm, LicensePlanForm, PlansManager, RevokeDialog,
                   SuspendButton, CreateCouponDialog, ToggleCouponButton,
                   ApproveReviewButton

lib/
├── supabase/      client.ts, server.ts, admin.ts
├── stripe/        client.ts, webhook-handlers.ts
├── licenses/      generate.ts
└── utils/         formatters.ts, validators.ts

types/
├── database.ts    Tipos completos de Supabase (manual)
└── index.ts       Row helpers, composite types, constantes

supabase/migration.sql   Esquema completo, RLS, triggers, índices
scripts/load-test.mjs    Script de carga para medir latencia p95
```

---

## Base de datos

### Tablas principales

| Tabla | Propósito |
|-------|-----------|
| `profiles` | Espejo de `auth.users` con campo `role` ('admin' / 'customer') |
| `products` | Catálogo: nombre, slug, tipo, estado, thumbnail |
| `license_plans` | Planes de cada producto: precio, tipo, max_activations, trial_days |
| `orders` / `order_items` | Historial de compras, vinculado a Stripe |
| `licenses` | **Tabla central**: clave, estado, tipo, expiración, conteo de activaciones |
| `license_activations` | Dispositivos registrados por licencia (machine_id, is_active) |
| `license_events` | Log append-only de auditoría (issued, activated, verified, revoked…) |
| `coupons` | Códigos de descuento (porcentaje o monto fijo) |
| `reviews` | Reseñas de usuarios verificados (requieren licencia activa del producto) |

### Índices de rendimiento

```sql
idx_licenses_license_key   -- búsqueda primaria en verify/activate/deactivate
idx_licenses_status
idx_activations_license_id
idx_activations_machine_id
idx_events_license_id
```

### Seguridad (RLS)

- `licenses` / `license_activations`: el usuario solo ve las suyas; `service_role` escribe (via webhook)
- `license_events`: solo admin y `service_role` pueden leer/escribir
- `coupons`: solo admin y servidor
- `profiles`: cada usuario gestiona el suyo; admin ve todos

---

## Variables de entorno requeridas

```bash
# Supabase
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=        # solo server-side

# Stripe
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=
STRIPE_SECRET_KEY=                # solo server-side
STRIPE_WEBHOOK_SECRET=

# App
NEXT_PUBLIC_SITE_URL=http://localhost:3000
LICENSE_KEY_SECRET=               # opcional, para HMAC si se implementa firma
```

---

## Cómo iniciar en desarrollo

```bash
# 1. Instalar dependencias
npm install

# 2. Copiar variables de entorno
cp .env.local.example .env.local   # llenar con tus keys de Supabase y Stripe

# 3. Ejecutar la migración SQL en Supabase
#    Copiar el contenido de supabase/migration.sql y correrlo en el SQL Editor

# 4. Asignar role 'admin' al primer usuario
#    UPDATE profiles SET role = 'admin' WHERE email = 'tu@email.com';

# 5. Correr en local
npm run dev

# 6. Escuchar webhooks de Stripe (terminal separada)
stripe listen --forward-to localhost:3000/api/webhooks/stripe
```

---

## Load test (rendimiento)

```bash
# Objetivo: p95 < 100ms bajo 100 req/s en /api/v1/licenses/verify
node scripts/load-test.mjs TU-LICENSE-KEY 20 15
```

---

## Roles y accesos

| Ruta | Acceso |
|------|--------|
| `/` `/products` `/products/[slug]` | Público |
| `/auth/login` `/auth/register` | Público (redirige si ya hay sesión) |
| `/dashboard/**` | Autenticado (`role` = 'customer' o 'admin') |
| `/admin/**` | Solo `role` = 'admin' |
| `/api/v1/licenses/**` | Público (con rate limiting) |
| `/api/checkout` `/api/coupons/validate` | Autenticado |
| `/api/webhooks/stripe` | Solo Stripe (verificación HMAC) |
| `/api/admin/**` | Solo admin (verificado server-side) |
