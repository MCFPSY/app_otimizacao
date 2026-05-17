# App Otimização — MCF

PWA para otimização do aproveitamento de rolaria em MCF. Recomenda mudanças nas 3 alavancas (combinações de corte, fronteiras de triagem, mix de compra) que produzem a mesma cesta de produtos consumindo menos rolaria.

## Estado

**Fase 3 — scaffold inicial.** Estrutura de tabs montada; lógica de cálculo e ingestão por implementar.

## Estrutura

```
app_otimizacao/
├── index.html          # Entry point (PWA, single-page)
├── styles.css          # Design tokens (Apple-style)
├── app.js              # Roteamento de tabs + lógica principal
├── manifest.json       # PWA manifest
├── sw.js               # Service worker (offline shell)
└── tabs/               # Conteúdo por tab (a vir nas próximas sprints)
```

## Stack

- PWA vanilla (sem framework — segue o padrão das outras apps MCF)
- Supabase (auth + DB) — projeto a configurar
- Design Apple-style com paleta `#007AFF`

## Inputs esperados

Long-form, header-based (não pivots). 5 ficheiros: compras, triagem, produção, planeamento, inventário. Schemas definidos na tab Premissas.

## Princípios

1. **Manter a cesta de produtos** sempre satisfeita
2. **Balanço de massa** em todas as recomendações
3. **Baseline real** (pares dominantes do MCF data), nunca proxies como "média Folha5"
4. **Granularidade de lote** (~50 m³/dia × 2 turnos)
