pico-8 cartridge // http://www.pico-8.com
version 35
__lua__

-- eggjam feb 22
-- by broquaint

#include utils.lua

-- Mathematical constants
-- hex angle
C_hex_angle = 60
-- trig step
C_trig_step = 1 / 360

-- Global game state
-- hex length
g_hex_length = 16
g_hex_grid = {}

function _setup_hexagon(col, row, x1, y1)
   local angle = C_hex_angle
   local hexagon = {}
   for _ = 1,6 do
      local x2, y2 = x1 + (g_hex_length * cos(angle * C_trig_step)), y1 + (g_hex_length * sin(angle * C_trig_step))
      add(hexagon, { x1 = x1, y1 = y1, x2 = x2, y2 = y2, column = col, row = row })
      x1, y1 = x2, y2
      angle -= C_hex_angle
   end
   return hexagon
end

function _setup_grid()
   for col = 0, 5 do
      for row = 0, 5 do
         local x1, y1 = col * 24, row * 27 + (col % 2 * 14)
         add(g_hex_grid, _setup_hexagon(col, row, x1, y1))
      end
   end
end

function _init()
   _setup_grid()
end

function _update()
end

function _draw()
   cls()
   for hexagon in all(g_hex_grid) do
      for hl in all(hexagon) do
         line(hl.x1, hl.y1, hl.x2, hl.y2, white)
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
