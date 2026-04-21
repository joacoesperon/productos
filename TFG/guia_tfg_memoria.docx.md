  
**ESCOLA POLITÈCNICA SUPERIOR**

UNIVERSITAT DE LES ILLES BALEARS

**GUÍA COMPLETA PARA LA REDACCIÓN**

**DE LA MEMORIA DEL**

**TRABAJO FIN DE GRADO**

*Desarrollo de una Plataforma Web para la Venta de Productos Digitales*

Grado en Ingeniería Informática — Curso 2025-26

# **1\. Introducción y propósito de este documento**

Este documento constituye una guía de referencia completa para la elaboración de la memoria del Trabajo Fin de Grado (TFG) del Grado en Ingeniería Informática de la Escola Politècnica Superior (EPS) de la UIB. Está dirigida a aquellos estudiantes cuyo proyecto consiste en el diseño y desarrollo de una plataforma web para la venta de productos digitales.

La memoria es, junto con la defensa oral, el principal instrumento de evaluación del TFG. No basta con haber desarrollado un buen software: la capacidad de comunicarlo de forma precisa, estructurada y rigurosa es en sí misma una competencia fundamental del ingeniero. Esta guía te proporcionará todas las herramientas necesarias para redactar una memoria de la máxima calidad.

| *Recuerda: la manera en que se explica un trabajo es tan importante como el propio trabajo. Un excelente proyecto mal documentado perderá valor ante el tribunal. Invierte tiempo en la memoria.* |
| :---- |

# **2\. Antes de empezar a escribir**

## **2.1 Las cinco cualidades de una buena memoria técnica**

Antes de redactar una sola línea, debes interiorizar los cinco principios fundamentales que definen una memoria técnica de calidad. Estos principios deben guiar cada párrafo, cada figura y cada tabla que incluyas:

| CUALIDAD | DESCRIPCIÓN APLICADA A TU TFG |
| :---- | :---- |
| **Precisión** | Cada afirmación técnica debe ser exacta. Si dices que usas REST, explica por qué no GraphQL. Si indicas rendimiento, aporta métricas concretas. |
| **Concisión** | No incluyas en la memoria todo lo que sabes sobre desarrollo web. Solo lo que sea relevante para entender las decisiones tomadas en este proyecto concreto. |
| **Claridad** | El tribunal debe poder entender la arquitectura del sistema, el flujo de datos y las decisiones de diseño sin necesidad de ejecutar el código. |
| **Coherencia** | Los requisitos planteados en la introducción deben verse satisfechos en los resultados. Las decisiones de diseño deben responder a los objetivos iniciales. |
| **Adecuación a la audiencia** | Tu tribunal son profesores de informática. No necesitan que expliques qué es HTTP, pero sí necesitan entender por qué elegiste tu stack tecnológico concreto. |

## **2.2 El proceso de focalización: qué incluir y qué no**

Antes de escribir, realiza este ejercicio de focalización. Elabora una lista de todos los temas relevantes para tu proyecto (React, pasarelas de pago, arquitectura de microservicios, seguridad, UX...) y, para cada uno, responde estas preguntas:

* ¿Es imprescindible para entender las decisiones técnicas de mi proyecto?

* ¿Se perderá el lector sin este conocimiento previo?

* ¿Puedo referenciarlo con bibliografía en lugar de desarrollarlo yo?

* ¿Es relevante para los objetivos concretos de mi TFG o es conocimiento general?

Solo incluye en la memoria lo que supere este filtro. La enciclopedia de tecnologías web no pertenece a tu TFG; lo que sí pertenece es la justificación razonada de por qué escogiste cada tecnología para tu caso de uso específico.

## **2.3 El esbozo previo: tu hoja de ruta**

Antes de redactar, construye un esbozo detallado con los títulos de todos los capítulos, secciones y subsecciones. Para cada apartado, escribe 2-3 frases cortas que describan qué contendrá. Revísalo con tu tutor antes de escribir el texto completo. Es mucho más eficiente descartar o reorganizar ideas en esta fase que cuando ya tienes 30 páginas escritas.

| *Estrategia recomendada: escribe primero los capítulos de desarrollo y resultados (la parte que mejor conoces), y deja la introducción y las conclusiones para el final. Así tendrás una visión completa del trabajo antes de describir su contexto y sus implicaciones.* |
| :---- |

# **3\. Estructura de la memoria: sección por sección**

La memoria del TFG debe seguir la estructura estándar para trabajos científico-técnicos, tal y como prescriben los organismos internacionales de estandarización (ANSI, ISO) y la normativa de la EPS. A continuación se detalla cada sección con indicaciones específicas para un proyecto de plataforma web de venta de productos digitales. El límite orientativo para el Grado en Ingeniería Informática es de 72 páginas más anexos.

## **3.1 Portada**

La portada es la tarjeta de presentación del trabajo. Usa la plantilla oficial de la EPS. Debe incluir obligatoriamente:

* Título del TFG: preciso, descriptivo y conciso. Por ejemplo: "Diseño e implementación de una plataforma web para la venta de productos digitales con gestión de accesos y pagos integrados". Evita títulos vagos como "Proyecto de plataforma web".

* Nombre completo del estudiante.

* Nombre del tutor y, si aplica, cotutor o supervisor de empresa.

* Titulación: Grado en Ingeniería Informática.

* Centro: Escola Politècnica Superior, Universitat de les Illes Balears.

* Año académico.

| *El título es el primer punto de contacto con el lector. Debe describir con precisión el contenido del trabajo con el menor número de palabras posible. Parte de una lista de palabras clave (plataforma, productos digitales, pagos, web, gestión de accesos...) y construye el título a partir de las más definitorias.* |
| :---- |

## **3.2 Resumen (Abstract)**

El resumen debe tener entre 250 y 500 palabras y ser completamente autónomo: el lector debe poder entender el trabajo leyendo solo esta sección. No uses acrónimos sin definirlos y no incluyas referencias bibliográficas. Debe incluir los siguientes elementos:

1. **¿Qué necesidad cubre la plataforma? ¿Qué carencias del mercado o situación justifican su desarrollo?** Definición concisa del problema:

2. **¿Cómo se ha abordado el desarrollo? (metodología ágil, prototipado, arquitectura elegida...)** Metodología:

3. **¿Qué se ha construido? ¿Qué funcionalidades ofrece la plataforma? ¿Qué métricas de rendimiento o calidad se han alcanzado?** Principales resultados:

4. **¿Se han cumplido los objetivos? ¿Qué valor aporta el trabajo?** Conclusiones:

Redacta también el resumen en inglés (Abstract). Ambas versiones son necesarias para el depósito en el repositorio institucional de la UIB.

## **3.3 Introducción**

La introducción es el capítulo que establece el marco completo del trabajo. Un buen lector buscará en ella tres elementos fundamentales:

### **3.3.1 Contextualización**

Sitúa el trabajo en su contexto. Para una plataforma de venta de productos digitales, esto implica describir el ecosistema del comercio electrónico de productos digitales (software, ebooks, cursos online, música, diseños...), las tendencias del mercado, los principales actores y las soluciones existentes. No es una enciclopedia de e-commerce; es el contexto específico que justifica que valga la pena hacer este TFG.

### **3.3.2 Definición del problema**

Define con precisión el problema que resuelve tu plataforma. ¿Qué limitaciones tienen las soluciones actuales? ¿Por qué se necesita una nueva plataforma? ¿A qué tipo de usuarios va dirigida? ¿Qué requisitos específicos debe cumplir? Esta sección justifica la existencia del proyecto.

### **3.3.3 Objetivos del trabajo**

Lista los objetivos concretos y verificables del TFG. Distingue entre objetivo general (desarrollar la plataforma) y objetivos específicos (implementar sistema de autenticación de usuarios, integrar pasarela de pago, diseñar panel de vendedor, implementar descarga segura de archivos, etc.). Estos objetivos serán el criterio con el que el tribunal evaluará si el trabajo ha sido exitoso.

### **3.3.4 Estructura de la memoria**

Cierra la introducción con un párrafo que describa brevemente el contenido de cada capítulo. Esto orienta al lector y refuerza la coherencia estructural del documento.

| *Consejo clave: la introducción es el último capítulo que debes redactar en su versión definitiva, aunque sea el primero que el lector leerá. Solo cuando hayas completado el resto del trabajo podrás describir con precisión su contexto, objetivos y alcance real.* |
| :---- |

## **3.4 Estado del arte y marco teórico**

Este capítulo sitúa tu trabajo dentro del conocimiento existente y justifica las decisiones técnicas adoptadas. Para tu proyecto, debe abordar los siguientes bloques, siempre desde una perspectiva analítica y no meramente descriptiva:

* Análisis de plataformas existentes de venta de productos digitales (Gumroad, Sellfy, Payhip, Shopify Digital...). No describas sus características; analiza sus fortalezas y limitaciones en relación con los objetivos de tu proyecto.

* Arquitecturas web relevantes: monolítica vs. microservicios, SPA vs. SSR, REST vs. GraphQL. Justifica desde aquí tu elección arquitectónica.

* Tecnologías del stack seleccionado: fundamenta la elección de cada tecnología principal (framework frontend, framework backend, base de datos, sistema de autenticación, pasarela de pago). Argumenta por qué esa tecnología y no las alternativas.

* Seguridad en plataformas de e-commerce: OWASP, protección de descargas digitales, gestión de tokens, cifrado.

* Normativa aplicable: RGPD, normativa sobre facturación electrónica, condiciones de uso de pasarelas de pago.

| *Atención: este capítulo no es un resumen de lo que has leído. Es una síntesis elaborada que muestra tu comprensión del campo y que construye los fundamentos sobre los que se asienta tu solución. Evita copiar o parafrasear superficialmente fuentes externas; demuestra que has procesado la información y la has aplicado a tu caso.* |
| :---- |

## **3.5 Análisis y diseño del sistema**

Este es uno de los capítulos centrales del trabajo para un proyecto de ingeniería informática. Documenta todo el proceso de análisis de requisitos y diseño arquitectónico previo al desarrollo. Una memoria de calidad en este apartado demuestra que el sistema fue pensado antes de ser construido.

### **3.5.1 Requisitos del sistema**

Presenta los requisitos de forma estructurada. Distingue claramente entre:

* Requisitos funcionales: lo que el sistema debe hacer. Por ejemplo: el usuario puede registrarse, autenticarse, explorar el catálogo, añadir productos al carrito, realizar el pago, descargar el producto comprado, recibir confirmación por email. El vendedor puede subir productos, configurar precios, ver estadísticas de ventas...

* Requisitos no funcionales: rendimiento, escalabilidad, seguridad, usabilidad, disponibilidad, compatibilidad de navegadores.

Puedes usar una tabla de requisitos numerados (RF-01, RF-02... / RNF-01...) para facilitar la trazabilidad con las fases de desarrollo y testing.

### **3.5.2 Arquitectura del sistema**

Describe la arquitectura de alto nivel. Incluye un diagrama de arquitectura claro que muestre los componentes principales del sistema (frontend, backend, base de datos, servicios externos como pasarela de pago o almacenamiento de archivos), sus responsabilidades y cómo se comunican entre sí. Explica las decisiones de diseño: ¿por qué esta arquitectura? ¿qué alternativas se consideraron?

### **3.5.3 Diseño de la base de datos**

Incluye el modelo entidad-relación y/o el diagrama del esquema de la base de datos. Para una plataforma de productos digitales, los modelos clave incluirán usuarios, productos, categorías, órdenes de compra, pagos, archivos descargables, tokens de descarga, etc. Justifica las decisiones de modelado relevantes.

### **3.5.4 Diseño de la API**

Si el sistema tiene una API REST o similar, documenta los endpoints principales con su método HTTP, ruta, descripción, parámetros y respuesta esperada. Puedes incluir una tabla resumen y ampliar los detalles en un anexo.

### **3.5.5 Diseño de la interfaz de usuario**

Incluye los wireframes o mockups de las pantallas principales (página de inicio, catálogo, página de producto, carrito, checkout, panel de vendedor, historial de compras...). Explica las decisiones de UX relevantes. Si has realizado pruebas de usabilidad con usuarios, documéntalas aquí.

## **3.6 Implementación**

Este capítulo describe cómo se ha construido el sistema. No es un tutorial de las tecnologías usadas ni una lista de todo el código escrito. Su objetivo es mostrar las decisiones de implementación más relevantes y complejas, y demostrar que se han resuelto los problemas técnicos de forma competente.

* Entorno de desarrollo y herramientas: stack tecnológico completo, gestión del proyecto (control de versiones, gestión de tareas), metodología de desarrollo utilizada.

* Estructura del proyecto: organización del repositorio, separación de responsabilidades, patrones de diseño aplicados.

* Funcionalidades clave implementadas: desarrolla en detalle los aspectos técnicos más complejos o relevantes de tu proyecto. Por ejemplo: el flujo completo de pago (desde la selección hasta la confirmación y generación del enlace de descarga), el sistema de autenticación y gestión de sesiones, la protección de archivos descargables, el panel de estadísticas para vendedores...

* Integración de servicios externos: cómo se ha integrado la pasarela de pago, el servicio de almacenamiento de archivos, el sistema de envío de emails, etc.

* Decisiones técnicas destacadas: documenta los problemas técnicos encontrados y cómo fueron resueltos. Esto demuestra madurez técnica.

| *No incluyas listados de código fuente extensos en el cuerpo de la memoria. Si es necesario mostrar código, usa fragmentos cortos y representativos (máximo 15-20 líneas) con una explicación clara de su propósito. El código completo puede ir en un anexo o en el repositorio referenciado.* |
| :---- |

## **3.7 Pruebas y validación**

El tribunal valorará positivamente que el trabajo incluya una estrategia de testing sistemática. Documenta:

* Estrategia de pruebas: qué tipos de pruebas se han realizado (unitarias, de integración, end-to-end, de rendimiento, de seguridad, de usabilidad...) y por qué.

* Casos de prueba representativos: no es necesario listar todos los tests, pero sí mostrar casos de prueba clave, especialmente para las funcionalidades críticas (proceso de pago, descarga de archivos, autenticación...).

* Resultados de las pruebas: cobertura de tests, resultados de pruebas de rendimiento (tiempos de carga, concurrencia), resultados de pruebas de seguridad si se han realizado.

* Gestión de errores y casos límite: cómo responde el sistema ante fallos en la pasarela de pago, archivos corruptos, intentos de acceso no autorizado, etc.

## **3.8 Resultados y discusión**

Presenta los resultados del trabajo de forma objetiva y analítica. Para un proyecto de plataforma web, los resultados incluyen:

* Funcionalidades implementadas vs. planificadas: tabla comparativa entre los requisitos definidos inicialmente y lo que finalmente se ha entregado.

* Métricas de rendimiento: tiempos de carga, Lighthouse scores, capacidad de respuesta bajo carga.

* Capturas de pantalla de las principales pantallas del sistema en funcionamiento.

* Comparación con soluciones existentes: ¿en qué puntos supera tu plataforma a las soluciones analizadas en el estado del arte? ¿Cuáles son sus limitaciones respecto a ellas?

La discusión es la parte analítica: no solo presenta los datos sino que los interpreta. ¿Por qué se obtuvieron esos resultados? ¿Qué implican? ¿Qué aspectos no han funcionado como se esperaba y por qué?

## **3.9 Conclusiones**

Las conclusiones no son un resumen del trabajo. Son la síntesis reflexiva de lo que se ha aprendido y conseguido. Un capítulo de conclusiones de calidad debe:

* Retomar de forma muy breve los objetivos planteados en la introducción y evaluar en qué medida se han cumplido. Sé honesto: si algún objetivo no se alcanzó completamente, explica por qué.

* Enunciar las conclusiones principales: qué afirmaciones puedes hacer a la vista de los resultados obtenidos. ¿Es técnicamente viable construir una plataforma de este tipo con las tecnologías seleccionadas? ¿Qué has aprendido sobre el proceso de desarrollo web complejo?

* Identificar las limitaciones del trabajo: qué aspectos han quedado fuera del alcance, qué simplificaciones se han asumido, qué problemas no se han resuelto completamente.

* Proponer líneas de trabajo futuro: qué funcionalidades ampliarían la plataforma, qué mejoras técnicas serían prioritarias, qué investigación adicional sería útil.

| *Error frecuente: repetir en las conclusiones lo mismo que se dijo en la introducción. Las conclusiones deben aportar algo nuevo: la evaluación reflexiva del trabajo realizado, no la descripción de lo que ibas a hacer.* |
| :---- |

## **3.10 Referencias bibliográficas**

La bibliografía debe incluir todas las fuentes que hayas citado en el texto. Para un proyecto de desarrollo web, las referencias típicas incluyen: documentación oficial de las tecnologías utilizadas, artículos académicos sobre arquitectura de software, libros sobre diseño de sistemas, estándares de seguridad web, artículos sobre comercio electrónico. Algunas directrices:

* Cita solo lo que hayas realmente consultado y utilizado.

* Prioriza fuentes académicas y oficiales sobre blogs o artículos sin autoría clara.

* Usa un estilo de citación consistente (IEEE es habitual en ingeniería informática).

* Asegúrate de que todas las citas en el texto tienen su entrada en la bibliografía y viceversa.

## **3.11 Anexos**

Los anexos contienen información relevante que no pertenece al flujo principal de la memoria. Para un proyecto de plataforma web, los candidatos habituales son:

* Manual de instalación y despliegue del sistema.

* Manual de usuario (si no se incluye como capítulo principal).

* Documentación completa de la API (todos los endpoints).

* Esquema completo de la base de datos.

* Catálogo completo de casos de prueba.

* Fragmentos de código especialmente relevantes.

* Presupuesto del proyecto.

# **4\. Formato, extensión y aspectos formales**

## **4.1 Extensión y plantilla**

La EPS recomienda para el Grado en Ingeniería Informática un máximo de 72 páginas para el cuerpo principal de la memoria, más los anexos que sean necesarios. Esta cifra no incluye portada, índices ni referencias bibliográficas.

Para el formato, la EPS pone a disposición dos opciones:

* Plantilla en LaTeX (recomendada): disponible en la web de la EPS como archivo descargable (zip), en Overleaf y como PDF compilado de muestra. LaTeX gestiona automáticamente el formato, los índices, las referencias, la numeración de figuras y tablas, y garantiza un resultado profesional consistente.

* Plantilla Word (solo portada): para el cuerpo de la memoria en formato Word, se proporciona únicamente la portada oficial. El resto del formato debe seguir las convenciones estándar de documentos técnicos.

| *Si no tienes experiencia previa con LaTeX, este TFG es una excelente oportunidad para aprenderlo. El tiempo de aprendizaje inicial se recupera ampliamente en la calidad del resultado final y en la facilidad de gestionar documentos largos.* |
| :---- |

## **4.2 Uso de figuras, tablas y ecuaciones**

Los elementos visuales son herramientas de comunicación poderosas. Para usarlos correctamente:

### **Figuras**

* Toda figura debe tener un número y un pie de figura descriptivo (no solo "Arquitectura del sistema", sino "Figura 3.2: Arquitectura del sistema mostrando la separación entre frontend React y backend Node.js con conexión a PostgreSQL y servicios externos de Stripe y AWS S3").

* Toda figura mencionada en el texto debe referenciarse explícitamente ("como se muestra en la Figura 3.2...").

* Las capturas de pantalla deben ser de alta resolución y mostrar el sistema en un estado representativo y limpio.

* Los diagramas (arquitectura, ER, flujos) deben crearse con herramientas que permitan exportar en alta resolución (draw.io, Lucidchart, PlantUML...).

### **Tablas**

* Toda tabla debe tener número y título.

* Las tablas de requisitos, endpoints de API o casos de prueba aportan gran valor y organización al documento.

* Evita tablas con demasiadas columnas que no sean legibles en el formato de página.

### **Código fuente**

* Si debes incluir fragmentos de código en el cuerpo principal, usa entornos de código (listings en LaTeX) con numeración de líneas y coloreado de sintaxis.

* Los fragmentos deben ser cortos (no más de 20-25 líneas) y explicados en el texto circundante.

* Nunca incluyas código sin comentarlo ni sin explicar su propósito.

## **4.3 Lista de acrónimos**

Un proyecto de ingeniería informática usa inevitablemente multitud de acrónimos (API, REST, SPA, JWT, HTTPS, CRUD, ORM, CI/CD...). Incluye siempre una lista de acrónimos al principio de la memoria. La primera vez que uses un acrónimo en el texto, escríbelo completo seguido del acrónimo entre paréntesis. Por ejemplo: "Se utilizó una Interfaz de Programación de Aplicaciones (API) de tipo REST..."

# **5\. El proceso de redacción: cómo organizarse**

Redactar la memoria es un proceso iterativo, no lineal. Estas son las fases recomendadas:

| FASE | CUÁNDO | QUÉ HACER |
| :---- | :---- | :---- |
| **1\. Focalización** | Inicio del TFG | Lista de temas, revisión bibliográfica, definición del alcance. Decide qué entra y qué no en la memoria. |
| **2\. Esbozo** | Inicio del TFG | Crea el índice provisional con todos los capítulos y secciones. Escribe 2-3 frases por sección. Revísalo con el tutor. |
| **3\. Redacción** | Durante el desarrollo | Redacta primero los capítulos técnicos (diseño, implementación, pruebas). Deja introducción y conclusiones para el final. |
| **4\. Revisión** | Tras cada capítulo | Comparte cada capítulo terminado con el tutor. Incorpora sus comentarios. Revisa ortografía, gramática, coherencia y referencias. |
| **5\. Revisión global** | Al terminar | Lee la memoria completa de principio a fin. Verifica coherencia global, que todos los objetivos del capítulo 1 estén respondidos en resultados y conclusiones. |

# **6\. El depósito: qué debes entregar**

El depósito del TFG se realiza a través de la herramienta informática de gestión de TFG de la EPS, accesible desde la web de la Escola. El estudiante es el responsable del depósito y debe asegurarse de entregar toda la documentación requerida. El tutor verificará que la documentación entregada se corresponde con la que él ha revisado antes de autorizar la tramitación.

La documentación de depósito incluye:

* Memoria del TFG en PDF con el formato oficial de la EPS.

* Declaración de autoría y originalidad del trabajo.

* Autorización (o no) para la publicación en abierto en el repositorio institucional de la UIB.

* Vídeo divulgativo (opcional, pero puede aportar hasta 0,5 puntos adicionales a la nota final).

## **6.1 El vídeo divulgativo (opcional, \+0,5 puntos)**

Los estudiantes que aporten un vídeo divulgativo en el momento del depósito pueden obtener hasta 0,5 puntos adicionales en la nota final. Las condiciones son:

* Duración: entre 1 y 3 minutos. Formato horizontal.

* Carácter divulgativo: dirigido al público general o a estudiantes de bachillerato. No es una defensa técnica; es una presentación atractiva del problema que resuelves y de cómo lo resuelves.

* Formato: MP4, máximo 180 MB. Se recomienda HandBrake con preset Fast 1080p30 para la compresión.

* Idioma: catalán, castellano o inglés.

* Calidad: cuida el audio (micrófono o auriculares con micro, sin ruido ambiental), la imagen (enfocada, con buena luz de cara) y el contenido (estructura previa, mensajes breves y claros).

| *Para el vídeo, imagina que debes explicar tu plataforma a alguien sin conocimientos técnicos en menos de 2 minutos. ¿Qué problema resuelve? ¿Para quién? ¿Cómo funciona brevemente? Este ejercicio de simplificación también te ayudará a preparar la defensa oral.* |
| :---- |

## **6.2 Fechas clave del curso 2025-26**

| Fecha límite de depósito | Consecuencia |
| :---- | :---- |
| 3 de julio de 2026 a las 15:00h | Defensa garantizada antes del verano |
| 4 de septiembre de 2026 a las 15:00h | Defensa dentro del curso 2025-26 (sin pagar tasas adicionales) |
| **Después del 4 de septiembre** | Posible defensa fuera del cierre del curso y necesidad de pagar tasas del curso siguiente |

# **7\. Cómo se evalúa el TFG**

El tribunal evaluador está formado por tres miembros titulares (presidente, vocal y secretario) más un suplente. La defensa es un acto público con una exposición oral de máximo 30 minutos seguida de un turno de preguntas de hasta 60 minutos. La nota se obtiene por media ponderada de las evaluaciones de los miembros del tribunal según los criterios del Anexo 3 de la normativa EPS.

Los principales aspectos que evalúa el tribunal son:

* Calidad técnica del trabajo realizado: complejidad, rigor, profundidad técnica de la solución implementada.

* Calidad de la memoria: precisión, claridad, estructura, coherencia, referencias bibliográficas.

* Calidad de la presentación oral: organización, claridad expositiva, dominio del tema, gestión del tiempo.

* Capacidad de respuesta en el turno de preguntas: comprensión profunda del trabajo y de las tecnologías utilizadas.

| *El tribunal también puede otorgar hasta 0,5 puntos adicionales si el estudiante ha aportado material que la Escola pueda usar para promover los estudios (vídeo divulgativo u otro material). En ningún caso la nota final puede superar 10 puntos.* |
| :---- |

# **8\. Errores frecuentes que debes evitar**

| \# | ERROR FRECUENTE | CÓMO EVITARLO |
| :---: | :---- | :---- |
| **1** | Introducción que no contextualiza el problema sino que solo describe el índice | La introducción debe establecer el contexto, definir el problema y justificar los objetivos antes de describir la estructura. |
| **2** | Estado del arte que es un catálogo de tecnologías sin análisis | Analiza las tecnologías en relación con tu caso de uso. Justifica por qué elegiste unas y descartaste otras. |
| **3** | Conclusiones que repiten la introducción | Las conclusiones deben evaluar los resultados obtenidos y proponer líneas futuras, no describir lo que ibas a hacer. |
| **4** | Código fuente extenso en el cuerpo de la memoria | Usa fragmentos cortos y representativos. El código completo va en anexos o en el repositorio. |
| **5** | Figuras sin pie descriptivo ni referencia en el texto | Toda figura debe tener número, pie y ser mencionada explícitamente en el texto. |
| **6** | Objetivos no verificables ('mejorar la experiencia de usuario') | Define objetivos medibles y concretos que el tribunal pueda verificar. |
| **7** | Decisiones técnicas sin justificación ('se usó React') | Siempre argumenta las decisiones técnicas. ¿Por qué React y no Vue o Angular para este proyecto? |
| **8** | Falta de coherencia entre objetivos iniciales y resultados | Lee la memoria completa al final y verifica que cada objetivo del capítulo 1 tiene respuesta en los capítulos de resultados y conclusiones. |

# **9\. Checklist de revisión final**

Antes de entregar la memoria al tutor para su validación final, verifica cada uno de estos puntos:

## **Estructura y contenido**

* La portada usa la plantilla oficial de la EPS e incluye todos los campos obligatorios.

* El resumen tiene entre 250 y 500 palabras, es autónomo e incluye versión en inglés.

* La introducción contextualiza el problema, define los objetivos y describe la estructura.

* El estado del arte analiza soluciones existentes y justifica las decisiones tecnológicas.

* El capítulo de diseño incluye diagramas de arquitectura, modelo de datos y diseño de UI.

* La implementación documenta las decisiones técnicas relevantes con fragmentos de código bien explicados.

* Las pruebas documentan la estrategia de testing y presentan resultados concretos.

* Los resultados incluyen métricas objetivas y una comparativa con los objetivos planteados.

* Las conclusiones evalúan los objetivos, identifican limitaciones y proponen trabajo futuro.

* La bibliografía lista todas las fuentes citadas en el texto y solo esas.

## **Formato y calidad**

* La memoria tiene como máximo 72 páginas en el cuerpo principal.

* Todas las figuras tienen número, pie descriptivo y son referenciadas en el texto.

* Todas las tablas tienen número y título.

* La lista de acrónimos está completa y se corresponde con los usados en el texto.

* No hay errores ortográficos ni gramaticales (usa el corrector y lee en voz alta).

* El estilo de citación es consistente en todo el documento.

* Los fragmentos de código son cortos, tienen comentarios y están explicados.

## **Coherencia global**

* Cada objetivo definido en la introducción tiene respuesta en resultados y/o conclusiones.

* Las decisiones de diseño se corresponden con los requisitos definidos.

* Las conclusiones no repiten la introducción sino que evalúan los resultados.

* El trabajo futuro propuesto es coherente con las limitaciones identificadas.

# **10\. Recursos disponibles**

La EPS pone a tu disposición los siguientes recursos para la realización del TFG:

* Herramienta de gestión de TFG: accesible desde la web de la EPS. Gestiona la solicitud de asignación, el depósito y la consulta de calificación.

* Plantilla LaTeX completa: disponible como archivo ZIP descargable, en Overleaf y como PDF de muestra desde la web de la EPS. Incluye ayuda y recomendaciones de uso.

* Repositorio de TFGs anteriores: consulta memorias de TFGs ya defendidos en la EPS para tener referencias de formato, estructura y nivel de detalle esperado.

* BiblioClips de la Biblioteca de la UIB: módulos formativos obligatorios (BiblioÈtica y BiblioCita deben estar superados para poder defender). Completar los 5 módulos otorga 1 ECTS adicional.

* Tutor del TFG: tu principal recurso. Establece un calendario de tutorías regular desde el inicio del proyecto. No esperes a tener la memoria casi terminada para compartirla.

*Escola Politècnica Superior · Universitat de les Illes Balears · Curs 2025-26*