# PRD — MVP de reserva de turnos

Estado: **borrador, pendiente de validación de asunciones** — 2026-10-26

## Fuente
- Documento "Challenge técnico: MVP de reserva de turnos", 22/10/2026,
  10 páginas (`~/Documents/repos/Docs/Challenge técnico MVP de reserva de
  turnos.pdf`). Incluye un diagrama de módulos (pág. 6) transcripto abajo.
- No hubo intercambios posteriores por mail ni llamada. Todo lo que no esté
  en este documento no existe.
- Aclaración de la usuaria (26/10/2026): no hay plazo ni evaluador externo.
  Es un proyecto de portfolio personal para mostrar el trabajo que puede
  hacer; ella es quien decide sobre el alcance.
- Decisión de alcance de la usuaria (26/10/2026): el MVP no cubre
  multi-tenancy; el esquema queda preparado para agregarla en una segunda
  etapa (ver A32).

## El encargo en una frase
Construir el backend de un MVP de reserva de turnos online para un negocio,
preparado para varios, donde un profesional nunca tiene dos turnos
superpuestos aunque lleguen cientos de pedidos simultáneos, y explicar el
porqué de cada decisión como pieza de portfolio.

## Contexto dado
- Negocios de belleza, bienestar y salud (peluquerías, barberías, centros
  de estética, consultorios). El negocio publica servicios y la agenda de
  sus profesionales; el cliente final elige servicio, profesional y
  horario, y reserva sin llamar.
- "El foco no es la cantidad de features sino la calidad de las
  decisiones": consistencia bajo concurrencia, dominio claro, sistema fácil
  de operar.
- Proyecto nuevo (modo A): no hay código heredado.
- Tres actores en el enunciado; cuatro con la recepción (A34):

| Actor | Qué hace | Autenticación |
|---|---|---|
| Admin del negocio | Configura negocio, servicios, profesionales y horarios; ve la agenda | Usuario y contraseña, JWT |
| Profesional | Ve su agenda del día y la semana | Usuario y contraseña, JWT |
| Recepcionista o encargada *(agregado por decisión de la usuaria, A34; no está en el enunciado)* | Opera la aplicación en el local: ve la agenda de todos los profesionales, reserva para clientes que llaman o se acercan, cancela, reprograma y cierra turnos como `COMPLETED` o `NO_SHOW`. Menos permisos que el admin | Usuario y contraseña, JWT |
| Cliente final | Consulta disponibilidad, reserva, cancela y reprograma | Sin cuenta: nombre, email, teléfono; gestiona su turno con link firmado |

- Diagrama de módulos (pág. 6), transcripto: la API REST (pública por slug
  y admin con JWT) entra por `tenancy`, que resuelve el negocio de cada
  request y aísla sus datos. Debajo, `catalog`, `scheduling` y `booking`.
  Flechas sólidas (llamadas en proceso): `scheduling → catalog`
  ("consulta") y `scheduling → booking` ("consulta"). Flecha punteada:
  `booking → notifications` ("evento vía outbox"). Los cuatro módulos de
  dominio llegan a PostgreSQL ("exclusion constraint sobre el rango de cada
  turno · outbox de eventos"). "Toda decisión que se aparte de esta tabla
  se documenta en un ADR."

## Objetivos
| # | Objetivo | Explícito o inferido |
|---|---|---|
| O1 | Garantizar en la base que dos turnos activos del mismo profesional no compartan ningún instante, buffer incluido (RD-01) | explícito |
| O2 | Cubrir el ciclo completo de un turno, de la configuración del negocio al cierre (`COMPLETED`, `NO_SHOW` o `CANCELLED`), para los cuatro actores: admin, profesional, recepcionista y cliente final (HU-01 a HU-10) | explícito; ampliado con la recepción y el cierre manual (A7, A34); el alta de negocios de HU-01 pasa a la etapa 2 (A2, A32) |
| O3 | Aislar los datos de cada negocio en una instancia compartida (RD-05) | explícito — **diferido a la etapa 2** (A32); en el MVP el esquema queda preparado |
| O4 | Un dominio que se lea en el código: estados explícitos, invariantes en las entidades, sin anemia | explícito (criterio de evaluación) |
| O5 | Sistema operable: logs JSON con trace id, métricas, health checks, errores con código estable | explícito |
| O6 | Que alguien sin contexto lo levante con un comando y reserve un turno en menos de 5 minutos | explícito (definición de terminado) |
| O7 | Que las decisiones y sus trade-offs queden explicados (README, ADRs) y sirvan como pieza de portfolio | explícito |

### Historias de usuario (transcriptas, con sus criterios)
- **HU-01 · Alta de negocio.** Admin registra negocio con nombre, slug
  público y zona horaria. Slug único, define la URL pública. Zona horaria es
  un `ZoneId` válido y se usa en todos los cálculos de agenda.
- **HU-02 · Catálogo de servicios.** Admin crea, edita y desactiva servicios
  con duración, precio y buffer posterior. Duración y buffer múltiplos de 5
  min; duración > 0, buffer ≥ 0. Desactivar no afecta turnos confirmados.
- **HU-03 · Profesionales y horarios.** Admin da de alta profesionales, les
  asigna servicios y define horario semanal. Un día puede tener varios
  tramos; los tramos de un día no se superponen.
- **HU-04 · Excepciones.** Admin o profesional bloquea rangos de fecha y
  hora. Un bloqueo que se superpone con turnos confirmados se rechaza y
  devuelve la lista de turnos en conflicto.
- **HU-05 · Consultar disponibilidad.** Cliente ve horarios libres de un
  servicio en un rango de fechas, con o sin profesional elegido. Slot válido
  si entra completo (duración + buffer) en un tramo, sin bloqueos ni turnos
  activos. Horarios en la zona del negocio con offset explícito. Sin slots en
  el pasado ni más allá de la ventana de reserva.
- **HU-06 · Reservar turno.** Cliente reserva dejando nombre, email y
  teléfono. Slot tomado → `409 SLOT_TAKEN`. Mismo `Idempotency-Key` →
  mismo turno, no crea otro. Al confirmar se dispara email de confirmación
  con link de gestión.
- **HU-07 · Cancelar turno.** Cliente (con link) o admin. Cliente solo hasta
  la antelación mínima del negocio; admin siempre. El slot liberado vuelve a
  la disponibilidad de inmediato.
- **HU-08 · Reprogramar turno.** Cliente o admin mueve un turno a otro slot.
  Atómico: si el nuevo slot no está libre, el original queda intacto.
- **HU-09 · Recordatorios.** Se envía una sola vez por turno, aunque el
  proceso se reinicie o corra en varias instancias.
- **HU-10 · Agenda.** Admin o profesional ve turnos por día y semana,
  filtrando por profesional y estado.

### Reglas de dominio (transcriptas)
- **RD-01 · Sin superposición.** Constraint en la base, no chequeo previo en
  código.
- **RD-02 · Tiempo.** Instantes en UTC; conversión con la zona del negocio,
  contemplando cambios de horario.
- **RD-03 · Estados.** (Ampliado por A7: se agrega `NO_SHOW`.)
  `CONFIRMED`, `CANCELLED`, `COMPLETED`. Solo
  `CONFIRMED` ocupa agenda. Transiciones inválidas se rechazan.
- **RD-04 · Políticas del negocio.** Antelación mínima para reservar,
  ventana máxima de reserva y antelación mínima para cancelar, configurables
  por negocio con valores por defecto.
- **RD-05 · Aislamiento.** Ninguna consulta devuelve datos de otro negocio;
  recurso de otro tenant → `404`, no `403`.

### Requerimientos no funcionales (transcriptos)
- **Concurrencia:** 200 pedidos simultáneos por el mismo slot → exactamente
  una confirmación, el resto `409`. Demostrado con test automatizado.
- **Idempotencia:** POST de reserva, cancelación y reprogramación aceptan
  `Idempotency-Key`; la clave se guarda al menos 24 h.
- **Entrega de eventos:** emails por outbox transaccional; si la reserva se
  confirma, el evento no se pierde aunque el proceso caiga.
- **Errores:** `application/problem+json` con código de negocio estable
  (ejemplo en el enunciado: `type`, `title`, `status`, `code`, `detail`).
- **Observabilidad:** logs JSON con trace id, métricas de Actuator, health
  checks de liveness y readiness.
- **Seguridad:** BCrypt, links de gestión firmados y con vencimiento, rate
  limit básico en endpoints públicos.

### Modelo y API de partida
El enunciado declara que modelo y endpoints "son un punto de partida: se
pueden ajustar si se justifica en un ADR".

- Entidades (todas con `tenant_id`): `Business` (slug, nombre, zona,
  políticas), `Service` (nombre, duración, buffer, precio, activo),
  `Professional` (nombre, servicios, activo), `WorkingHours` (profesional,
  día, inicio, fin), `TimeOff` (profesional, rango de instantes, motivo),
  `Customer` (nombre, email, teléfono), `Booking` (profesional, servicio,
  cliente, rango ocupado `tstzrange` que incluye el buffer, estado,
  versión).
- Públicos: `GET /public/{slug}/services`,
  `GET /public/{slug}/availability?serviceId&professionalId&from&to`,
  `POST /public/{slug}/bookings`, `GET /public/bookings/{token}`,
  `POST /public/bookings/{token}/cancel`,
  `POST /public/bookings/{token}/reschedule`.
- Admin (JWT, tenant del token): `POST /auth/login`, CRUD
  `/admin/services`, CRUD `/admin/professionals`,
  `PUT /admin/professionals/{id}/working-hours`,
  `POST /admin/professionals/{id}/time-off`,
  `GET /admin/bookings?date&view=day|week&professionalId&status`,
  `POST /admin/bookings/{id}/cancel`.
- Agregados por decisiones de este PRD (cada desvío lleva ADR):
  endpoint de inicialización del admin con token (A3, A33); alta y baja de
  recepcionistas por el admin (A34); `POST /admin/bookings` para reservas
  de recepción (A34); `POST /admin/bookings/{id}/reschedule` (A12); cierre
  del turno como `COMPLETED` o `NO_SHOW` (A7). Las rutas exactas se fijan
  en los contratos de cada spec.

## Entregables
1. Repositorio público; `docker compose up` levanta todo con datos de
   ejemplo (un negocio, dos profesionales, tres servicios). Con las
   decisiones de este PRD, los datos de ejemplo incluyen también al admin
   (A33).
2. README con propósito, cómo correrlo, diagrama de arquitectura y
   decisiones principales; resultados de la prueba de carga resumidos.
3. `docs/adr` con al menos tres ADRs: monolito modular, estrategia anti
   doble-booking, outbox para notificaciones. Se suman uno de alcance (MVP
   de un solo negocio preparado para multi-tenancy, A32) y los de cada
   desvío del modelo o la API del enunciado (A3/A33, A7/A34, A12).
4. Especificación OpenAPI accesible desde la app.
5. Test de concurrencia (200 reservas simultáneas, un solo éxito) corriendo
   en CI.
6. Script de carga k6 o Gatling.
7. Pipeline de CI con build, tests y verificación de módulos en cada push.
8. Demo desplegada con URL pública.

## Restricciones
- Monolito modular en Java 21 sobre Postgres; microservicios explícitamente
  fuera.
- Stack fijo: Spring Boot 3 (Web, Data JPA, Security), Spring Modulith con
  test de dependencias, PostgreSQL 16 + Flyway, Event Publication Registry
  de Spring Modulith como outbox, OpenAPI 3 con springdoc, JUnit 5 +
  Testcontainers + ArchUnit o Modulith, k6 o Gatling, Docker Compose con
  app + Postgres + Mailpit.
- Cinco módulos: `tenancy`, `catalog`, `scheduling` (no conoce a `booking`
  por dentro), `booking` (único que escribe turnos), `notifications` (solo
  escucha eventos, nunca se llama síncrono).
- Apartarse de la tabla de stack o del modelo/API de partida requiere ADR.
- Repositorio público en GitHub, con CI en GitHub Actions (decisión de la
  usuaria, 2026-10-26; ver `ARCHITECTURE.md` § Restricciones).
- Plazo: no hay (A1, confirmado por la usuaria). Tamaño: el que marquen
  las iteraciones.
- Orden sugerido de iteraciones: 1) núcleo de reservas, 2) agenda y
  disponibilidad, 3) gestión del turno, 4) notificaciones, 5) admin y
  multi-tenancy, 6) operación y portfolio. "El núcleo de concurrencia va
  primero." (Transcripción del enunciado; el orden que se sigue es el de
  abajo.)
- **Orden adoptado** (decidido por la usuaria, 2026-10-26). Se aparta del
  sugerido porque las decisiones de este PRD y la constitución lo cambian;
  el desvío se explica en el README o en un ADR. El núcleo de concurrencia
  sigue siendo la primera iteración con dominio.

| # | Iteración | Incluye | Por qué en este lugar |
|---|---|---|---|
| 0 | Esqueleto | Proyecto y módulos vacíos con verificación de Spring Modulith; estructura interna hexagonal con sus reglas de dependencia (jMolecules, `ARCHITECTURE.md` A2); reglas ArchUnit; PMD; CI con gitleaks; logs JSON con trace id; health checks; Docker Compose; base de tests con Testcontainers; manejo de errores `problem+json` | La constitución exige estas verificaciones desde la primera feature (P1 test de concurrencia en CI; P2, P4, P5, P8, P9, P10, P11). No agrega funcionalidad de dominio |
| 1 | Núcleo de reservas | Negocio único con `tenant_id` (A32); turno con exclusion constraint; `POST` público de reserva con `Idempotency-Key` (A17); test de 200 reservas concurrentes en CI; test de esquema de P3 | Como en el enunciado. La reserva pública no requiere autenticación, así que no depende de la iteración 2 |
| 2 | Usuarios y acceso | Inicialización del admin con token (A3, A33); login JWT; roles `ADMIN`, `PROFESSIONAL`, `RECEPTIONIST` (A34); alta y baja de recepcionistas; datos de ejemplo | Antes era parte de la 5. Todo lo que sigue tiene endpoints protegidos por rol, y los profesionales necesitan usuario (A3) |
| 3 | Catálogo, agenda y disponibilidad | Servicios; profesionales con su usuario; horarios semanales; bloqueos (A4–A6); disponibilidad con paso por negocio (A8) y tests de cambio de horario (A24) | Antes era la 2; requiere usuarios y permisos |
| 4 | Gestión del turno | Cancelar y reprogramar solo el horario (A10, A11); links firmados con revocación (A16); políticas del negocio (A20); reserva de recepción (A34); cierre `COMPLETED`/`NO_SHOW` (A7); agenda por día y semana (HU-10, A25) | Antes era la 3, ampliada: reúne todas las operaciones sobre un turno existente |
| 5 | Notificaciones | Outbox con Spring Modulith; emails de confirmación, reprogramación y cancelación (A19), con email opcional (A34); recordatorio único (A18) | Antes era la 4; reacciona a los eventos de las iteraciones 1 y 4 |
| 6 | Portfolio | Prueba de carga k6 con resultados (A29); README; ADRs finales; demo desplegada (A28) | CI y observabilidad ya están desde la 0 |

## Criterios de evaluación
| Criterio | Qué se mira (explícito) |
|---|---|
| Corrección | RD-01 a RD-05 se cumplen y tienen tests que lo prueban. En el MVP, RD-05 queda fuera por decisión de alcance (A32) |
| Concurrencia | La garantía vive en la base y se demuestra bajo carga |
| Modelado | Estados explícitos, invariantes en las entidades, sin anemia |
| Diseño | Módulos con límites claros y dependencias verificadas |
| Tests | Unitarios de disponibilidad, integración con Postgres real, sin mocks de la base |
| Operabilidad | Logs, métricas, health checks, errores con código estable |
| Comunicación | README y ADRs explican el porqué y los trade-offs |

Inferido: que el historial del repo muestre el método de trabajo (specs,
TDD) suma como portfolio, aunque no se pide.

## Ambigüedades
| # | Qué no está claro | Cómo se resuelve | Riesgo si me equivoco |
|---|---|---|---|
| A1 | Plazo de entrega y tiempo disponible | **Confirmado:** no hay plazo. Se avanza por iteraciones y cada una deja algo mostrable | — |
| A2 | HU-01 no tiene endpoint en la API de partida: ¿cómo se da de alta un negocio y su primer admin? | **Confirmado por la usuaria (2026-10-26):** En el MVP hay un solo negocio y se crea con los datos de ejemplo (A32); el admin puede editar nombre, zona horaria y políticas. El alta de negocios nuevos (`POST /auth/signup` u otro mecanismo) pasa a la etapa 2 | Falta el alta autoservicio que pide HU-01; queda declarado como etapa 2 |
| A3 | Usuarios por negocio: ¿uno o varios admins? ¿cómo se crea el usuario del profesional? | **Confirmado por la usuaria (2026-10-26):** exactamente un admin por negocio; es siempre el primer usuario y sin él no se puede crear ningún otro. Se crea con un endpoint de inicialización que solo funciona mientras no exista admin (después responde `409`); ver A33. Profesionales: N por negocio, cada uno con su usuario en relación 1 a 1, creado por el admin con una contraseña que el admin define. El admin da de baja a un profesional desactivándolo: deja de poder entrar y de ofrecerse en la disponibilidad; sus turnos confirmados siguen en pie y los gestiona el admin. La recepcionista es un tercer tipo de usuario (A34). Cambio y recuperación de contraseña, para todos los usuarios, pasan a la etapa 2 | El admin no puede rotar credenciales de un profesional en el MVP salvo dándolo de baja y creando otro |
| A4 | HU-04 permite al profesional bloquear, pero el endpoint está bajo `/admin`. ¿Qué puede bloquear el profesional? | **Confirmado por la usuaria (2026-10-26):** El profesional usa el mismo endpoint y solo puede bloquear su propia agenda; sobre otro profesional responde `404` | Si debía tener endpoints propios, rutas distintas en el contrato |
| A5 | HU-04: ¿qué devuelve un bloqueo rechazado? | **Confirmado por la usuaria (2026-10-26):** `409` problem+json con `code` `TIME_OFF_CONFLICT` y una extensión con la lista de turnos en conflicto (id, rango, sin datos personales del cliente) | Formato distinto al esperado; menor |
| A6 | `TimeOff` es por profesional: ¿cómo se carga un feriado de todo el negocio? | **Confirmado por la usuaria (2026-10-26):** Solo bloqueos por profesional; un feriado se carga en cada profesional. Bloqueos del negocio entero fuera de alcance | Carga tediosa para el admin; se podría esperar un bloqueo global |
| A7 | RD-03: ¿quién o qué pasa un turno a `COMPLETED`? No hay endpoint | **Decidido por la usuaria (2026-10-26), amplía RD-03:** se agrega el estado `NO_SHOW`. El cierre de un turno es **manual**, sin proceso automático: la recepcionista (A34) o el admin pasan un turno `CONFIRMED` a `COMPLETED` o a `NO_SHOW`. Se puede marcar desde que empieza el turno, sin plazo límite (confirmado). `COMPLETED` y `NO_SHOW` son finales: un `NO_SHOW` cargado por error no se corrige. Un turno pasado que nadie cierra queda `CONFIRMED`; no afecta la disponibilidad porque no se ofrecen slots en el pasado. Marcar no-show no envía email. Desvío del modelo del enunciado: se justifica en ADR | Turnos pasados sin cerrar ensucian la agenda y cualquier métrica de asistencia; un error de carga en `NO_SHOW` es permanente |
| A8 | Granularidad de los slots: ¿cada cuánto empieza un slot? (slot = horario de inicio que se ofrece como reservable; distinto de la duración del servicio, que dice cuánto ocupa el turno) | **Confirmado por la usuaria (2026-10-26), opción A:** paso fijo configurable por negocio (`slot step`), por defecto 15 min, múltiplo de 5; los slots se alinean al inicio de cada tramo laboral y el último es el que permite terminar (duración + buffer) dentro del tramo. Descartado: paso igual a duración + buffer de cada servicio (con servicios de distinta duración en un mismo profesional ofrece horarios desalineados y deja huecos sueltos) y paso configurable por servicio (más configuración y casos de test sin beneficio claro para el MVP) | Huecos cortos inutilizables entre turnos; se ajusta cambiando el paso del negocio |
| A9 | HU-05 "sin profesional elegido": ¿cómo se reserva luego? | **Confirmado por la usuaria (2026-10-26):** Disponibilidad sin profesional devuelve cada slot con los profesionales libres. La reserva **siempre** lleva `professionalId` (el cliente elige uno de los ofrecidos). Asignación automática fuera de alcance | Si se esperaba "cualquiera" con asignación por el sistema, falta lógica y cambia el test de concurrencia |
| A10 | HU-08: ¿la reprogramación puede cambiar servicio o profesional? ¿Mismo turno o uno nuevo? | **Decidido por la usuaria (2026-10-26):** reprogramar cambia **solo el horario**; servicio y profesional quedan fijos. Para cambiar de profesional o de servicio se cancela y se reserva de nuevo. Se modifica el mismo turno (mismo id, nueva versión, el link sigue valiendo), en una sola transacción contra el constraint: si el nuevo horario no está libre, el turno original queda intacto | Un cliente que quiere otro profesional tiene que cancelar y reservar, y puede perder el horario original si dentro de la antelación de cancelación ya no puede cancelar |
| A11 | HU-08: ¿el cliente puede reprogramar dentro de la antelación mínima de cancelación? | **Confirmado por la usuaria (2026-10-26):** No: reprogramar respeta la misma antelación mínima que cancelar; el nuevo slot respeta antelación mínima de reserva y ventana. El admin no tiene límite de antelación | Política más restrictiva o más laxa que la esperada |
| A12 | HU-08 dice "cliente o admin", pero no hay endpoint admin de reprogramación | **Confirmado por la usuaria (2026-10-26):** Se agrega `POST /admin/bookings/{id}/reschedule`, usable por admin y recepcionista (A34), justificado en ADR | Endpoint de más si no se esperaba |
| A13 | HU-07/HU-10: ¿el profesional puede cancelar? | **Confirmado por la usuaria (2026-10-26):** No; cancelan el cliente, el admin y la recepcionista (A34). El profesional solo ve su agenda (y bloquea, A4) | Falta un permiso esperado |
| A14 | ¿Ve el profesional la agenda de otros profesionales? | **Confirmado por la usuaria (2026-10-26):** No; un profesional solo ve la suya | Restricción que nadie pidió |
| A15 | `Customer`: ¿se reutiliza entre turnos? | **Confirmado por la usuaria (2026-10-26):** Un `Customer` por (negocio, email); en cada reserva se actualizan nombre y teléfono **Ampliado por la usuaria (2026-10-26):** un cliente sin email (reserva de recepción, A34) se identifica por (negocio, teléfono normalizado; el formato se define en la spec). Al reservar con email: (1) se busca por email; (2) si no existe, se busca por teléfono entre los clientes **sin email** y, si hay uno, se le asocia el email (sin duplicar el cliente); (3) si no, se crea uno nuevo. Nunca se reemplaza un email ya asociado. **Sin precarga:** ningún endpoint público devuelve datos de un cliente a partir de su email o teléfono; el cliente siempre escribe sus datos y la asociación ocurre solo del lado del servidor. Precargar datos con verificación del email pasa a la etapa 2. Descartado: identificar siempre por teléfono (cambia la identidad por email); cliente nuevo por turno sin email (un habitual del local aparecería repetido); asociación confirmada por recepción (más segura, pero suma un flujo y una pantalla para el MVP); precarga sin verificación (expone nombre y teléfono de terceros a quien conozca su email, contra la Ley 25.326) | Nadie verifica que el teléfono sea de quien lo escribe: alguien que conozca el teléfono de un cliente sin email puede asociarle su propio email y recibir los links de gestión de sus próximos turnos cargados por recepción. Acotado a clientes sin email y documentado; la mitigación fuerte (verificación del email o confirmación de recepción) es de la etapa 2 |
| A16 | Link firmado: ¿cuándo vence? ¿sirve después de cancelar? | **Decidido por la usuaria (2026-10-26):** (1) el link permite **operar** (cancelar, reprogramar) solo hasta el límite de la antelación mínima de cancelación del negocio (A11, A20); después solo permite **ver** el turno, hasta que el turno termina (confirmado). (2) Al **reprogramar** (por el cliente, el admin o recepción) el token actual se revoca y se emite uno nuevo, que va en el email de reprogramación (A19); el link viejo deja de funcionar incluso para ver, porque el horario anterior puede pasar a ser de otra persona. (3) Al **cancelar** el token se revoca y no se emite otro (confirmado): el link deja de funcionar. El turno conserva su id al reprogramar (A10); lo que cambia es el token. Cómo se revoca (por ejemplo, firmar id + versión del turno, o token aleatorio guardado con su hash) es una decisión de diseño de la spec | Un cliente que pierde el email de reprogramación queda sin link y tiene que gestionar el turno por el negocio; no hay reenvío de link en el MVP |
| A17 | `Idempotency-Key`: ¿obligatoria en las tres operaciones? ¿Qué pasa si se reusa con otro cuerpo? | **Confirmado por la usuaria (2026-10-26):** obligatoria en todo `POST` que escribe un turno: reservar, cancelar y reprogramar (públicos), y reservar (A34), cancelar, reprogramar (A12) y cerrar como `COMPLETED`/`NO_SHOW` (A7) desde administración; sin ella `400`. Un reintento con la misma clave no vuelve a ejecutar la operación y devuelve la respuesta guardada. Misma clave con cuerpo distinto → `422` `IDEMPOTENCY_KEY_REUSED`. Alcance de la clave: negocio + operación; retención `IDEMPOTENCY_KEY_TTL`, por defecto 24 h. Por qué obligatoria aunque el exclusion constraint ya impide el doble turno: el constraint protege la agenda, la clave protege la semántica del reintento; sin ella, un reintento de una reserva exitosa recibe un `409 SLOT_TAKEN` falso y el cliente puede reservar otro horario creyendo que perdió el primero, y un reintento de cancelar o reprogramar devuelve error o duplica emails | Clientes de la API que no mandan la clave reciben `400`; se documenta en el contrato OpenAPI |
| A18 | HU-09: ¿cuánto antes se envía el recordatorio? ¿Y si el turno se reservó dentro de ese plazo? | **Confirmado por la usuaria (2026-10-26):** Antelación del recordatorio configurable a nivel aplicación (por defecto 24 h); turnos reservados dentro de ese plazo no reciben recordatorio. Por negocio fuera de alcance | Si se esperaba por negocio, otra política en RD-04 |
| A19 | ¿Qué emails salen ante reprogramación y ante cancelación por el negocio? | **Confirmado por la usuaria (2026-10-26):** Reprogramar envía un email de "turno reprogramado" con el nuevo horario; cancelación (por cliente o negocio) envía email de cancelación al cliente. Ningún email al profesional | Se espera notificar al profesional, o no notificar la reprogramación |
| A20 | RD-04: valores por defecto de las políticas | **Confirmado por la usuaria (2026-10-26):** Antelación mínima para reservar 1 h, ventana máxima 60 días, antelación mínima para cancelar 24 h, todo configurable por negocio | Defaults poco realistas; solo afecta la demo |
| A21 | Precio: ¿moneda? | **Confirmado por la usuaria (2026-10-26):** solo `ARS`, parametrizado. El negocio guarda su moneda (código ISO 4217, validado contra la lista estándar del JDK) y al crearse toma el valor de configuración `DEFAULT_CURRENCY`, por defecto `ARS`. Sin tabla de monedas: no hay tipos de cambio, conversiones ni monedas fuera de ISO que administrar. Precio como decimal exacto (`numeric` / `BigDecimal`), con los decimales que define la moneda | Si en el futuro hiciera falta multimoneda con conversión, recién ahí se justifica modelar monedas |
| A22 | Diagrama: `scheduling → booking` ("consulta"), pero `booking` también necesita validar que el slot cae en horario laboral y conocer duración/buffer del servicio. Si `booking` llama a `scheduling` hay un ciclo | `booking` depende de las API públicas de `catalog` y `scheduling` para validar; `scheduling` obtiene la ocupación de turnos sin depender de `booking` (por ejemplo, `booking` expone un puerto que `scheduling` define, o se lee de una vista de solo lectura). La forma exacta la decide `sdd-architecture` y queda en ADR | Ciclo de dependencias que hace fallar la verificación de Modulith, o desvío del diagrama sin justificar |
| A23 | ¿Reemplazar el horario semanal (`PUT working-hours`) puede dejar turnos confirmados fuera de horario? | **Confirmado por la usuaria (2026-10-26):** Se permite; los turnos existentes quedan intactos (como desactivar servicio, HU-02). Mismo criterio al desactivar un profesional, confirmado en A3 | Si se esperaba rechazo como en HU-04, inconsistencia con los bloqueos |
| A24 | Horarios semanales y cambio de horario: tramos que cruzan medianoche o caen en la hora que no existe | **Confirmado por la usuaria (2026-10-26):** Los tramos son de un mismo día (fin > inicio) en hora local del negocio; una hora local inexistente se corre hacia adelante y una repetida toma el primer instante, siguiendo `ZonedDateTime`. Se implementa en el MVP aunque Argentina hoy no cambie la hora: lo exige RD-02 y constitución P2, y se cubre con tests de disponibilidad en una zona con cambio de horario | Slots fantasma o faltantes en los días de cambio de horario |
| A25 | HU-10: ¿qué es "la semana"? | **Confirmado por la usuaria (2026-10-26):** Semana ISO (lunes a domingo) en la zona del negocio | Menor |
| A26 | Rate limit "básico": ¿por instancia o distribuido? | **Confirmado por la usuaria (2026-10-26):** Por IP y por instancia, en memoria, umbrales configurables. Distribuido fuera de alcance | Con varias instancias el límite efectivo se multiplica; se documenta |
| A27 | ADRs en `docs/adr` (enunciado) vs. decisiones en `DESIGN.md`/`ARCHITECTURE.md` (método SDD) | **Confirmado por la usuaria (2026-10-26):** `docs/adr/` es el entregable con el análisis completo; `ARCHITECTURE.md` y `DESIGN.md` resumen cada decisión y enlazan su ADR en vez de duplicarlo | Duplicación o ADRs que no reflejan las decisiones reales |
| A28 | Demo desplegada: ¿dónde y con qué presupuesto? | Pendiente de decisión de la usuaria (iteración 6) | Costos o un proveedor que no conviene |
| A29 | Test de concurrencia: ¿test de integración o prueba de carga? | **Confirmado por la usuaria (2026-10-26):** Ambos: test JUnit + Testcontainers con 200 pedidos concurrentes en CI (P1), y script k6 aparte para la prueba de carga del README | Ninguno relevante |
| A30 | Datos personales del cliente: ¿retención y borrado? | **Confirmado por la usuaria (2026-10-26):** Fuera de alcance del MVP; se menciona en el README como deuda (Ley 25.326) | Un evaluador puede esperar al menos una política declarada |
| A31 | Idioma de API, errores y emails | **Confirmado por la usuaria (2026-10-26):** Código y API en inglés (como el enunciado); `title` de errores y emails en español | Menor |
| A32 | ¿Multi-tenancy en el MVP? (decisión de alcance, no del enunciado) | **Decidido por la usuaria:** el MVP sirve a un solo negocio, pero queda preparado. Cada tabla de negocio lleva `tenant_id` y las unicidades se definen por negocio desde la primera migración; el negocio único se crea con los datos de ejemplo. Pasan a la etapa 2: resolución del tenant por request (slug/JWT), filtrado de toda consulta por `tenant_id`, tests de aislamiento con `404` entre negocios (RD-05) y alta de negocios (HU-01). Las rutas públicas conservan `{slug}`. Se documenta en un ADR que aclara que la columna sin filtro **no** es aislamiento | Que la columna `tenant_id` se tome por aislamiento real; que la etapa 2 encuentre consultas que asumen un solo negocio |
| A33 | Endpoint de inicialización del admin (A3) vs. datos de ejemplo: el enunciado pide un negocio con dos profesionales precargados, pero los profesionales tienen usuario y sin admin no se crean usuarios. Además, en la demo pública el endpoint queda abierto a quien llegue primero | **Confirmado por la usuaria (2026-10-26), (a) + (b):** (a) el endpoint de inicialización exige un token que se lee de una variable de entorno; si la variable no está definida, el endpoint queda deshabilitado (falla cerrado). (b) Con la carga de datos de ejemplo activada (parámetro de configuración), se crean negocio, admin, profesionales y servicios, y el endpoint responde `409` porque el admin ya existe; sin datos de ejemplo, el endpoint es el camino de alta del admin. Las credenciales del admin de ejemplo también salen de variables de entorno (constitución P9): el entorno local trae un valor de ejemplo en `.env.example` y la demo pública define los suyos | Un token filtrado permite apropiarse de una instancia sin admin; se mitiga porque deja de servir apenas existe el admin |
| A34 | Rol de recepción (no está en el enunciado) | **Decidido por la usuaria (2026-10-26):** se agrega el rol `RECEPTIONIST` (recepcionista o encargada que opera la aplicación en el local), con menos permisos que el admin. Puede: ver la agenda de todos los profesionales (HU-10); cancelar y reprogramar sin límite de antelación, como el admin; reservar para un cliente por teléfono o en el local (endpoint nuevo `POST /admin/bookings`, con `Idempotency-Key`); cerrar turnos como `COMPLETED` o `NO_SHOW` (A7). No puede: tocar catálogo, profesionales, horarios, bloqueos de agenda, usuarios ni políticas del negocio. El admin tiene todos los permisos de recepción. Confirmado también: N recepcionistas por negocio, creadas por el admin con contraseña, igual que los profesionales (A3); no aplican la antelación mínima ni la ventana máxima, pero no se puede reservar en el pasado ni fuera del horario laboral o sobre un bloqueo. Datos del cliente en una reserva de recepción: nombre y teléfono obligatorios, **email opcional**; con email se envían los mismos emails que en la reserva online (confirmación con link de gestión, recordatorio, reprogramación, cancelación); sin email no hay link ni emails y el turno se gestiona solo desde el local. Desvío del enunciado: se justifica en ADR | Un rol más multiplica los tests de permisos por endpoint; un cliente sin email no recibe recordatorio y es más probable que falte |

Cada decisión tomada acá se documenta después en DESIGN.md o como ADR
(A27) cuando tenga impacto técnico.

## Fuera de alcance
- Lo que el enunciado excluye: pagos y señas; stock, comisiones, caja,
  reportes de ventas; marketing, fidelización, giftcards; WhatsApp, IA,
  marketplace; apps móviles nativas; microservicios.
- Extras opcionales del enunciado, que solo se consideran una vez cerrado el
  MVP: seña con MercadoPago (estado `HELD`), Row Level Security, frontend
  mínimo, SQS en lugar del outbox local.
- Por decisión de la usuaria (A32), en la etapa 2: aislamiento entre
  negocios (RD-05), resolución del tenant por request, alta de negocios
  (HU-01) y tests de aislamiento. El esquema ya queda preparado.
- Por decisión de la usuaria (A3), en la etapa 2: cambio y recuperación de
  contraseña.
- Por decisión de la usuaria (A15), en la etapa 2: precarga de datos del
  cliente con verificación del email, y verificación de la asociación
  email-teléfono.
- Por asunción (ver Ambigüedades): asignación automática de profesional
  (A9), bloqueos de todo el negocio (A6), no-show (A7), gestión de usuarios
  más allá de un admin y sus profesionales (A3), recordatorio configurable por negocio (A18), rate limit distribuido (A26),
  emails al profesional (A19), política de retención de datos personales
  (A30).

## Preguntas para el evaluador/cliente
No hay evaluador ni cliente externo: es un proyecto de portfolio personal y
la usuaria decide el alcance (confirmado el 26/10/2026). Las ambigüedades se
resuelven por asunción validada por ella. Queda abierta:
- ¿Dónde se despliega la demo y con qué presupuesto? (A28) — se decide en
  la iteración 6.
