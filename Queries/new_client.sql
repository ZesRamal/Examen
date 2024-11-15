-- La función new_client crea una nueva entrada en la tabla Contracts.
-- Módifica los parámetros según la descripción que se indica.
SELECT
    new_client (
        'John Doe', -- Nombre del Cliente
        '2024-01-01', -- Fecha Inicial
        '2024-02-01', -- Fecha Final
        1200.00, -- Monto Total a Pagar
        'weekly' -- Frecuencia de Pago (weekly, monthly, quarterly,semiannually,annually)
    );