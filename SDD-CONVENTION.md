# Método SDD — Spec-Driven Development

Documento de referencia del método de trabajo. Vive a nivel usuario
(`~/.claude/sdd/SDD-METHOD.md`) para que aplique en cualquier proyecto sin
tener que repetir la configuración. Las skills `sdd-*` lo usan como fuente
de verdad; si algo en la práctica lo contradice, gana este documento o lo
actualizamos — no dejamos la divergencia en silencio.

Este documento es la versión generalizada de una convención que nació para
un refactor de proyecto heredado puntual. La lógica del método (spec antes
que código, tests antes que implementación, verificación al cierre) es la
misma para cualquier trabajo de software; lo único que cambia es si hace
falta o no una fase previa de arqueología.

Dos convenciones fijas del método, sin excepción:

- **Los criterios de aceptación se escriben en Gherkin** (`Dado / Cuando /
  Entonces`), no como prosa o checkboxes sueltos. Un criterio que no se
  puede escribir como escenario Gherkin es un criterio ambiguo.
- **La implementación es TDD real**, ciclo rojo-verde-refactor por
  escenario — no "escribo todos los tests y después todo el código". Ver
  §8 F5/F6.

---

## 1. Principio

La fuente de verdad es la spec, no el código. El código es una derivación.

En un **proyecto nuevo** el flujo es directo: no hay código todavía, así que
se especifica y después se construye. En un **proyecto heredado** arranca al
revés: el código ya existe y no hay spec. Por eso hay una fase previa de
arqueología, donde el código es la fuente y la spec es el producto. Recién
cuando lo existente está documentado y congelado con tests, se invierte la
relación y se vuelve al SDD normal.

Regla que sostiene todo el método:

> **Cambio de comportamiento → spec primero, siempre.**
> Si el código se adelanta a la spec tres veces, la spec es ficción y
> volviste a desarrollar como siempre pero con más archivos markdown.

## 2. Dos modos de entrada

| | Modo A — Proyecto nuevo | Modo B — Proyecto heredado |
|---|---|---|
| Punto de partida | No hay código relevante todavía | Ya existe código sin spec |
| Fases previas | FC Constitución + FA Arquitectura | FC Constitución + F1 Arqueología + F2 Baseline + FA Arquitectura |
| Primera spec | `001-<nombre>.md` | `000-baseline.md`, luego `001-<nombre>.md` |
| Skill de arranque | `sdd-init` → `sdd-constitution` → `sdd-prd` → `sdd-architecture` → `sdd-spec` | `sdd-init` → `sdd-constitution` → `sdd-prd` → `sdd-archaeology` → `sdd-baseline` → `sdd-architecture` → `sdd-spec` |

A partir de ahí (F3 en adelante) el ciclo es idéntico en los dos modos.

## 3. Estructura de archivos

```
proyecto/
├── CLAUDE.md                      # reglas de la casa de ESTE proyecto (estable)
├── SDD-CONVENTION.md              # copia de este método, congelada al iniciar
├── docs/
│   ├── CONSTITUTION.md            # principios no negociables del proyecto P<n> (versionada)
│   ├── PRD.md                     # el encargo, pasado en limpio (congelado)
│   ├── PRODUCT.md                 # qué es esto y para quién (estable)
│   ├── AS-IS.md                   # lo heredado, tal cual está hoy (solo modo B)
│   ├── ARCHITECTURE.md            # arquitectura objetivo y decisiones estructurales A<n> (crece)
│   ├── DATA-MODEL.md              # modelo lógico/físico vigente e historial de cambios (crece)
│   ├── DATA-AUDIT.md              # auditoría fechada del esquema heredado (solo modo B, si aplica)
│   ├── DESIGN.md                  # decisiones técnicas y por qué (crece)
│   ├── AI-WORKFLOW.md             # registro de prompts usados y correcciones
│   ├── contracts/                 # contratos de interfaz: OpenAPI, AsyncAPI, ... (si aplica)
│   └── specs/
│       ├── 000-baseline.md        # comportamiento heredado observable (solo modo B, congelado)
│       ├── 001-<nombre>.md        # primera spec
│       ├── 001-<nombre>.arch.md   # arquitectura de esa feature
│       └── 002-<nombre>.md
└── src/
```

### Qué información va en cada archivo

| Pregunta que contesta | Archivo |
|---|---|
| ¿Qué no se negocia en este proyecto? | `docs/CONSTITUTION.md` |
| ¿Qué nos pidieron exactamente? | `docs/PRD.md` |
| ¿Qué comando corre los tests? | `CLAUDE.md` |
| ¿Para qué existe este sistema? | `docs/PRODUCT.md` |
| ¿Cómo está hecho hoy y qué duele? | `docs/AS-IS.md` |
| ¿Cómo está armado el sistema y por qué esa estructura? | `docs/ARCHITECTURE.md` |
| ¿Por qué elegimos X sobre Y (dentro de una feature)? | `docs/DESIGN.md` |
| ¿Qué tablas, columnas e índices hay y por qué consulta? | `docs/DATA-MODEL.md` |
| ¿Qué está mal hoy en la base heredada? | `docs/DATA-AUDIT.md` |
| ¿Qué hace la feature Z, verificable? | `docs/specs/NNN-*.md` |
| ¿Cómo encaja la feature Z en el sistema? | `docs/specs/NNN-*.arch.md` |
| ¿Qué forma exacta tiene la interfaz X? | `docs/contracts/` |

Criterio rápido: si lo vas a repetir en cada prompt → `CLAUDE.md`.
Si es un **por qué** estructural (afecta a varias specs, caro de revertir) →
`ARCHITECTURE.md`; si es local a una spec → `DESIGN.md`. Si es un **qué hace** verificable → spec.

**PRD vs PRODUCT.md:** el PRD es lo que te pidieron, congelado, con la
ambigüedad del enunciado explicitada. `PRODUCT.md` es tu interpretación
operativa, ya con las decisiones tomadas. El PRD no se toca; `PRODUCT.md`
evoluciona.

## 4. El flujo

```
        ┌─────────────────────────────┐
  FC    │  CONSTITUCIÓN               │   principios P<n> → CONSTITUTION.md
        │  qué no se negocia          │   ← versionada, solo cambia por enmienda
        └──────────────┬──────────────┘
                       ↓
        ┌─────────────────────────────┐
  F0    │  PRD                        │   encargo → docs/PRD.md
        │  qué nos pidieron           │   ← se congela, no se toca más
        └──────────────┬──────────────┘
                       ↓
        ┌─────────────────────────────┐
  F1    │  ARQUEOLOGÍA (solo modo B)  │   código → AS-IS.md
        │  entender lo heredado       │
        └──────────────┬──────────────┘
                       ↓
        ┌─────────────────────────────┐
  F2    │  BASELINE (solo modo B)     │   spec 000 + characterization tests
        │  congelar el comportamiento │   ← red de seguridad, quedan VERDES
        └──────────────┬──────────────┘
                       ↓
        ┌─────────────────────────────┐
  FA    │  ARQUITECTURA               │   drivers + opciones + trade-offs
        │  cómo se arma el sistema    │   → ARCHITECTURE.md (decisiones A<n>)
        └──────────────┬──────────────┘
                       ↓
        ┌─────────────────────────────┐
  F3    │  SPECIFICATION              │   docs/specs/NNN-*.md
        │  qué queremos que haga      │   incluye criterios de aceptación
        └──────────────┬──────────────┘
                       ↓
        ┌─────────────────────────────┐
  F3b   │  ARQUITECTURA DE FEATURE    │   NNN-*.arch.md + contratos
        │  cómo encaja en el sistema  │   (si contradice una A<n> → vuelve a FA)
        └──────────────┬──────────────┘
                       ↓
        ┌─────────────────────────────┐
  F4    │  DESIGN / DATOS             │   DESIGN.md (D<n>), DATA-MODEL.md
        │  cómo y por qué             │   con alternativas descartadas
        └──────────────┬──────────────┘
                       ↓
        ┌─────────────────────────────┐
  F4b   │  ANÁLISIS                   │   consistencia entre artefactos
        │  ¿todo cierra entre sí?     │   ← un crítico bloquea F5
        └──────────────┬──────────────┘
                       ↓
        ┌─────────────────────────────┐
 F5+F6  │  TDD — rojo/verde/refactor  │   un escenario Gherkin a la vez
        │  por escenario Gherkin      │   (baseline sigue verde todo el ciclo)
        └──────────────┬──────────────┘
                       ↓
        ┌─────────────────────────────┐
  F7    │  VERIFICATION               │   spec ↔ código, escenario por escenario
        │  ¿qué quedó desalineado?    │
        └──────────────┬──────────────┘
                       │
        ┌──────────────┴──────────────┐
        ↓                             ↓
  todo alineado               hay divergencia
   → siguiente spec (F3)       → volver a F3
                                 (actualizar spec, DESPUÉS código)
```

FC, F0 (y F1/F2 en modo B) se corren una sola vez; la constitución solo
cambia por enmienda versionada. FA corre una vez antes de la
primera spec y se repite solo ante un cambio estructural. F3 a F7 es el ciclo que se
repite por spec.

**La flecha de vuelta no es opcional.** Implementar siempre enseña algo que
la spec no previó. Que F7 devuelva trabajo a F3 es el proceso funcionando,
no fallando.

**Los tests van antes de la implementación.** Si se implementa y después se
escriben los tests, se escriben contra el código que ya existe, no contra la
spec: si el código interpretó mal un requisito, el test hereda el mismo
error y da verde igual. Por eso F5 y F6 no son dos pasos separados en el
tiempo (todos los tests, después todo el código) sino un único ciclo TDD
que se repite escenario por escenario — ver §8.

## 4b. Fase C — Constitución

Objetivo: fijar los principios no negociables **propios de este proyecto**
(seguridad, privacidad, contratos de API, accesibilidad, presupuestos,
licencias, compliance) antes de que una spec los contradiga sin darse
cuenta. Salida: `docs/CONSTITUTION.md`. Skill: `sdd-constitution`.

Cada principio `P<n>` es verificable y dice cómo se verifica (mejor
automatizado; si no, con una instrucción precisa para F7). Entre 5 y 12. No
repite el método ni las reglas de la casa: los referencia.

Precedencia: **constitución > ARCHITECTURE.md > DESIGN.md / DATA-MODEL.md
> specs**. Ante un choque, o se ajusta lo de menor nivel o se enmienda la
constitución (versión semántica, fila en § Enmiendas, con motivo). Una
excepción también es una enmienda. En modo B, las violaciones del código
heredado van en § Deuda conocida; el código nuevo o tocado cumple siempre.

**Gate:** `sdd-verify` chequea en cada cierre de spec los principios que
aplican al código tocado. Un incumplimiento bloquea el cierre igual que un
escenario sin cubrir.

## 5. Fase 0 — PRD

Objetivo: pasar en limpio el encargo tal como te lo dieron, separando lo que
dice de lo que vos estás asumiendo. Salida: `docs/PRD.md`. Skill: `sdd-prd`.

No es un resumen del enunciado. Es una traducción a criterios verificables,
con la ambigüedad **marcada en vez de resuelta**. Lo que el enunciado no
dice es información tan importante como lo que dice: es donde se define el
alcance real de la entrega.

**Gate:** el PRD se congela antes de abrir el código. Si después descubrís
algo que lo contradice, no lo editás en silencio: agregás una sección
`## Cambios` al final con fecha y motivo.

## 6. Fase 1 — Arqueología (solo modo B)

Objetivo: entender lo heredado sin tocar nada. Salida: `docs/AS-IS.md`.
Skill: `sdd-archaeology` (delega la exploración de solo lectura al agente
`sdd-archaeologist`).

No es un resumen bonito del código. Es un mapa con lo que duele marcado.
Conviene hacerlo en dos pasadas: reconocimiento primero, redacción después.
De un tiro sale un resumen genérico.

Regla de oro de esta fase: **todo lo que se afirme lleva archivo y línea.**
Si no se verificó leyendo código, no se escribe.

Si los datos son centrales al sistema, en esta misma fase corre `sdd-dba`
en modo auditoría (agente `sdd-dba-auditor`, solo lectura): sale
`docs/DATA-AUDIT.md`, y el comportamiento de datos observable (cascadas,
triggers, borrados lógicos) alimenta el baseline. Acceder a la base viva
requiere autorización explícita y un usuario de solo lectura.

## 7. Fase 2 — Baseline (solo modo B)

Antes de mover una sola línea, se congela el comportamiento actual.
Skill: `sdd-baseline`.

**Spec 000:** describe el comportamiento observable heredado, sin juicio de
valor. Es el contrato que el trabajo posterior **no puede romper**. Se
escribe una vez y no se toca: si querés cambiar comportamiento, va en una
spec nueva, no acá.

**Characterization tests:** documentan lo que el sistema hace hoy, incluyendo
los bugs. Nacen verdes y tienen que seguir verdes durante todo el trabajo
posterior. Son la red: si uno se pone rojo, rompiste algo.

Criterio de alcance: cubrí los entrypoints y los caminos que vas a tocar.
No apuntes al 100%, apuntá a **dormir tranquilo**.

**Gate:** no se pasa a F3 hasta que la suite de baseline esté verde y
commiteada.

## 7b. Fase A — Arquitectura (los dos modos)

Objetivo: decidir cómo se arma el sistema antes de que las specs lo fijen
de hecho, feature por feature. Salida: `docs/ARCHITECTURE.md`. Skill:
`sdd-architecture`.

Se lleva como el interrogatorio de F3: primero los drivers (restricciones y
atributos de calidad, estos escritos como escenarios Gherkin medibles),
después las decisiones estructurales de a una, cada una con 2-4 opciones
reales, una matriz de trade-offs justificada celda por celda y una
recomendación. Vos decidís. El nivel de rigor (liviano, estándar o formal
tipo ATAM-lite) se elige al arrancar según qué tan crítico es el sistema.

Las decisiones van numeradas `A<n>`, con su "Descartado", igual que en
`DESIGN.md`. La frontera: si revertirla obliga a tocar varias specs o a
migrar datos o infra, es `A<n>`; si se revierte dentro de una spec, es
`D<n>`.

**Gate:** no se arranca la spec `001` sin las decisiones `A<n>` que la
condicionan tomadas. Si una spec posterior choca con la arquitectura, se
vuelve a FA (nueva `A<n>` que reemplaza a la vieja) antes de implementar,
no se rodea la arquitectura en silencio.

Además del modo sistema, la misma skill tiene un **modo feature** que
corre en cada spec (F3b, ver §8).

## 8. Fases 3 a 7 — El ciclo (aplica en los dos modos)

Se repite una vez por spec. Una spec = un cambio acotado, implementable en
una sesión.

### F3 — Specification (skill `sdd-spec`)

Se redacta conversando, no de un tirón. Orden:

1. Volcás el problema en bruto. *"No escribas la spec todavía."*
2. **Interrogatorio:** *"Hacéme las preguntas necesarias para que la spec no
   tenga ambigüedades. De a una, priorizando las que más impactan en el
   diseño."* Esta es la parte de mayor valor del método: son las preguntas
   que ibas a descubrir a mitad de la implementación, cuando corregirlas
   cuesta caro.
3. Recorte de alcance.
4. Redacción.

Los criterios de aceptación se escriben como **escenarios Gherkin**
(`Dado / Cuando / Entonces`), uno por caso — incluyendo los bordes y los
casos negativos, no solo el camino feliz. Un escenario Gherkin bien escrito
**es** el test: el Dado es el setup, el Cuando es la acción bajo prueba, el
Entonces es la aserción. Si no podés escribir el Entonces como una
aserción concreta, el escenario está mal recortado — separalo o
precisalo, no lo dejes en prosa.

```gherkin
Escenario: cancelar una orden que todavía no fue despachada
  Dado una orden en estado PENDIENTE
  Cuando se solicita su cancelación
  Entonces la orden pasa a estado CANCELADA
  Y se emite el evento OrdenCancelada

Escenario: intentar cancelar una orden ya despachada
  Dado una orden en estado DESPACHADA
  Cuando se solicita su cancelación
  Entonces la operación se rechaza con "orden no cancelable"
  Y el estado de la orden no cambia
```

Usá Gherkin en español o inglés según lo que ya use el stack del proyecto
para tests (si hay Cucumber/Behave/SpecFlow configurado con `Given/When/Then`,
seguí ese idioma) — lo que no cambia es la estructura de tres partes.

Si al redactar queda una ambigüedad abierta, se marca inline donde aparece
como `[NECESITA ACLARACIÓN: <pregunta>]`. Antes de mostrar la spec se corre
el checklist de completitud de `sdd-spec`. **Gate:** una spec con marcas o
con ítems del checklist sin pasar es un borrador, no sale de F3.

### F3b — Arquitectura de feature (skill `sdd-architecture`, modo feature)

En **cada** spec, después de aprobarla: qué componentes toca, diagramas de
secuencia, contratos que crea o cambia (en `docs/contracts/`, con su tipo
de cambio: nuevo, compatible o incompatible), impacto en datos y estados,
atributos de calidad afectados y parámetros nuevos. Sale en
`docs/specs/NNN-*.arch.md`, siempre — "sin impacto arquitectónico" también
se escribe y se justifica. Si encajar la feature contradice una `A<n>`, se
vuelve a FA antes de seguir.

Los contratos son la fuente de verdad de las interfaces: el código se
valida contra ellos con tests de contrato, nunca se copian del código al
final.

### F4 — Design (skill `sdd-design`)

Solo si la spec implica una decisión no obvia. Una entrada por decisión en
`DESIGN.md`. Si la spec agrega o cambia algo persistido, además corre
`sdd-dba` (modo diseño): actualiza `DATA-MODEL.md` y deja el plan de
migración que después sigue `sdd-implement` — la skill DBA diseña, no
escribe migraciones. La parte que más rinde es **"Descartado"**: evita que en dos
semanas Claude (o vos) proponga lo que ya rechazaste. Toda ambigüedad
resuelta del PRD termina acá.

### F4b — Análisis de consistencia (skill `sdd-analyze`, agente `sdd-analyzer`)

Antes de escribir código, un agente independiente cruza la spec, su
arquitectura de feature, `ARCHITECTURE.md`, `DATA-MODEL.md`, los contratos,
`DESIGN.md`, la constitución y las specs anteriores: marcas pendientes,
contradicciones, escenarios sin componente, contratos sin escenario,
cambios incompatibles sin versión, deriva de terminología. Clasifica por
severidad. **Gate:** un hallazgo crítico bloquea F5; uno alto se resuelve o
se acepta explícitamente (y queda registrado).

### F5 + F6 — TDD, rojo/verde/refactor (skill `sdd-implement`)

No son dos pasos separados: es un único ciclo que se repite **un escenario
Gherkin a la vez**, solo para los escenarios de la sección "Cambia" de la
spec (los de "Se preserva" ya están cubiertos por baseline).

1. **Rojo.** Tomá un escenario Gherkin — el más simple o el que más
   condiciona el diseño, no los seis a la vez. Escribí el test que lo
   traduce literalmente: Dado → setup, Cuando → acción, Entonces →
   aserción. Corré la suite y confirmá que falla **por la razón correcta**
   (el comportamiento nuevo no existe todavía). Si falla por un error de
   compilación en otra clase, un import roto o un typo, no probaste nada
   todavía — arreglá eso y volvé a confirmar el rojo.
2. **Verde.** Escribí el mínimo código de producción para que ese test
   pase. Mínimo en serio: no adelantes lógica para el próximo escenario
   todavía, aunque la tentación sea resolverlos todos juntos porque "ya que
   estás". Corré la suite completa (no solo el test nuevo). Si un test de
   baseline se puso rojo, **PARÁ y reportá antes de seguir** — no lo
   arregles en silencio ni sigas de largo.
3. **Refactor (opcional).** Con el test en verde como red de seguridad,
   limpiá duplicación u obviedad que haya quedado del paso anterior. Corré
   la suite de nuevo después — el refactor no cambia comportamiento, si
   algo se puso rojo el refactor introdujo un bug, no lo dejes pasar.
4. Repetí desde 1 con el siguiente escenario. Un commit por escenario (o
   por grupo chico de escenarios relacionados) es razonable; mezclar todos
   los escenarios de la spec en un commit gigante pierde la trazabilidad
   que el ciclo da.

Este ciclo es lo que reemplaza el paso a paso genérico: cada "paso chico"
del método **es** un escenario Gherkin, no una unidad arbitraria.

### F7 — Verification (skill `sdd-verify`, agente `sdd-verifier`)

Dos preguntas, siempre las mismas:

```
Andá escenario por escenario de la spec NNN. Para cada uno: qué test lo
cubre y si realmente verifica el Entonces, no solo ejercita el Cuando. Si
alguno no está cubierto o el test no lo verifica de verdad, decímelo en vez
de justificar.
```

```
¿Hay algo en el código que no esté en la spec, o algo en la spec que el
código resuelva distinto? Listá las diferencias.
```

Ante divergencia hay dos salidas legítimas — corregir el código, o
actualizar la spec porque la realidad enseñó algo. Dejarlos desincronizados
no es una opción.

En paralelo, el agente `sdd-complexity-reviewer` revisa la complejidad del
código tocado contra la sección "Volumen y presupuestos" de la spec:
Big-O en variables del dominio, accesos a datos en loops (N+1), cargas sin
cota y estructuras mal elegidas. Lo que una herramienta puede medir
(complejidad ciclomática y cognitiva) va al build como principio de la
constitución; el agente queda para lo que depende del volumen. Un hallazgo
crítico bloquea el cierre; uno mayor se corrige o se acepta con una entrada
en `DESIGN.md`.

## 9. Convenciones operativas

### Numeración

`000` baseline (solo modo B). `001` en adelante, orden de ejecución, sin
renumerar nunca. Nombre: `NNN-verbo-objeto.md` → `003-extraer-pricing-service.md`.

### Commits

Un tipo por commit, nunca mezclados:

```
docs(constitution): v1.0.0 principios iniciales
docs(prd): encargo pasado en limpio
docs(spec): 003 extraer pricing service
test(baseline): characterization de OrderController
feat(003): agregar endpoint de cancelación de orden
refactor(003): mover cálculo de descuentos a PricingService
docs(design): D3 servicio de dominio para pricing
docs(architecture): A2 PostgreSQL como almacén principal
docs(data): modelo para spec 004
docs(arch): 004 arquitectura de feature
```

Regla dura: **un commit no cambia comportamiento y estructura a la vez.**

### Quién escribe qué

| Archivo | Autor |
|---|---|
| `CONSTITUTION.md` | vos decidís cada principio y cada enmienda, Claude interroga y redacta |
| `PRD.md` | Claude redacta del enunciado, vos validás cada asunción |
| `PRODUCT.md` | vos — Claude no sabe para qué querés esto |
| `CLAUDE.md` (del proyecto) | vos — un error acá contamina cada sesión |
| `AS-IS.md` | Claude redacta, vos validás contra el código |
| `ARCHITECTURE.md` | Claude propone opciones y recomienda, vos decidís, Claude redacta |
| `DESIGN.md` | vos decidís, Claude redacta |
| `DATA-MODEL.md`, `DATA-AUDIT.md` | Claude redacta, vos validás contra la base y las migraciones |
| specs | Claude redacta tras el interrogatorio, vos leés entera antes de commitear |
| `NNN-*.arch.md`, `contracts/` | Claude redacta, vos decidís las bifurcaciones y aprobás los cambios de contrato |

Si no la leíste entera, no es tu spec.

### Dónde se hace cada fase

- **Conversación (chat):** F0, F1 (exploración), FA, F3 (interrogatorio y
  redacción), F3b, F4.
- **Con acceso a herramientas de edición (Claude Code):** F1 (lectura del
  repo), F2, F4b, F5, F6, F7.

Mezclarlas es lo que arruina el método: la tentación es implementar
mientras discutís, y ahí el código se adelanta a la spec.

### Dónde vive el registro de trabajo

- `docs/AI-WORKFLOW.md` — qué prompt/skill usaste en cada fase, qué
  devolvió, qué corregiste a mano. Es lo que demuestra criterio ante un
  evaluador o revisor.
- Mensajes de commit — cuando un output entra al repo casi sin tocar.

No mantener un `PROMPTS.md` suelto: se desincroniza de lo que realmente se
corre.

## 10. Herramientas del método (a nivel usuario)

| Fase | Skill | Agente | Sale en |
|---|---|---|---|
| Bootstrap | `sdd-init` | — | estructura del proyecto |
| FC Constitución | `sdd-constitution` | — | `docs/CONSTITUTION.md` |
| F0 PRD | `sdd-prd` | — | `docs/PRD.md` |
| F1 Arqueología | `sdd-archaeology` | `sdd-archaeologist` | `docs/AS-IS.md` |
| F1 Auditoría de datos (opcional) | `sdd-dba` | `sdd-dba-auditor` | `docs/DATA-AUDIT.md` |
| F2 Baseline | `sdd-baseline` | — | `docs/specs/000-baseline.md` + tests |
| FA Arquitectura | `sdd-architecture` | — | `docs/ARCHITECTURE.md` |
| F3 Spec | `sdd-spec` | — | `docs/specs/NNN-*.md` |
| F3b Arquitectura de feature | `sdd-architecture` (modo feature) | — | `docs/specs/NNN-*.arch.md` + `docs/contracts/` |
| F4 Design | `sdd-design` | — | entrada en `docs/DESIGN.md` |
| F4 Datos (si la spec toca el esquema) | `sdd-dba` | — | `docs/DATA-MODEL.md` + plan de migración |
| F4b Análisis | `sdd-analyze` | `sdd-analyzer` | informe de consistencia (gate) |
| F5+F6 TDD | `sdd-implement` | — | tests + código, escenario por escenario |
| F7 Verification | `sdd-verify` | `sdd-verifier` + `sdd-complexity-reviewer` | reporte de divergencias y de complejidad |

Los agentes son de **solo lectura**: exploran o comparan y devuelven un
informe; la skill que los invocó es quien decide qué escribir en disco,
después de que vos lo veas. Esto evita que una exploración termine
editando algo sin que lo hayas mirado, y le da a la verificación una mirada
sin el sesgo de quien implementó.

## 11. Errores frecuentes

| Error | Síntoma | Corrección |
|---|---|---|
| Principio aspiracional | "el código tiene que ser seguro" — nadie puede verificarlo | reescribirlo como regla con verificación concreta |
| Excepción de palabra | "esta vez lo dejamos pasar" | o se cumple o se enmienda la constitución, con versión y motivo |
| Arrancar sin PRD | a mitad del trabajo no sabés si algo estaba pedido | F0 antes de abrir el código |
| Resolver ambigüedad en silencio | asunciones que solo viven en tu cabeza | van en PRD § Ambigüedades |
| Refactorizar/modificar sin baseline (modo B) | "creo que no rompí nada" | F2 es un gate, no una sugerencia |
| Specs demasiado grandes | plan con más de 6 pasos | partir la spec |
| Spec que describe implementación | dice "usar un HashMap" | eso va en DESIGN.md |
| Arquitectura por acumulación | cada spec elige su base de datos o su forma de comunicarse | FA antes de la 001; los cambios estructurales vuelven a FA |
| Spec con ambigüedad resuelta en silencio | el código "interpreta" algo que nadie decidió | marca `[NECESITA ACLARACIÓN]` inline; con marcas no sale de F3 |
| Feature sin arquitectura propia | cada spec encaja como puede y el sistema deriva | `.arch.md` en cada spec, aunque diga "sin impacto" |
| Implementar sin análisis | la contradicción entre spec y modelo aparece en el código | F4b antes de F5, siempre |
| Esquema que cambia sin diseño | la migración se escribe directo en el código, índices "por las dudas" | `sdd-dba` antes de implementar; cada índice con su consulta |
| Editar una migración ya aplicada | checksum roto, entornos desincronizados | siempre una migración nueva |
| Matriz de trade-offs para justificar lo ya elegido | pesos fijados después de puntuar, opciones de relleno | pesos acordados antes, solo opciones reales |
| Arreglar bugs "de paso" | commit que mezcla cambios no relacionados | spec aparte |
| Saltear F7 | specs viejas que nadie lee, código y spec divergen | son documentación, no specs |
| `CLAUDE.md` inflado | pasa de 100 líneas | mover a archivos referenciados |
| Criterios de aceptación en prosa suelta | "tiene que andar bien con órdenes canceladas" no dice qué verificar | reescribir como escenario Gherkin |
| Escribir todos los tests y después todo el código | no es TDD, es "tests primero" de nombre — el diseño ya quedó fijado antes del primer verde | ciclo rojo/verde/refactor por escenario, uno a la vez |
| Refactor que cambia un test para que pase | el refactor "arregla" el test en vez de arreglar el código | si un test se pone rojo en el paso de refactor, el bug está en el código nuevo, no en el test |

## 12. Checklist de arranque

**Modo A — proyecto nuevo:**
- [ ] `CONSTITUTION.md` v1.0.0 con 5-12 principios verificables
- [ ] `PRD.md` redactado, con ambigüedades explicitadas y asunciones tomadas
- [ ] `PRODUCT.md` escrito a mano
- [ ] `CLAUDE.md` del proyecto con stack, estructura, comandos y reglas
- [ ] `ARCHITECTURE.md` con las decisiones `A<n>` que condicionan la primera spec
- [ ] Spec `001` redactada tras el interrogatorio

**Modo B — proyecto heredado, además:**
- [ ] `AS-IS.md` completo: mapa, comportamiento, dolores, rarezas, zonas sin cobertura
- [ ] `CONSTITUTION.md` § Deuda conocida con las violaciones del código heredado
- [ ] Rarezas resueltas: cada una marcada como "preservar" o "corregir en spec NNN"
- [ ] Spec `000-baseline.md` redactada
- [ ] Characterization tests verdes y commiteados
- [ ] `ARCHITECTURE.md` con la arquitectura objetivo y la estrategia de transición
- [ ] Recién ahora: spec `001`
