# Fury's Guild Management Toolset (ESO addon) v1.16.11

**AI disclosure:** This addon's code was written with the assistance of an AI coding assistant (Claude by Anthropic), working from my designs and instructions. I test every release in game in my own guilds before it goes up, and I maintain it. Please report any problem in the comments.

**Credits:**

- Guild history is read through **LibHistoire** by sirinsidiator (Artistic License 2.0).
- Settings pages use **LibAddonMenu-2.0** by Seerah and sirinsidiator.
- Game API details from the ESOUI wiki and ZeniMax's ESO UI source code.
- Thanks to Dack for code review feedback on how guild history should be read.
- The Guild Crier started as my own separate addon, "Fury's Guild Crier", and is now part of this toolset.

**An officer toolkit for ESO guild leaders and officers.** It watches your guild banks, rosters, trader and guild store, tells you when something needs your attention, and lets you deal with it in a click or two. It also helps you advertise, recruit, welcome new members, run raffles and fill your guild events from sesh sign-ups.

**Every feature starts turned off.** Nothing runs, alerts, logs or mails until you turn it on, so you can switch on only what you want. Updating from an older version keeps your settings as they were.

**You stay in control.** Nothing is done to a member without your click, unless you turn on auto-demote yourself. The addon never kicks, invites or posts in chat by itself: chat text waits in the chat box for you to press Enter, and mails open for you to press Send.

**Requires:** **LibHistoire** (AddOn version 1112 or newer) and **LibAddonMenu-2.0** (version 43 or newer). Both are separate downloads: search for them in Minion, or get them from ESOUI.

**Download:** [ESOUI](https://www.esoui.com/downloads/info5063.html) or Minion, or [FurysGuildToolset-1.16.11.zip](https://github.com/AlbertHoffpauir/FurysGuildToolset/raw/main/downloads/FurysGuildToolset-1.16.11.zip) from GitHub. To install by hand, copy the `FurysGuildToolset` folder to `Documents/Elder Scrolls Online/live/AddOns/`.

**Contents:** [Getting started](#getting-started) · [Finding your way around](#finding-your-way-around) · [Bank alerts](#bank-alerts) · [Auto-demote and the Auto tab](#auto-demote-and-the-auto-tab) · [Members and Inactive](#members-and-inactive) · [Kick and blacklist mails](#kick-and-blacklist-mails) · [Bank hoppers and watchlist](#bank-hoppers-and-watchlist) · [History](#history) · [Bank space](#bank-space) · [Trader and Member sales](#trader-and-member-sales) · [Guild Crier](#guild-crier) · [Recruiting](#recruiting) · [Raffle](#raffle) · [Events](#events) · [Questions](#questions)

## Getting started

1. Install **LibHistoire** and **LibAddonMenu-2.0** (see Requires above). The addon won't load without them.
2. Log in and type `/gtsettings`. Under **Guilds to get alerts from**, tick the guilds you look after, then reload when asked. (Only needed for the bank, member, hopper and bank space features.)
3. On the same page, turn on the features you want. Each one has its own section below with what to turn on and where.
4. Click **Open Guild rules settings** and set the rules for each ticked guild: bank limits, who to ignore, inactivity limits and so on. **Copy rules from** gives a guild the same rules as another in one click.
5. Type `/gt` (or set a keybind) to open the report window. Each feature has its own tab.

## Finding your way around

### The report window

- `/gt` opens it; `/gt bank`, `/gt members`, `/gt raffle` and so on open a tab directly (see Commands).
- **Right-click any row** for what you can do with it: whisper, mail, set rank, kick, dismiss and more. The line at the top of each tab reminds you.
- To copy someone's @name, right-click their row > **Copy @name**. The name shows up selected in a small window; press Ctrl+C.
- **Hover** over any button, tab, column header or row for a short tip or the full details.
- Click a column header to sort, and again to reverse.
- Every tab has an **Export / copy** button: the tab as comma-separated text to paste into Excel, Google Sheets or Discord.
- The gear at the top right opens the settings.

### The settings pages

- Esc > Settings > Add-Ons, or `/gtsettings`. There are six pages, all starting with "Fury's Guild Management":
- **Fury's Guild Management** (main page): guilds to get alerts from, bank alerts, members, hoppers, history, automatic actions, bank space and trader week totals. It has a button that opens each of the other pages.
- **- Guild rules:** a **Rules for (guild)** section for each ticked guild.
- **- Recruiting**, **- Raffle**, **- Events** and **- Crier:** everything for those features.

### Commands

- `/gt`: open or close the report window.
- `/gt bank`, `hoppers`, `watchlist`, `history`, `space`, `members`, `inactive`, `trader`, `sales`, `auto`, `recruit`, `raffle`, `events`, `crier`: open that tab.
- `/gtsettings` (or `/gt settings`): open the settings.
- `/gt tour`: start or stop the recruiting zone tour.
- `/gt raffle add @name 3 (reason)` and `/gt raffle remove @name 3`: change someone's raffle tickets by hand.
- `/crier`: the Guild Crier menu. `/crier next` posts the next message, `/crier reset` restarts the rotation.
- `/gt status`: how much history has loaded per guild, and the biggest withdrawers. `/gt guilds`: which guilds have alerts on.
- `/gt reset`: rebuild the alerts from the logged history with your current settings (what you already did is kept). `/gt reset full`: wipe the log and trader totals and download the look-back period again (settings and watchlist are kept).

### Keybinds

- Controls > Keybindings > Fury's Guild Management: open or close the report window, open or close the Crier menu, post the next Crier message, put the zone ad in chat, start or stop the zone tour, and travel to the next ready zone.

## Bank alerts

Catch members who take more from the guild bank than your rules allow.

### Turn it on

- Tick your guilds under **Guilds to get alerts from**, then turn on **Guild bank alerts > Enable bank alerts** (main settings page).
- On the **Guild rules** page, set each guild's limits: warn, demote and kick at X stacks per day (0 = never). Demote starts at 50; warn and kick start off.
- Add your bankers and restocking officers under **Ignore rank names** or **Ignore @names**. The top 2 ranks are ignored from the start.
- Optional: **Watch gold withdrawals too** (warn 50,000, demote 200,000, kick 500,000 gold per day), counting items instead of stacks, or a rolling window of hours instead of midnight to midnight.

### Use it

- You get a chat and on-screen alert as it happens while you're online, and a summary at login.
- The **Bank alerts** tab (`/gt bank`) lists everyone over a limit: how many stacks and items they took, and how many came back. Hover for the full item list.
- Right-click an alert for **Whisper**, **Mail**, **Warn** (by whisper or mail), **Demote**, **Set rank**, **Add to guild note**, **Kick**, **Kick and blacklist** and **Dismiss**. Anything that changes the guild asks first.
- Warn and Demote open a filled-in message: the date, what they took, and your bank rules (from the Crier's "Guild Bank 101" message unless you write your own). Every text can be changed in the guild's rules.

### Good to know

- A stack put back whole within 72 hours (adjustable) doesn't count. A partly used stack still counts.
- Deposits never count, so stocking the bank never triggers anything.
- The first time, the addon looks back 30 days. Old withdrawals show up as alerts to review; nothing is done to anyone for them.
- After changing limits, click **Rescan with current settings** (main page) or type `/gt reset`.

## Auto-demote and the Auto tab

Optional: let the addon demote someone the moment they reach a guild's demote limit.

### Turn it on

- On the **Guild rules** page, in that guild's rules, turn on **Auto-demote at the demote threshold**. Each guild is separate.
- Optional, in the same place: **Send the demotion mail automatically** and **Note the reason in their guild note**.
- Optional, on the main page under **Automatic actions**: **Alert window for auto-demotes** (a big window that stays until you close it). **Test the alert window** shows you what it looks like.

### Use it

- Each auto-demote is explained in chat: old and new rank, the rule they hit, and each withdrawal.
- The **Auto** tab (`/gt auto`) keeps everything the addon did by itself, with the reason: auto-demotes, demotion mails and hoppers added to the watchlist. It shows whether the server confirmed the new rank and the mail. If a mail failed, right-click to send it.

### Good to know

- Only withdrawals after you turn it on count. It never touches anyone at or above your rank or on your ignore lists.
- At most 5 per session over all guilds (change it under **Guild bank alerts**).
- Kick and blacklist always need your click. The addon never kicks anyone by itself.

## Members and Inactive

See your whole roster, and who has been offline too long.

### Members tab

- `/gt members`: every member's rank, time at rank, last promotion, last online and guild note. Filter by guild or rank, hide offline members, search and sort.
- Right-click a member to whisper or mail them, **Set rank**, **Kick** or **Kick and blacklist**. Each change asks first.

### Turn on inactivity alerts

- On the **Guild rules** page, in each guild's rules, turn on **Inactivity alerts**.
- Set the limits: officers 30, members 21, recruits 14 days offline to start with. For each rank, pick which limit applies, or no check.
- Optional, on the main page under **Members and inactivity**: **Alert at login** tells you how many are over the limit.

### Inactive tab

- `/gt inactive`: members over the limit for their rank, and how many guild slots each guild has open (out of 500).
- Right-click for a **"we miss you" mail**, a blank mail, **Set rank**, **Kick**, **Kick and blacklist** or **Dismiss**. A dismissed member comes back if they go over the limit again after logging in.
- Tip: pick Rank: Recruit and sort by Offline to go through recruits from most to least inactive.

### Good to know

- The game doesn't store when someone got their rank, so rank dates come from roster history. Older changes show as "since before (date)".

## Kick and blacklist mails

Optional: mail people why they were removed.

### Turn it on

- On the **Guild rules** page, in each guild's rules under **Mail when you kick or blacklist**, turn on **Mail members kicked for inactivity** and/or **Mail members you blacklist**, and edit the texts if you like.

### Use it

- **Kick** on the Inactive tab mails them why (days offline and their limit) and that they're welcome back if they return to the game.
- **Kick and blacklist** or **Blacklist** on any tab opens a confirm window with a reason box, filled in for you. The reason becomes their blacklist note and goes in the mail.
- The **Send mail** button in the confirm window skips the mail for one person. Hover it to read the mail. The mail goes out after you click Confirm, with normal postage.
- In the mail texts, `<<1>>` is their @name and `<<2>>` the guild; then `<<3>>` is the days offline and `<<4>>` their limit (kick), or `<<3>>` is the reason (blacklist).

## Bank hoppers and watchlist

Spot people who join, empty the bank and leave.

### Turn it on

- Turn on **Bank hoppers and watchlist > Enable hopper report** (main settings page).
- On the **Guild rules** page, set how soon a leave counts (48 hours to start with), and optionally **Add hoppers to the watchlist automatically** and **Alert when a watchlisted person joins**.

### Use it

- The **Bank hoppers** tab (`/gt hoppers`) lists people who joined and left within your time limit. Right-click to blacklist, watch, whisper, mail or dismiss them.
- The **Watchlist** (`/gt watchlist`) is shared by all your guilds and alerts you when a known hopper joins any of them.

## History

A searchable log of your guild banks and rosters.

### Turn it on

- Turn on **History log and export > Keep a history log** (main settings page). Events are kept 90 days to start with (up to 20,000).

### Use it

- `/gt history`: bank items, bank gold and roster events (joins, leaves, kicks, promotions, demotions, blacklist changes) for all your guilds.
- Filter by type, time and guild, search by name or item, or see totals per member.
- **Show: Bank items** marks every withdrawal as returned whole, returned partly or not returned, so you can see who took what and what came back.

## Bank space

Know when a guild bank is getting full.

### Turn it on

- Turn on **Guild bank space > Alert when a guild bank is nearly full** (main settings page). Each guild's alert level (90% to start with) is on the **Guild rules** page.

### Use it

- Open each guild bank once. The game only shows how full a bank is while it's open, so the count updates every time you open it.
- The **Bank space** tab (`/gt space`) shows each bank and how long ago it was counted.

## Trader and Member sales

Weekly trader results, and what each member sold.

### Turn it on

- Turn on **Trader week totals > Keep weekly trader and bank totals** (main settings page). 12 weeks are kept to start with (up to 52).

### Trader tab

- `/gt trader`: for each guild and trader week (from the Tuesday trader change): your trader, sales and tax, what the trader really cost (every bid marked won or refunded), revenue against cost in green or red, and gold in and out.
- **View: traders** compares every trader you held. The top line shows your current trader, the bank gold and when traders change next.

### Member sales tab

- `/gt sales`: what each member sold in the guild store and the tax it earned, for one week or all stored weeks.
- Right-click to whisper, mail (sellers get a filled-in congratulations note) or shout them out in guild chat. **Post top ten** puts the top sellers in the guild chat box.

## Guild Crier

A clickable menu of ready-made guild, zone and whisper messages.

### Use it

- `/crier` (or the Crier tab, or a keybind) opens the menu. Click a message to put it in the chat box, then press Enter.
- `/crier next` (or a keybind) posts the next message in the rotation. The rotation is weighted and remembers its place between sessions.

### Set it up

- On the **Crier** settings page, replace the sample messages and the 19 tips for newer players with your own, add sections, and set each section's channel and rotation weight.
- Optional: a **Rotation reminder** every X minutes. It keeps its timing across logouts and reloads.
- Updates never replace your messages. **Import new tips** adds tips from a newer version.

## Recruiting

Advertise in zones, invite, and welcome new members. Every part is off until you turn it on.

### Set it up

- Open the **Recruiting** settings page (or the button under Recruiting in `/gtsettings`).
- Pick the guild you recruit for, write a zone ad for each guild (`{guild}` becomes the guild's name), and turn on the parts you want.

### Zone ads and the zone tour

- **Put ad in chat** (a button on the Recruit tab, or a keybind) puts your ad in zone chat; press Enter. That zone then goes on cooldown (15 minutes to start with, up to 4 hours), and posting there too soon asks first.
- **Start tour:** each time you press Enter on your ad, you travel to the next ready zone, through a guildmate, a friend or a house you own there, and the ad is waiting when you arrive. Nothing moves until you post. If a jump fails, it tries the next person, then the next zone.
- The **Recruit** tab (`/gt recruit`) lists every zone as ready or on cooldown. Right-click one to travel there, clear its cooldown or leave it out of the tour.

### Invites and leads

- Right-click a name in chat for **Invite to (guild)**.
- **Whisper leads:** when someone whispers a keyword (inv, invite, join, guild to start with), you get an [Invite] link and a row on the Recruit tab. Nobody is invited without your click.
- **Join notices:** who joined, how many slots are left, and a warning when the guild is nearly full or has no trader.

### Welcomes

- Pick a guild under **Welcome settings for**, tick **Welcome new members in this guild**, and write its welcome message and mail. Each guild has its own.
- Someone who joins while you're online gets the welcome in the guild chat box; press Enter. Someone who joined while offline gets a welcome mail that opens for you to send (or goes out by itself, if you turn on **Send the welcome mail automatically**).

### Status bar

- Optional: a small bar you can drag anywhere, with zones posted (for example 5/23), pending applications and whether whisper leads are listening. Show it during the zone tour or always.

## Raffle

Sell raffle tickets for gold and draw the winners. Works without a guild too, for housing, fashion or other groups.

### Set it up

- Open the **Raffle** settings page (or the button under Raffle in `/gtsettings`) and turn on **Turn on the raffle**; reload when asked.
- Pick the raffle guild (or "(no guild)" for mail only), and whether **guild bank deposits**, **mailed gold** or both buy tickets.
- List the prizes, one per line: the first goes to the winner of draw 1, and so on. Set the ticket price, winners, one win per person, an optional limit per person, the start time and how many hours sales run.

### Run it

- On the **Raffle** tab (`/gt raffle`), click **Start sales now** (or let your start time arrive). The tab counts down to the end.
- **Announce in guild** puts the announcement in the guild chat box; **Text for Discord** gives you text to paste into Discord.
- Each deposit or mail buys its amount divided by the ticket price; the rest is dropped (with 1,000g tickets, 5,600g buys 5). Plain donations count too.
- For mailed gold, open your mailbox: each gold mail is counted once and printed in chat. Open it once more after sales end.
- Right-click a buyer to add or remove tickets, or leave them out of the draw. Every change is logged.

### Draw the winners

- When sales end, click **Draw winners** (or **End and draw now** while sales run). Each draw picks a random ticket.
- **Winners to guild chat** and **Winners for Discord** post the results. Right-click a winner to mail them their prize, or to draw a replacement if they can't take it.
- **New / other raffles > New raffle** puts the finished raffle away and opens the settings for the next one.

### Several raffles at once

- **New / other raffles > Add another raffle to sell at the same time** gives you another raffle with its own prizes, price, times, draw and posts. The same button switches between raffles.
- Raffles in different guilds never share bank deposits. Two raffles taking deposits into the same guild bank need different prices: a deposit counts for the raffle whose price it's an exact multiple of, so use odd prices like 1,001g and 1,003g (a new raffle gets one automatically).
- Two raffles taking mail at the same time each need a **mail subject keyword**; a mail counts for the raffle whose keyword is in its subject.
- Anything unclear goes to **Unassigned payments** (in the New / other raffles menu). Right-click to count it for a raffle or ignore it. A raffle won't draw while something unassigned might belong to it.

## Events

See who signed up for a guild event in Discord (sesh bot) and who actually showed up, then fill the empty slots. Works for trials with Tank, Healer and DPS limits, and for classes or any event with no limit.

### Turn it on

- Open the **Events** settings page (or the button under Events in `/gtsettings`) and tick **Turn on Events**.
- Under **Guilds to advertise in**, tick the guilds that should get your ads for open slots.
- **Group forms (minutes before start)** is when your group starts forming (15 minutes before the start time by default). Before then, ads ask people to sign up. From then on, they ask for replacements.
- Tick **Invite by code** and set your **Invite code** ("X" to start with; upper or lower case both work) if people who type the code in guild chat should get a group invite (see Fill the empty slots).
- Change the whisper, mail and guild ad texts if you like (one ad for sign-ups, one for replacements). {name}, {event}, {time} (how long until it starts, like "3d 4h 30m from now", right in every time zone), {date}, {need}, {cp}, {code} and {me} are filled in for you.

### Read the sign-ups

- In Discord, select the sesh event post from its title down to the last name under the last role, and press Ctrl+C.
- On the **Events** tab (`/gt events`), click **Paste sign-ups**, click in the box, press Ctrl+V, then **Read sign-ups**.
- The addon reads the title, time, CP requirement ("160 CP"), required addons, and every sign-up section with its limit: "Tank (1 / 2)", "DPS (1 / 8)", "Standby (0)" or "Attendees (4)". Any number of tanks or DPS works, and so does a section with no limit.
- When the event is over, click **Clear** to empty the tab. The accounts you matched to Discord names are kept for the next event.

### Who's here, who's missing

- Each sign-up shows as **In group**, **In group as (another role)**, **Online, not in group** or **Offline** (with how long), plus their group role and CP. CP under the requirement shows in red.
- People in your group who didn't sign up show as **Not signed up**.
- Discord names are matched to @accounts by name (fancy letters and spaces are ignored). If a match is wrong or missing, right-click the row > **Set account**. The addon remembers it for every event.
- The line at the top shows each section's sign-ups and how many are here, and the open slots:
- Before the group forms: **Open sign-up slots** (for example "1 tank, 6 DPS"), the slots nobody has signed up for. Everyone who signed up keeps their slot.
- Once the group forms (start time minus the minutes in the settings): **Need now** (for example "1 tank, 1 healer, 7 DPS"), what your group is missing, so people who signed up and didn't show count as open too.

### Ping the missing people

- Right-click a sign-up to **Whisper** them (the text waits in the chat box), **Invite** them to the group, or **Mail** them (the mail opens for you to send).
- **Invite online** sends a group invite to every sign-up who is online and not in your group (not Standby).
- **Copy for Discord** gives you a message to paste into Discord. Before the group forms it lists the open sign-up slots. Once it forms it lists the missing names and what the group needs now. A menu lets you pick either; the one that fits the time is first.

### Fill the empty slots

- With **Invite by code** on, anyone who types your invite code in the chat of a guild you advertise in, or whispers it to you, gets a group invite once the group forms (until 2 hours after the start time). The replacement ad tells people the code; while Invite by code is off, the ad leaves the code out. Nobody is invited when the group is full, when you aren't the group leader, or when their CP (as their guild shows it) is under the post's requirement; you get a chat line instead.
- **Advertise in guilds** puts an ad in the chat box of each ticked guild, one after another. Press Enter for each. Pick the kind from the menu: **Ask for sign-ups** (before the event, for the slots nobody signed up for) or **Ask for replacements, join now** (once the group forms, for no-shows and empty slots). The one that fits the time is first.
- **Group Finder** shows a listing to check: the first line is its title (the event's name; numbers and symbols are taken out, since the Group Finder takes letters and spaces only, and at most 5 words: day names go first, then words from the end), the rest its description (the description from the sesh post, cut to fit; the Group Finder shows the roles it still needs by itself). It picks the trial from the post ("Sunspire", "vSS") and lists it as Veteran unless the post says normal (or "nSS") and switches your difficulty to match, as the game's own Group Finder does, the playstyle (Educational when the post says trainer or training, Speed Run for a zerg or loot run, Standard otherwise), Voice Chat Required with VOICE REQUIRED in the description (and in the title when the game takes it) when the post says learn, sets the CP minimum, and sets the group's roles to the sign-up limits (2 tanks, 2 healers, 8 DPS for a trial when the post doesn't say). The Group Finder shows who's there and who's still needed by itself. Edit it, then press **Create listing**. You accept applicants in the game's Group Finder window.

## Questions

**Will it kick, blacklist or invite people on its own?**  
Kick, blacklist and Group Finder listings always need your click, and kicks and blacklists ask to confirm. It can do two things by itself, and only if you turn them on: demote (auto-demote), and invite someone who types your event invite code (Invite by code on the Events page).

**I just installed it and already have a pile of alerts. Did it do anything?**  
No. The first time, it looks back 30 days so you can review older withdrawals. Nothing is done to anyone for those.

**Why does Warn put the text in my chat box instead of sending it?**  
Addons can't send chat messages. Press Enter to send it. Mails open filled in and you press Send.

**My bankers keep getting flagged.**  
Add their rank name or @name to the ignore lists in that guild's rules (Guild rules page), then type `/gt reset`.

**I don't see a Rules for section for my guild.**  
Tick the guild under Guilds to get alerts from (main settings page) and reload. The Rules for sections are on the Guild rules page.

**Why is the Bank space tab empty?**  
The game only shows how full a guild bank is while it's open. Open each guild bank once.

**Do I need to be online for it to work?**  
Addons only run while you're logged in. Anything that happened while you were away is picked up at your next login.

**Can my rank use the menus?**  
The menus do what the game lets your rank do. If your rank can't demote, kick or invite in that guild, the game won't allow it.

Bug reports and ideas are welcome in the comments on ESOUI.

---

<sub>**AI disclosure:** This addon's code was written with the assistance of an AI coding assistant (Claude by Anthropic), working from my designs and instructions. I test every release in game in my own guilds before it goes up, and I maintain it. Please report any problem in the comments.</sub>
