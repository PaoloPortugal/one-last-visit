-- entities

sprites={
    player={
        still=1,
        walk={
            ver_1=3,
            ver_2=5,
            hor_1=7,
            hor_2=9,
            hor_3=11
        },
        pull=13
    },
    chair=16,
    interact=32
}

flags={
    solid=0,
    barrier=7
}

-- the player and camera logic are taken and adapted from the advanced micro platformer - starting kit by @matthughson
-- it can be found here: https://www.lexaloffle.com/bbs/?tid=28793

function make_player(s_x,s_y)
-- creates a new player character
    local p={
        x=s_x,
        y=s_y,
        dx=0, -- speed on x axis
        dy=0, -- speed on y axis
        acc=0.05,
        max_dx=1,
        max_dy=1,

        w=16, -- width
        h=24, -- height

        interact_range=4, -- how close to be to interact
        nearby_interactable=nil, -- object player can interact with right now

        inventory={},

        anims={
            -- frames indicates how long each sprite is shown
            -- sprites indicates which sprites are shown
            ["still"]={
                frames=60,
                sprites={sprites.player.still}
            },
            ["walk_ver"]={
                frames=15,
                sprites={sprites.player.walk.ver_1,sprites.player.walk.ver_2}
            },
            ["walk_hor"]={
                frames=15,
                sprites={sprites.player.walk.hor_1,sprites.player.walk.hor_2,sprites.player.walk.hor_1,sprites.player.walk.hor_3}
            },
            ["pull"]={
                frames=60,
                sprites={sprites.player.pull}
            }
        },

        -- animation variables
        curranim="still", -- start off standing still
        currsprite=1, -- at the first sprite
        anim_timer=1, -- amount of frames that must pass until the next sprite
        flipx=false, -- should the sprite be flipped?

        --request new animation to play.
        set_anim=function(self, anim)
            if anim==self.curranim then return end -- exit if we don't need to change the animation
            local a=self.anims[anim]
            self.anim_timer=a.frames
            self.curranim=anim
            self.currsprite=1
        end,

        -- call once per frame
        update=function(self, objects)
            self:check_objects(objects)
            self:input()
            self:handle_horizontal_movement()
            self:handle_vertical_movement()
            self:handle_animations()
        end,

        input=function(self)
            if btn(⬅️) then
                if self.dx>0 then self.dx=0 end
                self.dx-=self.acc
                self.flipx=true
            elseif btn(➡️) then
                if self.dx<0 then self.dx=0 end
                self.dx+=self.acc
                self.flipx=false
            else
                self.dx=0
            end
            self.dx=mid(-self.max_dx,self.dx,self.max_dx) -- limit horizontal speed

            if btn(⬆️) then
                if self.dy>0 then self.dy=0 end
                self.dy-=self.acc
            elseif btn(⬇️) then
                if self.dy<0 then self.dy=0 end
                self.dy+=self.acc
            else
                self.dy=0
            end
            self.dy=mid(-self.max_dy,self.dy,self.max_dy) -- limit vertical speed

            -- normalize diagonal speed
            if self.dx!=0 and self.dy!=0 then
                local norm=sqrt(self.dx^2+self.dy^2)
                self.dx=self.dx/norm
                self.dy=self.dy/norm
            end

            -- check for interact button
            if btnp(🅾️) and self.nearby_interactable then
                self.nearby_interactable:interact(self)
            end
        end,

        check_objects=function(self, objects)
            self.nearby_interactable=nil
            for obj in all(objects) do
                if obj.interactable then
                    local dist=sqrt((self.x-obj.x)^2+(self.y-obj.y)^2)
                    if dist<=self.interact_range then
                        self.nearby_interactable=obj
                        break
                    end
                end
            end
        end,

        handle_horizontal_movement=function(self)
            self.x+=self.dx
            local col,dir=self:check_solid_horizontal()
            if col then
                self.dx=0
                local offset=6
                if dir==1 then -- right
                    self.x=flr((self.x+offset)/8)*8-offset
                else -- left
                    self.x=ceil((self.x-offset)/8)*8+offset
                end
            end
        end,

        handle_vertical_movement=function(self)
            self.y+=self.dy
            local col,dir=self:check_solid_vertical()
            if col then
                self.dy=0
                local offset=2
                local y_base=self.y+10
                if dir==1 then -- down
                    self.y=flr((y_base+offset)/8)*8-offset-10.1
                else -- up
                    self.y=ceil((y_base-offset)/8)*8+offset-10
                end
            end
        end,

        check_solid_horizontal=function(self)
            local offset=6
            local y_base=self.y+10
            for i=-2,2,2 do -- only check bottom 4 pixels vertically
                if self.dx>0 and (fget(mget((self.x+(offset))/8,(y_base+i)/8),flags.solid) or fget(mget((self.x+(offset))/8,(y_base+i)/8),flags.barrier)) then return true,1
                elseif self.dx<0 and (fget(mget((self.x-(offset))/8,(y_base+i)/8),flags.solid) or fget(mget((self.x-(offset))/8,(y_base+i)/8),flags.barrier)) then return true,-1 end
            end
            return false,nil -- didnt hit a solid tile
        end,

        check_solid_vertical=function(self)
            local offset=2
            local y_base=self.y+10
            for i=-(self.w/3),(self.w/3),2 do
                if self.dy<0 and (fget(mget((self.x+i)/8,(y_base-(offset))/8),flags.solid) or fget(mget((self.x+i)/8,(y_base-(offset))/8),flags.barrier)) then return true,-1
                elseif self.dy>=0 and (fget(mget((self.x+i)/8,(y_base+(offset))/8),flags.solid) or fget(mget((self.x+i)/8,(y_base+(offset))/8),flags.barrier)) then return true,1 end
            end
            return false,nil -- didnt hit a solid tile
        end,

        handle_animations=function(self)
            if self.dx!=0 then
                self:set_anim("walk_hor")
            elseif self.dy!=0 then
                self:set_anim("walk_ver")
            else
                self:set_anim("still")
            end

            -- animation timer
            self.anim_timer-=1
            if self.anim_timer<=0 then
                self.currsprite+=1
                local a=self.anims[self.curranim]
                self.anim_timer=a.frames
                if self.currsprite>#a.sprites then self.currsprite=1 end -- loop
            end
        end,

        draw=function(self)
            local a=self.anims[self.curranim]
            local sprite_tl=a.sprites[self.currsprite]
            local sprite_tr=sprite_tl+1
            local sprite_ml=sprite_tl+16
            local sprite_mr=sprite_ml+1
            local sprite_bl=sprite_ml+16
            local sprite_br=sprite_bl+1
            
            if self.dy<0 then pal(7,15) else pal(7,1) end -- this removes the eyes if the player is moving up to not make a new sprite from the back
            
            -- draw 3x2 sprite grid
            local x_base=self.x-(self.w/2)
            local y_base=self.y-(self.h/2)

            spr(self.flipx and sprite_tr or sprite_tl, x_base, y_base, 1, 1, self.flipx, false)
            spr(self.flipx and sprite_tl or sprite_tr, x_base+8, y_base, 1, 1, self.flipx, false)
            spr(self.flipx and sprite_mr or sprite_ml, x_base, y_base+8, 1, 1, self.flipx, false)
            spr(self.flipx and sprite_ml or sprite_mr, x_base+8, y_base+8, 1, 1, self.flipx, false)
            spr(self.flipx and sprite_br or sprite_bl, x_base, y_base+16, 1, 1, self.flipx, false)
            spr(self.flipx and sprite_bl or sprite_br, x_base+8, y_base+16, 1, 1, self.flipx, false)
            
            pal()

            -- draw interact prompt if near something
            if self.nearby_interactable then
                print("Z",self.x-2,self.y-self.h/2-8,7)
            end
        end,

        draw_inventory=function(self)
            
        end
    }
    return p
end

function make_chair(s_x,s_y)
-- creates a chair object
    local c={
        x=s_x,
        y=s_y,
        dx=0,
        dy=0,

        w=8, -- width
        h=8, -- height

        interactable=true,

        -- call once per frame
        update=function(self)
            if self.interacting then
                self.dx=player.dx
                self.dy=player.dy
                self:handle_horizontal_movement()
                self:handle_vertical_movement()
            end
        end,

        handle_horizontal_movement=function(self)
            self.x+=self.dx

            local col,dir=self:check_solid_horizontal()
            local offset=self.w/2
            if col then
                self.dx=0
                if dir==1 then -- right
                    self.x=flr((self.x+(offset))/8)*8-(offset)
                else -- left
                    self.x=ceil((self.x-(offset))/8)*8+(offset)
                end
            end
        end,

        handle_vertical_movement=function(self)
            self.y+=self.dy

            local col,dir=self:check_solid_vertical()
            local offset=self.h/2
            if col then
                self.dy=0
                if dir==1 then -- down
                    self.y=flr((self.y+(offset))/8)*8-(offset)
                else -- up
                    self.y=ceil((self.y-(offset))/8)*8+(offset)
                end
            end
        end,

        check_solid_vertical=function(self)
            local offset=self.h/2
            for i=-(self.w/3),(self.w/3),2 do
                if self.dy<0 and (fget(mget((self.x+i)/8,(self.y-(offset))/8),flags.solid) or fget(mget((self.x+i)/8,(self.y-(offset))/8),flags.barrier)) then return true,-1
                elseif self.dy>=0 and (fget(mget((self.x+i)/8,(self.y+(offset))/8),flags.solid) or fget(mget((self.x+i)/8,(self.y+(offset))/8),flags.barrier)) then return true,1 end
            end
            return false,nil -- didnt hit a solid tile
        end,

        check_solid_horizontal=function(self)
            if self.x<=7 then return true end
            local offset=self.w/2
            for i=-(self.w/3),(self.w/3),2 do
                if self.dx>0 and (fget(mget((self.x+(offset))/8,(self.y+i)/8),flags.solid) or fget(mget((self.x+(offset))/8,(self.y+i)/8),flags.barrier)) then return true,1
                elseif self.dx<0 and (fget(mget((self.x-(offset))/8,(self.y+i)/8),flags.solid) or fget(mget((self.x-(offset))/8,(self.y+i)/8),flags.barrier)) then return true,-1 end
            end
            return false,nil -- didnt hit a solid tile
        end,

        draw=function(self)
            spr(sprites.chair,
                self.x-(self.w/2),
                self.y-(self.h/2),
                self.w/8,self.h/8,
                false,
                false)
        end,
    }
    return c
end

function make_camera(target)
-- creates a new camera
    local c=
    {
        tar=target,--target to follow.
        pos={x=target.x,y=target.y},
       
        --how far from center of screen target must
        --be before camera starts following.
        --allows for movement in center without camera
        --constantly moving.
        pull_threshold=16,

        --min and max positions of camera.
        --the edges of the level.
        pos_min={x=72,y=1},
        pos_max={x=64*8-72,y=64*8-72},
       
        shake_remaining=0,
        shake_force=0,

        update=function(self)

            self.shake_remaining=max(0,self.shake_remaining-1)
           
            --follow target outside of
            --pull range.
            if self:pull_max_x()<self.tar.x then
                self.pos.x+=min(self.tar.x-self:pull_max_x(),4)
            end
            if self:pull_min_x()>self.tar.x then
                self.pos.x+=min((self.tar.x-self:pull_min_x()),4)
            end
            if self:pull_max_y()<self.tar.y then
                self.pos.y+=min(self.tar.y-self:pull_max_y(),4)
            end
            if self:pull_min_y()>self.tar.y then
                self.pos.y+=min((self.tar.y-self:pull_min_y()),4)
            end

            --lock to edge
            if(self.pos.x<self.pos_min.x)self.pos.x=self.pos_min.x
            if(self.pos.x>self.pos_max.x)self.pos.x=self.pos_max.x
            if(self.pos.y<self.pos_min.y)self.pos.y=self.pos_min.y
            if(self.pos.y>self.pos_max.y)self.pos.y=self.pos_max.y
        end,

        cam_pos=function(self)
            return self.pos.x-64,self.pos.y-64
        end,

        pull_max_x=function(self)
            return self.pos.x+self.pull_threshold
        end,

        pull_min_x=function(self)
            return self.pos.x-self.pull_threshold
        end,

        pull_max_y=function(self)
            return self.pos.y+self.pull_threshold
        end,

        pull_min_y=function(self)
            return self.pos.y-self.pull_threshold
        end,
    }

    return c
end
