CREATE
OR REPLACE FUNCTION new_client (
    client_name VARCHAR,
    start_date DATE,
    end_date DATE,
    total_amount DECIMAL(15, 2),
    payment_frequency VARCHAR
) RETURNS VOID AS $$
DECLARE
    partial_payment_amount DECIMAL(15, 2);
    adjusted_end_date DATE;
    adjusted_start_date DATE;
    next_due_date DATE;
    remaining_balance DECIMAL(15, 2);
    days_diff INT;
BEGIN
    -- Adjust start date and end date if they are on Sunday (move to Monday)
    IF EXTRACT(DOW FROM start_date) = 0 THEN
        adjusted_start_date := start_date + INTERVAL '1 day';  -- Move to Monday
    ELSE
        adjusted_start_date := start_date;
    END IF;

    IF EXTRACT(DOW FROM end_date) = 0 THEN
        adjusted_end_date := end_date + INTERVAL '1 day';  -- Move to Monday
    ELSE
        adjusted_end_date := end_date;
    END IF;

    -- Ensure start date is before end date
    IF adjusted_start_date >= adjusted_end_date THEN
        RAISE EXCEPTION 'Start date must be before end date';
    END IF;

    -- Calculate the difference in days between start_date and end_date
    days_diff := adjusted_end_date - adjusted_start_date;

    -- Check if the difference in days is greater than 0 to avoid division by 0
    IF days_diff <= 0 THEN
        RAISE EXCEPTION 'End date must be later than start date';
    END IF;

    -- Adjust end date according to payment frequency
    IF payment_frequency = 'weekly' THEN
        -- Add full weeks to align the end date
        adjusted_end_date := adjusted_start_date + INTERVAL '1 week' * CEIL(days_diff / 7.0);
    ELSIF payment_frequency = 'monthly' THEN
        -- Add months to align the end date (approximate 30 days per month)
        adjusted_end_date := adjusted_start_date + INTERVAL '1 month' * CEIL(days_diff / 30.0);
    ELSIF payment_frequency = 'quarterly' THEN
        -- Add 3 months for quarterly (approximate 90 days per quarter)
        adjusted_end_date := adjusted_start_date + INTERVAL '3 months' * CEIL(days_diff / 90.0);
    ELSIF payment_frequency = 'semiannually' THEN
        -- Add 6 months for semiannually (approximate 180 days per half year)
        adjusted_end_date := adjusted_start_date + INTERVAL '6 months' * CEIL(days_diff / 180.0);
    ELSIF payment_frequency = 'annually' THEN
        -- Add 12 months for annually (approximate 365 days per year)
        adjusted_end_date := adjusted_start_date + INTERVAL '1 year' * CEIL(days_diff / 365.0);
    END IF;

    -- Calculate partial payment amount
    IF payment_frequency = 'weekly' THEN
        partial_payment_amount := total_amount / CEIL(days_diff / 7.0);
    ELSIF payment_frequency = 'monthly' THEN
        partial_payment_amount := total_amount / CEIL(days_diff / 30.0);
    ELSIF payment_frequency = 'quarterly' THEN
        partial_payment_amount := total_amount / CEIL(days_diff / 90.0);
    ELSIF payment_frequency = 'semiannually' THEN
        partial_payment_amount := total_amount / CEIL(days_diff / 180.0);
    ELSIF payment_frequency = 'annually' THEN
        partial_payment_amount := total_amount / CEIL(days_diff / 365.0);
    END IF;

    -- Set the next due date as the start date
    next_due_date := adjusted_start_date;

    -- Set the remaining balance to the total amount
    remaining_balance := total_amount;

    -- Insert the new contract into the Contracts table
    INSERT INTO Contracts (
        client_name, start_date, end_date, total_amount, payment_frequency,
        partial_payment_amount, next_due_date, remaining_balance, status
    )
    VALUES (
        client_name, adjusted_start_date, adjusted_end_date, total_amount, payment_frequency,
        partial_payment_amount, next_due_date, remaining_balance, TRUE
    );
END;
$$ LANGUAGE plpgsql;