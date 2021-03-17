pico-8 cartridge // http://www.pico-8.com
version 30
__lua__

-- Brain won't map colours to numbers so get computer to do it
black    = 0 navy     = 1 magenta  = 2 green    = 3
brown    = 4 dim_grey = 5 silver   = 6 white    = 7
red      = 8 orange   = 9 yellow   = 10 lime    = 11
azure    = 12 violet  = 13 salmon  = 14 coral   = 15

screen_width = 128

dir_left  = -1
dir_right = 1

b_left  = ⬅️ b_right = ➡️
b_down  = ⬇️ b_up    = ⬆️
b_x     = ❎  b_z     = 🅾️

g_dt           = 1/30
g_friction     = 0.9
g_air_friction = 0.98
g_top_speed    = 3
g_top_boost    = 10
-- The speed at which a jump starts to build up on a ramp.
g_jump_speed   = 2.6

g_edge_rhs  = 64
g_edge_lhs  = 16

g_racing_line = 118
g_car_line    = g_racing_line - 6

r_step = 1 / 360

spr_tree   = { 0,  32, 8,  16 }
spr_shrub  = { 8,  32, 16, 8  }
spr_player = { 8,  0,  8,  8  }
spr_boost  = { 16, 0,  8,  8  }
spr_flag   = { 24, 32, 16, 16 }

spr_villa_savoye = { 48, 46, 31, 18 }
-- https://en.wikipedia.org/wiki/Palladian_architecture#/media/File:Andrea_palladio_fourth_book_image.jpg
spr_villa_palladio = { 80, 40, 32, 23 }
-- https://www.archdaily.com/957550/rendezvous-house-clb-architects
spr_house_rendevous = { 0, 48, 16, 16 }
-- https://www.archdaily.com/957922/nk-home-kien-truc-ndt
spr_house_tube = { 16, 48, 16, 16 }
-- https://www.archdaily.com/957520/cruz-de-pedra-house-ca-colectivo-de-arquitectura
spr_house_cruz_de_pedra = { 32, 48, 16, 16 }
-- https://www.archdaily.com/956776/vila-house-flipe-arquitetura
spr_house_vila_flipe = { 64, 0, 16, 16 }
-- https://www.archdaily.com/956258/borderless-house-haryu-wood-studio-plus-selma-masic
spr_house_haryu = { 112, 0, 16, 16 }
-- https://www.architectural-review.com/buildings/sergison-bates-semi-detached-stevenage-2000
spr_house_semi_detached = { 96, 0, 16, 16 }
-- https://www.archdaily.com/956098/tam-dao-villa-tropical-space
spr_house_tam_dao = { 80, 0, 16, 16 }

function make_location(spr, name, y_pos)
   return { spr = spr, name = name, y_pos = (y_pos or 85) }
end

locations = {
   make_location(spr_villa_savoye, 'villa savoye', 87),
   make_location(spr_villa_palladio, 'palladian villa', 81),
   make_location(spr_house_rendevous, 'rendevous house'),
   make_location(spr_house_tube, 'typical tube house'),
   make_location(spr_house_cruz_de_pedra, 'cruz de pedra house'),
   make_location(spr_house_vila_flipe, 'vila house'),
   make_location(spr_house_haryu, 'borderless house'),
   make_location(spr_house_semi_detached, 'sergison bates semi-detached'),
   make_location(spr_house_tam_dao, 'tam dao villa'),
}

function _init()
   car = {
      x = 16,
      y = g_car_line,
      dir = dir_right,
      speed = 0,
      accel = 0.4,
      dy = 0,
      jumping = false,
      boosted_at = false,
      boost_meter = 0,
      delivered = {}
   }

   -- Track debug info separately so dumping data is sane.
   dbg = {
      past = {},
      at_hypot = 0,
   }

   local lvl_len = 1500

   level = {
      length = lvl_len
   }

   scene = { make_bg_spr(spr_flag, { 0, 88 }) }

   level.sections = make_sections()
   level.deliveries = generate_deliveries()

   ramps = {}
   boosters = {}
   platforms = {}

   populate_scenery()
   populate_geometry()

   car.deliveries = {level.deliveries[randx(#level.deliveries)]}
end

function make_obj(pos, attr)
   return merge(
      { x = pos[1], y = pos[2], orig_x = pos[1], orig_y = pos[2] },
      attr
   )
end

function make_bg_spr(spr, at)
   return make_obj(at, { spr = spr, width = spr[3] })
end

function make_ramp(attr)
   -- With ramps the length of the hypoteneuse determines how wide the ramp is.
   local w = abs(attr.hypot * cos(attr.angle * r_step))
   return make_obj({ attr.x, g_racing_line }, merge(attr, { width = w }))
end

function make_booster(attr) return make_obj({ attr.x, g_racing_line }, attr) end

function make_sections()
   local sections = {}
   local colours = {azure, violet, salmon, coral, orange, yellow, lime}

   local sec_x = 0
   local sec_size = level.length / 10
   for sec = 1, flr(level.length / sec_size) do
      local col = colours[sec == #colours and #colours or sec % #colours]
      add(sections, make_obj({sec_x, 64}, {width=sec_size,colour=col,id=sec}))
      sec_x += sec_size
   end

   return sections
end

function populate_scenery()
   for s in all(level.sections) do
      local new_x   = s.x + randx(90) + 30 -- Avoid bg sprites on the edges
      local new_obj = randx(2) == 1
         and make_bg_spr(spr_tree,  { new_x, 85 })
         or  make_bg_spr(spr_shrub, { new_x, 95 })

      -- TODO Maybe have more than one bg sprite per section?
      add(scene, new_obj)
   end
end

function populate_geometry()
   for s in all(slice(level.sections, 1, #level.sections - 1)) do
      -- Only create ramps every other section
      if s.id % 2 == 0 then
         local new_x = s.x + randx(30)

         add(boosters, make_booster(
                { x = new_x, boost = 1.1, width = randx(30) + 10 }
         ))

         local l = make_ramp(
            { x = new_x + 50, angle = randx(25) + 10, hypot = randx(20) + 30 }
         )
         local r = make_ramp(
            { x = l.x + l.width, angle = 180 - l.angle, hypot = l.hypot }
         )

         add(ramps, l)
         add(ramps, r)

         add(boosters, make_booster(
                { x = r.x+r.width+10, boost = 1.1, width = randx(30) + 10 }
         ))

         if not any(level.deliveries, function(d) return d.section.id == s.id + 1 end) then
            add(platforms, make_obj({r.x + 100, g_racing_line - 25}, {width = 80}))
         end
      end
   end
end

function find_free_pos(known, sec_gen)
   function is_sec_in_set(sec_set, sec)
      for s in all(sec_set) do
         if(sec.id == s.section.id) return true
      end
      return false
   end

   local new_sec = sec_gen()
   -- Enter loop if the new section is already present to generate a new section.
   while(is_sec_in_set(known, new_sec)) do
      new_sec = sec_gen()
   end
   return new_sec
end

delivery_id = 1
function generate_deliveries()
   function rand_section()
      local idx = randx(#level.sections)
      -- Only use odd indexes so the locations don't align with ramps.
      return level.sections[idx % 2 == 0 and idx - 1 or idx]
   end

   local deliveries = {}
   -- local colours    = { salmon, azure, lime, yellow, orange, red, coral }
   local locs = copy_table(locations)
   -- TODO The number of deliveries needs to be more dynamic.
   for i = 1,flr(level.length/400) do
      local loc   = del(locs, locs[randx(#locs)])
      local sec = find_free_pos(deliveries, rand_section)
      -- TODO Same logic as bg sprites, maybe attempt to avoid overlap?
      local del_x = sec.x + randx(90) + 30
      deliveries[delivery_id] = make_obj({del_x, loc.y_pos}, {location=loc, width=loc.spr[3], id=delivery_id,section=sec})
      -- The IDs happen to align with where the index in , it could diverge.
      delivery_id += 1
   end

   return deliveries
end

----------------------
-- UPDATE functions --
----------------------

function track_car()
   if(not DEBUG_GFX) return

   while #dbg.past > 50 do
      deli(dbg.past, 1)
   end

   add(dbg.past, {x = car.x, y = car.y + 8})
end

function respect_incline(r)
   if r.angle < 90 then
      car.speed -= 0.1
   else
      car.speed += 0.1
   end
   car.dy += 0.2
end

function apply_gravity()
   -- The number used here feels about right, is arbitrary.
   car.dy += 35 * g_dt -- 35 is arbitrary!
   car.y += car.dy * g_dt

   -- TODO Implement a bounce!
   if car.y >= g_car_line then
      car.y = g_car_line
      car.dy = 0
      car.jumping = false
   else
      car.jumping = true
      debug('car.y = ', car.y, ', car.dy = ', car.dy)
   end
end

function on_ramp(car_x)
   car_x += 4
   for r in all(ramps) do
      local rx0 = r.angle < 90 and r.x or r.x + r.width
      if r.angle < 90 then
         local rx1 = ramp_trig(rx0, r.y, r.hypot, r.angle)
         if car_x > rx0 and car_x < rx1 then
            return r
         end
      else
         local rx1 = ramp_trig(rx0, r.y, r.hypot, r.angle)
         if car_x > rx1 and car_x < rx0 then
            return r
         end
      end
   end
   return false
end

function on_booster()
   for b in all(boosters) do
      if (car.x+4) > b.x and (car.x+4) < (b.x + b.width)
      and car.y == g_car_line then
         return b
      end
   end
   return false
end

function on_platform()
   local car_x = car.x + 4
   local car_y = car.y + 8
   for p in all(platforms) do
      if car_x > p.x and car_x < (p.x + p.width) then
         -- Landing
         if car.dy > 0 -- falling down
            and (car_y < p.y and (car_y + car.dy * g_dt) > p.y) -- will be "on" it in the next frame
         then
            return p
         -- Landed
         elseif car.dy == 0 and not car.jumping then
            return p
         end
      end
   end
   return false
end

function still_boosting()
   local boost_active = car.boosted_at and t() - car.boosted_at < 0.5
   local boost_power  = car.boost_meter > 0
   return boost_active or boost_power
end

function handle_ramp(r)
   -- Calculate the car's position as the middle of the sprite.
   local car_x = car.x + 4
   -- TODO Reconcile actute and obtuse ramp handling code.
   if r.angle < 90 then
      -- These are offsets relative to where the car is on the ramp.
      local car_x = car_x - r.x
      local car_y = max(car.speed, g_car_line - car.y)
      -- Rough calculation of the current position along the hypoteneuse.
      -- It's rough because car_y is just a reasonable guess.
      local len   = sqrt((car_x*car_x)+(car_y*car_y))
      local new_y = len * sin(r.angle * r_step)

      car.y = min(g_car_line, g_car_line + new_y)

      -- Used for graphical debugging.
      dbg.at_hypot = len

      -- Only apply jump increase if going up the ramp!
      if car.speed > g_jump_speed and car.dir == dir_right then
         local new_dy = car.dy - (0.03 * r.angle)
         if(car.boosted_at) new_dy *= 3
         car.dy = abs(new_dy) > 32 and -32 or new_dy
      elseif btn(b_left) then
         car.speed -= car.accel
         car.dy += 10
      end
      -- debug('-> on l2r ramp ', r, ', car.x ', car_x, ' spd ', car.speed, ' car.dy ', car.dy)
   else
      -- These are offsets relative to where the car is on the ramp.
      local car_x = (r.x+r.width) - car_x
      local car_y = max(car.speed, g_car_line - car.y)
      -- Rough calculation of the current position along the hypoteneuse.
      -- It's rough because car_y is just a reasonable guess.
      local len   = sqrt((car_x*car_x)+(car_y*car_y))
      local new_y = len * sin(r.angle * r_step)

      car.y = min(g_car_line, g_car_line + new_y)

      -- Used for graphical debugging.
      dbg.at_hypot = len

      if abs(car.speed) > g_jump_speed and car.dir == dir_left then
         local new_dy = car.dy - (0.03 * r.angle)
         if(car.boosted_at) new_dy *= 3
         car.dy = abs(new_dy) > 32 and -32 or new_dy
      elseif btn(b_right) then
         car.speed += car.accel
         car.dy = 0
      end
      -- debug('<- on r2l ramp ', r, ', car.x ', car.x, ' spd ', car.speed, ' car.dy ', car.dy)
   end

   if not(btn(b_right) or btn(b_left)) then
      respect_incline(r)
   end
end

function handle_platform(p)
   debug('landed on platform ', p)
   debug('car was at ', car)
   car.on_platform = p
   car.y = p.y - 8
   car.dy = 0
   car.jumping = false
end

function update_car()
   local accelerating = btn(b_right) or btn(b_left)

   local sw = car.speed
   if btn(b_right) then
      if car.dir != dir_right and car.speed >= 0 then
         car.dir = dir_right
         car.dy = 0
      end

      if (car.speed + car.accel) < g_top_speed then
         car.speed += car.accel
      end
   end

   if btn(b_left) then
      if car.dir != dir_left and car.speed < 0 then
         car.dir = dir_left
         car.dy = 0
      end

      if abs(car.speed - car.accel) < g_top_speed then
         car.speed -= car.accel
      end
   end

   -- debug('was going ', sw, ' now going ', car.speed, ' with boost ', car.boost_meter, ' boost amt ', car.boost_was, ' last boost at ', car.boosted_at)

   -- Don't consider speed as it hasn't yet been calculated
   local r = on_ramp(car.x)

   if not still_boosting() then
      -- TODO Make this more gradual, probably need to move away from linear speed.
      if not car.jumping then
         car.speed *= g_friction
         if not accelerating  then
            car.speed *= g_friction
         end
      else
         car.speed *= g_air_friction
      end

      if r then
         -- TODO Improve friction relative to ramp.
         car.speed *= g_friction * 0.95 - (r.angle/1000)
      end

      car.boosted_at = false
   end

   -- Reduce boost if on the ground or in the air and "breaking"
   local break_button = car.dir == dir_right and b_left or b_right
   if still_boosting() and (not car.jumping and t() - car.boosted_at > 0.3) or btn(break_button) then
      if car.boost_meter > 0 then
         if btn(break_button) then
            car.boost_meter *= (car.boost_meter > 1) and 0.9 or 0
         else
            car.boost_meter -= 1
         end
      end
   end

   local b = on_booster()
   if b and abs(car.speed) < g_top_boost then
      -- TODO implement a max speed ... but going insanely fast is fun.
      car.speed *= b.boost
      car.boosted_at  = t()
      car.boost_meter = 32
      car.boost_was   = b.boost
   end

   track_car()

   local next_pos = car.x + car.speed
   if next_pos > g_edge_lhs and next_pos < g_edge_rhs then
      car.x += car.speed
      -- TODO Don't update what ought to be a constant!
      g_edge_lhs += 1
   elseif next_pos > g_edge_rhs then
      car.x = g_edge_rhs
      g_edge_lhs = g_edge_rhs
   end

   local p = on_platform()
   -- Recalculate ramp now the car's position has been recalculated
   r = on_ramp(car.x)

   -- TODO Handle landing on a ramp!
   if r and not car.jumping then
      handle_ramp(r)
      -- Initiate jump if on the next frame car is not on this ramp and
      -- has a negative vertical inertia.
      local next_ramp = on_ramp(car.x + car.speed)
      if next_ramp and r != next_ramp and car.dy < 0 then
         car.jumping = true
      end
   elseif p and car.jumping then
      handle_platform(p)
   elseif not p then
      car.on_platform = false
      apply_gravity()
   end
end

function horizon_offset(y)
   return y - (0.1 * (g_car_line - car.y))
end

function update_scene()
   local function update_pos(obj)
      local x = obj.x + -car.speed
      if x < 0 and x > -64 then
         obj.x = x
      else
         obj.x = x % level.length
      end
      -- Only move bg sprites but not flag or transition.
      if obj.spr then
         obj.y = horizon_offset(obj.orig_y)
      end
   end

   foreach(scene, update_pos)
   foreach(ramps, update_pos)
   foreach(boosters, update_pos)
   foreach(platforms, update_pos)
   foreach(level.deliveries, update_pos)
   foreach(level.sections, update_pos)
end

function handle_deliveries()
   local cx0 = car.x
   local cx1 = car.x+8
   for idx, cd in pairs(car.deliveries) do
      local del_loc = level.deliveries[cd.id]
      local dx0 = del_loc.x
      local dx1 = dx0+del_loc.width
      if (cx1 > dx0 and cx1 < dx1) or (cx0 < dx1 and cx0 > dx0) then
         car.delivered = deli(car.deliveries, idx)
      end
   end
end

function _update()
   update_scene()

   update_car()

   handle_deliveries()

   if btnp(b_z) then
      DEBUG = not DEBUG
      DEBUG_GFX = not DEBUG_GFX
   end
end

----------------------
-- DRAW functions --
----------------------

function ramp_trig(x, y, hypot, angle)
   local rx = x + (hypot * cos(angle * r_step))
   local ry = y + (hypot * sin(angle * r_step))
   return rx, ry
end

function render_sprite(sxywh, x, y, flip_x, flip_y)
   local s = copy_table(sxywh)
   add(s, x)
   add(s, y)
   add(s, sxywh[3])
   add(s, sxywh[4])
   if(flip_x != nil) add(s, flip_x)
   if(flip_y != nil) add(s, flip_y)
   sspr(unpack(s)) -- Could be done with spr, too lazy to change.
end

-- Handle drawing in objects that are about to "wrap in" from the LHS.
function wrapped_x(obj)
   local x = obj.x
   if (x + obj.width) > level.length then
      return -obj.width - (level.length - (x + obj.width))
   else
      return x
   end
end

-- Only bother rendering objects that will be on screen.
function should_draw(x, w)
   return x > -w and x < 128
end

function draw_ramp(r, rx)
   local ry = r.y
   local x, y

   -- Slope going up from the left
   if r.angle < 90 then
      x, y = ramp_trig(rx, ry, r.hypot, r.angle)
      line(rx, ry, x, y, yellow)
   else
      rx += r.width
      -- Other edge going up from the right
      x, y = ramp_trig(rx, ry, r.hypot, r.angle)
      -- Need offset to draw correctly while maintaining consistent x coordinate
      line(rx, ry, x, y, lime)
   end

   local slope = r.angle
   -- Fill the ramp with solid colour.
   if r.angle < 90 then
      while slope >= 0 do
         local lx, ly = ramp_trig(rx, ry, r.hypot, slope)
         local d   = r.angle - slope
         local col = (d < 5) and yellow or (d < 20) and orange or red
         line(rx, ry, x, ly, col)
         -- line(x, ly, opx, ry, col)
         slope -= 1
      end
   else
      while slope < 182 do
         local lx, ly = ramp_trig(rx, ry, r.hypot, slope)
         local d   = slope - r.angle
         local col = (d < 5) and lime or (d < 20) and green or azure
         line(rx, ry, x, ly, col)
         slope += 1
      end
   end
end

function draw_scene()
   for obj in all(scene) do
      local x = wrapped_x(obj)
      if should_draw(x, obj.width) then
         -- Flag fiddliness, prolly worth splitting it out.
         if obj.spr == spr_flag then
            palt(0, false)
            palt(1, true)
         else
            palt()
         end

         render_sprite(obj.spr, x, obj.y)
      end
   end

   palt()

   for d in all(level.deliveries) do
      local del_x = wrapped_x(d)
      if should_draw(del_x, d.width) then
         render_sprite(d.location.spr, del_x, d.y)
      end
   end

   for r in all(ramps) do
      local rx = wrapped_x(r)

      if should_draw(rx, r.width) then
         draw_ramp(r, rx)
      end
   end

   for b in all(boosters) do
      local bx0 = wrapped_x(b)
      if should_draw(bx0, b.width) then
         local bx1 = bx0 + b.width
         line(bx0, g_racing_line, bx1, g_racing_line, yellow)
         line(bx0, g_racing_line + 1, bx1, g_racing_line + 1, orange)
         line(bx0, g_racing_line + 2, bx1, g_racing_line + 2, red)
      end
   end

   for p in all(platforms) do
      local px0 = wrapped_x(p)
      if should_draw(px0, p.width) then
         local px = p.x
         local py = p.y
         rectfill(px0, py, px0 + p.width, py - 2, white)
      end
   end

   for s in all(level.sections) do
      local sx0 = wrapped_x(s)
      if should_draw(sx0, s.width) then
         local sx = s.x
         local sy = s.y
         rectfill(sx0, sy, sx0 + s.width, sy + 2, s.colour)
         print('section ' .. s.id, sx0 + 75, sy + 4, dim_grey)
      end
   end
end

function draw_ewe_ai()
   rectfill(92, 2, 124, 8, white)
   if car.boost_meter > 0 then
      rectfill(92, 2, 92 + car.boost_meter, 8, orange)
      print('boost', 94, 3, yellow)
   else
      print('boost', 94, 3, salmon)
   end

   local del_name = (#car.deliveries > 0) and car.deliveries[1].location.name or 'done!'
   local del_x    = 126 - (#del_name * 4)
   local del_y    = 12
   print(del_name, del_x, del_y, dim_grey)
   print(del_name, del_x - 1, del_y - 1, white)

   local dbg = DEBUG and '🐱' or '@'
   local jumpstate = car.jumping and '⬆️' or '-'
   print(dumper(dbg, ' ', nice_pos(car.dy), ' -> ', car.speed, ' ', jumpstate), 2, 2, azure)
end

function draw_car_debug()
   if(not DEBUG_GFX) return

   for pos in all(dbg.past) do
      pset(pos.x, pos.y, white)
   end

   local r = on_ramp(car.x)
   if r then
      line(r.x, r.y, (car.x+4), car.y+8, lime)
      line(r.x, r.y, r.x+dbg.at_hypot, r.y, azure)
   end

   local car_at = car.x + 4
   line(car_at, car.y, car_at, car.y + 8, white)
end

function draw_car()
   draw_car_debug()

   local flip = car.dir == dir_left
   if still_boosting() then
      local bx = flip and car.x + 8 or car.x - 8
      render_sprite(spr_boost, bx, car.y, flip)
   end

   render_sprite(spr_player, car.x, car.y, flip)
end

function _draw()
   cls(silver)

   draw_ewe_ai()

   -- Background layer.
   rectfill(0, horizon_offset(100), 128, 105, violet)
   rectfill(0, 105, 128, 128, navy)

   draw_scene()

   draw_car()
end

----------------------
-- UTILITY functions --
----------------------

DEBUG_GFX = false
DEBUG = false

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

function debug(...)
   if(not DEBUG) return

   printh(dumper(...))
end

function tbl_to_str(a)
   local res = '{'
   for k, v in pairs(a) do
      local lhs = type(k) != 'number' and k .. ' => ' or ''
      res = res .. lhs .. dumper(v) .. ', '
   end
   return sub(res, 0, #res - 2) .. "}"
end

-- Create a deep copy of a given table.
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

-- Like copy_table but for any value
function clone(v)
   return type(v) == 'table' and copy_table(v) or v
end

-- Take a slice of a table.
function slice(tbl, from, to)
   from = from or 1
   to = to or #tbl
   local res = {}
   for idx = from,to do
      res[idx] = clone(tbl[idx])
   end
   return res
end

-- Add one table to another in–place.
function merge(t1, t2)
   for k,v in pairs(t2) do t1[k] = v end
   return t1
end

-- Test if a value is present in a table.
function any(t, f)
   for v in all(t) do
      if f(v) then
         return true
      end
   end
   return false
end

-- Random index.
function randx(n)
   return flr(rnd(n)) + 1
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

__gfx__
0000000000aaaa0000000000000000000000000000000000000000000000000007777777777777700000000000000000000000000d0000000000555555555000
000000000aacaca0000000000000000000000000000000000000000000000000011111111111111000000000000000000000000ddddd00000000449444444000
007007000aacaca000000000000000000000000000000000000000000000000001777777777777100000000000000000000000ddddddd0000000455594444000
000770000a9aaaa000000a000000000000000000000000000000000000000000017fff7676fff71077777777777777770000ddddddddddd0000045a594944000
000770000aa99aa0000799900000000000000000000000000000000000000000017fff6767fff71075611144cc411337000ddddddddddddd0000957544944000
007007000566665000aa889a0000000000000000000000000000000000000000017fff7676fff710765fff44cc4ffb370ddddddddddddddd000095b544449000
00000000575665750007999000000000000000000000000000000000000000000177777777777710757fff44cc4ff5b7ddd7777ddddd777d0000455544449000
000000000500005000000a0000000000000000000000000000000000000000000111111111111110755fff44994ff547ddd7aa7ddddd717d0000444445554000
000000000000000000000000000000000000000000000000000000000000000001111111111111107777777777777777ddd7a17ddddd717d0000449445754000
00000000000000000000000000000000000000000000000000000000000000000ffffffffffffff0000711ddddc17000ddd7777ddddd777d0000449495a54000
00000000000000000000000000000000000000000000000000000000000000000ffffffffffffff0000716da2d167000dddddddddddddddd0000455595359000
00000000009aa0000000000000000000000000000000000000000000000000000ff55555fffa55f0000766d2dd667000d7777777ddd55555000045d545559000
00000000099999900000000000000000000000000000000000000000000000000ff56065fffa55f00007777777777000d7111117dddd4544000095d544944000
00000000955995590000000000000000000000000000000000000000000000000ff5c065fffa55f00007677777767000d75a5557dddd4544000095f544444000
00000000055005500000000000000000000000000000000000000000000000000ff55555fffa55f0000767dddd767000d7777777dddd4564000095e533333000
00000000000000000000000000000000000000000000000000000000000000000ffffffffffaa5f0000777dff97770009f9f9f9f9f9f4544000045d599999000
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
00033300000000000000000011555511111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33333333000003333330000011555511111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33333333000033333733000011155770077007710000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33333333000033733333300011155770077007710000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33333333000333333333300011155007700770010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33333330000373337373000011155007700770010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
03333333000333733333000011155770077007710000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
03344433000044455440000011155770077007710000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00444400000000000000000011155111111111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00444400000000000000000011155111111111110000000000000000000000000000000000000000000000000000000fff000000000000000000000000000000
004444000000000000000000111551111111111100000000000000000000000000000000000000000000000000000ff777ff0000000000000000000000000000
0044440000000000000000001115513111111111000000000000000000000000000000000000000000000000000ff7777777ff00000000000000000000000000
00444400000000000000000013155131111111110000000000000000000000000000000000000000000000000ff77777777777ff000000000000000000000000
044444400000000000000000131553311111111100000000000000000000000000000000000000000000000ffffffffffffffffff00000000000000000000000
044444400000000000000000113533111111111100000000000000dd777000000000000000000000000000005757757577575775000000000000000000000000
444444440000000000000000113333111111111100000000000000dd777000000000000000000000000000005775757757577575000000000000000000000000
00000000000000000000bbbbbbbbb000333333333333333300777777777777777777777777777700000000009999999999999999000000000000000000000000
0000000dd00000000000b3333333b00003dddddddddddd300074444444444444444444444444470000000ff444774447744477444ff000000000000000000000
00000dddddd000000000b3443223b00003daaddaaddaad300074dd664666646666466634333d4700000ff77747dd747dd747dd74777ff0000000000000000000
000ddd5555ddd0000000b3443993b00003d77dd77dd77d300074d6664666646633433334333d47000ff7777747dd747dd747dd7477777ff00000000000000000
0ddd55555555ddd00000b3443333b00003d47dd79dde7d3000746666466664633343333433dd470ff777777747777477774777747777777ff000000000000000
dd550000000055dd0000bbbbbbbbb00003d47d37b3dc7d300074444444444444444444444444470fffffffff4ffff4ffff4ffff4fffffffff000000000000000
55550a0aa0a055550000b3333333b00003dddd3333dddd3000777777777777777777777777777700777777774777747777477774777777770000000000000000
55550703a07055550000b34a3aa3b00003dddddddddddd300000077000007700000770000077000077ddd77747dd747dd747dd74777ddd770000000000000000
55550704707055550000b3493993b00003dddddddddddd300000077000007700000770000077000077ddd77747dd747dd747dd74777ddd770000000000000000
55550000000055550000b3493333b00003daaddaaddaad300000077000007700000770000077000077ddd77747dd747dd747dd74777ddd770000000000000000
55555555555555550000bbbbbbbbb00003d79dd33dd97d300000077000007700000770000077000077ddd77747dd747dd747dd74777ddd770000000000000000
55550000000055550000b7676767b00003d79dd33dd97d3000000770000077555557700000770000ffffffff4ffff4fddf4ffff4ffffffff0000000000000000
55550a05501055550000b7676767b00003dbbdd33ddbbd3000000775555577555557755555770000777777774777747dd7477774777777770000000000000000
55550a05901055550000b7676767b00003ddddd33ddddd30005557755555775555577555557755507777777444ff444dd444ff44477777770000000000000000
55550909901055550000b7676767b00003dddddffddddd30005555555555555555555555555555507777777fff777777777777fff77777770000000000000000
55550909901055550000b7676767b00003dddddfffdddd30000000000000000000000000000000007777777ffffffffffffffffff77777770000000000000000
__label__
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
666c666666ccc6c6c6c6c6cc66cc66ccc66666666666666666ccc6c6c6ccc6666666666666666666666666666666777777777777777777777777777777777666
66c6c6666666c6c6c6c6c66c666c6666c66666666666666666c6c6c6c6c6c666666666666666666666666666666677eee77ee77ee77ee7eee777777777777666
66c6c666666cc6ccc66c666c666c66ccc66666ccc66666ccc6ccc6ccc6c6c666666666666666666666666666666677e7e7e7e7e7e7e7777e7777777777777666
66c666666666c666c6c6c66c666c66c6666666666666666666c6c666c6c6c666666666666666666666666666666677ee77e7e7e7e7eee77e7777777777777666
666cc66666ccc666c6c6c6ccc6ccc6ccc66666666666666666ccc666c6ccc666666666666666666666666666666677e7e7e7e7e7e777e77e7777777777777666
6666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666677eee7ee77ee77ee777e7777777777777666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666777777777777777777777777777777777666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
666633366666666666666666666666666666666666666666666666666666666666666666666fff66666666666666666666666666666666666666666666666666
6333333336666666666666666666666666666666666666666666666666666666666666666ff777ff666666666666666666666666666666666666666666666666
63333333366666666666666666666666666666666666666666666666666666666666666ff7777777ff6666666666666666666666666666666666666666666666
633333333666666666666666666666666666666666666666666666666666666666666ff77777777777ff66666666666666666666666666666666666666666666
6333333336666666666666666666666666666666666666666666666666666666666ffffffffffffffffff6666666666666666666666666666666666666666666
63333333666666666666666666666666666666666666666666666666666666666666575775757757577566666666666666666666666666666666666666666666
66333333366666666666666666666666666666666666666666666666666666666666577575775757757566666666666666666666666666666666666666666666
663344433666666666666666666666666666666666666666666666666666666666ff9999999999999999ff666666666666666666666666666666666666666666
6664444666666666666666666666666666666666666666666666666666666666ff74447744477444774447ff6666666666666666666666666666666666666666
66644446666666666666666666666666666666666666666666666666666666ff777f47dd747dd747dd74f777ff66666666666666666666666666666666666666
666444466666666666666666666666666666666666666666666666666666ff77777f47dd747dd747dd74f77777ff666666666666666666666666666666666666
666444466666666666666666666666666666666666666666666666333333f777777f4777747777477774f777777f666666666666666666666666666666666666
666444466666666666666666666666666666666666666666666663333373ffffffff4ffff4ffff4ffff4ffffffff666666666666666666666666666666666666
6644444466666666666666666666666666666666666666666666633733337777777f4777747777477774f7777777666666666666666666666666666666666666
66444444666666666666666666666666666666666666666666663333333377ddd77f47dd747dd747dd74f77ddd77666666666666666666666666666666666666
d44444444ddddddddddddddddddddddddddddddddddddddddddd3733373777ddd77f47dd747dd747dd74f77ddd77dddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddd3337333377ddd77f47dd747dd747dd74f77ddd77dddddddddddddddddddddddddddddddddddd
ddddddddddddddddddddddddddddddddddddddddddddddddddddd444554477ddd77f47dd747dd747dd74f77ddd77dddddddddddddddddddddddddddddddddddd
ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddffffffff4ffff4fddf4ffff4ffffffffdddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd7777777f4777747dd7477774f7777777dddddddddddddddddddddddddddddddddddd
1111111111111111111111111111111111111111111111111111111111117777777444ff444dd444ff4447777777111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111111117777777fff777777777777fff7777777111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111111111aaaa1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111aacaca111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111aacaca111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111a9aaaa111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111aa99aa111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111566665111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111115756657511111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111511115111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111

