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
g_jump_max     = 38

g_del_time = 1.2

g_section_size = 150
g_edge_rhs  = 64
g_edge_lhs  = 16

g_racing_line = 118
g_car_line    = g_racing_line - 6

g_tile_size = 32

r_step = 1 / 360

spr_tree    = { 0,  32, 8,  16 }
spr_shrub   = { 8,  32, 16, 8  }
spr_player1 = { 8,  0,  8,  8  }
spr_player2 = { 8,  8,  8,  8  }
spr_player3 = { 8,  16, 8,  9  }
spr_boost1  = { 16, 0,  8,  8  }
spr_boost2  = { 24, 0,  8,  8  }
spr_boost3  = { 32, 0,  8,  8  }
spr_flag    = { 24, 32, 16, 16 }

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
      absolute_x = 16,
      x = 16,
      y = g_car_line,
      dir = dir_right,
      speed = 0,
      accel = 0.4,
      dy = 0,
      launched = false,
      jumping = false,
      boosted_at = false,
      boost_meter = 0,
      delivered = {},
      accelerating = false,
      del_start = 0,
   }

   -- Track debug info separately so dumping data is sane.
   dbg = {
      past = {},
      at_hypot = 0,
   }

   level = {
      length = g_section_size * 20,
      complete_at = false,
      scene_map = {},
      start_time = 600, -- doesn't change
      delivery_time = 600, -- change as deliveries are added
      prompt_for_help = true,
      will_help = false,
      delivery_count = 5
   }

   scene = { make_bg_spr(spr_flag, { 0, 88 }) }

   level.sections   = make_sections()
   level.deliveries = generate_deliveries()

   ramps = {}
   boosters = {}
   platforms = {}

   populate_scenery()
   populate_geometry()
end

function make_obj(pos, attr)
   return merge(
      { x = pos[1], y = pos[2], orig_x = pos[1], orig_y = pos[2] },
      attr
   )
end

function track_scene_obj(x)
   level.scene_map['at_'..flr(x/g_tile_size)] = x
end
function is_tile_free(x)
   return level.scene_map['at_'..flr(x/g_tile_size)] == nil
end

function make_bg_spr(spr, at)
   -- Track what has gone where in 32 pixel "tile" divisions on the x-axis.
   track_scene_obj(at[1])
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
   local sec_size = g_section_size -- level.length / 10
   for sec = 1, flr(level.length / sec_size) do
      local col = colours[(sec % #colours) == 0 and #colours or sec % #colours]
      add(sections, make_obj({sec_x, 32}, {width=sec_size,colour=col,id=sec}))
      sec_x += sec_size
   end

   return sections
end

function find_free(gen, check)
   local el = gen()
   -- Enter loop if the new tilet is already present to generate a new tile.
   while(not check(el)) do
      el = gen()
   end
   return el
end

function rand_tile_in_section(s)
   return find_free(
      function()
         return s.x + g_tile_size * randx(flr(s.width / g_tile_size))
      end,
      is_tile_free
   )
end

function populate_scenery()
   for s in all(level.sections) do
      for _ = 1,2 do
         local tile_x = rand_tile_in_section(s)
         local bg_obj = randx(2) == 1
            and make_bg_spr(spr_tree,  { tile_x, 85 })
            or  make_bg_spr(spr_shrub, { tile_x, 95 })

         add(scene, bg_obj)
      end
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

function make_delivery(deliveries)
   function is_section_free(sec)
      for s in all(deliveries) do
         if(sec.id == s.section.id) return false
      end
      return true
   end
   local function rand_section()
      -- Don't generate a delivery in the first or last section
      local idx = 1 + randx(#level.sections - 2)
      -- Only use odd indexes so the locations don't align with ramps.
      return level.sections[idx % 2 == 0 and idx + 1 or idx]
   end
   local function rand_location()
      return locations[randx(#locations)]
   end
   local function is_free_location(loc)
      for l in all(deliveries) do
         if l.id == loc.id then
            return false
         end
      end
      return true
   end

   local loc   = find_free(rand_location, is_free_location)
   local sec   = find_free(rand_section, is_section_free)
   local del_x = rand_tile_in_section(sec)

   sec.has_delivery = true

   track_scene_obj(del_x)

   level.delivery_time += (12 + randx(7))
   local delivery = make_obj(
      {del_x, loc.y_pos},
      {
         location=loc,
         width=loc.spr[3],
         id=delivery_id,
         section=sec,
         due=level.delivery_time,
         delivered=false
      }
   )

   return delivery
end

delivery_id = 1
function add_delivery(deliveries, del)
   deliveries[delivery_id] = del
   delivery_id += 1
end

function generate_deliveries()
   local deliveries = {}
   -- TODO The number of deliveries needs to be more dynamic.
   for _ = 1, level.delivery_count do
      local new_del = make_delivery(deliveries)
      add_delivery(deliveries, new_del)
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

function in_air()
   return car.launched or car.jumping
end

function car_launch()
   -- Only "launch" if not already in the air i.e jumping
   if not in_air() then
      car.launched = true
      car.jumping  = false
   end
end

function car_jump()
   car.launched = false
   car.jumping  = true
end

function car_land()
   car.launched = false
   car.jumping  = false
end

function calc_gravity_delta()
   local dy = min(g_jump_max, car.dy + (35 * g_dt)) -- 35 is arbitrary!
   return dy, car.y + dy * g_dt
end

function apply_gravity()
   -- The number used here feels about right, is arbitrary.
   car.dy, car.y = calc_gravity_delta()

   -- TODO Implement a bounce!
   if car.y >= g_car_line then
      car.y = g_car_line
      car.dy = 0
      car_land()
   else
      car_launch()
      debug('car.y = ', car.y, ', car.dy = ', car.dy)
   end
end

function on_ramp(car_x)
   car_x += 4
   local _, next_y = calc_gravity_delta()
   local car_y = next_y
   for r in all(ramps) do
      local rx0 = r.angle < 90 and r.x or r.x + r.width
      if r.angle < 90 then
         local rx1, ry1 = ramp_trig(rx0, r.y, r.hypot, r.angle)
         if (car_x > rx0 and car_x < rx1) and car_y >= ry1 then
            -- debug('on ramp ', car_x, ' > ', rx0, ' and ', car_x, ' < ', rx1, ' and ', car_y, ' >= ', ry1, '[', r.angle, ' ; ', r.hypot, ']')
            return r
         end
      else
         local rx1, ry1 = ramp_trig(rx0, r.y, r.hypot, r.angle)
         if (car_x > rx1 and car_x < rx0) and car_y >= ry1 then
            -- debug('on ramp ', car_x, ' > ', rx1, ' and ', car_x, ' < ', rx0, ' and ', car_y, ' >= ', ry1, '[', r.angle, ' ; ', r.hypot, ']')
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
   local _, next_y = calc_gravity_delta()
   local car_y = next_y + 8
   for p in all(platforms) do
      if car_x > p.x and car_x < (p.x + p.width) then
         -- Landing
         if car.dy > 0 -- falling down
            and (car_y < p.y and (car_y + car.dy * g_dt) > p.y) -- will be "on" it in the next frame
         then
            return p
         -- Landed
         elseif car.dy == 0 and not in_air() and flr(car_y - 8) == p.y then
            debug('staying on platform ', p)
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

function respect_incline(r)
   if r.angle < 90 then
      car.speed -= 0.1
   else
      car.speed += 0.1
   end
   car.dy = min(g_jump_max, car.dy + 0.2)
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
         new_dy *= car.speed
         car.dy = abs(new_dy) > g_jump_max and -g_jump_max or new_dy
      elseif btn(b_left) then
         car.speed -= car.accel
         car.dy = min(g_jump_max, car.dy + 10)
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
         new_dy *= car.speed
         car.dy = abs(new_dy) > g_jump_max and -g_jump_max or new_dy
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
   car_land()
end

last_vroom = t()
function update_car()
   local accelerating = btn(b_right) or btn(b_left)
   car.accelerating = accelerating

   if accelerating and t() - last_vroom > 0.25 then
      local prev_sfx = last_vroom % 1
      local vroom = prev_sfx > 0.5 and 2 or 3
      if in_air() then
         vroom = prev_sfx > 0.4 and 4 or 5
      elseif still_boosting() then
         vroom = prev_sfx > 0.4 and 6 or 7
      end
      sfx(vroom)
      last_vroom = t()
   end

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

   if not in_air() and btn(b_x) and car.del_start == 0 then
      car_jump()
      car.dy -= 30
      sfx(1)
   end

   -- Don't consider speed as it hasn't yet been calculated
   local r = on_ramp(car.x)

   if not still_boosting() then
      -- TODO Make this more gradual, probably need to move away from linear speed.
      local ns = car.speed
      if not in_air() then
         ns *= g_friction
         if not accelerating  then
            ns *= g_friction
         end
      else
         ns *= g_air_friction
      end

      if r then
         -- TODO Improve friction relative to ramp.
         ns *= g_friction * 0.95 - (r.angle/1000)
      end

      -- debug('applying friction was ', tostr(car.speed), ' now ', tostr(ns))
      -- For some reason going left doesn't reduce speed to 0. FP math >_<
      car.speed = abs(ns) > 0.05 and ns or 0

      car.boosted_at = false
   end

   -- Reduce boost if on the ground or in the air and "braking"
   local brake_button = car.dir == dir_right and b_left or b_right
   if still_boosting() and (not in_air() and t() - car.boosted_at > 0.3) or btn(brake_button) then
      if car.boost_meter > 0 then
         if btn(brake_button) then
            -- About enough to stop between ramps.
            car.boost_meter -= 1.5
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

   if in_air() then
      -- Landing
      if car.dy > 0 then
         if r then
            handle_ramp(r)
         elseif p then
            handle_platform(p)
         elseif not p then
            car.on_platform = false
            apply_gravity()
         else
            apply_gravity()
         end
      -- Launched on to a ramp
      elseif car.jumping and r then
         debug('on ramp ', r.angle, ' ; ', r.hypot, ' - ', car.x, 'x', car.y, ' - ', car.dy)
         handle_ramp(r)
      -- Falling
      else
         apply_gravity()
      end
   elseif r then
      handle_ramp(r)
      -- Initiate jump if on the next frame car is not on this ramp and
      -- has a negative vertical inertia.
      local next_ramp = on_ramp(car.x + car.speed)
      if next_ramp and r != next_ramp and car.dy < 0 then
         -- debug('ramp change! ', r.angle, ' -> ', next_ramp.angle)
         car_launch()
      end
   elseif p then
      handle_platform(p)
   else
      car.on_platform = false
      apply_gravity()
   end
end

function horizon_offset(y)
   return y - (0.1 * (g_car_line - car.y))
end

function update_scene()
   local function update_pos(obj)
      local x = obj.x + -flr(car.speed)
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

   local abs_next_pos = car.absolute_x + flr(car.speed)
   if abs_next_pos > level.length then
      car.absolute_x = abs_next_pos % level.length
   elseif abs_next_pos < 0 then
      car.absolute_x = level.length + abs_next_pos
   else
      car.absolute_x = abs_next_pos
   end
end

function handle_deliveries()
   if in_air() then
      return
   end

   local delivering = false
   for del in all(level.deliveries) do
      local cx0 = car.x
      local cx1 = car.x+8

      local dx0 = del.x
      local dx1 = dx0+del.width

      if not del.delivered and ((cx1 > dx0 and cx1 < dx1) or (cx0 < dx1 and cx0 > dx0)) then
         delivering = true
         if car.del_start == 0 then
            car.del_start = t()
            local del_count = count(level.deliveries, function(d) return d.delivered end) + 1
            local del_sfx   = del_count == #level.deliveries and 8 or 9
            sfx(del_sfx, 2)
         end
         -- Don't prompt on the first delivery.
         if any(level.deliveries, function(d) return d.delivered end) then
            if btn(b_x) and level.prompt_for_help then
               level.prompt_for_help = false
               level.will_help = true
               local new_del = make_delivery(level.deliveries)
               new_del.for_robots = true
               new_del.section.for_robots = true
               add_delivery(level.deliveries, new_del)
            elseif btnp(b_z) then
               level.prompt_for_help = false
               level.will_help = false
            end
         end
         if t() - car.del_start > g_del_time then
            del.delivered = true
            del.done_at = t() + level.start_time
            car.del_start = 0
            local del_count = count(level.deliveries, function(d) return d.delivered end)
            if #level.deliveries == del_count then
               level.complete_at = t()
            end
            return
         end
      end
   end

   if not delivering and car.del_start > 0 then
      car.del_start = 0
      sfx(-1, 2)
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
         if not d.delivered then
            print(clock_time(d.due), del_x - 4, d.y - 8, white)
            local dw = del_x + d.width
            if car.del_start > 0 and not in_air() then
               local perc = 22 * ((t() - car.del_start) / g_del_time)
               local dy1 = 127 - perc

               rectfill(del_x,     105, dw,     dy1, white)
               rectfill(del_x + 1, 105, dw - 1, dy1, magenta)
               -- Don't prompt on the first delivery.
               if any(level.deliveries, function(d) return d.delivered end) then
                  if level.prompt_for_help then
                     print('help the robots?', 20, 64, white)
                     print(' ❎ ok 🅾️ no way', 40, 70, white)
                  end
               end
            else
               rectfill(del_x,     105, dw,     127, dim_grey)
               rectfill(del_x + 1, 105, dw - 1, 127, navy)
            end
         end
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
         local px1 = px0 + p.width
         local py0 = p.y
         local py1 = p.y + 1
         line(px0, py0, px1, py0, navy)
         line(px0, py1, px1, py1, dim_grey)
      end
   end

   for s in all(level.sections) do
      local sx0 = wrapped_x(s)
      if should_draw(sx0, s.width) then
         local sx = s.x
         local sy = s.y
         rectfill(sx0, sy, sx0 + s.width, sy + 2, s.colour)
         local glyph = s.has_delivery and '⌂' or '…'
         if(s.for_robots) glyph = ' 😐'
         print(glyph .. s.id, sx0 + 75, sy + 4, dim_grey)
      end
   end
end

function clock_time(n)
   local hours = flr(n / 60)
   local mins  = flr((n - (hours * 60)) % 60)
   local meridiem = 'AM'
   if hours >= 12 then
      if(flr(hours / 12) % 2 != 0) meridiem = 'PM'
      if(hours % 24 == 0) then
         hours = 0
      else
         hours = hours % 12
      end
   end
   local hour_s = (hours < 10 and '0' or '') .. hours
   local min_s  = (mins < 10 and '0' or '') .. mins
   return hour_s .. ':' .. min_s .. meridiem
end

function draw_ewe_ai()
   local by = 2
   rectfill(92, by, 124, by+6, white)
   if car.boost_meter > 0 then
      rectfill(92, by, 92 + car.boost_meter, by+6, orange)
      print('boost', 94, by+1, yellow)
   else
      print('boost', 94, by+1, salmon)
   end

   if car.del_start > 0 and not in_air() then
      print('⬇️ ' .. nice_pos(g_del_time - (t() - car.del_start)), 72, 122, azure)
   end

   rectfill(92, 22, 125, 31, black)
   rectfill(93, 23, 124, 31, dim_grey)
   local t_offset = t() + level.start_time
   print(clock_time(t_offset), 95, 25, lime)
   local del_offset = 0
   for d in all(level.deliveries) do
      if not d.delivered and del_offset < 3 then
         local before = clock_time(d.due)
         local rem    = d.due - t_offset
         local del_y  = del_offset * 8 + 2
         local col    = rem > 12 and white or rem > 6 and yellow or rem > 0 and salmon or red
         local msg    =  before .. ' ⌂ '.. d.section.id
         if(d.for_robots) msg = msg .. ' 😐'
         print(msg, 2, del_y, col)
         rectfill(66, del_y, 71, del_y + 4, white)
         rectfill(67, del_y+1, 70, del_y + 3, d.section.colour)
         del_offset += 1
      end
   end
   local remaining = count(level.deliveries, function(d) return not d.delivered end)
   if remaining > 2 then
      print(tostr(remaining - 3) .. ' remaining', 2, 25, white)
   end

   local cur_sect  = flr((75 + car.absolute_x) / g_section_size) + 1
   local prev_sect = cur_sect <= 1 and #level.sections or cur_sect - 1
   local next_sect = cur_sect >= #level.sections and 1 or cur_sect + 1
   print(prev_sect, 2, 36, dim_grey)
   print(next_sect, 120, 36, dim_grey)

   if level.complete_at then
      rectfill(8, 62, 120, 88, dim_grey)
      print('all deliveries complete!', 10, 64, white)
      local offset = 10
      local score  = 0
      for d in all(level.deliveries) do
         local rem = d.due - d.done_at
         local res_col = rem > 12 and white or rem > 6 and yellow or rem > 0 and salmon or red
         print('⌂', offset, 72, res_col)
         offset += 10
         score += (rem > 12 and 4 or rem > 6 and 3 or rem > 0 and 2 or 1)
      end
      local total = 4 * #level.deliveries
      print('customer satisfaction ' .. score .. '/' .. total, 10, 80, white)
      if any(level.deliveries, function(d) return d.for_robots end) then
         rectfill(8, 88, 120, 96)
         print('robot revolution begins', 10, 90, lime)
      end
   end

   local dbg = DEBUG and '🐱' or '@'
   local jumpstate = in_air() and '⬆️' or '-'
   print(dumper(dbg, ' ', nice_pos(car.dy), ' -> ', car.speed, ' ', jumpstate), 2, 122, azure)
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
      local bm = car.boost_meter
      local bs = bm > 20 and spr_boost1 or bm > 8 and spr_boost2 or spr_boost3
      render_sprite(bs, bx, car.y, flip)
   end

   local s = spr_player1
   if car.accelerating and not in_air() then
      s = t() % 1 > 0.5 and spr_player1 or spr_player2
   elseif in_air() then
      s = spr_player3
   end

   render_sprite(s, car.x, car.y, flip)
end

function _draw()
   cls(silver)

   -- Background layer.
   rectfill(0, horizon_offset(100), 128, 105, violet)
   rectfill(0, 105, 128, 128, navy)

   draw_scene()

   draw_car()

   draw_ewe_ai()
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

-- Add one table to another in-place.
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

-- Count of occurrences in a table
function count(t, f)
   local res = 0
   for v in all(t) do
      if f(v) then
         res += 1
      end
   end
   return res
end

-- Random index.
function randx(n)
   return flr(rnd(n)) + 1
end

-- Create a randomly ordered copy of a
function shuffle(a)
   local copy = copy_table(a)
   local res = {}
   for _ = 1, #copy do
      local idx = randx(#copy)
      add(res, copy_table(copy[idx]))
      deli(copy, idx)
   end
   return res
end

-- Like sprintf %2f
function nice_pos(num)
   local s   = sgn(num)
   local n   = abs(num)
   local sig = flr(n)
   local frc = flr(n * 100 % 100)
   if(frc == 0) then
      frc = '00'
   elseif(frc < 10) then
      frc = '0' .. frc
   end
   return (s == -1 and '-' or '') .. sig .. '.' .. frc
end

__gfx__
0000000000aaaa0000000000000000000000000000000000000000000000000007777777777777700000000000000000000000000d0000000000555555555000
000000000aacaca0000000000000000000000000000000000000000000000000011111111111111000000000000000000000000ddddd00000000449444444000
007007000aacaca000000000000000000000000000000000000000000000000001777777777777100000000000000000000000ddddddd0000000455594444000
000770000a9aaaa000000a000000000000000000000000000000000000000000017fff7676fff71077777777777777770000ddddddddddd0000045a594944000
000770000aa99aa00007999000000a0000009000000000000000000000000000017fff6767fff71075611144cc411567000ddddddddddddd0000957544944000
007007000588885000aa889a00a7889000a9a900000000000000000000000000017fff7676fff710765fff44cc4ff7570ddddddddddddddd000095b544449000
00000000575885750007999000000a00000090000000000000000000000000000177777777777710757fff44cc4ff567ddd7777ddddd777d0000455544449000
000000000500005000000a0000000000000000000000000000000000000000000111111111111110755fff44994ff557ddd7aa7ddddd717d0000444445554000
000000000000000000000000000000000000000000000000000000000000000001111111111111107777777777777777ddd7a17ddddd717d0000449445754000
0000000000aaaa000000000000000000000000000000000000000000000000000ffffffffffffff0000711dddd117000ddd7777ddddd777d0000449495a54000
000000000aacaca00000000000000000000000000000000000000000000000000ffffffffffffff0000716da2d167000dddddddddddddddd0000455595359000
000000000aacaca00000000000000000000000000000000000000000000000000ff55555fffa55f0000766d2dd667000d7777777ddd55555000045d545559000
000000000a9aaaa00000000000000000000000000000000000000000000000000ff56065fffa55f00007777777777000d7111117dddd4544000095d544944000
0000000005a99a500000000000000000000000000000000000000000000000000ff5c065fffa55f00007677777767000d75a5557dddd4544000095f544444000
00000000575885750000000000000000000000000000000000000000000000000ff55555fffa55f0000767dddd767000d7777777dddd4564000095e533333000
00000000050000500000000000000000000000000000000000000000000000000ffffffffffaa5f0000777dff97770009f9f9f9f9f9f4544000045d599999000
0000000000aaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000aacaca00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000aacaca00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000a9aaaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000aa99aa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000aaaa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000058888500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000575885750000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000050000500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
66886688866666886688868886888666666886888668868886666666668886666666666666666666666666666666999999999999999999977777777777777666
6668668686686668668666868688866666866686668666686666666666868666666666666666666666666666666699aaa99aa99aa99aa9aaa777777777777666
6668668686666668668886888686866666888688668666686666666666888666666666666666666666666666666699a9a9a9a9a9a9a9999a7777777777777666
6668668686686668666686868686866666668686668666686666666666668666666666666666666666666666666699aa99a9a9a9a9aaa99a7777777777777666
6688868886666688868886868686866666886688866886686668666666668666666666666666666666666666666699a9a9a9a9a9a999a99a7777777777777666
6666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666699aaa9aa99aa99aa999a7777777777777666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666999999999999999999977777777777777666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66776677766666777677767776777666666776777667767776666666667776666666666666666666666666666666666666666666666666666666666666666666
66676676766766667676767676777666667666766676666766666666667666666666666666666666666666666666666666666666666666666666666666666666
66676676766666677676767776767666667776776676666766666666667776666666666666666666666666666666666666666666666666666666666666666666
66676676766766667676767676767666666676766676666766666666666676666666666666666666666666666666666666666666666666666666666666666666
66777677766666777677767676767666667766777667766766676666667776666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66776677766666767677767776777666666776777667767776666666667776666666666666666666666666666666666666666666666666666666666666666666
66676676766766767676667676777666667666766676666766666666666676666666666666666666666666666666666666666666666666666666666666666666
66676676766666777677767776767666667776776676666766666666666776666666666666666666666666666666666666666666666666666666666666666666
66676676766766667666767676767666666676766676666766666666666676666666666666666666666666666666666666666666666666666666666666666666
66777677766666667677767676767666667766777667766766676666667776666666666666666666666666666666000000000000000000000000000000000066
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666055555555555555555555555555555555066
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666055555555555555555555555555555555066
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666055bb55bbb55555bb55bbb5bbb5bbb555066
666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666660555b55b5b55b555b55b555b5b5bbb555066
666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666660555b55b5b555555b55bbb5bbb5b5b555066
666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666660555b55b5b55b555b5555b5b5b5b5b555066
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666055bbb5bbb55555bbb5bbb5b5b5b5b555066
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666055555555555555555555555555555555066
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666055555555555555555555555555555555066
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666556555665565556555665565566666655566666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666665666566656666566656656565656666656666666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666665556556656666566656656565656666655566666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666666656566656666566656656565656666666566666666666666666666666666
66666666666666666666666666666666666666666666666666666666666666666665566555665566566555655665656666655566666666666666666666666666
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
66666666666666666666666666666666666666666666666666666666666666666666666fff666666666666666666666666666666666666666666666666666666
666666666666666666666666666666666666666666666666666666666666666666666ff777ff6666666666666666666666666666666666666666666666666666
6666666666666666666666666666666666666666666666666666666666666666666ff7777777ff66666666666666666666666666666666666666666666666666
66666666666666666666666666633366666666666666666666666666666666666ff77777777777ff666666666666666666666666666666666666666666633366
666666666666666666666666333333336666666666666666666666666666666ffffffffffffffffff66666666666666666666666666666666666666633333333
66666666666666666666666633333333666666666666666666666666666666665757757577575775666666666666666666666666666666666666666633333333
66666666666666666666666633333333666666666666666666666666666666665775757757577575666666666666666666666666666666666666666633333333
66666666666666666666666633333333666666666666666666666666666666669999999999999999666666666666666666666666666666666666666633333333
6666666666666666666666663333333666666666666666666666666666666ff444774447744477444ff666666666666666666666666666666666666633333336
66666666666666666666666663333333666666666666666666666666666ff77747dd747dd747dd74777ff6666666666666666666666666666666666663333333
666666666666666666666666633444336666666666666666666666666ff7777747dd747dd747dd7477777ff66666666666666666666666666666666663344433
66666666666666666666666666444466666666666666666666666666f777777747777477774777747777777f6666666666666666666666666666666666444466
66666666666666666666666666444466666666666666666666666666ffffffff4ffff4ffff4ffff4ffffffff6666666666666666666666666666666666444466
66666666666666666666666666444466666666666666666666666666777777774777747777477774777777776666666666666666666666666666666666444466
6666666666666666666666666644446666666666666666666666666677ddd77747dd747dd747dd74777ddd776666666666666666666666666666666666444466
6666666666666666666666666644446666666666666666666666666677ddd77747dd747dd747dd74777ddd776666666666666666666666666666666666444466
6666666666666666666666666444444666666666666666666666666677ddd77747dd747dd747dd74777ddd776666666666666666666666666666666664444446
6666666666666666666666666444444666666666666666666666666677ddd77747dd747dd747dd74777ddd776666666666666666666666666666666664444446
dddddddddddddddddddddddd44444444ddddddddddddddddddddddddffffffff4ffff4fddf4ffff4ffffffffdddddddddddddddddddddddddddddddd44444444
dddddddddddddddddddddddddddddddddddddddddddddddddddddddd777777774777747dd747777477777777dddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddd7777777444ff444dd444ff4447777777dddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddd7777777fff777777777777fff7777777dddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
11111111111111111111111111111111111111111111111111111111722222222222222222222222222222227111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111722222222222222222222222222222227111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111722222222222222222222222222222227111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111722222222222222222222222222222227111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111722222222222222222222222222222227111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111722222222222222222222222222222227111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111722222222222222222222222222222227111111111111111111111111111111111111111
111111111111111111111111111111111111111111111111111111117222222222aaaa2222222222222222227111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111722222222aacaca222222222222222227111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111722222222aacaca222222222222222227111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111722222222a9aaaa222222222222222227111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111172222a222aa99aa222222222222222227111111111111111111111111111111111111111
1111111111111111111111111111111111111111111111111111111172a788922588885222222222222222227111111111111111111111111111111111111111
aaaaaaaaaaaaa111111111111111111111111111111111111111111172222a225758857522222222222222227111111111111111111111111111111111111111
99999999999991111111111111111111111111111111111111111111722222222522225222222222222222227111111111111111111111111111111111111111
88888888888881111111111111111111111111111111111111111111722222222222222222222222222222227111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111722222222222222222222222222222227111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111722222222222222222222222222222227111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111722222222222222222222222222222227111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111722222222222222222222222222222227111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111722222222222222222222222222222227111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111

__sfx__
4d0600000511705117061170811709117091170211702117031170611708117091170211702117031170511706117061170711708117011170311704117051100611007110001100010000100001000010000000
4b08000005534055360553007531075300b5350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a70800000573404721057310472500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
9f0a00000473402721047310272500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a70800001172410711117211071500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
57080000107240e711107210e71500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a70800000c7440e7310c7410e73500700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010800000e744107310e7411073500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
090b000013534155311353015530175400c540175400c5401a5301c5301a5301c5301f540215401f5402154023550235502355024551245512455124555000000000000000000000000000000000000000000000
510c000013534155311353015530175400c540175400c5401a5301c5301a5301c5350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01100000180501a0501c050180501a0501c0501b0501b0501d05018050180501a0501c0501d050210501f050210501f05021050230502305020050230502005023050220502205022050240501d0501d05018050
__music__
00 0a424344

