Version 1.0

**SETUP GUIDE AT THE BOTTOM**

My custom version of mouse2joystick tweaked for shadPS4 and Bloodborne.
I only take credit for the improvements and new features I developed (see below), everything else is credited to the original creators:
 * Helgef - Original creator of mouse2joystic
 * CemuUser8 - Mouse2joystick Custom CEMU version
 * CemuUser8 - CvGenInterface.ahk
 * evilC - CvJoyInterface.ahk
 * nefarius/Scarlett.Crush Productions - ScpVBus
 * Shaul Eizikovich - vGenInterface

# Improvement
 * "SR40" bug fix. This fix makes the mouse input way more precise and consistent. Easiest to explain with pictures:

# New features
 * Deadzone compensation. Allows the user to entirely eliminate the ingame deadzone. The value (between 0-1) represents the relative position where the stick tilt will start when the mouse is moved. Should be set the same as the ingame deadzone (which can be found by trial and error). Bloodborne has a fairly large deadzone, around 0.37. This means you have to tilt the stick to at least 37% of its full range, otherwise no camera movement is registered. So, if you set this to 0.37 then any mouse movement will cause the stick to start at 37% of its full range, thus eliminating the deadzone. If set to 1 then any mouse movement will cause full stick tilt.
 * Mouse acceleration. A very simple implentation, increases stick sensitivity the faster the mouse moves. Set to 0 to disable it.
 * Bloodborne Bonus Buttons. Fromsoft games like to do this thing where roll, backstep, sprint and jump are all the same button. This doesn't have to be this way, so I implemented hotkeys for these actions, so now you can bind each of these actions to separate keys. I also added a jump attack key. Later I may add a save-and-quit hotkey.

# Settings Overview
 * General
	* Output Mode - should be vXBox, as vJoy is not supported by shadPS4 and I did not test the new features with vJoy
	* Executable Name - enter the executable name (e.g. shadPS4.exe) that you want m2j to switch to when auto activate in turned on
	* Auto Activate Executable - if turned on then m2j will switch to the game window when the toggle key is pressed
 * General-Setup
	* Resistance - controls the camera sensitivity. Value in pixels that the mouse has to move to tilt the stick completely. Setting this to 1 will cause full stick tilt on any mouse movement.
	* Non-Linear Sensitivity - Lower values cause the sensitivity to be raised near the center
	* Deadzone - Adds deadzone to the mouse. Not needed for shadPS4! Should be 0
	* Mouse Check Frequency - Value in ms. This is how often the mouse position is checked and reset back to the center. Higher value causes delayed camera control. Should be somewhere between 1-50.
	* Deadzone Compensation - Used to eliminate ingame deadzone. Causes the stick tilt to start at the specified value. E.g. 0.5 will make the stick tilt start at 50% of its full range. Should be the same as the game's deadzone to improve mouse precision.
	* Mouse Acceleration - Exponent to control the mouse speed/camera sensibility curve. Fast camera movement becomes even faster, slow camera movement is less affected. Set to 0 to turn it off.
 * General-Hotkeys
	* Toggle Controller On/Off - Set the key to choose the Toggle for the controller (Default F1)
	* Quit Application - A Master Hotkey to quit out of the script immediately
 * Mouse2Joystick-Axes
	* Invert X-Axis - self explanatory
	* Invert Y-Axis - self explanatory
 * Mouse2Joystick-Keys
	* Active KeyList - Shows your main keybinds as a comma separated list
	* KeyList Helper - This is where you can conveniently set up your main keybinds
	* Saved KeyList Manager - Allows you to save your main binds into separate profiles
 * Keyboard Movement-Keys
	* Keyboard Movement - self explanatory
	* Walking - set up a key to toggle walking and increase/decrease walking speed
 * Bloodborne Bonus Buttons
	* Bonus Buttons - I used the same interface as the KeyList Helper. Each key does specifically what it says. All dodge and backstep binds are executed on key press, rather than on release.
		* Dodge/Backstep (no jump) - Dedicated dodge/backstep key. If used while stationary it causes a backstep. If used while moving it causes a dodge. If used while sprinting, it cause you to momentarily stop and roll.
		* Dodge (no jump) - Dedicated dodge key. If used while stationary it causes you to dodge forward. If used while moving it causes a dodge. If used while sprinting, it cause you to momentarily stop and roll.
		* Dodge/Backstep (with jump) - Same as above, but can be used for jumping
		* Dodge (with jump) - Same as above, but can be used for jumping
		* Backstep - Dedicated backstep key. If used while stationary it causes a backstep. If used while running/sprinting, it cause you to momentarily stop and backstep.
		* Sprint - Dedicated sprint key. If used while moving, it makes you sprint. Otherwise, it does nothing.
		* Jump - Dedicated jump key. If used while sprinting if initiates a jump (after the minimum time needed to reach jumping speed). Otherwise, it does nothing.
		* Jump Attack - Dedicated jump attack key. Does a jump attack. Can be used while stationary/running/sprinting.
 * Extra Settings - apart from the self explanatory hide cursor option, these are not tested with shadPS4 and probably won't work.

## Known issues
 * After using the script for a while, then toggling if off, mouse buttons stop working (mouse can still move). User can only click on the game window. Workaround: press ctrl+alt+del then esc to fix this state.

# Setup Guide
1. Download and extract the latest release of mouse2joystick_shadPS4
2. Run mouse2joystick_shadPS4.exe as admin. You'll get a prompt to install ScpVBus (virtual XBox controller driver). Click yes, the driver will install and the script will reload.
	* If the driver installation was succesfull, you'll hear the device connected sound and Scp Virtual Bus Driver and Xbox 360 Pheripherials will show up in your Decive Manager. If you have issues try running the Install.bat as admin in the ScpVBus folder.
3. Double click on the mouse2joystick tray icon
	* General-Hotkeys to set a toggle key for mouse2joystick (default is F1)
	* General-Setup if you want to tweak your mouse
	* Mouse2Joystick-Keys to set up your main keybinds (several profiles can be saved with the KeyList Manager)
	* Keyboard Movement-Keys to set up your movement keys and walk toggle key
	* Bloodborne Bonus Buttons to set up special keybinds for Bloodborne
4. Run the game and press your toggle key (default is F1)
