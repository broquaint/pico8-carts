pico-8 cartridge // http://www.pico-8.com
version 30
__lua__

function make_obj()
   return {
      at = t(),
      dt = 1/30,

      velocity = 0.0,
      position = 0.0,
      force = 20.0,
      mass = 1.0,
   }
end

objs = {}
function _update()
   if btnp(5) then
      add(objs, make_obj())
   end

   for obj in all(objs) do
      obj.velocity += ( obj.force / obj.mass ) * obj.dt;
      obj.position += obj.velocity * obj.dt;
      -- t += dt;
   end
end

function _draw()
   cls()
   for obj in all(objs) do
      line(60, obj.position, 68, obj.position, 12)
   end
end

function make_obj(at, attr)
   return merge({ at = at, orig_at = copy_table(at) }, attr)
end

function merge(t1,t2) for k,v in pairs(t2) do t1[k] = v end return t1 end

function _init()
   printh('made an object: ' .. dumper(make_obj({33,66}, { foo = 'bar', now = t() })))
   local foo = {'abc','def','ghi'}
   local bar = deli(foo,2)
   printh('deleted ' .. bar .. ' from ' .. dumper(foo))
end

function dumper(...)
   local res = ''
   for v in all({...}) do
      if type(v) == 'table' then
         res = res .. tbl_to_str(v)
      elseif type(v) == 'number' then
         res = res .. ( v % 1 == 0 and v or nice_pos(v) )
      else
         res = res .. tostr(v)
      end
   end
   return res
end

function tbl_to_str(a)
   local res = '{'
   for k, v in pairs(a) do
      local lhs = type(k) != 'number' and k .. ' => ' or ''
      res = res .. lhs .. dumper(v) .. ', '
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

function nice_pos(inms)
   local sec = flr(inms)
   local ms  = flr(inms * 100 % 100)
   if(ms == 0) then
      ms = '00'
   elseif(ms < 10) then
      ms = '0' .. ms
   end
   return sec .. '.' .. ms
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
