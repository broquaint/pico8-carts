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
      local offset_up   = randx(20) + (l*3)
      local offset_down = randx(20) + (l*3)
      for _=1,16 do
         local up = randx(30) + offset_up
         add(lvl.up,   up)
         local down = randx(30) + offset_down
         if (down + up + 8) >= 118 then
            down -= randx(5) + 8
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
         local c  = ({azure,lime,red,yellow})[randx(4)]
         add(terr, { x=x, y=y, colour=tc, texture=(randx(20)<2 and {c=c,y=-3+randx(y-g_td)}) })
         x+=2
         y+=step
      end
   end

   local colours = {{silver,dim_grey},{magenta,violet},{silver,white}}
   -- Calculate terrain
   local x = 0
   for i = 1, #lvl.up - 2, 2 do
      local tc_up   = colours[i < 60 and 1 or i < 120 and 2 or 3]
      local tc_down = colours[i < 60 and 2 or i < 120 and 1 or 3]

      calc_terrain_step(terrain.up,   lvl.up[i],   lvl.up[i+1],   x, tc_up[1])
      calc_terrain_step(terrain.down, lvl.down[i], lvl.down[i+1], x, tc_down[1])

      x += 16
      i += 1

      calc_terrain_step(terrain.up,   lvl.up[i],   lvl.up[i+1],   x, tc_up[2])
      calc_terrain_step(terrain.down, lvl.down[i], lvl.down[i+1], x, tc_down[2])

      x += 16
   end
end

cam_x = 0
cam_speed = 1

player_x = 8
player_y = 64
player_speed_vert  = 0
player_speed_horiz = 0

collided = { up = false, down = false}

g_max_speed = 6
g_min_speed = 1

g_friction = 0.9
g_accel_fwd  = 0.2
g_accel_back = 0.4
g_accel_vert = 0.3


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
      player_speed_horiz = min(g_max_speed, player_speed_horiz + g_accel_fwd)
      next_s = min(g_max_speed, max(0.2, cam_speed) * 1.1)
   elseif btn(b_left) then
      player_speed_horiz = max(-2.5, player_speed_horiz - g_accel_back)
      next_s = max(g_min_speed, cam_speed * 0.95)
   else
      player_speed_horiz *= g_friction
   end

   if btn(b_up) then
      player_speed_vert -= g_accel_vert
   elseif btn(b_down) then
      player_speed_vert += g_accel_vert
   else
      player_speed_vert = abs(player_speed_vert) > 0.05 and player_speed_vert * g_friction or 0
   end

   next_y = player_speed_vert > 0 and flr(player_speed_vert + next_y) or -flr(-player_speed_vert) + next_y

   if did_collide_up(next_x, next_y) then
      collided = { up = true,  down = false }
   elseif did_collide_down(next_x, next_y) then
      collided = { up = false, down = true }
   else
      collided = { up = false, down = false }
   end

   if (not collided.up and next_y < player_y)
      or (not collided.down and next_y > player_y) then
      player_y = flr(next_y)
   end

   if not collided.up and not collided.down then
      next_x += player_speed_horiz
      if next_x > 8 and next_x < 96 then
         player_x = flr(next_x)
      end

      cam_speed = next_s

      cam_x += flr(cam_speed)

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
         do_draw(pos)
      end
   end
end

function draw_terrain_texture(x, y, c)
   pset(x,   y, white)
   pset(x-1, y,   c)
   pset(x+1, y,   c)
   pset(x,   y-1, c)
   pset(x,   y+1, c)
end

function _draw()
   cls(navy)

   draw_terrain(terrain.up, function(t)
                   rectfill(t.x, t.y-g_td, t.x+2, t.y, t.colour)
                   rectfill(t.x, 0, t.x+2, t.y-g_td, black)
                   if t.texture then
                      draw_terrain_texture(t.x, t.texture.y, t.texture.c)
                   end
   end)
   draw_terrain(terrain.down, function(t)
                   local w      = t.x + 2
                   local from_y = 128 - t.y
                   local to_y   = 128 - (t.y - g_td)
                   rectfill(t.x, from_y, w, to_y, t.colour)
                   rectfill(t.x, 128, w, to_y, black)
                   if t.texture then
                      draw_terrain_texture(t.x, 128-t.texture.y, t.texture.c)
                   end
   end)

   local px = flr(player_x + cam_x)
   -- Player "ship"
   spr(1, px, player_y)
   -- "thruster" on ship
   line(px-1, player_y+2, px-1,player_y+6, silver)
   -- "exhaust" from thruster
   if not collided.up and not collided.down then
      sspr(4, 10, 3, 5, px - (3+flr(cam_speed)), player_y+2, 2+cam_speed, 5)
   end

   print(dumper('<| ', cam_x, ' -> ', cam_speed, ' @> ', player_speed_horiz, ' @^ ', player_speed_vert), cam_x + 2, 2, white)
end

__gfx__
00000000066666600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000065aaaa560000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
007007006aacaca60000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000770006aacaca60000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000770006a9aaaa60000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
007007006aa99aa60000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000065aaaa560000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000066666600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000008a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00008a70000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000008a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
