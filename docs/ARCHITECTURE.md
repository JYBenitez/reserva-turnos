# Arquitectura

Nivel de rigor: estándar
Convención: el análisis completo de cada decisión `A<n>` vive en su ADR en
`docs/adr/` (PRD A27); acá queda el resumen y el enlace.
Última actualización: 2026-10-27 — A1 motor de base de datos; A2 estructura interna de los módulos; A3 modelado del dominio; restricciones de repositorio y CI; escenario de calidad Q1; pendientes de resiliencia, observabilidad y seguridad en § 11. El resto del
modo sistema (estilo, componentes, integración, despliegue, atributos de
calidad) se completa después de cerrar el PRD.

## 1. Contexto y alcance
Backend del MVP de reserva de turnos descrito en `PRD.md`: un solo negocio
en el MVP, con el esquema preparado para multi-tenancy (PRD A32,
constitución P3). Este documento todavía cubre solo la base de datos (A1),
la estructura interna de los módulos (A2) y el modelado del dominio (A3).

## 2. Drivers

### Restricciones
- PostgreSQL 16 con migraciones Flyway — impuesta por el enunciado (PRD
  § Restricciones). A1 la analiza como si no lo estuviera, para dejar
  explícito por qué se habría elegido igual.
- La no superposición de turnos se garantiza con un constraint en la base,
  no con un chequeo previo en código — RD-01, constitución P1.
- Persistencia probada contra el mismo motor y versión mayor que
  producción, sin bases embebidas — constitución P8.
- Repositorio público en GitHub — decisión de la usuaria, 2026-10-26.
- CI con GitHub Actions — se deriva de la restricción anterior; no se
  evaluó como decisión con matriz porque no hay una alternativa sensata con
  el repositorio en GitHub (gratuito para repos públicos, Docker disponible
  en los runners para Testcontainers, action oficial de gitleaks para P9).
  Descartado: GitLab CI (solo tiene sentido con el repo en GitLab),
  CircleCI (no aporta sobre Actions para un repo en GitHub), Jenkins
  (servidor propio que mantener).

### Atributos de calidad
Priorizados. Por ahora solo está Q1; el resto (y su prioridad relativa) se
define en el modo sistema completo.

| # | Atributo | Prioridad | Escenario |
|---|---|---|---|
| Q1 | Performance de disponibilidad y reserva | Alta | ver escenario Q1; es el "escenario de carga del proyecto" de constitución P12 |

```gherkin
Escenario: Q1 — carga sostenida sobre disponibilidad y reserva
  Dado un negocio con 12 profesionales
  Y 3 meses de historial con 8 turnos por profesional por día
  Y la app y Postgres corriendo en Docker Compose local, con el hardware declarado en el README
  Cuando llegan 200 pedidos por segundo durante 5 minutos, con esta mezcla:
    | Pedido                                        | Proporción |
    | Disponibilidad de 1 semana por profesional    | 64%        |
    | Disponibilidad de 1 semana sin profesional    | 16%        |
    | Reserva de un slot ofrecido por disponibilidad | 20%       |
  Entonces el p95 de cada tipo de pedido queda por debajo de PERF_BUDGET_P95_MS
  Y ningún pedido responde 5xx
```

Notas de Q1:
- Decidido por la usuaria (2026-10-27): 200 req/s sostenidos, 12
  profesionales, 8 turnos por profesional por día, horizonte de 1 semana, 3
  meses de historial, 80% lectura y 20% reserva, con la disponibilidad sin
  profesional (PRD A9) dentro de la mezcla (80/20 de las lecturas).
- Es un escenario de **estrés**, no de carga esperada: un negocio real de
  este tamaño recibe unos pocos pedidos por minuto. El README lo presenta
  así.
- Corre contra el Docker Compose local, no contra la demo desplegada (plan
  del proveedor y sus términos de uso).
- Los 3 meses de historial son datos de prueba del script, no una política
  de retención (PRD A30 sigue fuera de alcance).
- [NECESITA ACLARACIÓN: saturación de la agenda. 20% de 200 req/s son 40
  reservas por segundo; la capacidad de una semana de 12 profesionales con
  8 turnos diarios es de unos 500 a 600 turnos, así que la semana se llena
  en unos 15 segundos y, desde ahí, casi toda reserva responde `409
  SLOT_TAKEN`. Opciones: (a) contar `409 SLOT_TAKEN` como respuesta válida,
  medir su p95 igual que el de una reserva confirmada e informar la
  proporción; (b) que las reservas apunten a toda la ventana de reserva del
  negocio y no a la semana consultada (alarga la saturación, no la evita);
  (c) bajar la proporción o la duración. Recomendación de Claude: (a), porque
  el camino del `409` también escribe (intenta insertar y la base lo rechaza)
  y es el que se ve bajo contención real. Decide la usuaria.]
- Parámetros en §9.

## 3. Decisiones

### A1 — Motor de base de datos
Estado: vigente — detalle completo en
[ADR-0001](adr/0001-motor-de-base-de-datos.md) (opciones, matriz ponderada,
sensibilidad y consecuencias).

**Elegido:** PostgreSQL 16 — único de los evaluados que expresa RD-01 como
constraint declarativo del esquema (exclusion constraint sobre
`tstzrange`), con matriz 4,80 contra 3,70 de la siguiente opción.
Decidido por: la usuaria, 2026-10-26. Coincide con la recomendación de
Claude y con la restricción del enunciado.

Descartado: MySQL 8, MongoDB 7, CockroachDB, SQL Server y Oracle — motivos
en el ADR.

### A2 — Estructura interna de los módulos
Estado: vigente — detalle completo en
[ADR-0002](adr/0002-estructura-interna-de-los-modulos.md) (opciones, matriz
ponderada, sensibilidad, reglas de dependencia y consecuencias).

**Elegido:** hexagonal pragmática en todos los módulos: `domain/` (reglas,
admite anotaciones JPA), `application/` (casos de uso y puertos),
`infrastructure/` y `web/` (adaptadores), con la API del módulo en el
paquete raíz. Matriz 4,35 contra 4,20 de Clean estricta; la diferencia
depende del peso del costo frente al dominio sin JPA. Verificado con
jMolecules + ArchUnit desde la iteración 0.
Decidido por: la usuaria, 2026-10-26. Coincide con la recomendación de
Claude.

Descartado: capas clásicas, Clean estricta y estructura mixta — motivos en
el ADR.

### A3 — Modelado del dominio
Estado: vigente — detalle completo en
[ADR-0003](adr/0003-modelado-del-dominio.md) (opciones, matriz ponderada,
sensibilidad y consecuencias).

**Elegido:** orientación a objetos sin DDD táctico: entidades JPA con
comportamiento, value objects como `record`, estados explícitos y las
reglas de constitución P11. jMolecules se usa solo para las capas de A2.
Matriz 4,15 contra 4,05 de DDD táctico liviano; la diferencia depende de
que no demorar el portfolio pese más que el resto (con esfuerzo en 25%,
gana el DDD liviano).
Decidido por: la usuaria, 2026-10-27. Coincide con la recomendación de
Claude.

Descartado: DDD táctico liviano por convención y DDD táctico completo con
jMolecules DDD — motivos en el ADR.

## 9. Parámetros de configuración

| Parámetro | Valor por defecto | Dónde se configura | Notas |
|---|---|---|---|
| URL de conexión a la base | `jdbc:postgresql://localhost:5432/reserva_turnos` solo en el perfil local | Variable de entorno `SPRING_DATASOURCE_URL` | |
| Usuario y contraseña de la base | Sin valor por defecto fuera del perfil local | `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD` | Constitución P9: nunca en el repositorio |
| Versión de la imagen de Postgres | `16` | `docker-compose.yml` y configuración de Testcontainers, leyendo un mismo valor | Constitución P8: igual versión mayor en tests y producción |
| Presupuesto de p95 de Q1 | `300` ms | Variable de entorno `PERF_BUDGET_P95_MS` del script k6 | Constitución P12 |
| Tasa de pedidos de Q1 | `200` req/s | `PERF_LOAD_RPS` del script k6 | Escenario de estrés |
| Duración de Q1 | `5m` | `PERF_LOAD_DURATION` del script k6 | |
| Mezcla de Q1 | `64` / `16` / `20` (% disponibilidad por profesional / sin profesional / reserva) | `PERF_MIX_AVAILABILITY_BY_PROFESSIONAL`, `PERF_MIX_AVAILABILITY_ANY`, `PERF_MIX_BOOKING` del script k6 | Deben sumar 100; el script falla si no |
| Datos de prueba de Q1 | `12` profesionales, `8` turnos por profesional por día, `3` meses de historial, horizonte de `7` días | `PERF_SEED_PROFESSIONALS`, `PERF_SEED_BOOKINGS_PER_DAY`, `PERF_SEED_HISTORY_MONTHS`, `PERF_AVAILABILITY_DAYS` del script de carga | Solo para la prueba de carga |

## 11. Preguntas abiertas
- ¿El proveedor de la demo permite `btree_gist`? — se resuelve al elegir
  dónde desplegar (PRD A28, iteración 6) — decide la usuaria.
- Resto del modo sistema (estilo, componentes y ciclo entre `scheduling`
  y `booking` de PRD A22, outbox, despliegue, atributos de calidad) —
  pendiente hasta cerrar el PRD.
- Resiliencia, a resolver en el modo sistema completo (los timeouts ya son
  constitución P10 v2.4.0; circuit breaker descartado: la única dependencia
  externa además de la base es SMTP y va por el outbox, fuera del request):
  - Política de reintentos del outbox: reintento periódico de publicaciones
    incompletas con backoff y máximo de intentos (Spring Modulith por
    defecto solo las reintenta al reiniciar), métrica o alerta de eventos
    trabados, y deduplicación por evento en `notifications` (la entrega es
    al menos una vez). Parámetros nuevos a §9.
  - Graceful shutdown: `server.shutdown=graceful` con readiness en "no
    listo" durante el drenaje; encaja con P10. Se resuelve con despliegue.
  - Bulkhead: pool de hilos acotado y separado para los listeners de
    `notifications`, para que una cola de emails no quite hilos ni
    conexiones a las reservas.
- Bloqueo optimista (`@Version`) en el turno, para que dos transiciones de
  estado concurrentes (por ejemplo, cerrar `COMPLETED` y cancelar) no se
  pisen: la segunda recibe `409`. El exclusion constraint de P1 no cubre
  este caso. Lo diseña `sdd-dba` en la spec del núcleo de reservas
  (iteración 1); el código de error lo fija esa spec.
- Cotas a la entrada: tamaño máximo de página en agendas, tamaño máximo del
  body y rango máximo de fechas en la consulta de disponibilidad,
  parametrizados. Las fija cada spec que expone el endpoint (iteraciones 3
  y 4).
- Observabilidad, a resolver en el modo sistema completo (lo verificable
  hoy está en constitución P10 v2.5.0: logs JSON con trace id, sin datos
  personales, health checks y timeouts):
  - Métricas de negocio con Micrometer: reservas confirmadas, `409
    SLOT_TAKEN` (contención), `429` del rate limit, reintentos atendidos
    por `Idempotency-Key`, emails fallidos y eventos pendientes del outbox;
    y formato de exposición (por ejemplo `/actuator/prometheus`). Candidato
    a escenarios de calidad `Q<n>`.
  - Origen y propagación del trace id: qué lo genera (Micrometer Tracing,
    OpenTelemetry) y cómo viaja con los eventos del outbox, para unir el
    log de un email fallido con el request de la reserva que lo originó.
  - Latencia en ejecución: histograma por endpoint para vigilar el
    presupuesto de P12 en la demo, no solo con k6.
  - Alertas y dashboards: dependen de dónde se despliegue la demo (PRD A28,
    iteración 6).
- Seguridad, fuera de constitución P9 (v2.6.0):
  - JWT: algoritmo, largo de clave, vencimiento y qué pasa al desactivar un
    usuario (hoy un profesional dado de baja seguiría entrando hasta que
    venza su token). Decisión con alternativas para el modo sistema.
  - Fuerza bruta en `/auth/login`: el rate limit por IP (PRD A26) no frena
    un ataque distribuido contra una sola cuenta; evaluar bloqueo o demora
    por cuenta. Modo sistema.
  - Headers de seguridad: `Referrer-Policy: no-referrer` como mínimo, porque
    el token del link de gestión va en el path y se filtraría por `Referer`;
    además CORS, HTTPS y el motivo para deshabilitar CSRF (JWT sin estado).
    Se resuelven con el despliegue (PRD A28).
  - Escaneo de vulnerabilidades en dependencias (Dependabot, gratuito con
    el repo público en GitHub): se agrega en la spec de esqueleto
    (iteración 0), junto con gitleaks.
  - SQL armado por concatenación de strings: JPA lo evita casi siempre,
    pero una query nativa puede saltearlo. Candidato a regla de P9 o a
    revisión en F7 cuando aparezca la primera query nativa.
