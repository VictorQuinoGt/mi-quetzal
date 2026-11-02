# Arquitectura de Mi Quetzal

## Decisión y estado actual

La aplicación utiliza Flutter/Dart para Android, con soporte web para desarrollar y comprobar la interfaz sin Android Studio. Se adopta MVVM. Están implementados cuentas, tarjetas de débito vinculadas, compras/gastos, ingresos, transferencias, pagos de tarjeta y filtros de historial, con persistencia SQLite y saldos derivados. Categorías, devoluciones, planificación e importación siguen pendientes.

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
- `domain/models/` contiene dinero, cuentas, tarjetas de débito, movimientos, `MovementFilter` y `LedgerSnapshot`. `domain/rules/movement_rules.dart` centraliza las validaciones y efectos de cada operación, sin Flutter ni SQL.
- `ui/movements/` contiene listado, formulario, filtros y `MovementsViewModel`, que recibe `MovementRepository`. Maneja carga, cuentas/tarjetas compatibles, validación, guardado, filtros y errores.
- `data/repositories/` contiene el contrato de cuentas y su implementación SQLite. El repositorio asigna identificadores persistentes y guarda los datos en una transacción.
- `data/services/` abre la base, activa claves foráneas y aplica migraciones versionadas; selecciona la fábrica nativa/web por importación condicional.
- `ui/home/` y `ui/planning/` mantienen sus vistas de presentación. Las introductorias no necesitan repositorios hasta que existan operaciones propias.
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

`LocalDatabase` conserva una sola apertura y permite reintentar tras un fallo. El esquema 1 crea `accounts`. El esquema 2 añade `movements` e índice por fecha. El esquema 3 añade `debit_cards` y la columna opcional `movements.debit_card_id`; las filas existentes permanecen intactas con tarjeta nula. Claves foráneas y disparadores validan vínculos bancarios y coincidencia tarjeta/cuenta; una tarjeta usada no se puede reasignar a otro banco mediante SQL, ni transformar su banco en efectivo/crédito. `onCreate` y `onUpgrade` ejecutan migraciones transaccionales; un downgrade falla sin borrar la base. No hay reparación ni restauración de bases dañadas.

Una transferencia o pago es una sola fila con dos referencias de cuenta y una identidad común. `SqliteMovementRepository` lee el estado, valida la operación, inserta la fila y reconstruye `LedgerSnapshot` antes del commit, usando solo el objeto transacción. Ante error se revierte la operación completa. Los repositorios comparten `ledger_reader.dart` para obtener cuentas e historial consistentes. No se almacenan saldos actuales duplicados en SQL.

`LedgerSnapshot` ordena por fecha y luego identidad de registro, calcula efectos con `MovementRules` y construye cuentas con `currentBalance`. Se mantienen apertura y moneda. Efectivo nunca puede quedar negativo, incluso con movimientos retroactivos; banco admite sobregiro. Crédito puede quedar con saldo a favor por un pago mayor a la deuda, sin alterar la regla de apertura no negativa. La pantalla muestra el importe a favor como positivo con su etiqueta.

Las compras con fondos reducen saldo; con crédito aumentan deuda. Los ingresos solo se aplican a efectivo/banco. Transferencias y pagos no se clasifican como ingreso ni gasto. Los pagos exigen origen de fondos y destino de crédito; las transferencias excluyen crédito. Cada cuenta involucrada debe usar la moneda de la operación y tener apertura no posterior a ella. Al registrar se rechazan fechas futuras. No se implementan conversiones ni pagos de origen desconocido en este formulario.

`AccountDetails` representa el alta: alias, tipo efectivo/banco/crédito, saldo o deuda inicial, moneda y fecha. Crédito admite límite y últimos cuatro opcionales; una deuda superior al límite no se rechaza. `DebitCardDetails` contiene alias, cuenta bancaria y últimos cuatro opcionales; no define saldo ni moneda. `AccountRepository` gestiona su alta transaccional y consulta. `LedgerSnapshot` conserva las tarjetas aparte de las cuentas, valida sus vínculos y usa `MovementRules` para comprobar la tarjeta opcional de una compra. El único efecto es reducir el saldo bancario una vez. Los identificadores no dependen del alias ni de últimos dígitos; se permiten alias repetidos.

`MovementFilter` aplica descripción literal sin distinción de mayúsculas, cuenta (origen o contraparte), operación, moneda y fechas inclusivas. Filtra la instantánea completa sin escribir datos ni afectar saldos. `MovementsViewModel` conserva los criterios al navegar, recargar o guardar; son efímeros al reiniciar la app. La vista distingue historial vacío de filtro sin coincidencias y ofrece limpiar criterios. No se han implementado categorías, paginación ni resúmenes a partir de estos filtros.

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
