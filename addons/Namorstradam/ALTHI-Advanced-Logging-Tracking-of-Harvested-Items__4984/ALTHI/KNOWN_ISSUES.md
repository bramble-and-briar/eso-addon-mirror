# Beta 0.9.4 – Umfang und bekannte Grenzen / Scope and known limitations

## Deutsch

- Ressourcenmodul: Belegte Sammel- und zugelassene Sonderweltknoten zählen. Bank, Handel, Post, Gegner-/Tierkörper und Herstellungs-/Veredelungsergebnisse zählen nicht. Angeln/Filetieren ist noch kein eigenes Modul; Perfekter Rogen ist lediglich für eine spätere Fundmeldung vorbereitet.
- Die ESO-Beutemeldung enthält keine vollständige Herkunfts-ID. ALTHI wertet Interaktionsnachweise konservativ aus; ungewöhnliche/verspätete Ereignisse können fehlen. Nicht belegte Quellen bleiben offen. Eine bekannte Bezugsquelle ist kein persönlicher Fund und keine garantierte Dropchance.
- Internationale Sonderweltknoten sind nicht in jeder Sprache vollständig bestätigt. Fünf zusätzliche Übersetzungen sind Entwürfe; native Schriftzeichen und längere Texte müssen Tester prüfen.
- Werte sind Schätzungen. AGS liefert einen eigenen letzten Angebotspreis, keinen bestätigten Verkauf. NPC-Basiswerte sind kein Marktpreis. Die einheitliche 7-%-Ansicht rechnet auf ausdrücklichen Wunsch auch diesen Ersatzwert um. Konkrete Verkaufsrundungen, erneut eingestellte Angebote und tatsächlich erreichte Marktpreise können abweichen.
- Manche seltenen Stil-/Eigenschaftsmaterialien besitzen noch keine vollständige Liste sämtlicher Bezugswege. Alte Schmuckkörner werden nicht pauschal als aktuelle Drops beschrieben. Aktuelle Native-Typ-/ID-Auflösung durch den Client bleibt nötig.
- Der aktuelle Menü-/Maus-Hotfix wurde mit LAM-/ESO-Simulationen geprüft. Reale Fensterketten mit/ohne LAM und konkrete Controller-Menüs vor Veröffentlichung erneut im Client testen.
- Keine schreibenden ESO-Loot-/Beuteleinstellungszugriffe im aktiven Code gefunden. Ursache eines früher beobachteten ausgeschalteten Beutelschalters nicht nachgewiesen; Neustart/Addon-Aktivierung und Wechselwirkungen anderer Addons im Client vergleichen.
- Manifest deklariert API 101051, von Roman mit ALTHI 0.9.3 im Client bestätigt. Weitere API-Versionen sind nicht deklariert.

## English

- This is the resource-session module. Proven harvesting and allowed special world nodes count; bank/trade/mail, creature loot, crafting/refining outputs and a separate fishing/filleting module are outside its current counting scope. Perfect Roe is only reserved for a future notification integration.
- ESO does not supply complete provenance in each loot event. Conservative interaction checks can miss unusual or delayed events. Known origins are information, not proof of your own find or guaranteed drop rates.
- Special-node names and the five draft translations need further international testing. Some rare material origins remain incomplete.
- Prices are estimates. AGS values are listing prices; NPC fallback is a base value. The optional 7% display factor applies consistently to all sources, including that fallback. Actual rounding, relisting costs and sale proceeds can differ.
- Menu/input behavior is locally regression-tested with client doubles; real window chains with/without LAM and controller menus still need confirmation.
- No direct ESO loot-setting writes were found. The earlier crafting-bag-option observation has no confirmed cause; actual restart/enable/disable behavior with other addons remains a client test.
- Declared manifest API is 101051, confirmed by Roman in the client running ALTHI 0.9.3. Other API versions are not declared.

## 0.9.4 language loading

English/client language load by default; other interface languages require their optional packs. Stored preferences survive missing packs. Native load order, saved-data upgrade and crafting-bag event filtering still require the final 0.9.4 in-game check. No experimental fishing functionality is included.
