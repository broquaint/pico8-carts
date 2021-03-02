pico-8 cartridge // http://www.pico-8.com
version 30
__lua__

PI=3.14159
TWOPI = PI * 2

DEBUG = true

-- cos1 = cos function cos(angle) return cos1(angle / TWOPI) end
-- sin1 = sin function sin(angle) return -sin1(angle / TWOPI) end

function _update()
   if btn(2) then
      angle += 1
      if(angle == 361) angle = 0
   end
   if btn(3) then
      angle -= 1
      if(angle == -1) angle = 360
   end
end

angle_step=1/360
function _draw()
   cls()

   line(64, 64, 96, 64, 7)
   local x = 64 + (32 * cos(angle*angle_step))
   local y = 64 + (32 * sin(angle*angle_step))
   line(64, 64, x, y, 3)

   rectfill(0, 0, 128, 8, 1)
   print(
      dumper('∧ ', angle, ' [', nice_pos(angle*angle_step), '], x ', nice_pos(x), ', y ', nice_pos(y)),
      2, 2, 7
   )
end

function _init()
   angle = 0
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

missiles = {}

function can_go() return true end -- flr(t() * 10 % 10) % 2 == 0 end

function launch_missile()
   add(missiles, { x = 8, y = 64, dx = 1, angle = rnd() * 10, past = {} })
end

step = 0.05
--ax^{2}+bx+c
function update_missile(m)
   while #m.past > 100 do
      deli(m.past, 1)
   end

   add(m.past, {x = m.x, y = m.y})

   m.x += 1

   if m.angle < 9 then
      m.y += sin(m.angle)

      -- m.dx -= step
      m.angle -= step
   elseif m.angle > 3 then
      m.y -= sin(m.angle)
      -- m.dx += step
      m.angle += step
   end
end

function _update_missiles()
   if btnp(5) then
      launch_missile()
      debug('launched ', missiles[#missiles], ' at ', flr(t() * 10 % 10))
   end

   if can_go() then
      --- if(#missiles > 0) debug('missiles at: ', missiles)
   else
      return
   end

   remaining_missiles = {}
   for missile in all(missiles) do
      if missile.x < 228 then
         update_missile(missile)
         add(remaining_missiles, missile)
      end
   end

   missiles = remaining_missiles
end

function draw_missile(m)
   for pos in all(m.past) do
      pset(pos.x, pos.y, 7)
   end

   print(tostr(m.angle), m.x - 8, m.y - 8)
   spr(2, m.x, m.y)
end

function _draw_missiles()
   if not can_go() then
      return
   else
      cls()
   end

   for missile in all(missiles) do
      draw_missile(missile)
   end

   spr(1, 0, 68)
end

count = 1
function _draw_clock_dealie()
   local len=50
   local x,y
   local angle=0.0
   local step=0.1

   local now = t()
   if flr(now % 60) == 0 then
      count = 0
   end

   if count > flr(now % 60) then
      return
   else
      cls()
      printh('dbg: ' .. count .. ' > ' .. flr(now % 60) .. ' [' .. now .. ']')
   end

   local pc = 0
   while(angle < TWOPI) do
      local x = len*cos(angle)
      local y = len*sin(angle)

      local px  = flr(x + 64)
      local py  = flr(y + 64)
      local col = 1 + (x % 12)
      if pc < count then
         pset(px, py, col)
      elseif pc == count then
         line(64, 64, px, py, col)
         printh('dbg: '.. x .. 'x' .. y .. ' - ' ..angle .. ' ['..count..','..now..','..(now%60)..']')
      end
      angle += step
      pc += 1

      --printh('dbg: '.. flr(x + 64) .. 'x' .. flr(y + 64) .. ' - ' ..angle)
   end

   count += 1
end


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

__gfx__
00000000000006770088880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000066a70899998000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0070070000066a66897aa79800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000770000066a66089a77a9800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000066a660089a77a9800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0070070066a66000897aa79800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000006a6600000899998000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000a66000000088880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
