pico-8 cartridge // http://www.pico-8.com
version 32
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

function animate_particle(p)
   -- for y=0,127 do
   --   pset(sin(y/127)*30+64,y,7)
   -- end

   p.x = 64
   p.y = 127
   p.frames=128

   local co = cocreate(function()
         for f = 1, p.frames do
            -- obj.x = lerp(obj.from, obj.to, easeout(f/obj.frames))
            p.x = 64+sin(p.y/127)*20
            p.y -= 1
            yield()
         end
         p.alive = false
   end)
   coresume(co)
   add(anims, co)
end

for x=0,127 do
	pset(x,sin(x/127)*30+64,8)
    end
objs = {}
function _update()
   if btnp(5) then
      local obj = make_obj()
      obj.type = 'sprite'
      add(objs, obj)
      animate(obj)
   end
   if btnp(5) then
      local p = make_obj()
      p.type = 'particle'
      add(objs, p)
      animate_particle(p)
   end

   run_animations()

   for obj in all(objs) do
      if not obj.alive then
         del(objs, obj)
      end
   end
end

function _draw()
   cls()
   for obj in all(objs) do
      if obj.type == 'sprite' then
         -- circfill(obj.x, obj.y, 8, obj.colour)
         pal(4, 130, 1)
         --pal(3, 131, 1)
         sspr(0, 16, 16, 16, obj.x, obj.y)
      elseif obj.type == 'particle' then
         pset(obj.x, obj.y, 7)
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
00030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00333330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00033424000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00034322200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00042222220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00042222222220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00044222222d22000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000044222222d2200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000044222222dd200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000004442222d2200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000044222d22200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000004442224400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000444444000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
