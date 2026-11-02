# Mi Quetzal: instrucciones para Codex

## Contexto y alcance
- App personal para Android, desarrollada con Flutter y Dart. Nombre visible: Mi Quetzal.
- Arquitectura acordada: Model-View-ViewModel (MVVM). No sustituirla por MVC, BLoC u otra arquitectura por iniciativa propia.
- Trabajar desde la raíz que contiene este archivo, `pubspec.yaml` y `android/`.
- Al comenzar, revisar Git, `README.md` y los archivos afectados. Conservar los cambios ajenos a la tarea.
- El estado inicial es la demo de Flutter. Una maqueta o función descrita no equivale a una función implementada.
- Comunicarse y documentar en español. Usar `lower_snake_case` para archivos Dart y `UpperCamelCase` para clases.

## Arquitectura
- Consultar `docs/arquitectura.md` antes de implementar un módulo.
- Views: widgets, composición, navegación y estado visual efímero. Enviar acciones al ViewModel.
- ViewModels: estado de presentación, validación de entradas y coordinación. Recibir repositorios por constructor.
- Models: entidades, dinero y reglas compartidas, sin depender de widgets, SQL ni plugins.
- Repositories: fuente de verdad para los datos, interfaces e implementaciones. Encapsular persistencia y operaciones atómicas.
- Services: acceso a base local, archivos o plataforma cuando se implementen. No conocen pantallas ni ViewModels.
- Una View no consulta SQL, lee Excel ni calcula saldos, deudas o presupuestos.
- Centralizar las reglas financieras en funciones o servicios de dominio comprobables; no duplicarlas entre ViewModels.
- Empezar con `ChangeNotifier` y herramientas del SDK. No introducir un framework de estado o generación de código sin necesidad concreta.
- Mantener `main.dart` pequeño, dedicado al arranque y composición de dependencias.
- Crear carpetas y abstracciones cuando una función las necesite; no generar módulos vacíos ni capas que solo reenvían llamadas.

## Reglas financieras
- Leer `docs/importacion-y-reglas.md` al modificar cuentas, tarjetas, movimientos, importaciones o reportes.
- Separar tipo de cuenta/tarjeta, cargo/abono original y tipo de operación. La columna Excel Crédito no indica tipo de tarjeta ni implica ingreso.
- Una compra con crédito registra gasto y aumenta deuda. Con débito registra gasto y reduce el saldo bancario vinculado.
- Un pago de tarjeta reduce deuda y saldo de origen cuando este se conoce; no es ingreso ni un segundo gasto.
- Vincular ambas caras de una transferencia con una operación común y aplicar los cambios de forma atómica.
- Un adelanto o retiro mueve fondos hacia efectivo cuando este se controla; comisiones e intereses son gastos separados.
- Las devoluciones y extornos revierten el efecto correspondiente; no clasificarlos automáticamente como ingresos.
- Una tarjeta de débito referencia la cuenta bancaria: varias tarjetas de la misma cuenta no duplican su saldo.
- Guardar dinero como unidades menores enteras (centavos para GTQ/USD), con moneda explícita. No usar `double` en cálculos financieros.
- No sumar monedas distintas sin conversión explícita, fecha y tipo de cambio conservados.
- Separar saldos iniciales, movimientos reales, presupuestos y compromisos futuros. Una suscripción prevista no es un gasto pagado.
- No inventar saldos, monedas, referencias, cuentas de origen ni clasificaciones que el archivo no aporta.

## Importación y persistencia
- El histórico observado incluye Fecha, Descripción, Sub-descripción, Crédito, Débito, Monto, TipoMovimiento, Año, Mes, Día y BANCO.
- Importar mediante vista previa, mapeo, validación y confirmación. Conservar descripción original, hoja, fila y lote.
- Asignar cuenta/tarjeta y moneda por lote solo para hojas homogéneas; exigir identificación por fila si mezcla cuentas o monedas.
- Derivar año/mes/día de la fecha válida. El banco no identifica de forma única una tarjeta.
- Revisar filas con ambos importes informados, fechas inválidas, montos incoherentes u operación ambigua.
- No eliminar compras legítimas repetidas por coincidir en fecha y monto. Usar referencias disponibles y revisar ambigüedades.
- Diseñar reimportaciones idempotentes, lotes rastreables y escrituras atómicas. No modificar el Excel original.
- Mantener separadas categorías, tipos de operación y reglas que sugieren clasificaciones.
- Al implementar SQLite, usar consultas parametrizadas, claves foráneas, transacciones y migraciones versionadas. No borrar la base del usuario para resolver una migración.
- La persistencia todavía no está instalada. No presentar SQLite, sincronización, autenticación ni respaldos como disponibles sin implementarlos y verificarlos.

## Privacidad y Git
- Usar exclusivamente datos sintéticos en ejemplos y pruebas. Guardar Excel reales, estados de cuenta, exportaciones y respaldos en las carpetas ignoradas.
- No registrar descripciones financieras, números completos de tarjetas, credenciales o archivos reales en logs ni capturas de pruebas.
- No almacenar CVV, PIN bancario ni números completos de tarjetas. Usar alias y últimos cuatro dígitos.
- Almacenamiento local no equivale a cifrado. No declarar biometría, cifrado ni recuperación segura sin implementación real.
- Conservar `pubspec.lock`, `.metadata`, configuración compartida y documentación en Git. Excluir `.env`, archivos locales y claves de firma.
- Revisar diff y archivos antes de preparar un commit; no incluir datos privados mediante un `git add .` indiscriminado.
- No hacer push forzado, borrar archivos del usuario ni cambiar remotos. Crear commits o publicar solo cuando la tarea lo autorice.
- Añadir dependencias cuando una función las necesite, comprobar compatibilidad y documentar su propósito. No actualizar Flutter/Gradle/Kotlin en tareas ajenas.

## Interfaz
- UI en español, fechas legibles y moneda visible. Separar fondos disponibles, deuda y límite de crédito.
- Navegación prevista: Inicio, Movimientos, Cuentas y Planificación, con acceso rápido para registrar movimientos.
- Tema consistente, controles accesibles y estados de carga, vacío, datos y error. No comunicar estados solo con color.
- Las maquetas son referencias: saldos y listas reales deben venir de repositorios, no de constantes en una View.

## Verificación y entrega
- Documentación/configuración: comprobar diff, enlaces, consistencia y patrones afectados. No generar pruebas artificiales de texto.
- Para cambios Dart, ejecutar las verificaciones pertinentes desde la raíz:
  - `flutter pub get` si cambian dependencias o falta su resolución.
  - `dart format --output=none --set-exit-if-changed lib test`
  - `flutter analyze`
  - `flutter test`
- Probar las reglas financieras, repositorios, importación y ViewModels cuando cambie su comportamiento. Cubrir crédito/débito, pagos sin doble gasto, monedas, duplicados legítimos y fallos según el alcance.
- Ejecutar `flutter build apk --debug` cuando cambien plugins o integración Android. No exigir firma privada ni build release para documentación.
- No silenciar lints ni borrar pruebas para obtener resultados verdes. Adaptar la prueba del contador al sustituir la demo.
- Al finalizar, resumir cambios, verificaciones realmente ejecutadas, limitaciones y un nombre de commit sugerido. Distinguir implementación de propuesta.
