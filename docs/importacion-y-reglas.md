# Importación del histórico y reglas financieras

## Evidencia disponible

La propuesta se basa en encabezados, categorías y tres filas mostradas en las capturas del usuario. El archivo completo `Gastos Personales TC.xlsx` no pudo abrirse durante la revisión. No se afirma haber auditado todo el histórico.

Las fórmulas toman Crédito si está informado y, en caso contrario, Débito. El texto calculado Crédito/Débito representa el lado original del registro, no el tipo de tarjeta ni una clasificación de ingreso/gasto.

## Correspondencia de campos

| Excel | Tratamiento |
| --- | --- |
| Fecha | Fecha de operación. Las fechas textuales de la muestra están en día/mes/año; comprobar también fechas numéricas de Excel. |
| Descripción | Conservar el texto original sin sobrescribirlo al categorizar. |
| Sub-descripción | Conservar la etiqueta original y enlazar una categoría normalizada. No implica suscripción recurrente. |
| Crédito / Débito | Conservar importe y lado original. Mapear su efecto según cuenta y tipo de operación. |
| Monto | Importe de control contra el lado informado. No crea un movimiento adicional. |
| TipoMovimiento | Texto Crédito/Débito de origen; contrastarlo con importes. No es tipo de tarjeta. |
| Año / Mes / Día | Controles opcionales; derivar valores de consulta desde la fecha validada. |
| BANCO | Banco relacionado; no identifica una tarjeta de forma única. |

El modelo necesita además identificador de cuenta/tarjeta, moneda, tipo de operación e identificador estable del movimiento. Asignar cuenta/moneda por lote solo si la hoja es homogénea. Las hojas mezcladas requieren asignación por fila. No se ha confirmado cómo se distribuyen cuentas y monedas en el archivo completo.

Conservar lote, nombre de archivo, hoja, número de fila y valores de origen necesarios para rastrear el registro. La huella del archivo y la posición de la fila permiten reconocer el mismo archivo, pero no bastan para detectar solapamientos o archivos reordenados.

## Categorías observadas

Supermercados, Educación, Comisión y financiamiento, Telefonía e Internet, Restaurantes, Tecnología, Farmacias, Gasolineras, Traslado compra, Ópticas, Diversión, Zapaterías, Ropa, Adelanto de efectivo, Impuestos, Repuestos, Pago parqueos, Extorno membresía, Pago TC y Canje de puntos.

Conservar etiquetas originales y proponer acentuación como normalización de catálogo. No fusionar categorías automáticamente. Pago TC, Adelanto de efectivo o Extorno membresía pueden sugerir operaciones, pero su confirmación debe considerar descripción, sentido y cuenta.

## Efecto financiero

| Operación | Efecto | Reporte |
| --- | --- | --- |
| Compra con crédito | Aumenta deuda. | Un gasto. |
| Compra con débito | Reduce saldo bancario vinculado. | Un gasto. |
| Pago de tarjeta | Reduce deuda y cuenta de origen si se conoce. | Transferencia, sin nuevo gasto ni ingreso. |
| Adelanto de efectivo | Aumenta deuda y efectivo controlado si se confirma destino. | Transferencia; intereses/comisiones son gastos separados. |
| Retiro con débito | Reduce banco y aumenta efectivo controlado. | Transferencia, sin gasto por el principal. |
| Devolución o extorno | Revierte deuda o devuelve fondos. | Reversión del gasto correspondiente. |
| Comisión o interés | Aumenta deuda o reduce fondos según la cuenta. | Gasto financiero. |
| Canje de puntos | Depende de cómo se aplica. | Revisar sin asumir ingreso ni devolución. |

Si un pago aparece en ambas fuentes, vincular sus registros a una sola transferencia. Si falta la cuenta de origen, registrar solo la cara conocida y marcar vinculación pendiente. No inventar una salida ni borrar el abono. Conciliar sin exigir contraparte para todo el histórico.

Registrar saldo o deuda inicial con fecha anterior al primer movimiento importado y contrastar con estados de cuenta. Un histórico incompleto no permite reconstruir saldos definitivos. El límite de crédito no es dinero disponible.

Una misma tarjeta de crédito puede mantener deuda, apertura y límite independientes en GTQ y USD. Cada movimiento conserva su moneda y afecta solo ese saldo; pagar USD no reduce deuda GTQ. La segunda apertura sin registrar no equivale a cero. Monetario/Ahorro identifica el tipo de cuenta bancaria, no su moneda. Editar una apertura exige validar nuevamente todo el historial sin alterar los movimientos originales.

## Secuencia de carga

1. Seleccionar archivo y hoja, identificar encabezados y previsualizar filas.
2. Asignar cuenta/tarjeta y moneda o mapear sus columnas si están mezcladas.
3. Convertir fechas e importes sin perder precisión. Distinguir vacío de cero; revisar ceros y negativos sin asumir su significado.
4. Separar filas válidas, errores y operaciones pendientes. Ambos lados informados o ninguno requieren revisión.
5. Mostrar cantidad y totales por cuenta, moneda, cargos/abonos y operación propuesta.
6. Revisar referencias, reimportaciones y coincidencias ambiguas. Dos compras de igual fecha e importe pueden ser legítimas.
7. Confirmar y guardar las filas aprobadas del lote de forma atómica, con reporte de excluidas y sin omisiones silenciosas. Revertir si falla la escritura.
8. Conciliar saldos y conservar trazabilidad. Reimportar el mismo lote no debe repetir movimientos.

Probar archivos idénticos, reordenados, parcialmente solapados y compras repetidas legítimas. Un hash de fecha, descripción e importe no es por sí solo una referencia bancaria única.

## Privacidad y recurrencia

Usar `local_data/` o `imports/` para archivos reales, `exports/` para resultados y `backups/` para respaldos. Estas rutas están ignoradas. Las muestras en `test/fixtures/` deben ser sintéticas. No almacenar CVV, PIN ni números completos de tarjeta.

Telefonía e Internet no confirma una suscripción. La recurrencia se configura aparte y genera previsiones o recordatorios. El gasto real se registra al confirmar el cargo.
