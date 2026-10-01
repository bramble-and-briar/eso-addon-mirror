# Take One
Author: Mightyjo

Depends on: 
- LibAddonMenu-2.0 
- LibCustomMenu 
- LibMarify

Optionally depends on:
- LibDebugLogger
- DebugLogViewer

This add-on provides a context menu option to pull one item from a Bank or Guild Bank stack into your inventory.
NEW in v1.2.0! This add-on provides a context menu option to pull all but one item from a Bank or Guild Bank stack into your inventory.

The context menu item will only appear when all the preconditions to use it are met
- The source slot is in your Bank or Guild Bank.
- You have permission to withdraw and deposit into the Guild Bank.
- You have 2 free backpack slots (for Guild Bank withdrawals).
- The source stack contains more than 1 item.

# Requires 2 free slots in your backpack
When working with the Guild Bank it really just automates the process of withdrawing the whole stack in a bank slot, splitting out one item from the stack, and returning the remaining stack to the Guild Bank. Consequently, you must have 2 free slots in your backpack to withdraw 1 item from a Guild Bank stack. Annoying, but that's what the API allows.  

# Settings
You can turn on debug logging if you're having a problem. If you have DebugLogViewer installed you'll be able to see the add-on working in a UI window. Otherwise, the log is stored in your saved variables whenever you quit or /reloadui.

# Support
If you need help or find a bug, open an issue on the GitHub issue tracker at [https://github.com/Mightyjo/TakeOne/issues](https://github.com/Mightyjo/TakeOne/issues).

# Thanks
Many thanks to the authors whose examples I followed:
- @Marify
- Valandil
- @Architectura
- @Magnum1997
- Wobin
- CrazyDutchGuy
- Ayantir
- silvereyes

Thanks to wolfstar07 for adding support for the Furnishing Vault.

# License

[![CC-BY-NC-SA-4.0Creative Commons License BY-NC-SA-4.0](https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png "Creative Commons License BY-NC-SA-4.0")](http://creativecommons.org/licenses/by-nc-sa/4.0/)  
This work is licensed under a [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License](http://creativecommons.org/licenses/by-nc-sa/4.0/).

# Disclaimer

This Add-on is not created by, affiliated with or sponsored by ZeniMax Media Inc. or its affiliates. The Elder Scrolls® and related logos are registered trademarks or trademarks of ZeniMax Media Inc. in the United States and/or other countries. All rights reserved.

The creation and use of Add-ons are subject to the Add-on Terms of Use, available at [https://account.elderscrollsonline.com/add-on-terms](https://account.elderscrollsonline.com/add-on-terms).
