pico-8 cartridge // http://www.pico-8.com
version 39
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

function animate_lavafall()
   local co = cocreate(function()
         local tick = 1
         default_fall = {
            --     sx sy  sw  sh  dx  dy dw  dh
            foo = {sx=24, sy=0,  sw=40, sh=16, dx=62, dy=2},
            bar = {sx=24, sy=16, sw=40, sh=0,  dx=62, dy=2}
         }
         lavafall = copy_table(default_fall)
         while tick > 0 do
            if tick % 10 == 0 then
               -- debug(lavafall)
               lavafall.foo.sh -= 1
               lavafall.bar.sh += 1
               lavafall.bar.sy -= 1
               lavafall.foo.dy += 1
               if lavafall.foo.sh == 0 then
                  --debug('looping!')
                  --debug(default_fall)

                  -- For some reason I can't see lavafall _does not change_
                  lavafall.foo = copy_table(default_fall.foo)
                  lavafall.bar = copy_table(default_fall.bar)

                  --debug(lavafall)
               end
            end
            tick += 1
            yield()
         end
         obj.alive = false
   end)
   coresume(co)
   add(anims, co)
end

function animate_spark(sp)
   -- via https://create.roblox.com/docs/mechanics/bezier-curves
   function lerp(a, b, t)
	return a + (b - a) * t
   end
   function quadraticBezier(t, p0, p1, p2)
	local l1 = lerp(p0, p1, t)
	local l2 = lerp(p1, p2, t)
	local quad = lerp(l1, l2, t)
	return quad
   end
   local co = cocreate(function()
         local p0 = 127
         local p1 = 40+randx(50)
         local p2 = 132
         local len = 30 + randx(30)
         for f = 1,len do
            sp.x += 1
            sp.y = quadraticBezier(f/len, p0, p1, p2)
            --debug(sp)
            yield()
         end
   end)
   coresume(co)
   add(anims, co)
end

-- for x=0,127 do
-- 	pset(x,sin(x/127)*30+64,8)
--     end
objs = {}
lavafall = nil

function _update()
   if btnp(5) then
      local obj = make_obj()
      obj.type = 'sprite'
      add(objs, obj)
      animate(obj)

      local p = make_obj()
      p.type = 'particle'
      add(objs, p)
      animate_particle(p)

      local rect = make_obj()
      rect.x = 16 rect.y = 16
      rect.from = 16
      rect.to   = 64
      rect.type = 'rect'
      add(objs, rect)
      animate(rect)

      local sp = make_obj()
      sp.type = 'spark'
      sp.x = 32
      sp.y = 127
      add(objs, sp)
      animate_spark(sp)
   end   

   if not lavalfall then
      animate_lavafall()
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
         pal(tan, port)
         --pal(3, 131, 1)
         sspr(0, 16, 16, 16, obj.x, obj.y)
      elseif obj.type == 'particle' then
         pset(obj.x, obj.y, silver)
      elseif obj.type == 'spark' then
         circfill(obj.x, obj.y, 2, lemon)
      elseif obj.type == 'rect' then
         fillp(✽)
         rectfill(obj.x, obj.y, obj.x + 32, obj.y + 16)
         fillp()
      end
   end

   pal(coral, salmon, 1)
   pal(lemon, sand, 1)

   -- sspr(24, 0, 40, 16, 62, 2)
   local foo = lavafall.foo
   sspr(foo.sx, foo.sy, foo.sw, foo.sh, foo.dx, foo.dy)
   local bar = lavafall.bar
   sspr(bar.sx, bar.sy, bar.sw, bar.sh, bar.dx, bar.dy)
   -- pal()
end

-- Glyphs when using glyph in the PICO-8 editor.
-- …∧░➡️⧗▤⬆️☉🅾️◆
-- █★⬇️✽●♥웃⌂⬅️:"
-- ▥❎🐱ˇ▒♪😐<>?   


__gfx__
00000000000000000000000099aaaa9999aaaa990000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000009aaffaa99aaffaa90000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
007007000000000000000000aaffffaaaaffffaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000770000000000000000000affaaffaaffaaffa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000770000000000000000000ffaaaaffffaaaaff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
007007000000000000000000faa99aaffaa99aaf0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000aa9999aaaa9999aa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000a99aa99aa99aa99a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000099aaaa9999aaaa990000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000009aaffaa99aaffaa90000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000aaffffaaaaffffaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000affaaffaaffaaffa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000ffaaaaffffaaaaff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000faa99aaffaa99aaf0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000aa9999aaaa9999aa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000a99aa99aa99aa99a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
