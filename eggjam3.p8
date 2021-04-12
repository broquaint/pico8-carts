pico-8 cartridge // http://www.pico-8.com
version 32
__lua__
-- keeping it short

#include utils.lua

function make_obj(attr)
   return merge({
      at = t(),
      x = 120, y = 32,
      from = 32, to = 96,
      frames = 40,
      colour = azure,
      animating = false,
      alive = true
      }, attr)
end

anims={}
function animate(obj)
   function easein(t)
      return t*t
   end

   function lerp(a,b,t)
      return a+(b-a)*t
   end

   obj.co = cocreate(function()
         obj.animating = true
         for f = 1, obj.frames do
            obj.y = lerp(obj.from, obj.to, easein(f/obj.frames))
            yield()
         end
         obj.alive = false
   end)
   coresume(obj.co)
   add(anims, obj)
end

function start_escape()
   cam_x = 0
   cam_speed = 1

   player_x = 8
   player_y = 64
   player_speed_vert  = 0
   player_speed_horiz = 0

   player_fuel = 100

   frame_count = 0

   collided = { up = false, down = false}
end

function generate_terrain()
   terrain={up={},down={}}
   objects={}

   local lvl={up={},down={}}

   -- Generate slopes
   for l = 1,10 do
      local go_up       = randx(2) > 1
      local offset_up   = randx(20) + (l*3)
      local offset_down = randx(20) + (l*3)
      for _ = 1,16 do
         local up = 8 + randx(30) + offset_up
         add(lvl.up,   up)
         local down = randx(30) + offset_down
         if (down + up + 8) >= 110 then
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

      if x % 128 == 0 and randx(3) > 1 then
         local oy = terrain.up[#terrain.up].y - 4
         local obj = make_obj(
            { y=oy, x=x, from=oy, to=128-terrain.down[#terrain.down].y }
         )
         add(objects, obj)
      end
   end
end

function _init()
   start_escape()
   generate_terrain()
end

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

function run_animations()
   for obj in all(anims) do
      if costatus(obj.co) != 'dead' then
         coresume(obj.co)
      else
         del(anims, obj)
         if(obj.callback) obj.callback()
      end
   end
end

function _update()
   frame_count += 1

   run_animations()

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
      player_speed_horiz = 0
      cam_speed = g_min_speed
   elseif did_collide_down(next_x, next_y) then
      collided = { up = false, down = true }
      player_speed_horiz = 0
      cam_speed = g_min_speed
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

      if frame_count % 30 == 0 then
         local next_f = player_fuel - max(1, cam_speed * 0.5)
         player_fuel = next_f >= 0 and next_f or 0
      end
   else
      player_fuel = (player_fuel > 0.5) and (player_fuel - 0.5) or 0
   end

   for obj in all(objects) do
      if not obj.animating and on_screen(obj.x) and obj.x - (cam_x+player_x) < 60 then
         animate(obj)
      end
   end
end

function on_screen(x)
   local pcx = x - cam_x
   return pcx > -10 and pcx < 132
end

function draw_terrain(terr, do_draw)
   local px0 = player_x + cam_x
   local px1 = px0 + 8
   local py0 = player_y
   local py1 = py0 + 8

   for pos in all(terr) do
      if on_screen(pos.x) then
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

   for obj in all(objects) do
      if on_screen(obj.x) then
         spr(obj.alive and 2 or 3, obj.x, obj.y)
      end
   end

   local px = flr(player_x + cam_x)
   -- Player "ship"
   spr(1, px, player_y)
   -- "thruster" on ship
   line(px-1, player_y+2, px-1,player_y+6, silver)
   -- "exhaust" from thruster
   if not collided.up and not collided.down then
      sspr(4, 10, 3, 5, px - (3+flr(cam_speed)), player_y+2, 2+cam_speed, 5)
   end

   rectfill(cam_x, 0, cam_x+128, 8, silver)
   print('fuel ', cam_x+2, 2, white)
   rectfill(cam_x+20, 1, cam_x+20+player_fuel, 7, player_fuel > 30 and yellow or orange)
   print(nice_pos(player_fuel), cam_x+22, 2, player_fuel > 30 and orange or red)
   if(DEBUG) print(dumper('<| ', cam_x, ' -> ', cam_speed, ' @> ', player_speed_horiz, ' @^ ', player_speed_vert, ' F',frame_count), cam_x + 2, 11, yellow)
end

__gfx__
00000000066666600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000065aaaa560550055005500550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
007007006aacaca60655556006555560000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000770006aacaca60665566006655660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000770006a9aaaa60066660000666600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
007007006aa99aa60066660011666600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000065aaaa560007700001177110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000066666600000000000000011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000008a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00008a70000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000008a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
