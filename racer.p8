pico-8 cartridge // http://www.pico-8.com
version 30
__lua__

-- Brain won't map colours to numbers so get computer to do it
black    = 0 navy     = 1 magenta  = 2 green    = 3
brown    = 4 dim_grey = 5 silver   = 6 white    = 7
red      = 8 orange   = 9 yellow   = 10 lime    = 11
azure    = 12 violet  = 13 salmon  = 14 coral   = 15

dir_left  = -1
dir_right = 1

b_left  = ⬅️ b_right = ➡️
b_down  = ⬇️ b_up    = ヌて●
b_x     = ❎  b_z     = 🅾️

g_friction  = 0.9
g_top_speed = 3
g_edge_rhs  = 64
g_edge_lhs  = 16

function _init()
   car = {
      x = 16,
      y = 110,
      speed = 0,
      accel = 0.6,
   }

   scene = {
      -- Tree
      { spr = { 0, 32, 8, 16 }, at = { 64, 85 } },
      -- Shrub
      { spr = { 8, 32, 16, 8 }, at = { 64, 85 } },
   }
end

function update_car()
      if btn(b_right) then
      car.speed += car.accel
   end

   if btn(b_left) then
      car.speed -= car.accel
   end

   car.speed *= g_friction
   if(not btnp(b_right) and not btnp(b_left)) then
      car.speed *= g_friction
   end

   if(abs(car.speed) > g_top_speed) car.speed = sgn(car.speed) * g_top_speed

   local next_pos = car.x + car.speed
   if next_pos > g_edge_lhs and next_pos < g_edge_rhs then
      car.x += car.speed
   end
end

function update_scene()
   for obj in all(scene) do
      obj.at[1] += -car.speed
   end
end

function _update()
   update_car()
   update_scene()
end

function draw_scene()
   for obj in all(scene) do
      local s = copy_table(obj.spr)
      add(s, obj.at[1])
      add(s, obj.at[2])
      sspr(unpack(s))
   end
end

function _draw()
   cls(silver)

   rectfill(0, 100, 128, 128, 1)

   draw_scene()

   spr(1, car.x, car.y)
end

-- ## Util functions ## --
DEBUG = false

function dumper(...)
   local res = ''
   for v in all({...}) do
      res = res .. (type(v) == 'table' and arr_to_str(v) or tostr(v))
   end
   return res
end

function debug(...)
   if(not DEBUG) return

   printh(dumper(...))
end

-- Not supporting non-array tables as not using them.
function arr_to_str(a)
   local res = '{'
   for k, v in pairs(a) do
      if type(k) != 'number' then
         res = res .. k .. ' => '
      end
      if(type(v) == 'table') then
         res = res .. arr_to_str(v)
      else
         res = res .. tostr(v)
      end
      res = res .. ", "
   end
   return sub(res, 0, #res - 2) .. "}"
end

function copy_table(tbl)
   local ret = {}
   for i,v in pairs(tbl) do
      if(type(v) == 'table') then
         ret[i] = copy_table(v)
      else
         ret[i] = v
      end
   end
   return ret
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000009aa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000099999900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700955995590000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000055005500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00033300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33333333000003333330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33333333000033333733000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33333333000033733333300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33333333000333333333300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33333330000373337373000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
03333333000333733333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
03344433000044455440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00444400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00444400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00444400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00444400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00444400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
04444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
04444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44444444000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
