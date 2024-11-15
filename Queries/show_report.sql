-- get_payment_report regresa una tabla de los pagos faltantes de un contrato con su monto y fecha.
-- Modifica el número por la ID del contrato deseado.
SELECT
    *
FROM
    get_payment_report (1);