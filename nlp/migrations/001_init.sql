CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS documents (
  id UUID PRIMARY KEY,
  title TEXT,
  classification TEXT,
  hash_hex TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  original_path TEXT,
  raw_bytes BYTEA,
  fingerprint TEXT
);

CREATE TABLE IF NOT EXISTS embeddings (
  doc_id UUID REFERENCES documents(id) ON DELETE CASCADE,
  chunk_index INT,
  content TEXT,
  embedding vector(768),
  PRIMARY KEY (doc_id, chunk_index)
);

CREATE INDEX ON embeddings USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
