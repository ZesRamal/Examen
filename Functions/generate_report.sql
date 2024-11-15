CREATE
OR REPLACE FUNCTION get_payment_report (p_contract_id INT) RETURNS TABLE (
    due_date DATE,
    amount_to_pay DECIMAL(15, 2),
    payment_status VARCHAR
) AS $$
DECLARE
    v_next_due_date DATE;
    v_end_date DATE;
    v_payment_frequency VARCHAR;
    v_partial_payment_amount DECIMAL(15, 2);
BEGIN
    -- Retrieve contract details
    SELECT next_due_date, end_date, payment_frequency, partial_payment_amount
    INTO v_next_due_date, v_end_date, v_payment_frequency, v_partial_payment_amount
    FROM Contracts
    WHERE contract_id = p_contract_id;

    -- Loop over the due dates, starting from the next_due_date until the end_date
    WHILE v_next_due_date <= v_end_date LOOP
        -- Set the current row's due date and amount to pay
        due_date := v_next_due_date;
        amount_to_pay := v_partial_payment_amount;

        -- Check if a payment exists for the current due date and contract_id
        IF EXISTS (
            SELECT 1
            FROM PaymentLogs
            WHERE contract_id = p_contract_id
              AND DATE(payment_due_date) = v_next_due_date  -- Ensure we are comparing the DATE part
        ) THEN
            -- If a payment exists, the status is 'Paid'
            payment_status := 'Paid';
        ELSE
            -- If no payment exists, the status is 'Pending'
            payment_status := 'Pending';
        END IF;

        -- Return the row with the assigned values
        RETURN NEXT;

        -- Move to the next due date based on the payment frequency
        CASE 
            WHEN v_payment_frequency = 'weekly' THEN
                v_next_due_date := v_next_due_date + INTERVAL '1 week';
            WHEN v_payment_frequency = 'monthly' THEN
                v_next_due_date := v_next_due_date + INTERVAL '1 month';
            WHEN v_payment_frequency = 'quarterly' THEN
                v_next_due_date := v_next_due_date + INTERVAL '3 months';
            WHEN v_payment_frequency = 'semiannually' THEN
                v_next_due_date := v_next_due_date + INTERVAL '6 months';
            WHEN v_payment_frequency = 'annually' THEN
                v_next_due_date := v_next_due_date + INTERVAL '1 year';
            ELSE
                RAISE EXCEPTION 'Invalid payment frequency: %', v_payment_frequency;
        END CASE;
    END LOOP;
    
    RETURN;
END;
$$ LANGUAGE plpgsql;