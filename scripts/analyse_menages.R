# ==============================================================================
# Projet 2 : profils de ménages au Bénin (ACM sur l'EHCVM 2018-2019)
# Question : quels profils de ménages selon leurs équipements et leur
#            assainissement, et correspondent-ils à des niveaux de bien-être
#            différents ?
# Usage    : ouvrir le projet RStudio (répertoire de travail = racine du projet)
#            puis exécuter ce fichier en entier (Source) ou section par section.
#
# Sections : 1 Import | 2 Fusion | 3 Inspection | 4 Recodage | 5 Descriptif
#            6 ACM | 7 Interprétation | 8 Classification (HCPC) | 9 Noms et figures
#            10 Sensibilité | 11 Trace de l'environnement
# ==============================================================================


# ---- 1. IMPORT ---------------------------------------------------------------
library(tidyverse)
library(haven)   # lecture des .dta avec libellés

for (d in c("data/processed", "outputs/figures", "outputs/tables")) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

menage  <- read_dta("data/raw/ehcvm_menage_ben2018.dta")    # logement, équipements
welfare <- read_dta("data/raw/ehcvm_welfare_ben2018.dta")   # région, milieu, bien-être, poids

dim(menage); dim(welfare)   # attendu : 8012 lignes chacun


# ---- 2. FUSION (clé : hhid) --------------------------------------------------
stopifnot(!any(duplicated(menage$hhid)), !any(duplicated(welfare$hhid)))

cols_nouvelles <- setdiff(names(welfare), names(menage))
df <- menage %>%
  left_join(welfare %>% select(hhid, all_of(cols_nouvelles)), by = "hhid")

stopifnot(nrow(df) == nrow(menage), sum(is.na(df$hhweight)) == 0)
cat("Fusion OK :", nrow(df), "ménages\n")


# ---- 3. INSPECTION DES VARIABLES CANDIDATES ----------------------------------
vars_cand <- c("toit", "mur", "sol",                                   # logement
               "eauboi_ss", "elec_ac", "toilet", "ordure",             # services
               "tv", "fer", "frigo", "cuisin", "ordin", "decod", "car") # équipements

modalites <- map_dfr(vars_cand, function(v) {
  x <- df[[v]]
  lib <- attr(x, "label")
  tibble(code = as.numeric(x), modalite = as.character(as_factor(x))) %>%
    count(code, modalite) %>%
    mutate(variable = v,
           libelle  = if (is.null(lib)) NA_character_ else lib,
           pct      = round(100 * n / sum(n), 1),
           .before  = 1)
})
print(modalites, n = Inf)
write_csv(modalites, "outputs/tables/modalites_variables_candidates.csv")

count(df, as_factor(milieu))
count(df, as_factor(region))
summary(df$pcexp)

# Contrôle de pcexp : consommation annuelle par tête, déflatée ? Le rapport qui vaut 1 donne la formule
summary(df$dtot / df$hhsize / df$pcexp)                                   # 1 si aucun déflateur
summary(df$dtot / df$hhsize / df$pcexp / df$def_spa)                      # 1 si déflateur spatial seul
summary(df$dtot / df$hhsize / df$pcexp / (df$def_spa * df$def_temp))      # 1 si spatial et temporel


# ---- 4. RECODAGE ET VALEURS MANQUANTES ---------------------------------------
# 5 biens ont moins de 5 % de "Oui" (fer, frigo, car, cuisin, ordin) : une
# modalité rare déforme l'ACM. On les regroupe en une variable "biens_confort".
table(cuisin = df$cuisin, ordin = df$ordin)   # variables distinctes (81 ménages ont les deux)

biens_rares <- c("fer", "frigo", "cuisin", "ordin", "car")
df <- df %>%
  mutate(nb_biens = rowSums(across(all_of(biens_rares), as.numeric)),
         biens_confort = factor(
           if_else(nb_biens == 0, "biens_Aucun", "biens_AuMoinsUn"),
           levels = c("biens_Aucun", "biens_AuMoinsUn")))   # 3 modalités : la 3e < 5 %

count(df, biens_confort) %>% mutate(pct = round(100 * n / sum(n), 1))

# Variables 0/1 -> facteurs (modalités préfixées : "tv_Oui")
vars_binaires <- c("toit", "mur", "sol", "eauboi_ss", "elec_ac",
                   "toilet", "ordure", "tv", "decod")
recoder_01 <- function(x, nom) {
  factor(as.numeric(x), levels = c(0, 1), labels = paste0(nom, c("_Non", "_Oui")))
}
df <- df %>% mutate(across(all_of(vars_binaires), ~ recoder_01(.x, cur_column())))

# Rôle des variables
vars_actives   <- c(vars_binaires, "biens_confort")   # définissent les profils
vars_sup_qual  <- c("milieu", "region")               # interprétation
var_sup_quanti <- "pcexp"                             # bien-être (interprétation)
var_poids      <- "hhweight"

df <- df %>%
  mutate(across(all_of(vars_sup_qual), ~ factor(as.character(as_factor(.x)))))

# Valeurs manquantes
vars_utiles <- c(vars_actives, vars_sup_qual, var_sup_quanti, var_poids)
colSums(is.na(df[, vars_utiles]))

df_mca <- df %>% select(hhid, all_of(vars_utiles)) %>% drop_na()
cat("Ménages conservés :", nrow(df_mca), "sur", nrow(df), "\n")

# Modalités sous 5 % dans les variables actives (attendu : aucune)
freq <- df_mca %>%
  select(all_of(vars_actives)) %>%
  pivot_longer(everything(), names_to = "variable", values_to = "modalite") %>%
  count(variable, modalite) %>%
  group_by(variable) %>%
  mutate(pct = round(100 * n / sum(n), 1)) %>%
  ungroup()
filter(freq, pct < 5)

saveRDS(df_mca, "data/processed/df_mca.rds")


# ---- 5. STATISTIQUES DESCRIPTIVES --------------------------------------------
# pct_pondere = part dans la population (avec hhweight) : c'est le chiffre à citer
desc <- df_mca %>%
  select(all_of(vars_actives), poids = all_of(var_poids)) %>%
  pivot_longer(-poids, names_to = "variable", values_to = "modalite") %>%
  group_by(variable, modalite) %>%
  summarise(n = n(), poids_tot = sum(poids), .groups = "drop") %>%
  group_by(variable) %>%
  mutate(pct         = round(100 * n / sum(n), 1),
         pct_pondere = round(100 * poids_tot / sum(poids_tot), 1)) %>%
  ungroup() %>%
  select(variable, modalite, n, pct, pct_pondere)

print(desc, n = Inf)
write_csv(desc, "outputs/tables/descriptif_variables_actives.csv")


# ---- 6. ACM ------------------------------------------------------------------
library(FactoMineR)
library(factoextra)

k <- length(vars_actives)
w <- df_mca[[var_poids]]

# Colonnes : actives, puis qualitatives supplémentaires, puis quantitative
# supplémentaire (log de la dépense, car la dépense est très asymétrique)
base <- as.data.frame(df_mca[, c(vars_actives, vars_sup_qual)])
base$log_pcexp <- log(df_mca[[var_sup_quanti]])

pos_sup_qual   <- (k + 1):(k + length(vars_sup_qual))
pos_sup_quanti <- k + length(vars_sup_qual) + 1

# ncp = 10 : garde toutes les dimensions (sinon la table des valeurs propres est tronquée)
res_mca_nw <- MCA(base, ncp = 10, quali.sup = pos_sup_qual,
                  quanti.sup = pos_sup_quanti, graph = FALSE)               # sans poids
res_mca    <- MCA(base, ncp = 10, quali.sup = pos_sup_qual,
                  quanti.sup = pos_sup_quanti, row.w = w, graph = FALSE)    # avec poids (référence)

# Valeurs propres ; on garde les axes au-dessus du seuil 1/k
round(res_mca$eig, 3)
cat("Seuil 1/k =", round(1 / k, 3), "\n")

# La pondération change-t-elle le résultat ? (corrélation des coordonnées)
abs(cor(res_mca_nw$ind$coord[, 1], res_mca$ind$coord[, 1]))
abs(cor(res_mca_nw$ind$coord[, 2], res_mca$ind$coord[, 2]))

fviz_screeplot(res_mca, addlabels = TRUE)


# ---- 7. INTERPRÉTATION DES AXES ----------------------------------------------
# Résultats : axe 1 (35 %) = équipements et services ; axe 2 (13,6 %) = qualité
# des matériaux du logement (avec un effet d'arche) ; axe 3 (9,7 %) sous le seuil.

# Modalités : coordonnées et contributions (en %, moyenne = 5 %)
tab_axes <- tibble(
  modalite = rownames(res_mca$var$coord),
  coord1   = res_mca$var$coord[, 1],
  coord2   = res_mca$var$coord[, 2],
  contrib1 = res_mca$var$contrib[, 1],
  contrib2 = res_mca$var$contrib[, 2]
) %>%
  mutate(across(where(is.numeric), ~ round(.x, 2))) %>%
  arrange(desc(contrib1))

print(tab_axes, n = Inf)
write_csv(tab_axes, "outputs/tables/acm_modalites_axes.csv")

round(res_mca$var$eta2[, 1:2], 3)               # lien variable-axe (0 à 1)
round(res_mca$quali.sup$coord[, 1:2], 2)        # position du milieu et des régions
round(res_mca$quanti.sup$coord[, 1:2], 2)       # corrélation de log(pcexp) avec les axes

# Axe 3 : apporte-t-il quelque chose ?
tab_axe3 <- tibble(
  modalite = rownames(res_mca$var$coord),
  coord3   = res_mca$var$coord[, 3],
  contrib3 = res_mca$var$contrib[, 3]
) %>%
  mutate(across(where(is.numeric), ~ round(.x, 2))) %>%
  arrange(desc(contrib3))

print(tab_axe3, n = Inf)
round(res_mca$var$eta2[, 3], 3)
round(res_mca$quali.sup$coord[, 3], 2)
round(res_mca$quanti.sup$coord[, 3], 2)

# Graphiques
g_contrib1 <- fviz_contrib(res_mca, choice = "var", axes = 1, top = 20)
g_contrib2 <- fviz_contrib(res_mca, choice = "var", axes = 2, top = 20)
g_plan     <- fviz_mca_var(res_mca, col.var = "contrib", repel = TRUE)
g_eboulis  <- fviz_screeplot(res_mca, addlabels = TRUE)

g_contrib1; g_contrib2; g_plan; g_eboulis

ggsave("outputs/figures/eboulis.png",        g_eboulis,  width = 7, height = 5, dpi = 200)
ggsave("outputs/figures/contrib_axe1.png",   g_contrib1, width = 7, height = 5, dpi = 200)
ggsave("outputs/figures/contrib_axe2.png",   g_contrib2, width = 7, height = 5, dpi = 200)
ggsave("outputs/figures/plan_factoriel.png", g_plan,     width = 8, height = 6, dpi = 200)


# ---- 8. CLASSIFICATION EN PROFILS (HCPC) -------------------------------------
# HCPC classe sur les axes conservés dans l'ACM : on la relance avec 2 axes.
# (L'axe 3 ne représente que l'accès à l'eau en saison sèche : on l'écarte.)
ncp_hcpc <- 2
res_mca_h <- MCA(base, ncp = ncp_hcpc, quali.sup = pos_sup_qual,
                 quanti.sup = pos_sup_quanti, row.w = w, graph = FALSE)

nb_classes <- 4      # coude des gains d'inertie après 3-4 classes ; à 5 classes le découpage varie (voir 10)

# kk = Inf : pas de pré-regroupement k-means, donc résultat déterministe (kk = 100 variait selon la graine)
res_hcpc <- HCPC(res_mca_h,
                 nb.clust = if (is.null(nb_classes)) -1 else nb_classes,
                 kk = Inf, graph = FALSE)

# Nombre de classes, gains d'inertie (un saut net suggère le bon nombre), effectifs
cat("Nombre de classes :", length(unique(res_hcpc$data.clust$clust)), "\n")
round(res_hcpc$call$t$inert.gain[1:10], 3)
table(res_hcpc$data.clust$clust)
round(100 * prop.table(table(res_hcpc$data.clust$clust)), 1)

df_mca$cluster <- res_hcpc$data.clust$clust
saveRDS(df_mca, "data/processed/df_mca_cluster.rds")

# Profil de chaque classe :
#   colonnes des variables = % pondéré de ménages ayant le bien/service
#   part_ponderee          = poids de la classe dans la population
#   pcexp_median           = dépense médiane pondérée par tête (validation sur le bien-être)
# Médiane pondérée (poids = hhweight)
wmedian <- function(x, w) {
  o <- order(x)
  x[o][which(cumsum(w[o]) >= sum(w) / 2)[1]]
}

resume_profil <- function(d) {
  d %>% summarise(
    effectif = n(),
    poids    = sum(hhweight),
    across(all_of(vars_actives),
           ~ round(100 * weighted.mean(grepl("_Oui$|AuMoinsUn$", .x), hhweight), 1)),
    pcexp_median = wmedian(pcexp, hhweight))
}

profils <- bind_rows(
  df_mca %>% group_by(cluster) %>% resume_profil() %>% mutate(cluster = as.character(cluster)),
  df_mca %>% resume_profil() %>% mutate(cluster = "Ensemble")) %>%
  mutate(part_ponderee = round(100 * poids / poids[cluster == "Ensemble"], 1)) %>%
  select(-poids)

print(profils, width = Inf)
stopifnot(!is.unsorted(profils$elec_ac[1:nb_classes]))   # les noms (section 9) supposent cet ordre
write_csv(profils, "outputs/tables/profils_classes.csv")


# ---- 9. NOMS DES CLASSES ET FIGURES --------------------------------------------
# Noms descriptifs (logement, équipement), sans jugement sur les ménages
noms_classes <- c("1" = "1. Mur et sol majoritairement non durables",
                  "2" = "2. Logement surtout durable, sans équipement",
                  "3" = "3. Équipement intermédiaire",
                  "4" = "4. Équipement élevé")
df_mca$profil <- factor(noms_classes[as.character(df_mca$cluster)], levels = noms_classes)
saveRDS(df_mca, "data/processed/df_mca_cluster.rds")

# Groupes et libellés des colonnes de la figure 1
groupes <- c(toit = "Logement", mur = "Logement", sol = "Logement",
             eauboi_ss = "Services", elec_ac = "Services", toilet = "Services", ordure = "Services",
             tv = "Équipements", decod = "Équipements", biens_confort = "Équipements")
lib_vars <- c(toit = "Toit\ndurable", mur = "Mur\ndurable", sol = "Sol\ndurable",
              eauboi_ss = "Eau\n(saison sèche)", elec_ac = "Électricité",
              toilet = "Toilettes\nsaines", ordure = "Déchets\névacués",
              tv = "Télévision", decod = "Décodeur", biens_confort = "Biens de\nconfort")
virgule  <- function(x) sub("\\.", ",", x)                              # séparateur décimal français
milliers <- function(x) format(round(x), big.mark = " ", trim = TRUE)  # 241 354

# Données de la figure 1 : % pondéré de ménages par classe et par variable
fig_data <- profils %>%
  filter(cluster != "Ensemble") %>%
  mutate(etiq = paste0(noms_classes[cluster], "\n(", virgule(part_ponderee), " % des ménages)")) %>%
  pivot_longer(all_of(vars_actives), names_to = "variable", values_to = "pct") %>%
  mutate(groupe   = factor(groupes[variable], levels = c("Logement", "Services", "Équipements")),
         variable = factor(variable, levels = vars_actives),
         etiq     = factor(etiq, levels = rev(unique(etiq))),
         texte    = ifelse(pct == 100, "100", virgule(formatC(pct, format = "f", digits = 1))))

# Figure 1 : profils (% pondéré de ménages concernés)
g_profils <- ggplot(fig_data, aes(variable, etiq, fill = pct)) +
  geom_tile(colour = "white", linewidth = 1) +
  geom_text(aes(label = texte, colour = pct > 45), size = 3.2) +
  scale_colour_manual(values = c("TRUE" = "white", "FALSE" = "#1f2d3d"), guide = "none") +
  scale_fill_gradient(low = "#eaf0f6", high = "#1f4e79", limits = c(0, 100), guide = "none") +
  scale_x_discrete(labels = lib_vars) +
  facet_grid(. ~ groupe, scales = "free_x", space = "free_x") +
  labs(x = NULL, y = NULL,
       caption = "Source : EHCVM Bénin 2018-2019 ; calculs de l'auteur (ACM + HCPC, 4 classes) ; % pondérés") +
  theme_minimal() +
  theme(panel.grid = element_blank(),
        strip.text = element_text(face = "bold", colour = "#1f4e79", size = 11),
        axis.text.y = element_text(hjust = 1, colour = "#222222"),
        panel.spacing.x = unit(8, "pt"),
        plot.caption = element_text(colour = "grey40"))
g_profils
ggsave("outputs/figures/profils_classes.png", g_profils, width = 10, height = 4.3, dpi = 200)

# Figure 2 : dépense médiane par tête (validation externe, non utilisée pour les classes)
med_ens <- profils$pcexp_median[profils$cluster == "Ensemble"]
g_pcexp <- profils %>%
  filter(cluster != "Ensemble") %>%
  mutate(profil = factor(noms_classes[cluster], levels = noms_classes)) %>%
  ggplot(aes(profil, pcexp_median, fill = profil)) +
  geom_col(width = 0.62) +
  geom_text(aes(label = milliers(pcexp_median), colour = cluster == "1"),
            vjust = 1.6, fontface = "bold") +
  scale_colour_manual(values = c("TRUE" = "#1f2d3d", "FALSE" = "white"), guide = "none") +
  scale_fill_manual(values = c("#a9c4de", "#729dc6", "#3f78ab", "#1f4e79"), guide = "none") +
  geom_hline(yintercept = med_ens, linetype = "dashed", colour = "#c0392b", linewidth = 0.9) +
  annotate("text", x = 0.5, y = med_ens, hjust = 0, vjust = -0.7, colour = "#c0392b",
           label = paste0("Médiane de l'ensemble : ", milliers(med_ens), " FCFA")) +
  scale_x_discrete(labels = scales::label_wrap(22)) +
  scale_y_continuous(labels = scales::label_number(big.mark = " "),
                     expand = expansion(mult = c(0, 0.05))) +
  labs(x = NULL, y = "Dépense annuelle médiane par tête (FCFA)",
       caption = "Source : EHCVM Bénin 2018-2019 ; calculs de l'auteur ; médianes pondérées") +
  theme_minimal() +
  theme(panel.grid.major.x = element_blank(), panel.grid.minor = element_blank())
g_pcexp
ggsave("outputs/figures/pcexp_par_profil.png", g_pcexp, width = 10, height = 3.9, dpi = 200)

write_csv(profils %>% mutate(profil = unname(noms_classes[cluster])),
          "outputs/tables/profils_classes_nommes.csv")


# ---- 10. SENSIBILITÉ : LES PROFILS TIENNENT-ILS ? ------------------------------
# Référence : kk = Inf, pondéré, 4 classes. Les numéros de classes des variantes n'ont pas de
# lien avec ceux de la référence : on compare par tableau croisé (% en ligne, pondéré) et par
# indice de Rand ajusté (1 = identique ; non pondéré).
# install.packages("mclust")   # une seule fois
ari <- function(x) round(mclust::adjustedRandIndex(df_mca$cluster, x), 3)
classer <- function(acm, k) HCPC(acm, nb.clust = k, kk = Inf, graph = FALSE)$data.clust$clust

res_mca_nw_h <- MCA(base, ncp = ncp_hcpc, quali.sup = pos_sup_qual,
                    quanti.sup = pos_sup_quanti, graph = FALSE)   # sans poids

round(res_hcpc$call$t$inert.gain[1:10], 3)   # gains d'inertie : choix du nombre de classes

variantes <- list("Sans pondération, 4 classes" = classer(res_mca_nw_h, 4),
                  "Pondéré, 3 classes"          = classer(res_mca_h, 3),
                  "Pondéré, 5 classes"          = classer(res_mca_h, 5))
for (nm in names(variantes)) {
  v <- variantes[[nm]]
  cat("\n==", nm, "==\n")
  cat("Rand ajusté vs référence :", ari(v), "\n")
  print(round(100 * prop.table(xtabs(df_mca$hhweight ~ df_mca$cluster + v), 1), 1))  # % en ligne, pondéré
  print(round(sapply(split(seq_len(nrow(df_mca)), v),
                     function(i) wmedian(df_mca$pcexp[i], df_mca$hhweight[i]))))   # médiane pondérée
}

# Ancienne méthode (kk = 100) : le découpage s'éloigne de la référence (Rand 0,47 à 0,52) et n'est pas stable -> abandonnée
for (g in c(1, 42, 123, 777, 2024)) {
  set.seed(g)
  cl <- suppressWarnings(HCPC(res_mca_h, nb.clust = nb_classes, kk = 100, graph = FALSE)$data.clust$clust)
  cat("kk = 100, graine", g, ": Rand ajusté", ari(cl), "\n")
}


# ---- 11. TRACE DE L'ENVIRONNEMENT --------------------------------------------
writeLines(capture.output(sessionInfo()), "outputs/session_info.txt")
