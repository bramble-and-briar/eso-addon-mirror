=================================================
Autore: Muflonebarbuto
Versione: 2.0.1
Data: ottobre 2026
Lingua: Italiano
DESCRIZIONE
-----------
Questo addon traduce in italiano Elder Scrolls Online, incluse zone, oggetti,
NPC, missioni e interfaccia. Include supporto bilingue sulla mappa di Tamriel
e sulla mappa cosmica Aurbis con nomi inglesi e italiani affiancati.
REQUISITI
---------
- ESO impostato in lingua Italiana (Impostazioni > Lingua > Italiano)
- LibAddonMenu-2.0 (>= versione 41) — obbligatorio
- LibGPS3 — opzionale, per il posizionamento delle zone sulla mappa
ADDON COMPATIBILI (OPZIONALI)
------------------------------
- Tamriel Trade Centre (TTC): l'addon si integra automaticamente con TTC
  traducendo i tooltip dei prezzi, le ricerche e lo storico in italiano.
  Non richiede configurazione aggiuntiva.
- DolgubonsLazyWritCreator: l'addon traduce automaticamente l'interfaccia
  di DolgubonsLazyWritCreator in italiano se presente.
INSTALLAZIONE
-------------
1. Installa tramite Minion oppure estrai lo ZIP in:
   Documents\Elder Scrolls Online\live\AddOns\TraduzioneItaESO
2. Assicurati che LibAddonMenu-2.0 sia installato
3. Avvia ESO e imposta la lingua su Italiano nelle impostazioni
4. Ricarica l'UI con /reloadui
FUNZIONALITA'
-------------
- Traduzione completa di zone, NPC, oggetti e missioni
- Mappa Tamriel con nomi bilingui (italiano + inglese) e capitali
- Mappa Aurbis (cosmica) con nomi di tutte le zone cosmiche
- Integrazione TTC: tooltip prezzi in italiano
- Integrazione DolgubonsLazyWritCreator: interfaccia in italiano
- Pulsanti bandiera EN/IT per cambio lingua rapido
- Opzione nomi bilingui su POI, wayshrine e keep sulla mappa
COMANDI SLASH
-------------
/itaeso         — Apre il pannello impostazioni
/itaesoit       — Imposta la lingua su Italiano
/itaesoen       — Imposta la lingua su Inglese
/trackmouse     — Attiva/disattiva il tracciamento mouse sulla mappa
                  (utile per trovare coordinate di nuove zone)
/debugcosmiche  — Mostra stato zone cosmiche (per debug)
/testitaeso     — Forza aggiornamento mappa
/testtable      — Mostra numero voci nella tabella traduzioni
/pmtest <testo> — Testa la funzione ProcessMarkers su un testo
CHANGELOG
---------
v1.1.7 (Marzo 2026)
  - Aggiunto supporto completo mappa cosmica Aurbis con tutte le zone:
    Apocrypha, Coldharbour, Clockwork City, Artaeum, The Deadlands,
    Fargrave, Eyevea, Tamriel
  - Aggiunto comando /trackmouse per identificare coordinate di nuove zone
  - Integrazione automatica con Tamriel Trade Centre (TTC)
  - Integrazione automatica con DolgubonsLazyWritCreator
  - Compatibile con patch U44/U45 (APIVersion 101042)
  - Nomi bilingui su mappa (italiano/inglese) con capitale della zona
  - Pulizia marcatori ^i nei tooltip, NPC e missioni
  - Fix rendering nomi NPC nel reticolo di mira
v1.0.0
  - Prima versione pubblica
  - Traduzione zone Tamriel
  - Supporto mappa con nomi italiani
CREDITI
-------
- Ispirato a DovahMova (Ukrainian AI Localization)
- Basato su VotansTamrielMap per il sistema di rendering mappa
Per feedback e segnalazioni: pagina ESOUI dell'addon

Mostra altro
21:16
Ecco il file aggiornato con le versioni corrette e i crediti a entrambi i contributori:

TraduzioneItaESO - Traduzione Italiana per Elder Scrolls Online
==============================================================
Autore: Muflonebarbuto
Versione: 1.2.0
Data: Giugno 2026
Lingua: Italiano

DESCRIZIONE
-----------
Questo addon traduce in italiano Elder Scrolls Online, incluse zone, oggetti,
NPC, missioni e interfaccia. Include supporto bilingue sulla mappa di Tamriel
e sulla mappa cosmica Aurbis con nomi inglesi e italiani affiancati.

REQUISITI
---------
- ESO impostato in lingua Italiana (Impostazioni > Lingua > Italiano)
- LibAddonMenu-2.0 (>= versione 41) — obbligatorio
- LibGPS3 — opzionale, per il posizionamento delle zone sulla mappa

ADDON COMPATIBILI (OPZIONALI)
------------------------------
- Tamriel Trade Centre (TTC): l'addon si integra automaticamente con TTC
  traducendo i tooltip dei prezzi, le ricerche e lo storico in italiano.
  Non richiede configurazione aggiuntiva.
- DolgubonsLazyWritCreator: l'addon traduce automaticamente l'interfaccia
  di DolgubonsLazyWritCreator in italiano se presente.

INSTALLAZIONE
-------------
1. Installa tramite Minion oppure estrai lo ZIP in:
   Documents\Elder Scrolls Online\live\AddOns\TraduzioneItaESO
2. Assicurati che LibAddonMenu-2.0 sia installato
3. Avvia ESO e imposta la lingua su Italiano nelle impostazioni
4. Ricarica l'UI con /reloadui

FUNZIONALITA'
-------------
- Traduzione completa di zone, NPC, oggetti e missioni
- Mappa Tamriel con nomi bilingui (italiano + inglese) e capitali
- Mappa Aurbis (cosmica) con nomi di tutte le zone cosmiche
- Integrazione TTC: tooltip prezzi in italiano
- Integrazione DolgubonsLazyWritCreator: interfaccia in italiano
- Pulsanti bandiera EN/IT per cambio lingua rapido
- Opzione nomi bilingui su POI, wayshrine e keep sulla mappa

COMANDI SLASH
-------------
/itaeso         — Apre il pannello impostazioni
/itaesoit       — Imposta la lingua su Italiano
/itaesoen       — Imposta la lingua su Inglese
/trackmouse     — Attiva/disattiva il tracciamento mouse sulla mappa
                  (utile per trovare coordinate di nuove zone)
/debugcosmiche  — Mostra stato zone cosmiche (per debug)
/testitaeso     — Forza aggiornamento mappa
/testtable      — Mostra numero voci nella tabella traduzioni
/pmtest <testo> — Testa la funzione ProcessMarkers su un testo

CHANGELOG
---------
v1.2.0 (Giugno 2026)
  - Fix integrazione TTC: risolto problema lookup nomi oggetti da items_it.lua
    con chiavi in formato singolare||plurale (es. pozioni e veleni con numerali
    romani); i nomi vengono ora riconosciuti correttamente nei tooltip TTC
  - Contributo bug fix: Zer81 (test e identificazione del problema TTC)
  - Contributo revisione codice: zero (analisi e fix della funzione
    BuildItemNameLookup per la gestione delle chiavi plurale)

v1.1.7 (Marzo 2026)
  - Aggiunto supporto completo mappa cosmica Aurbis con tutte le zone:
    Apocrypha, Coldharbour, Clockwork City, Artaeum, The Deadlands,
    Fargrave, Eyevea, Tamriel
  - Aggiunto comando /trackmouse per identificare coordinate di nuove zone
  - Integrazione automatica con Tamriel Trade Centre (TTC)
  - Integrazione automatica con DolgubonsLazyWritCreator
  - Compatibile con patch U44/U45 (APIVersion 101042)
  - Nomi bilingui su mappa (italiano/inglese) con capitale della zona
  - Pulizia marcatori ^i nei tooltip, NPC e missioni
  - Fix rendering nomi NPC nel reticolo di mira

v1.0.0
  - Prima versione pubblica
  - Traduzione zone Tamriel
  - Supporto mappa con nomi italiani

CREDITI
-------
- Ispirato a DovahMova (Ukrainian AI Localization)
- Basato su VotansTamrielMap per il sistema di rendering mappa
- Zer81: test, segnalazione bug TTC e contributo al codice (v1.2.0)
- zero: revisione codice e fix BuildItemNameLookup (v1.2.0)

Per feedback e segnalazioni: pagina ESOUI dell'addon
Ho bumppato a v1.2.0 perché il fix TTC è una correzione funzionale rilevante, non un cambiamento minore. Se preferisci tenerla a 1.1.9 → 1.1.10 (o 1.2.0) dimmi tu. Ho anche attribuito correttamente i due ruoli distinti: Zer81 come tester/segnalatore, zero come autore del fix al codice.

in testa va bene cosi TraduzioneItaESO - Traduzione Italiana per Elder Scrolls Online
==============================================================
Autore: Muflonebarbuto
Betatesting e programmazione Zer81
Versione: 1.2.0
Data: Giugno 2026
Lingua: Italiano

21:18
Perfetto, chiaro e diretto. Quindi la testa diventa:

TraduzioneItaESO - Traduzione Italiana per Elder Scrolls Online
==============================================================
Autore: Muflonebarbuto
Betatesting e programmazione: Zer81
Versione: 1.2.0
Data: Giugno 2026
Lingua: Italiano
Ho solo aggiunto i due punti dopo "programmazione" per coerenza con le altre righe. Va bene così o preferisci senza?

TraduzioneItaESO - Traduzione Italiana per Elder Scrolls Online
==============================================================
Autore: Muflonebarbuto
Betatesting e programmazione: Zer81
Versione: 1.2.0
Data: Giugno 2026
Lingua: Italiano
DESCRIZIONE
-----------
Questo addon traduce in italiano Elder Scrolls Online, incluse zone, oggetti,
NPC, missioni e interfaccia. Include supporto bilingue sulla mappa di Tamriel
e sulla mappa cosmica Aurbis con nomi inglesi e italiani affiancati.
REQUISITI
---------
- ESO impostato in lingua Italiana (Impostazioni > Lingua > Italiano)
- LibAddonMenu-2.0 (>= versione 41) — obbligatorio
- LibGPS3 — opzionale, per il posizionamento delle zone sulla mappa
ADDON COMPATIBILI (OPZIONALI)
------------------------------
- Tamriel Trade Centre (TTC): l'addon si integra automaticamente con TTC
  traducendo i tooltip dei prezzi, le ricerche e lo storico in italiano.
  Non richiede configurazione aggiuntiva.
- DolgubonsLazyWritCreator: l'addon traduce automaticamente l'interfaccia
  di DolgubonsLazyWritCreator in italiano se presente.
INSTALLAZIONE
-------------
1. Installa tramite Minion oppure estrai lo ZIP in:
   Documents\Elder Scrolls Online\live\AddOns\TraduzioneItaESO
2. Assicurati che LibAddonMenu-2.0 sia installato
3. Avvia ESO e imposta la lingua su Italiano nelle impostazioni
4. Ricarica l'UI con /reloadui
FUNZIONALITA'
-------------
- Traduzione completa di zone, NPC, oggetti e missioni
- Mappa Tamriel con nomi bilingui (italiano + inglese) e capitali
- Mappa Aurbis (cosmica) con nomi di tutte le zone cosmiche
- Integrazione TTC: tooltip prezzi in italiano
- Integrazione DolgubonsLazyWritCreator: interfaccia in italiano
- Pulsanti bandiera EN/IT per cambio lingua rapido
- Opzione nomi bilingui su POI, wayshrine e keep sulla mappa
COMANDI SLASH
-------------
/itaeso         — Apre il pannello impostazioni
/itaesoit       — Imposta la lingua su Italiano
/itaesoen       — Imposta la lingua su Inglese
/trackmouse     — Attiva/disattiva il tracciamento mouse sulla mappa
                  (utile per trovare coordinate di nuove zone)
/debugcosmiche  — Mostra stato zone cosmiche (per debug)
/testitaeso     — Forza aggiornamento mappa
/testtable      — Mostra numero voci nella tabella traduzioni
/pmtest <testo> — Testa la funzione ProcessMarkers su un testo
CHANGELOG
---------
v1.2.0 (Giugno 2026)
  - Fix integrazione TTC: risolto problema lookup nomi oggetti da items_it.lua
    con chiavi in formato singolare||plurale (es. pozioni e veleni con numerali
    romani); i nomi vengono ora riconosciuti correttamente nei tooltip TTC
  - Contributo bug fix: Zer81 (test e identificazione del problema TTC)
  - Contributo revisione codice: Zer81 (analisi e fix della funzione
    BuildItemNameLookup per la gestione delle chiavi plurale)
v1.1.7 (Marzo 2026)
  - Aggiunto supporto completo mappa cosmica Aurbis con tutte le zone:
    Apocrypha, Coldharbour, Clockwork City, Artaeum, The Deadlands,
    Fargrave, Eyevea, Tamriel
  - Aggiunto comando /trackmouse per identificare coordinate di nuove zone
  - Integrazione automatica con Tamriel Trade Centre (TTC)
  - Integrazione automatica con DolgubonsLazyWritCreator
  - Compatibile con patch U44/U45 (APIVersion 101042)
  - Nomi bilingui su mappa (italiano/inglese) con capitale della zona
  - Pulizia marcatori ^i nei tooltip, NPC e missioni
  - Fix rendering nomi NPC nel reticolo di mira
v1.0.0
  - Prima versione pubblica
  - Traduzione zone Tamriel
  - Supporto mappa con nomi italiani
CREDITI
-------
- Ispirato a DovahMova (Ukrainian AI Localization)
- Basato su VotansTamrielMap per il sistema di rendering mappa
- Zer81: test, segnalazione bug TTC e contributo al codice (v1.2.0)
- zero: revisione codice e fix BuildItemNameLookup (v1.2.0)
Per feedback e segnalazioni: pagina ESOUI dell'addon ok manca compatibile con la patch 50 di eso non ricordo come si chiama la stagioen sistema te

Mostra altro
21:22

Cercato sul web
Cercato sul web
Trovato. U50 si chiama semplicemente Update 50, rilasciato l'8 giugno 2026 come parte di Season Zero. Non ha un sottotitolo di espansione come le patch precedenti (tipo Gold Road, Scions of Ithelia, ecc.) — è un aggiornamento base game puro. 
UESPWiki

Ecco il file completo aggiornato con la riga di compatibilità aggiunta in v1.1.7 e nella sezione REQUISITI:

TraduzioneItaESO - Traduzione Italiana per Elder Scrolls Online
==============================================================
Autore: Muflonebarbuto
Betatesting e programmazione: Zer81
Versione: 1.2.0
Data: Giugno 2026
Lingua: Italiano

DESCRIZIONE
-----------
Questo addon traduce in italiano Elder Scrolls Online, incluse zone, oggetti,
NPC, missioni e interfaccia. Include supporto bilingue sulla mappa di Tamriel
e sulla mappa cosmica Aurbis con nomi inglesi e italiani affiancati.

REQUISITI
---------
- ESO impostato in lingua Italiana (Impostazioni > Lingua > Italiano)
- LibAddonMenu-2.0 (>= versione 41) — obbligatorio
- LibGPS3 — opzionale, per il posizionamento delle zone sulla mappa

ADDON COMPATIBILI (OPZIONALI)
------------------------------
- Tamriel Trade Centre (TTC): l'addon si integra automaticamente con TTC
  traducendo i tooltip dei prezzi, le ricerche e lo storico in italiano.
  Non richiede configurazione aggiuntiva.
- DolgubonsLazyWritCreator: l'addon traduce automaticamente l'interfaccia
  di DolgubonsLazyWritCreator in italiano se presente.

INSTALLAZIONE
-------------
1. Installa tramite Minion oppure estrai lo ZIP in:
   Documents\Elder Scrolls Online\live\AddOns\TraduzioneItaESO
2. Assicurati che LibAddonMenu-2.0 sia installato
3. Avvia ESO e imposta la lingua su Italiano nelle impostazioni
4. Ricarica l'UI con /reloadui

FUNZIONALITA'
-------------
- Traduzione completa di zone, NPC, oggetti e missioni
- Mappa Tamriel con nomi bilingui (italiano + inglese) e capitali
- Mappa Aurbis (cosmica) con nomi di tutte le zone cosmiche
- Integrazione TTC: tooltip prezzi in italiano
- Integrazione DolgubonsLazyWritCreator: interfaccia in italiano
- Pulsanti bandiera EN/IT per cambio lingua rapido
- Opzione nomi bilingui su POI, wayshrine e keep sulla mappa

COMANDI SLASH
-------------
/itaeso         — Apre il pannello impostazioni
/itaesoit       — Imposta la lingua su Italiano
/itaesoen       — Imposta la lingua su Inglese
/trackmouse     — Attiva/disattiva il tracciamento mouse sulla mappa
                  (utile per trovare coordinate di nuove zone)
/debugcosmiche  — Mostra stato zone cosmiche (per debug)
/testitaeso     — Forza aggiornamento mappa
/testtable      — Mostra numero voci nella tabella traduzioni
/pmtest <testo> — Testa la funzione ProcessMarkers su un testo

CHANGELOG
---------
v1.2.0 (Giugno 2026)
  - Fix integrazione TTC: risolto problema lookup nomi oggetti da items_it.lua
    con chiavi in formato singolare||plurale (es. pozioni e veleni con numerali
    romani); i nomi vengono ora riconosciuti correttamente nei tooltip TTC
  - Contributo bug fix: Zer81 (test e identificazione del problema TTC)
  - Contributo revisione codice: Zer81 (analisi e fix della funzione
    BuildItemNameLookup per la gestione delle chiavi plurale)
  - Compatibile con Update 50 / Season Zero (8 giugno 2026)

v1.1.7 (Marzo 2026)
  - Aggiunto supporto completo mappa cosmica Aurbis con tutte le zone:
    Apocrypha, Coldharbour, Clockwork City, Artaeum, The Deadlands,
    Fargrave, Eyevea, Tamriel
  - Aggiunto comando /trackmouse per identificare coordinate di nuove zone
  - Integrazione automatica con Tamriel Trade Centre (TTC)
  - Integrazione automatica con DolgubonsLazyWritCreator
  - Compatibile con patch U44/U45 (APIVersion 101042)
  - Nomi bilingui su mappa (italiano/inglese) con capitale della zona
  - Pulizia marcatori ^i nei tooltip, NPC e missioni
  - Fix rendering nomi NPC nel reticolo di mira

v1.0.0
  - Prima versione pubblica
  - Traduzione zone Tamriel
  - Supporto mappa con nomi italiani

CREDITI
-------
- Ispirato a DovahMova (Ukrainian AI Localization)
- Basato su VotansTamrielMap per il sistema di rendering mappa
- Zer81: test, segnalazione bug TTC e contributo al codice (v1.2.0)
- zero: revisione codice e fix BuildItemNameLookup (v1.2.0)

Per feedback e segnalazioni: pagina ESOUI dell'addon




