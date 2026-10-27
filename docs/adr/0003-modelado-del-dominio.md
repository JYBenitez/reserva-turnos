# ADR-0003 — Modelado del dominio: orientación a objetos sin DDD táctico

- Estado: aceptado
- Fecha: 2026-10-27
- Decisión de arquitectura: A3 en [`ARCHITECTURE.md`](../ARCHITECTURE.md)

## Contexto

A2 ([ADR-0002](0002-estructura-interna-de-los-modulos.md)) fija la
estructura hexagonal pragmática de cada módulo y usa jMolecules solo para
verificar las capas. No decide cómo se modela el dominio por dentro. La
constitución v2.3.0 introdujo `@ValueObject` (módulo DDD de jMolecules) en
P11, con lo que adoptaba DDD táctico de forma implícita; la usuaria lo
detectó, P11 se corrigió en v2.3.1 para no depender de DDD, y esta decisión
se evalúa aparte.

Drivers:
- El enunciado evalúa "el dominio se lee en el código: estados explícitos,
  invariantes en las entidades, sin anemia".
- No demorar el portfolio. La usuaria está entre aprender DDD con este
  proyecto o solo usarlo si mejora el dominio; si el esfuerzo es mucho, lo
  aprende en un proyecto aparte.
- La persistencia es JPA dentro del dominio (A2).
- La no superposición de turnos la garantiza la base (constitución P1), no
  una invariante en memoria.
- Entre módulos solo se ve la API del paquete raíz (constitución P4, Spring
  Modulith), así que las referencias entre módulos ya van por id.
- `catalog` y `tenancy` son mayormente altas, bajas y modificaciones.

El DDD estratégico (bounded contexts) queda fuera: los cinco módulos de
Spring Modulith, impuestos por el enunciado, ya cumplen ese papel.

## Opciones

- **A. Orientación a objetos sin DDD:** entidades JPA con comportamiento,
  value objects como `record`, estados explícitos y las reglas de P11
  (v2.3.1). Sin agregados ni vocabulario DDD.
- **B. DDD táctico liviano, por convención:** reglas centrales de agregados
  (una raíz protege las invariantes, referencia a otro agregado solo por id,
  una transacción modifica un solo agregado) en `booking` y `scheduling`,
  documentadas y revisadas en F7, sin jMolecules DDD. `catalog` y `tenancy`
  como en A.
- **C. DDD táctico completo con jMolecules DDD:** `@AggregateRoot`,
  `@Entity`, `@ValueObject`, `@Identity`, `Association<>` entre agregados,
  reglas DDD de jMolecules en ArchUnit e integración con JPA (plugin de
  ByteBuddy), en los cinco módulos.

Criterios y pesos acordados con la usuaria antes de puntuar (2026-10-27),
escala 1 a 5:

| Criterio (peso) | A. OOP sin DDD | B. DDD liviano | C. DDD completo |
|---|---|---|---|
| Esfuerzo y demora del portfolio (35%) | 5 — ya definido en P11, nada que aprender ni configurar | 4 — tres reglas en dos módulos, sin librería; el costo es aprender a recortar agregados | 2 — DDD, jMolecules DDD y plugin de ByteBuddy, con ceremonia en cinco módulos |
| Dominio expresivo (30%) | 4 — invariantes en entidades, value objects y estados explícitos; sin límite de consistencia, un caso de uso puede repartir reglas entre entidades | 5 — suma ese límite donde está la lógica rica | 4 — rico en `booking`, pero en `catalog` y `tenancy` la ceremonia se lee como sobreingeniería (KISS, P11) |
| Verificabilidad (15%) | 4 — ArchUnit de P11 cubre encapsulamiento e inmutabilidad; no hay reglas de agregado que verificar | 3 — "una transacción, un agregado" no se chequea con ArchUnit, queda a revisión F7 | 5 — `JMoleculesDddRules` verifica referencias entre agregados e identidades |
| Encaje con A2, JPA y Modulith (10%) | 5 — es lo que A2 supone | 4 — referencia por id entre módulos ya la impone P4; el DDD clásico pondría la no superposición en un agregado "Agenda", pero P1 la deja en la base, así que el agregado es `Turno` y esa invariante queda afuera | 3 — el plugin toca el build y JPA, `Association<>` exige converters, misma tensión con P1 |
| Aprendizaje de DDD (10%) | 1 — no se practica | 3 — lo central sin el tooling | 5 — completo |
| **Total ponderado** | **4,15** | **4,05** | **3,45** |

Sensibilidad: A y B quedan casi empatadas. Con esfuerzo en 25% y
aprendizaje en 20%, gana B (3,95 contra 3,75); con esfuerzo en 25% y
dominio expresivo en 40%, también gana B (4,15 contra 4,05). A gana solo
mientras no demorar el portfolio pese más que el resto. C queda última con
cualquier peso razonable.

## Decisión

**Elegido:** A, orientación a objetos sin DDD táctico. Lo que B aporta acá
es menor de lo que parece: la invariante central (no superposición) ya la
garantiza la base por P1, y la referencia por id entre módulos ya la impone
Spring Modulith por P4; lo que queda, los límites de consistencia dentro de
`booking`, no justifica el tiempo de aprendizaje frente al objetivo de no
demorar el portfolio. DDD se practica en un proyecto aparte.
Decidido por: la usuaria, 2026-10-27. Coincide con la recomendación de
Claude.

## Consecuencias

- El dominio se modela con las reglas de orientación a objetos de la
  constitución P11 (encapsulamiento, value objects inmutables, polimorfismo
  y herencia acotada) y la guía de `CLAUDE.md` del proyecto (dominio rico,
  tell don't ask, Demeter, objetos válidos al nacer).
- jMolecules se usa solo para verificar capas (A2). No se agrega el módulo
  DDD de jMolecules ni su integración con JPA.
- Specs, código y documentos no usan vocabulario de DDD táctico
  (agregado, raíz de agregado, repositorio por agregado) como si fuera una
  convención del proyecto. "Entidad" y "value object" se usan en su sentido
  de orientación a objetos.
- Sin límite de consistencia formal, cada caso de uso que modifica más de
  una entidad lo hace dentro de una transacción de `application/`, y las
  reglas que involucran a varias entidades viven en una de ellas o en un
  servicio de dominio de `domain/`, no en el caso de uso (guía "dominio
  rico" de `CLAUDE.md`).
- Pasar a B más adelante implica refactorizar las relaciones entre
  entidades de `booking`; es barato antes de la iteración 1 y más caro
  después. Se haría con un ADR nuevo que reemplace a este.

## Alternativas descartadas

B, DDD táctico liviano: mejora el dominio poco más que A, porque P1 y P4 ya
cubren la invariante central y las referencias entre módulos, y su costo es
aprender a recortar agregados en un proyecto que no debe demorarse. C, DDD
táctico completo con jMolecules: el mayor esfuerzo de las tres, ceremonia
en módulos de altas y bajas que choca con KISS, y fricción con JPA y el
build.
