pico-8 cartridge // http://www.pico-8.com
version 35
__lua__

-- eggjam feb 22
-- by broquaint

#include utils.lua

function _init()
end

function _update()
end

-- hex length
g_hl = 16
-- hex angle
g_ha = 60
-- trig step
g_ts = 1 / 360

function draw_hexagon(x1,y1)
   local angle = g_ha
   for _ = 1,6 do
      local x2, y2 = x1 + (g_hl * cos(angle * g_ts)), y1 + (g_hl * sin(angle * g_ts))
      dump_once("x1, y1 = ", x1, ", ", y1, " - x2, y2 = ", x2, ", ", y2, " angle = ", angle)
      line(x1, y1, x2, y2, 7)
      x1, y1 = x2, y2
      angle -= g_ha
   end
end

function _draw()
   cls()
   for i = 0, 5 do
      for j = 0, 5 do
         local x1, y1 = i * 24, j * 27 + (i % 2 * 14)
         draw_hexagon(x1, y1)
      end
   end
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
