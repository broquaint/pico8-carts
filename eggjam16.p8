pico-8 cartridge // http://www.pico-8.com
version 39
__lua__
-- eggjam16
-- by broquaint

#include utils.lua
#include animation.lua

g_anims = {}
frame_count = 0
depth_count = 0
player = make_obj({ x = 32, y = 12, sprite = 1 })
obstacles = {}
   
function _init()
   camera()
end

function run_animations()
   for obj in all(g_anims) do
      if costatus(obj.co) != 'dead' then
         coresume(obj.co)
      else
         del(g_anims, obj)
      end
   end
end

rock_frequency = {1, 2, 3, 4}

function rand_tile_x()
   local x = randx(127)
   return x - (x % 8)
end

function _update()
   frame_count += 1
   if frame_count % 30 == 0 then
      depth_count += 1
   end

   run_animations()

   if btn(b_right) then
      local next_x = player.x + 1
      player.x = next_x < 120 and next_x or player.x
   end
   if btn(b_left) then
      local next_x = player.x - 1
      player.x = next_x > 0 and next_x or player.x
   end

   if #obstacles == 0 then
      local rock_count = deli(rock_frequency, 1)
      for n = 1, rock_count do
         local rock = make_obj({
               x = rand_tile_x(x),
               y = 128 + 8 * n,
               sprite = 16
         })
         add(obstacles, rock)
      end
   end

   for obstacle in all(obstacles) do
      obstacle.y = obstacle.y - 1.5
   end

   for idx,obstacle in pairs(obstacles) do
      if obstacle.y < -8 then
         deli(obstacles, idx)
      end
   end
end

function _draw()
   cls(black)

   print(depth_count .. 'M', 1, 1, white)
   -- print('cool', 16, 16, frame_count % 16)
   spr(player.sprite, player.x, player.y)

   for obstacle in all(obstacles) do
      spr(obstacle.sprite, obstacle.x, obstacle.y)
   end
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000aaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
007007000aaafaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000770000accafa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000770000aaaafa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
007007000accaaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000aaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00055500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
05444450000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44444450000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
49944444000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00994994000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00099900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
