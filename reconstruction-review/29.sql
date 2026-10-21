-- =============================================================================
-- Peer-review reconstruction — "NYC taxi" ER mermaid diagram

-- Ambiguities / assumptions made while reconstructing:

--   1. The diagram's "has" relationship is 1:1 between trip and trip_payment.
--      TRIP_PAYMENT.trip_id is both PK and FK, following that relationship.
--   2. Required relationship FKs are NOT NULL; unspecified descriptive fields
--      are nullable because the diagram does not mark their nullability.
--   3. IDs use INT/BIGINT, amounts DECIMAL(8,2), and instants TIMESTAMP;
--      precision, lengths and time zones were not specified in the diagram.

-- =============================================================================

DROP TABLE IF EXISTS trip_payment;
DROP TABLE IF EXISTS trip;
DROP TABLE IF EXISTS payment_type;
DROP TABLE IF EXISTS rate_code;
DROP TABLE IF EXISTS location;
DROP TABLE IF EXISTS vendor;

CREATE TABLE vendor (
    vendor_id   INT PRIMARY KEY,
    vendor_name VARCHAR(100) NOT NULL
);

CREATE TABLE location (
    location_id  INT PRIMARY KEY,
    borough      VARCHAR(100),
    zone         VARCHAR(100),
    service_zone VARCHAR(100)
);

CREATE TABLE rate_code (
    rate_code_id          INT PRIMARY KEY,
    rate_code_description VARCHAR(100) NOT NULL
);

CREATE TABLE payment_type (
    payment_type_id          INT PRIMARY KEY,
    payment_type_description VARCHAR(100) NOT NULL
);

CREATE TABLE trip (
    trip_id                BIGINT PRIMARY KEY,
    vendor_id               INT NOT NULL REFERENCES vendor(vendor_id),
    pickup_datetime          TIMESTAMP NOT NULL,
    dropoff_datetime         TIMESTAMP NOT NULL,
    passenger_count          INT,
    trip_distance             DECIMAL(8, 2),
    rate_code_id             INT NOT NULL REFERENCES rate_code(rate_code_id),
    store_and_forward_flag   CHAR(1),
    pickup_location_id       INT NOT NULL REFERENCES location(location_id),
    dropoff_location_id      INT NOT NULL REFERENCES location(location_id)
);

--weak entity
CREATE TABLE trip_payment (
    trip_id                BIGINT PRIMARY KEY REFERENCES trip(trip_id) ON DELETE CASCADE,
    payment_type_id          INT NOT NULL REFERENCES payment_type(payment_type_id),
    fare_amount               DECIMAL(8, 2),
    extra                      DECIMAL(8, 2),
    mta_tax                    DECIMAL(8, 2),
    tip_amount                  DECIMAL(8, 2),
    tolls_amount                DECIMAL(8, 2),
    improvement_surcharge       DECIMAL(8, 2),
    total_amount                  DECIMAL(8, 2),
    congestion_surcharge        DECIMAL(8, 2),
    airport_fee                   DECIMAL(8, 2)
);
