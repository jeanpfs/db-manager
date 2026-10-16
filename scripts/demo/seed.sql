-- Fictional shop schema + data. Run once per database (shop_dev, shop_prod).
CREATE TABLE customers (
  id serial PRIMARY KEY,
  name text NOT NULL,
  email text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE orders (
  id integer PRIMARY KEY,
  customer_id integer NOT NULL REFERENCES customers(id),
  total numeric(10,2) NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','paid','refunded')),
  created_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO customers (name, email) VALUES
  ('Ada Lovelace','ada@example.com'),('Grace Hopper','grace@example.com'),
  ('Alan Turing','alan@example.com'),('Linus Pauling','linus@example.com'),
  ('Marie Curie','marie@example.com'),('Niels Bohr','niels@example.com');
INSERT INTO orders (id, customer_id, total, status, created_at) VALUES
  (1038,1,24.90,'paid',now()-interval '9 days'),
  (1039,2,112.00,'paid',now()-interval '8 days'),
  (1040,3,59.50,'refunded',now()-interval '7 days'),
  (1041,4,18.00,'paid',now()-interval '6 days'),
  (1042,5,249.00,'pending',now()-interval '5 days'),
  (1043,6,36.75,'paid',now()-interval '4 days'),
  (1044,1,89.99,'pending',now()-interval '3 days'),
  (1045,2,14.20,'paid',now()-interval '3 days'),
  (1046,3,310.00,'paid',now()-interval '2 days'),
  (1047,4,47.30,'pending',now()-interval '2 days'),
  (1048,5,22.00,'paid',now()-interval '1 day'),
  (1049,6,75.10,'refunded',now()-interval '1 day'),
  (1050,1,128.40,'paid',now()-interval '20 hours'),
  (1051,2,9.90,'pending',now()-interval '6 hours'),
  (1052,3,64.00,'paid',now()-interval '2 hours');
