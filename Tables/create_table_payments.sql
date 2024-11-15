CREATE TABLE
    PaymentLogs (
        payment_id SERIAL PRIMARY KEY, -- Unique identifier for each payment record
        contract_id INT NOT NULL, -- The contract to which the payment belongs
        payment_amount DECIMAL(15, 2) NOT NULL, -- The amount paid in this specific payment
        payment_due_date DATE NOT NULL, -- The due date this payment represents
        FOREIGN KEY (contract_id) REFERENCES Contracts (contract_id) ON DELETE CASCADE -- Reference to the Contracts table
    );