pico-8 cartridge // http://www.pico-8.com
version 32
__lua__
-- keeping it short

#include utils.lua

terrain={up={},down={}}
function _init()
   local lvl={up={},down={}}

   -- Generate slopes
   for l=1,10 do
      local go_up       = randx(2) > 1
      local offset_up   = randx(20) + (l*2)
      local offset_down = randx(20) + (l*2)
      for _=1,16 do
         local up = randx(30) + offset_up
         add(lvl.up,   up)
         local down = randx(30) + offset_down
         if (down + up + 8) >= 118 then
            down -= randx(5) + 10
         end
         add(lvl.down, down)
         -- Random slopes so the middle isn't totally safe
         offset_up   = max(1, offset_up   + (go_up and -2 or 2))
         offset_down = max(1, offset_down + (go_up and  2 or -2))
      end
   end

   local function calc_terrain_step(terr, from, to, x, tc)
      local step = -(from-to) / 8
      local y    = from
      for j = 1,8 do
         add(terr, { x=x, y=y, colour=tc })
         x+=2
         y+=step
      end
   end

   local colours = {brown,dim_grey,magenta,violet,dim_grey}
   -- Calculate terrain
   local x = 0
   for i = 1, #lvl.up - 1 do
      local tc_up = colours[randx(#colours)]
      local tc_down = colours[randx(#colours)]
      calc_terrain_step(terrain.up, lvl.up[i], lvl.up[i+1], x, tc_up)
      calc_terrain_step(terrain.down, lvl.down[i], lvl.down[i+1], x, tc_down)
      x += 16
   end
end

cam_x=0
cam_speed = 1
player_x = 8
player_y = 64

g_max_speed = 5
g_min_speed = 1

-- td = terrain_depth
g_td = 15

function did_collide(terr, x, y, test)
   local px0 = x + cam_x
   local px1 = px0 + 8
   local py0 = y
   local py1 = py0 + 8

   for pos in all(terr) do
      if test(pos, px0, px1, py0, py1) then
         return true
      end
   end

   return false
end

function did_collide_up(x, y)
   local function coll_test(pos, px0, px1, py0, py1)
      local pos_top = max(1, pos.y - g_td)
      return ((px0 >= pos.x and px0 <= (pos.x+2))
           or (px1 >= pos.x and px1 <= (pos.x+2)))
         and py0 < pos_top
   end

   return did_collide(terrain.up, x, y, coll_test)
end

function did_collide_down(x, y)
   local function coll_test(pos, px0, px1, py0, py1)
      local pos_top = pos.y - g_td
      return ((px0 >= pos.x and px0 <= (pos.x+2))
           or (px1 >= pos.x and px1 <= (pos.x+2)))
         and py1 > (128-pos_top)
   end

   return did_collide(terrain.down, x, y, coll_test)
end

function _update()
   local next_x = player_x
   local next_y = player_y
   local next_s = cam_speed
   if btn(b_right) then
      next_x += 1
      -- TODO Momentum!
      next_s = min(g_max_speed, max(0.2, cam_speed) * 1.1)
   end
   if btn(b_left) then
      next_x -= 1
      next_s = max(g_min_speed, cam_speed * 0.9)
   end
   if btn(b_up) then
      next_y -= 1
   end
   if btn(b_down) then
      next_y += 1
   end

   if did_collide_up(next_x, next_y) or did_collide_down(next_x, next_y) then
      dump('collided at ',next_x,'x',next_y)
   else
      player_x  = next_x
      player_y  = next_y
      cam_speed = next_s

      cam_x += cam_speed

      camera(flr(cam_x))
   end
end

function draw_terrain(terr, do_draw)
   local px0 = player_x + cam_x
   local px1 = px0 + 8
   local py0 = player_y
   local py1 = py0 + 8

   for pos in all(terr) do
      local pcx = pos.x - cam_x
      -- Only draw onscreen terrain
      if pcx > -4 and pcx < 132 then
         local colour = nil
         if (px0 >= pos.x and px0 <= (pos.x+2))
            or (px1 >= pos.x and px1 <= (pos.x+2)) then
            colour = salmon
         end

         do_draw(pos.x, pos.y, colour or pos.colour)
      end
   end
end

function _draw()
   cls(navy)

   draw_terrain(terrain.up, function(x, y, colour)
                   rectfill(x, 0, x+2, y, colour)
                   rectfill(x, 0, x+2, y-g_td, black)
   end)
   draw_terrain(terrain.down, function(x, y, colour)
                   rectfill(x, 128, x+2, 128-y, colour)
                   rectfill(x, 128, x+2, 128-(y-g_td), black)
   end)

   -- line(0, 64, 128+cam_x, 64, yellow)
   spr(1, flr(player_x + cam_x), player_y)

   print(dumper('<| ', cam_x), cam_x + 2, 2, white)
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
