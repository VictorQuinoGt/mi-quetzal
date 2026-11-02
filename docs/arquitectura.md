# Arquitectura de Mi Quetzal

## Decisión y estado actual

La aplicación utiliza Flutter/Dart para Android. Se adopta MVVM para desarrollar funcionalidades. La separación aquí descrita todavía debe implementarse: el código inicial mantiene la pantalla de ejemplo del contador.

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

Se prevé persistencia local para uso sin conexión. SQLite es la opción propuesta; todavía no existe una base ni un paquete instalado para ella. Su implementación debe definir esquema, migraciones, transacciones y recuperación antes de cargar el histórico real.

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
