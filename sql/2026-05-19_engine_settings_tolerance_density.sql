-- Migration: 2026-05-19
-- Adiciona density_rolaria_ton_m3 e demand_tolerance_pct à tabela engine_settings.
-- Densidade: canónico 0.85 ton/m³ (pinho fresco PT).
-- Tolerância demanda: banda ±% que o LP pode entregar acima/abaixo do nominal por produto.
-- Default 10% = ±10%.

ALTER TABLE engine_settings
  ADD COLUMN IF NOT EXISTS density_rolaria_ton_m3 numeric(6,3) NOT NULL DEFAULT 0.85,
  ADD COLUMN IF NOT EXISTS demand_tolerance_pct   numeric(6,3) NOT NULL DEFAULT 10.0;

-- Garantir que o registo id=1 tem os defaults (caso já existisse sem estas colunas)
UPDATE engine_settings
   SET density_rolaria_ton_m3 = COALESCE(density_rolaria_ton_m3, 0.85),
       demand_tolerance_pct   = COALESCE(demand_tolerance_pct,   10.0)
 WHERE id = 1;
