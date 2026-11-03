# Compras en cuotas

## Uso

En Cuentas, abrir una tarjeta de crédito y seleccionar **Cuotas → Agregar compra en cuotas**. La tarjeta está precargada; elegir una de sus monedas configuradas. Informar descripción, categoría opcional, monto original, plazo, importe mensual real, primera fecha y día mensual. Revisar el calendario antes de guardar.

La deuda, Fecha corte/Fecha pago, Límite y Disponible están en un mismo resumen. Las fechas se ven en `dd/MM`, pero se conservan completas e independientes; no se deduce su ciclo bancario. GTQ se presenta como `Q` y USD como `US$`, con dos decimales y espacio inseparable. Las columnas se apilan con poco ancho o texto ampliado. Movimientos conserva sus filtros por mes y cada tarjeta muestra únicamente sus propios planes.

## Calendario y costos

Se utilizan meses calendario. Un cargo del día 31 cae el último día de febrero y vuelve al 31 en marzo. No se suman intervalos de treinta días. Se admiten entre 1 y 600 cuotas.

- **Sin intereses:** el capital mensual es el importe informado; la última cuota contiene el capital restante exacto. La vista previa muestra ese ajuste antes de confirmar.
- **Desglose fijo conocido:** informar capital, interés y comisión mensuales. Deben sumar la mensualidad real; la última cuota ajusta el capital y conserva los costos fijos informados. No se estiman tasas.
- **Sin desglose:** se conserva el importe mensual real y no se inventa su amortización de capital. Si afecta el límite ordinario, Disponible queda sin determinar mientras haya cuotas pendientes.

No se implementa amortización por tasa variable ni costos distintos para cada mes. Si el financiamiento tiene esas condiciones, usar los importes conocidos sin inventar una tasa; revisar el calendario frente al estado bancario. Cada moneda se calcula por separado en centavos enteros, con límites de precisión iguales en Android y web.

## Planes que ya comenzaron

Informar cuántas cuotas están **previamente cargadas** y una fecha de referencia. La última cuota previa debe ser anterior o igual a esa referencia; la siguiente pendiente debe quedar después. Para un plan nuevo sin cuotas previas, la primera fecha puede coincidir con la referencia. La referencia no puede ser futura al guardar.

Las cuotas previas no crean movimientos, no vuelven a aumentar la deuda inicial y no se consideran pagadas. La deuda que ya exista debe estar en la apertura o en movimientos reales. La aplicación no reconstruye historia desconocida. Las cuotas posteriores a la referencia que ya vencieron se recuperan al guardar.

## Generación y persistencia

El esquema **9** añade planes, calendario, revisiones, conciliaciones y metadatos de origen en movimientos, mediante migración transaccional. Conserva las tablas y registros anteriores; no borra ni reinicia la base. No se necesitan planes para utilizar cuentas antiguas.

Cada cuota tiene identidad persistente `(plan_id, number)` y cada movimiento generado tiene una clave única por plan/número. Insertar el movimiento y asociarlo a la cuota ocurre en la misma transacción; reconstruir el ledger antes del commit valida sus efectos. Un fallo revierte toda la operación. Repetir la revisión no duplica cargos.

Las revisiones se hacen al leer saldos, iniciar/reanudar, navegar hacia saldos y cada minuto mientras la app está activa. Android registra además trabajo persistente con `workmanager`, con intervalo solicitado de 15 minutos. El sistema operativo decide cuándo ejecutarlo; ahorro de batería, cierre forzado y restricciones del fabricante pueden retrasarlo. La consistencia se recupera en la siguiente lectura/apertura, conservando la fecha programada de cada cargo. No se prometen ejecuciones a una hora exacta. El worker abre y cierra su propia conexión; no cierra la conexión de la interfaz.

La integración se compiló en APK debug. Su ejecución con ahorro de batería/cierre forzado debe comprobarse en el teléfono físico. Web utiliza lecturas, reanudación y revisión en primer plano; no tiene worker Android.

Referencia del plugin: [workmanager](https://pub.dev/packages/workmanager) y [registerPeriodicTask](https://pub.dev/documentation/workmanager/latest/workmanager/Workmanager/registerPeriodicTask.html).

## Deuda, gastos y límite

El calendario pendiente representa compromisos futuros, no deuda ya cargada. Cada vencimiento añade una sola mensualidad a la deuda. Los pagos de tarjeta conservan las reglas existentes: reducen deuda y fondos de origen sin reconocer otro gasto.

Los planes de límite ordinario reservan únicamente el capital futuro conocido: `Disponible = máximo(0, límite − deuda ordinaria − reserva futura)`. Al cargar una cuota se retira su capital de la reserva y se añade el cargo a la deuda; no se descuenta dos veces. Intereses/comisiones conocidos se reconocen cuando se cargan. La línea adicional conserva su deuda separada al calcular disponible ordinario y no reserva ese límite. Si hay cuotas adicionales previas incluidas en una apertura, o un pago cuya asignación entre líneas se desconoce, el disponible ordinario se muestra sin determinar. No se inventa una distribución del pago. Si falta límite o hay saldo a favor tampoco se infiere una autorización bancaria.

Si la **compra completa ya existe**, seleccionarla al crear el plan. Debe corresponder a la misma tarjeta, moneda e importe, sin devoluciones ni otro plan. Una conversión identificada reclasifica el capital pendiente fuera de la deuda corriente, conservando el gasto original. Las mensualidades devuelven ese capital a deuda sin reconocerlo otra vez como gasto; solo añaden gastos financieros conocidos. Esta vinculación exige conocer el desglose de capital. El historial conserva la compra y la conversión.

## Conciliación y edición

Los movimientos están identificados como generados por la app y pendientes de conciliación. Son registros de control personal; no ejecutan cobros ni pagos bancarios.

En el detalle del plan, **Conciliar cuota N** permite seleccionar un gasto bancario ya registrado de esa tarjeta, moneda e importe e introducir una referencia. No selecciona coincidencias automáticamente. Se conservan ambos movimientos y una relación explícita: el cargo generado mantiene el efecto financiero y el registro bancario vinculado deja de contarse por segunda vez. Repetir la misma vinculación es idempotente; una relación incompatible se rechaza. El importador de archivos Excel sigue pendiente: por ahora el cargo bancario se registra manualmente y después se vincula mediante este mismo mecanismo.

**Editar cuotas pendientes** modifica descripción, categoría y calendario futuro conservando plazo restante, capital pendiente conocido, modalidad y moneda. Presenta el nuevo calendario antes de guardar. Las cuotas cargadas y sus movimientos no se reescriben; una revisión queda registrada. La nueva fecha pendiente debe quedar en un mes posterior al de la última cuota cargada y no puede ser anterior al día actual. No se registra una liquidación ni se modifican condiciones bancarias.

**Cancelar cargos futuros** conserva los cargos históricos y detiene únicamente los pendientes. No es un pago ni una cancelación bancaria. Los planes distinguen Activo, Completado y Cancelado; “cargadas” no significa “pagadas”. Las devoluciones genéricas de cuotas generadas no se ofrecen: requieren un ajuste específico que aún no está implementado.

## Verificación reproducible

Pruebas con datos sintéticos: calendario bisiesto y cambio de año; última cuota exacta; recuperación de meses; concurrencia/reintentos; planes previos; monedas independientes; límites y líneas adicionales; compra completa sin doble gasto; conciliación explícita; edición/cancelación; rollback de generación y migración v8; reapertura nativa y SQLite web. Pruebas de interfaz cubren creación con vista previa, cancelación y actualización de Cuentas/detalle abierto al reanudar. Las pruebas anteriores de resumen cubren fechas sin configurar, `dd/MM`, 320 px, texto a 1.8 y montos largos.
