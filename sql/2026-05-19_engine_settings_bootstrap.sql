-- ============================================================
-- Bootstrap completo da tabela engine_settings (id=1)
-- Idempotente: pode ser corrido várias vezes sem efeito secundário.
-- ============================================================

CREATE TABLE IF NOT EXISTS engine_settings (
  id                       int PRIMARY KEY,
  kerf_disco_mm            numeric(6,3) NOT NULL DEFAULT 3.20,
  kerf_fita_mm             numeric(6,3) NOT NULL DEFAULT 2.50,
  cap_costaneiros          int          NOT NULL DEFAULT 3,
  pi_value                 numeric(8,6) NOT NULL DEFAULT 3.14,
  ratio_ton_m3             numeric(6,3) NOT NULL DEFAULT 2.130,
  preco_eur_ton            numeric(7,2) NOT NULL DEFAULT 85.00,
  density_rolaria_ton_m3   numeric(6,3) NOT NULL DEFAULT 0.85,
  demand_tolerance_pct     numeric(6,3) NOT NULL DEFAULT 10.0,
  updated_at               timestamptz  NOT NULL DEFAULT now(),
  updated_by               text,
  notes                    text
);

-- Caso a tabela já existisse com schema antigo, garante colunas em falta
ALTER TABLE engine_settings
  ADD COLUMN IF NOT EXISTS density_rolaria_ton_m3 numeric(6,3) NOT NULL DEFAULT 0.85,
  ADD COLUMN IF NOT EXISTS demand_tolerance_pct   numeric(6,3) NOT NULL DEFAULT 10.0;

-- Seed do registo id=1 (apenas se ainda não existir)
INSERT INTO engine_settings (
  id, kerf_disco_mm, kerf_fita_mm, cap_costaneiros, pi_value,
  ratio_ton_m3, preco_eur_ton, density_rolaria_ton_m3, demand_tolerance_pct, notes
)
VALUES (1, 3.20, 2.50, 3, 3.14, 2.130, 85.00, 0.85, 10.0, 'Bootstrap canónico — 2026-05-19')
ON CONFLICT (id) DO NOTHING;

-- RLS aberto para utilizadores autenticados (ajustar depois para produção)
ALTER TABLE engine_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "engine_settings_authenticated_all" ON engine_settings;
CREATE POLICY "engine_settings_authenticated_all"
  ON engine_settings FOR ALL
  TO authenticated
  USING (true) WITH CHECK (true);

-- Verificação
SELECT * FROM engine_settings WHERE id = 1;
