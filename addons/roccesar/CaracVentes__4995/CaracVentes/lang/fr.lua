------------------------------------------------------------
-- CaracVentes : textes français
-- Chargé seulement si le jeu est en français ; remplace les textes de default.lua.
-- Le dernier nombre (2) est la version : il doit être supérieur ou égal à celle de default.lua (1).
------------------------------------------------------------

-- Historique / voyant
SafeAddString(CARACVENTES_HISTO_INCOMPLET, "Historique incomplet : sans trou depuis le %s.", 2)   -- %s = date, ne pas l'enlever
SafeAddString(CARACVENTES_HISTO_AIDE, "Patientez ou listez manuellement les pages de l'historique du Marchand (option guilde) pour accélérer la récupération, puis relancez l'opération. Le voyant restera rouge si les données sont manquantes sur la période : pas de marchand de guilde, guilde rejointe depuis moins de 7 jours, trou dans l'historique, etc.", 2)
SafeAddString(CARACVENTES_HISTO_COMPLET, "Historique complet.", 2)
SafeAddString(CARACVENTES_HISTO_DATE_INCONNUE, "une date inconnue", 2)
SafeAddString(CARACVENTES_DATE_FORMAT, "%d/%m/%Y %H:%M UTC", 2)

-- Section "Dernières ventes"
SafeAddString(CARACVENTES_TITRE_DERNIERES_VENTES, "Dernière(s) vente(s) enregistrée(s)", 2)
SafeAddString(CARACVENTES_BTN_AFFICHER, "Afficher", 2)
SafeAddString(CARACVENTES_BTN_MASQUER, "Masquer", 2)
SafeAddString(CARACVENTES_COLV_ARTICLE, "Article", 2)
SafeAddString(CARACVENTES_COLV_UNITE, "Prix/pièce", 2)
SafeAddString(CARACVENTES_COLV_TOTAL, "Prix total", 2)
SafeAddString(CARACVENTES_COLV_ACHETEUR, "Acheteur", 2)

-- Tableau des guildes
SafeAddString(CARACVENTES_COL_GUILDES, "Guilde(s)", 2)
SafeAddString(CARACVENTES_COL_VENTES, "Ventes", 2)
SafeAddString(CARACVENTES_COL_TOTAL_GUILDE, "Total guilde", 2)
SafeAddString(CARACVENTES_COL_GAINS_GUILDE, "Gains Guilde", 2)
SafeAddString(CARACVENTES_COL_HISTORIQUE, "Historique", 2)
SafeAddString(CARACVENTES_LIGNE_TOTAL, "Total", 2)

-- Cases à cocher
SafeAddString(CARACVENTES_CASE_TAXES_DEDUITES, "Ventes taxes déduites", 2)
SafeAddString(CARACVENTES_CASE_SEMAINE_COURS, "Semaine en cours", 2)
SafeAddString(CARACVENTES_CASE_SEMAINE_PASSEE, "Semaine passée", 2)

-- Meilleurs vendeurs
SafeAddString(CARACVENTES_NB_VENDEURS, "Nombre de vendeur(s) :", 2)
SafeAddString(CARACVENTES_TOP_DEBUT, "Le(s) ", 2)
SafeAddString(CARACVENTES_TOP_FIN, " meilleur(s) vendeur(s)", 2)
SafeAddString(CARACVENTES_AUCUNE_VENTE, "aucune vente.", 2)
SafeAddString(CARACVENTES_DEUX_POINTS_GUILDE, " :", 2)   -- en français, espace avant les deux-points

-- Boutons et infobulles
SafeAddString(CARACVENTES_BTN_COLLECTER, "Collecter", 2)
SafeAddString(CARACVENTES_BTN_PURGER, "Purger", 2)
SafeAddString(CARACVENTES_BTN_FERMER, "Fermer", 2)
SafeAddString(CARACVENTES_INFO_COLLECTER, "Lance la récupération des ventes.", 2)
SafeAddString(CARACVENTES_INFO_PURGER, "Efface les données sauvegardées, à utiliser notamment lors de la première utilisation, si les ventes ne s'affichent pas.", 2)
SafeAddString(CARACVENTES_INFO_FERMER, "Ferme la fenêtre.", 2)
SafeAddString(CARACVENTES_FOND, "Fond", 2)

-- Messages d'information
SafeAddString(CARACVENTES_STATUT_PRET, "Prêt.", 2)
SafeAddString(CARACVENTES_AUCUNE_GUILDE, "Aucune guilde sélectionnée.", 2)
SafeAddString(CARACVENTES_RECHERCHE_EN_COURS, "Recherche des ventes en cours...", 2)
SafeAddString(CARACVENTES_AUCUNE_VENTE_TROUVEE, "Aucune vente trouvée pour ce joueur sur cette période.", 2)
SafeAddString(CARACVENTES_VENTES_TROUVEES, "%d vente(s) trouvée(s).", 2)
SafeAddString(CARACVENTES_COLLECTE_EN_COURS, "Collecte en cours...", 2)
SafeAddString(CARACVENTES_COLLECTE_TERMINEE, "Terminé : %d nouvelle(s) vente(s).", 2)
SafeAddString(CARACVENTES_DONNEES_PURGEES, "Données purgées (effet complet dans le fichier après /reloadui).", 2)
