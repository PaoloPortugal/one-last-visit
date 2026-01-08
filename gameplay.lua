-- gameplay
function make_pantry()
    local left=44
    local right=59
    local top=0
    local wall_start=16
    local bottom=22

    mset(left,top,58)
    for y=top+1,wall_start do mset(left,y,57) end
    mset(left,wall_start,62)

    for x=left+1,left+2 do
        mset(x,top,59)
        for y=top+1,top+5 do mset(x,y,15) end
        for y=top+6,top+7 do mset(x,y,70) end
        for y=top+8,bottom do mset(x,y,68) end
    end

    mset(left+3,top,59)
    for y=top+1,top+5 do mset(left+3,y,15) end
    for y=top+6,top+7 do mset(left+3,y,70) end
    for y=top+8,wall_start-1 do mset(left+3,y,68) end
    mset(left+3,wall_start,59)
    for y=wall_start+1,wall_start+4 do mset(left+3,y,31) end
    for y=wall_start+5,bottom do mset(left+3,y,70) end

    for x=left+4,right-1 do
        mset(x,top,59)
        for y=top+1,top+5 do mset(x,y,15) end
        for y=top+6,top+7 do mset(x,y,70) end
        for y=top+8,wall_start-1 do mset(x,y,68) end
    end

    mset(right,top,60)
    for y=top+1,wall_start do mset(right,y,57) end
    mset(right,wall_start,63)
end
