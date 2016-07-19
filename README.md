# WA_Radar
A radar for World of Warcraft written for WeakAuras

Idea of this module came from looking at the implementation of [ekardnah](http://www.mmo-champion.com/members/742395-ekardnah) the module can be found on [mmo-champion](http://www.mmo-champion.com/threads/1839869-Raid-HUD-plotter-for-WeakAuras).
What this implementation tries to do is expand on the idea and add more features and even easier extensions.

## Getting started

Radar CORE is a WeakAura that's controllable by making additional weakauras. The public API of radar CORE tries to be as simple as possible for an elaborate example please see the examples folder.

### Enable / Disable

Before Radar CORE can do anything it has to be enabled.

```lua
-- Grab the global, always check for existence!
local core = WA_RADAR_CORE
if not core then return end

-- enable CORE
core:Enable()

-- disable CORE
core:Disable()
```

### Connect / Disconnect
Radar CORE is able to connect (or disconnect) lines between members tracked on the radar. To simply connect yourself with a player named "Bob":

```lua
-- Grab the global, always check for existence!
local core = WA_RADAR_CORE
if not core then return end

-- Radar CORE holds an internal map of all player references,
-- you can pass CORE a unitID, unitGUID or unitName as long as it is a member of the group CORE knows who it is.
core:Connect("player", "Bob")

-- By default a width of 4 is used, if you want a bigger line, you are free to adjust the width
core:Connect("player", "Bob", 10)

-- By default CORE will draw a line SEGMENT
-- meaning that the line will be drawn between the two players and won't be extended.
-- You are able to override this by supplying different 'extend modes'.
-- Read more about extend modes in the Init function of CORE.

local EXTEND = core.constants.lines.extend.EXTEND -- will extend the line both ways
core:Connect("player", "Bob", 4, EXTEND)

-- By default CORE sees a line as a dangerous thing,
-- meaning that standing on the line that's drawn will indicate you are in danger,
-- to turn this around you can pass different 'danger modes'.
-- Read more about 'danger modes' in the Init function of CORE.
local FRIENDLY = core.constants.lines.danger.FRIENDLY -- will classify the line as friendly
core:Connect("player", "Bob", 4, EXTEND, FRIENDLY)

-- Disconnecting a line can be done by supplying the correct player references again
core:Disconnect("player", "Bob")

-- or by holding on to the line object itself and call Disconnect on it directly
local line = core:Connect("player", "Bob")
line:Disconnect()

-- or you can disconnect all active lines at once
core:DisconnectAllLines()
```
### Disks
Radar CORE has a very easy api to create disks or areas on the radar to indicate danger or other form of attention.

```lua
-- Grab the global, always check for existence!
local core = WA_RADAR_CORE
if not core then return end

-- Similar to the lines API you can pass any unit reference to CORE

-- Create a default disk on yourself:
core:Disk("player")

-- You are able to specify the radius (in-game yards)
-- To create a disk with a radius of 30 yards:
core:Disk("player", 30)

-- You can also add additional text to the disk for more information
core:Disk("player", 30, "Shackle 1")

-- By default CORE sees a disk as a dangerous zone,
-- meaning that standing on in the radius of the disk will indicate you are in danger,
-- to turn this around you can pass different 'danger modes'.
-- Read more about 'danger modes' in the Init function of CORE.
local FRIENDLY = core.constants.disks.danger.FRIENDLY -- will classify the disk area as friendly
core:Disk("player", 30, "Shackle 1", FRIENDLY)

-- To remove the disk:
core:RemoveDisk("player")

-- or hold on to the disk reference yourself and destroy it
local disk = core:Disk("player")
disk:Destroy()

-- or destroy all disks at once
core:DestroyAllDisks()
```

### Static points
Radar CORE has a way to add points on the radar, these points are static and can be added/removed at any time.
*Static points have the exact same behaviour as members on the radar, you can connect them or place disks on them!*

```lua
-- Grab the global, always check for existence!
local core = WA_RADAR_CORE
if not core then return end

-- A static point can be created using x and y coordinates and by supplying a name
-- the name has to be unique!
core:Static("my_new_static", 4450, 3530)

-- Because you might want to capture the position of a member of the raid and turn it into a static point
-- CORE has a very easy way todo so,
-- To capture your own position and convert it to a static point:
core:Static("my_personal_static", "player")

-- Static points are by default rendered as white circles with a black dot in the middle
-- You can also give the static point a raid marker, to indicate special points on the map
-- Just supply a raidtargetindex as last argument to either function invocation.
local star = 1
core:Static("my_new_static", 4450, 3530, star)
-- or
core:Static("my_personal_static", "player", star)
```

### Utilities
Radar CORE also offers some utility functions that can be used at any time.

```lua
-- Grab the global, always check for existence!
local core = WA_RADAR_CORE
if not core then return end

-- Calculate the distance between two units (can also be static points)
core:Distance("player", "Bob")
-- output: 60.050

-- Check if Bob in a range of 20 yards of yourself
core:IsInRange("Bob", 20)
-- output: true/false

-- Get a list of all unitIDs (raid1, raid2, raid3, ...) of all members in range of a given unit
-- ONLY COUNTS REAL PLAYERS
core:GetInRangeMembers("Bob", 20)
-- output: { "raid1", "raid2", "raid3" }

-- Get the total count of players in range of a given unit
-- ONLY COUNTS REAL PLAYERS
core:GetInRangeCount("Bob", 20)
-- output: 3

```

# STILL BEEING ACTIVELY DEVELOPED!
