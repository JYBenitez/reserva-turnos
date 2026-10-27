# reserva-turnos

Backend de un MVP de reserva de turnos online para negocios de belleza,
bienestar y salud. Monolito modular. El MVP sirve a un solo negocio con el
esquema preparado para multi-tenancy (etapa 2): ver `docs/PRD.md` A32 y
constitución P3.

## Stack
- Java 21, Spring Boot 3 (Web, Data JPA, Security), Spring Modulith
- PostgreSQL 16, migraciones con Flyway (`src/main/resources/db/migration`)
- Maven con wrapper (`./mvnw`)
- Tests: JUnit 5, Testcontainers (Postgres real, sin mocks de la base),
  verificación de módulos con Spring Modulith
- Entorno local: Docker Compose (app, Postgres, Mailpit)

## Comandos
- Tests unitarios: `./mvnw test`
- Build completo con tests de integración y verificación de módulos: `./mvnw verify`
- Levantar todo: `docker compose up`

## Método de trabajo
Spec-Driven Development: ver `SDD-CONVENTION.md`. Documentación en `docs/`.
Las migraciones Flyway ya commiteadas no se editan: se agrega una nueva.

## Tests
Lo verificable está en la constitución (P8: Postgres real, trazabilidad con
los escenarios, dobles solo en los bordes, determinismo). Además:
- Unitarios: clases `*Test`, corren con Surefire en `./mvnw test`, sin
  contexto de Spring ni Docker; cubren `domain/` y los casos de uso con
  dobles de los puertos.
- Integración: clases `*IT`, corren con Failsafe en `./mvnw verify`, con
  Testcontainers; cubren persistencia, web, seguridad y eventos.
- Un comportamiento por test, con el Dado / Cuando / Entonces visible en el
  cuerpo (bloques separados o comentarios `// dado`, `// cuando`,
  `// entonces`).
- Datos de prueba con builders que solo explicitan lo que el test mira; el
  resto con valores por defecto válidos.
- Aserciones con AssertJ; un fallo tiene que explicar qué se esperaba sin
  abrir el código.
- Nombres de método que describen el comportamiento; el `@DisplayName`
  lleva la referencia al escenario (P8).

## Estilo de código
Lo verificable está en la constitución (P11: complejidad, duplicación,
diseño de clases, nombres del dominio, encapsulamiento, value objects
inmutables, polimorfismo y herencia acotada). Además, al escribir código:
- SOLID completo: una responsabilidad por clase, extender sin modificar,
  subtipos intercambiables, interfaces chicas y específicas, depender de
  abstracciones solo donde hay algo que aislar (`ARCHITECTURE.md` A2).
- KISS: la solución más simple que cumple la spec. Un patrón de diseño se
  aplica cuando resuelve un problema presente, no por anticipación.
- DRY dentro de cada módulo; entre módulos, preferir una duplicación menor
  a un módulo común que los acople.
- Preferir composición sobre herencia.
- Orientación a objetos:
  - Dominio rico, no anémico: las invariantes y las transiciones de estado
    viven en las entidades (constructor, fábrica estática,
    métodos de negocio); los casos de uso de `application/` orquestan, no
    deciden reglas.
  - Tell, don't ask: pedirle al objeto que haga algo (`turno.cancelar(...)`)
    en vez de leer su estado y decidir afuera.
  - Ley de Demeter: hablar con los colaboradores directos, sin cadenas
    `a.getB().getC().hacer()`.
  - Un objeto nace válido: si no se puede construir en un estado
    consistente, la construcción falla; nada de objetos a medio armar.
  - No exponer colecciones internas mutables: devolver vistas no
    modificables o copias.
- Nombres que expresan intención y usan el lenguaje del dominio; métodos
  cortos que se leen de arriba abajo; comentarios solo para el porqué, no
  para el qué.
