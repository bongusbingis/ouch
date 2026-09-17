# STRUCTURAL/BUILD/LAYOUT/GAMEPLAY ISSUES IN ALL MAPS
- almost all of the maps (except summit, because it was a legacy map) use a clear blue "water" as the thing players fall into, which is visually inconsistent with the game. all splashdown maps should utilize the purple lava within summit splash.
- checkpoints are too strict in detecting when players reach them; currently, they have to go directly through the arch. instead, imagine an invisible clear wall splitting the checkpoint in half, if the player crosses that wall, they should be counted. essentially just make the detection area larger in case players dont go directly through the arch.
- repeated and unnecessary overruse of certain assets. see ![ball barrage chaining them together](image-32.png)
- there's also a common recurring overuse pattern of map assets (a lot of the time the "1-2-3" stack pictured) being used in transitional ways or being resized to serve a purpose they dont fit. for instance, in ![this screenshot from ball barrage](image-33.png) it is used as a small bridge off of a ramp when that could have just been a plain colored part or a more suitable mesh.
- the pictured green ramp is largely used in all the courses and has an angle at the beginning/end of it, which resulted in many gaps or unnatural junctions between platforms like shown ![here](image-34.png)) and ![here](image-35.png), also compare their position relative to the normal arrows I put in ![this image](image-42.png), and ![this image](image-44.png) for more insight. this is a reoccurring problem in many other areas throughout the map.
- overall, the model that built these courses neglected to use many of the assets it was given holistically ![as shown in this image](image-36.png). the splashdown assets are already comprehensively inventoried in @01-asset-inventory.
- there are many "foam pits" that appear throughout the courses; remove these entirely. that idea is from an old GDD doc that is no longer a legitemate feature. it doesn't make sense to have foam pits for courses floating in the air


# MAP-SPECIFIC FIXES (formatted in image - description format, with some issues having no associated image alongside their description)

Ball Barrage
- the checkpoints are broken and not properly advancing my progress; i am entering some checkpoints and nothing happens
- ![alt text](image-1.png) the third ball players are supposed to jump on is too high after the ramp down for the player to be able to jump on it
- ![alt text](image-14.png) slide is literally stuck clipping through the map
- ![alt text](image-15.png) bumper in the middle of the finish line + z-clipping between the final and second-to-last platforms
- ![alt text](image-24.png) i don't like how this spiky spinning wheel moves side-to-side and its also clipping into the platform below it 
- ![alt text](image-25.png) only one random bumper placed on this stretch containing no map hazards; add more in areas that make sense
- ![alt text](image-26.png) towards the end of the course it becomes very bland with no real hazards or obstacles


TipToe Trials
- ![alt text](image-3.png) the seesaw platform doesn't dip down far enough to be hazardous or dangerous to players
- ![alt text](image-4.png) same seesaw issue as image-4
- ![alt text](image-5.png) spinner is not centered on the platform
- ![alt text](image-27.png) oddly and sloppily placed jump pads; why are they hanging off the edge?
- ![alt text](image-28.png) this fan is clipping into the platform
- ![alt text](image-39.png) the layout pictured here isn't logical. what is the point of the flap going up and down if there's a platform under it?


Piston Peak
![alt text](image-10.png) - these bumpers are jammed too close together and overlapping each other
![alt text](image-12.png) - random, sloppy placement of the same yellow wall with a hole in it - also shown ![here](image-37.png)
![alt text](image-13.png) - the pink tunnel looks like it was just copied and pasted onto the ending, also there is visible z-clipping in this screenshot. both of these issues are recurring in many maps.

Tumble Tunnels
- the beach balls blown through the tunnel don't pose a real hazard to players nor are they spawned often enough nor are they big enough. they dont give any knockback like other map hazards which needs fixing.
- ![alt text](image-18.png) - the fan is rotating on the y axis not on its relative axis; it thinks its still blowing up
- ![alt text](image-19.png) towards the maps end there is a fan literally inside of a platform
- the ending tunnel slightly too difficult to traverse and overall needs remediation; pictured from the side ![here](image-40.png)

Summit Splash
- ![alt text](image-29.png) - overruse of the yellow wall assets (with/without the center hole); sloppy. also shown ![here](image-38.png)
- ![alt text](image-30.png) - i genuinely dont know what to make of this image; this is towards the end of summit splash and it is terrible. i cant even make out whats supposed to be happening here.
- ![alt text](image-31.png) finishing arch is HUGE compared to other maps. 

Door Dash
- the map name is too similar to DoorDash food delivery
- ![alt text](image-16.png) - starting course of the "doors" is very sloppy - i don't like the "roof" that was put on top and it literally just looks like a bunch of assets were sloppily copied and pasted. 
- ![alt text](image-17.png) - the second part of this course shown in image 17 is actually pretty good; the only observable issue is with the axe being misaligned, which is a recurring issue elsewhere
- ![alt text](image-20.png) - slide asset appearing partially inside of a platform; looks sloppy
- ![alt text](image-21.png) - remove the platform under this second jump pad; its supposed to be 2 jumps in succession on both jump pads, which having a platform directly linked to the second pad violates. see ![alt text](image-22.png) also which appears shortly after in the course.
- ![alt text](image-23.png) z-clipping at the finish line; recurring in many courses

Whirlpool Waltz
![alt text](image-43.png) - slide positioned partially inside of platform
![alt text](image-45.png) - spinner right at the finish line + random platform appearing under it causing z-clipping

# MAP FEATURE FIXES
- ![alt text](image-2.png) the "punchers" pictured are too far away to be effective, move them inwards towards the walkway more and extend the punch + make it faster. this is a reoccuring issue in many maps; see ![piston peak](image-11.png)
- ![alt text](image.png) The axe is swinging with its face swinging on the axis that the edge shoudld. It should also be swinging perpendicular to the actual direction of the course (i.e. swinging against their path from the side, not with it from upfront). This is a reoccuring issue in many maps where the path/rotation of the axe doesn't match the feature's relative position to the course direction itself. see also ![alt text](image-6.png), ![alt text](image-7.png)
- ![alt text](image-8.png) some of the swinging panels aren't swinging on their proper axis
- ![alt text](image-9.png) these conveyor belts are unintuitive and need major creative updating. 