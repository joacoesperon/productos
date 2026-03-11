# Reglas para mantener memoria.md

## Propósito

`memoria.md` es el diario de desarrollo del proyecto. Su función es doble:

1. **Técnica:** registro de referencia para entender qué existe, cómo funciona y por qué.
2. **Académica:** fuente de material para redactar la memoria formal del TFG. Cuando llegue ese momento, toda la información necesaria debe estar aquí: el contexto del problema, las decisiones tomadas, las alternativas descartadas, los errores encontrados y cómo se resolvieron, y los resultados obtenidos.

Cada vez que implementes una funcionalidad, corrijas un bug relevante, tomes una decisión de diseño o arquitectura, o refactorices algo significativo, debes registrarlo en `memoria.md` siguiendo el formato de esta guía.

---

## Cuándo actualizar memoria.md

Actualiza `memoria.md` **después de cada una de estas acciones**:

- Implementación de una funcionalidad nueva (grande o pequeña).
- Corrección de un bug no trivial (cualquier cosa que requiriera análisis o más de un intento).
- Decisión de diseño o arquitectura (elegir una tecnología, un patrón, una estructura de datos, un flujo).
- Cambio de enfoque: cuando se descarta lo que se había planteado inicialmente y se adopta otra solución.
- Refactorización que afecte a la estructura del proyecto.
- Problema técnico encontrado durante el desarrollo, aunque no sea un bug del código (limitaciones de una librería, comportamiento inesperado de una API, etc.).

---

## Estructura de cada entrada

Cada entrada en `memoria.md` corresponde a una sesión de trabajo o a un conjunto de cambios relacionados. Usa el siguiente formato:

```
## Sesión N — Título descriptivo de lo que se implementó
```

Dentro de cada sesión, incluye los bloques que apliquen según lo que ocurrió. No todos son obligatorios en todas las sesiones, pero sí en las que correspondan.

---

### Bloque 1: Contexto y motivación

**Qué incluir:** Por qué se implementó esto. Qué problema resuelve para el usuario o para el sistema. Qué faltaba o qué no funcionaba antes.

**Por qué importa para la memoria:** La memoria académica exige justificar por qué cada parte del sistema existe. Sin este contexto, la implementación parece arbitraria.

**Ejemplo de lo que se espera:**

> El sistema carecía de mecanismo para que los usuarios pudiesen gestionar sus licencias activas. Cuando un usuario cambiaba de dispositivo, no había forma de liberar una activación existente, lo que hacía que el límite de activaciones se agotase sin posibilidad de recuperación. Era necesario implementar una vista de gestión que permitiese al usuario ver sus dispositivos activos y desactivar los que ya no usase.

---

### Bloque 2: Diseño previo — opciones evaluadas

**Qué incluir:** Antes de implementar, ¿qué opciones se consideraron? Describe brevemente cada alternativa y por qué se eligió una sobre las otras. Si la decisión fue obvia o no hubo alternativas reales, lo puedes indicar brevemente.

**Por qué importa para la memoria:** Demostrar que las decisiones técnicas fueron razonadas es uno de los criterios de evaluación del TFG. El tribunal valora que el estudiante haya analizado alternativas, no que simplemente haya usado lo primero que encontró.

**Formato sugerido para cuando hay varias opciones:**

| Opción | Descripción | Decisión |
|--------|-------------|----------|
| A — ... | ... | ✅ Elegida |
| B — ... | ... | ❌ Descartada — motivo |
| C — ... | ... | ❌ Descartada — motivo |

**Si solo había una opción razonable:** explícalo igualmente. Por ejemplo: *"Se usó la API de Supabase Auth directamente porque no existe alternativa dentro del stack del proyecto para gestionar sesiones de forma segura."*

---

### Bloque 3: Planteamiento inicial vs. implementación real

**Qué incluir:** Si en algún momento se planteó hacerlo de una forma y luego se cambió de enfoque durante o después de la implementación, documéntalo aquí. Describe qué se pensaba hacer originalmente y qué cambió, con el motivo.

**Por qué importa para la memoria:** El proceso de diseño iterativo es parte del trabajo de ingeniería. Documentar los cambios de enfoque muestra madurez técnica y capacidad de adaptación ante problemas reales.

**Ejemplo:**

> **Planteamiento inicial:** Se pensaba gestionar la lógica de descuento de cupones directamente en el API route de checkout, consultando y actualizando la tabla `coupons` en la misma transacción.
>
> **Problema encontrado:** Supabase no soporta transacciones explícitas en PostgREST. Si el proceso de Stripe fallaba después de decrementar el uso del cupón, el contador quedaba desincronizado sin forma de revertirlo.
>
> **Solución adoptada:** Se delegó el decremento a una función SQL (`increment_coupon_usage`) que Stripe confirma vía webhook solo cuando el pago está completado. De esta forma el contador nunca se modifica por un pago que no llegó a completarse.

---

### Bloque 4: Implementación — qué se hizo y cómo

**Qué incluir:** Los archivos creados o modificados, con una explicación de su responsabilidad. No es un listado de cambios de git; es una descripción que permita entender el sistema sin leer el código. Incluye fragmentos de código solo cuando ilustren algo no obvio: una decisión de tipado, un patrón particular, un workaround relevante.

**Nivel de detalle esperado:**

- Para cada archivo nuevo: nombre, ubicación, responsabilidad principal, y cualquier detalle de implementación que no sea evidente por el nombre.
- Para modificaciones en archivos existentes: qué se añadió o cambió y por qué, no solo que "se modificó".
- Para fragmentos de código: incluir solo cuando el código en sí sea la documentación más clara (una función con lógica no obvia, un tipo complejo, una query con joins relevantes). Acompañar siempre de una explicación.

**Lo que NO hace falta incluir aquí:** cambios de estilo CSS sin implicaciones funcionales, renombrados triviales, correcciones de typos.

---

### Bloque 5: Problemas técnicos y cómo se resolvieron

**Qué incluir:** Bugs, comportamientos inesperados de librerías, limitaciones del stack, errores de TypeScript difíciles, inconsistencias entre versiones de dependencias. Describe el síntoma, la causa raíz una vez identificada, y la solución.

**Por qué importa para la memoria:** Este bloque es directamente útil para el capítulo de implementación de la memoria, que debe demostrar que se resolvieron problemas técnicos reales. También sirve como referencia si el mismo problema reaparece.

**Formato:**

> **Problema:** [descripción del síntoma — qué fallaba y cómo se manifestaba]
>
> **Causa:** [por qué ocurría — una vez identificada]
>
> **Solución:** [qué se hizo para resolverlo]

---

### Bloque 6: Resultado y estado final

**Qué incluir:** Cómo quedó la funcionalidad después de la implementación. Qué puede hacer el usuario ahora que antes no podía. Si hay algo que quedó pendiente o incompleto, indícalo.

**Por qué importa para la memoria:** El capítulo de resultados de la memoria describe el sistema terminado. Este bloque acumula el material para esa sección.

**Ejemplo:**

> El usuario puede ahora acceder a `/dashboard/licenses`, ver todas sus licencias con su estado actual, expandir cada una para ver los dispositivos activados, y desactivar cualquiera con un click. La acción es inmediata y el límite de activaciones se recalcula en tiempo real. Las licencias de tipo `ebook` y `course` no muestran la sección de dispositivos, ya que no tienen límite de activaciones por diseño.

---

## Reglas generales de escritura

**Usa prosa, no solo listas.** Las listas de bullets son útiles para enumerar archivos o pasos, pero el razonamiento detrás de las decisiones se explica en párrafos. La memoria académica está escrita en prosa; si ahora escribes en prosa, luego será más fácil adaptarlo.

**Escribe en pasado para lo que ya se hizo.** *"Se decidió...", "Se implementó...", "El problema era..."*. Esto facilita la redacción posterior de la memoria.

**Sé específico.** *"Se mejoró el rendimiento"* no sirve. *"Se añadió un índice en `licenses(user_id)` que redujo el tiempo de la query de listado de licencias de ~800ms a ~40ms en pruebas locales con 10.000 registros"* sí sirve.

**Documenta las cosas difíciles, no las fáciles.** Si algo tardó tiempo en resolver, si requirió investigación, si hubo que revisar la documentación de una librería, o si hubo varios intentos fallidos antes de llegar a la solución: eso es lo que más vale documentar. Lo trivial puede omitirse o mencionarse brevemente.

**Mantén la coherencia entre sesiones.** Si en la Sesión 5 se tomó una decisión de diseño que en la Sesión 8 se revisa o contradice, la Sesión 8 debe referenciar explícitamente que se está cambiando algo anterior y por qué.

---

## Mantenimiento de todo.md

Además de `memoria.md`, mantén `todo.md` actualizado en todo momento. Este archivo lleva el registro de:

- **Tareas completadas:** con una marca de completado y la sesión en que se implementaron.
- **Tareas en curso:** lo que está siendo implementado ahora.
- **Tareas pendientes:** funcionalidades planificadas, mejoras identificadas, bugs conocidos.

Formato sugerido para `todo.md`:

```markdown
## Completado
- [x] Sesión 1 — Infraestructura base (Supabase, Stripe, dependencias)
- [x] Sesión 2 — Auth y layout principal
- [x] Sesión 3 — Panel admin: productos y planes
...

## En curso
- [ ] Nombre de la funcionalidad que se está implementando ahora

## Pendiente
- [ ] Funcionalidad A — descripción breve
- [ ] Funcionalidad B — descripción breve
- [ ] Bug conocido: descripción del problema
```

Cuando termines una sesión, mueve los items de "En curso" a "Completado" y actualiza "Pendiente" si surgieron nuevas tareas durante la implementación.

---

## Referencia rápida: checklist por sesión

Antes de dar por actualizada `memoria.md` tras una sesión, verifica:

- [ ] ¿Está claro el **problema o necesidad** que motivó este trabajo?
- [ ] ¿Se documentaron las **alternativas evaluadas** (aunque sea brevemente)?
- [ ] ¿Se explicó qué se **planteó inicialmente** y qué cambió, si algo cambió?
- [ ] ¿Los archivos nuevos o modificados tienen una **descripción de su responsabilidad**, no solo su nombre?
- [ ] ¿Se documentaron los **problemas técnicos** encontrados con su causa y solución?
- [ ] ¿Está claro el **resultado final**: qué puede hacer el sistema ahora que antes no podía?
- [ ] ¿`todo.md` está actualizado?