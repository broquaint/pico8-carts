pico-8 cartridge // http://www.pico-8.com
version 32
__lua__
-- keeping it short

#include utils.lua

terrain={up={},down={}}
function _init()
   local lvl={up={},down={}}

   -- Generate slopes
   for _=1,10 do
      local go_up       = randx(2) > 1
      local offset_up   = randx(20)
      local offset_down = randx(20)
      for _=1,16 do
         add(lvl.up,   randx(40) + offset_up)
         add(lvl.down, randx(40) + offset_down)
         -- Random slopes so the middle isn't totally safe
         offset_up   += go_up and -2 or 2
         offset_down += go_up and  2 or -2
      end
   end

   local function calc_terrain_step(lvl, i, x, terr)
      local from = lvl[i]
      local to   = lvl[i+1]
      local step = -(from-to) / 8
      local y    = from
      for j = 1,8 do
         add(terr, { x=x, y=y })
         x+=2
         y+=step
      end
   end
   -- Calculate terrain
   local x = 0
   for i = 1, #lvl.up - 1 do
      calc_terrain_step(lvl.up,   i, x, terrain.up)
      calc_terrain_step(lvl.down, i, x, terrain.down)
      x += 16
   end
end

cam_x=0
cam_speed = 1
player_x = 8
player_y = 64
function _update()
   if btn(b_right) then
      player_x += 1
      cam_speed += 0.25
   end
   if btn(b_left) then
      player_x -= 1
      cam_speed -= 0.25
   end
   if btn(b_up) then
      player_y -= 1
   end
   if btn(b_down) then
      player_y += 1
   end

   cam_x += cam_speed

   camera(flr(cam_x))
end

function draw_terrain(terr, do_draw)
   local px0 = player_x + cam_x
   local px1 = px0 + 8
   local py0 = player_y
   local py1 = py0 + 8

   for pos in all(terr) do
      local colour = violet
      if (px0 >= pos.x and px0 <= (pos.x+2))
      or (px1 >= pos.x and px1 <= (pos.x+2)) then
         colour = salmon
      end
      do_draw(pos.x, pos.y, colour)
   end
end

function _draw()
   cls(navy)

   draw_terrain(terrain.up, function(x, y, colour)
                   rectfill(x, 0, x+2, y, colour)
   end)
   draw_terrain(terrain.down, function(x, y, colour)
                   rectfill(x, 128, x+2, 128-y, colour)
   end)

   -- line(0, 64, 128+cam_x, 64, yellow)
   spr(1, flr(player_x + cam_x), player_y)

   print(dumper('@ ', cam_x), cam_x + 2, 2, white)
end

__gfx__
00000000066666600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000060aaaa060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
007007006aacaca60000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000770006aacaca60000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000770006a9aaaa60000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
007007006aa99aa60000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000060aaaa060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000066666600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
