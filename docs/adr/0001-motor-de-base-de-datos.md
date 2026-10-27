# ADR-0001 — Motor de base de datos: PostgreSQL 16

- Estado: aceptado
- Fecha: 2026-10-26
- Decisión de arquitectura: A1 en [`ARCHITECTURE.md`](../ARCHITECTURE.md)

## Contexto

La regla central del sistema es que un profesional nunca tenga dos turnos
superpuestos, aunque lleguen cientos de pedidos simultáneos por el mismo
horario. El enunciado exige que esa garantía viva en la base de datos y no
en un chequeo previo en código (RD-01), y que todo instante se persista en
UTC y se convierta con la zona horaria del negocio (RD-02).

El enunciado ya impone PostgreSQL 16. Este ADR analiza la elección como si
no estuviera impuesta, para dejar explícito por qué se habría elegido
igual y qué se descartó.

## Opciones

Se evaluaron PostgreSQL 16, MySQL 8, MongoDB 7 y CockroachDB.

No entran en la matriz: SQL Server y Oracle, que para garantizar RD-01
tienen las mismas limitaciones que MySQL y suman costo de licencia en un
proyecto open source de portfolio.

Criterios y pesos acordados con la usuaria antes de puntuar (2026-10-26), escala 1 a 5:

| Criterio (peso) | PostgreSQL 16 | MySQL 8 | MongoDB 7 | CockroachDB |
|---|---|---|---|---|
| Garantía de no superposición en la base, RD-01 (40%) | 5 — exclusion constraint sobre `tstzrange` (`EXCLUDE USING gist (professional_id WITH =, occupied WITH &&) WHERE status = 'CONFIRMED'`): declarativo, cubre duración + buffer variables sin lógica extra | 3 — sin exclusion constraint; la garantía en la base exige una tabla de bloques de 5 min con índice único por profesional: funciona, pero multiplica filas y reservar/reprogramar opera sobre N filas | 2 — el mismo truco de bloques con índice único, más transacciones multidocumento que requieren replica set y reintentos | 3 — sin exclusion constraint ni tipos de rango; serializable por defecto, así que "consultar y luego insertar" es seguro con reintentos, pero la regla vive en la query y no en el esquema |
| Encaje con el stack: JPA, Flyway, Testcontainers, outbox de Spring Modulith (20%) | 4 — soporte de primera en todo; único roce: mapear `tstzrange` en Hibernate (tipo custom o columnas inicio/fin con rango generado) | 5 — soporte de primera sin tipos especiales | 2 — fuera de Spring Data JPA y de Flyway (Spring Data MongoDB, Mongock); contradice el stack del enunciado | 3 — compatible con el protocolo de Postgres y con Flyway/Hibernate, pero el registro de eventos de Modulith y Testcontainers no lo tienen como caso principal |
| Costo y operación de la demo (15%) | 5 — imagen oficial para Docker Compose; planes gratuitos administrados en varios proveedores | 5 — idem | 3 — local necesita replica set para transacciones (compose más complejo); plan gratuito administrado disponible | 3 — corre en un solo nodo local; plan administrado gratuito, pero menos conocimiento operativo difundido |
| Evolución a la etapa 2: aislamiento entre negocios y escala (15%) | 5 — Row Level Security nativo (el extra sugerido como segunda barrera); réplicas de lectura alcanzan para el volumen de un MVP | 3 — sin RLS: el aislamiento queda solo en la aplicación | 3 — sin RLS; escala horizontal nativa, que el MVP no necesita | 4 — escala horizontal y multirregión nativas; RLS menos maduro que en Postgres (verificar en la versión elegida) |
| Tiempo y zonas horarias, RD-02 (10%) | 5 — `timestamptz`, tipos de rango y operadores de intervalo | 3 — `DATETIME` sin zona, `TIMESTAMP` limitado a 2038: UTC queda a cargo de la app | 3 — fechas en UTC, sin rangos ni zona | 4 — `timestamptz`, sin tipos de rango |
| **Total ponderado** | **4,80** | **3,70** | **2,40** | **3,25** |

Sensibilidad: el peso más discutible es RD-01 (40%). Bajándolo a 30% y
pasando esos 10 puntos al encaje con el stack, que es donde MySQL gana,
queda PostgreSQL 4,70 contra MySQL 3,90. Con pesos iguales, 4,80 contra
3,80. La ganadora no cambia: la ventaja de Postgres no depende de cómo se
reparta el peso.

## Decisión

**Elegido:** PostgreSQL 16 — es el único de los evaluados que expresa la
regla central (RD-01) como constraint declarativo del esquema, y además
encaja con todo el stack. La restricción del enunciado y el análisis
coinciden.
Decidido por: la usuaria, 2026-10-26. Coincide con la recomendación de
Claude.

## Consecuencias

- Se requiere la extensión `btree_gist` para combinar igualdad
  (`professional_id`) y superposición de rangos en el mismo constraint.
  Esta extensión viene con Postgres; hay que verificar que el proveedor
  administrado de la demo la permita (pregunta abierta en `ARCHITECTURE.md` § 11).
- La violación del constraint (SQLSTATE `23P01`, `exclusion_violation`) se
  traduce a `409 SLOT_TAKEN` (constitución P1).
- Cómo se mapea `tstzrange` en JPA es una decisión local de la spec del
  núcleo de reservas (`D<n>` en `DESIGN.md`).

## Alternativas descartadas

MySQL 8 (sin exclusion constraint: la garantía en la base exige
una tabla de bloques que multiplica filas y complica reprogramar; sin RLS
para la etapa 2); MongoDB 7 (modelo relacional forzado a documentos y fuera
del stack JPA/Flyway del enunciado); CockroachDB (resuelve una escala
distribuida que el MVP no tiene, al precio de sacar la regla del esquema y
de reintentos obligatorios); SQL Server y Oracle (mismas limitaciones que
MySQL frente a RD-01, más costo de licencia).
