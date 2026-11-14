# ==============================================================================
# PROJETO - ANÁLISE DE REGRESSÃO LINEAR
# Autor: Leonardo Oliveira Eid
# Disciplina: SME0220 - Introdução à Teoria das Probabilidades
# Análise: IDHM Educação (X) vs. Renda Per Capita (Y) - Municípios SP 2010
# ==============================================================================

# 1. Configuração e Bibliotecas ------------------------------------------------
# Verifica se os pacotes existem, instala se necessário e carrega
if(!require(tidyverse)) install.packages("tidyverse")
if(!require(scales)) install.packages("scales")
if(!require(broom)) install.packages("broom")

library(tidyverse)
library(scales)
library(broom)

# 2. Carregamento e Organização dos Dados --------------------------------------

# Lê o arquivo CSV (usando read.csv2 pois o formato original é PT-BR)
# Certifique-se que o arquivo "dados_atlas.csv" está na pasta de trabalho
dados_brutos <- read.csv2("dados_atlas.csv", 
                          check.names = FALSE, 
                          encoding = "UTF-8")

# Limpeza Inicial: Seleciona apenas as 3 primeiras colunas 
# (Evita erro de colunas vazias geradas pelo Excel)
dados_brutos <- dados_brutos[, 1:3] 

dados <- dados_brutos %>%
  # 1. Filtrar apenas municípios de SP (Remove totais "Brasil" e "São Paulo")
  filter(grepl("\\(SP\\)", Territorialidades)) %>% 
  
  # 2. Renomear as colunas pelo índice para evitar erro de digitação
  # Coluna 2 = IDHM Educação (X) | Coluna 3 = Renda (Y)
  select(
    x = 2, 
    y = 3 
  ) %>%
  
  # 3. Garantir formato numérico (corrige vírgula/ponto se necessário)
  mutate(
    x = as.numeric(gsub(",", ".", as.character(x))),
    y = as.numeric(gsub(",", ".", as.character(y)))
  ) %>%
  
  # 4. Remover linhas com dados faltantes (NA)
  filter(!is.na(x) & !is.na(y))

# Conferência dos dados carregados
cat("\n--- DADOS CARREGADOS (Primeiras linhas) ---\n")
print(head(dados))

# 3. Análise Exploratória: Gráfico de Dispersão (G0) ---------------------------
G0 = 
  dados %>% 
  ggplot() +
  geom_point(aes(x=x, y=y), alpha=0.5, color="darkblue") + 
  labs(
    title = "Relação: Educação vs. Renda (Municípios SP - 2010)",
    x = 'IDHM Educação (X)',
    y = 'Renda Per Capita (Y)'
  ) +
  theme_minimal()

print(G0) # Exibe o gráfico base

# 4. Ajuste do Modelo de Regressão Linear Simples ------------------------------
modelo = lm(formula = y ~ x, data = dados)

# 5. Resultados Estatísticos ---------------------------------------------------
cat("\n--- RESUMO DO MODELO (Estatísticas e Coeficientes) ---\n")
print(summary(modelo)) 

cat("\n--- INTERVALOS DE CONFIANÇA (95% para os Coeficientes) ---\n")
print(confint(modelo)) 

# 6. Diagnóstico do Modelo (Gráficos de Resíduos) ------------------------------
sigma_hat = sigma(modelo)

# R0: Resíduos vs Índice (Observação)
R0 = 
  augment(modelo) %>%
  mutate(id = 1:n()) %>% 
  ggplot() +
  geom_point(aes(x=id, y=.resid)) +
  geom_hline(yintercept=0, linetype='dashed') +
  geom_hline(yintercept=c(-sigma_hat, sigma_hat), linewidth=1.0, color="red") +
  labs(title = "Diagnóstico: Resíduos vs. Índice", x='Observação', y='Resíduo') +
  theme_minimal()

# R1: Resíduos vs Valores Ajustados (Verificar Homocedasticidade)
R1 = 
  augment(modelo) %>%
  ggplot() +
  geom_point(aes(x=.fitted, y=.resid)) +
  geom_hline(yintercept=0, linetype='dashed') +
  geom_hline(yintercept=c(-sigma_hat, sigma_hat), linewidth=1.0, color="red") +
  labs(title = "Diagnóstico: Resíduos vs. Valores Ajustados", x='Valor Ajustado', y='Resíduo') +
  theme_minimal()

# R2: Resíduos vs Variável Preditora (X)
R2 = 
  augment(modelo) %>%
  ggplot() +
  geom_point(aes(x=x, y=.resid)) +
  geom_hline(yintercept=0, linetype='dashed') +
  geom_hline(yintercept=c(-sigma_hat, sigma_hat), linewidth=1.0, color="red") +
  labs(title = "Diagnóstico: Resíduos vs. IDHM Educação", x='IDHM Educação (X)', y='Resíduo') +
  theme_minimal()

# R3: QQ-Plot (Verificar Normalidade)
R3 = 
  augment(modelo) %>% 
  ggplot(aes(sample=.resid)) +
  geom_qq() +
  geom_qq_line(color="red") +
  labs(title = "Diagnóstico: Normal Q-Q Plot", x='Quantis Teóricos', y='Quantis Amostrais') +
  theme_minimal()

# Exibir os gráficos de diagnóstico em sequência
print(R0)
print(R1)
print(R2)
print(R3)

# 7. Gráficos com Bandas de Confiança e Predição -------------------------------
# Cria sequência de X para desenhar as bandas suaves
new.X = seq(min(dados$x), max(dados$x), length.out=100)

# G1: Banda de Confiança (Para a Média)
IC = predict(modelo, newdata=tibble(x=new.X), interval='confidence', level=0.95) %>% 
  data.frame() %>% 
  mutate(x=new.X)

G1 = G0 + 
  geom_line(data=IC, aes(x=x, y=fit, colour='Média Estimada'), linewidth=1.0) +
  geom_ribbon(data=IC, aes(x=x, ymin=lwr, ymax=upr, fill='IC Média 95%'), alpha=0.3) +
  scale_color_manual(name="", values=c('Média Estimada'='blue')) +
  scale_fill_manual(name="", values=c('IC Média 95%'='blue')) +
  labs(title = "Regressão com Intervalo de Confiança da Média") +
  theme(legend.position='bottom')

# G2: Banda de Predição (Para Novos Indivíduos)
IP = predict(modelo, newdata=tibble(x=new.X), interval='prediction', level=0.95) %>% 
  data.frame() %>% 
  mutate(x=new.X)

G2 = G0 +
  geom_line(data=IP, aes(x=x, y=fit, colour='Reta Ajustada'), linewidth=1.0) +
  geom_ribbon(data=IP, aes(x=x, ymin=lwr, ymax=upr, fill='IC Predição 95%'), alpha=0.2) +
  scale_color_manual(name="", values = c('Reta Ajustada'='black')) +
  scale_fill_manual(name="", values=c('IC Predição 95%'='gray30')) +
  labs(title = "Regressão com Intervalo de Predição (Novos Dados)") +
  theme(legend.position='bottom')

print(G1)
print(G2)

# 8. Aplicação Prática: Predição Pontual (IDHM = 0.75) -------------------------
# Criação do cenário hipotético citado no relatório
novo_municipio <- data.frame(x = 0.75)

# Cálculo da Predição da Média (Intervalo de Confiança)
pred_media <- predict(modelo, newdata=novo_municipio, interval="confidence", level=0.95)

# Cálculo da Predição do Indivíduo (Intervalo de Predição)
pred_individuo <- predict(modelo, newdata=novo_municipio, interval="prediction", level=0.95)

# Exibição formatada no Console para conferência do Relatório
cat("\n======================================================\n")
cat(" RESULTADOS DA PREDIÇÃO PARA IDHM = 0.75\n")
cat("======================================================\n")
cat("Estimativa Pontual (Renda Esperada): R$", round(pred_media[1], 2), "\n\n")

cat("1. Intervalo de Confiança (Média Populacional):\n")
cat("   [ R$", round(pred_media[2], 2), "; R$", round(pred_media[3], 2), "]\n\n")

cat("2. Intervalo de Predição (Município Específico):\n")
cat("   [ R$", round(pred_individuo[2], 2), "; R$", round(pred_individuo[3], 2), "]\n")
cat("======================================================\n")
