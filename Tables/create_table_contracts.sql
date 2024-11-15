CREATE TABLE
    Contracts (
        contract_id SERIAL PRIMARY KEY, -- Unique identifier for the contract
        client_name VARCHAR(255) NOT NULL, -- Name of the client
        start_date DATE NOT NULL, -- Starting date of the contract
        end_date DATE NOT NULL, -- Ending date of the contract
        total_amount DECIMAL(15, 2) NOT NULL, -- Total amount to be paid for the contract
        payment_frequency VARCHAR(15) NOT NULL CHECK (
            payment_frequency IN (
                'weekly',
                'monthly',
                'quarterly',
                'semiannually',
                'annually'
            )
        ), -- Frequency of payments
        partial_payment_amount DECIMAL(15, 2) NOT NULL, -- Amount of each partial payment
        next_due_date DATE NOT NULL, -- The next due date for payment
        remaining_balance DECIMAL(15, 2),
        status BOOLEAN NOT NULL DEFAULT TRUE -- Contract status (TRUE for pending, FALSE for completed)
    );