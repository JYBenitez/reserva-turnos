# Architecture Decision Records

Una decisión por archivo, numerados `NNNN-<titulo>.md`. Cada ADR tiene el
análisis completo: contexto, opciones con su matriz de trade-offs,
decisión, consecuencias y alternativas descartadas. `ARCHITECTURE.md`
(decisiones `A<n>`) y `DESIGN.md` (decisiones `D<n>`) resumen la decisión y
enlazan su ADR, sin duplicar el análisis.

Un ADR aceptado no se reescribe: si la decisión cambia, se agrega uno nuevo
que lo reemplaza y el viejo pasa a estado "reemplazado por ADR-NNNN".

| ADR | Decisión | Estado | Referencia |
|---|---|---|---|
| [0001](0001-motor-de-base-de-datos.md) | Motor de base de datos: PostgreSQL 16 | aceptado | A1 |
| [0002](0002-estructura-interna-de-los-modulos.md) | Estructura interna de los módulos: hexagonal pragmática | aceptado | A2 |
| [0003](0003-modelado-del-dominio.md) | Modelado del dominio: orientación a objetos sin DDD táctico | aceptado | A3 |

## Pendientes que exige el enunciado
- Monolito modular.
- Estrategia anti doble-booking (se apoya en ADR-0001).
- Outbox para notificaciones.
- Alcance: MVP de un solo negocio preparado para multi-tenancy (PRD A32).

## Pendientes por desvíos del modelo o la API del enunciado
- Estado `NO_SHOW` con cierre manual de turnos (PRD A7) y rol de recepción
  con su endpoint de reserva desde administración (PRD A34).
- Endpoint de reprogramación desde administración (PRD A12).
- Endpoint de inicialización del admin con token (PRD A3, A33).
