Venom Skull Guard
Version 1.6.0

Author
------
O-Range

Description
-----------
Venom Skull Guard helps prevent accidental low-value
casts of the Necromancer Venom Skull morph, and can also
optionally block Render Flesh and its morphs above a
configurable health percentage.

Unlike other Skull abilities, Venom Skull builds stacks
and gains additional power as those stacks increase.

This addon allows players to protect those valuable
casts through configurable stamina and stack thresholds,
while also offering an independent health threshold
guard for Render Flesh, Resistant Flesh, and Blood
Sacrifice.

Protection types may be used independently or together.

Features
--------
- Venom Skull specific protection
- Optional Stamina Protection
- Optional Stack Protection
- Configurable Stamina Threshold
- Configurable Stack Threshold
- Optional Render Flesh Protection (Render Flesh,
  Resistant Flesh, Blood Sacrifice)
- Configurable Health Threshold ("Block Above Health %")
- Alert Notifications
- Account-wide Settings
- LibAddonMenu Settings Panel

Settings
--------

Enable Blocker
--------------
Master enable/disable toggle for Venom Skull Guard.

Stamina Protection
------------------

Enable Stamina Protection
When enabled, Venom Skull will be blocked if your
stamina percentage falls below the configured value.

Minimum Stamina %
Adjust the minimum stamina percentage required to
cast Venom Skull.

Stack Protection
----------------

Enable Stack Protection
When enabled, Venom Skull will be blocked if your
current Venom Skull stacks are below the configured
threshold.

Minimum Venom Skull Stacks

Valid values:
0
1
2
3

Understanding Venom Skull Stacks
--------------------------------

Venom Skull gains a stack when it is cast.

Because the cast itself contributes a stack, a current
stack count of 2 will result in an empowered three-stack
Venom Skull.

Current Stacks      Result
--------------------------------
0                   Normal Skull
1                   Normal Skull
2                   Empowered Skull
3                   Empowered Skull

For this reason, many players will prefer a setting of 2.

A stack setting of 2 means:

0 -> Blocked
1 -> Blocked
2 -> Allowed
3 -> Allowed

This effectively reserves Venom Skull for empowered casts.

Combined Protection
-------------------

Both Venom Skull protection systems can run together.

Example:

Enable Stamina Protection = ON
Minimum Stamina % = 25

Enable Stack Protection = ON
Minimum Venom Skull Stacks = 2

Result:

Venom Skull is only allowed when:

- Stamina is 25% or higher
- Venom Skull stacks are 2 or higher

Render Flesh Protection
-----------------------

Enable Render Flesh Protection
When enabled, Render Flesh and its morphs (Resistant
Flesh and Blood Sacrifice) are blocked while your
current health percentage is above the configured
threshold.

Block Above Health %
Adjust the health percentage above which Render Flesh
and its morphs are blocked (default: 70%).

Alerts
------

Optional alerts notify you when a cast is blocked and
display the reason for the block.

Requirements
------------

- LibSkillBlocker version 110 or newer
- LibAddonMenu-2.0 version 43 or newer

Installation
------------

1. Install the required libraries.
2. Extract the addon folder into:

   Documents\Elder Scrolls Online\live\AddOns

3. Enable the addon from the ESO AddOns menu.
4. Configure through:

   Settings -> Addon Settings -> Venom Skull Guard

Version History
---------------

Version 1.6.0
- Merged Render Flesh protection (Render Flesh, Resistant
  Flesh, Blood Sacrifice) above a configurable health %
- Added Render Flesh settings to the LibAddonMenu panel
- Added Render Flesh block alerts and independent alert
  cooldown tracking
- Updated addon version to 1.6.0 and documentation

Version 1.5.1
- Added explicit dependency version requirements
- Updated documentation

Version 1.5
- Rebranded from Necro Stamina Guard
- Updated addon naming throughout
- Updated documentation
- Added Venom Skull specific descriptions

Version 1.4
- Added Venom Skull stack protection
- Added configurable minimum stack threshold
- Added separate stamina protection toggle
- Added combined stamina and stack blocking logic
- Added stack-based alert messages

Version 1.0
- Initial release

Thank You
---------

Venom Skull Guard was created to help players protect
valuable Venom Skull casts and avoid wasted Render
Flesh casts while preserving the freedom to customize
how those protections work.