# Constitución del proyecto

Versión: 2.7.1 — 2026-10-27

Principios no negociables de este proyecto. Toda spec, decisión de
arquitectura y diseño de datos los respeta; `sdd-verify` los chequea en
cada cierre de spec. Precedencia: constitución > ARCHITECTURE.md >
DESIGN.md / DATA-MODEL.md > specs.

Los umbrales numéricos que aparecen acá se parametrizan en la
configuración de Spring (`application.yml`, sobreescribible por variable de
entorno) o en las propiedades del `pom.xml`, según se indica en cada
principio. El código y los checks los leen de ahí; no se repiten como
literales.

## Heredados por referencia
- Método SDD: `SDD-CONVENTION.md`.
- Reglas de la casa (`~/.claude/CLAUDE.md`): Spec-Driven Development; Sin
  hardcode, sin magic strings. Commits y push solo con autorización
  explícita de la persona usuaria.

## Principios

### P1 — La no superposición la garantiza la base
**Regla:** Dos turnos activos del mismo profesional no deben compartir
ningún instante, buffer incluido. La garantía debe ser un constraint de
PostgreSQL (exclusion constraint sobre el rango ocupado); un chequeo previo
en código puede existir como optimización, nunca como única barrera. Ante
una violación del constraint, la API responde `409` con código
`SLOT_TAKEN`.
**Por qué:** Es la restricción central del challenge (RD-01): con cientos
de pedidos simultáneos, solo la base serializa de forma confiable.
**Alcance:** Módulo `booking` y esquema de la tabla de turnos.
**Verificación:** Automatizada — test de integración con Testcontainers
que lanza `BOOKING_CONCURRENCY_TEST_REQUESTS` (por defecto 200) reservas
simultáneas sobre el mismo slot y afirma exactamente una confirmada y el
resto `409 SLOT_TAKEN`; corre en CI. Test de esquema que afirma la
existencia del exclusion constraint.

### P2 — Tiempo en UTC, presentación en la zona del negocio
**Regla:** Todo instante debe persistirse en UTC (`timestamptz` /
`Instant`). La conversión a hora local debe usar el `ZoneId` del negocio y
contemplar cambios de horario. Ninguna lógica de agenda debe depender de la
zona horaria del servidor o de la JVM. Las respuestas con horarios deben
incluir el offset explícito.
**Por qué:** RD-02. Un negocio en otra zona o un cambio de horario no puede
generar slots fantasma ni turnos corridos una hora.
**Alcance:** Todo el sistema.
**Verificación:** Automatizada — tests unitarios de disponibilidad que
cruzan un cambio de horario y corren con la JVM en una zona distinta de la
del negocio; regla ArchUnit que prohíbe `LocalDateTime.now()`,
`ZoneId.systemDefault()` y `new Date()` fuera de un `Clock` inyectado.

### P3 — Esquema preparado para aislar negocios
**Regla:** Toda tabla que guarde datos de un negocio debe tener
`tenant_id NOT NULL` con clave foránea a la tabla de negocios desde su
primera migración, y toda unicidad de datos de negocio debe incluir
`tenant_id` (por ejemplo, email del cliente único por negocio, no global).
El negocio actual debe obtenerse siempre de un único componente del módulo
`tenancy` (en el MVP devuelve el negocio configurado); ningún otro código
debe asumir que hay un solo negocio ni fijar su id. El MVP **no** garantiza
aislamiento entre negocios: ni el README, ni los ADRs, ni el contrato de la
API deben presentarlo como multi-tenant.
**Por qué:** Decisión de alcance A32 del PRD: el MVP se enfoca en el
núcleo y sirve a un solo negocio, pero agregar `tenant_id` después
obligaría a migrar todas las tablas, cambiar unicidades y tocar todas las
consultas. Con el esquema preparado, la etapa 2 solo agrega piezas.
**Alcance:** Esquema de datos de todos los módulos y todo acceso al negocio
actual.
**Verificación:** Automatizada — test de esquema contra Postgres que
recorre `information_schema` y afirma `tenant_id NOT NULL` con FK en cada
tabla, salvo una lista explícita de tablas de infraestructura (historial de
Flyway, registro de eventos de Spring Modulith, la tabla de negocios
misma). Revisión en F7: toda unicidad nueva incluye `tenant_id`; ningún
código fuera del componente de `tenancy` obtiene o fija el negocio actual.
**Etapa 2:** Al abrir multi-tenancy se enmienda este principio para
restituir la garantía de la v1.0.0: toda consulta filtra por el tenant
resuelto en el request (JWT o slug), un recurso de otro negocio responde
`404` y no `403`, verificado con un test de dos negocios por endpoint.

### P4 — Límites de módulos verificados
**Regla:** El sistema es un monolito modular con los módulos `tenancy`,
`catalog`, `scheduling`, `booking` y `notifications`. Ningún módulo debe
acceder a paquetes internos de otro. Solo `booking` escribe turnos.
`scheduling` no depende de los internos de `booking`. `notifications` solo
reacciona a eventos; ningún módulo la invoca de forma síncrona.
**Por qué:** Restricción técnica del challenge y criterio de evaluación de
diseño: los límites tienen que estar verificados, no solo dibujados.
**Alcance:** Todo el código de producción.
**Verificación:** Automatizada — test de Spring Modulith
(`ApplicationModules.verify()`) más reglas ArchUnit para "solo `booking`
escribe turnos" y "nadie llama a `notifications`"; corren en `./mvnw
verify` y en CI.

### P5 — Contrato de API estable
**Regla:** Toda la API pública y de administración debe estar descrita en
OpenAPI 3 servido por la app. Toda respuesta de error debe ser
`application/problem+json` con un campo `code` de negocio estable (por
ejemplo `SLOT_TAKEN`); un `code` publicado no cambia de significado ni se
reutiliza.
**Por qué:** RNF de errores y entregable de OpenAPI. Los clientes reaccionan
al `code`, no al texto.
**Alcance:** Capa web de todos los módulos.
**Verificación:** Automatizada — test que obtiene `/v3/api-docs` y lo
compara con los contratos de `docs/contracts/`; test por cada `code` de
error que afirma status, `Content-Type` y `code`. Revisión en F7: ningún
`code` existente cambió de significado.

### P6 — Escrituras de turnos idempotentes
**Regla:** Los `POST` de reserva, cancelación y reprogramación deben aceptar
`Idempotency-Key`. Un reintento con la misma clave debe devolver el mismo
resultado sin repetir el efecto. La clave se retiene al menos
`IDEMPOTENCY_KEY_TTL` (configuración de Spring, por defecto `PT24H`).
**Por qué:** RNF de idempotencia: los reintentos de red no pueden duplicar
turnos ni cancelar dos veces.
**Alcance:** Endpoints de escritura de `booking`.
**Verificación:** Automatizada — test de integración por endpoint que repite
el pedido con la misma clave y afirma mismo cuerpo, mismo turno y un solo
efecto (un turno, un evento); test de que la clave sigue vigente dentro del
TTL configurado.

### P7 — Una notificación nunca compromete una reserva
**Regla:** Ningún envío de email ni efecto externo debe ocurrir dentro de la
transacción de un turno ni bloquear su respuesta. Un cambio de estado
confirmado debe producir su evento de forma durable, en la misma
transacción, y el evento no debe perderse aunque el proceso caiga. Cada
efecto que debe ocurrir una sola vez (por ejemplo, el recordatorio) debe
ser idempotente aunque corran varias instancias o se reprocese el evento.
**Por qué:** RNF de entrega de eventos y HU-09. Una falla de SMTP no puede
deshacer una reserva ni un reinicio duplicar un recordatorio.
**Alcance:** `booking` y `notifications`. El mecanismo (outbox) es una
decisión de `ARCHITECTURE.md`, no de este principio.
**Verificación:** Automatizada — test de integración que simula falla del
envío de email y afirma turno confirmado y evento pendiente de
reprocesamiento; test que reprocesa el mismo evento dos veces y afirma un
solo email (contra Mailpit o un doble del transporte de mail, nunca de la
base).

### P8 — Tests confiables y trazables
**Regla:**
- **Persistencia real:** todo test que ejercite persistencia debe correr
  contra PostgreSQL de la misma versión mayor que producción
  (Testcontainers). No se usan mocks de repositorios para probar reglas que
  dependen de la base ni bases embebidas (H2 u otras) como sustituto.
- **Trazabilidad:** todo test que cubre un escenario Gherkin de una spec
  debe nombrarlo en su `@DisplayName` con el número de spec y el título
  exacto del escenario (por ejemplo `001 · reservar un slot libre`). Un
  test puede cubrir un solo escenario; un escenario puede tener varios
  tests.
- **Dobles solo en los bordes:** solo se reemplazan con dobles (mocks,
  stubs, fakes) los puertos de `application/` hacia afuera (SMTP, `Clock`,
  cualquier servicio externo futuro). Nunca clases de `domain/` ni casos de
  uso; los repositorios se rigen por la persistencia real de arriba.
- **Determinismo:** ningún test debe depender del orden de ejecución, de
  datos que dejó otro test, de la hora real, de valores aleatorios sin
  semilla ni de esperas fijas (`Thread.sleep`); las esperas asíncronas usan
  Awaitility con un tope. Un test inestable es un bug: no se reintenta
  automáticamente (`rerunFailingTestsCount` en 0, sin extensiones de
  reintento) ni se deshabilita sin un motivo escrito en el `@Disabled` y
  una spec o issue que lo resuelva.
- **Mutation testing como reporte:** PIT corre en CI sobre `domain/` de
  `scheduling` y `booking` y publica su reporte, sin umbral que falle el
  build.
**Por qué:** Criterio de evaluación del challenge; además P1 depende de un
exclusion constraint que solo existe en Postgres. La trazabilidad vuelve
mecánica la verificación de cobertura de F7, que hoy se hace infiriendo.
Mockear el dominio acopla los tests a la implementación y encarece el
refactor del ciclo TDD. Los tests de concurrencia y de outbox son
candidatos naturales a volverse inestables, y un test que a veces falla
deja de frenar regresiones. PIT mide si los tests detectan cambios en la
lógica, no solo si la ejecutan; queda como reporte para no sumar tiempo de
build obligatorio (decisión de la usuaria).
**Alcance:** Suite de tests.
**Verificación:** Automatizada — regla ArchUnit/Maven Enforcer que prohíbe
la dependencia de H2 y bases embebidas; regla ArchUnit sobre el código de
test que prohíbe llamadas a `Thread.sleep` y campos `@Mock` /
`@MockitoBean` de tipos de `domain/` o de casos de uso de `application/`;
orden aleatorio de métodos y clases configurado en JUnit
(`junit.jupiter.testmethod.order.default` y
`junit.jupiter.testclass.order.default`); `rerunFailingTestsCount` en 0 en
Surefire y Failsafe; PIT publicado como artefacto de CI. Script del
proyecto que cruza los títulos de los escenarios de una spec con los
`@DisplayName` de los tests y lista los escenarios sin test; lo corre
`sdd-verify` en F7 (no en CI, porque una spec a medio implementar tiene
escenarios sin test a propósito). Revisión en F7: ningún test de una regla
de persistencia usa un repositorio mockeado; ningún doble reemplaza algo
que no sea un puerto hacia afuera; todo `@Disabled` tiene motivo y spec o
issue; los mutantes sobrevivientes de PIT en el código que tocó la spec se
miran y cada uno se cubre con un test o se justifica en el informe de
verificación.

### P9 — Seguridad de credenciales y accesos públicos
**Regla:** Las contraseñas deben guardarse con BCrypt. Los links de gestión
del cliente deben estar firmados y tener vencimiento: permiten operar
sobre el turno solo hasta el límite de la antelación mínima de cancelación
del negocio, después solo verlo, y dejan de funcionar al terminar el
turno. Todo link debe quedar revocado al reprogramar o cancelar su turno
(al reprogramar se emite uno nuevo); un link revocado no permite ni ver.
Los endpoints públicos deben tener
rate limit con umbrales configurables. Ningún secreto (clave de firma JWT o
de links, credenciales de base o SMTP) debe estar en el repositorio; se
inyectan por variable de entorno.
- **Autorización denegada por defecto:** todo endpoint debe declarar
  explícitamente qué roles (`ADMIN`, `RECEPTIONIST`, `PROFESSIONAL`) o qué
  acceso público lo alcanzan; un endpoint sin declaración se deniega
  (`denyAll` como última regla de Spring Security). Los permisos son los
  del PRD (A3, A4, A13, A34). Un profesional solo accede a su propia
  agenda y a sus propios bloqueos: un recurso de otro profesional responde
  `404`, no `403`, para no confirmar que existe.
- **Actuator privado:** por HTTP solo son públicos
  `/actuator/health/liveness` y `/actuator/health/readiness`, sin detalle
  de componentes para quien no esté autenticado. Métricas y cualquier otro
  endpoint de Actuator exigen rol `ADMIN` o no se exponen por HTTP.
- **Errores sin detalles internos:** ninguna respuesta de error debe
  incluir stack traces, mensajes de excepción, SQL, nombres de clases ni de
  tablas; un error inesperado responde `500` `problem+json` con un `detail`
  genérico y el trace id para correlacionar con los logs
  (`server.error.include-stacktrace` y `server.error.include-message` en
  `never`).
**Por qué:** RNF de seguridad. El cliente no tiene cuenta: el link firmado
es su única credencial. Autorización: en una API con varios roles, el error
más común es que un usuario alcance recursos ajenos cambiando un id
(IDOR), y un endpoint nuevo sin regla queda abierto si el default es
permitir. Actuator: las métricas que exige P10 exponen detalles internos
del sistema. Errores: un stack trace o un SQL en la respuesta le da a un
atacante el mapa de la aplicación.
**Alcance:** Todo el sistema. Links de gestión: `booking` y la capa web
pública; credenciales y roles: `tenancy`.
**Verificación:** Automatizada — tests de link adulterado, link pasado el
límite de cancelación (ver sí, operar no), link vencido, link revocado tras
reprogramar y tras cancelar, y rate limit excedido (`429`); escaneo de secretos (por ejemplo gitleaks) en
CI. Autorización: test parametrizado endpoint × rol (anónimo, `PROFESSIONAL`,
`RECEPTIONIST`, `ADMIN`) que lee una única tabla de permisos esperados y
afirma el resultado de cada combinación; test que recorre todos los
endpoints registrados en Spring MVC y falla si alguno no está en esa tabla
(un endpoint nuevo no se puede agregar sin declarar sus permisos); test de
un profesional que pide la agenda y los bloqueos de otro y recibe `404`.
Actuator: test anónimo contra `/actuator/metrics`, `/actuator/prometheus`,
`/actuator/env` y `/actuator/health` con componentes, que afirma que no
devuelven información. Errores: test que fuerza una excepción inesperada y
una de la base, y afirma `500` `problem+json` sin `Exception`, líneas de
stack trace, SQL ni nombres de clase en el cuerpo. Revisión en F7: ninguna
clave o credencial con valor literal en código ni en `application.yml`
versionado; la tabla de permisos coincide con el PRD.

### P10 — Operable, con timeouts y sin datos personales en logs
**Regla:** Los logs deben ser JSON estructurado con trace id en cada línea.
La app debe exponer métricas de Actuator y health checks de liveness y
readiness. Ningún dato personal del cliente (nombre, email, teléfono) ni
token de gestión debe aparecer en logs, trazas ni en el `detail` de un
error; si hace falta correlacionar, se usa el id del turno o del cliente.
Liveness no debe depender de ningún servicio externo. Readiness debe
depender solo de lo que impide atender reservas: la base sí, SMTP no (por
P7, una caída de SMTP no puede sacar la app de servicio). Los grupos se
declaran explícitamente en `management.endpoint.health.group.*` y no quedan
librados a los health indicators que Spring Boot agrega solo.
Ninguna llamada de red debe poder esperar indefinidamente: toda conexión a
un servicio externo debe tener timeouts de conexión y de lectura (y de
escritura donde el cliente lo admita) finitos y configurados, nunca el
default de la librería. Valores por defecto, sobreescribibles por variable
de entorno en `application.yml`:
- SMTP: conexión `mail.smtp.connectiontimeout` 5 s, lectura
  `mail.smtp.timeout` 10 s, escritura `mail.smtp.writetimeout` 10 s
  (propiedades de JavaMail bajo `spring.mail.properties`).
- Pool de conexiones a la base: `spring.datasource.hikari.connection-timeout`
  5 s.
- PostgreSQL por sesión: `statement_timeout` 5 s y `lock_timeout` 3 s,
  parametrizados como `app.db.statement-timeout` y `app.db.lock-timeout`.
  Un `lock_timeout` o `statement_timeout` vencido responde `503` con un
  código estable y reintentable, nunca `500`, y nunca `409 SLOT_TAKEN`
  (que solo sale de la violación del exclusion constraint, P1).

Todo cliente de red nuevo (HTTP, colas, otro proveedor) entra con sus
timeouts parametrizados en la misma spec que lo introduce.
**Por qué:** RNF de observabilidad, y los datos personales del cliente final
están protegidos por la Ley 25.326 de protección de datos personales. Los
timeouts: el default de JavaMail es infinito, así que un SMTP colgado
bloquea para siempre el hilo que procesa eventos; sin `statement_timeout` ni
`lock_timeout`, una consulta o un bloqueo trabados retienen conexiones del
pool hasta agotarlo y frenan las reservas. Readiness: Spring Boot agrega
el health indicator de mail por defecto, y con SMTP caído la app saldría de
servicio y dejaría de tomar reservas.
**Alcance:** Todo el sistema.
**Verificación:** Automatizada — test que captura la salida de logs de un
flujo completo de reserva y cancelación y afirma JSON válido con trace id y
ausencia del email, teléfono y token usados; test de
`/actuator/health/liveness` y `/readiness`; test con SMTP inalcanzable que
afirma liveness y readiness `UP`, y test con la base inalcanzable que
afirma readiness `DOWN` y liveness `UP`. Timeouts: test de integración
que levanta el contexto y afirma que cada timeout listado arriba es finito y
coincide con la configuración (propiedades de JavaMail, Hikari, y
`SHOW statement_timeout` / `SHOW lock_timeout` en una conexión del pool);
test con un servidor SMTP que acepta la conexión y nunca responde, que
afirma que el envío falla dentro del timeout de lectura y el evento queda
pendiente de reintento (P7); test que fuerza un `lock_timeout` y afirma
`503` con su código. Revisión en F7: todo cliente de red nuevo declara sus
timeouts parametrizados. El test de concurrencia de P1 debe seguir dando
exactamente una confirmada y el resto `409`, sin ningún `503`: si los
valores por defecto de `lock_timeout` lo rompieran, se ajusta el valor, no
el test.

### P11 — Código legible y diseño sostenible
**Regla:** El código de producción debe respetar SOLID, KISS, DRY y los
principios de la programación orientada a objetos (encapsulamiento,
inmutabilidad de los valores, polimorfismo antes que condicionales por
tipo), y cada patrón de diseño aplicado debe resolver un problema presente
en el código. En concreto:
- Ningún método debe superar los umbrales de complejidad cognitiva y
  ciclomática (`pmd.cognitiveComplexity.max`,
  `pmd.cyclomaticComplexity.max`).
- No debe haber bloques duplicados de `cpd.minimumTokens` tokens o más
  (por defecto 100) dentro de un mismo módulo.
- Ninguna clase debe acumular responsabilidades ni dependencias por encima
  de los umbrales de diseño de PMD (regla `GodClass`;
  `pmd.couplingBetweenObjects.max`; `pmd.excessiveParameterList.max`).
- Los nombres del código usan el lenguaje del dominio (turno, slot,
  bloqueo, profesional), no nombres genéricos (`Manager`, `Helper`,
  `Util`, `Data`).
- **Encapsulamiento:** los campos de las clases de `domain/` deben ser
  privados (salvo constantes `static final`) y ninguna clase de `domain/`
  debe exponer setters públicos; el estado cambia solo por métodos con
  nombre de negocio (`confirmar`, `cancelar`, `reprogramar`). El
  constructor sin argumentos que exige JPA (A2) debe ser `protected`.
- **Value objects inmutables:** los conceptos sin identidad propia (rango
  horario, duración, email, teléfono, dinero) deben modelarse como tipos
  propios, no como `String` o primitivos sueltos. En `domain/`, todo tipo
  que no sea una entidad JPA (`@Entity`) debe ser inmutable: `record` o con
  todos sus campos `final`, sin métodos que muten su estado; los
  `@Embeddable` se implementan como `record`.
- **Polimorfismo y herencia acotada:** una decisión por tipo o por estado
  que se repite en más de un lugar (`switch`/`if` sobre un enum o un
  `instanceof`) debe resolverse con polimorfismo (métodos en el enum, en el
  estado o en una jerarquía `sealed`), no con condicionales duplicados. La
  herencia se usa solo para una relación "es-un" real, nunca para reusar
  código (para eso, composición): ninguna clase de producción debe extender
  una clase concreta propia del proyecto.

Todos los umbrales viven en las propiedades del `pom.xml`. DRY se exige
dentro de cada módulo; entre módulos se comparte solo por la API pública
del módulo, y una duplicación menor es preferible a un módulo común que
acople a varios (P4).
**Por qué:** El challenge evalúa que el dominio se lea en el código y que
los módulos tengan límites claros; como pieza de portfolio, la legibilidad
es parte del entregable. Un patrón sin problema que resolver va contra KISS
y se lee como sobreingeniería. Un dominio con setters públicos o valores
mutables deja que cualquier capa saltee las invariantes del turno; los
condicionales por tipo duplicados obligan a tocar varios lugares para
agregar un estado o un tipo nuevo.
**Alcance:** Código de producción (no tests).
**Verificación:** Automatizada — PMD (complejidad y diseño) y CPD con los
umbrales del `pom`, fallan el build en `./mvnw verify` y en CI; la
inversión de dependencias hacia el dominio la verifican las reglas de capas
de `ARCHITECTURE.md` A2 (jMolecules + ArchUnit). Reglas ArchUnit de
orientación a objetos, que también fallan el build: campos privados y sin
setters públicos en `domain/`, constructores sin argumentos `protected`,
tipos de `domain/` que no son `@Entity` como `record` o con campos `final`,
`@Embeddable` como `record`, y ninguna clase de
producción que extienda una clase concreta del proyecto. Revisión en F7:
cada patrón de diseño nuevo nombra el problema concreto que resuelve;
ninguna abstracción (interfaz, fábrica, estrategia) tiene una sola
implementación sin un motivo escrito (puerto hacia algo externo, punto de
extensión previsto en una spec); nombres en el lenguaje del dominio;
ningún `switch`/`if` sobre el mismo enum, estado o `instanceof` aparece en
más de un lugar; todo concepto de valor sin identidad que la spec introduce
está modelado como value object y no como `String` o primitivo suelto.

### P12 — Costo en ejecución acotado
**Regla:** Ningún endpoint debe ejecutar una cantidad de queries
proporcional a la cantidad de resultados (sin N+1), ni cargar colecciones
completas para filtrar o paginar en memoria. El p95 de los endpoints de
disponibilidad y reserva debe quedar por debajo de `PERF_BUDGET_P95_MS`
(configuración del script de carga, por defecto 300) con el escenario de
carga del proyecto, definido como Q1 en `ARCHITECTURE.md` § 2.
**Por qué:** Disponibilidad recorre días × tramos × turnos × profesionales;
es el camino que más crece con el uso. El número tiene que poder
defenderse en el README.
**Alcance:** Capa de acceso a datos y endpoints de `scheduling` y `booking`.
**Verificación:** Automatizada — tests que cuentan queries en disponibilidad
y agenda con volúmenes distintos y afirman la misma cantidad; script k6 con
`thresholds` leídos de `PERF_BUDGET_P95_MS`. Revisión en F7:
`sdd-complexity-reviewer` contra la sección "Volumen y presupuestos" de
cada spec.

## Verificaciones pendientes

Ninguna verificación automatizada existe todavía (proyecto nuevo). Cada
una se crea en la spec que introduce el comportamiento que verifica; las
transversales son candidatas a spec propia o a la spec de base del
proyecto. Las iteraciones son las del orden adoptado en `PRD.md` §
Restricciones:

| Verificación | Principio | Candidata |
|---|---|---|
| Test Modulith + reglas ArchUnit | P2, P4, P8 | Spec de esqueleto (iteración 0) |
| Reglas ArchUnit de orientación a objetos (encapsulamiento, value objects, herencia) | P11 | Spec de esqueleto (iteración 0); hasta que haya clases de dominio, las reglas no deben fallar por vacías |
| Test de esquema: `tenant_id` con FK en cada tabla de negocio | P3 | Primera spec que crea tablas (núcleo de reservas) |
| PMD (complejidad y diseño) y CPD con umbrales en el `pom` | P11 | Spec de esqueleto (iteración 0) |
| Pipeline de CI (GitHub Actions) con gitleaks | P9 | Spec de esqueleto (iteración 0) |
| Actuator privado y errores sin detalles internos | P9 | Spec de esqueleto (iteración 0) |
| Reglas ArchUnit de tests (sin `Thread.sleep`, sin dobles del dominio), orden aleatorio, sin reintentos, PIT en CI | P8 | Spec de esqueleto (iteración 0) |
| Script de trazabilidad escenario ↔ `@DisplayName` | P8 | Spec de esqueleto (iteración 0), antes de que la primera spec con escenarios llegue a F7 |
| Tabla de permisos, test endpoint × rol y test de endpoints sin declarar | P9 | Spec de usuarios y acceso (iteración 2); cada spec posterior suma sus endpoints a la tabla |
| Test de agenda y bloqueos de otro profesional → `404` | P9 | Spec de catálogo, agenda y disponibilidad (iteración 3) |
| Logs JSON, health checks, test de ausencia de datos personales | P10 | Spec de esqueleto, iteración 0 (logs, health); test de datos personales con la primera spec que reciba datos del cliente |
| Timeouts: test de configuración de la base y del pool, test de `lock_timeout` → `503` | P10 | Spec de esqueleto (iteración 0) para el pool y la sesión de Postgres; el test de `503` con la primera spec que escribe turnos (iteración 1) |
| Timeouts SMTP: test de configuración y test con un SMTP que no responde | P10 | Spec de notificaciones (iteración 5) |
| Health checks: base inalcanzable → readiness `DOWN`; SMTP inalcanzable → readiness `UP` | P10 | Spec de esqueleto, iteración 0 (base); el caso SMTP con la spec de notificaciones (iteración 5), cuando se agrega el envío de mail |
| Test de 200 reservas concurrentes | P1 | Spec del núcleo de reservas (iteración 1) |
| Script k6 con umbrales | P12 | Spec de portfolio (iteración 6) |

## Enmiendas

| Fecha | Versión | Cambio | Motivo |
|---|---|---|---|
| 2026-10-25 | 1.0.0 | Versión inicial | — |
| 2026-10-26 | 2.0.0 | P3 redefinido: de "Aislamiento entre negocios" (filtrado por tenant y `404` entre negocios) a "Esquema preparado para aislar negocios" (`tenant_id` con FK y unicidades por negocio, negocio actual desde un solo componente). El aislamiento real vuelve en la etapa 2 | Decisión de alcance de la usuaria (PRD A32): el MVP no cubre multi-tenancy |
| 2026-10-26 | 2.1.0 | P9: el vencimiento del link de gestión deja de ser un plazo fijo (`MANAGEMENT_LINK_TTL`, eliminado) y pasa a depender de la antelación de cancelación del negocio (operar) y del fin del turno (ver); se agrega la revocación del link al reprogramar o cancelar, con sus tests | Decisión de la usuaria en PRD A16 |
| 2026-10-26 | 2.1.1 | Redacción: "Verificaciones pendientes" alineada al orden de iteraciones adoptado en el PRD; el CI (GitHub Actions) con gitleaks pasa de "esqueleto o de operación" a la spec de esqueleto (iteración 0). Ningún principio cambia | Orden de iteraciones adoptado por la usuaria |
| 2026-10-26 | 2.2.0 | P11 ampliado: de "Complejidad estructural acotada" a "Código legible y diseño sostenible" — suma SOLID, KISS, DRY (CPD con `cpd.minimumTokens`, por defecto 100, dentro de cada módulo), reglas de diseño de PMD, nombres del dominio y patrones con problema que resolver (revisión F7) | Pedido de la usuaria: dejar registrados SOLID, KISS, DRY, patrones de diseño y legibilidad |
| 2026-10-27 | 2.3.0 | P11 ampliado con orientación a objetos: encapsulamiento en `domain/` (campos privados, sin setters públicos, constructor de JPA `protected`), value objects inmutables (`@ValueObject` como `record` o campos `final`) y polimorfismo con herencia acotada (sin condicionales por tipo duplicados, sin extender clases concretas propias); verificado con ArchUnit y revisión en F7. "Dominio rico" queda como guía en `CLAUDE.md` del proyecto | Pedido de la usuaria: reglas de programación orientada a objetos, como se hizo con SOLID, KISS y DRY |
| 2026-10-27 | 2.3.1 | Redacción de P11: la inmutabilidad de los value objects deja de depender de `@ValueObject` (módulo DDD de jMolecules, no adoptado) y se define sobre JPA: en `domain/`, todo tipo que no es `@Entity` es `record` o con campos `final`, y los `@Embeddable` son `record`. Ninguna obligación nueva | Detectado por la usuaria: v2.3.0 adoptaba DDD táctico de forma implícita; la adopción de DDD se evalúa aparte como `ARCHITECTURE.md` A3 |
| 2026-10-27 | 2.4.0 | P10 ampliado con timeouts: toda llamada de red con timeouts finitos y parametrizados, nunca el default de la librería (SMTP 5 s / 10 s / 10 s, Hikari 5 s, `statement_timeout` 5 s, `lock_timeout` 3 s); timeout de la base → `503` reintentable, nunca `500` ni `409`; tests de configuración, de SMTP que no responde y de `lock_timeout` | Pedido de la usuaria tras revisar prácticas de resiliencia; P10 en vez de un P13 para no pasar el tope de 12 principios |
| 2026-10-27 | 2.5.0 | P10 ampliado: liveness sin dependencias externas; readiness depende de la base y no de SMTP; grupos de health declarados explícitamente; tests con base y SMTP inalcanzables | Pedido de la usuaria tras revisar las reglas de observabilidad: el health indicator de mail que agrega Spring Boot sacaría la app de servicio con SMTP caído, contra P7 |
| 2026-10-27 | 2.6.0 | P9 ampliado: autorización denegada por defecto con tabla de permisos verificada endpoint × rol y recursos de otro profesional → `404`; Actuator privado salvo liveness y readiness; errores sin stack traces, mensajes de excepción, SQL ni nombres de clase; alcance de P9 pasa a todo el sistema | Pedido de la usuaria tras revisar las reglas de seguridad |
| 2026-10-27 | 2.7.0 | P8 ampliado de "Persistencia probada contra Postgres real" a "Tests confiables y trazables": suma trazabilidad escenario ↔ `@DisplayName`, dobles solo en los puertos hacia afuera, determinismo (sin `Thread.sleep`, orden aleatorio, sin reintentos, `@Disabled` con motivo) y PIT como reporte sin umbral; la regla de persistencia real no cambia | Pedido de la usuaria tras revisar las reglas de testing; PIT solo como reporte por decisión de la usuaria |
| 2026-10-27 | 2.7.1 | Redacción de P12: "el escenario de carga del proyecto" pasa a referenciar Q1 de `ARCHITECTURE.md` § 2, que no existía. Ninguna obligación nueva | Definición del escenario de carga con la usuaria |
