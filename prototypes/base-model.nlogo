extensions [
  ls
  array
  ;time
]

breed [people person]

globals [
  clock-h
  clock-m
  current-time
  days
  homes
  public-places
  work-places
  schools
  ;dt
]

people-own [
  id
  state ;; healthy/infected/recovered/dead -> 0/1/2/3
  age
  routine-index
  routine-time
  routine-place
  ;routine-horas [ 0800 0815 1730 1745 1900 1930 ]
  ;rutina-lugares [ limbo trabajo limbo libre limbo casa]
  location ;; id of the container the agent is currently on. -1 means limbo
  home-loc
  time-infected ;; days since the agent got infected
]

to setup
  ls:reset
  clear-all
  set clock-h 00
  set clock-m 00
  let l (sqrt n-agents)
  resize-world 0 l 0 l
  set days 0
  set-default-shape people "circle"
  set public-places num-public-places
  set work-places num-work-places
  set schools num-schools

  ;; ============ IMPORTANT ============
  ;; The order in which container groups are created is important as their model-id is inferred from it
  ;; Our convention is: Homes -> Public places -> Work places -> Schools
  create-homes
  create-public-places
  create-work-places ; WIP work in progress
  create-schools ; WIP

  ;; generating routines
  ask people [
    ;set routine-index 0
    generate-routine-2
    ;old-routine
  ]

  ;; reset people's locations (currently they have their home as the default location)
  ask people [ set location -1 ]
  ls:ask ls:models [ setup ]
  reset-ticks
end

to go
  update-infection
  if (clock-m mod 15 = 0) [
    ask people [
      follow-routine
      color-agent
    ]
  ]
  ls:ask ls:models [ go ]
  update-clock
  tick
end

to update-clock
  set clock-m clock-m + 1
  if clock-m = 60 [
    set clock-m 0
    set clock-h clock-h + 1
  ]
  if clock-h = 24 [
    set clock-h 0
    set days days + 1
  ]
  set current-time clock-h * 100 + clock-m
end

to color-agent
  if state = 0 [ set color color-healthy ]
  if state = 1 [ set color color-infected ]
  if state = 2 [ set color color-recovered ]
end


;; ============ Container creation procedures ============
to create-homes
  ;; Here we create the agents & home-containers toghether, to avoid leaving empty houses
  let counter n-agents ; counter keeps count of the number of agents that need to be created
  ls:let dias-recuperacion avg-recovery-time
  set homes 0
  while [ counter != 0 ] [
    ;; Create a house
    ifelse show-containers
    [ ls:create-interactive-models 1 "container.nlogo" ]
    [ ls:create-models 1 "container.nlogo" ]
    set homes homes + 1
    ;; houses will be small with prolonged interactions
    ;; container-settings width height recovery-time speed transmition-chance
    container-settings 10 10 avg-recovery-time 0.1 base-transmition-chance

    ;; Populate home with 1 - 4 people
    let rand (random 4) + 1
    set rand min (list rand counter) ; do not let rand be greater than the number of agents left to be created

    ask n-of rand (patches with [ (count people-here) = 0 ]) [
      sprout-people 1 [
        set id who
        set state 0
        set location last ls:models ; this agent's home is the last container created
        set time-infected 0
        set home-loc last ls:models
        color-agent
      ]
    ]
    set counter counter - rand
  ]
end

to create-public-places
  ;; Creating public places
  let counter public-places
  ls:let dias-recuperacion avg-recovery-time
  while [ counter != 0 ] [
    ;; Create a public space
    ifelse show-containers
    [ ls:create-interactive-models 1 "container.nlogo" ]
    [ ls:create-models 1 "container.nlogo" ]

    ;; public spaces will be large with shorter interactions
    ;; container-settings width height recovery-time speed transmition-chance
    container-settings 40 40 avg-recovery-time (random-normal 1 0.15) base-transmition-chance
    set counter counter - 1
  ]
end

to create-work-places
  ;; Creating work places
  let counter work-places
  ls:let dias-recuperacion avg-recovery-time
  while [ counter != 0 ] [
    ;; Create a work space
    ifelse show-containers
    [ ls:create-interactive-models 1 "container.nlogo" ]
    [ ls:create-models 1 "container.nlogo" ]

    ;; work spaces will be large with longer interactions
    ;; container-settings width height recovery-time speed transmition-chance
    container-settings 20 20 avg-recovery-time (0.2) base-transmition-chance
    set counter counter - 1
  ]
end

to create-schools
end

to container-settings [ w h recov-time speed infec-chance ]
  ls:assign last ls:models width w
  ls:assign last ls:models height h
  ls:assign last ls:models dias-para-recuperacion recov-time
  ifelse speed > 0
  [ ls:assign last ls:models movespeed speed ]
  [ ls:assign last ls:models movespeed 0 ]
  ls:assign last ls:models infection-chance infec-chance
  ;ls:assign last ls:models dias de incahggoasfef askjfhaskjf
end

to old-routine
  set routine-time [ 0800 0815 1730 1745 1900 1930 ]
  set routine-place [ -1 1 -1 0 -1 2 ]
end

to generate-routine
  set routine-index 0
  ;posición 0 -> están en casa
  ;posición 1 -> salen de la casa luego de 8 o más horas
  let aux-time (800 + (100 * random (4)) + (random (4) * 15))
  let aux-time2 100 * random (4)

  set routine-time list aux-time2 (aux-time + aux-time2)
  set routine-place list location (random (homes + public-places))

  let tiempo-restante 2400 - aux-time - aux-time2
  let tiempo-nuevo 0

  while [tiempo-restante > 0 and aux-time > 0][
    set aux-time ((100 * (random (4) + 1)) + (random (4) * 15))
    set aux-time min (list aux-time tiempo-restante)
    ;if (tiempo-restante < aux-time) [set aux-time tiempo-restante]

    set tiempo-nuevo aux-time + last routine-time
    if (tiempo-nuevo mod 100 >= 60)[
      set tiempo-nuevo tiempo-nuevo - 60 + 100
    ]

    set routine-time lput tiempo-nuevo routine-time
    ifelse random-float 1 < 0.95 ; arbitrary chance of visiting a public place
    [ set routine-place lput get-rand-public routine-place ] ; visit random public place
    [ set routine-place lput random (homes) routine-place ] ; visit a random house
    ;set routine-place lput random (homes + public-places) routine-place

    set tiempo-restante tiempo-restante - aux-time
    let correccion 100 - (tiempo-restante mod 100)
    set tiempo-restante tiempo-restante - (tiempo-restante mod 100) + 60 - correccion
  ]

  let aux-index length routine-time - 1
  set routine-time remove-item aux-index routine-time
  set routine-place remove-item aux-index routine-place

end

to generate-routine-2
  let arr-t array:from-list n-values (3 + random 4) [0]
  ; contains the times
  let len array:length arr-t

  let arr-p array:from-list n-values len [-2]
  ; contains the places, need to initialize slots with "free" time place

  ;; "Time slots" (ts) are windows of time of 15 mins each
  array:set arr-p (len - 1) home-loc ; routine ends by sending the agent home
  array:set arr-t (len - 1) ((floor random-normal 90 1.8) mod 96) ; time measured in "time slots".
  ;; time slot 90 corresponds to 22:30

  ;; A day has 96 time slots. (24 hrs * 4 slots of 15 mins each)
  let free-time 96

  ; An agent should get around 8 hrs of sleep
  let home-time (floor random-normal 36 1.8)
  set free-time free-time - home-time

  ; 9 hrs (36 ts) of work for adults, 7 hrs (28 ts) of school for students
  let work-time (floor random-normal 36 1.8)
  set free-time free-time - work-time
  ; whatever remaining ts are left will be free time, split evenly
  ; among the free window segments (should be around 18 ts on avg)

  ; dropping the "go to work" call anywhere in the array, hopefully somewhere close to after waking up
  ; (i.e: close to index 0)
  let random-index-close-to-the-start floor (abs random-normal 0 0.6)
  array:set arr-p random-index-close-to-the-start get-rand-work
  ;array:set arr-t 0 array:item arr-t (len - 1) + home-time mod 96 ; esto calcula la hora en la que el agente se iría a trabajar


  let free-window-segment floor (free-time / (len - 2))

  ; fill the remaining free windows with the "free time" tag (-2)
  foreach n-values (len) [ i -> i ]
  [ i ->
    ifelse array:item arr-p ((i - 1) mod len) = -2 [
      array:set arr-t i (free-window-segment + (array:item arr-t ((i - 1) mod len))) mod 96
    ][
      ifelse i = 0 [
        array:set arr-t i (home-time + array:item arr-t ((i - 1) mod len)) mod 96
      ][
        array:set arr-t i (work-time + array:item arr-t ((i - 1) mod len)) mod 96
      ]
    ]
  ]

  ;; Now we convert the ts in the time array to time in the military format
  foreach n-values (len) [i -> i]
  [i ->
    array:set arr-t i cambiar-formato-hora array:item arr-t i
  ]

  ;; Finally we convert the arrays into lists, since no further changes should be done.
  set routine-place array:to-list arr-p
  set routine-time array:to-list arr-t
  set routine-index 0
end

to-report get-rand-home
  report random homes
end

to-report get-rand-public
  report homes + (random public-places)
end

to-report get-rand-work
  report homes + public-places + (random work-places)
end

to-report get-rand-school
  report homes + public-places + work-places + (random schools)
end


to follow-routine
  if (item routine-index routine-time) = current-time [
    ifelse (item routine-index routine-place) = -2 [ ; agent has free time
      let next-p 0
      ifelse random-float 1 < 0.5 [ ; chance to go home
        set next-p home-loc
      ][
        ifelse random-float 1 < 0.8 [ ; chance to go to a public place
          set next-p get-rand-public
        ][
          set next-p get-rand-home ; chance to go to someone else's house
        ]
      ]

      if (location != next-p)[ ; only move the agent if the next place is different than current loc
        leave-container ([id] of self)
        enter-container ([id] of self) (next-p)
      ]
    ][
      if (location != (item routine-index routine-place))[ ; only move the agent if the next place is different than current loc
        leave-container ([id] of self)
        enter-container ([id] of self) (item routine-index routine-place)
      ]
    ]
    set routine-index (routine-index + 1) mod length routine-time
  ]
end

to seed-infection
  if any? people [
    ask one-of people [
      set state 1
      color-agent
    ]
  ]
end

to follow-routine-viejo
  (foreach routine-time routine-place [
    [time place] ->
    if time = current-time [
      leave-container ([id] of self)
      enter-container ([id] of self) (place)
    ]
  ])
end

to enter-container [ agent-id container-id ]
  ;; container-id -1 representa el "limbo".
  ;; eventualmente podemos modelar el "limbo" como un container propiamente tal.
  if container-id = -1 [ stop ]

  ls:let _id agent-id
  ls:let _state [state] of person agent-id
  ls:let _time-infected [time-infected] of person agent-id
  ls:ask container-id [
    ;let _state [state] of person agent-id
    insert-agent _id _state _time-infected
  ]
  ask person agent-id [ set location container-id ]
end

to leave-container [ agent-id ]
  let container-id [location] of person agent-id
  if container-id = -1 [ stop ]
  ls:let _id agent-id

  ask person agent-id [
    set state ls:report container-id [ check-state-of-agent _id ]
    set time-infected ls:report container-id [check-time-infected-of-agent _id]
    set location -1
  ]

  ls:ask container-id [
    remove-agent _id
  ]

  ;print [state] of person agent-id
end

to update-infection
  ask people [
    if (state = 1 )[;infected
      set time-infected time-infected + 1
    ]

    if (time-infected >= avg-recovery-time * 1440)[
      set state 2
      set time-infected 0
    ]
  ]
end

to-report cambiar-formato-hora [hora]
  let int-part int (hora / 4)
  let dec-part (hora / 4) - int-part

  report (int-part * 100) + (dec-part * 60)
end

;██████████▀▀▀▀▀▀▀▀▀▀▀▀▀██████████
;█████▀▀░░░░░░░░░░░░░░░░░░░▀▀█████
;███▀░░░░░░░░░░░░░░░░░░░░░░░░░▀███
;██░░░░░░░░░░░░░░░░░░░░░░░░░░░░░██
;█░░░░░░▄▄▄▄▄▄░░░░░░░░▄▄▄▄▄▄░░░░░█
;█░░░▄█████████░░░░░░██▀░░░▀██▄░░█
;█░░░██████████░░░░░░█▄░░▀░░▄██░░█
;██░░░▀▀██████░░░██░░░██▄▄▄█▀▀░░██
;███░░░░░░▄▄▀░░░████░░░▀▄▄░░░░░███
;██░░░░░█▄░░░░░░▀▀▀▀░░░░░░░█▄░░░██
;██░░░▀▀█░█▀▄▄▄▄▄▄▄▄▄▄▄▄▄▀██▀▀░░██
;███░░░░░▀█▄░░█░░█░░░█░░█▄▀░░░░███
;████▄░░░░░░▀▀█▄▄█▄▄▄█▄▀▀░░░░▄████
;███████▄▄▄▄░░░░░░░░░░░░▄▄▄███████
@#$#@#$#@
GRAPHICS-WINDOW
220
10
267
58
-1
-1
13.0
1
10
1
1
1
0
1
1
1
0
2
0
2
0
0
1
ticks
30.0

BUTTON
0
10
63
43
NIL
setup\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
0
103
61
136
go-step
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
0
200
57
245
NIL
clock-h
0
1
11

MONITOR
57
200
114
245
NIL
clock-m
0
1
11

BUTTON
0
137
63
170
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
1
247
65
292
time
clock-h * 100 + clock-m
0
1
11

MONITOR
66
247
123
292
NIL
days
17
1
11

INPUTBOX
158
46
214
106
n-agents
5.0
1
0
Number

BUTTON
0
45
78
78
NIL
seed-infection
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
173
325
317
358
imrpime rutina
ask one-of people [ \nprint routine-place \nprint routine-time\n]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
86
10
213
43
show-containers
show-containers
1
1
-1000

INPUTBOX
1
573
91
633
color-healthy
88.0
1
0
Color

INPUTBOX
95
573
183
633
color-infected
66.0
1
0
Color

INPUTBOX
186
573
276
633
color-recovered
47.0
1
0
Color

INPUTBOX
110
109
215
169
num-public-places
2.0
1
0
Number

INPUTBOX
122
171
215
231
num-work-places
3.0
1
0
Number

SLIDER
581
68
776
101
avg-incubation-period
avg-incubation-period
0
20
3.0
1
1
Days
HORIZONTAL

SLIDER
581
34
758
67
avg-recovery-time
avg-recovery-time
1
50
14.0
1
1
Days
HORIZONTAL

TEXTBOX
584
10
734
28
Infection Parameters
14
0.0
1

INPUTBOX
140
232
215
292
num-schools
0.0
1
0
Number

SLIDER
581
102
767
135
base-transmition-chance
base-transmition-chance
0
1
0.12
0.01
1
NIL
HORIZONTAL

SLIDER
0
387
172
420
chance-go-home
chance-go-home
0
1
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
0
420
172
453
chance-go-out
chance-go-out
0
1
0.3
0.1
1
NIL
HORIZONTAL

SLIDER
0
453
172
486
chance-visit-friend
chance-visit-friend
0
1
0.0
0.1
1
NIL
HORIZONTAL

MONITOR
218
73
275
118
NIL
homes
17
1
11

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
