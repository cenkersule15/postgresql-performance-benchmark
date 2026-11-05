CREATE TABLE IF NOT EXISTS events (
    event_id BIGINT PRIMARY KEY,

    event_ts TIMESTAMPTZ NOT NULL,

    customer_id INTEGER NOT NULL
        CHECK (customer_id BETWEEN 1 AND 100000),

    product_id INTEGER NOT NULL
        CHECK (product_id BETWEEN 1 AND 2000),

    region TEXT NOT NULL
        CHECK (region IN (
            'North',
            'South',
            'East',
            'West',
            'Central'
        )),

    quantity INTEGER NOT NULL
        CHECK (quantity BETWEEN 1 AND 5),

    unit_price_cents INTEGER NOT NULL
        CHECK (unit_price_cents >= 0),

    status TEXT NOT NULL
        CHECK (status IN (
            'completed',
            'cancelled',
            'pending'
        ))
);