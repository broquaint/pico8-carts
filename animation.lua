
function wait(n)
   for _ = 1,n do yield() end
end

function delay(f, n)
   animate(function() wait(n) f() end)
end

function animate(f)
   animate_obj({}, f)
end

function animate_obj(obj, animation)
   obj.co = cocreate(function()
         obj.animating = true
         animation(obj)
         obj.animating = false
         if(obj.cb) obj.cb(obj)
   end)
   coresume(obj.co)
   add(g_anims, obj)
end

function easein(t)
   return t*t
end
function easeoutquad(t)
  t-=1
  return 1-t*t
end
function lerp(a,b,t)
   return a+(b-a)*t
end

function animate_move(obj)
   for f = 1, obj.frames do
      if(obj.crashed or obj.collected) return
      obj.y = lerp(obj.from, obj.to, easein(f/obj.frames))
      yield()
   end
end
