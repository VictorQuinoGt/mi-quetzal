# Mi Quetzal

Aplicación personal para Android orientada al control de cuentas, tarjetas de crédito y débito, consumos, pagos y planificación financiera.

## Estado actual

El repositorio contiene la estructura inicial de Flutter y la pantalla de ejemplo del contador. Se definieron instrucciones de trabajo con Codex y la arquitectura MVVM. Las pantallas financieras, base local e importación están pendientes de implementación.

## Desarrollo

- Flutter con soporte Android. Entorno revisado: Flutter 3.47.0 / Dart 3.13.0.
- Restricción Dart actual: `^3.13.0` en `pubspec.yaml`.
- Android SDK y un emulador o dispositivo configurado.
- Abrir la raíz con `pubspec.yaml`, `AGENTS.md` y `android/`. La instalación local revisada es `D:\MiQuetzal\mi-quetzal`.

```powershell
flutter doctor
flutter pub get
flutter devices
flutter run -d <id_del_dispositivo_android>
```

Sustituir el identificador por uno mostrado en `flutter devices`.

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
```

Cuando cambien plugins o integración Android:

```powershell
flutter build apk --debug
```

Los cambios solo documentales o de Git requieren revisar diff y patrones afectados, sin compilar la app. No existe todavía un flujo CI configurado.

## Próximo incremento

Sustituir la demo por navegación Inicio/Movimientos/Cuentas/Planificación con tema y ViewModels. Después implementar modelos, repositorios y persistencia antes de cargar datos reales. Adaptar la prueba del contador al sustituir la pantalla inicial.

El applicationId `com.example.mi_quetzal`, nombre Android de plantilla y firma release quedan pendientes antes de distribuir.
