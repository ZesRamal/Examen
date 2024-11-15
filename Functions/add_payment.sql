CREATE
OR REPLACE FUNCTION add_payment (payment_contract_id INT) RETURNS VOID AS $$
DECLARE
    v_contract Contracts%ROWTYPE;
    v_new_due_date DATE;
BEGIN
    -- Fetch contract details for the given payment_contract_id
    SELECT * INTO v_contract
    FROM Contracts
    WHERE contract_id = payment_contract_id AND status = TRUE;

    -- If the contract does not exist or is already completed, exit
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Contract not found or already completed';
    END IF;

    -- Insert payment into PaymentLogs
    INSERT INTO PaymentLogs (contract_id, payment_amount, payment_due_date)
    VALUES (
        v_contract.contract_id,
        v_contract.partial_payment_amount,
        v_contract.next_due_date
    );

    -- Update remaining balance (subtract the partial payment amount)
    v_contract.remaining_balance := v_contract.remaining_balance - v_contract.partial_payment_amount;

    -- If remaining balance is 0, change the contract status to FALSE (completed)
    IF v_contract.remaining_balance <= 0 THEN
        v_contract.remaining_balance := 0;
        v_contract.status := FALSE;
    END IF;

    -- Calculate the new next_due_date based on the payment_frequency
    CASE v_contract.payment_frequency
        WHEN 'weekly' THEN
            v_new_due_date := v_contract.next_due_date + INTERVAL '1 week';
        WHEN 'monthly' THEN
            v_new_due_date := v_contract.next_due_date + INTERVAL '1 month';
        WHEN 'quarterly' THEN
            v_new_due_date := v_contract.next_due_date + INTERVAL '3 months';
        WHEN 'semiannually' THEN
            v_new_due_date := v_contract.next_due_date + INTERVAL '6 months';
        WHEN 'annually' THEN
            v_new_due_date := v_contract.next_due_date + INTERVAL '1 year';
    END CASE;

    -- If the new due date falls on a Sunday, adjust it to Monday
    IF EXTRACT(DOW FROM v_new_due_date) = 0 THEN
        v_new_due_date := v_new_due_date + INTERVAL '1 day';
    END IF;

    -- Update the contract with the new due date and remaining balance
    UPDATE Contracts
    SET next_due_date = v_new_due_date,
        remaining_balance = v_contract.remaining_balance,
        status = v_contract.status
    WHERE contract_id = v_contract.contract_id;
    
END;
$$ LANGUAGE plpgsql;