-- ============================================================
-- Fase B passo 1: schema para histórico de compras
-- Source files:
--   1) 05. MCF - Evol. Ent. Mad. (mai26).xlsx → sheet "03. Evolução Mensal"
--      ─ volumes em ton por (comprimento × gama × mês)
--   2) Historico compras por gama.xlsx → sheet Wood_Trend_YOY (2º pivot)
--      ─ preços €/ton por (empresa × país × designação × mês)
--
-- Idempotente: pode ser corrido várias vezes.
-- ============================================================

-- Tabela granular: 1 linha por (empresa × país × comprimento × gama × ano × mês)
CREATE TABLE IF NOT EXISTS compras_historico (
  id              bigserial PRIMARY KEY,
  empresa         text NOT NULL,
  pais            text NOT NULL,                       -- 'PT' | 'ES' | '(em branco)'
  comprimento_mm  int  NOT NULL,                       -- 2100 | 2500 | 2600 | 2750
  gama_compras    text NOT NULL,                       -- '≥15AC' | '≥25AC' | 'CANTER'
  ano             int  NOT NULL,
  mes             int  NOT NULL CHECK (mes BETWEEN 1 AND 12),
  ton             numeric(12,3),                       -- volume entregue
  eur_per_ton     numeric(8,2),                        -- preço médio do mês
  designacao_orig text,                                -- nome bruto do produto
  empresa_orig    text,                                -- nome bruto do fornecedor
  uploaded_at     timestamptz NOT NULL DEFAULT now(),
  source_row      int,                                 -- linha do Excel (debug)
  UNIQUE (empresa, pais, comprimento_mm, gama_compras, ano, mes, empresa_orig)
);

CREATE INDEX IF NOT EXISTS idx_compras_ano_mes ON compras_historico (ano, mes);
CREATE INDEX IF NOT EXISTS idx_compras_comp_gama ON compras_historico (comprimento_mm, gama_compras);
CREATE INDEX IF NOT EXISTS idx_compras_pais ON compras_historico (pais);

ALTER TABLE compras_historico ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "compras_historico_authenticated_all" ON compras_historico;
CREATE POLICY "compras_historico_authenticated_all"
  ON compras_historico FOR ALL
  TO authenticated
  USING (true) WITH CHECK (true);


-- ============================================================
-- View: mix 2025 agregado por (comprimento × gama × país)
-- Usado pelo LP Fase B como baseline para constraint ±15%
-- ============================================================
CREATE OR REPLACE VIEW compras_mix_2025 AS
WITH base AS (
  SELECT
    comprimento_mm,
    gama_compras,
    pais,
    SUM(ton)         AS ton_total,
    -- preço médio ponderado por volume
    CASE WHEN SUM(ton) > 0
         THEN SUM(ton * eur_per_ton) / SUM(ton)
         ELSE AVG(eur_per_ton) END AS eur_per_ton_avg
  FROM compras_historico
  WHERE ano = 2025
    AND ton IS NOT NULL
    AND ton > 0
  GROUP BY comprimento_mm, gama_compras, pais
)
SELECT
  comprimento_mm,
  gama_compras,
  pais,
  ton_total,
  eur_per_ton_avg,
  -- Banda ±15% para LP
  ton_total * 0.85 AS ton_min_lp,
  ton_total * 1.15 AS ton_max_lp,
  -- Share dentro do (comprimento × gama)
  ton_total / NULLIF(SUM(ton_total) OVER (PARTITION BY comprimento_mm, gama_compras), 0) AS share_pais
FROM base
ORDER BY comprimento_mm, gama_compras, pais;


-- ============================================================
-- View auxiliar: mix por (comprimento × gama) total — útil para UI
-- ============================================================
CREATE OR REPLACE VIEW compras_mix_2025_total AS
SELECT
  comprimento_mm,
  gama_compras,
  SUM(ton_total)    AS ton_total,
  -- preço médio ponderado por volume (over país)
  CASE WHEN SUM(ton_total) > 0
       THEN SUM(ton_total * eur_per_ton_avg) / SUM(ton_total)
       ELSE NULL END AS eur_per_ton_avg,
  SUM(ton_total) * 0.85 AS ton_min_lp,
  SUM(ton_total) * 1.15 AS ton_max_lp
FROM compras_mix_2025
GROUP BY comprimento_mm, gama_compras
ORDER BY comprimento_mm, gama_compras;


-- ============================================================
-- Verificação rápida
-- ============================================================
-- SELECT * FROM compras_mix_2025;
-- SELECT * FROM compras_mix_2025_total;
-- SELECT SUM(ton_total) FROM compras_mix_2025;  -- deve dar ~76 062 ton para 2025
