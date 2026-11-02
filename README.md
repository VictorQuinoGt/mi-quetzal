# Mi Quetzal

Aplicación personal para Android orientada al control de cuentas, tarjetas de crédito y débito, consumos, pagos y planificación financiera.

## Estado actual

Aplicación Flutter con tema azul y rojo e interfaz en español:

- Inicio con accesos a Movimientos, Cuentas y Planificación.
- Navegación inferior en móvil y lateral desde 840 px de ancho.
- Estado de navegación en `AppShellViewModel` mediante `ChangeNotifier`.
- Acceso rápido «Registrar» con formulario de movimientos; si faltan cuentas, conduce a su alta.
- Soporte web para desarrollar y probar la interfaz sin Android Studio.
- Registro y listado de efectivo, cuentas bancarias y tarjetas de crédito.
- Cuentas organizadas en crédito, débito, bancos y efectivo, con tarjetas visuales del mismo estilo y saldos actuales visibles.
- Crédito con aperturas, saldos/deudas y límites independientes en GTQ y USD dentro de una misma tarjeta.
- Cuentas bancarias de tipo Monetario o Ahorro; débito muestra el saldo compartido del banco vinculado.
- Edición de cuentas y tarjetas de débito existentes, conservando identidad e historial.
- Importes exactos en centavos, con moneda GTQ o USD, saldo/deuda inicial y fecha.
- Límite de crédito y últimos cuatro dígitos opcionales; no se solicitan números completos, CVV ni PIN.
- Persistencia SQLite de cuentas y recuperación al volver a abrir la aplicación.
- Compras/gastos, ingresos, transferencias y pagos de tarjeta con historial persistente.
- Saldos actuales calculados desde la apertura y los movimientos, sin mezclar monedas.
- Tarjetas de débito vinculadas a bancos, sin saldos independientes, y compras identificadas por tarjeta.
- Filtros de historial por cuenta, operación, moneda, descripción y rango de fechas.
- Categorías propias de ingreso/gasto, opcionales al registrar y asignables a operaciones anteriores.
- Resumen mensual en Inicio, por moneda y categoría, sin doble gasto por pagos de tarjeta.
- Devoluciones parciales o completas vinculadas a compras, con control del importe pendiente y reversión del gasto.
- Migración al esquema 6 que conserva cuentas, tarjetas, categorías y movimientos anteriores.

Cuentas muestra saldo o deuda actual junto con su apertura. Un pago o una devolución mayor a la deuda deja saldo a favor en su moneda, mostrado por separado del límite de crédito. Se pueden editar alias, aperturas, fecha, límites, últimos cuatro y tipo bancario; el tipo general y la moneda principal de una cuenta existente se conservan. La categoría de ingresos/gastos se puede cambiar; la edición general de movimientos y el borrado aún no están implementados. Siguen pendientes adelantos de crédito, conversiones, presupuestos e importación. No se cargan datos de ejemplo ni saldos ficticios.

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

## Probar débito y filtros en el teléfono

Instalar la APK como actualización, sin desinstalar la anterior ni borrar datos, para comprobar la migración.

1. En Cuentas, crear una nueva cuenta bancaria sintética «Banco débito prueba», GTQ y saldo inicial `1000`.
2. Pulsar «Vincular débito». Crear «Débito principal» con últimos cuatro `0042` y vincularla al banco anterior. Se puede añadir otra tarjeta «Débito adicional» a la misma cuenta.
3. En «Registrar», elegir compra/gasto y la cuenta «Banco débito prueba». Seleccionar «Débito principal» en el campo opcional de tarjeta y registrar `12.50` con descripción «Compra débito prueba».
4. Registrar otra compra de `7.50` con «Débito adicional». La cuenta bancaria debe mostrar `GTQ 980.00`. Las tarjetas no muestran ni agregan saldos propios.
5. En Movimientos, filtrar por el banco, compra/gasto y GTQ. Buscar «débito» y seleccionar un rango de fechas que incluya ambas compras. Deben aparecer dos operaciones con su tarjeta identificada.
6. Cambiar a USD manteniendo la cuenta GTQ: debe aparecer el estado sin coincidencias. Consultar Cuentas y comprobar que el saldo sigue en `GTQ 980.00`.
7. Volver a Movimientos y pulsar «Limpiar filtros» para recuperar todo el historial. Cerrar y volver a abrir la app: las tarjetas y compras deben conservarse.

Débito se registra con alias y últimos cuatro opcionales. Solo puede vincularse a una cuenta bancaria existente; la moneda se toma de esa cuenta. Varias tarjetas pueden compartir el banco. En compras, seleccionar una tarjeta es opcional; cambiar de cuenta o tipo de operación limpia esa selección. La identificación de tarjeta de débito se admite únicamente en compras/gastos. Los retiros pueden registrarse como transferencia banco→efectivo; identificar su tarjeta queda pendiente.

Los filtros se combinan, mantienen el orden del historial y nunca recalculan saldos con una lista parcial. El filtro por cuenta incluye origen y destino de transferencias/pagos. La búsqueda en descripción es literal y no distingue mayúsculas; los extremos del rango de fechas son inclusivos. Se conservan al navegar o recargar datos, pero se reinician al abrir una nueva sesión de la app.

## Probar categorías y resumen mensual

Instalar la APK como actualización, sin desinstalar ni borrar datos, para comprobar la migración desde la versión anterior.

1. En Movimientos → Categorías, crear «Alimentos de prueba» de tipo Gasto y «Salario de prueba» de tipo Ingreso. Las categorías no se asignan automáticamente por descripción.
2. Para una prueba aislada, usar nuevas cuentas sintéticas en GTQ: «Banco resumen» con apertura `1000` y «Crédito resumen» con deuda inicial `0`.
3. En el mes actual, registrar ingreso `100` al banco con categoría «Salario de prueba», una compra de crédito de `50` con «Alimentos de prueba» y un pago de tarjeta de `20` desde el banco hacia crédito.
4. En Inicio, el incremento de los totales GTQ del mes debe ser ingresos `100`, gastos `50` y diferencia `50`. El pago de `20` no vuelve a sumar gasto; la apertura `1000` tampoco es ingreso. Si ya hay operaciones de ese mes, estos valores se agregan a ellas.
5. En Movimientos, pulsar «Categorizar» sobre un ingreso o gasto anterior. Asignar una categoría compatible o «Sin categoría». Deben conservarse descripción, fecha, importe, identidad y saldos; el desglose por categoría se actualiza.
6. Probar el filtro por categoría y «Sin categoría». Este último incluye ingresos/gastos no clasificados y sus devoluciones; no incluye transferencias ni pagos. Los filtros no cambian los totales de Inicio.
7. Cambiar al mes anterior y regresar. GTQ y USD tienen resúmenes separados; no se suman ni convierten. Cerrar y volver a abrir la app para comprobar la conservación de categorías y asignaciones.

El resumen utiliza todas las operaciones del mes seleccionado, incluidas compras con crédito y débito una sola vez. Excluye aperturas, transferencias y pagos de tarjeta. «Diferencia del mes» es ingreso menos gasto y no representa dinero disponible. Los meses sin ingresos/gastos muestran un estado vacío, incluso si solo hubo transferencias. Las categorías de ingreso y gasto se mantienen separadas; no se aplican a pagos ni transferencias.

Los totales usan centavos exactos y comprobación de rango mediante `BigInt`. Si un agregado supera el rango de `Money`, el resumen muestra un error explícito; los movimientos válidos se conservan. No se ha implementado renombrar, borrar o fusionar categorías. Se permiten nombres repetidos con identidades diferentes.

## Probar devoluciones en el teléfono

Instalar la APK como actualización, sin desinstalar la anterior ni borrar sus datos. En Movimientos, cada compra con importe pendiente tiene el botón «Devolver»; las devoluciones se registran desde esa compra.

1. Crear cuentas sintéticas GTQ «Banco devoluciones» con apertura `1000` y «Crédito devoluciones» con deuda `0`.
2. Registrar una compra de `50` desde el banco. Pulsar «Devolver» en esa compra, escribir descripción e importe `20` y guardar. Banco debe quedar en `970`; el pendiente de devolver es `30`.
3. Si ambas operaciones son del mes actual, el incremento de gastos del resumen debe ser `30`, sin nuevos ingresos. Si la compra es del mes anterior, conserva el gasto original en ese mes y resta `20` de los gastos del mes de devolución; el total neto puede ser negativo.
4. Devolver los `30` restantes. Banco regresa a `1000` y la compra muestra «Compra devuelta por completo». El registro original conserva importe, fecha, descripción y tarjeta de débito si tenía una.
5. Registrar compra de crédito de `50` y pagar `50` desde el banco. Después devolver `20` de esa compra: crédito debe mostrar saldo a favor `20`, sin registrar otro ingreso ni modificar el pago.
6. Intentar devolver `30.01` de esa compra cuyo pendiente es `30`. El formulario debe rechazarlo sin cambiar saldo ni historial. La fecha debe estar entre la compra original y hoy.
7. Filtrar por operación «Devolución» y por la categoría de la compra. Cambiar la categoría de la compra también cambia la clasificación de sus devoluciones, sin tocar importes ni saldos. Cerrar y abrir la app para comprobar persistencia.

Las devoluciones siempre usan la cuenta y moneda originales, tanto para efectivo/banco como para crédito. Se admiten varias devoluciones parciales hasta completar el importe de cada compra; compras repetidas legítimas mantienen pendientes independientes. La escritura es transaccional y se bloquea el doble envío. No se admiten devoluciones de ingresos, pagos, transferencias ni otras devoluciones, ni abonos sin compra original conocida en este flujo.

## Probar cuentas editables, saldos GTQ/USD y nuevo diseño

Instalar la APK como actualización, sin desinstalar ni borrar datos. Las cuentas anteriores conservan su moneda, apertura, vínculos e historial. El tipo bancario y la segunda moneda que no estaban registrados quedan sin especificar hasta completarlos al editar.

1. En Cuentas, pulsar el lápiz rojo de una tarjeta de crédito existente. Comprobar que están cargados su alias, apertura original, fecha, límite y últimos cuatro.
2. Conservar la deuda inicial GTQ y registrar, por ejemplo, `25.29` en «Deuda inicial USD», o `0` si no hay deuda en dólares. Añadir un límite USD es opcional. Si la tarjeta anterior tenía USD como moneda principal, el segundo campo corresponde a GTQ. No hay conversión ni suma entre monedas.
3. Guardar y comprobar ambas deudas actuales en una sola tarjeta. El saldo actual incluye los movimientos anteriores; el formulario edita la apertura, no registra una compra ni ingreso nuevo.
4. En Registrar, seleccionar esa tarjeta y elegir «Moneda del movimiento». Una compra USD debe aumentar solo su deuda USD. Su devolución usa automáticamente esa misma moneda.
5. Para pagar USD, usar un banco USD como origen y la tarjeta dual como destino. La deuda GTQ no debe cambiar; pagos y transferencias no convierten monedas.
6. Al crear un banco, elegir «Monetario» o «Ahorro». También se puede completar o cambiar este dato al editar un banco anterior. Su saldo actual aparece tanto en Cuentas bancarias como en sus tarjetas de débito, sin duplicar fondos.
7. Editar el alias o los últimos cuatro de una tarjeta de débito. Si ya tiene compras, no se puede cambiar su banco vinculado. Las compras conservan su referencia a la tarjeta.
8. Cerrar y volver a abrir la app para comprobar persistencia. Intentar una apertura posterior a movimientos existentes o un efectivo inicial que dejaría el historial negativo: debe rechazarse sin guardar cambios parciales.

La segunda moneda de crédito es opcional: dejarla vacía significa que aún no se ha registrado, no saldo cero. Una vez que tiene movimientos, no se puede quitar. El tipo general y la moneda principal se conservan al editar para evitar reinterpretar el historial. El tema utiliza azul para marca/acciones y rojo para edición, selección y errores.

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

Las pruebas cubren navegación, formularios, dinero exacto, monedas, compras con fondos/crédito/débito, pagos sin doble gasto, transferencias, saldo a favor, filtros combinados, categorías, resúmenes mensuales, validaciones, envíos repetidos, errores y recuperación. SQLite se prueba con bases temporales sintéticas: reapertura, parámetros, identidades distintas, restricciones, escrituras concurrentes, operaciones retroactivas, transacciones, migraciones desde esquemas 1, 2, 3, 4 y 5 y fallos de migración sin borrar datos. Se comprueba que categorizar conserva datos financieros y que los totales mensuales no dependen de filtros ni mezclan monedas. Las pruebas exclusivas de SQLite web se omiten en la ejecución nativa; el comando de Chrome usa un archivo en la raíz de `test/` para evitar el defecto de rutas anidadas de Flutter 3.47 en Windows y agrupa también pruebas de dominio en JavaScript.

Verificación del incremento de cuentas editables: formato y análisis sin incidencias, compilaciones APK debug y web correctas, 176 pruebas nativas y 54 en Chrome aprobadas. Las seis pruebas exclusivas de SQLite web se omiten en el entorno nativo. Se comprueban saldos GTQ/USD independientes, compras/pagos/devoluciones por moneda, edición sin alterar movimientos, validación del historial, débito compartido, tipos bancarios y migración desde v5 sin inventar saldos ni clasificaciones. Las pruebas incluyen teclado y texto ampliado a 320 px; se revisó el diseño mediante capturas locales con datos sintéticos.

La prueba física en teléfono debe realizarse con los pasos anteriores; no se ha ejecutado desde este entorno. Los cambios solo documentales o de Git requieren revisar diff y patrones afectados, sin compilar la app. No existe todavía un flujo CI configurado.

## Persistencia y dependencias

- `sqflite` usa SQLite local en Android; `sqflite_common` define la API compartida.
- `sqflite_common_ffi_web` adapta SQLite a IndexedDB con recursos WASM y worker generados.
- `sqflite_common_ffi` permite probar el mismo repositorio con SQLite real en la computadora.
- `path` compone la ruta local y `flutter_localizations` presenta controles y fechas en español.

El esquema actual es versión 6: `accounts`, `movements`, `debit_cards` y `categories`. La migración v6 añade columnas opcionales para tipo bancario, segunda apertura y segundo límite de crédito, preservando los valores anteriores. Las columnas quedan nulas en cuentas existentes hasta que se completen. Las altas y ediciones son transaccionales; editar una apertura reconstruye el historial antes del commit y revierte ante incompatibilidad. La migración v5 conserva el vínculo `movements.original_movement_id` de devoluciones. Claves foráneas, restricciones y disparadores protegen vínculos, monedas y categorías. La apertura se mantiene separada de los movimientos; los saldos actuales se reconstruyen por cuenta y moneda en el dominio. El almacenamiento actual no incorpora cifrado, respaldos, sincronización ni autenticación.

## Próximo incremento

Incorporar conciliación e importación validada. No cargar históricos reales antes de implementar y comprobar su importación.

El applicationId `com.example.mi_quetzal`, nombre Android de plantilla y firma release quedan pendientes antes de distribuir.
