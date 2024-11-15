--
-- PostgreSQL database dump
--

-- Dumped from database version 16.4
-- Dumped by pg_dump version 16.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: add_payment(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.add_payment(payment_contract_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.add_payment(payment_contract_id integer) OWNER TO postgres;

--
-- Name: get_payment_report(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_payment_report(p_contract_id integer) RETURNS TABLE(due_date date, amount_to_pay numeric, payment_status character varying)
    LANGUAGE plpgsql
    AS $$
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
            SELECT *
            FROM PaymentLogs
            WHERE contract_id = p_contract_id AND payment_due_date = v_next_due_date
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
$$;


ALTER FUNCTION public.get_payment_report(p_contract_id integer) OWNER TO postgres;

--
-- Name: new_client(character varying, date, date, numeric, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.new_client(client_name character varying, start_date date, end_date date, total_amount numeric, payment_frequency character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER FUNCTION public.new_client(client_name character varying, start_date date, end_date date, total_amount numeric, payment_frequency character varying) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: contracts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.contracts (
    contract_id integer NOT NULL,
    client_name character varying(255) NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    total_amount numeric(15,2) NOT NULL,
    payment_frequency character varying(15) NOT NULL,
    partial_payment_amount numeric(15,2) NOT NULL,
    next_due_date date NOT NULL,
    remaining_balance numeric(15,2),
    status boolean DEFAULT true NOT NULL,
    CONSTRAINT contracts_payment_frequency_check CHECK (((payment_frequency)::text = ANY ((ARRAY['weekly'::character varying, 'monthly'::character varying, 'quarterly'::character varying, 'semiannually'::character varying, 'annually'::character varying])::text[])))
);


ALTER TABLE public.contracts OWNER TO postgres;

--
-- Name: contracts_contract_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.contracts_contract_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.contracts_contract_id_seq OWNER TO postgres;

--
-- Name: contracts_contract_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.contracts_contract_id_seq OWNED BY public.contracts.contract_id;


--
-- Name: paymentlogs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.paymentlogs (
    payment_id integer NOT NULL,
    contract_id integer NOT NULL,
    payment_amount numeric(15,2) NOT NULL,
    payment_due_date date NOT NULL
);


ALTER TABLE public.paymentlogs OWNER TO postgres;

--
-- Name: paymentlogs_payment_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.paymentlogs_payment_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.paymentlogs_payment_id_seq OWNER TO postgres;

--
-- Name: paymentlogs_payment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.paymentlogs_payment_id_seq OWNED BY public.paymentlogs.payment_id;


--
-- Name: contracts contract_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contracts ALTER COLUMN contract_id SET DEFAULT nextval('public.contracts_contract_id_seq'::regclass);


--
-- Name: paymentlogs payment_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.paymentlogs ALTER COLUMN payment_id SET DEFAULT nextval('public.paymentlogs_payment_id_seq'::regclass);


--
-- Data for Name: contracts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.contracts (contract_id, client_name, start_date, end_date, total_amount, payment_frequency, partial_payment_amount, next_due_date, remaining_balance, status) FROM stdin;
2	John Doe	2024-01-01	2025-02-01	1200.00	monthly	92.31	2025-02-03	0.00	f
3	John Doe	2024-01-01	2024-02-05	1200.00	weekly	240.00	2024-01-01	1200.00	t
1	John Doe	2024-01-01	2025-01-06	1200.00	weekly	22.64	2024-01-15	1154.72	t
4	John Doe	2024-01-01	2027-01-01	1200.00	annually	400.00	2025-01-01	800.00	t
\.


--
-- Data for Name: paymentlogs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.paymentlogs (payment_id, contract_id, payment_amount, payment_due_date) FROM stdin;
1	1	22.64	2024-01-01
2	2	92.31	2024-01-01
3	2	92.31	2024-02-01
4	2	92.31	2024-03-01
5	2	92.31	2024-04-01
6	2	92.31	2024-05-01
7	2	92.31	2024-06-01
8	2	92.31	2024-07-01
9	2	92.31	2024-08-01
10	2	92.31	2024-09-02
11	2	92.31	2024-10-02
12	2	92.31	2024-11-02
13	2	92.31	2024-12-02
14	2	92.31	2025-01-02
15	1	22.64	2024-01-08
16	4	400.00	2024-01-01
\.


--
-- Name: contracts_contract_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.contracts_contract_id_seq', 4, true);


--
-- Name: paymentlogs_payment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.paymentlogs_payment_id_seq', 16, true);


--
-- Name: contracts contracts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.contracts
    ADD CONSTRAINT contracts_pkey PRIMARY KEY (contract_id);


--
-- Name: paymentlogs paymentlogs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.paymentlogs
    ADD CONSTRAINT paymentlogs_pkey PRIMARY KEY (payment_id);


--
-- Name: paymentlogs paymentlogs_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.paymentlogs
    ADD CONSTRAINT paymentlogs_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES public.contracts(contract_id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

