pico-8 cartridge // http://www.pico-8.com
version 30
__lua__

#include utils.lua

colours = {azure,violet,magenta,navy}
function make_obj()
   return {
      at = t(),
      x = 32, y = 64,
      from = 32, to = 96,
      frames = 60,
      colour = colours[randx(#colours)],
      alive = true
   }
end

function easeout(t)
  t-=1
  return 1-t*t
end

function lerp(a,b,t)
  return a+(b-a)*t
end

anims = {}
function run_animations()
   for co in all(anims) do
      if costatus(co) != 'dead' then
         coresume(co)
      else
         del(anims, co)
      end
   end
end

function animate(obj)
   local co = cocreate(function()
         for f = 1, obj.frames do
            obj.x = lerp(obj.from, obj.to, easeout(f/obj.frames))
            yield()
         end
         obj.alive = false
   end)
   coresume(co)
   add(anims, co)
end

objs = {}
function _update()
   if btnp(5) then
      local obj = make_obj()
      add(objs, obj)
      animate(obj)
   end

   run_animations()
end

function _draw()
   cls()
   for obj in all(objs) do
      if obj.alive then
         circfill(obj.x, obj.y, 8, obj.colour)
      else
         del(objs, obj)
      end
   end
end

-- Glyphs when using glyph in the PICO-8 editor.
-- …∧░➡️⧗▤⬆️☉🅾️◆
-- █★⬇️✽●♥웃⌂⬅️:"
-- ▥❎🐱ˇ▒♪😐<>?   


__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
