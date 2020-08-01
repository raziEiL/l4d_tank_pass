
# l4d_tank_pass
The plugin developed for [Left 4 Dead](http://www.l4d.com/blog/ "Left 4 Dead & Left 4 Dead 2")  games under [SourceMod](https://www.sourcemod.net/ "SourceMod") platform (SourcePawn).

## Features:
- Pass the Tank (player to player).
- Confirmation menu for new Tank owner.
- Flexible configs. 
- Admin menu: 
  - Pass the Tank (without confirmation)
  - Takeover the Tank (AI to player)
- Supports both left 4 dead games.
- Don't break game behavior.
- Supports En,Ru languages.

## Credits:
[Scratchy (Laika)](https://steamcommunity.com/id/Myavuka/) - For idea and base code.  
[tRizo Chuck {RW}](https://steamcommunity.com/profiles/76561197998918131/) - For tons of testing.  
[AdMiRaL*MaLinKa](https://steamcommunity.com/profiles/76561199011947213/) - Testing.  


## Сonsole Variables:

    // "Tank Pass plugin version."
    l4d_tank_pass_version
    // "Execute command according convar value on old_tank and new_tank to close 3d party HUD."
    l4d_tank_pass_command "sm_tankhud"
    // "0=Kill the alive player before the Tank pass, 1=Replace the alive player with an infected bot before the Tank pass."
    l4d_tank_pass_replace "1"
    // "0=Allow to pass the Tank when taking any damage, 1=Prevent to pass the Tank when taking any damage."
    l4d_tank_pass_damage "0"
    // "0=Allow to pass the Tank when on fire, 1=Prevent to pass the Tank when on fire."
    l4d_tank_pass_fire "1"
    // "If l4d_tank_pass_fire convar set to 0: 0=Ignite the new Tank when passed, 1=Extinguish the new Tank when passed."
    l4d_tank_pass_extinguish "0"
    // "Sets the Tank passed count according convar value when taking control of the Tank AI. If >1 the tank will be replaced with a bot when the his frustration reaches 0."
    l4d_tank_pass_takeover "1"
    // "0=Off, 1=Display pass command info to the Tank through chat messages."
    l4d_tank_pass_notify "1"

## Сonsole Commands:

    // Player Commands:
    sm_pass/sm_tankpass // Pass the Tank control to another player.
    
    // Admin Commands (ADMFLAG_KICK):
    sm_forcepass <#userid|name> // Force to pass the Tank to target player.
    sm_taketank <#userid|name> // Take control of the Tank AI.

## Plugin Forwards:

    /**
     * Called whenever plugin replaces a players tank control with another player
     *
     * @param old_tank	the player who was a tank
     * @param new_tank	a player who will become a new tank
     * @noreturn
     */
    forward void TP_OnTankPass(int old_tank, int new_tank);

## Plugin Requirements:
[Left 4 DHooks Direct](https://forums.alliedmods.net/showthread.php?t=321696)  
[l4d_lib.inc](https://github.com/raziEiL/rotoblin2/blob/dev/left4dead/addons/sourcemod/scripting/include/l4d_lib.inc)
## Donation
If you want to thank me for the hard work feel free to [send any amount](https://www.paypal.me/razicat "send any amount").

## Note:
1. Multiply Tanks plugins is not supported!
2. sm_pass command is blocked on final stages due [issue #3](https://github.com/raziEiL/l4d_tank_pass/issues/3).


## Changelog:
v 2.2 (01 Aug 2020)
 - Blocked sm_pass command on final stages.
 - Updated translations.

v 2.1 (24 July 2020)
 - Released on alliedmods.net.
 - Added the tank pass/takeover cmds to admin menu.
 - Added more convars.
 - Bug fixes.
 - Phrases grammar fixes.
	
v 2.0 (23 July 2020)
 - Updated SourcePawn syntax.
 - left4dhooks migration.
 - Added l4d2 support.
 - Added confirm menu.
 - Added sm_tankpass, sm_tankfpass commands.
 - Removes tank_pass_button convar.

v 1.1 (14 February 2014)
 - Added TP_OnTankPass forward.
 - Added tank_pass_button convar.
 
v 1.0 (somewhere in 2013)
 - Released privately for some l4d1 servers.
