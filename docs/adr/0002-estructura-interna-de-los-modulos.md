# ADR-0002 — Estructura interna de los módulos: hexagonal pragmática

- Estado: aceptado
- Fecha: 2026-10-26
- Decisión de arquitectura: A2 en [`ARCHITECTURE.md`](../ARCHITECTURE.md)

## Contexto

El enunciado fija un monolito modular con cinco módulos (`tenancy`,
`catalog`, `scheduling`, `booking`, `notifications`) verificados con Spring
Modulith, pero no dice cómo se organiza cada módulo por dentro.

El dominio tiene lógica propia que conviene aislar: cálculo de
disponibilidad (tramos, buffer, paso de slots, cambios de horario), ciclo de
estados del turno, políticas del negocio y permisos por rol. Entre los
criterios de evaluación están "el dominio se lee en el código: estados
explícitos, invariantes en las entidades, sin anemia" y "unitarios para
disponibilidad".

Hay tres condiciones que pesan en la decisión:
- Spring Modulith ya define la frontera de cada módulo: el paquete raíz es
  su API y los subpaquetes son internos. La estructura que se elija va
  dentro de cada módulo.
- La persistencia es JPA. Un dominio sin JPA exige un segundo modelo de
  persistencia y mappers por entidad.
- No todos los módulos tienen dominio rico: `catalog` y `tenancy` son
  mayormente altas, bajas y modificaciones.

## Opciones

- **A. Capas clásicas:** `web` → `service` → `repository`, con entidades
  JPA.
- **B. Clean Architecture estricta:** dominio sin frameworks; casos de uso
  y puertos; adaptadores de web y persistencia con modelo propio y
  mappers.
- **C. Hexagonal pragmática:** las reglas viven en el dominio, que admite
  anotaciones JPA; casos de uso en la capa de aplicación; puertos solo donde
  hay algo externo que aislar; misma estructura en todos los módulos.
- **D. Mixta:** B o C en `booking` y `scheduling`, capas clásicas en el
  resto.

Criterios y pesos acordados con la usuaria antes de puntuar (2026-10-26),
escala 1 a 5:

| Criterio (peso) | A. Capas | B. Clean estricta | C. Hexagonal pragmática | D. Mixta |
|---|---|---|---|---|
| Dominio expresivo, sin anemia (30%) | 2 — nada empuja las reglas al dominio; terminan en los `service` | 5 — dominio puro, sin frameworks | 4 — las reglas viven en el dominio; las anotaciones JPA lo condicionan un poco (constructor vacío, mutabilidad) | 4 — rico donde importa; `catalog` queda anémico aunque tiene invariantes |
| Testabilidad unitaria (25%) | 3 — la lógica en `service` con repositorios exige mocks o integración | 5 — dominio testeable sin Spring ni base | 5 — las anotaciones JPA no impiden testear el dominio sin Spring | 5 — igual que C donde está la lógica |
| Verificabilidad de límites (20%) | 3 — ArchUnit verifica capas, pero no protege al dominio de Spring ni de JPA | 5 — jMolecules verifica que el dominio no dependa de nada | 4 — jMolecules verifica capas y que el dominio no use Spring ni web; JPA se permite | 3 — dos estilos, dos juegos de reglas |
| Costo y código repetitivo (15%) | 5 — lo mínimo | 1 — doble modelo y mappers por entidad en cinco módulos | 4 — apenas más que capas: paquetes separados y clases de caso de uso, sin mappers | 4 — no ahorra mucho frente a C |
| Consistencia y lectura (10%) | 5 — conocida por todos | 3 — uniforme, pero la ceremonia confunde en módulos de altas y bajas | 5 — misma estructura en todos, sin ceremonia de más | 2 — quien lee tiene que entender por qué hay dos estilos |
| **Total ponderado** | **3,20** | **4,20** | **4,35** | **3,85** |

Sensibilidad: la diferencia entre B y C es chica y depende de un juicio. Si
"dominio expresivo" sube a 40% y "costo" baja a 5%, gana B (4,60 contra
4,35). La elección de C asume que un dominio libre de JPA no vale el costo
de duplicar cada entidad en cinco módulos.

## Decisión

**Elegido:** C, hexagonal pragmática en todos los módulos. Lo que B agrega
sobre C es un dominio sin anotaciones JPA, y eso compra poco acá: las
anotaciones no impiden los tests unitarios, y el doble modelo con mappers
en cinco módulos se lee como sobreingeniería. C conserva la regla central de
la Clean Architecture: las dependencias apuntan hacia el dominio.
Decidido por: la usuaria, 2026-10-26. Coincide con la recomendación de
Claude.

Estructura de cada módulo:

```
<módulo>/            API del módulo: eventos publicados e interfaces que
                     otros módulos pueden usar (lo único visible afuera)
  domain/            entidades, value objects, estados, invariantes y reglas
  application/       casos de uso y puertos (interfaces hacia lo externo)
  infrastructure/    adaptadores de salida: persistencia JPA, email, reloj
  web/               adaptadores de entrada: controllers, DTOs, errores
```

Reglas de dependencia:
- `domain` no depende de Spring, de `web`, de `application` ni de
  `infrastructure`. Se permite `jakarta.persistence` (anotaciones JPA).
- `application` depende de `domain`; puede usar transacciones y publicación
  de eventos de Spring; no depende de `web` ni de `infrastructure`.
- `web` e `infrastructure` dependen de `application` y `domain`, nunca entre
  sí.
- Otro módulo solo ve la API del paquete raíz (regla de Spring Modulith,
  constitución P4).

## Consecuencias

- Las reglas de dependencia se verifican con jMolecules + ArchUnit desde la
  spec de esqueleto (iteración 0), junto con la verificación de módulos de
  Spring Modulith.
- Un módulo sin lógica externa que aislar puede no tener puertos propios;
  la estructura de carpetas es la misma igual.
- Las entidades del dominio deben proteger sus invariantes aunque JPA
  exija un constructor sin argumentos (por ejemplo, constructor protegido y
  creación por métodos de fábrica).
- Dónde se declara el puerto de repositorio y cómo lo implementa Spring
  Data es un detalle que fija la spec de esqueleto (`D<n>` en
  `DESIGN.md`).
- Si la contaminación de JPA en el dominio molestara en la práctica, el
  camino es pasar módulo por módulo a B, empezando por `booking`; esa
  migración se haría con un ADR nuevo que reemplace a este.

## Alternativas descartadas

A, capas clásicas: no empuja las reglas al dominio y deja la lógica en
servicios que requieren mocks para probarse, justo lo que el enunciado
evalúa. B, Clean estricta: el beneficio sobre C es un dominio sin JPA, a
cambio de duplicar modelo y mappers en cinco módulos. D, mixta: con C casi
tan barata como capas, mezclar dos estilos no ahorra trabajo y suma
explicación.
