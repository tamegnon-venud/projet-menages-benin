# Profils de ménages au Bénin selon le logement et les équipements

Analyse de l'enquête EHCVM 2018-2019, avec R (ACM et classification).

## La question

Les ménages béninois peuvent-ils être regroupés selon leur logement, leurs services (eau, électricité, toilettes) et leurs équipements ? Et ces groupes ont-ils des niveaux de dépense différents ?

L'analyse est descriptive : elle regroupe des ménages qui se ressemblent, sans expliquer les écarts.

## Les résultats en bref

- **4 profils** de ménages, du logement surtout non durable à l'équipement élevé.
- Le profil le plus répandu (**53,8 %** des ménages) vit dans un logement surtout durable, mais sans équipement : 6,5 % seulement ont l'électricité.
- La dépense annuelle médiane par tête passe de **241 354 à 657 993 FCFA** d'un profil à l'autre, soit environ **2,7 fois** plus. La médiane de l'ensemble des ménages est de 331 361 FCFA. Cela décrit des regroupements : cela n'établit aucune cause.
- Les profils des deux extrémités sont stables, avec ou sans pondération, avec 3 ou 5 groupes. Les profils du milieu dépendent du nombre de groupes choisi.

![Profils de ménages](outputs/figures/profils_classes.png)

Rapport complet : [`report/rapport_profils_menages_benin.pdf`](report/rapport_profils_menages_benin.pdf)

## Les données

**Source.** Enquête harmonisée sur les conditions de vie des ménages (EHCVM) du Bénin, 2018-2019. Banque mondiale, Microdata Library, identifiant `BEN_2018_EHCVM_v02_M`.
Lien : https://microdata.worldbank.org/catalog/4291/get-microdata

**Les données ne sont pas dans ce dépôt.** Seuls des résultats d'ensemble sont publiés, aucun fichier au niveau des ménages. Pour les télécharger, il faut s'inscrire gratuitement sur le lien ci-dessus et accepter les conditions d'utilisation.

**Conditions d'utilisation (résumé).** Usage de recherche statistique et scientifique, pas de redistribution sans accord écrit, résultats d'ensemble uniquement, aucune tentative d'identifier les répondants.

**Comment citer les données.** Selon les exigences de la page de l'enquête :

> WAEMU Commission, *Harmonized Survey on Households Living Standards, Benin 2018/19*. Ref. BEN_2018_EHCVM_v02_M. Dataset downloaded from www.microdata.worldbank.org on 20 November 2026.
> Investigateur principal : Institut National de la Statistique et de l'Analyse Économique (INSAE).
> DOI : https://doi.org/10.48529/rn3k-z374

**Mesure du bien-être.** La variable `pcexp` est la consommation annuelle par personne, en FCFA, corrigée des écarts de prix. La base fournit un déflateur spatial et un déflateur temporel ; le script le vérifie à la section 3.

## La méthode

- Logiciel : R 4.6.1 (tidyverse, haven, FactoMineR, factoextra, mclust).
- Une **analyse des correspondances multiples (ACM)**, pondérée, résume dix variables de logement, de services et d'équipements.
- Une **classification hiérarchique ascendante (HCPC)** regroupe les ménages en 4 profils, à partir des deux premiers axes.
- La dépense par tête ne sert pas à former les profils : elle sert à les vérifier.
- Tests de stabilité : sans pondération, avec 3 groupes et avec 5 groupes.

## Les limites

- Un seul moment (2018-2019) : pas d'évolution dans le temps, pas de causes.
- Cinq biens rares (fer à repasser, réfrigérateur, cuisinière, ordinateur, voiture) sont regroupés en une seule variable. Le seuil de 5 % est un choix pratique.
- Quatre groupes est un choix. Le profil 2 est large et hétérogène, et le profil 3 est un profil de transition.

## Reproduire l'analyse

1. Télécharger `ehcvm_menage_ben2018.dta` et `ehcvm_welfare_ben2018.dta` dans `data/raw/`.
2. Installer les packages :

   ```r
   install.packages(c("tidyverse", "haven", "FactoMineR", "factoextra", "mclust"))
   ```

3. Ouvrir le projet RStudio (le répertoire de travail doit être la racine du projet), puis exécuter `scripts/analyse_menages.R`. Les tableaux et les figures sont écrits dans `outputs/`.

## Contenu du dépôt

```
scripts/analyse_menages.R   analyse complète, par sections numérotées
outputs/tables/             tableaux (profils, contributions, descriptif)
outputs/figures/            figures
report/                     rapport PDF
data/SOURCE.txt             source et date de téléchargement des données
```

## Auteur

Sètondji Venud Tamegnon · [LinkedIn](https://www.linkedin.com/in/venud-tamegnon-61b8183b2/)
