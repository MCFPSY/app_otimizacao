-- ============================================================
-- Fase B — schema v2 (simplificado)
-- Substitui v1 (2026-05-20_compras_historico.sql)
-- Razão: separar volumes/preços/share país em tabelas dedicadas
--        em vez de uma tabela "tudo dentro" com nulls.
-- ============================================================

-- Limpar v1
DROP VIEW IF EXISTS compras_mix_2025_total;
DROP VIEW IF EXISTS compras_mix_2025;
DROP TABLE IF EXISTS compras_historico;

-- ────────────────────────────────────────────────────────────
-- Volumes anuais por (ano × comprimento × gama)
-- Fonte: '05. MCF - Evol. Ent. Mad. (mai26).xlsx' / sheet '03. Evolução Mensal'
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS compras_volumes (
  id              bigserial PRIMARY KEY,
  ano             int NOT NULL,
  comprimento_mm  int NOT NULL,            -- 2100 | 2500 | 2600 | 2750
  gama_compras    text NOT NULL,           -- '≥15AC' | '≥25AC' | 'CANTER'
  ton             numeric(12,3) NOT NULL,  -- volume anual entregue
  uploaded_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (ano, comprimento_mm, gama_compras)
);

CREATE INDEX IF NOT EXISTS idx_compras_vol_ano ON compras_volumes (ano);

ALTER TABLE compras_volumes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "compras_volumes_authenticated_all" ON compras_volumes;
CREATE POLICY "compras_volumes_authenticated_all"
  ON compras_volumes FOR ALL TO authenticated USING (true) WITH CHECK (true);


-- ────────────────────────────────────────────────────────────
-- Preços mensais por (ano × mês × comprimento × gama × país × designação)
-- Fonte: 'Historico compras por gama.xlsx' / sheet Wood_Trend_YOY (2º pivot)
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS compras_precos (
  id              bigserial PRIMARY KEY,
  ano             int NOT NULL,
  mes             int NOT NULL CHECK (mes BETWEEN 1 AND 12),
  comprimento_mm  int NOT NULL,
  gama_compras    text NOT NULL,
  pais            text NOT NULL,          -- 'PT' | 'ES' | 'OUTRO'
  eur_per_ton     numeric(8,2) NOT NULL,
  designacao_orig text,                   -- "Rolaria de Pinho 2,52/25 Acima..."
  uploaded_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (ano, mes, comprimento_mm, gama_compras, pais, designacao_orig)
);

CREATE INDEX IF NOT EXISTS idx_compras_pre_ano_mes ON compras_precos (ano, mes);
CREATE INDEX IF NOT EXISTS idx_compras_pre_gama   ON compras_precos (comprimento_mm, gama_compras);

ALTER TABLE compras_precos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "compras_precos_authenticated_all" ON compras_precos;
CREATE POLICY "compras_precos_authenticated_all"
  ON compras_precos FOR ALL TO authenticated USING (true) WITH CHECK (true);


-- ────────────────────────────────────────────────────────────
-- Share país de cada ano (Nacional vs Espanha)
-- Fonte: '05. MCF - Evol. Ent. Mad.' linhas 36-37 ('Nacional', 'Espanha')
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS compras_pais_share (
  ano         int PRIMARY KEY,
  share_pt    numeric(5,4) NOT NULL,
  share_es    numeric(5,4) NOT NULL,
  uploaded_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE compras_pais_share ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "compras_pais_share_authenticated_all" ON compras_pais_share;
CREATE POLICY "compras_pais_share_authenticated_all"
  ON compras_pais_share FOR ALL TO authenticated USING (true) WITH CHECK (true);


-- ────────────────────────────────────────────────────────────
-- View principal: mix 2025 com banda ±15%, preço médio anual ponderado,
-- e share país (para constraint estratégica do LP).
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW compras_mix_2025 AS
SELECT
  v.comprimento_mm,
  v.gama_compras,
  v.ton AS ton_total,
  -- Preço médio (média simples dos meses de 2025; fallback para preço médio over país)
  (SELECT AVG(p.eur_per_ton)
     FROM compras_precos p
    WHERE p.ano = 2025
      AND p.comprimento_mm = v.comprimento_mm
      AND p.gama_compras = v.gama_compras) AS eur_per_ton_avg,
  -- Banda ±15% pré-calculada
  v.ton * 0.85 AS ton_min_lp,
  v.ton * 1.15 AS ton_max_lp,
  -- Share país (do ano)
  (SELECT share_pt FROM compras_pais_share WHERE ano = 2025) AS share_pt,
  (SELECT share_es FROM compras_pais_share WHERE ano = 2025) AS share_es
FROM compras_volumes v
WHERE v.ano = 2025
ORDER BY v.comprimento_mm, v.gama_compras;


-- ============================================================
-- Verificação
-- ============================================================
-- SELECT * FROM compras_mix_2025;            -- deve dar 0 linhas até carregares ficheiros
-- SELECT * FROM compras_pais_share;
-- SELECT SUM(ton) FROM compras_volumes WHERE ano = 2025;  -- esperado ~76 062
