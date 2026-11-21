# ESQL

An in-game SQL window for Elder Scrolls Online, built on [LibESQL](../LibESQL/README.md). Look up any ability id, find sets by their bonus text, list your buffs, count your collectibles, and keep notes and lists of your own in saved tables. It works on PC/Mac and console.

```sql
SELECT id, name, duration_ms, cost FROM abilities WHERE name LIKE '%whip%'
SELECT s.name, b.description FROM sets s JOIN set_bonuses b ON b.set_id = s.id WHERE b.description LIKE '%critical%'
SELECT unit, name, remaining_s FROM effects WHERE unit = 'player'
```

## Install

1. Copy the `ESQL` and `LibESQL` folders into `Documents/Elder Scrolls Online/live/AddOns/`.
2. For console, also install **LibHarvensAddonSettings**.
3. Enable both add-ons and `/reloadui`.

## Using it

**On PC**
- Type `/esql` to open the window, or bind a key in Controls > Keybindings > ESQL.
- Type a query and press Enter or **Run**. When you're not typing, the query is shown with **syntax highlighting**: keywords in blue, functions in yellow, table names in teal, text in green, numbers in orange, `?` in purple and comments in grey. While you type it shows as plain text. Turn it off with `/esql highlight off` or the console checkbox. You can also run SQL directly from chat: `/esql SELECT * FROM character`.
- The arrow keys step through your last 50 queries.
- Scroll the results with the **scroll bars** (rows on the right, columns along the bottom), with the mouse wheel, or with Shift+wheel for columns. Drag a bar's thumb, or click its track to jump a page. The `<` and `>` buttons also move across columns.
- Click a column header to sort by it. Hover a cell to see its full text, and click a row to print it to chat.
- Table and column names in the results are shown in **blue**, for example in `SHOW TABLES`, `DESCRIBE` and the `tables` and `columns` tables. Click one to put it into your query:
  - When the query box is empty or still holds `SHOW TABLES`, `DESCRIBE` or `HELP`, it becomes `SELECT * FROM <table>`, or `SELECT <column> FROM <table>` for a column.
  - Otherwise the name goes in where your cursor was, with spaces added as needed. For example, type `SELECT * FROM ` and click a table, or put the cursor after `SELECT name, ` and click a column.
- **Example** cycles through ready-made queries. **Tables** lists everything you can query, and **Help** shows the syntax.
- **New table** opens the Create Table dialog:
  - **Start from** fills in a template (Notes, Wishlist, Boss times, Shopping list).
  - Name the table, then give each column a name and pick its type from the dropdown: **TEXT** for words, **INT** for whole numbers, **REAL** for decimals, **BOOL** for true/false, or **ANY**.
  - **+ Add column** adds a row and **X** removes one. The line underneath shows the exact `CREATE TABLE`, or what needs fixing.
  - **Create** makes the table and puts a ready `INSERT` for it in the query box.
- **Copy** opens the results as text to copy into a spreadsheet or file:
  - Big results are split into pages that the game can display (about 6,000 characters each, always ending at a whole row). Use **< Prev** and **Next >** to move between them. The header row is on page 1, so pasted pages stack into one sheet.
  - **Select all (then Ctrl+C)** selects the page you're on; press Ctrl+C to copy it. The game doesn't let add-ons put text on the clipboard themselves, so the last step is yours.
  - The format button cycles through **Tabs (spreadsheet)**, which pastes straight into separate columns; **Commas (CSV)**, for .csv files; and **MySQL (.sql)**, a `CREATE TABLE` + `INSERT` dump. MySQL pages always end on a whole statement, so paste them in order into one file.
  - For everything in one go, use `/esql export <name>` and the MySQL tool below.
- **A-** / **A+** change the text size, which is remembered.

**On console** (Settings > Addons > ESQL)
- **Edit SQL** opens the on-screen keyboard. Confirm to run the query.
- **Example queries** and **Browse a table** fill in a query for you.
- Use **Down / Up / Right / Left** to page through the results window, and **Print** to send the visible rows to chat.
- The **Syntax highlighting** checkbox (under Results) turns colouring on or off.
- **Create a table** makes a table without typing SQL:
  1. Pick a template under **Start from** (Notes, Wishlist, Boss times, Shopping list) or **Blank**, then change the **Table name**.
     - To add columns, type a name in **New column**, pick its **Type** from the dropdown (TEXT, INT, REAL, BOOL or ANY) and press **Add column**. **Remove last column** takes one off.
     - You can also type the **Columns** line yourself, for example `id INT, note TEXT, done BOOL`.
  2. The line below shows the exact `CREATE TABLE` that will run, or what needs fixing.
  3. Press **Create**.
  4. **Add a row** opens the keyboard with a ready `INSERT` for the new table: change the values and confirm. **View** shows what's in it.

## Other add-ons' saved data

ESQL can read other add-ons' SavedVariables as tables, on PC and on console. Their lists, such as saved fights, tracked items or settings for each character, become their own tables.

```sql
SELECT name, addon, tables FROM saved_variables
SELECT table_name, records FROM sv_tables ORDER BY records DESC
SELECT * FROM sv_consolemetrics_savedfights
```

- Table names in the results are clickable, as usual.
- These tables are read-only: other add-ons' data is never changed.
- Run `SCAN savedvariables` (on console, the **Rescan other add-ons' saved data** button) after installing or enabling add-ons.

## Your own tables

Your own tables are saved with your account and come back after a reload. Every table that comes with ESQL is read-only and can't be changed, dropped or replaced: only tables you create can be written to. Run `SELECT name, writable FROM tables` to see which ones those are.

```sql
CREATE TABLE IF NOT EXISTS notes (id INT, note TEXT, done BOOL)
INSERT INTO notes VALUES (1, 'Farm Kinras''s Wrath', FALSE), (2, 'Buy soul gems', FALSE)
UPDATE notes SET done = TRUE WHERE id = 2
DELETE FROM notes WHERE done
SELECT * FROM notes
DROP TABLE notes
```

- You can also save any query result as a table: `SELECT name, set_type INTO my_sets FROM sets WHERE name LIKE '%mother%'`.
- Give a table a `PRIMARY KEY` to keep one row per thing, then **upsert** into it: new rows are added and existing ones updated.
  ```sql
  CREATE TABLE best (boss TEXT PRIMARY KEY, secs REAL, tries INT)
  INSERT INTO best VALUES ('Zaan', 58, 1) ON CONFLICT DO UPDATE SET secs = MIN(secs, excluded.secs), tries = tries + 1
  UPSERT INTO best (boss, secs) VALUES ('Nirn', 47)
  ```
  In the **New table** dialog, the **Key** button on a column makes it part of the key. On console, add `PRIMARY KEY` after the type in the Columns line.
- `UPDATE` or `DELETE` without a `WHERE` changes every row of the table. ESQL asks first: press **Run** a second time to confirm.

## Commands (PC)

| Command | Does |
|---|---|
| `/esql` | Opens or closes the window |
| `/esql <sql>` | Runs a query |
| `/esql size 1.4` | Sets the text size (0.6 to 2.5) |
| `/esql highlight on` or `/esql highlight off` | Turns syntax highlighting of the query box and previews on or off |
| `/esql track on` or `/esql track off` | Turns on or off the recording of every buff and debuff id you see (`effects_seen`) |
| `/esql log on`, `/esql log off` or `/esql log clear` | Turns on, turns off or clears combat event recording (`combat_log`) |
| `/esql export <name>` | Saves the last result as export `<name>` (default `export`) in `SavedVariables/ESQL.lua`, written on logout or `/reloadui` |
| `/esql exports` or `/esql exports clear` | Lists your saved exports, or removes them all |
| `/esql reset` | Puts the window back in the middle of the screen |

`/sql` works too, if no other add-on uses it.

## Export to MySQL / phpMyAdmin

Your exports and your own tables can go into a MySQL database. The dump is in phpMyAdmin's own format: `utf8mb4`, InnoDB, with column types worked out from the data.

1. In the game, run a query and save it: `/esql export abilities`. Repeat for each result you want, with a different name each time. On console use **Export name** and **Export** in the settings panel.
2. Type `/reloadui` (or log out). Only then does the game write `SavedVariables/ESQL.lua`.
   - **This step needs the PC live or PTS client.** Clients with the console UI (`pccert`, and consoles themselves) keep addon data off your PC and never write these files. Run ESQL in the PTS or live client for this step, or use the Copy window's **MySQL (.sql)** format: Ctrl+C each page in order into one `.sql` file.
3. On your PC, run the tool in `ESQL/tools`. It finds your SavedVariables by itself:
   ```bash
   python esql_to_mysql.py
   ```
   This writes `esql_dump.sql` with:
   - one table per export, named `esql_<name>`
   - every table you created in the game (`CREATE TABLE`, `SELECT ... INTO`), keeping their column types
4. In phpMyAdmin, pick or create a database, then **Import**, choose `esql_dump.sql`, and **Go**.

Options:
- `-o file.sql` sets the output file.
- `--database eso` adds `CREATE DATABASE` and `USE`.
- `--only esql_abilities,notes` exports only those tables.
- `--clean` strips ESO colour codes, icons and link markup from the text.
- `--no-drop` leaves out `DROP TABLE IF EXISTS`.
- `--list` shows what would be exported without writing anything.
- `--sv-dir "<folder>"` uses a specific SavedVariables folder.

You need Python 3.7 or newer, and nothing else. The game ignores the `tools` folder. For a small result, the Copy window's **MySQL (.sql)** format gives the same SQL without leaving the game.

## Good to know

- The first query on `abilities` or `items` indexes every id once per game update. That takes a few seconds and runs in the background, and the window shows its progress.
- Text matching ignores case: `WHERE name = 'molten whip'` works.
- See the [LibESQL README](../LibESQL/README.md) for every table and SQL feature, and the [API Reference](../LibESQL/API%20Reference.md) for the full details.

## License

MIT. See [LICENSE](LICENSE).
