------------------------------------------------------------
-- CaracVentes : textes par défaut (anglais)
-- Chargé pour TOUS les joueurs ; fr.lua vient ensuite remplacer
-- ces textes pour les joueurs dont le jeu est en français.
-- Ne pas redéfinir un même ID avec ZO_CreateStringId dans un autre fichier :
-- les autres langues utilisent SafeAddString.
------------------------------------------------------------

-- Historique / voyant
ZO_CreateStringId("CARACVENTES_HISTO_INCOMPLET", "Incomplete history: no gap since %s.")   -- %s = date, ne pas l'enlever
ZO_CreateStringId("CARACVENTES_HISTO_AIDE", "Please wait, or manually browse the pages of the Guild Store history (guild option) to speed up retrieval, then run the operation again. The indicator will stay red if data is missing for the period: no guild store, guild joined less than 7 days ago, gap in the history, etc.")
ZO_CreateStringId("CARACVENTES_HISTO_COMPLET", "History complete.")
ZO_CreateStringId("CARACVENTES_HISTO_DATE_INCONNUE", "an unknown date")
ZO_CreateStringId("CARACVENTES_DATE_FORMAT", "%Y-%m-%d %H:%M UTC")   -- format os.date (le "!" est ajouté par le code)

-- Section "Dernières ventes"
ZO_CreateStringId("CARACVENTES_TITRE_DERNIERES_VENTES", "Latest recorded sale(s)")
ZO_CreateStringId("CARACVENTES_BTN_AFFICHER", "Show")
ZO_CreateStringId("CARACVENTES_BTN_MASQUER", "Hide")
ZO_CreateStringId("CARACVENTES_COLV_ARTICLE", "Item")
ZO_CreateStringId("CARACVENTES_COLV_UNITE", "Price/item")
ZO_CreateStringId("CARACVENTES_COLV_TOTAL", "Total price")
ZO_CreateStringId("CARACVENTES_COLV_ACHETEUR", "Buyer")

-- Tableau des guildes
ZO_CreateStringId("CARACVENTES_COL_GUILDES", "Guild(s)")
ZO_CreateStringId("CARACVENTES_COL_VENTES", "Sales")
ZO_CreateStringId("CARACVENTES_COL_TOTAL_GUILDE", "Guild total")
ZO_CreateStringId("CARACVENTES_COL_GAINS_GUILDE", "Guild gains")
ZO_CreateStringId("CARACVENTES_COL_HISTORIQUE", "History")
ZO_CreateStringId("CARACVENTES_LIGNE_TOTAL", "Total")

-- Cases à cocher
ZO_CreateStringId("CARACVENTES_CASE_TAXES_DEDUITES", "Sales after tax")
ZO_CreateStringId("CARACVENTES_CASE_SEMAINE_COURS", "Current week")
ZO_CreateStringId("CARACVENTES_CASE_SEMAINE_PASSEE", "Last week")

-- Meilleurs vendeurs
ZO_CreateStringId("CARACVENTES_NB_VENDEURS", "Number of seller(s):")
ZO_CreateStringId("CARACVENTES_TOP_DEBUT", "Top ")          -- suivi du nombre
ZO_CreateStringId("CARACVENTES_TOP_FIN", " seller(s)")      -- précédé du nombre
ZO_CreateStringId("CARACVENTES_AUCUNE_VENTE", "no sales.")
ZO_CreateStringId("CARACVENTES_DEUX_POINTS_GUILDE", ":")    -- après le nom de la guilde

-- Boutons et infobulles
ZO_CreateStringId("CARACVENTES_BTN_COLLECTER", "Collect")
ZO_CreateStringId("CARACVENTES_BTN_PURGER", "Purge")
ZO_CreateStringId("CARACVENTES_BTN_FERMER", "Close")
ZO_CreateStringId("CARACVENTES_INFO_COLLECTER", "Starts retrieving the sales.")
ZO_CreateStringId("CARACVENTES_INFO_PURGER", "Erases the saved data. Use it especially on first use, if the sales do not show up.")
ZO_CreateStringId("CARACVENTES_INFO_FERMER", "Closes the window.")
ZO_CreateStringId("CARACVENTES_FOND", "BG")   -- étiquette courte (peu de place avant les boutons - / +)

-- Messages d'information
ZO_CreateStringId("CARACVENTES_STATUT_PRET", "Ready.")
ZO_CreateStringId("CARACVENTES_AUCUNE_GUILDE", "No guild selected.")
ZO_CreateStringId("CARACVENTES_RECHERCHE_EN_COURS", "Searching for sales...")
ZO_CreateStringId("CARACVENTES_AUCUNE_VENTE_TROUVEE", "No sales found for this player in this period.")
ZO_CreateStringId("CARACVENTES_VENTES_TROUVEES", "%d sale(s) found.")          -- %d = nombre
ZO_CreateStringId("CARACVENTES_COLLECTE_EN_COURS", "Collecting...")
ZO_CreateStringId("CARACVENTES_COLLECTE_TERMINEE", "Done: %d new sale(s).")    -- %d = nombre
ZO_CreateStringId("CARACVENTES_DONNEES_PURGEES", "Data purged (the saved file is only fully updated after /reloadui).")

------------------------------------------------------------
-- Enregistrement de la version 1 de chaque texte (pour les traductions)
------------------------------------------------------------
SafeAddVersion(CARACVENTES_HISTO_INCOMPLET, 1)
SafeAddVersion(CARACVENTES_HISTO_AIDE, 1)
SafeAddVersion(CARACVENTES_HISTO_COMPLET, 1)
SafeAddVersion(CARACVENTES_HISTO_DATE_INCONNUE, 1)
SafeAddVersion(CARACVENTES_DATE_FORMAT, 1)

SafeAddVersion(CARACVENTES_TITRE_DERNIERES_VENTES, 1)
SafeAddVersion(CARACVENTES_BTN_AFFICHER, 1)
SafeAddVersion(CARACVENTES_BTN_MASQUER, 1)
SafeAddVersion(CARACVENTES_COLV_ARTICLE, 1)
SafeAddVersion(CARACVENTES_COLV_UNITE, 1)
SafeAddVersion(CARACVENTES_COLV_TOTAL, 1)
SafeAddVersion(CARACVENTES_COLV_ACHETEUR, 1)

SafeAddVersion(CARACVENTES_COL_GUILDES, 1)
SafeAddVersion(CARACVENTES_COL_VENTES, 1)
SafeAddVersion(CARACVENTES_COL_TOTAL_GUILDE, 1)
SafeAddVersion(CARACVENTES_COL_GAINS_GUILDE, 1)
SafeAddVersion(CARACVENTES_COL_HISTORIQUE, 1)
SafeAddVersion(CARACVENTES_LIGNE_TOTAL, 1)

SafeAddVersion(CARACVENTES_CASE_TAXES_DEDUITES, 1)
SafeAddVersion(CARACVENTES_CASE_SEMAINE_COURS, 1)
SafeAddVersion(CARACVENTES_CASE_SEMAINE_PASSEE, 1)

SafeAddVersion(CARACVENTES_NB_VENDEURS, 1)
SafeAddVersion(CARACVENTES_TOP_DEBUT, 1)
SafeAddVersion(CARACVENTES_TOP_FIN, 1)
SafeAddVersion(CARACVENTES_AUCUNE_VENTE, 1)
SafeAddVersion(CARACVENTES_DEUX_POINTS_GUILDE, 1)

SafeAddVersion(CARACVENTES_BTN_COLLECTER, 1)
SafeAddVersion(CARACVENTES_BTN_PURGER, 1)
SafeAddVersion(CARACVENTES_BTN_FERMER, 1)
SafeAddVersion(CARACVENTES_INFO_COLLECTER, 1)
SafeAddVersion(CARACVENTES_INFO_PURGER, 1)
SafeAddVersion(CARACVENTES_INFO_FERMER, 1)
SafeAddVersion(CARACVENTES_FOND, 1)

SafeAddVersion(CARACVENTES_STATUT_PRET, 1)
SafeAddVersion(CARACVENTES_AUCUNE_GUILDE, 1)
SafeAddVersion(CARACVENTES_RECHERCHE_EN_COURS, 1)
SafeAddVersion(CARACVENTES_AUCUNE_VENTE_TROUVEE, 1)
SafeAddVersion(CARACVENTES_VENTES_TROUVEES, 1)
SafeAddVersion(CARACVENTES_COLLECTE_EN_COURS, 1)
SafeAddVersion(CARACVENTES_COLLECTE_TERMINEE, 1)
SafeAddVersion(CARACVENTES_DONNEES_PURGEES, 1)
