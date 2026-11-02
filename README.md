# Mi Quetzal

Aplicación personal para Android orientada al control de cuentas, tarjetas de crédito y débito, consumos, pagos y planificación financiera.

## Estado actual

Aplicación Flutter con tema propio e interfaz en español:

- Inicio con accesos a Movimientos, Cuentas y Planificación.
- Navegación inferior en móvil y lateral desde 840 px de ancho.
- Estado de navegación en `AppShellViewModel` mediante `ChangeNotifier`.
- Acceso rápido «Registrar» con formulario de movimientos; si faltan cuentas, conduce a su alta.
- Soporte web para desarrollar y probar la interfaz sin Android Studio.
- Registro y listado de efectivo, cuentas bancarias y tarjetas de crédito.
- Importes exactos en centavos, con moneda GTQ o USD, saldo/deuda inicial y fecha.
- Límite de crédito y últimos cuatro dígitos opcionales; no se solicitan números completos, CVV ni PIN.
- Persistencia SQLite de cuentas y recuperación al volver a abrir la aplicación.
- Compras/gastos, ingresos, transferencias y pagos de tarjeta con historial persistente.
- Saldos actuales calculados desde la apertura y los movimientos, sin mezclar monedas.
- Migración al esquema 2 que conserva las cuentas de la versión anterior.

Cuentas muestra saldo o deuda actual junto con su apertura. Un pago mayor a la deuda deja saldo a favor, mostrado por separado del límite de crédito. Todavía no hay edición/borrado, vinculación de tarjetas de débito, devoluciones vinculadas, adelantos de crédito, conversiones, filtros de historial, resúmenes mensuales, presupuestos ni importación. No se cargan datos de ejemplo ni saldos ficticios.

## Desarrollo

- Flutter con soporte Android. Entorno revisado: Flutter 3.47.0 / Dart 3.13.0.
- Restricción Dart actual: `^3.13.0` en `pubspec.yaml`.
- Chrome o Edge para desarrollar la interfaz sin Android Studio.
- Para ejecutar en Android: SDK, licencias aceptadas y emulador o dispositivo configurado.
- Abrir la raíz con `pubspec.yaml`, `AGENTS.md` y `android/`. La instalación local revisada es `D:\MiQuetzal\mi-quetzal`.

Desde `D:\MiQuetzal\mi-quetzal`, ejecutar en navegador:

```powershell
flutter pub get
.\tool\prepare_web.ps1
flutter run -d chrome --web-port 5353
```

También se puede usar `flutter run -d edge --web-port 5353`. El script genera el motor SQLite y su worker, ignorados en Git, y copia los recursos para las pruebas de navegador. También copia CanvasKit desde la caché del SDK al directorio de pruebas para evitar los 404 del ejecutor de Flutter 3.47 en Windows, sin modificar el SDK. Debe ejecutarse tras clonar el proyecto o cambiar sus dependencias de SQLite web; para regenerarlos tras una actualización, usar `dart run sqflite_common_ffi_web:setup --force` antes del script. [Guía oficial de desarrollo web de Flutter](https://docs.flutter.dev/platform-integration/web/setup).

En navegador, SQLite se conserva en IndexedDB por origen (protocolo, host y puerto). Mantener el puerto evita abrir otro almacenamiento durante el desarrollo. Los datos de Chrome, Edge y la app Android son independientes; borrar datos del sitio o usar una sesión privada puede eliminarlos. La adaptación web es experimental según [su documentación](https://pub.dev/packages/sqflite_common_ffi_web).

Para revisar el entorno y ejecutar en Android cuando esté configurado:

```powershell
flutter doctor
flutter devices
flutter run -d <id_del_dispositivo_android>
```

Sustituir el identificador por uno mostrado en `flutter devices`.

## Probar cuentas en el teléfono

1. Generar la APK con `flutter build apk --debug` e instalar `build/app/outputs/flutter-apk/app-debug.apk`, o ejecutar directamente con `flutter run -d <id_del_dispositivo_android>`.
2. Abrir Cuentas y pulsar «Nueva cuenta» o «Agregar cuenta».
3. Usar datos sintéticos: alias «Cuenta de prueba», tipo bancaria, GTQ y saldo inicial `123.45`; elegir su fecha y guardar.
4. Cerrar y volver a abrir la app. La cuenta debe conservar `GTQ 123.45` como saldo inicial.
5. Agregar una tarjeta USD con deuda `25.10`, límite `500` y últimos cuatro `0042`. Deben verse deuda y límite separados, sin sumar GTQ y USD.

También se puede dejar vacío el límite cuando no se conoce. El saldo bancario admite sobregiro; efectivo y deuda inicial deben ser cero o positivos. Los importes aceptan punto o coma decimal y hasta dos decimales, sin separadores de miles. Los saldos iniciales no crean ingresos ni gastos. El guardado impide envíos repetidos y conserva el formulario si falla.

## Probar movimientos en el teléfono

Para comprobar la migración, instalar la nueva APK como actualización sobre la anterior, sin desinstalar ni borrar datos. La compilación se realiza con `flutter build apk --debug`.

Usar cuentas sintéticas en GTQ con fecha de apertura anterior o igual a los movimientos:

1. Crear «Banco de prueba» con saldo `1000`, «Efectivo de prueba» con `0` y «Crédito de prueba» con deuda `0`.
2. Pulsar «Registrar», elegir compra/gasto en crédito y guardar `50`. La deuda debe ser `GTQ 50.00`.
3. Registrar pago de tarjeta de `20`, desde banco hacia crédito. Banco debe quedar en `GTQ 980.00` y deuda en `GTQ 30.00`. El historial muestra una compra y un pago; el pago no es otro gasto.
4. Transferir `100` del banco al efectivo: banco `GTQ 880.00` y efectivo `GTQ 100.00`.
5. Registrar una compra de `10` desde efectivo y un ingreso de `25` al banco: efectivo `GTQ 90.00` y banco `GTQ 905.00`.
6. Cerrar y volver a abrir la app. Cuentas e historial deben conservarse. Los saldos iniciales permanecen visibles e intactos.

Las operaciones requieren importe positivo y fecha entre la apertura de las cuentas involucradas y hoy. Las operaciones de un mismo día se ordenan por registro. El efectivo no puede ser negativo en ningún punto del historial; las cuentas bancarias admiten sobregiro. Las transferencias y pagos requieren origen/destino conocidos, distintos y de la misma moneda. No se agregan ni convierten GTQ y USD.

El registro de pagos con origen desconocido se abordará con la importación y conciliación. Por ahora, el formulario exige una cuenta de origen. Una transferencia o pago se guarda como una sola operación vinculada; si la escritura o la validación del historial falla, se revierte todo. Las compras legítimas repetidas mantienen identidades diferentes.

## Codex y arquitectura

Leer [AGENTS.md](AGENTS.md) antes de cambiar el proyecto. Define responsabilidades MVVM, reglas financieras, privacidad y comprobaciones.

- [Arquitectura y organización prevista](docs/arquitectura.md).
- [Importación del histórico y reglas financieras](docs/importacion-y-reglas.md).

## Funciones previstas

| Módulo | Alcance previsto |
| --- | --- |
| Inicio | Saldos, deuda, resumen mensual y compromisos. |
| Movimientos | Compras, ingresos, pagos, transferencias, devoluciones y filtros. |
| Cuentas | Efectivo, bancos y tarjetas de crédito/débito. |
| Planificación | Presupuestos, metas y compromisos recurrentes. |
| Importación | Vista previa, mapeo y carga validada de Excel/CSV. |

Una compra con crédito aumenta deuda. Con débito reduce fondos bancarios. Ambas son gastos. Pagar una tarjeta es una transferencia y no vuelve a sumar el gasto.

## Archivos locales

Guardar datos financieros reales en `local_data/` o `imports/`, resultados en `exports/` y respaldos en `backups/`. Estas carpetas, las bases locales, `.env`, claves de firma y artefactos generados están ignorados.

`.gitignore` no elimina archivos ya versionados ni protege copias fuera de las rutas ignoradas. Revisar archivos y diff antes de un commit. Usar solo datos sintéticos en `test/fixtures/`.

Conservar `pubspec.lock`, `.metadata`, `AGENTS.md`, configuración compartida y documentación en Git. `.editorconfig` y `.gitattributes` establecen formato y finales de línea.

## Verificación

Para cambios Dart:

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
.\tool\prepare_web.ps1
flutter test --platform chrome test/sqlite_web_repository_test.dart
flutter build web
```

Cuando cambien plugins o integración Android:

```powershell
flutter build apk --debug
```

Las pruebas cubren navegación, formularios, dinero exacto, monedas, compras con fondos/crédito, pagos sin doble gasto, transferencias, saldo a favor, validaciones, estados, envíos repetidos, fallos de escritura y recuperación. SQLite se prueba con bases temporales sintéticas: reapertura, parámetros, identidades distintas, restricciones, escrituras concurrentes, operaciones retroactivas, transacciones, migración desde esquema 1 y fallos de migración sin borrar datos. Las pruebas de SQLite web se omiten en la ejecución nativa y se ejecutan mediante el comando explícito de Chrome. Su archivo está en la raíz de `test/` para evitar el escape incorrecto de rutas anidadas del ejecutor de Flutter 3.47 en Windows; agrupa también las pruebas monetarias y reglas de movimientos en JavaScript.

Verificación del incremento de movimientos: formato y análisis sin incidencias, 67 pruebas nativas aprobadas (dos exclusivas de web omitidas), 16 pruebas en Chrome aprobadas y compilaciones web y APK debug correctas. Se comprobó que la APK contiene el formulario y el modelo de movimientos nuevos.

La prueba física en teléfono debe realizarse con los pasos anteriores; no se ha ejecutado desde este entorno. Los cambios solo documentales o de Git requieren revisar diff y patrones afectados, sin compilar la app. No existe todavía un flujo CI configurado.

## Persistencia y dependencias

- `sqflite` usa SQLite local en Android; `sqflite_common` define la API compartida.
- `sqflite_common_ffi_web` adapta SQLite a IndexedDB con recursos WASM y worker generados.
- `sqflite_common_ffi` permite probar el mismo repositorio con SQLite real en la computadora.
- `path` compone la ruta local y `flutter_localizations` presenta controles y fechas en español.

El esquema actual es versión 2, tablas `accounts` y `movements`, con identificadores enteros estables, restricciones, claves foráneas activadas y altas transaccionales. La apertura se mantiene en cuentas; los saldos actuales se reconstruyen en el dominio sin sobrescribirla. La migración añade movimientos e índice de fecha sin borrar cuentas. Las futuras migraciones deben conservar los datos. El almacenamiento actual no incorpora cifrado, respaldos, sincronización ni autenticación.

## Próximo incremento

Vincular tarjetas de débito a cuentas bancarias y añadir categorías, filtros y resúmenes por moneda. Después incorporar devoluciones vinculadas y conciliación. No cargar históricos reales antes de implementar y comprobar su importación.

El applicationId `com.example.mi_quetzal`, nombre Android de plantilla y firma release quedan pendientes antes de distribuir.
