# Arquitectura de Mi Quetzal

## Decisión y estado actual

La aplicación utiliza Flutter/Dart para Android, con soporte web para desarrollar y comprobar la interfaz sin Android Studio. Se adopta MVVM. Están implementados cuentas editables, crédito GTQ/USD en una tarjeta, bancos Monetario/Ahorro, débito vinculado, compras/gastos, ingresos, transferencias, pagos de tarjeta, devoluciones vinculadas, filtros, categorías y resumen mensual por moneda, con persistencia SQLite y tema azul/rojo. Planificación e importación siguen pendientes.

El entorno revisado utiliza Flutter 3.47.0 y Dart 3.13.0. `pubspec.yaml` declara Dart `^3.13.0`. Estas versiones describen la revisión inicial y no autorizan actualizaciones automáticas.

## Responsabilidades

| Componente | Responsabilidad | Dependencias |
| --- | --- | --- |
| View | Presentar estado, componer widgets y recoger acciones. | Su ViewModel y widgets compartidos. |
| ViewModel | Exponer estado de pantalla, validar entradas y coordinar operaciones. | Interfaces de repositorio y modelos/reglas. |
| Model y reglas de dominio | Representar entidades y aplicar reglas financieras reutilizables. | Dart, sin widgets, SQL ni plugins. |
| Repository | Fuente de verdad, transformación de datos y operaciones consistentes. | Modelos, reglas y servicios de datos. |
| Service | Acceso a base local, archivos o plataforma. | APIs y plugins específicos. |

La View invoca acciones del ViewModel y observa su estado. El ViewModel consulta repositorios y estos utilizan servicios. Los resultados regresan como modelos y estado de presentación. Ningún servicio necesita conocer una pantalla.

Los cambios sobre varias cuentas se realizan en una transacción desde datos. La View no actualiza saldos por separado. Las reglas compartidas pertenecen al dominio y no se copian en cada pantalla.

## Organización prevista

Crear las rutas conforme se implementa cada módulo, sin añadir carpetas vacías.

Implementado en este incremento:

- `main.dart` compone una `LocalDatabase` compartida por `SqliteAccountRepository` y `SqliteMovementRepository`, inyectados en `MiQuetzalApp`.
- `app/navigation/` contiene `AppSection`, `AppShellViewModel` y `AppShell`. El ViewModel conserva la sección seleccionada y notifica sus cambios.
- `ui/accounts/` contiene listado, formularios de cuenta/débito y `AccountsViewModel`, que recibe `AccountRepository`. Coordina carga, alta, vinculación de tarjetas, errores y bloqueo de envíos repetidos. Las vistas solo recopilan entradas y representan el estado.
- `domain/models/` contiene dinero, cuentas, débito, movimientos, categorías, filtros, instantáneas y `MonthlySummary`. `domain/rules/movement_rules.dart` centraliza validaciones y efectos de cada operación, sin Flutter ni SQL.
- `ui/movements/` contiene listado, formulario, filtros y `MovementsViewModel`, que recibe `MovementRepository`. Maneja carga, cuentas/tarjetas compatibles, validación, guardado, filtros y errores.
- `data/repositories/` contiene contratos y repositorios SQLite. `MovementRepository` coordina altas de movimientos/categorías y asignación de categoría a un ingreso/gasto existente, devolviendo instantáneas consistentes tras el commit.
- `data/services/` abre la base, activa claves foráneas y aplica migraciones versionadas; selecciona la fábrica nativa/web por importación condicional.
- `ui/categories/` presenta alta de categorías y clasificación de operaciones existentes, usando el estado compartido de `MovementsViewModel`.
- `ui/home/` presenta el resumen mensual proyectado por `MovementsViewModel`, con selección de mes independiente de los filtros de historial. `ui/planning/` conserva su presentación de funciones pendientes.
- `ui/core/` reúne el contenedor desplazable y la presentación de funciones pendientes.
- `web/` permite ejecutar el mismo código de interfaz en Chrome o Edge.

El estado de navegación es efímero y comienza en Inicio en cada arranque. En Cuentas, el acceso rápido abre «Nueva cuenta». En las demás secciones, «Registrar» abre el formulario de movimientos o conduce a Cuentas si no hay ninguna. Tras crear una cuenta se recarga la instantánea de movimientos; tras guardar un movimiento se recargan las cuentas. Los formularios no se pueden cerrar durante una escritura y conservan los datos si falla.

| Ruta | Contenido previsto |
| --- | --- |
| `lib/main.dart` | Entrada de la aplicación. |
| `lib/app/` | App, tema, navegación y composición de dependencias. |
| `lib/domain/models/` | Account, Card, Money, Movement y Category. |
| `lib/domain/rules/` | Reglas de saldos, deudas, transferencias y clasificación. |
| `lib/data/repositories/` | Contratos e implementaciones de acceso a datos. |
| `lib/data/services/` | Base local, lectura de archivos e integraciones. |
| `lib/ui/home/` | View, ViewModel y widgets de Inicio. |
| `lib/ui/movements/` | View, ViewModel y widgets de Movimientos. |
| `lib/ui/accounts/` | View, ViewModel y widgets de Cuentas. |
| `lib/ui/planning/` | View, ViewModel y widgets de Planificación. |
| `lib/ui/imports/` | Selección, vista previa, validación e importación. |
| `lib/ui/core/` | Componentes reutilizables. |
| `test/` | Pruebas de dominio, repositorios y módulos. |

## Estado y dependencias

Comenzar con `ChangeNotifier` y herramientas de escucha del SDK. Recibir dependencias por constructor. No introducir frameworks de estado, service locators o generación de código por anticipación: una necesidad concreta puede justificar una decisión posterior documentada.

Cada ViewModel expone carga, vacío, datos y error. La View no interpreta excepciones SQL ni convierte archivos. Usar identificadores estables para entidades y operaciones; nombres visibles y últimos cuatro dígitos no son claves primarias.

## Persistencia y datos

SQLite está implementado para cuentas y movimientos mediante `sqflite` en Android. La adaptación web `sqflite_common_ffi_web` persiste en IndexedDB y es experimental; requiere generar `sqlite3.wasm` y `sqflite_sw.js` mediante `tool/prepare_web.ps1`. Sus archivos generados no se versionan. En desarrollo se mantiene el puerto 5353 para conservar el origen del almacenamiento. No hay sincronización entre plataformas.

`LocalDatabase` conserva una sola apertura y permite reintentar tras un fallo. Los esquemas 1, 2 y 3 añaden cuentas, movimientos y débito. El esquema 4 añade `categories` y `movements.category_id`, opcional; las operaciones anteriores conservan categoría nula. No hay datos de categorías preinstalados ni clasificación automática. Claves foráneas y disparadores protegen referencias, banco/tarjeta y compatibilidad categoría/operación. El tipo de una categoría usada no se puede alterar mediante SQL para reinterpretar sus movimientos. `onCreate` y `onUpgrade` ejecutan migraciones transaccionales; un downgrade falla sin borrar la base. No hay reparación ni restauración de bases dañadas.

Una transferencia o pago es una sola fila con dos referencias de cuenta y una identidad común. `SqliteMovementRepository` lee el estado, valida la operación, inserta la fila y reconstruye `LedgerSnapshot` antes del commit, usando solo el objeto transacción. Ante error se revierte la operación completa. Los repositorios comparten `ledger_reader.dart` para obtener cuentas e historial consistentes. No se almacenan saldos actuales duplicados en SQL.

`LedgerSnapshot` ordena por fecha y luego identidad de registro, calcula efectos con `MovementRules` y acumula saldos por par `(accountId, currency)`. Conserva `currentBalance` para la moneda principal y `secondaryCurrentBalance` para la segunda moneda opcional de crédito. Se mantienen aperturas y monedas independientes, sin convertir ni sumar GTQ/USD. Efectivo nunca puede quedar negativo, incluso con movimientos retroactivos; banco admite sobregiro. Crédito puede quedar con saldo a favor en una moneda sin afectar la otra. La pantalla muestra el importe a favor como positivo con su etiqueta.

Las compras con fondos reducen saldo; con crédito aumentan deuda. Los ingresos solo se aplican a efectivo/banco. Transferencias y pagos no se clasifican como ingreso ni gasto. Los pagos exigen origen de fondos y destino de crédito; las transferencias excluyen crédito. Cada cuenta involucrada debe usar la moneda de la operación y tener apertura no posterior a ella. Al registrar se rechazan fechas futuras. No se implementan conversiones ni pagos de origen desconocido en este formulario.

`AccountDetails` representa alias, tipo efectivo/banco/crédito, apertura principal, moneda y fecha. Banco admite `BankAccountType.monetary/savings`. Crédito admite una segunda apertura en la otra moneda y límites opcionales para cada una; una deuda superior al límite no se rechaza. `openingBalanceFor` permite validar qué monedas están registradas. Una segunda apertura nula se distingue de cero; no se inventa al migrar. La fecha de apertura es común a ambas monedas de una tarjeta. `DebitCardDetails` contiene alias, cuenta bancaria y últimos cuatro opcionales; no define saldo ni moneda. `LedgerSnapshot` conserva las tarjetas aparte de las cuentas y valida sus vínculos. Una compra con débito reduce el saldo bancario una vez.

`AccountRepository.updateAccount` conserva identidad y usa `AccountRules` para impedir cambiar tipo general, moneda principal o quitar una moneda con movimientos. Actualiza la apertura y reconstruye el historial dentro de la transacción; una fecha incompatible, exceso de rango o efectivo negativo revierte toda la edición. El saldo actual se recalcula sin modificar filas de movimientos. `updateDebitCard` permite cambiar alias/últimos cuatro y valida el banco; una tarjeta usada en compras conserva su banco vinculado. Views reutilizan los formularios de alta con datos precargados y `AccountsViewModel.saveAccount/saveDebitCard`; muestran errores y bloquean navegación/envíos durante la escritura. Tras guardar se recarga el ViewModel de movimientos y su resumen.

El esquema 6 añade a `accounts` las columnas opcionales `bank_account_type`, `secondary_opening_minor` y `secondary_credit_limit_minor`, con restricciones SQL. La segunda moneda es la opuesta a la principal (solo GTQ/USD). No modifica identidades ni movimientos existentes; conserva nulos para datos aún no registrados. Las migraciones son transaccionales y se comprueban también en SQLite web.

La pantalla Cuentas agrupa crédito, débito, cuentas bancarias y efectivo. Usa el mismo componente visual para todas las tarjetas, con icono, alias, tipo, saldo y edición. Crédito utiliza «Saldo actual» por moneda o «Saldo a favor», conservando el significado de deuda del modelo. Crédito, débito y bancos ocultan apertura y fecha; se conservan en formularios y dominio. Débito muestra el saldo de su banco sin duplicar fondos. Las tarjetas muestran entidad financiera y terminación cuando están registradas. El formulario de compras permite escoger la moneda de una tarjeta dual. Los pagos usan la moneda del banco de origen y ofrecen tarjetas que tengan esa moneda registrada, aunque sea su segunda moneda. Las devoluciones toman la moneda de la compra original.

El esquema 7 crea `financial_institutions` y agrega referencias opcionales desde cuentas y débito, protegidas por claves foráneas. Añade `accounts.bank_last_four` para la terminación bancaria sin alterar el CHECK histórico de `last_four` de crédito. `AccountDetails.lastFour` expone ambos casos; solo admite cuatro dígitos para banco/crédito, y no almacena números completos. La migración conserva nulos hasta que el usuario complete los datos; no deduce entidades a partir de alias.

`FinancialInstitutionDetails` valida el nombre del catálogo. `LedgerSnapshot` conserva las entidades aparte de las categorías y valida sus referencias. `MovementRepository.createFinancialInstitution` devuelve una instantánea tras una escritura transaccional; `AccountsViewModel` carga el catálogo mediante `AccountRepository` para los formularios. Categorías incluye una sección de alta/listado de entidades independiente de las categorías. Al cerrar esa pantalla se recarga Cuentas para actualizar los selectores. En débito una entidad explícita tiene prioridad; si no existe se presenta la del banco vinculado. Es metadata de identificación, sin efectos monetarios.

Movimientos presenta un único bloque tipo estado de cuenta, con filas de descripción, monto y fecha, adaptadas al ancho disponible. «?» o pulsar la fila abre `MovementDetailView`, que observa el ViewModel compartido y consulta el movimiento actual por su id. El detalle presenta cuentas, terminaciones, entidades, categoría y relaciones de débito/devolución. Las acciones de categorizar/devolver se ejecutan desde ahí con los formularios existentes; al volver se actualiza el detalle sin perder los filtros del listado. La consulta de detalle es de solo lectura.

`CategoryDetails` define nombre y uso ingreso/gasto; no es un tipo de operación. Las categorías son opcionales y solo compatibles con ese uso. `assignCategory` valida y actualiza únicamente `category_id`, conservando identidad, descripción, fecha, cuentas e importe. Se permite desasignar y tener nombres repetidos con identidades distintas. Transferencias y pagos no admiten categoría.

El esquema 5 reconstruye `movements` transaccionalmente para ampliar su CHECK de tipos y añadir `original_movement_id`, con clave foránea a la propia tabla. Conserva las filas anteriores, sus ids, secuencia autoincremental, vínculos, índices y disparadores. Comprueba las claves foráneas antes del commit. Nuevos disparadores validan cuenta, moneda, fecha, tipo original e importe acumulado de devoluciones; impiden cambiar los datos financieros de una compra ya devuelta y permiten categorizarla. Un fallo tardío revierte tabla, disparadores, secuencia y versión.

`MovementType.refund` requiere una compra/gasto original existente, con la misma cuenta/moneda y fecha no anterior a la compra ni posterior a hoy. La suma de devoluciones no puede superar su importe. `MovementRules` valida el vínculo y centraliza el pendiente y la reversión; `LedgerSnapshot` valida en orden cronológico con los movimientos ya procesados. Devuelve fondos en efectivo/banco o reduce deuda de crédito, permitiendo saldo a favor si ya estaba pagado. No altera ni borra la compra ni sus pagos. La categoría se deriva de la compra original sin copiarla, evitando asignaciones desactualizadas al recategorizar. La tarjeta de débito se conserva en la compra.

El detalle de un gasto ofrece «Devolver» cuando tiene pendiente positivo. `CreateRefundView` recoge importe, descripción y fecha; `MovementsViewModel.refundPurchase` toma cuenta y moneda de la compra. Usa el mismo contrato transaccional `createMovement`; la validación se repite en el repositorio dentro de la transacción para proteger escrituras concurrentes. No se permite cerrar ni reenviar mientras guarda. Las devoluciones aparecen como operaciones separadas con referencia a su compra en el detalle, y recargan las cuentas tras guardar.

`MovementFilter` aplica descripción literal, cuenta (origen o contraparte), operación, moneda, categoría y fechas inclusivas. «Sin categoría» selecciona ingresos/gastos no clasificados y sus devoluciones; estas usan la categoría actual de la compra. Filtra la instantánea completa sin escribir datos ni afectar saldos. Los criterios son efímeros, se conservan al navegar/recargar y se pueden limpiar. No hay paginación.

`MonthlySummary` consume la instantánea completa, nunca la lista filtrada. Agrupa ingresos/gastos del año/mes por moneda y categoría, incluyendo una sección sin categoría. Excluye aperturas, pagos y transferencias; crédito y débito se cuentan una vez como gasto. Las devoluciones restan gasto en su propio mes, con la categoría actual de la compra y sin sumar ingresos ni reescribir meses anteriores. Puede haber gastos netos negativos; un mes con solo devoluciones tiene resumen. Usa acumuladores `BigInt` y `Money.fromBigInt` con comprobación de rango. Un exceso del rango produce un error del resumen, sin invalidar ni revertir movimientos válidos. La diferencia ingreso-gasto no es saldo disponible. `MovementsViewModel` recalcula el resumen al cargar o guardar, conserva el mes al navegar y limita la navegación desde enero de 1900 hasta el mes actual. Los meses sin ingresos/gastos/devoluciones muestran vacío.

`Money` usa centavos enteros dentro del rango exacto compartido con JavaScript (valor absoluto máximo 9007199254740991). Análisis decimal y sumas usan `BigInt` para comprobar el rango antes de convertir; se rechaza exceso de precisión o rango sin redondear y no se usa `double`. No se suman monedas distintas. Los saldos iniciales se guardan como apertura, separados de movimientos. El almacenamiento no está cifrado ni incluye respaldos.

Guardar dinero como unidades menores enteras y conservar su moneda. La tarjeta de débito referencia la cuenta bancaria que mantiene el saldo. La deuda de crédito es independiente del dinero disponible.

No incorporar acceso bancario automático, Firebase, sincronización o autenticación al inicializar MVVM. Son decisiones posteriores según el alcance. Un login no presupone cifrado de datos locales.

## Verificaciones

| Área | Comprobación |
| --- | --- |
| Documentación o Git | Diff, consistencia y patrones afectados. |
| Dinero y dominio | Importes exactos, signos, monedas, pagos y devoluciones. |
| Repositorios y base | Integridad, transacciones, migraciones y recuperación. |
| ViewModels | Estados, acciones, validaciones y dependencias simuladas. |
| Views | Widgets y navegación de los flujos afectados. |
| Plugins o Android | Análisis, pruebas pertinentes y compilación debug. |

## Pendientes antes de distribuir

Android conserva `com.example.mi_quetzal` y la firma debug de la plantilla. Definir applicationId y firma release antes de distribuir, manteniendo las claves fuera de Git.

## Referencias

- [Guía de arquitectura Flutter y MVVM](https://docs.flutter.dev/app-architecture/guide).
- [Persistencia con SQLite](https://docs.flutter.dev/cookbook/persistence/sqlite).
- [Compilación y distribución Android](https://docs.flutter.dev/deployment/android).
