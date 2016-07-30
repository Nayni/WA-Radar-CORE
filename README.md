# WA RADAR CORE
A radar for World of Warcraft written for WeakAuras

Idea of this module came from looking at the implementation of [ekardnah](http://www.mmo-champion.com/members/742395-ekardnah) the module can be found on [mmo-champion](http://www.mmo-champion.com/threads/1839869-Raid-HUD-plotter-for-WeakAuras).
What this implementation tries to do is expand on the idea and add more features and even easier extensions.

# STILL BEEING ACTIVELY DEVELOPED!

## Getting started

Radar CORE is a WeakAura that's controllable by making additional weakauras. The public API of radar CORE tries to be as simple as possible for an elaborate example please see the examples folder.

To install radar CORE as a WeakAura:

1. Create a new WeakAura of the **Icon Type**
2. Set the color alpha to 0, hiding the icon, all we need is the frame.
3. **(Optionally)** choose an icon, mostly used to identify the WeakAura in the list on the left.
4. The display should be a custom function so use **%c** as the text, this will allow you to input a function as display
5. Set **Update custom text on...** to **Every frame**
6. Expand the text editor and paste the [display function](/CORE_Display.lua) into the editor (just the function, skip the local declaration)
7. Choose a **width** and **height** for the radar (the display logic will always choose the maximum of both and take that as width and height of the radar)
8. Go to the **Trigger** tab
9. Choose **Custom** as your **Trigger Type**
10. Choose **Status** as **Event Type**
11. Choose **Every Frame** as **Check On...**
12. Expand the Text Editor of **Custom Trigger** and paste the [trigger function](/CORE_Trigger.lua) into the editor (just the function, skip the local declaration)
13. Expand the Text Editor of **Custom Untrigger** and paste the [untrigger function](/CORE_Trigger.lua) into the editor (just the function, skip the local declaration)
14. Go to the **Actions** tab
15. Check **Custom**
16. Expand the Text Editor of **Custom Code** and paste the [init code](/CORE_Init.lua) into the editor
17. You've intsalled radar CORE!

## API Documentation

### Enable / Disable

Before Radar CORE can do anything it has to be enabled.

```lua
-- Grab the global, always check for existence!
local core = WA_RADAR_CORE
if not core then return end

-- enable CORE and show the radar
core:Enable()

-- disable CORE and hide the radar
core:Disable()
```

### Connect / Disconnect
Radar CORE is able to connect (or disconnect) lines between members tracked on the radar.

```lua
-- Radar CORE holds an internal map of all player references,
-- you can pass CORE a unitID, unitGUID or unitName as long as it is a member of the group CORE knows who it is.
core:Connect("player", "Bob")

-- By default a width of 4 is used, if you want a bigger line, you are free to adjust the width
core:Connect("player", "Bob", 10)

-- By default CORE will draw a line segment. The line will be drawn between the two players and won't be extended.
-- You are able to override this by supplying different 'extend modes'.
-- See the CORE_Init.lua for more info.
local EXTEND = core.constants.lines.extend.EXTEND -- will extend the line both ways
core:Connect("player", "Bob", 4, EXTEND)

-- By default CORE sees a line as a dangerous thing. Standing on the line will indicate you are in danger.
-- To turn this around you can pass different 'danger modes'.
-- See the CORE_Init.lua for more info.
local FRIENDLY = core.constants.lines.danger.FRIENDLY -- will classify the line as friendly
core:Connect("player", "Bob", 4, EXTEND, FRIENDLY)

-- Disconnecting a line can be done by supplying the correct player references again
core:Disconnect("player", "Bob")

-- Or by holding on to the line object itself and call Disconnect on it directly
local line = core:Connect("player", "Bob")
line:Disconnect()

-- Or you can disconnect all active lines at once
core:DisconnectAllLines()
```
### Disks
Radar CORE is also able to place what's called Disks on members. A disk is an area with a given radius around a member.

```lua
-- Similar to the lines API you can pass any unit reference to CORE

-- Create a default disk on yourself:
core:Disk("player")

-- You are able to specify the radius (in-game yards)
-- To create a disk with a radius of 30 yards:
core:Disk("player", 30)

-- You can also add additional text to the disk for more information
core:Disk("player", 30, "Shackle 1")

-- By default CORE sees a disk as a dangerous zone. Standing in the disk will indicate you are in danger,
-- To turn this around you can pass different 'danger modes'.
-- See the CORE_Init.lua for more info.
local FRIENDLY = core.constants.disks.danger.FRIENDLY -- will classify the disk area as friendly
core:Disk("player", 30, "Shackle 1", FRIENDLY)

-- To remove the disk:
core:RemoveDisk("player")

-- Or hold on to the disk reference yourself and destroy it
local disk = core:Disk("player")
disk:Destroy()

-- Or destroy all disks at once
core:DestroyAllDisks()
```

Disks are stuck on a member, meaning that if the member moves the disk will follow. If you'd like to place static areas you can combine disks with static points (see further).

### Static points
Radar CORE has a way to add points on the radar, these points are, as the name dictates, static and can be added/removed at any time.

**Static points have the exact same behaviour as members on the radar, you can connect them or place disks on them!**

```lua
-- A static point can be created using x and y coordinates and by supplying a name, the name has to be unique!
core:Static("my_new_static", 4450, 3530)

-- Because you might want to capture the position of a member of the raid and turn it into a static point
-- To capture your own position and convert it to a static point:
core:Static("my_personal_static", "player")

-- Static points are by default rendered as white circles with a black dot in the middle
-- You can also give the static point a raid marker, to indicate special points on the map,
-- just supply a raidtargetindex as last argument to either function invocation.
local star = 1
core:Static("my_new_static", 4450, 3530, star)

-- or
core:Static("my_personal_static", "player", star)
```

### Utilities
Radar CORE also offers some utility functions that can be used at any time.

```lua
-- Calculate the distance between two units (can also be static points)
core:Distance("player", "Bob")
-- output: 60.050

-- Check if Bob is in a range of 20 yards of yourself
core:IsInRange("Bob", 20)
-- output: true/false

-- Get a list of all unitIDs (raid1, raid2, raid3, ...) of all members in range of a given unit
core:GetInRangeMembers("Bob", 20)
-- output: { "raid1", "raid2", "raid3" }

-- Get the total count of players in range of a given unit
core:GetInRangeCount("Bob", 20)
-- output: 3

```
